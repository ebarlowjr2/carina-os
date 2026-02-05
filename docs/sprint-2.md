# CARINA OS — Sprint 2

## Sprint 2 Objective

Introduce CARINA Sandbox, a fast, disposable execution environment system that allows engineers, scientists, and developers to test code safely, run experiments without polluting the host OS, and validate scripts, configs, and workflows quickly.

## What Was Built

### Sandbox Runtime

Podman-based container isolation (no Docker daemon dependency). Rootless-capable with better security model.

### CLI Extensions

New `carina sandbox` namespace with commands:

- `carina sandbox templates` - List available sandbox templates
- `carina sandbox list` - Show active sandboxes with ID, template, age, TTL
- `carina sandbox up <template> [--ttl 10m] [--name <name>]` - Start sandbox
- `carina sandbox exec <name|id> <command>` - Execute in sandbox
- `carina sandbox down <name|id>` - Stop and remove sandbox
- `carina sandbox cleanup` - Remove expired/orphaned sandboxes

### Sandbox Templates

Three templates created:

- **ubuntu** - Base sandbox for generic testing (bash, coreutils, curl, ca-certificates)
- **python** - Python 3.12 sandbox for scripts and data science
- **node** - Node.js LTS sandbox for tooling and UI experiments

### Security Constraints

All sandboxes enforce:

- Unprivileged execution (runs as `sandbox` user)
- All capabilities dropped (`--cap-drop ALL`)
- Read-only base filesystem
- No host filesystem access
- Memory limited to 512MB, CPU limited to 1 core
- No new privileges allowed (`--security-opt no-new-privileges:true`)
- Isolated network (bridge only)

### TTL Enforcement

- TTL tracked in `/var/lib/carina/sandboxes.json`
- Uses Unix epoch timestamps (UTC-based, locale-independent)
- Cleanup removes expired sandboxes and orphan state entries

### Logging

All actions logged to `/var/log/carina/sandbox.log`:

- Who started the sandbox
- Template used
- TTL configured
- Commands executed
- Destruction time

Logrotate configured for weekly rotation with 4 weeks retention.

### Permission Model

Mission-grade permissions using `carina` group:

- Directories: `root:carina` with `2775` (setgid)
- Files: `root:carina` with `664`
- Users automatically added to group during bootstrap

## Validated Test Commands

These commands were tested on EC2 instance (98.92.29.166) running CARINA OS:

```bash
# Install/update CARINA with sandbox support
sudo ./bootstrap/bootstrap-carina.sh

# Log out and back in for group membership to take effect

# Verify installation
carina doctor

# List available templates
carina sandbox templates

# Start a Python sandbox with 5-minute TTL
carina sandbox up python --ttl 5m --name test-python

# List active sandboxes
carina sandbox list

# Execute command in sandbox
carina sandbox exec test-python python --version
# Output: Python 3.12.12

# Stop and remove sandbox
carina sandbox down test-python

# Verify logging
cat /var/log/carina/sandbox.log

# Verify logrotate config
cat /etc/logrotate.d/carina-sandbox
```

### TTL Expiration Test

```bash
# Start sandbox with short TTL
carina sandbox up python --ttl 5m

# Wait for TTL to expire
sleep 6m

# Cleanup expired sandboxes
carina sandbox cleanup

# Verify sandbox was removed
carina sandbox list
# Output: No active sandboxes
```

## What Sprint 2 Does NOT Include

These features are planned for future sprints:

- KVM / VM sandboxes
- GUI sandbox manager
- AI agent execution
- Network simulation
- Persistent environments
- Automatic cleanup via cron/systemd timer

## Files Added/Modified

### New Files

- `sandbox/templates/ubuntu/Containerfile` - Ubuntu base image
- `sandbox/templates/ubuntu/README.md`
- `sandbox/templates/python/Containerfile` - Python 3.12 image
- `sandbox/templates/python/README.md`
- `sandbox/templates/node/Containerfile` - Node.js LTS image
- `sandbox/templates/node/README.md`
- `sandbox/sandbox.sh` - Standalone sandbox functions
- `sandbox/cleanup.sh` - Cleanup script
- `docs/sandbox.md` - Sandbox documentation

### Modified Files

- `bootstrap/bootstrap-carina.sh` - Added Podman install, sandbox setup, carina group
- `cli/carina` - Added sandbox command namespace, updated to v0.2

## Version

CARINA OS v0.2.0
