# CARINA Core

## Overview

CARINA Core is the foundation layer of CARINA OS. It converts a standard Ubuntu Server installation into CARINA OS by applying identity branding, installing the CLI, configuring security defaults, and enabling the profile system.

## Design Principles

- **Ubuntu LTS Foundation** — Builds on Ubuntu LTS for stability, security updates, and hardware compatibility
- **Headless-First** — Designed primarily for server and embedded use; GUI is optional
- **Profile-Based Configuration** — System configuration managed through modular profiles
- **Platform Agnostic** — Works on EC2, local VMs, laptops, and ruggedized hardware

## System Layers

### Layer 1: Ubuntu LTS Base
Standard Ubuntu Server installation. CARINA does not modify the kernel or core system libraries.

### Layer 2: CARINA Identity
Replaces Ubuntu branding with CARINA identity:
- `/etc/os-release` — Identifies as CARINA OS
- `/etc/motd` — Clean, professional login message

```
NAME="CARINA OS"
PRETTY_NAME="CARINA OS (Core)"
ID=carina
ID_LIKE=debian
VERSION_ID="0.1"
```

### Layer 3: CARINA CLI
System management tool at `/usr/local/bin/carina` providing health checks, profile management, and GUI toggling.

### Layer 4: Profiles
Collections of packages and configuration scripts. See [FlightDeck](flightdeck.md) and [MissionLab](missionlab.md).

### Layer 5: First-Boot System
Systemd-based first-boot configuration via `/etc/carina/firstboot.yaml`:
- Hostname configuration
- User creation
- SSH authorized keys
- GUI enablement

## Directory Structure

```
/etc/carina/           — Configuration files
/opt/carina/           — Tools and profiles
/var/log/carina/       — Log files
/usr/local/bin/carina  — CLI binary
```

## Security Defaults

The Core profile applies:
- UFW firewall with default deny incoming, allow outgoing, SSH allowed
- Sysctl hardening for network security
- SSH service enabled
- Chrony time synchronization

## Validation

```bash
carina doctor    # Check all system components
carina version   # Verify version
```

---

*Related: [Architecture Overview](../features.md), [Getting Started](../getting-started.md), [Profiles](flightdeck.md)*


<!-- Imported from the CARINA OS Wiki (Wiki.js). Original path: /features/core · last updated 2026-04-16 -->
