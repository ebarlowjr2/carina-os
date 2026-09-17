# FlightDeck

## Overview

FlightDeck is the graphical interface profile for CARINA OS. It adds desktop capabilities on top of the headless Core profile when GUI access is needed.

## What FlightDeck Provides

| Component | Purpose |
|-----------|---------|
| ubuntu-desktop-minimal | Lightweight XFCE-based desktop |
| GDM3 | Display manager for local sessions |
| xRDP | Remote Desktop Protocol for remote GUI access |

## Enable FlightDeck

```bash
carina gui enable
sudo reboot
```

## Disable FlightDeck

```bash
carina gui disable
sudo reboot
```

## Remote Access via xRDP

After enabling FlightDeck, connect via any RDP client:

1. Open your RDP client (Windows: Remote Desktop Connection, macOS: Microsoft Remote Desktop)
2. Connect to the CARINA host IP on port 3389
3. Log in with your CARINA user credentials

**Firewall note:** The FlightDeck profile automatically adds a UFW rule for port 3389.

## Profiles System

Profiles are stored in `/opt/carina/profiles/<name>/` and contain:
- `packages.txt` — List of packages to install
- `config.sh` — Configuration script run after installation

### Available profiles

| Profile | Purpose |
|---------|---------|
| core | Minimal server with essential tools |
| flightdeck | GUI desktop with xRDP |
| missionlab-embedded | Embedded development toolchain |
| missionlab-robotics | ROS2 development tools |

### Apply a profile

```bash
sudo carina profile apply flightdeck
```

### List profiles

```bash
carina profile list
```

## Creating Custom Profiles

1. Create a directory under `/opt/carina/profiles/`
2. Add `packages.txt` with package names (one per line)
3. Add `config.sh` with configuration commands
4. The profile appears automatically in `carina profile list`

**Best practice:** Keep profiles focused, idempotent, and platform-agnostic.

---

*Related: [CARINA Core](core.md), [Administration](../administration.md)*


<!-- Imported from the CARINA OS Wiki (Wiki.js). Original path: /features/flightdeck · last updated 2026-04-16 -->
