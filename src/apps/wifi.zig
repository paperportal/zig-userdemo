const std = @import("std");

const sdk = @import("paper_portal_sdk");
const display = sdk.display;
const net = sdk.net;
const speaker = sdk.speaker;
const Error = sdk.errors.Error;

const assets = @import("../assets.zig");
const fonts = @import("../fonts.zig");
const util = @import("../util.zig");

const Tap = util.Tap;
const Rect = util.Rect;

const kScanButton = Rect{ .x = 506, .y = 248, .w = 276, .h = 127 };
const kScanIconX: i32 = 543;
const kScanIconY: i32 = 287;
const kScanIconW: i32 = 201;
const kScanIconH: i32 = 53;

const kResultRect = Rect{ .x = 463, .y = 97, .w = 363, .h = 431 };

const State = enum {
    Idle,
    FirstScan,
    ScanningResult,
};

fn draw_scan_icon() Error!void {
    try display.epd.set_mode(display.epd.QUALITY);
    try display.image.draw_png(kScanIconX, kScanIconY, assets.img_icon_wifi_scan_png);
    try display.update_rect(kScanIconX, kScanIconY, kScanIconW, kScanIconH);
}

pub const AppWifi = struct {
    state: State = .Idle,
    time_count_ms: i32 = 0,
    wifi_started_scanning: bool = false,

    pub fn is_wifi_start_scanning(self: *const AppWifi) bool {
        return self.wifi_started_scanning;
    }

    pub fn on_create(_: *AppWifi) Error!void {
        try draw_scan_icon();
    }

    pub fn update(self: *AppWifi, now_ms: i32, refresh: bool, tap: ?Tap) Error!void {
        switch (self.state) {
            .Idle => try self.handle_state_idle(refresh, tap),
            .FirstScan => try self.handle_state_first_scan(now_ms, refresh),
            .ScanningResult => try self.handle_state_scanning_result(now_ms, refresh),
        }
    }

    fn handle_state_idle(self: *AppWifi, refresh: bool, tap: ?Tap) Error!void {
        if (refresh) {
            try draw_scan_icon();
        }

        if (tap) |t| {
            if (!kScanButton.contains_click(t.x, t.y)) return;

            _ = speaker.tone(4000.0, 100) catch {};
            _ = net.wifi_scan_start() catch {};

            try display.epd.set_mode(display.epd.QUALITY);
            try display.fill_rect(kScanIconX, kScanIconY, kScanIconW, kScanIconH, display.colors.WHITE);
            try display.update_rect(kScanIconX, kScanIconY, kScanIconW, kScanIconH);

            self.state = .FirstScan;
        }
    }

    fn handle_state_first_scan(self: *AppWifi, now_ms: i32, refresh: bool) Error!void {
        if ((now_ms - self.time_count_ms) <= 1000 and !refresh) return;

        const scanning = net.wifi_scan_is_running();
        if (!scanning) {
            self.state = .ScanningResult;
            self.wifi_started_scanning = true;
            self.time_count_ms = 0;
            return;
        }

        try display.epd.set_mode(display.epd.TEXT);
        try display.text.set_datum(.middle_center);
        try display.text.set_color(display.colors.BLACK, null);
        try fonts.use(.Montserrat24);
        try display.text.draw("SCANNING...", 644, 312);

        try display.update_rect(kScanIconX, kScanIconY, kScanIconW, kScanIconH);

        self.time_count_ms = now_ms;
    }

    fn handle_state_scanning_result(self: *AppWifi, now_ms: i32, refresh: bool) Error!void {
        if ((now_ms - self.time_count_ms) <= 5000 and !refresh) return;

        const best = net.wifi_scan_get_best() catch net.WifiRecord{
            .rssi = -100,
            .ssid = [_]u8{0} ** 33,
        };

        const count_i32 = net.wifi_scan_get_count() catch 0;
        const count: usize = if (count_i32 <= 0) 0 else @intCast(count_i32);

        try display.epd.set_mode(display.epd.QUALITY);
        try fonts.use(.Montserrat18);
        try display.text.set_datum(.middle_left);

        // Clear panel area.
        try display.fill_rect(kResultRect.x, kResultRect.y, kResultRect.w, kResultRect.h, display.colors.WHITE);

        // Title chrome.
        const grey: i32 = 0xE6E6E6;
        try display.fill_rect(465, 105, 164, 32, grey);
        try display.fill_rect(465, 137, 5, 379, grey);
        try display.fill_rect(470, 137, 351, 32, display.colors.BLACK);

        try display.text.set_color(display.colors.BLACK, null);
        try display.text.draw("SCAN RESULT:", 478, 121);

        // Best SSID line (white on black bar).
        try display.text.set_color(display.colors.WHITE, null);
        var best_buf: [96]u8 = undefined;
        const best_ssid = best.ssid_slice();
        const best_fmt = std.fmt.bufPrint(best_buf[0..], "Best: {s} ({d} dBm)", .{ best_ssid, best.rssi }) catch best_buf[0..0];
        const best_len = @min(best_fmt.len, best_buf.len - 1);
        best_buf[best_len] = 0;
        try display.text.draw_cstr(best_buf[0..best_len :0], 478, 153);

        // Wi-Fi list.
        try display.text.set_color(display.colors.BLACK, null);
        const start_x: i32 = 478;
        const start_y: i32 = 197;
        const gap: i32 = 33;
        const max_num: usize = 10;

        const limit = @min(count, max_num);
        var i: usize = 0;
        while (i < limit) : (i += 1) {
            const rec = net.wifi_scan_get_record(@intCast(i)) catch continue;

            var line_buf: [96]u8 = undefined;
            const ssid = rec.ssid_slice();
            const line = std.fmt.bufPrint(line_buf[0..], "{s} ({d} dBm)", .{ ssid, rec.rssi }) catch line_buf[0..0];
            const line_len = @min(line.len, line_buf.len - 1);
            line_buf[line_len] = 0;
            try display.text.draw_cstr(line_buf[0..line_len :0], start_x, start_y + @as(i32, @intCast(i)) * gap);
        }

        try display.update_rect(kResultRect.x, kResultRect.y, kResultRect.w, kResultRect.h);

        self.time_count_ms = now_ms;
    }
};
