const std = @import("std");

const sdk = @import("paper_portal_sdk");
const core = sdk.core;
const display = sdk.display;
const power = sdk.power;
const speaker = sdk.speaker;
const Error = sdk.errors.Error;

const assets = @import("../assets.zig");
const fonts = @import("../fonts.zig");
const util = @import("../util.zig");

const Tap = util.Tap;
const Rect = util.Rect;

const kVoltageCenterX: i32 = 856;
const kVoltageCenterY: i32 = 41;
const kChargeIconX: i32 = 733;
const kChargeIconY: i32 = 16;

const kShutdownButton = Rect{ .x = 839, .y = 97, .w = 110, .h = 160 };

pub const AppPower = struct {
    last_bat_voltage_ms: i32 = 0,
    last_icon_chg_ms: i32 = 0,
    last_low_bat_ms: i32 = 0,
    current_usb_connected: bool = false,

    pub fn update(self: *AppPower, now_ms: i32, refresh: bool, tap: ?Tap, wifi_started_scanning: bool) Error!void {
        try self.update_bat_voltage(now_ms, refresh);
        try self.update_icon_chg(now_ms, refresh);
        try self.update_shut_down_button(tap);
        try self.check_low_battery_power_off(now_ms, wifi_started_scanning);
    }

    fn update_bat_voltage(self: *AppPower, now_ms: i32, refresh: bool) Error!void {
        if ((now_ms - self.last_bat_voltage_ms) <= 2000 and !refresh) return;

        const mv = power.battery_voltage_mv() catch 0;
        const volts: f32 = @as(f32, @floatFromInt(mv)) / 1000.0;

        var buf: [32]u8 = undefined;
        const s = std.fmt.bufPrint(buf[0..], " {d:.2}V ", .{volts}) catch buf[0..0];
        const len = @min(s.len, buf.len - 1);
        buf[len] = 0;

        try display.epd.set_mode(display.epd.FASTEST);
        try fonts.use(.Montserrat24);
        try display.text.set_datum(.middle_center);
        try display.text.set_color(display.colors.BLACK, display.colors.WHITE);
        try display.text.draw_cstr(buf[0..len :0], kVoltageCenterX, kVoltageCenterY);

        const text_w = display.text.text_width(buf[0..len :0]) catch 0;
        const text_h = display.text.font_height();
        const rx = kVoltageCenterX - @divTrunc(text_w, 2) - 2;
        const ry = kVoltageCenterY - @divTrunc(text_h, 2) - 2;
        const rw = text_w + 4;
        const rh = text_h + 4;

        if (rw > 0 and rh > 0) {
            try display.update_rect(rx, ry, rw, rh);
        }

        self.last_bat_voltage_ms = now_ms;
    }

    fn update_icon_chg(self: *AppPower, now_ms: i32, refresh: bool) Error!void {
        if ((now_ms - self.last_icon_chg_ms) <= 100 and !refresh) return;

        const usb_connected = power.is_usb_connected() catch false;
        if (usb_connected != self.current_usb_connected or refresh) {
            self.current_usb_connected = usb_connected;

            try display.epd.set_mode(display.epd.QUALITY);
            if (usb_connected) {
                try display.image.draw_png(kChargeIconX, kChargeIconY, assets.img_icon_chg_png);
            } else {
                try display.fill_rect(kChargeIconX, kChargeIconY, 50, 50, display.colors.WHITE);
            }
            try display.update_rect(kChargeIconX, kChargeIconY, 50, 50);
        }

        self.last_icon_chg_ms = now_ms;
    }

    fn update_shut_down_button(_: *AppPower, tap: ?Tap) Error!void {
        if (tap) |t| {
            if (!kShutdownButton.contains_click(t.x, t.y)) return;

            _ = speaker.tone(4000.0, 100) catch {};

            try display.epd.set_mode(display.epd.QUALITY);
            try display.image.draw_png(0, 0, assets.img_logo_png);
            try display.update();
            core.time.delay_ms(2000);

            try power.off();
        }
    }

    fn check_low_battery_power_off(self: *AppPower, now_ms: i32, wifi_started_scanning: bool) Error!void {
        if (!wifi_started_scanning) return;
        if ((now_ms - self.last_low_bat_ms) <= 2000) return;

        const usb_connected = power.is_usb_connected() catch false;
        const mv = power.battery_voltage_mv() catch 0;
        const volts: f32 = @as(f32, @floatFromInt(mv)) / 1000.0;

        if (!usb_connected and volts < 3.8) {
            try display.epd.set_mode(display.epd.QUALITY);
            try display.image.draw_png(0, 0, assets.img_logo_png);
            try display.update();
            core.time.delay_ms(2000);
            try power.off();
        }

        self.last_low_bat_ms = now_ms;
    }
};
