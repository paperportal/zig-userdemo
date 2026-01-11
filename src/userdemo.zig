const sdk = @import("paper_portal_sdk");
const core = sdk.core;
const display = sdk.display;
const hal = sdk.hal;
const power = sdk.power;
const rtc = sdk.rtc;
const imu = sdk.imu;
const nvs = sdk.nvs;
const Error = sdk.errors.Error;

const assets = @import("assets.zig");
const fonts = @import("fonts.zig");
const util = @import("util.zig");

const AppPower = @import("apps/power.zig").AppPower;
const AppSdCard = @import("apps/sd_card.zig").AppSdCard;
const AppRtc = @import("apps/rtc.zig").AppRtc;
const AppBuzzer = @import("apps/buzzer.zig").AppBuzzer;
const AppImu = @import("apps/imu.zig").AppImu;
const AppWifi = @import("apps/wifi.zig").AppWifi;

const Tap = util.Tap;

var g_initialized: bool = false;
var g_pending_tap: ?Tap = null;
var g_app_power: AppPower = .{};
var g_app_sd: AppSdCard = .{};
var g_app_rtc: AppRtc = .{};
var g_app_buzzer: AppBuzzer = .{};
var g_app_imu: AppImu = .{};
var g_app_wifi: AppWifi = .{};
var g_last_full_refresh_ms: i32 = 0;
var g_refresh_requested: bool = false;

fn draw_firmware_version() Error!void {
    try display.epd.set_mode(display.epd.QUALITY);
    try fonts.use(.Montserrat36);
    try display.text.set_datum(.middle_center);
    try display.text.set_color(display.colors.BLACK, null);
    try display.text.draw("FactoryTest: V0.5", @divTrunc(display.width(), 2), @divTrunc(display.height(), 2));
    try display.update();
    display.wait_update();
}

fn draw_gray_scale_bars() Error!void {
    const colors = [_]i32{
        0xffffff, 0xeeeeee, 0xdddddd, 0xcccccc,
        0xbbbbbb, 0xaaaaaa, 0x999999, 0x888888,
        0x777777, 0x666666, 0x555555, 0x444444,
        0x333333, 0x222222, 0x111111, 0x000000,
    };

    try display.epd.set_mode(display.epd.QUALITY);
    try display.fill_screen(display.colors.BLACK);
    try display.update();
    display.wait_update();

    core.time.delay_ms(800);
    try display.start_write();
    var i: i32 = 0;
    while (i < 16) : (i += 1) {
        try display.fill_rect(i * 60, 0, 60, 540, colors[@intCast(i)]);
    }
    try display.end_write();

    try display.update();
    display.wait_update();
}

fn boot_display_test() Error!void {
    try draw_firmware_version();
    core.time.delay_ms(1000);

    try display.epd.set_mode(display.epd.QUALITY);
    try display.fill_screen(display.colors.BLACK);
    try display.update();
    display.wait_update();
    core.time.delay_ms(2000);

    try display.epd.set_mode(display.epd.QUALITY);
    try display.fill_screen(display.colors.WHITE);
    try display.update();
    display.wait_update();
    core.time.delay_ms(2000);

    try draw_gray_scale_bars();
    core.time.delay_ms(2000);
}

fn check_full_display_refresh_request(last_full_refresh_ms: *i32, refresh_requested: *bool, force: bool) Error!void {
    const now = core.time.millis();
    if ((now - last_full_refresh_ms.*) > 15000 or force) {
        try display.epd.set_mode(display.epd.QUALITY);
        try display.image.draw_png(0, 0, assets.img_bg_png);
        try display.update();

        refresh_requested.* = true;
        last_full_refresh_ms.* = now;
    }
}

pub fn init() Error!void {
    if (g_initialized) return;
    g_initialized = true;

    try core.begin();
    try display.rotation.set(1);

    _ = display.text.set_encoding_utf8() catch {};
    _ = display.text.set_wrap(false, false) catch {};
    _ = display.text.set_scroll(false) catch {};

    // Initialize peripherals used by the demo.
    _ = power.begin() catch {};
    _ = rtc.begin() catch {};
    _ = imu.begin() catch {};
    _ = hal.ext_port_test_start() catch {};

    // Match the upstream demo: set a known RTC time at startup.
    _ = rtc.set_datetime(.{
        .year = 2077,
        .month = 1,
        .day = 1,
        .week_day = 1,
        .hour = 12,
        .minute = 0,
        .second = 0,
    }) catch {};

    try fonts.ensure_loaded();
    try boot_display_test();

    // Draw static Wi-Fi icon (will also be redrawn on refresh).
    _ = g_app_wifi.on_create() catch {};

    g_last_full_refresh_ms = core.time.millis();
    g_refresh_requested = false;

    // Trigger startup refresh (background + force apps to redraw their regions).
    try check_full_display_refresh_request(&g_last_full_refresh_ms, &g_refresh_requested, true);
}

pub fn tick(now_ms: i32) Error!void {
    if (!g_initialized) return;

    const tap = g_pending_tap;
    g_pending_tap = null;

    try check_full_display_refresh_request(&g_last_full_refresh_ms, &g_refresh_requested, false);

    try g_app_power.update(now_ms, g_refresh_requested, tap, g_app_wifi.is_wifi_start_scanning());
    try g_app_sd.update(now_ms, g_refresh_requested);
    try g_app_rtc.update(now_ms, g_refresh_requested, tap);
    try g_app_buzzer.update(tap, g_refresh_requested);
    try g_app_imu.update(now_ms, g_refresh_requested);
    try g_app_wifi.update(now_ms, g_refresh_requested, tap);

    g_refresh_requested = false;
}

pub fn on_tap(tap: Tap) void {
    g_pending_tap = tap;
}
