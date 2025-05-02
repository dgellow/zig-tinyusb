const std = @import("std");
const chip = @import("imxrt1062.zig");
const peripherals = chip.devices.MIMXRT1062.peripherals;

const c = @cImport({
    @cInclude("tusb.h");
    @cInclude("bsp/board_api.h");
});

pub extern "c" fn tusb_rhport_init(rhport: u8, init_params: ?*const c.tusb_rhport_init_t) bool;

pub fn tusbInit(params: ?*const c.tusb_rhport_init_t) bool {
    return tusb_rhport_init(0, params);
}

// LED pin definition for Teensy 4.1 (pin 13)
const LED_PIN = 13;

// Configure GPIO pin for LED
fn configurePin() void {
    // Configure pin mux for GPIO_B0_03 (pin 13)
    peripherals.IOMUXC.SW_MUX_CTL_PAD_GPIO_B0_03.modify(.{
        .MUX_MODE = .ALT5,
    });

    // Configure GPIO1 pin 3 as output (B0_03 maps to GPIO1_IO03)
    peripherals.GPIO1.GDIR.modify(.{
        .GDIR = peripherals.GPIO1.GDIR.read().GDIR | (1 << 3),
    });
}

// Toggle LED
fn toggleLed() void {
    const current = peripherals.GPIO1.DR.read().DR;
    peripherals.GPIO1.DR.modify(.{
        .DR = current ^ (1 << 3),
    });
}

fn busyWait(count: u32) void {
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        asm volatile ("" ::: "memory");
    }
}

// Complete Teensy 4.1 USB initialization
fn teensy41UsbInit() void {
    // First power up and configure the PLL
    peripherals.CCM_ANALOG.PLL_USB1.raw = 0; // Start fresh
    // Set to enable, power and EN_USB_CLKS
    peripherals.CCM_ANALOG.PLL_USB1.raw = 0x01000000 | 0x02000000 | 0x00000003;

    // Wait longer for PLL lock - Teensy needs this
    var timeout: u32 = 0;
    while ((peripherals.CCM_ANALOG.PLL_USB1.raw & 0x80000000) == 0) {
        timeout += 1;
        if (timeout > 1000000) break; // Safety timeout
    }

    // Set the USB clock gate register
    peripherals.CCM.CCGR6.raw = (peripherals.CCM.CCGR6.raw & ~@as(u32, 0x3)) | 0x3; // Always enable

    // 2. Configure USB PHY
    // Reset and initialize USB PHY
    peripherals.USBPHY1.CTRL.raw = 0;
    peripherals.USBPHY1.CTRL_SET.raw = 0x40000000; // SFTRST
    busyWait(100000);
    peripherals.USBPHY1.CTRL_CLR.raw = 0x40000000; // SFTRST
    peripherals.USBPHY1.CTRL_CLR.raw = 0x80000000; // CLKGATE

    // Critical: Enable transmitter
    peripherals.USBPHY1.TX.raw = 0x10000000; // Clear all but D_CAL=1

    // Power up the PHY
    peripherals.USBPHY1.PWD.raw = 0;

    // 3. Configure USB Controller
    peripherals.USB1.USBCMD.raw = 0x00080000; // Reset controller
    while ((peripherals.USB1.USBCMD.raw & 0x00080000) != 0) {} // Wait for reset to complete

    // Set to device mode
    peripherals.USB1.USBMODE.raw = 0x2; // Device mode

    // Required setup for Teensy 4.1
    peripherals.USB1.OTGSC.raw = 0x7F007000; // Clear all interrupt enable bits

    // Setup USB controller registers
    peripherals.USB1.USBINTR.raw = 0x140; // Enable transfer complete and USB reset interrupts

    // Configure USB endpoints
    peripherals.USB1.ENDPTFLUSH.raw = 0xFFFFFFFF; // Flush all endpoints
    busyWait(100000);
    peripherals.USB1.ENDPTCOMPLETE.raw = 0xFFFFFFFF; // Clear all complete flags

    // 4. Start the USB controller
    peripherals.USB1.USBCMD.raw = 0x1; // Start USB controller
}

// Initialize the hardware
fn hardwareInit() void {
    // Configure LED pin
    configurePin();

    // // Start-up LED indicator pattern
    // for (0..3) |_| {
    //     toggleLed();
    //     busyWait(100000);
    //     toggleLed();
    //     busyWait(100000);
    // }

    // Initialize USB
    teensy41UsbInit();

    // Another visual indicator after USB init
    // toggleLed();
    // busyWait(500000);
    // toggleLed();

    // Initialize board API (clocks, etc.)
    _ = c.board_init();
}

pub export fn main() void {
    hardwareInit();

    while (true) {
        // Unique pattern: 2 short, 1 long
        toggleLed();
        busyWait(200000);
        toggleLed();
        busyWait(200000);

        toggleLed();
        busyWait(200000);
        toggleLed();
        busyWait(200000);

        toggleLed();
        busyWait(1000000);
        toggleLed();

        busyWait(2000000); // 2 second pause
    }

    // Initialize TinyUSB stack
    const usb_init_result = tusbInit(null);

    // Show initialization result through LED pattern
    if (usb_init_result) {
        // Success pattern - one long blink
        toggleLed();
        busyWait(1000000);
        toggleLed();
    } else {
        // Failure pattern - five rapid blinks
        for (0..5) |_| {
            toggleLed();
            busyWait(100000);
            toggleLed();
            busyWait(100000);
        }
    }

    var led_timer: u32 = 0;

    // Main loop
    while (true) {
        // TinyUSB device task
        c.tud_task();

        // Heartbeat LED
        const current_time = c.board_millis();
        if (current_time - led_timer > 1000) { // Slower 1 second blink
            led_timer = current_time;
            toggleLed();
        }

        // CDC processing
        cdc_task();
    }
}

