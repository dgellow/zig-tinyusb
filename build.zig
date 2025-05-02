const std = @import("std");

pub fn build(b: *std.Build) void {
    // const target = b.standardTargetOptions(.{});
    const query = std.Target.Query{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m7 },
        .os_tag = .freestanding,
    };
    const target = b.resolveTargetQuery(query);
    const optimize = b.standardOptimizeOption(.{});

    // Fetch TinyUSB deps
    const deps_step = b.step("get-deps", "Download TinyUSB dependencies");

    const deps_cmd = b.addSystemCommand(&[_][]const u8{ "python", "./tinyusb/tools/get_deps.py", "imxrt" });
    deps_step.dependOn(&deps_cmd.step);

    // Test program
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/_startup.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "zig_tinyusb",
        .root_module = exe_mod,
    });

    exe.linkLibC();
    exe.setLinkerScript(b.path("gnu/teensy4.1.ld"));
    exe.entry = .{ .symbol_name = "__ivt_start" };

    // exe.linkSystemLibrary("c");
    // exe_mod.linkSystemLibrary("c", .{});
    // exe_mod.linkSystemLibrary("gcc", .{});
    // exe_mod.linkSystemLibrary("nosys", .{});

    exe_mod.addCMacro("CPU_MIMXRT1062DVJ6B", "1");
    exe_mod.addCMacro("FSL_FEATURE_GPIO_HAS_NO_INDEP_OUTPUT_CONTROL", "1");

    exe_mod.addIncludePath(b.path("include"));
    exe_mod.addIncludePath(b.path("tinyusb/src"));
    exe_mod.addIncludePath(b.path("tinyusb/hw"));
    exe_mod.addIncludePath(b.path("tinyusb/hw/bsp"));
    exe_mod.addIncludePath(b.path("tinyusb/hw/mcu/nxp/mcux-sdk/drivers/common"));
    exe_mod.addIncludePath(b.path("tinyusb/hw/mcu/nxp/mcux-sdk/devices/MIMXRT1062"));
    exe_mod.addIncludePath(b.path("tinyusb/hw/mcu/nxp/mcux-sdk/devices/MIMXRT1062/drivers"));
    exe_mod.addIncludePath(b.path("tinyusb/hw/mcu/nxp/mcux-sdk/devices/MIMXRT1062/utilities"));
    exe_mod.addIncludePath(b.path("tinyusb/hw/mcu/nxp/mcux-sdk/devices/MIMXRT1062/template"));
    exe_mod.addIncludePath(b.path("tinyusb/lib/CMSIS_5/CMSIS/Core/Include"));
    exe_mod.addIncludePath(b.path("tinyusb/hw/bsp/imxrt/boards/teensy_41"));
    exe_mod.addIncludePath(b.path("tinyusb/hw/bsp/imxrt/boards/teensy_41/board"));
    exe_mod.addIncludePath(b.path("tinyusb/hw/mcu/nxp/mcux-sdk/drivers/igpio"));
    exe_mod.addIncludePath(b.path("tinyusb/hw/mcu/nxp/mcux-sdk/drivers/lpuart"));
    exe_mod.addIncludePath(b.path("tinyusb/hw/mcu/nxp/mcux-sdk/drivers/ocotp"));
    exe_mod.addIncludePath(b.path("tinyusb/hw/mcu/nxp/mcux-sdk/drivers/port"));

    // const arm_gcc_path = b.option(
    //     []const u8,
    //     "arm-gcc-path",
    //     "Path to ARM GCC toolchain",
    // ) orelse "C:\\Program Files (x86)\\Arm GNU Toolchain arm-none-eabi\\14.2 rel1";

    // exe_mod.addIncludePath(b.path(b.fmt("{s}\\arm-none-eabi\\include", .{arm_gcc_path})));
    // exe_mod.addIncludePath(b.path(b.fmt("{s}\\lib\\gcc\\arm-none-eabi\\14.2.1\\include", .{arm_gcc_path})));
    // exe_mod.addIncludePath(b.path(b.fmt("{s}\\lib\\gcc\\arm-none-eabi\\14.2.1\\include-fixed", .{arm_gcc_path})));

    // exe.setLibCFile(b.path(b.fmt("{s}\\arm-none-eabi\\lib\\libc.a", .{arm_gcc_path})));

    const tinyusb_sources = [_][]const u8{
        // TinyUSB core
        "tinyusb/src/tusb.c",
        "tinyusb/src/common/tusb_fifo.c",

        // device mode
        "tinyusb/src/device/usbd.c",
        "tinyusb/src/device/usbd_control.c",
        "tinyusb/src/class/cdc/cdc_device.c",

        // board support
        // "tinyusb/hw/bsp/board.c",
        "tinyusb/hw/bsp/imxrt/family.c",

        // Teensy 4.1 specific files
        "tinyusb/hw/mcu/nxp/mcux-sdk/devices/MIMXRT1062/system_MIMXRT1062.c",
        "tinyusb/hw/mcu/nxp/mcux-sdk/devices/MIMXRT1062/drivers/fsl_clock.c",
        "tinyusb/hw/mcu/nxp/mcux-sdk/drivers/igpio/fsl_gpio.c",
        "tinyusb/hw/mcu/nxp/mcux-sdk/drivers/lpuart/fsl_lpuart.c",
        "tinyusb/hw/mcu/nxp/mcux-sdk/drivers/ocotp/fsl_ocotp.c",
        "tinyusb/src/portable/chipidea/ci_hs/dcd_ci_hs.c",
        "tinyusb/hw/bsp/imxrt/boards/teensy_41/board/pin_mux.c",
        "tinyusb/hw/bsp/imxrt/boards/teensy_41/board/clock_config.c",
    };
    for (tinyusb_sources) |src| {
        exe_mod.addCSourceFile(.{
            .file = b.path(src),
            .flags = &[_][]const u8{ "-std=c99", "-Wno-error" },
        });
    }

    exe_mod.addCSourceFile(.{
        .file = b.path("src/assert.c"),
        .flags = &[_][]const u8{ "-std=c99", "-Wno-error" },
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run test program");
    run_step.dependOn(&run_cmd.step);
}
