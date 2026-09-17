# Embedded and Robotics

## Overview

CARINA OS provides first-class support for embedded systems development and robotics through MissionLab profiles and tooling.

## Arduino CLI

### Installation

Arduino CLI is included in the `missionlab-embedded` profile:

```bash
sudo carina profile apply missionlab-embedded
```

### Basic usage

```bash
arduino-cli core update-index
arduino-cli core install arduino:avr
arduino-cli board list
arduino-cli compile --fqbn arduino:avr:uno MySketch/
arduino-cli upload -p /dev/ttyACM0 --fqbn arduino:avr:uno MySketch/
```

## PlatformIO

### Installation

PlatformIO is included in the `missionlab-embedded` profile.

### Basic usage

```bash
platformio device list
platformio init --board uno
platformio run
platformio run --target upload
```

## Device Permissions

CARINA handles device permissions automatically via udev rules and group membership:

- **dialout** — Serial port access
- **plugdev** — USB device access

After profile installation, log out and back in for group changes to take effect.

### Verify permissions

```bash
carina missionlab status
groups
```

## Serial Troubleshooting

### No serial port visible

1. Confirm device is connected: `lsusb`
2. Check for serial device: `ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null`
3. Check dmesg for device events: `dmesg | tail -20`
4. Verify udev rules: `ls /etc/udev/rules.d/99-carina-*`

### Permission denied

1. Check group membership: `groups | grep dialout`
2. If missing: `sudo usermod -aG dialout $USER && newgrp dialout`
3. Verify with: `carina missionlab status`

### Device detected but upload fails

1. Check correct port: `arduino-cli board list`
2. Try resetting the board before upload
3. Check baud rate compatibility
4. Try a different USB cable

## Future Robotics Tooling

Planned for future sprints:
- Full ROS2 desktop installation
- GUI device manager
- Firmware flashing automation
- Hardware simulation
- CAN bus support
- GPIO direct access utilities

---

*Related: [MissionLab](features/missionlab.md), [Features](features.md)*


<!-- Imported from the CARINA OS Wiki (Wiki.js). Original path: /embedded · last updated 2026-04-16 -->
