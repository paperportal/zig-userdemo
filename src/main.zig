const userdemo = @import("userdemo.zig");

pub fn main() !void {
    return;
}

pub export fn ppInit(api_version: i32, api_features: i64, screen_w: i32, screen_h: i32) i32 {
    _ = api_version;
    _ = api_features;
    _ = screen_w;
    _ = screen_h;

    userdemo.init() catch {
        return -1;
    };
    return 0;
}

pub export fn ppTick(now_ms: i32) i32 {
    userdemo.tick(now_ms) catch {};
    return 0;
}

pub export fn ppOnGesture(kind: i32, x: i32, y: i32, dx: i32, dy: i32, duration_ms: i32, now_ms: i32, flags: i32) i32 {
    _ = dx;
    _ = dy;
    _ = duration_ms;
    _ = now_ms;
    _ = flags;
    if (kind == 1) {
        userdemo.onTap(.{ .x = x, .y = y });
    }
    return 0;
}
