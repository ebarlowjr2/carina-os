# CARINA OS Architecture

## Overview

CARINA OS is a headless-first, Debian-based operating system layer built on top of Ubuntu LTS. It provides its own identity, tooling, and profiles while maintaining full compatibility with the Ubuntu ecosystem.

## Design Principles

CARINA OS follows these core principles:

**Ubuntu LTS Foundation**: Rather than forking the kernel or creating a custom distribution from scratch, CARINA builds on Ubuntu LTS to leverage its stability, security updates, and hardware compatibility.

**Headless-First**: The system is designed primarily for server and embedded use cases. GUI support is available but optional and can be enabled/disabled cleanly.

**Profile-Based Configuration**: System configuration is managed through profiles that bundle packages and configuration scripts together.

**Platform Agnostic**: CARINA works on EC2, local VMs, laptops, and ruggedized hardware like Toughbooks without hardcoding platform-specific assumptions.

## System Layers

### Layer 1: Ubuntu LTS Base

The foundation is a standard Ubuntu Server installation. CARINA does not modify the kernel or core system libraries, ensuring compatibility with Ubuntu packages and updates.

### Layer 2: CARINA Identity

CARINA replaces Ubuntu branding with its own identity through /etc/os-release and /etc/motd. This makes the system present itself as CARINA OS rather than Ubuntu.

### Layer 3: CARINA CLI

The carina command-line tool provides system management capabilities including health checks (doctor), profile management, and GUI toggling.

### Layer 4: Profiles

Profiles are collections of packages and configuration scripts that can be applied to customize the system for specific use cases. The core profile provides essential server tools, while flightdeck adds GUI capabilities.

### Layer 5: First-Boot System

A systemd-based first-boot system allows initial configuration through a YAML file, supporting hostname, user creation, SSH keys, and GUI enablement.

## Directory Structure

```
/etc/carina/           - Configuration files
/opt/carina/           - CARINA tools and profiles
/var/log/carina/       - Log files
/usr/local/bin/carina  - CLI binary
```

## Security Considerations

CARINA applies security defaults through the core profile including UFW firewall configuration, sysctl hardening, and SSH enablement. The system does not store or transmit credentials and operates entirely locally.
