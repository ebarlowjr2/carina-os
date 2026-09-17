# CARINA OS Mission Manual

## Overview

This manual provides a complete operational reference for CARINA OS. It covers system architecture, daily operations, troubleshooting, and maintenance procedures.

## System Overview

CARINA OS is a layered system built on Ubuntu LTS:

| Layer | Component | Purpose |
|-------|-----------|---------|
| 1 | Ubuntu LTS Base | Foundation OS with kernel and core libraries |
| 2 | CARINA Identity | Custom `/etc/os-release` and `/etc/motd` branding |
| 3 | CARINA CLI | System management commands (`carina doctor`, `carina profile`) |
| 4 | Profiles | Package bundles and configuration scripts |
| 5 | First-Boot | YAML-based initial configuration system |

## Quick Start

```bash
# Bootstrap CARINA on a fresh Ubuntu 24.04 server
sudo ./bootstrap/bootstrap-carina.sh

# Verify installation
carina doctor

# Check version
carina version
```

## CLI Reference

| Command | Description |
|---------|-------------|
| `carina doctor` | Run system health checks |
| `carina version` | Display current CARINA version |
| `carina profile list` | List available profiles |
| `carina profile apply <name>` | Apply a system profile |
| `carina gui enable` | Enable graphical interface (FlightDeck) |
| `carina gui disable` | Disable graphical interface |
| `carina sandbox templates` | List sandbox templates |
| `carina sandbox up <template>` | Start a sandbox environment |
| `carina sandbox list` | Show active sandboxes |
| `carina sandbox exec <id> <cmd>` | Execute command in sandbox |
| `carina sandbox down <id>` | Stop and remove a sandbox |
| `carina sandbox cleanup` | Remove expired sandboxes |
| `carina missionlab status` | Check MissionLab toolchain status |
| `carina missionlab devices` | Detect connected development devices |

## Sandbox Basics

CARINA Sandbox provides fast, disposable execution environments using Podman containers.

### Start a sandbox

```bash
carina sandbox up python --ttl 30m --name my-test
```

### Execute commands

```bash
carina sandbox exec my-test python --version
carina sandbox exec my-test bash
```

### Cleanup

```bash
carina sandbox down my-test
carina sandbox cleanup
```

See [Sandbox documentation](features/sandbox.md) for full details.

## MissionLab Basics

MissionLab provides embedded development tooling for microcontrollers and robotics.

### Check toolchain status

```bash
carina missionlab status
```

### Detect connected devices

```bash
carina missionlab devices
```

See [MissionLab documentation](features/missionlab.md) for full details.

## Logs and Troubleshooting

### CARINA logs

```bash
# Sandbox activity log
cat /var/log/carina/sandbox.log

# CARINA Control log
cat /var/log/carina-control.log

# System journal
journalctl -u carina-firstboot
```

### Common issues

**"Permission denied" on serial port:**
1. Check group membership: `groups`
2. Add to dialout: `sudo usermod -aG dialout $USER`
3. Log out and back in

**Device not detected:**
1. Verify connection: `lsusb`
2. Check serial ports: `ls -la /dev/ttyUSB* /dev/ttyACM*`
3. Reload udev: `sudo udevadm control --reload-rules && sudo udevadm trigger`

**GUI not starting after enable:**
1. Verify FlightDeck profile: `carina profile list`
2. Check GDM3 status: `systemctl status gdm3`
3. Reboot: `sudo reboot`

---

*Related: [Getting Started](getting-started.md), [Features](features.md), [Administration](administration.md)*


<!-- Imported from the CARINA OS Wiki (Wiki.js). Original path: /mission-manual · last updated 2026-04-16 -->
