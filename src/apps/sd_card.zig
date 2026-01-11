const std = @import("std");

const sdk = @import("paper_portal_sdk");
const display = sdk.display;
const fs = sdk.fs;
const Error = sdk.errors.Error;

const fonts = @import("../fonts.zig");
const util = @import("../util.zig");

const Rect = util.Rect;

const kPanelRect = Rect{ .x = 260, .y = 178, .w = 185, .h = 104 };

const SdResult = struct {
    mounted: bool = false,
    write_ok: bool = false,
    card_type: fs.SdCardType = .Unknown,
    capacity_bytes: u64 = 0,
    name: [6]u8 = [_]u8{0} ** 6,

    fn eql(a: SdResult, b: SdResult) bool {
        return a.mounted == b.mounted and a.write_ok == b.write_ok and a.card_type == b.card_type and a.capacity_bytes == b.capacity_bytes and std.mem.eql(u8, a.name[0..], b.name[0..]);
    }
};

fn sd_card_test() SdResult {
    if (!fs.is_mounted()) {
        fs.mount() catch return SdResult{};
    }

    if (!fs.is_mounted()) return SdResult{};

    var result = SdResult{ .mounted = true };

    // Try write.
    var file = fs.File.open("/test.txt", fs.FS_WRITE | fs.FS_CREATE | fs.FS_TRUNC) catch blk: {
        result.write_ok = false;
        break :blk null;
    };
    if (file) |*f| {
        defer _ = f.close() catch {};
        const msg = "Hello, World!";
        const n = f.write(msg[0..]) catch 0;
        result.write_ok = (n == msg.len);
    }

    const info = fs.card_info() catch return result;
    result.mounted = info.mounted;
    result.card_type = info.card_type;
    result.capacity_bytes = info.capacity_bytes;
    result.name = info.name;
    return result;
}

fn draw(result: SdResult) Error!void {
    try display.epd.set_mode(display.epd.TEXT);

    try display.fill_rect(kPanelRect.x, kPanelRect.y, kPanelRect.w, kPanelRect.h, display.colors.WHITE);
    try display.text.set_datum(.middle_left);
    try display.text.set_color(display.colors.BLACK, null);

    if (result.mounted) {
        try fonts.use(.Montserrat24);

        var size_buf: [40]u8 = undefined;
        const size_slice = if (result.write_ok) blk: {
            const gb: f32 = @as(f32, @floatFromInt(result.capacity_bytes)) / (1024.0 * 1024.0 * 1024.0);
            break :blk std.fmt.bufPrint(size_buf[0..], "Size: {d:.1} GB", .{gb}) catch size_buf[0..0];
        } else blk: {
            break :blk std.fmt.bufPrint(size_buf[0..], "Write Failed", .{}) catch size_buf[0..0];
        };
        const size_len = @min(size_slice.len, size_buf.len - 1);
        size_buf[size_len] = 0;
        try display.text.draw_cstr(size_buf[0..size_len :0], 267, 197);

        try fonts.use(.Montserrat18);

        var type_buf: [32]u8 = undefined;
        const type_str = switch (result.card_type) {
            .Sdio => "Type: SDIO",
            .Mmc => "Type: MMC",
            .Sdhc => "Type: SDHC/SDXC",
            .Sdsc => "Type: SDSC",
            .Unknown => "Type: ",
        };
        const type_len = @min(type_str.len, type_buf.len - 1);
        std.mem.copyForwards(u8, type_buf[0..type_len], type_str[0..type_len]);
        type_buf[type_len] = 0;
        try display.text.draw_cstr(type_buf[0..type_len :0], 267, 234);

        var name_buf: [32]u8 = undefined;
        const nul = std.mem.indexOfScalar(u8, result.name[0..], 0) orelse result.name.len;
        const name_slice = result.name[0..nul];
        const name_fmt = std.fmt.bufPrint(name_buf[0..], "Name: {s}", .{name_slice}) catch name_buf[0..0];
        const name_len = @min(name_fmt.len, name_buf.len - 1);
        name_buf[name_len] = 0;
        try display.text.draw_cstr(name_buf[0..name_len :0], 267, 267);
    } else {
        try fonts.use(.Montserrat24);
        try display.text.draw("Not Found", 271, 231);
    }

    try display.update_rect(kPanelRect.x, kPanelRect.y, kPanelRect.w, kPanelRect.h);
}

pub const AppSdCard = struct {
    last_update_ms: i32 = 0,
    last_result: SdResult = SdResult{},
    has_last: bool = false,

    pub fn update(self: *AppSdCard, now_ms: i32, refresh: bool) Error!void {
        if ((now_ms - self.last_update_ms) <= 2000 and !refresh) return;

        const result = sd_card_test();

        if (!refresh and self.has_last and SdResult.eql(result, self.last_result)) {
            self.last_update_ms = now_ms;
            return;
        }

        self.last_result = result;
        self.has_last = true;

        try draw(result);
        self.last_update_ms = now_ms;
    }
};
