# CARINA Sandbox

## Overview

CARINA Sandbox provides fast, disposable execution environments that allow engineers, scientists, and developers to test code safely, run experiments without polluting the host OS, and validate scripts, configs, and workflows quickly.

This is controlled isolation using containers, designed to feel like a mission tool, not a dev toy.

## Design Principles

- **Host safety first** — Sandboxed execution only
- **Fast to start, fast to destroy** — Minimal overhead
- **Auditable** — User knows what ran and where
- **Headless-first** — GUI optional
- **No Docker daemon dependency** — Uses Podman (rootless-capable)
- **No KVM / nested virtualization** — Container-based isolation

## CLI Commands

### List templates

```bash
carina sandbox templates
```

### Start a sandbox

```bash
carina sandbox up <template> [--ttl 10m] [--name <name>]
```

**Options:**
- `--ttl <duration>` — Time to live (default: 10m). Formats: `10m`, `1h`, `300s`
- `--name <name>` — Custom name (auto-generated if omitted)

**Example:**
```bash
carina sandbox up python --ttl 30m --name my-experiment
```

### List active sandboxes

```bash
carina sandbox list
```

### Execute in sandbox

```bash
carina sandbox exec <name|id> <command>
carina sandbox exec my-experiment python --version
carina sandbox exec my-experiment bash
```

### Stop a sandbox

```bash
carina sandbox down <name|id>
```

### Cleanup expired sandboxes

```bash
carina sandbox cleanup
```

## Templates

| Template | Base | Includes | Use For |
|----------|------|----------|---------|
| **ubuntu** | Ubuntu | bash, coreutils, curl, ca-certificates | Shell scripts, config testing |
| **python** | Python 3.12 | Python 3.12, pip | Data science, AI/ML, scripting |
| **node** | Node.js LTS | Node.js, npm | Tooling, UI experiments, builds |

## Security Constraints

All sandboxes enforce:

- Run unprivileged (no root in container)
- All capabilities dropped (`--cap-drop ALL`)
- Read-only base filesystem
- No host filesystem access
- Memory limited to 512MB
- CPU limited to 1 core
- No new privileges (`--security-opt no-new-privileges:true`)
- Isolated network (bridge only)
- No access to `/dev` or host network interfaces

## TTL Enforcement

Sandbox state is tracked in `/var/lib/carina/sandboxes.json` using UTC epoch timestamps. When TTL expires, `carina sandbox cleanup` removes the sandbox.

## Logging

All actions are logged to `/var/log/carina/sandbox.log`:

```
[2026-02-05 10:30:00] [ubuntu] START: id=python-abc123 template=python ttl=600s
[2026-02-05 10:35:00] [ubuntu] EXEC: id=python-abc123 cmd=python --version
[2026-02-05 10:40:00] [ubuntu] CLEANUP: id=python-abc123 reason=expired
```

## Troubleshooting

**Sandbox fails to start:**
1. Check Podman is installed: `which podman`
2. Check user is in `carina` group: `groups`
3. Check container images: `podman images`

**Cannot execute commands:**
1. Verify sandbox is running: `carina sandbox list`
2. Check TTL has not expired

---

*Related: [CARINA Control](../ai/carina-control.md), [Mission Manual](../mission-manual.md)*


<!-- Imported from the CARINA OS Wiki (Wiki.js). Original path: /features/sandbox · last updated 2026-04-16 -->
