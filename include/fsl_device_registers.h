#ifndef FSL_DEVICE_REGISTERS_H
#define FSL_DEVICE_REGISTERS_H

// Minimal register definitions for IMXRT1062
#define IMXRT1062_SERIES

// Basic memory-mapped registers
#define IMXRT_USBPHY1_BASE 0x400D9000
#define IMXRT_USBPHY2_BASE 0x400DA000
#define IMXRT_USB1_BASE 0x402E0000
#define IMXRT_USB2_BASE 0x402E0200

// Other essential definitions needed by TinyUSB
typedef unsigned int uint32_t;
typedef unsigned short uint16_t;
typedef unsigned char uint8_t;

#endif // FSL_DEVICE_REGISTERS_H