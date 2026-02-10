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

fn drawScanIcon() Error!void {
    try display.epd.setMode(display.epd.QUALITY);
    try display.image.drawPng(kScanIconX, kScanIconY, assets.img_icon_wifi_scan_png);
    try display.updateRect(kScanIconX, kScanIconY, kScanIconW, kScanIconH);
}

pub const AppWifi = struct {
    state: State = .Idle,
    time_count_ms: i32 = 0,
    wifi_started_scanning: bool = false,

    pub fn isWifiStartScanning(self: *const AppWifi) bool {
        return self.wifi_started_scanning;
    }

    pub fn onCreate(_: *AppWifi) Error!void {
        try drawScanIcon();
    }

    pub fn update(self: *AppWifi, now_ms: i32, refresh: bool, tap: ?Tap) Error!void {
        switch (self.state) {
            .Idle => try self.handleStateIdle(refresh, tap),
            .FirstScan => try self.handleStateFirstScan(now_ms, refresh),
            .ScanningResult => try self.handleStateScanningResult(now_ms, refresh),
        }
    }

    fn handleStateIdle(self: *AppWifi, refresh: bool, tap: ?Tap) Error!void {
        if (refresh) {
            try drawScanIcon();
        }

        if (tap) |t| {
            if (!kScanButton.containsClick(t.x, t.y)) return;

            _ = speaker.tone(4000.0, 100) catch {};
            _ = net.wifiScanStart() catch {};

            try display.epd.setMode(display.epd.QUALITY);
            try display.fillRect(kScanIconX, kScanIconY, kScanIconW, kScanIconH, display.colors.WHITE);
            try display.updateRect(kScanIconX, kScanIconY, kScanIconW, kScanIconH);

            self.state = .FirstScan;
        }
    }

    fn handleStateFirstScan(self: *AppWifi, now_ms: i32, refresh: bool) Error!void {
        if ((now_ms - self.time_count_ms) <= 1000 and !refresh) return;

        const scanning = net.wifiScanIsRunning();
        if (!scanning) {
            self.state = .ScanningResult;
            self.wifi_started_scanning = true;
            self.time_count_ms = 0;
            return;
        }

        try display.epd.setMode(display.epd.TEXT);
        try display.text.setDatum(.middle_center);
        try display.text.setColor(display.colors.BLACK, null);
        try fonts.use(.Montserrat24);
        try display.text.draw("SCANNING...", 644, 312);

        try display.updateRect(kScanIconX, kScanIconY, kScanIconW, kScanIconH);

        self.time_count_ms = now_ms;
    }

    fn handleStateScanningResult(self: *AppWifi, now_ms: i32, refresh: bool) Error!void {
        if ((now_ms - self.time_count_ms) <= 5000 and !refresh) return;

        const best = net.wifiScanGetBest() catch net.WifiRecord{
            .rssi = -100,
            .ssid = [_]u8{0} ** 33,
        };

        const count_i32 = net.wifiScanGetCount() catch 0;
        const count: usize = if (count_i32 <= 0) 0 else @intCast(count_i32);

        try display.epd.setMode(display.epd.QUALITY);
        try fonts.use(.Montserrat18);
        try display.text.setDatum(.middle_left);

        // Clear panel area.
        try display.fillRect(kResultRect.x, kResultRect.y, kResultRect.w, kResultRect.h, display.colors.WHITE);

        // Title chrome.
        const grey: i32 = 0xE6E6E6;
        try display.fillRect(465, 105, 164, 32, grey);
        try display.fillRect(465, 137, 5, 379, grey);
        try display.fillRect(470, 137, 351, 32, display.colors.BLACK);

        try display.text.setColor(display.colors.BLACK, null);
        try display.text.draw("SCAN RESULT:", 478, 121);

        // Best SSID line (white on black bar).
        try display.text.setColor(display.colors.WHITE, null);
        var best_buf: [96]u8 = undefined;
        const best_ssid = best.ssidSlice();
        const best_fmt = std.fmt.bufPrint(best_buf[0..], "Best: {s} ({d} dBm)", .{ best_ssid, best.rssi }) catch best_buf[0..0];
        const best_len = @min(best_fmt.len, best_buf.len - 1);
        best_buf[best_len] = 0;
        try display.text.drawCstr(best_buf[0..best_len :0], 478, 153);

        // Wi-Fi list.
        try display.text.setColor(display.colors.BLACK, null);
        const start_x: i32 = 478;
        const start_y: i32 = 197;
        const gap: i32 = 33;
        const max_num: usize = 10;

        const limit = @min(count, max_num);
        var i: usize = 0;
        while (i < limit) : (i += 1) {
            const rec = net.wifiScanGetRecord(@intCast(i)) catch continue;

            var line_buf: [96]u8 = undefined;
            const ssid = rec.ssidSlice();
            const line = std.fmt.bufPrint(line_buf[0..], "{s} ({d} dBm)", .{ ssid, rec.rssi }) catch line_buf[0..0];
            const line_len = @min(line.len, line_buf.len - 1);
            line_buf[line_len] = 0;
            try display.text.drawCstr(line_buf[0..line_len :0], start_x, start_y + @as(i32, @intCast(i)) * gap);
        }

        try display.updateRect(kResultRect.x, kResultRect.y, kResultRect.w, kResultRect.h);

        self.time_count_ms = now_ms;
    }
};
