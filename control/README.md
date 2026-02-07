# CARINA Control

**AI Advisory System for CARINA OS**

CARINA Control is a read-only advisory engine that observes system state and provides recommendations. It never executes commands or modifies the system.

## Security Guarantees

CARINA Control is designed with strict security boundaries:

- **Read-only by default**: Only observes, never modifies
- **No command execution**: Cannot run shell commands
- **No network access required**: Works entirely offline
- **No API keys required**: No external dependencies
- **Human-in-the-loop only**: All actions require human approval
- **Transparent inputs and outputs**: Fully auditable

## Commands

### `carina control status`

Reports the status of the Control subsystem:

```
CARINA Control Status

- System data: OK
- Sandbox data: OK
- MissionLab data: OK
- Logs accessible: OK
- Execution capability: DISABLED
```

### `carina control advise`

Generates an advisory report based on collected system data:

```
CARINA Control Advisory Report

Observations:
- System load is normal (0.15)
- Disk usage is healthy (45%)
- Arduino CLI is installed
- No serial devices detected

Recommendations:
- Consider connecting a device or verifying USB permissions
- Continue monitoring system health with: carina doctor

No actions were taken.
```

## Data Sources

CARINA Control collects data from these sources:

| Collector | Data |
|-----------|------|
| `system.sh` | OS version, uptime, load averages, disk usage, memory |
| `sandbox.sh` | Active sandboxes, TTL patterns, expired sandboxes |
| `missionlab.sh` | Installed tools, permissions, connected devices |
| `logs.sh` | Recent actions, errors/warnings |

All data collection is read-only and auditable.

## Logging

Each advisory run is logged to `/var/log/carina-control.log`:

```
2026-02-07T15:30:00Z user=ubuntu action=advisory status=success sources="system,sandbox,missionlab,logs"
```

The advisory content itself is NOT logged for privacy.

## Architecture

```
control/
├── control.sh          # Main advisory engine
├── collect/
│   ├── system.sh       # System data collector
│   ├── sandbox.sh      # Sandbox data collector
│   ├── missionlab.sh   # MissionLab data collector
│   └── logs.sh         # Log data collector
├── prompts/
│   └── advisory.md     # Advisory prompt template
└── README.md           # This file
```

## What Control Does NOT Do

- Execute commands
- Spawn shells
- Modify files (except logs)
- Write state
- Install packages
- Make network requests
- Access external APIs

## Future Extensions

Sprint 4A establishes the trust model. Future sprints may add:

- Constrained execution (with explicit approval)
- Policy-based automation
- Mission simulation
- Educational AI assistance

These capabilities will only be added after trust is earned through transparent, predictable behavior.

## Philosophy

CARINA Control exists to help users understand their system state and make informed decisions. It is a helpful advisor, not an autonomous agent.

> "Aware, helpful, and safe — not autonomous."
