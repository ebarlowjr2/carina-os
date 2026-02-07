#!/bin/bash
#
# CARINA Control - Sandbox Data Collector
# Collects sandbox state for advisory analysis
#
# Security: Read-only, no execution, no modification
#

set -e

SANDBOX_STATE_DIR="/var/lib/carina/sandbox"
SANDBOX_LOG="/var/log/carina-sandbox.log"

collect_sandbox_data() {
    echo "=== SANDBOX DATA ==="
    
    # Count active sandboxes
    echo "ACTIVE_SANDBOXES:"
    if [[ -d "$SANDBOX_STATE_DIR" ]]; then
        active_count=$(find "$SANDBOX_STATE_DIR" -name "*.state" 2>/dev/null | wc -l)
        echo "  Count: $active_count"
        
        # List active sandboxes with TTL info
        if [[ $active_count -gt 0 ]]; then
            echo "  Active:"
            for state_file in "$SANDBOX_STATE_DIR"/*.state; do
                if [[ -f "$state_file" ]]; then
                    name=$(basename "$state_file" .state)
                    ttl=$(grep "^TTL=" "$state_file" 2>/dev/null | cut -d= -f2 || echo "unknown")
                    template=$(grep "^TEMPLATE=" "$state_file" 2>/dev/null | cut -d= -f2 || echo "unknown")
                    echo "    - $name (template: $template, ttl: $ttl)"
                fi
            done
        fi
    else
        echo "  Count: 0"
        echo "  Note: Sandbox state directory not found"
    fi
    
    # TTL usage patterns from logs
    echo "TTL_PATTERNS:"
    if [[ -f "$SANDBOX_LOG" ]]; then
        # Count TTL values used
        ttl_5m=$(grep -c "ttl=5m" "$SANDBOX_LOG" 2>/dev/null || echo "0")
        ttl_15m=$(grep -c "ttl=15m" "$SANDBOX_LOG" 2>/dev/null || echo "0")
        ttl_30m=$(grep -c "ttl=30m" "$SANDBOX_LOG" 2>/dev/null || echo "0")
        ttl_1h=$(grep -c "ttl=1h" "$SANDBOX_LOG" 2>/dev/null || echo "0")
        echo "  5m: $ttl_5m, 15m: $ttl_15m, 30m: $ttl_30m, 1h: $ttl_1h"
    else
        echo "  No log data available"
    fi
    
    # Recently expired sandboxes (from logs)
    echo "RECENTLY_EXPIRED:"
    if [[ -f "$SANDBOX_LOG" ]]; then
        expired_count=$(grep -c "action=destroy" "$SANDBOX_LOG" 2>/dev/null || echo "0")
        echo "  Total destroyed: $expired_count"
        
        # Last 5 destroyed
        echo "  Recent:"
        grep "action=destroy" "$SANDBOX_LOG" 2>/dev/null | tail -5 | while read -r line; do
            name=$(echo "$line" | grep -oP 'sandbox=\K[^ ]+' || echo "unknown")
            timestamp=$(echo "$line" | awk '{print $1}')
            echo "    - $name at $timestamp"
        done
    else
        echo "  No log data available"
    fi
    
    # Template usage
    echo "TEMPLATE_USAGE:"
    if [[ -f "$SANDBOX_LOG" ]]; then
        ubuntu_count=$(grep -c "template=ubuntu" "$SANDBOX_LOG" 2>/dev/null || echo "0")
        python_count=$(grep -c "template=python" "$SANDBOX_LOG" 2>/dev/null || echo "0")
        node_count=$(grep -c "template=node" "$SANDBOX_LOG" 2>/dev/null || echo "0")
        echo "  ubuntu: $ubuntu_count, python: $python_count, node: $node_count"
    else
        echo "  No log data available"
    fi
    
    echo "=== END SANDBOX DATA ==="
}

# Run collector
collect_sandbox_data
