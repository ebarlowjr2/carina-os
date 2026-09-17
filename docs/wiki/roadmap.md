# CARINA OS Roadmap

## Overview

CARINA OS development follows a sprint-based model. Each sprint delivers a focused set of capabilities that build on previous work.

## Completed Sprints

### Sprint 1: CARINA Core (v0.1)

**Objective:** Build the foundation OS layer.

**Delivered:**
- Bootstrap script converting Ubuntu 24.04 to CARINA OS
- CARINA CLI (`doctor`, `profile`, `gui`, `version`)
- Core profile (essential server tools, security defaults)
- FlightDeck profile (GUI with XFCE + xRDP)
- First-boot YAML configuration system
- CARINA identity branding (`/etc/os-release`, `/etc/motd`)
- OS branding with wallpapers and color system

### Sprint 2: Sandbox and MissionLab (v0.2)

**Objective:** Introduce safe execution environments and embedded tooling.

**Delivered:**
- Podman-based sandbox runtime (rootless containers)
- Sandbox CLI namespace (`up`, `down`, `exec`, `list`, `cleanup`, `templates`)
- Three sandbox templates (Ubuntu, Python, Node)
- Security constraints (unprivileged, read-only, resource-limited)
- TTL enforcement with JSON state tracking
- Sandbox logging with logrotate
- MissionLab embedded profile (Arduino CLI, PlatformIO, OpenOCD, serial tools)
- MissionLab robotics profile (ROS2 dev tools)
- Device detection and status commands
- udev rules for automatic device permissions
- CARINA Control proposal/approval/execution system

## Current Sprint

### Sprint 3: Documentation and Polish

**Objective:** Create comprehensive documentation and operational tooling.

**In Progress:**
- Wiki.js documentation portal (this site)
- Content migration from repo docs
- Admin runbooks and backup procedures
- Contributor guidelines

## Upcoming Milestones

### Future: Advanced Sandbox
- KVM / VM sandboxes
- GUI sandbox manager
- AI agent execution environments
- Network simulation
- Persistent environments

### Future: MissionLab Extended
- Full ROS2 desktop installation
- GUI device manager
- Firmware flashing automation
- Hardware simulation
- CAN bus support

### Future: CARINA Control Enhanced
- Multi-step proposals
- Automated approval for low-risk operations
- Execution history dashboard
- Integration with CI/CD pipelines

### Future: Desktop Polish
- Custom CARINA GTK theme (Adwaita-based)
- Mission Control UI
- Sandbox UI panels
- Installer visuals

---

*Related: [Features](features.md), [Contributing](contributing.md)*


<!-- Imported from the CARINA OS Wiki (Wiki.js). Original path: /roadmap · last updated 2026-04-16 -->
