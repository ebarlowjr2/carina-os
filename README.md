# CARINA OS

CARINA OS is a mission-grade, headless-first, Debian-based operating system layer built on top of Ubuntu LTS for compatibility.

## Overview

CARINA Core provides its own identity, tooling, and profiles while maintaining full compatibility with Ubuntu packages and ecosystem. It is designed to work on EC2, local VMs, laptops, and Toughbooks.

## Quick Start

To convert a fresh Ubuntu Server 24.04 into CARINA Core:

```bash
sudo ./bootstrap/bootstrap-carina.sh
```

## CLI Usage

```bash
carina doctor              # Check system health
carina profile list        # List available profiles
carina profile apply core  # Apply a profile
carina gui enable          # Enable graphical interface
carina gui disable         # Disable graphical interface
carina version             # Show version
```

## Directory Structure

```
carina-os/
├── README.md
├── docs/                  # Documentation
├── bootstrap/             # Bootstrap scripts
├── cli/                   # CARINA CLI
├── profiles/              # System profiles
│   ├── core/              # Core profile
│   └── flightdeck/        # GUI profile
├── system/                # System services
└── branding/              # OS branding files
```

## Profiles

- **core**: Minimal server profile with essential tools
- **flightdeck**: GUI-enabled profile with desktop environment

## Requirements

- Ubuntu Server 24.04 LTS
- Root/sudo access
- Network connectivity

## License

Proprietary - CARINA OS
