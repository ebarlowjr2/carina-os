# CARINA MissionLab

## Overview

MissionLab provides a first-class environment for embedded development and robotics:

- Microcontrollers (Arduino, ESP32, STM32, Teensy, Raspberry Pi Pico)
- Robotics development (ROS2 tooling)
- Sensors and serial devices
- Field hardware (USB, GPIO, UART)

**Goal:** Plug in a board, CARINA recognizes it, tooling works, no fighting permissions.

## Design Principles

- **Plug-and-work device experience** — No manual permission setup
- **No root required** for common hardware workflows
- **Safe by default** — Explicit escalation only
- **Headless-first** — GUI optional
- **Laptop/Toughbook realistic** — Works in the field
- **No vendor lock-in** — Open toolchains only

## Profiles

### missionlab-embedded

CLI-first toolchain for embedded development.

**Packages:** arduino-cli, PlatformIO, avrdude, dfu-util, openocd, minicom, screen, picocom, cmake, ninja-build

```bash
sudo carina profile apply missionlab-embedded
```

### missionlab-robotics

Minimal ROS2 development tooling.

**Packages:** ros-dev-tools, colcon, python3-rosdep, python3-vcstool

```bash
sudo carina profile apply missionlab-robotics
```

> **Note:** ROS2 is NOT auto-sourced. See `/etc/carina/ros2-setup-hint.sh` for setup instructions.

## Supported Hardware

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

## CLI Commands

### Check status

```bash
carina missionlab status
```

Reports toolchain availability, user group membership, serial port access, and udev rules status.

### Detect devices

```bash
carina missionlab devices
```

Scans serial ports, USB development devices, video capture devices, and GPIO/I2C/SPI interfaces.

## Device Access Model

MissionLab uses udev rules for non-root device access:

- **dialout group** — Serial port access (`/dev/ttyUSB*`, `/dev/ttyACM*`)
- **plugdev group** — USB device access (programmers, debuggers)

### udev Rules

Two rule files installed:
- `/etc/udev/rules.d/99-carina-serial.rules` — Serial device permissions
- `/etc/udev/rules.d/99-carina-usb.rules` — USB device permissions

## After Installation

1. Log out and back in for group changes
2. Run `carina missionlab status` to verify
3. Connect device and run `carina missionlab devices`
4. Test with toolchain:

```bash
arduino-cli board list
# or
platformio device list
```

## Troubleshooting

**"Permission denied" on serial port:**
1. Check groups: `groups`
2. Add to dialout: `sudo usermod -aG dialout $USER`
3. Log out and back in
4. Verify: `carina missionlab status`

**Device not detected:**
1. Check connection: `lsusb`
2. Check serial ports: `ls -la /dev/ttyUSB* /dev/ttyACM*`
3. Check udev rules: `ls /etc/udev/rules.d/99-carina-*`
4. Reload udev: `sudo udevadm control --reload-rules && sudo udevadm trigger`

**arduino-cli not finding boards:**
1. Update core index: `arduino-cli core update-index`
2. Install board support: `arduino-cli core install arduino:avr`
3. List boards: `arduino-cli board list`

---

*Related: [Embedded/Robotics Guide](../embedded.md), [Features](../features.md)*


<!-- Imported from the CARINA OS Wiki (Wiki.js). Original path: /features/missionlab · last updated 2026-04-16 -->
