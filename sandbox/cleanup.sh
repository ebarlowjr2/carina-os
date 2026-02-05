#!/bin/bash
#
# CARINA Sandbox Cleanup Script
# Removes expired sandboxes and orphaned containers
#
# Can be run manually or via cron/systemd timer
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/sandbox.sh" 2>/dev/null || {
    SANDBOX_DIR="/opt/carina/sandbox"
    source "$SANDBOX_DIR/sandbox.sh"
}

sandbox_cleanup
