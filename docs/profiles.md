# CARINA OS Profiles

## Overview

Profiles are the primary mechanism for configuring CARINA OS for specific use cases. Each profile consists of a package list and a configuration script that together define a complete system configuration.

## Profile Structure

Each profile is stored in /opt/carina/profiles/<name>/ and contains:

- packages.txt: List of packages to install (one per line)
- config.sh: Configuration script to run after package installation

## Available Profiles

### Core Profile

The core profile provides a minimal but functional server environment with essential tools for system administration and development.

Packages included: git, curl, wget, vim, tmux, htop, jq, openssh-server, chrony, ufw, rsyslog, logrotate

Configuration applied:
- SSH service enabled and started
- Chrony time synchronization enabled
- UFW firewall configured with default deny incoming, allow outgoing, and SSH allowed
- Sysctl defaults for network security and performance

### FlightDeck Profile

The flightdeck profile adds graphical interface capabilities to CARINA OS. It is designed to be applied on top of the core profile when GUI access is needed.

Packages included: ubuntu-desktop-minimal, gdm3, xrdp

Configuration applied:
- GDM3 display manager enabled
- XRDP remote desktop enabled
- Firewall rule for RDP (port 3389) added

## Using Profiles

List available profiles:
```bash
carina profile list
```

Apply a profile:
```bash
sudo carina profile apply core
sudo carina profile apply flightdeck
```

## Creating Custom Profiles

To create a custom profile, create a new directory under /opt/carina/profiles/ with:

1. packages.txt containing package names (one per line)
2. config.sh containing configuration commands

The profile will automatically appear in `carina profile list` and can be applied using `carina profile apply <name>`.

## Profile Best Practices

Keep profiles focused on a single purpose. Use the core profile as a base and create additional profiles for specific use cases. Configuration scripts should be idempotent so they can be safely re-run. Avoid hardcoding platform-specific assumptions in profiles.
