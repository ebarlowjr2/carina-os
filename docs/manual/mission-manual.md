# CARINA OS Mission Manual

## What is CARINA OS

CARINA OS is a headless-first, Debian-based operating system layer built on Ubuntu LTS. It provides a mission-grade environment for engineers, scientists, and developers who need reliable, secure, and reproducible systems.

CARINA consists of three main components:

**Core** is the minimal server foundation. It includes essential tools (git, curl, vim, tmux, htop), security hardening (UFW firewall, sysctl tuning), and the CARINA CLI. This is the default profile applied during bootstrap.

**FlightDeck** adds a graphical desktop environment. It installs ubuntu-desktop-minimal with GNOME and xrdp for remote access. Enable it with `carina gui enable`.

**MissionLab** provides embedded development and robotics tooling. It includes profiles for microcontroller development (Arduino, PlatformIO) and robotics (ROS2 tools). Tooling is opt-in and installed via `carina missionlab install`.

## Quick Start

### Install CARINA

On a fresh Ubuntu 24.04 Server:

```bash
git clone https://github.com/ebarlowjr2/carina-os.git
cd carina-os
sudo ./bootstrap/bootstrap-carina.sh
```

The bootstrap script converts Ubuntu to CARINA Core. Log out and back in to see CARINA branding.

### Verify Installation

```bash
carina doctor
```

All checks should show PASS. This verifies OS identity, disk space, memory, network, and systemd health.

### Update CARINA

Pull the latest changes and re-run bootstrap:

```bash
cd ~/carina-os
git pull
sudo ./bootstrap/bootstrap-carina.sh
```

### Enable GUI (FlightDeck)

```bash
sudo carina gui enable
```

This installs the desktop environment and xrdp. Connect via RDP on port 3389.

To disable:

```bash
sudo carina gui disable
```

## Sandbox Quick Start

CARINA Sandbox provides fast, disposable execution environments using Podman containers.

### List Available Templates

```bash
carina sandbox templates
```

Available templates: ubuntu, python, node

### Start a Sandbox

```bash
carina sandbox up python --ttl 30m
```

This creates a Python sandbox that auto-destroys after 30 minutes.

### List Active Sandboxes

```bash
carina sandbox list
```

### Execute Commands

```bash
carina sandbox exec python-abc123 python --version
carina sandbox exec python-abc123 bash
```

### Stop a Sandbox

```bash
carina sandbox down python-abc123
```

### Cleanup Expired Sandboxes

```bash
carina sandbox cleanup
```

### Sandbox Security

Sandboxes run with:
- All capabilities dropped
- Read-only base filesystem
- Memory and CPU limits
- No privileged access
- Isolated network

Logs are written to `/var/log/carina/sandbox.log`.

## MissionLab Overview

MissionLab is CARINA's embedded development and robotics environment. It provides plug-and-work device access without requiring root for common workflows.

### When to Use MissionLab

Use MissionLab when you need to:
- Develop firmware for microcontrollers (Arduino, ESP32, STM32)
- Work with serial devices and USB hardware
- Build robotics applications with ROS2

### How Installs Work

CARINA keeps the base system lean. MissionLab tooling is opt-in:

```bash
carina missionlab install arduino-cli
carina missionlab install platformio
```

This approach ensures:
- Minimal attack surface by default
- Explicit control over installed tools
- Clean uninstall paths
- Logged operations for audit

### Check MissionLab Status

```bash
carina missionlab status
```

Shows toolchain availability, user group membership, and udev rules status.

### List Available Tools

```bash
carina missionlab list
```

Shows all supported tools and their installation status.

### Detect Connected Devices

```bash
carina missionlab devices
```

Scans for serial ports, USB devices, cameras, and GPIO interfaces.

## Embedded Quick Start

### 1. Check Status

```bash
carina missionlab status
```

Verify you're in the dialout and plugdev groups. If not:

```bash
sudo usermod -aG dialout $USER
sudo usermod -aG plugdev $USER
```

Log out and back in for group changes to take effect.

### 2. Install Arduino CLI

```bash
sudo carina missionlab install arduino-cli
```

Verify:

```bash
arduino-cli version
```

### 3. Install PlatformIO

```bash
carina missionlab install platformio
```

Verify:

```bash
pio --version
```

Note: You may need to add `~/.local/bin` to your PATH:

```bash
export PATH="$PATH:$HOME/.local/bin"
```

### 4. Detect Devices

Connect your board and run:

```bash
carina missionlab devices
```

For Arduino boards:

```bash
arduino-cli board list
```

### 5. Flash a Board (Example)

With Arduino CLI:

```bash
arduino-cli core install arduino:avr
arduino-cli compile --fqbn arduino:avr:uno MySketch
arduino-cli upload -p /dev/ttyUSB0 --fqbn arduino:avr:uno MySketch
```

With PlatformIO:

```bash
pio run --target upload
```

## Security Model

CARINA follows a mission-grade security model:

### Why We Don't Install Everything by Default

- Smaller attack surface
- Faster bootstrap
- Explicit audit trail
- Clean system state

### Why No Root Needed for Devices

Device access is managed through:

1. **User groups**: Users are added to `dialout` (serial) and `plugdev` (USB)
2. **udev rules**: Rules set appropriate permissions for known devices
3. **No chmod 777**: Permissions are group-restricted, not world-writable

This model provides:
- Non-root access to development hardware
- Explicit permission grants
- No system-wide permission loosening

### Installed udev Rules

After applying a MissionLab profile:

```bash
ls /etc/udev/rules.d/99-carina-*
```

Rules cover:
- Arduino boards (Uno, Mega, Leonardo, Due)
- ESP32/ESP8266
- STM32 and ST-Link debuggers
- Raspberry Pi Pico
- Teensy
- FTDI, CP210x, CH340 serial adapters

## Logs and Support

### Log Locations

| Log | Purpose |
|-----|---------|
| `/var/log/carina-bootstrap.log` | Bootstrap operations |
| `/var/log/carina/sandbox.log` | Sandbox create/destroy/exec |
| `/var/log/carina-missionlab.log` | MissionLab tool installations |

### View Recent Logs

```bash
tail -n 100 /var/log/carina-missionlab.log
tail -n 100 /var/log/carina/sandbox.log
```

### Collect Logs for Support

```bash
cat /var/log/carina-bootstrap.log
cat /var/log/carina-missionlab.log
carina doctor
carina missionlab status
```

### System Health Check

```bash
carina doctor
```

This checks:
- OS identification
- Disk space (warns below 10%)
- Memory (warns below 512MB free)
- Network connectivity
- Systemd status
