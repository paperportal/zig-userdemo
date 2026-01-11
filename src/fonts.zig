const sdk = @import("paper_portal_sdk");
const display = sdk.display;
const Error = sdk.errors.Error;

const assets = @import("assets.zig");

pub const Font = enum {
    Montserrat18,
    Montserrat24,
    Montserrat36,
};

var loaded: bool = false;
var handle_18: i32 = -1;
var handle_24: i32 = -1;
var handle_36: i32 = -1;

pub fn ensure_loaded() Error!void {
    if (loaded) return;

    handle_18 = try display.vlw.register(assets.font_montserrat_medium_18_vlw);
    handle_24 = try display.vlw.register(assets.font_montserrat_medium_24_vlw);
    handle_36 = try display.vlw.register(assets.font_montserrat_medium_36_vlw);

    loaded = true;
}

pub fn use(font: Font) Error!void {
    try ensure_loaded();
    switch (font) {
        .Montserrat18 => try display.vlw.use(handle_18),
        .Montserrat24 => try display.vlw.use(handle_24),
        .Montserrat36 => try display.vlw.use(handle_36),
    }
}

