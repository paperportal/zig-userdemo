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

fn drawFirmwareVersion() Error!void {
    try display.epd.setMode(display.epd.QUALITY);
    try fonts.use(.Montserrat36);
    try display.text.setDatum(.middle_center);
    try display.text.setColor(display.colors.BLACK, null);
    try display.text.draw("FactoryTest: V0.5", @divTrunc(display.width(), 2), @divTrunc(display.height(), 2));
    try display.update();
    display.waitUpdate();
}

fn drawGrayScaleBars() Error!void {
    const colors = [_]i32{
        0xffffff, 0xeeeeee, 0xdddddd, 0xcccccc,
        0xbbbbbb, 0xaaaaaa, 0x999999, 0x888888,
        0x777777, 0x666666, 0x555555, 0x444444,
        0x333333, 0x222222, 0x111111, 0x000000,
    };

    try display.epd.setMode(display.epd.QUALITY);
    try display.fillScreen(display.colors.BLACK);
    try display.update();
    display.waitUpdate();

    core.time.delayMs(800);
    try display.startWrite();
    var i: i32 = 0;
    while (i < 16) : (i += 1) {
        try display.fillRect(i * 60, 0, 60, 540, colors[@intCast(i)]);
    }
    try display.endWrite();

    try display.update();
    display.waitUpdate();
}

fn bootDisplayTest() Error!void {
    try drawFirmwareVersion();
    core.time.delayMs(1000);

    try display.epd.setMode(display.epd.QUALITY);
    try display.fillScreen(display.colors.BLACK);
    try display.update();
    display.waitUpdate();
    core.time.delayMs(2000);

    try display.epd.setMode(display.epd.QUALITY);
    try display.fillScreen(display.colors.WHITE);
    try display.update();
    display.waitUpdate();
    core.time.delayMs(2000);

    try drawGrayScaleBars();
    core.time.delayMs(2000);
}

fn checkFullDisplayRefreshRequest(last_full_refresh_ms: *i32, refresh_requested: *bool, force: bool) Error!void {
    const now = core.time.millis();
    if ((now - last_full_refresh_ms.*) > 15000 or force) {
        try display.epd.setMode(display.epd.QUALITY);
        try display.image.drawPng(0, 0, assets.img_bg_png);
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

    _ = display.text.setEncodingUtf8() catch {};
    _ = display.text.setWrap(false, false) catch {};
    _ = display.text.setScroll(false) catch {};

    // Initialize peripherals used by the demo.
    _ = power.begin() catch {};
    _ = rtc.begin() catch {};
    _ = imu.begin() catch {};
    _ = hal.extPortTestStart() catch {};

    // Match the upstream demo: set a known RTC time at startup.
    _ = rtc.setDatetime(.{
        .year = 2077,
        .month = 1,
        .day = 1,
        .week_day = 1,
        .hour = 12,
        .minute = 0,
        .second = 0,
    }) catch {};

    try fonts.ensureLoaded();
    try bootDisplayTest();

    // Draw static Wi-Fi icon (will also be redrawn on refresh).
    _ = g_app_wifi.onCreate() catch {};

    g_last_full_refresh_ms = core.time.millis();
    g_refresh_requested = false;

    // Trigger startup refresh (background + force apps to redraw their regions).
    try checkFullDisplayRefreshRequest(&g_last_full_refresh_ms, &g_refresh_requested, true);
}

pub fn tick(now_ms: i32) Error!void {
    if (!g_initialized) return;

    const tap = g_pending_tap;
    g_pending_tap = null;

    try checkFullDisplayRefreshRequest(&g_last_full_refresh_ms, &g_refresh_requested, false);

    try g_app_power.update(now_ms, g_refresh_requested, tap, g_app_wifi.isWifiStartScanning());
    try g_app_sd.update(now_ms, g_refresh_requested);
    try g_app_rtc.update(now_ms, g_refresh_requested, tap);
    try g_app_buzzer.update(tap, g_refresh_requested);
    try g_app_imu.update(now_ms, g_refresh_requested);
    try g_app_wifi.update(now_ms, g_refresh_requested, tap);

    g_refresh_requested = false;
}

pub fn onTap(tap: Tap) void {
    g_pending_tap = tap;
}
