# Karotz Hardware Architecture

## Overview

This document describes the hardware architecture of the Karotz robot and the firmware requirements for building a custom open-source operating system.

## Hardware Specifications

### Main Processor
- **Chip**: ARM926EJ-S
- **Architecture**: ARMv5TE
- **Clock Speed**: ~200 MHz
- **Manufacturer**: Marvel (originally developed by Violet/Mindscape)

### Memory
- **RAM**: 64 MB (SDRAM)
- **Flash Storage**: 256 MB NAND
- **Partition Layout**:
  ```
  /dev/mtd0: U-Boot bootloader (1 MB)
  /dev/mtd1: Kernel (zImage) - 4 MB
  /dev/mtd2: Root filesystem - ~251 MB
  ```

### Connectivity
- **WiFi**: RTL8187L (802.11b/g) with USB interface
- **USB**: 1x USB 2.0 port (for firmware updates and accessories)
- **Audio**: 3.5mm audio jack, built-in speaker, microphone
- **Buttons**: 1x main button (on back), 2x belly buttons, 1x ear button

### Sensors & I/O
- **LEDs**: RGB LED in ears (individually controllable)
- **Camera**: VGA camera (640x480)
- **Microphone**: Built-in
- **RFID**: Built-in RFID reader
- **Accelerometer**: 3-axis

### Power
- **Battery**: 3.7V 1200mAh Lithium-ion
- **Charging**: USB-powered
- **Power consumption**: ~500mA active, ~50mA standby

## Flash Memory Layout

### MTD Partitions
```
Name           Size       Offset     Description
----           ----       ------     -----------
U-Boot        1024KB     0x00000000  Bootloader
Kernel        4096KB     0x00100000  Linux kernel (zImage)
RootFS        251MB      0x00500000  Root filesystem (YAFFS2)
```

### Boot Process
1. **Power-on**: U-Boot loads from MTD0
2. **Kernel load**: U-Boot loads zImage from MTD1
3. **RootFS mount**: Kernel mounts YAFFS2 filesystem from MTD2
4. **Init**: /sbin/init or /etc/init.d/rcS starts system services

## Firmware Components

### Bootloader (U-Boot)
- **Location**: /dev/mtd0
- **Size**: 1 MB
- **Function**: Loads kernel from NAND flash
- **Customization**: Not typically modified in firmware updates

### Kernel (zImage)
- **Location**: /dev/mtd1
- **Size**: ~2-3 MB (compressed)
- **Format**: zImage (compressed Linux kernel)
- **Requirements**:
  - ARMv5TE support
  - NAND flash (MTD) support
  - YAFFS2 filesystem support
  - USB support (EHCI/OHCI)
  - Audio support (ALSA/OSS)
  - WiFi support (RTL8187L)
  - LED GPIO support

### Root Filesystem
- **Location**: /dev/mtd2
- **Format**: YAFFS2 (compressed)
- **Size**: ~15-20 MB (compressed), expands to ~50-100 MB on device
- **Contents**:
  - BusyBox utilities
  - System initialization scripts
  - Network configuration
  - Audio playback (madplay)
  - Web server (lighttpd)
  - CGI scripts
  - Karotz-specific utilities

## Open-Source Component Sources

### Kernel
- **Source**: Linux kernel 5.4.x (LTS)
- **Repository**: https://cdn.kernel.org/pub/linux/kernel/v5.x/
- **Customization**: Karotz-specific device tree and configuration
- **Patches**: Minimal - mostly configuration

### Toolchain
- **Compiler**: GCC 10.3.0 (Linaro)
- **Repository**: https://releases.linaro.org/components/toolchain/binaries/
- **Target**: armv5te-linaro-musleabi
- **Binutils**: 2.36.1
- **libc**: musl (lightweight alternative to glibc)

### Root Filesystem Base
- **Distribution**: OpenWrt 21.02.x (LTS)
- **Repository**: https://downloads.openwrt.org/releases/
- **Target**: arm_xscale_be
- **Packages**: Minimal + Karotz-specific additions

### YAFFS2 Tools
- **Source**: YAFFS2 v5.1.6
- **Repository**: https://github.com/yaffs/yaffs2
- **Tools**: nandwrite, flash_eraseall, mkyaffs2image
- **License**: GPL-2.0

### Build System
- **Buildroot**: Alternative to OpenWrt (simpler, more customizable)
- **Repository**: https://buildroot.org/
- **Configuration**: Custom for Karotz hardware

## Device Tree (Simplified)

```c
/ {
    model = "Karotz (Nabaztag)";
    compatible = "violet,karotz";
    
    cpus {
        cpu@0 {
            compatible = "arm,arm926ej-s";
        };
    };
    
    memory {
        reg = <0xc0000000 0x04000000>; // 64MB RAM
    };
    
    nand {
        compatible = "marvell,orion-nand";
        reg = <0xff000000 0x10000>;
        #address-cells = <1>;
        #size-cells = <0>;
        
        partition@0 {
            label = "u-boot";
            reg = <0x000000 0x100000>; // 1MB
            read-only;
        };
        
        partition@100000 {
            label = "kernel";
            reg = <0x100000 0x400000>; // 4MB
        };
        
        partition@500000 {
            label = "rootfs";
            reg = <0x500000 0xfa00000>; // ~251MB
        };
    };
    
    gpio {
        leds {
            compatible = "gpio-leds";
            
            left-led {
                label = "karotz:left";
                gpios = <&gpio 0 1 0>;
            };
            
            right-led {
                label = "karotz:right";
                gpios = <&gpio 0 2 0>;
            };
        };
    };
    
    usb {
        compatible = "marvell,orion-usb";
        status = "okay";
    };
    
    wifi {
        compatible = "rtl8187";
        status = "okay";
    };
};
```

