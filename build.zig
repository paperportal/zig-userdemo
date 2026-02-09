const std = @import("std");
const sdk = @import("paper_portal_sdk");

pub fn build(b: *std.Build) void {
    const app = sdk.addPortalApp(b, .{
        .local_sdk_path = "../zig-sdk",
        .export_symbol_names = &.{ "pp_init", "pp_tick", "pp_on_gesture" },
    });

    _ = sdk.addPortalPackage(b, app.exe, .{
        .manifest = .{
            .id = "eaf05dce-18b7-482c-804e-4f07c87ef256",
            .name = "Userdemo",
            .version = "0.1.0",
        },
        .icon_png = b.path("icon.png"),
    });
}
