# Getting Started with CARINA OS

## Overview

CARINA OS converts a fresh Ubuntu Server 24.04 installation into a mission-grade operating system with its own identity, tooling, and profiles. This guide walks you through initial deployment and verification.

## What is CARINA OS?

CARINA OS is a headless-first Linux environment designed for:

- **STEM workflows** — engineering, data science, embedded systems
- **Embedded development** — Arduino, ESP32, STM32, ROS2
- **Robotics** — device access, serial debugging, sensor integration
- **AI-assisted engineering** — CARINA Control advisory system

### Core Components

| Component | Purpose |
|-----------|---------|
| **CARINA Core** | Base OS layer with identity, CLI, and security defaults |
| **FlightDeck** | Optional GUI profile with XFCE desktop and xRDP |
| **MissionLab** | Embedded and robotics development tooling |
| **Sandbox** | Disposable container environments for safe testing |
| **CARINA Control** | AI advisory with confirm-to-execute execution model |

## Prerequisites

- Ubuntu Server 24.04 LTS (fresh installation)
- Root or sudo access
- Network connectivity
- Supported platforms: EC2, local VMs, laptops, Toughbooks

## Bootstrap CARINA OS

Convert a fresh Ubuntu Server into CARINA Core:

```bash
git clone https://github.com/ebarlowjr2/carina-os.git
cd carina-os
sudo ./bootstrap/bootstrap-carina.sh
```

The bootstrap script:
1. Verifies Ubuntu version compatibility
2. Installs base dependencies
3. Installs the CARINA CLI to `/usr/local/bin/carina`
4. Applies CARINA identity (`/etc/os-release`, `/etc/motd`)
5. Enables the first-boot system
6. Applies the Core profile
7. Detects the hardware and applies matching hardware packs (for example `hw-laptop`)

## Verify Installation

After bootstrapping, verify the installation:

```bash
carina doctor
```

This runs health checks on all CARINA components and reports their status.

## First Commands

```bash
carina version             # Show CARINA version
carina profile list        # List available profiles
carina profile apply core  # Apply or reapply the core profile
```

## Installing on a Laptop

On a laptop, the bootstrap applies the `hw-laptop` hardware pack automatically. It adds NetworkManager for Wi-Fi, power management, lid/suspend settings, firmware updates and a roaming-safe firewall.

1. Install Ubuntu Server 24.04. Use Ethernet or USB tethering during install if the installer doesn't detect your Wi-Fi.
2. Run the bootstrap as above.
3. Reboot so NetworkManager takes over networking.
4. Connect to Wi-Fi: `nmcli device wifi connect <SSID> --ask`
5. Check the laptop section of `carina doctor`.

Lid behaviour and firewall policy are set in `/etc/carina/laptop.conf` and `/etc/carina/firewall.conf`. See [Hardware Detection](../hardware.md).

## Enable GUI (Optional)

If you need a graphical interface:

```bash
sudo carina gui enable    # Install and enable FlightDeck (XFCE + xRDP)
sudo reboot               # Reboot to activate display manager
```

To disable the GUI later:

```bash
sudo carina gui disable
sudo reboot
```

## Next Steps

- [Mission Manual](mission-manual.md) — Full system operations reference
- [Features](features.md) — Explore CARINA subsystems
- [MissionLab](features/missionlab.md) — Set up embedded development
- [Sandbox](features/sandbox.md) — Run your first sandbox

---

*Related: [Architecture](features/core.md), [Profiles](features/flightdeck.md), [Troubleshooting](administration.md)*


<!-- Imported from the CARINA OS Wiki (Wiki.js). Original path: /getting-started · last updated 2026-04-16 -->
