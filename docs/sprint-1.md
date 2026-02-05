# Sprint 1: CARINA Core

## Objective

Build CARINA Core, a headless-first, Debian-based operating system layer with its own identity, tooling, and profiles, running on top of Ubuntu LTS for compatibility.

## Deliverables

By the end of Sprint 1, the following capabilities are available:

A fresh Ubuntu Server can be converted into CARINA Core using the bootstrap script. CARINA branding replaces Ubuntu branding at the OS level. The carina CLI exists and manages profiles. GUI can be enabled/disabled cleanly. First-boot configuration is supported through a YAML file.

## Constraints

The following constraints were followed during Sprint 1:

- No kernel fork
- No ISO creation
- No hardcoded AWS assumptions
- Works on EC2, local VM, and future laptops/Toughbooks
- CARINA presents itself as its own OS

## Components Built

### Bootstrap Script

Location: bootstrap/bootstrap-carina.sh

The bootstrap script converts Ubuntu Server 24.04 into CARINA Core. It verifies the Ubuntu version, installs base dependencies, installs the CARINA CLI, applies CARINA identity, enables the first-boot system, and applies the core profile. The script is idempotent and safe to re-run.

### CARINA CLI

Location: cli/carina

Commands implemented:
- carina doctor - System health checks
- carina profile list - List available profiles
- carina profile apply <name> - Apply a profile
- carina gui enable - Enable graphical interface
- carina gui disable - Disable graphical interface
- carina version - Show version

### Profiles

Core profile (profiles/core/) provides minimal server tools including git, curl, wget, vim, tmux, htop, jq, openssh-server, chrony, ufw, rsyslog, and logrotate. Configuration enables SSH, chrony, UFW with SSH allowed, and sane sysctl defaults.

FlightDeck profile (profiles/flightdeck/) provides GUI capabilities with ubuntu-desktop-minimal, gdm3, and xrdp.

### First-Boot System

Location: system/firstboot.service and system/firstboot.sh

Supports configuration through /etc/carina/firstboot.yaml with fields for hostname, user, ssh_authorized_keys, and enable_gui. Runs once at boot and disables itself after success.

### Branding

Location: branding/os-release and branding/motd

Replaces Ubuntu branding with CARINA OS identity.

## Validation

Run the following to validate the installation:

```bash
sudo ./bootstrap/bootstrap-carina.sh
carina doctor
carina profile list
carina gui enable
sudo reboot
carina gui disable
sudo reboot
```

## What's NOT in Sprint 1

- No AI controller
- No sandboxing
- No ISO
- No heavy theming
- No AWS-specific logic
