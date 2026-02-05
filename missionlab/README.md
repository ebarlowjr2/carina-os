# CARINA MissionLab

Embedded, Robotics, and Device Control environment for CARINA OS.

## Overview

MissionLab provides a first-class environment for:

- Microcontrollers (Arduino, ESP32, STM32, Teensy, Raspberry Pi Pico)
- Robotics development (ROS2 tooling)
- Sensors and serial devices
- Field hardware (USB, GPIO, UART)

The goal is simple: **Plug in a board, CARINA recognizes it, tooling works, no fighting permissions.**

## Profiles

### missionlab-embedded

CLI-first toolchain for embedded development:

- arduino-cli
- PlatformIO
- avrdude, dfu-util, openocd
- minicom, screen, picocom
- Build tools (cmake, ninja-build)

Apply with:
```bash
sudo carina profile apply missionlab-embedded
```

### missionlab-robotics

Minimal ROS2 development tooling (not full desktop):

- ros-dev-tools
- colcon
- python3-rosdep, python3-vcstool

Apply with:
```bash
sudo carina profile apply missionlab-robotics
```

## Device Access

MissionLab uses udev rules to provide non-root access to common devices:

- USB-to-serial adapters (FTDI, CP210x, CH340, Prolific)
- Arduino boards (Uno, Mega, Leonardo, Due, etc.)
- ESP32/ESP8266 boards
- STM32 boards and ST-Link debuggers
- Raspberry Pi Pico
- Teensy boards
- Various programmers and debuggers

Users are added to `dialout` and `plugdev` groups during profile installation.

## CLI Commands

### Check Status

```bash
carina missionlab status
```

Reports:
- Toolchain availability (arduino-cli, PlatformIO, avrdude, etc.)
- User group membership (dialout, plugdev)
- Serial port access
- udev rules installation

### Detect Devices

```bash
carina missionlab devices
```

Scans and reports:
- Serial ports (/dev/ttyUSB*, /dev/ttyACM*)
- Known USB development devices
- Video capture devices
- GPIO/I2C/SPI interfaces

## Security

MissionLab follows CARINA's mission-grade security principles:

- No permanent root access required
- Uses groups + udev only (no chmod 777)
- Explicit permission model
- No system-wide permission loosening

## Directory Structure

```
missionlab/
├── udev/
│   ├── 99-carina-serial.rules    # Serial device permissions
│   └── 99-carina-usb.rules       # USB device permissions
├── profiles/
│   ├── embedded/
│   │   ├── packages.txt          # Embedded toolchain packages
│   │   └── config.sh             # User/group configuration
│   └── robotics/
│       ├── packages.txt          # ROS2 tooling packages
│       └── config.sh             # ROS2 environment setup
├── device-detect.sh              # Device detection utility
└── README.md                     # This file
```

## After Installation

After applying a MissionLab profile:

1. **Log out and back in** for group changes to take effect
2. Run `carina missionlab status` to verify setup
3. Connect your device and run `carina missionlab devices`

## Supported Devices

### Serial Adapters
- FTDI FT232, FT2232, FT232H
- Silicon Labs CP210x
- Prolific PL2303
- WCH CH340/CH341

### Microcontroller Boards
- Arduino Uno, Mega, Leonardo, Due, Micro
- ESP32, ESP8266, ESP32-S2, ESP32-S3
- STM32 (various, including Nucleo boards)
- Raspberry Pi Pico, Pico W
- Teensy 3.x, 4.x

### Debuggers/Programmers
- ST-Link V2, V2-1, V3
- Segger J-Link
- Black Magic Probe
- CMSIS-DAP compatible
- USBasp, AVR ISP

## What MissionLab Does NOT Include (Yet)

- Full ROS2 desktop installation
- GUI device manager
- AI control integration
- Firmware flashing automation
- Hardware simulation

These features are planned for future sprints.
