const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "zig_tinyusb",
        .root_module = exe_mod,
    });
    exe.linkLibC();

    exe_mod.addIncludePath(b.path("include"));
    exe_mod.addIncludePath(b.path("tinyusb/src"));
    exe_mod.addIncludePath(b.path("tinyusb/hw"));
    exe_mod.addIncludePath(b.path("tinyusb/hw/bsp"));

    const tinyusb_sources = [_][]const u8{
        // "tinyusb/hw/bsp/board.c",
        "tinyusb/src/tusb.c",
        "tinyusb/src/device/usbd.c",
        "tinyusb/src/common/tusb_fifo.c",
        // "tinyusb/src/device/usbd_control.c",
        "tinyusb/src/class/cdc/cdc_device.c",

        // Teensy 4.1 specific files
        "tinyusb/src/portable/chipidea/ci_hs/dcd_ci_hs.c",
        // "tinyusb/hw/bsp/imxrt/family.c",
        // "tinyusb/src/hw/bsp/imxrt/boards/teensy_41/",
    };

    // Add each TinyUSB source file
    for (tinyusb_sources) |src| {
        exe_mod.addCSourceFile(.{
            .file = b.path(src),
            .flags = &[_][]const u8{ "-std=c99", "-Wno-error" },
        });
    }

    // exe_mod.addCSourceFile(.{
    //     .file = b.path("src/tusb_wrapper.c"),
    //     .flags = &[_][]const u8{ "-std=c99", "-Wno-error" },
    // });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run test program");
    run_step.dependOn(&run_cmd.step);
}
