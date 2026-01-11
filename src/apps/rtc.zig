const std = @import("std");

const sdk = @import("paper_portal_sdk");
const core = sdk.core;
const display = sdk.display;
const rtc = sdk.rtc;
const power = sdk.power;
const speaker = sdk.speaker;
const Error = sdk.errors.Error;

const assets = @import("../assets.zig");
const fonts = @import("../fonts.zig");
const util = @import("../util.zig");

const Tap = util.Tap;
const Rect = util.Rect;

const kTimeRect = Rect{ .x = 15, .y = 178, .w = 205, .h = 44 };
const kDateRect = Rect{ .x = 15, .y = 236, .w = 205, .h = 46 };
const kSleepButton = Rect{ .x = 839, .y = 267, .w = 110, .h = 160 };

fn draw_time(dt: rtc.DateTime) Error!void {
    try display.epd.set_mode(display.epd.FASTEST);

    try display.fill_rect(kTimeRect.x, kTimeRect.y, kTimeRect.w, kTimeRect.h, display.colors.WHITE);
    try display.text.set_datum(.middle_right);
    try display.text.set_color(display.colors.BLACK, null);
    try fonts.use(.Montserrat36);

    var buf: [32]u8 = undefined;
    const s = std.fmt.bufPrint(buf[0..], "{d:0>2}:{d:0>2}:{d:0>2}", .{ dt.hour, dt.minute, dt.second }) catch buf[0..0];
    const len = @min(s.len, buf.len - 1);
    buf[len] = 0;
    try display.text.draw_cstr(buf[0..len :0], 218, 200);
}

fn draw_date(dt: rtc.DateTime) Error!void {
    try display.epd.set_mode(display.epd.FASTEST);

    try display.fill_rect(kDateRect.x, kDateRect.y, kDateRect.w, kDateRect.h, display.colors.WHITE);
    try display.text.set_datum(.middle_right);
    try display.text.set_color(display.colors.BLACK, null);
    try fonts.use(.Montserrat36);

    var buf: [32]u8 = undefined;
    const s = std.fmt.bufPrint(buf[0..], "{d}/{d:0>2}/{d:0>2}", .{ dt.year, dt.month, dt.day }) catch buf[0..0];
    const len = @min(s.len, buf.len - 1);
    buf[len] = 0;
    try display.text.draw_cstr(buf[0..len :0], 218, 260);
}

pub const AppRtc = struct {
    last_time_ms: i32 = 0,
    last_date_ms: i32 = 0,

    pub fn update(self: *AppRtc, now_ms: i32, refresh: bool, tap: ?Tap) Error!void {
        try self.update_date_time(now_ms, refresh);
        try self.update_sleep_and_wake_up_button(tap);
    }

    fn update_date_time(self: *AppRtc, now_ms: i32, refresh: bool) Error!void {
        const update_time = (now_ms - self.last_time_ms) > 1000 or refresh;
        const update_date = (now_ms - self.last_date_ms) > 1000 or refresh;
        if (!update_time and !update_date) return;

        const dt = rtc.get_datetime() catch return;

        var min_x: i32 = 0;
        var min_y: i32 = 0;
        var max_x: i32 = 0;
        var max_y: i32 = 0;
        var any: bool = false;

        if (update_time) {
            try draw_time(dt);
            self.last_time_ms = now_ms;
            min_x = kTimeRect.x;
            min_y = kTimeRect.y;
            max_x = kTimeRect.x + kTimeRect.w;
            max_y = kTimeRect.y + kTimeRect.h;
            any = true;
        }

        if (update_date) {
            try draw_date(dt);
            self.last_date_ms = now_ms;
            const dx0 = kDateRect.x;
            const dy0 = kDateRect.y;
            const dx1 = kDateRect.x + kDateRect.w;
            const dy1 = kDateRect.y + kDateRect.h;

            if (!any) {
                min_x = dx0;
                min_y = dy0;
                max_x = dx1;
                max_y = dy1;
                any = true;
            } else {
                min_x = @min(min_x, dx0);
                min_y = @min(min_y, dy0);
                max_x = @max(max_x, dx1);
                max_y = @max(max_y, dy1);
            }
        }

        if (any) {
            const w = max_x - min_x;
            const h = max_y - min_y;
            if (w > 0 and h > 0) {
                try display.update_rect(min_x, min_y, w, h);
            }
        }
    }

    fn update_sleep_and_wake_up_button(_: *AppRtc, tap: ?Tap) Error!void {
        if (tap) |t| {
            if (!kSleepButton.contains_click(t.x, t.y)) return;

            _ = speaker.tone(4000.0, 100) catch {};

            try display.epd.set_mode(display.epd.QUALITY);
            try display.image.draw_png(0, 0, assets.img_logo_png);
            try display.update();
            core.time.delay_ms(2000);

            _ = rtc.clear_irq() catch {};
            _ = rtc.set_alarm_irq(16) catch {};
            try power.off();
        }
    }
};
