# CARINA OS

CARINA OS is a mission-grade, headless-first, Debian-based operating system layer built on top of Ubuntu LTS for compatibility.

## Overview

CARINA Core provides its own identity, tooling, and profiles while maintaining full compatibility with Ubuntu packages and ecosystem. It is designed to work on EC2, local VMs, laptops, desktops, and ARM boards. CARINA detects the hardware it runs on and applies matching hardware packs automatically (see [docs/hardware.md](docs/hardware.md)).

## Quick Start

To convert a fresh Ubuntu Server 24.04 into CARINA Core:

```bash
sudo ./bootstrap/bootstrap-carina.sh
```

## CLI Usage

```bash
carina doctor              # Check system health (hardware-aware)
carina device              # Show detected hardware traits
carina device packs        # List hardware packs and whether they match
sudo carina device apply   # Apply matching hardware packs
carina profile list        # List available profiles
carina profile apply core  # Apply a profile
sudo carina gui enable     # Enable graphical interface
sudo carina gui disable    # Disable graphical interface
carina version             # Show version
```

## Directory Structure

```
carina-os/
├── README.md
├── VERSION                # CARINA version (single source of truth)
├── docs/                  # Documentation
├── bootstrap/             # Bootstrap scripts
├── cli/                   # CARINA CLI
├── lib/                   # Shared shell modules (device detection, packages, firewall)
├── hardware/              # Hardware packs, applied automatically when they match
│   └── hw-laptop/         # Laptops: Wi-Fi, power, lid, firmware, roaming firewall
├── profiles/              # System profiles
│   ├── core/              # Core profile
│   └── flightdeck/        # GUI profile
├── missionlab/            # Embedded and robotics tooling
├── sandbox/               # Sandbox templates
├── control/               # CARINA Control
├── system/                # System services
├── tests/                 # Tests (bash tests/test-device.sh)
└── branding/              # OS branding files
```

## Profiles

- **core**: Minimal server profile with essential tools
- **flightdeck**: GUI-enabled profile with XFCE desktop, LightDM and xRDP
- **missionlab-embedded** / **missionlab-robotics**: Embedded and robotics tooling

## Hardware Packs

Hardware packs adapt CARINA to the machine it runs on. They are applied during bootstrap when they match the detected hardware:

- **hw-laptop**: NetworkManager for Wi-Fi, power profiles, lid/suspend settings, firmware updates, Bluetooth, and a roaming-safe firewall

See [docs/hardware.md](docs/hardware.md).

## Requirements

- Ubuntu Server 24.04 LTS (amd64 or arm64)
- Root/sudo access
- Network connectivity

## License

Proprietary - CARINA OS