## GPIO Mapping

| Function       | GPIO Pin | Direction | Description                     |
|---------------|----------|-----------|---------------------------------|
| Left LED Red  | GPIO 0   | Output    | Left ear LED - Red             |
| Left LED Green| GPIO 1   | Output    | Left ear LED - Green           |
| Left LED Blue | GPIO 2   | Output    | Left ear LED - Blue            |
| Right LED Red | GPIO 3   | Output    | Right ear LED - Red            |
| Right LED Grn | GPIO 4   | Output    | Right ear LED - Green          |
| Right LED Blu | GPIO 5   | Output    | Right ear LED - Blue           |
| Button Back   | GPIO 6   | Input     | Back button (active low)       |
| Button Belly1 | GPIO 7   | Input     | Left belly button              |
| Button Belly2 | GPIO 8   | Input     | Right belly button             |
| Button Ear    | GPIO 9   | Input     | Ear button                     |
| WiFi Enable   | GPIO 10  | Output    | WiFi module enable             |
| Speaker Mute  | GPIO 11  | Output    | Speaker mute control           |

## Performance Considerations

### Memory Constraints
- Total RAM: 64 MB
- Kernel: ~8-12 MB
- RootFS in RAM: ~20-30 MB (uncompressed)
- Available for applications: ~30-40 MB

### CPU Constraints
- ARM926EJ-S @ 200 MHz
- No FPU (soft-float only)
- No MMU in some modes (but Linux requires MMU)

### Storage Constraints
- NAND flash: 256 MB total
- Kernel partition: 4 MB (must be < 4 MB)
- RootFS partition: ~251 MB
- Recommendation: Keep rootfs.img.gz < 20 MB compressed

## Boot Process Details

1. **Power-on Reset**
   - Hardware reset circuit activates
   - ARM processor starts at address 0x00000000
   - Boot ROM takes control

2. **Boot ROM**
   - Initializes minimal hardware (clocks, RAM controller)
   - Loads first 16KB from NAND flash to internal SRAM
   - Jumps to loaded code (U-Boot)

3. **U-Boot**
   - Full hardware initialization
   - NAND flash detection
   - Environment variable processing
   - Kernel loading from MTD1 (0x00100000)
   - Device tree passing (if configured)
   - Kernel execution at 0xC0008000

4. **Linux Kernel**
   - Early boot (uncompress, relocate)
   - Architecture-specific initialization
   - MTD partition detection
   - YAFFS2 filesystem mounting from MTD2
   - Root device setup (/dev/root or /dev/mtdblock2)
   - Init process starting (/sbin/init)

5. **Userspace**
   - /etc/init.d/rcS execution
   - Device node creation
   - Service startup
   - Application launch

## Firmware Update Process

### Original miniil Method
1. Insert USB with `autorun` script
2. Hold back button while powering on
3. U-Boot detects button press
4. Boot from USB instead of NAND
5. `autorun` script executes:
   - Verify MD5 checksums
   - Flash zImage to MTD1
   - Flash rootfs to MTD2
   - Clean YAFFS
   - Install additional packages
6. Reboot to new firmware

### Open-Source Method (This Project)
Same process, but:
- All components built from source
- SHA256 checksums instead of MD5
- No external binary downloads
- Full verification at each step

## Hardware Accessories

### Supported USB Devices
- WiFi adapters (RTL8187L, RTL8188EU, etc.)
- Audio devices (USB sound cards)
- Storage devices (USB sticks, HDDs)
- RFID readers (ACR122U, etc.)
- Bluetooth adapters (CSR 4.0)
- Cameras (UVC-compatible)

### Known Limitations
- No HDMI output (hardware limitation)
- No GPU acceleration (no GPU)
- Limited to 10/100 Ethernet (USB ethernet adapters)
- No SATA support (USB only)

## Development Board Comparison

For those who want to develop without Karotz hardware:

| Feature           | Karotz | Raspberry Pi Zero | BeagleBone Black | QEMU ARM |
|------------------|--------|-------------------|------------------|----------|
| CPU              | ARM926 | ARM1176           | AM335x           | Emulated |
| RAM              | 64MB   | 512MB             | 512MB            | Config   |
| Storage          | 256MB  | SD Card           | eMMC/SD          | Disk     |
| WiFi             | Yes    | Add-on            | Add-on           | No       |
| USB              | 1x     | 1x                | 1x               | Yes      |
| Audio            | Yes    | Add-on            | Yes              | No       |
| GPIO             | ~16    | 26                | 65+              | Emulated |
| Price            | N/A    | $5                | $55              | Free     |
| Boot time        | ~15s   | ~5s               | ~5s              | ~5s      |

## References

- [Linux Kernel Documentation](https://www.kernel.org/doc/html/latest/)
- [OpenWrt Documentation](https://openwrt.org/docs/)
- [YAFFS2 Documentation](https://github.com/yaffs/yaffs2)
- [ARM Architecture Reference](https://developer.arm.com/documentation/)
- [U-Boot Documentation](https://www.denx.de/wiki/U-Boot/)

## Appendix: U-Boot Environment Variables

```
bootcmd=run bootcmd_nand
bootdelay=3
baudrate=115200
ethaddr=00:11:22:33:44:55
ipaddr=192.168.1.1
serverip=192.168.1.100
netmask=255.255.255.0

# NAND boot
bootcmd_nand=nand read 0xc0008000 0x100000 0x400000; bootm 0xc0008000

# USB boot (for firmware update)
bootcmd_usb=usb start; fatload usb 0:1 0xc0008000 autorun; bootm 0xc0008000

# Recovery mode detection
recover=if test ${recover} -eq 1; then run bootcmd_usb; fi
```