fn cdc_task() void {
    const available = c.tud_cdc_available();

    if (available > 0) {
        // Data received - different pattern
        for (0..2) |_| {
            toggleLed();
            busyWait(50_000);
            toggleLed();
            busyWait(50_000);
        }

        // Buffer for incoming data
        var buf: [64]u8 = undefined;
        const count = c.tud_cdc_read(&buf, buf.len);

        // Echo back the data we received
        if (count > 0) {
            _ = c.tud_cdc_write(&buf, count);
            _ = c.tud_cdc_write_flush();
        }
    }
}

export fn tusb_time_millis_api() u32 {
    return c.board_millis();
}

export fn tud_descriptor_device_cb() [*]const u8 {
    const desc_device = [_]u8{
        0x12, // Length
        0x01, // Descriptor type (Device)
        0x00, 0x02, // USB Version 2.0 (Little Endian)
        0x02, // Class (CDC)
        0x00, // Subclass
        0x00, // Protocol
        64, // Max packet size
        0xF1, 0x16, // VID (0x16F1 - Teensy)
        0x72, 0x04, // PID
        0x00, 0x01, // Device version
        0x01, // Manufacturer string index
        0x02, // Product string index
        0x03, // Serial number string index
        0x01, // Number of configurations
    };
    return &desc_device;
}

// USB Configuration Descriptor
export fn tud_descriptor_configuration_cb(_: u8) [*]const u8 {
    // CDC configuration descriptor
    const desc_configuration = [_]u8{
        // Configuration descriptor
        9, // Length
        2, // Type
        9 + 9 + 5 + 5 + 4 + 5 + 7 + 9 + 7 + 7, 0, // Total length
        2, // Number of interfaces
        1, // Configuration number
        0, // Configuration string index
        0x80, // Attributes (bus powered)
        50, // Max power (100mA)

        // Interface descriptor (CDC Control)
        9, // Length
        4, // Type
        0, // Interface number
        0, // Alternate setting
        1, // Number of endpoints
        0x02, // Class (CDC)
        0x02, // Subclass (Abstract Control Model)
        0x01, // Protocol (AT Commands)
        0, // String index

        // CDC Header
        5, // Length
        0x24, // Type (CS_INTERFACE)
        0x00, // Subtype (Header)
        0x10, 0x01, // CDC Version 1.10

        // CDC Call Management
        5, // Length
        0x24, // Type
        0x01, // Subtype (Call Management)
        0x00, // Capabilities
        1, // Data interface

        // CDC ACM (Abstract Control Management)
        4, // Length
        0x24, // Type
        0x02, // Subtype
        0x02, // Capabilities

        // CDC Union
        5, // Length
        0x24, // Type
        0x06, // Subtype
        0, // Control interface
        1, // Data interface

        // CDC Endpoint (Notification)
        7, // Length
        5, // Type (Endpoint)
        0x81, // Address (EP1 IN)
        0x03, // Attributes (Interrupt)
        8, 0, // Size
        16, // Interval (16ms)

        // Interface descriptor (CDC Data)
        9, // Length
        4, // Type
        1, // Interface number
        0, // Alternate setting
        2, // Number of endpoints
        0x0A, // Class (CDC Data)
        0x00, // Subclass
        0x00, // Protocol
        0, // String index

        // CDC Data Endpoint (OUT)
        7, // Length
        5, // Type
        0x02, // Address (EP2 OUT)
        0x02, // Attributes (Bulk)
        64, 0, // Size
        0, // Interval

        // CDC Data Endpoint (IN)
        7, // Length
        5, // Type
        0x82, // Address (EP2 IN)
        0x02, // Attributes (Bulk)
        64, 0, // Size
        0, // Interval
    };

    return &desc_configuration;
}

// USB String Descriptors
export fn tud_descriptor_string_cb(index: u8, _: u16) [*]const u8 {
    const desc_string0 = [_]u8{
        4, // Length
        3, // Type (String)
        0x09, 0x04, // Supported LangID (English)
    };

    const desc_manufacturer = [_]u8{
        18, // Length
        3, // Type
        'T',
        0,
        'a',
        0,
        'b',
        0,
        'u',
        0,
        'l',
        0,
        'a',
        0,
        'r',
        0,
        'F',
        0,
    };

    const desc_product = [_]u8{
        18, // Length
        3, // Type
        'F',
        0,
        'o',
        0,
        'r',
        0,
        't',
        0,
        'h',
        0,
        'U',
        0,
        'S',
        0,
        'B',
        0,
    };

    const desc_serial = [_]u8{
        12, // Length
        3, // Type
        '1',
        0,
        '2',
        0,
        '3',
        0,
        '4',
        0,
        '5',
        0,
    };

    switch (index) {
        0 => return &desc_string0,
        1 => return &desc_manufacturer,
        2 => return &desc_product,
        3 => return &desc_serial,
        else => return &desc_string0,
    }
}

// pub export fn main() void {
//     hardwareInit();

//     // Initialize TinyUSB device
//     _ = tusbInit(null);

//     // Main loop
//     while (true) {
//         // USB device task - handle USB events
//         // c.tud_
//         // c.tud_task();

//         // Check if we have data
//         // if (c.tud_cdc_available() > 0) {
//         //     // Read data
//         //     var buf: [64]u8 = undefined;
//         //     const count = c.tud_cdc_read(&buf, buf.len);

//         //     // Echo back
//         //     _ = c.tud_cdc_write(&buf, count);
//         //     _ = c.tud_cdc_write_flush();
//         // }
//     }
// }

// fn hardwareInit() void {
//     // Initialize clocks, pins, etc. for Teensy 4.1
//     // This would be your hardware-specific code
// }
