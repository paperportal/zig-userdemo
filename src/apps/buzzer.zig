const sdk = @import("paper_portal_sdk");
const display = sdk.display;
const speaker = sdk.speaker;
const Error = sdk.errors.Error;

const assets = @import("../assets.zig");
const util = @import("../util.zig");

const Tap = util.Tap;
const Rect = util.Rect;

const kButtonRect = Rect{ .x = 238, .y = 320, .w = 207, .h = 207 };
const kIconX: i32 = 298;
const kIconY: i32 = 380;
const kIconW: i32 = 88;
const kIconH: i32 = 85;

fn drawIcon(is_beeper_on: bool) Error!void {
    if (is_beeper_on) {
        try display.image.drawPng(kIconX, kIconY, assets.img_icon_mute_off_png);
    } else {
        try display.image.drawPng(kIconX, kIconY, assets.img_icon_mute_on_png);
    }
    try display.updateRect(kIconX, kIconY, kIconW, kIconH);
}

pub const AppBuzzer = struct {
    is_beeper_on: bool = false,

    pub fn update(self: *AppBuzzer, tap: ?Tap, refresh: bool) Error!void {
        if (tap) |t| {
            if (kButtonRect.containsClick(t.x, t.y)) {
                if (self.is_beeper_on) {
                    self.is_beeper_on = false;
                    _ = speaker.beeperStop() catch {};
                } else {
                    self.is_beeper_on = true;
                    _ = speaker.beeperStart(4000.0, 4, 100, 100, 1000) catch {};
                }
                try drawIcon(self.is_beeper_on);
                return;
            }
        }

        if (refresh) {
            try drawIcon(self.is_beeper_on);
        }
    }
};
