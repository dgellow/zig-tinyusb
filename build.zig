const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = "src/main.zig",
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "zig_tinyusb",
        .root_module = exe_mod,
    });

    exe_mod.addIncludePath(b.path("tinyusb/src/"));
    // exe_mod.addIncludePath(b.path("tinyusb/lib/"));

    exe_mod.addCMacro("CFG_TUSB_MCU", "OPT_MCU_MIMXRT1062");
    exe_mod.addCMacro("CFG_TUSB_OS", "OPT_OS_NONE");

    const tinyusb_sources = [_][]const u8{
        "tinyusb/src/tusb.c",
        "tinyusb/src/common/tusb_fifo.c",
        "tinyusb/src/device/usbd.c",
        "tinyusb/src/device/usbd_control.c",
        "tinyusb/src/class/cdc/cdc_device.c",

        // Teensy 4.1 specific files
        "tinyusb/src/hw/bsp/imxrt/boards/family.c",
        // "tinyusb/src/hw/bsp/imxrt/boards/teensy_41/",
    };

    // Add each TinyUSB source file
    for (tinyusb_sources) |src| {
        exe_mod.addCSourceFile(.{
            .file = .{ .path = src },
            .flags = &[_][]const u8{ "-std=c99", "-Wno-error" },
        });
    }
}
