# CARINA Sandbox

Mission-Safe Execution Environments for CARINA OS.

## Overview

CARINA Sandbox provides fast, disposable execution environments that allow engineers, scientists, and developers to test code safely, run experiments without polluting the host OS, and validate scripts, configs, and workflows quickly.

This is controlled isolation using containers, designed to feel like a mission tool, not a dev toy.

## Design Principles

The sandbox system follows these non-negotiable principles:

- **Host safety first** - sandboxed execution only
- **Fast to start, fast to destroy** - minimal overhead
- **Auditable** - user knows what ran and where
- **Headless-first** - GUI optional later
- **No AWS assumptions** - works on EC2, local VMs, laptops
- **No Docker daemon dependency** - uses Podman (rootless-capable)
- **No KVM / nested virtualization** - container-based isolation

## Runtime

CARINA Sandbox uses Podman as its container runtime because:

- No daemon required
- Better security model (rootless by default)
- Works well on laptops, servers, and EC2
- Aligns with mission-grade isolation goals

## CLI Commands

### List Templates

```bash
carina sandbox templates
```

Shows available sandbox templates (ubuntu, python, node).

### Start a Sandbox

```bash
carina sandbox up <template> [--ttl 10m] [--name <name>]
```

Options:
- `--ttl <duration>` - Time to live (default: 10m). Formats: 10m, 1h, 300s
- `--name <name>` - Custom sandbox name (auto-generated if not provided)

Example:
```bash
carina sandbox up python --ttl 30m
```

### List Active Sandboxes

```bash
carina sandbox list
```

Shows active sandboxes with ID, template, age, and TTL remaining.

### Execute in Sandbox

```bash
carina sandbox exec <name|id> <command>
```

Executes a command inside the sandbox. If no command is provided, opens an interactive bash shell.

Example:
```bash
carina sandbox exec python-abc123 python --version
carina sandbox exec python-abc123 bash
```

### Stop a Sandbox

```bash
carina sandbox down <name|id>
```

Stops and removes the sandbox container.

### Cleanup Expired Sandboxes

```bash
carina sandbox cleanup
```

Removes expired sandboxes and orphaned containers. Can be run manually or via cron/systemd timer.

## Templates

### Ubuntu

Base sandbox for generic testing.

Includes: bash, coreutils, curl, ca-certificates

Use for: Testing shell scripts, validating configurations, general experimentation.

### Python

Python sandbox for data science and scripting.

Includes: Python 3.12, pip

Use for: Running Python scripts, data science experiments, testing AI/ML code.

### Node

Node.js sandbox for tooling and UI experiments.

Includes: Node.js LTS, npm

Use for: Running Node.js scripts, testing npm packages, build tool testing.

## Security Constraints

All sandboxes enforce these security constraints:

- Run unprivileged (no root in container)
- No access to /dev
- No access to host network interfaces (default bridge only)
- No access to host home directories
- Read-only base filesystem
- Temporary writable directories for /tmp and /home/sandbox
- Memory limited to 512MB
- CPU limited to 1 core
- No new privileges allowed
- All capabilities dropped

## TTL Enforcement

TTL (Time To Live) is optional but strongly encouraged. When a sandbox's TTL expires, it can be cleaned up using `carina sandbox cleanup`.

Sandbox state is tracked in `/var/lib/carina/sandboxes.json`.

## Logging

All sandbox actions are logged to `/var/log/carina/sandbox.log`:

- Who started the sandbox
- Template used
- TTL configured
- Commands executed
- Destruction time

Example log entry:
```
[2026-02-05 10:30:00] [ubuntu] START: id=python-abc123 template=python ttl=600s
[2026-02-05 10:35:00] [ubuntu] EXEC: id=python-abc123 cmd=python --version
[2026-02-05 10:40:00] [ubuntu] CLEANUP: id=python-abc123 reason=expired
```

## What Sprint 2 Does NOT Include

These features are planned for future sprints:

- KVM / VM sandboxes
- GUI sandbox manager
- AI agent execution
- Network simulation
- Persistent environments
