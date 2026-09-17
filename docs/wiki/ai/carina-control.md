# CARINA Control

## Overview

CARINA Control is an AI advisory system that follows a strict confirm-to-execute model. It proposes actions, validates them against security policies, and executes approved commands only inside sandbox environments.

## Advisory Mode

CARINA Control operates in advisory mode by default:

1. **Propose** — AI suggests a command with description and risk assessment
2. **Review** — User reviews the proposal, command, and risk level
3. **Approve or Reject** — User makes the decision
4. **Execute** — Approved commands run exclusively inside sandboxes
5. **Report** — Results are logged and sandbox is destroyed

## Confirm-to-Execute Model

**No command executes without explicit human approval.**

The execution path is:
```
Proposal → Policy Validation → Human Approval → Sandbox Execution → Destruction
```

### Security guarantees

- Execution ONLY occurs via `carina sandbox up` (no direct shell)
- No host filesystem mounts allowed
- No privileged containers
- No write access to host filesystem
- All execution is logged and auditable
- Sandbox is destroyed after execution

## Trust Boundaries

| Boundary | Rule |
|----------|------|
| Proposal creation | AI can propose; cannot execute |
| Policy validation | Automatic; blocks dangerous patterns |
| Human approval | Required for all execution |
| Sandbox execution | Only path to run commands |
| Host access | Never. All execution is isolated |

## Policy Engine

Commands are validated against security policies that block:
- Direct host shell execution
- Privileged operations
- Network-affecting commands
- Filesystem modification outside sandbox
- Commands matching dangerous patterns

### Risk levels

| Level | Meaning |
|-------|---------|
| LOW | Read-only operations, information gathering |
| MEDIUM | File creation, package installation inside sandbox |
| HIGH | Network operations, system configuration changes |

## What AI Can and Cannot Do

### AI CAN:
- Propose commands for execution
- Assess risk levels
- Provide descriptions and explanations
- List and review proposals

### AI CANNOT:
- Execute commands directly on the host
- Bypass the approval process
- Access host filesystem
- Run privileged operations
- Override security policies

## CLI Usage

```bash
# Create a proposal
carina control propose "Check Python version" "python --version" python

# List all proposals
carina control list

# List pending proposals
carina control list pending

# Approve and execute a proposal
carina control approve <id>

# Reject a proposal
carina control reject <id> "Reason"

# Clear completed proposals
carina control clear
```

## Logging

All control actions are logged to `/var/log/carina-control.log`:

```
2026-02-10 14:30:00 user=ubuntu action=propose proposal=1 status=created sandbox=python
2026-02-10 14:30:15 user=ubuntu action=approve proposal=1 status=approved sandbox=python
2026-02-10 14:30:20 user=ubuntu action=execute proposal=1 status=success sandbox=python
```

---

*Related: [Sandbox](../features/sandbox.md), [Features](../features.md)*


<!-- Imported from the CARINA OS Wiki (Wiki.js). Original path: /ai/carina-control · last updated 2026-04-16 -->
