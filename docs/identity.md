# CARINA OS Identity

## Overview

CARINA OS establishes its own identity separate from Ubuntu while maintaining full compatibility with the Ubuntu ecosystem. This document describes how CARINA presents itself to users and systems.

## OS Release Information

The /etc/os-release file is the primary source of OS identity information on Linux systems. The bootstrap generates CARINA's version from `branding/os-release`, filling in the CARINA version and the underlying Ubuntu release:

```
NAME="CARINA OS"
PRETTY_NAME="CARINA OS 0.4.0 (Core)"
ID=carina
ID_LIKE="ubuntu debian"
VERSION_ID="0.4.0"
VERSION="0.4.0 (Core, based on Ubuntu 24.04)"
VERSION_CODENAME=noble
UBUNTU_CODENAME=noble
HOME_URL="https://carinaos.org"
SUPPORT_URL="https://carinaos.org/support"
BUG_REPORT_URL="https://carinaos.org/bugs"
```

`ID_LIKE="ubuntu debian"` and the codename fields keep Ubuntu tooling working. This includes the apt setup steps for ROS, Docker and NodeSource (which read `VERSION_CODENAME`/`UBUNTU_CODENAME`), `ubuntu-drivers`, and PPAs.

### How the file is installed

On Ubuntu, `/etc/os-release` is a symlink owned by the `base-files` package, pointing to `/usr/lib/os-release`. The bootstrap:

1. Diverts `/etc/os-release` with `dpkg-divert`, so `base-files` upgrades update `/etc/os-release.ubuntu` instead and leave CARINA's file in place.
2. Writes CARINA's file to `/etc/os-release` atomically.
3. Leaves `/usr/lib/os-release` as Ubuntu's unmodified identity.

Bootstraps before 0.4 copied CARINA's file through the symlink and overwrote `/usr/lib/os-release`, and every `base-files` update reverted the branding. Re-running the bootstrap detects this and restores Ubuntu's file, from the old backup if it is intact or by reinstalling `base-files`.

## Message of the Day (MOTD)

The /etc/motd file displays when users log in. CARINA uses a minimal, professional message:

```
CARINA OS — Core
Mission-grade Debian-based operating system
```

## Ubuntu Branding Removal

The bootstrap script removes Ubuntu-specific MOTD scripts that would otherwise display Ubuntu branding:

- /etc/update-motd.d/00-header
- /etc/update-motd.d/10-help-text
- /etc/update-motd.d/50-motd-news
- /etc/update-motd.d/91-release-upgrade

All remaining scripts in /etc/update-motd.d/ are made non-executable.

## Version Scheme

CARINA uses semantic versioning:

- Major version: Significant changes to architecture or compatibility
- Minor version: New features or profiles
- Patch version: Bug fixes and minor improvements

The version lives in the `VERSION` file at the repo root. The CLI, bootstrap and os-release all read it.

## Branding Guidelines

CARINA OS branding should be:

- Professional and minimal
- Mission-focused
- Free of unnecessary decoration or emojis
- Consistent across all touchpoints

The name "CARINA" should always be written in all capitals. The full name "CARINA OS" should be used in formal contexts.
