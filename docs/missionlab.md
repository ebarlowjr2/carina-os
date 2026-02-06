# CARINA MissionLab

Embedded, Robotics, and Device Control environment for CARINA OS.

## Overview

MissionLab provides a first-class environment for:

- Microcontrollers (Arduino, ESP32, STM32, Teensy, Raspberry Pi Pico)
- Robotics development (ROS2 tooling)
- Sensors and serial devices
- Field hardware (USB, GPIO, UART)

The goal is simple: **Plug in a board, CARINA recognizes it, tooling works, no fighting permissions.**

## Design Principles

MissionLab follows these non-negotiable principles:

- **Plug-and-work device experience** - No manual permission setup
- **No root required** for common hardware workflows
- **Safe by default** - Explicit escalation only
- **Headless-first** - GUI optional
- **Laptop/Toughbook realistic** - Works in the field
- **No vendor lock-in** - Open toolchains only

## Profiles

### missionlab-embedded

CLI-first toolchain for embedded development.

**Packages installed:**
- arduino-cli - Arduino command-line interface
- PlatformIO - Universal embedded development platform
- avrdude - AVR programmer
- dfu-util - DFU mode programmer
- openocd - Open On-Chip Debugger
- minicom, screen, picocom - Serial terminal tools
- Build tools (cmake, ninja-build)

**Apply with:**
```bash
sudo carina profile apply missionlab-embedded
```

### missionlab-robotics

Minimal ROS2 development tooling (not full desktop).

**Packages installed:**
- ros-dev-tools - ROS2 development utilities
- colcon - Build tool for ROS2
- python3-rosdep - ROS dependency manager
- python3-vcstool - Version control system tool

**Apply with:**
```bash
sudo carina profile apply missionlab-robotics
```

**Note:** ROS2 is NOT auto-sourced. See `/etc/carina/ros2-setup-hint.sh` for setup instructions.

## Device Access

MissionLab uses udev rules to provide non-root access to common devices. Users are added to `dialout` and `plugdev` groups during profile installation.

### Supported Serial Adapters
- FTDI FT232, FT2232, FT232H
- Silicon Labs CP210x
- Prolific PL2303
- WCH CH340/CH341

### Supported Microcontroller Boards
- Arduino Uno, Mega, Leonardo, Due, Micro
- ESP32, ESP8266, ESP32-S2, ESP32-S3
- STM32 (various, including Nucleo boards)
- Raspberry Pi Pico, Pico W
- Teensy 3.x, 4.x

### Supported Debuggers/Programmers
- ST-Link V2, V2-1, V3
- Segger J-Link
- Black Magic Probe
- CMSIS-DAP compatible
- USBasp, AVR ISP

## CLI Commands

### Check Status

```bash
carina missionlab status
```

Reports:
- Toolchain availability (arduino-cli, PlatformIO, avrdude, openocd, minicom)
- User group membership (dialout, plugdev)
- Serial port access permissions
- udev rules installation status

Example output:
```
CARINA MissionLab Status
========================

Toolchain:
[PASS] arduino-cli: arduino-cli Version: 0.35.0
[PASS] PlatformIO: Available
[PASS] avrdude: Available
[PASS] OpenOCD: Available
[PASS] minicom: Available

User Groups:
[PASS] ubuntu is in dialout group (serial access)
[PASS] ubuntu is in plugdev group (USB access)

Serial Access:
[PASS] /dev/ttyUSB0: Accessible

udev Rules:
[PASS] Serial rules installed
[PASS] USB rules installed
```

### Detect Devices

```bash
carina missionlab devices
```

Scans and reports:
- Serial ports (/dev/ttyUSB*, /dev/ttyACM*)
- Known USB development devices
- Video capture devices
- GPIO/I2C/SPI interfaces

Example output:
```
CARINA MissionLab - Device Detection
=====================================

Serial Ports
------------
  /dev/ttyUSB0 Silicon Labs (CP210x USB-Serial)
  /dev/ttyACM0 Arduino (Arduino Uno)

USB Devices (Development)
-------------------------
  2341:0043 Arduino Uno
  10c4:ea60 CP210x USB-Serial

Video Devices
-------------
  No video devices detected

GPIO/Hardware Interfaces
------------------------
  No GPIO/hardware interfaces detected

Scan complete.
```

## Security Model

MissionLab follows CARINA's mission-grade security principles:

- **No permanent root access required** - All device access via groups
- **Uses groups + udev only** - No chmod 777 patterns
- **Explicit permission model** - Users must be in correct groups
- **No system-wide permission loosening** - Only specific devices affected

### Group Membership

Users need to be in these groups for device access:

- `dialout` - Serial port access (/dev/ttyUSB*, /dev/ttyACM*)
- `plugdev` - USB device access (programmers, debuggers)

The profile config scripts automatically add users to these groups.

### udev Rules

Two rule files are installed:

- `/etc/udev/rules.d/99-carina-serial.rules` - Serial device permissions
- `/etc/udev/rules.d/99-carina-usb.rules` - USB device permissions

These rules set appropriate permissions for known development devices without affecting system security.

## After Installation

After applying a MissionLab profile:

1. **Log out and back in** for group changes to take effect
2. Run `carina missionlab status` to verify setup
3. Connect your device and run `carina missionlab devices`
4. Test with your toolchain:
   ```bash
   arduino-cli board list
   # or
   platformio device list
   ```

## Troubleshooting

### "Permission denied" on serial port

1. Check group membership: `groups`
2. If not in `dialout`, run: `sudo usermod -aG dialout $USER`
3. Log out and back in
4. Verify with: `carina missionlab status`

### Device not detected

1. Check if device is connected: `lsusb`
2. Check if serial port exists: `ls -la /dev/ttyUSB* /dev/ttyACM*`
3. Check udev rules: `ls /etc/udev/rules.d/99-carina-*`
4. Reload udev: `sudo udevadm control --reload-rules && sudo udevadm trigger`

### arduino-cli not finding boards

1. Update core index: `arduino-cli core update-index`
2. Install board support: `arduino-cli core install arduino:avr`
3. List boards: `arduino-cli board list`

## What MissionLab Does NOT Include (Yet)

These features are planned for future sprints:

- Full ROS2 desktop installation
- GUI device manager
- AI control integration
- Firmware flashing automation
- Hardware simulation
- CAN bus support
- GPIO direct access utilities
