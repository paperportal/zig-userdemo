const std = @import("std");

const sdk = @import("paper_portal_sdk");
const display = sdk.display;
const imu = sdk.imu;
const Error = sdk.errors.Error;

const fonts = @import("../fonts.zig");
const util = @import("../util.zig");

const Rect = util.Rect;

const kLeftRect = Rect{ .x = 15, .y = 409, .w = 102, .h = 98 };
const kRightRect = Rect{ .x = 117, .y = 409, .w = 105, .h = 98 };

pub const AppImu = struct {
    last_update_ms: i32 = 0,

    pub fn update(self: *AppImu, now_ms: i32, refresh: bool) Error!void {
        if ((now_ms - self.last_update_ms) <= 500 and !refresh) return;

        _ = imu.update() catch {};
        const accel = imu.getAccel() catch imu.Vec3{ .x = 0, .y = 0, .z = 0 };
        const gyro = imu.getGyro() catch imu.Vec3{ .x = 0, .y = 0, .z = 0 };

        try display.epd.setMode(display.epd.FASTEST);
        try display.text.setDatum(.middle_left);
        try display.text.setColor(display.colors.BLACK, null);
        try fonts.use(.Montserrat18);

        try display.fillRect(kLeftRect.x, kLeftRect.y, kLeftRect.w, kLeftRect.h, display.colors.WHITE);
        try display.fillRect(kRightRect.x, kRightRect.y, kRightRect.w, kRightRect.h, display.colors.WHITE);

        var buf: [24]u8 = undefined;

        var s = std.fmt.bufPrint(buf[0..], "AX: {d:.1}", .{accel.x}) catch buf[0..0];
        var len = @min(s.len, buf.len - 1);
        buf[len] = 0;
        try display.text.drawCstr(buf[0..len :0], 24, 420);

        s = std.fmt.bufPrint(buf[0..], "AY: {d:.1}", .{accel.y}) catch buf[0..0];
        len = @min(s.len, buf.len - 1);
        buf[len] = 0;
        try display.text.drawCstr(buf[0..len :0], 24, 458);

        s = std.fmt.bufPrint(buf[0..], "AZ: {d:.1}", .{accel.z}) catch buf[0..0];
        len = @min(s.len, buf.len - 1);
        buf[len] = 0;
        try display.text.drawCstr(buf[0..len :0], 24, 496);

        s = std.fmt.bufPrint(buf[0..], "GX: {d:.1}", .{gyro.x}) catch buf[0..0];
        len = @min(s.len, buf.len - 1);
        buf[len] = 0;
        try display.text.drawCstr(buf[0..len :0], 122, 420);

        s = std.fmt.bufPrint(buf[0..], "GY: {d:.1}", .{gyro.y}) catch buf[0..0];
        len = @min(s.len, buf.len - 1);
        buf[len] = 0;
        try display.text.drawCstr(buf[0..len :0], 122, 458);

        s = std.fmt.bufPrint(buf[0..], "GZ: {d:.1}", .{gyro.z}) catch buf[0..0];
        len = @min(s.len, buf.len - 1);
        buf[len] = 0;
        try display.text.drawCstr(buf[0..len :0], 122, 496);

        // Update both rectangles at once (they are adjacent).
        try display.updateRect(kLeftRect.x, kLeftRect.y, kLeftRect.w + kRightRect.w, kLeftRect.h);

        self.last_update_ms = now_ms;
    }
};
