# CARINA OS Features

## Overview

CARINA OS provides a modular set of subsystems, each designed for a specific operational domain. All features follow CARINA design principles: headless-first, secure by default, and platform agnostic.

## Subsystems

### [CARINA Core](features/core.md)
The foundation layer. Ubuntu LTS base with CARINA identity, CLI tooling, profile system, and security defaults.

### [FlightDeck](features/flightdeck.md)
Optional graphical interface profile providing XFCE desktop, GDM3 display manager, and xRDP remote access.

### [Sandbox](features/sandbox.md)
Fast, disposable execution environments using Podman containers. Three templates (Ubuntu, Python, Node) with enforced security constraints.

### [MissionLab](features/missionlab.md)
Embedded development and robotics tooling. Arduino CLI, PlatformIO, OpenOCD, serial tools, ROS2 development support, and automatic device permissions.

### [CARINA Control](ai/carina-control.md)
AI advisory system with confirm-to-execute safety model. Proposals are validated against security policies and executed only inside sandboxes.

### [Desktop Integration](features/desktop.md)
GUI theming, wallpapers, and branding when FlightDeck is active. Custom CARINA wallpaper and dark mode defaults.

---

*Related: [Getting Started](getting-started.md), [Mission Manual](mission-manual.md)*


<!-- Imported from the CARINA OS Wiki (Wiki.js). Original path: /features · last updated 2026-04-16 -->
