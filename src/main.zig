const std = @import("std");

const c = @cImport({
    @cInclude("bsp/board_api.h");
    // @cInclude("fsl_device_registers.h");
    // @cInclude("bsp/imxrt/boards/teensy_41/board.h");
    @cInclude("tusb.h");
});

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
        0x03, 0x80, // PID (0x8003 - arbitrary)
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

pub extern "c" fn tusb_rhport_init(rhport: u8, init_params: ?*const c.tusb_rhport_init_t) bool;

pub fn tusbInit(params: ?*const c.tusb_rhport_init_t) bool {
    return tusb_rhport_init(0, params);
}

pub export fn main() void {
    hardwareInit();

    // Initialize TinyUSB device
    _ = tusbInit(null);

    // Main loop
    while (true) {
        // USB device task - handle USB events
        // c.tud_
        // c.tud_task();

        // Check if we have data
        // if (c.tud_cdc_available() > 0) {
        //     // Read data
        //     var buf: [64]u8 = undefined;
        //     const count = c.tud_cdc_read(&buf, buf.len);

        //     // Echo back
        //     _ = c.tud_cdc_write(&buf, count);
        //     _ = c.tud_cdc_write_flush();
        // }
    }
}

fn hardwareInit() void {
    // Initialize clocks, pins, etc. for Teensy 4.1
    // This would be your hardware-specific code
}
