# CARINA OS Identity

## Overview

CARINA OS establishes its own identity separate from Ubuntu while maintaining full compatibility with the Ubuntu ecosystem. This document describes how CARINA presents itself to users and systems.

## OS Release Information

The /etc/os-release file is the primary source of OS identity information on Linux systems. CARINA replaces the Ubuntu version with its own:

```
NAME="CARINA OS"
PRETTY_NAME="CARINA OS (Core)"
ID=carina
ID_LIKE=debian
VERSION_ID="0.1"
VERSION="0.1 (Core)"
HOME_URL="https://carinaos.org"
SUPPORT_URL="https://carinaos.org/support"
BUG_REPORT_URL="https://carinaos.org/bugs"
```

The ID_LIKE=debian field ensures that tools expecting a Debian-based system continue to work correctly.

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

Sprint 1 establishes version 0.1, indicating pre-release status.

## Branding Guidelines

CARINA OS branding should be:

- Professional and minimal
- Mission-focused
- Free of unnecessary decoration or emojis
- Consistent across all touchpoints

The name "CARINA" should always be written in all capitals. The full name "CARINA OS" should be used in formal contexts.
