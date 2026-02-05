# CARINA Sandbox - Ubuntu Template

## Purpose

Base Ubuntu sandbox for generic testing and experimentation. This template provides a minimal Ubuntu 24.04 environment with essential tools.

## What it's for

- Testing shell scripts
- Validating configurations
- Running basic Linux commands
- General experimentation

## What it's NOT for

- Production workloads
- Persistent data storage
- Network services
- Heavy computation

## Included packages

- bash
- coreutils
- curl
- ca-certificates

## Security

- Runs as unprivileged user `sandbox`
- No host filesystem access
- No privileged capabilities
- Read-only base filesystem where possible
