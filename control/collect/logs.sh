#!/bin/bash
#
# CARINA Control - Log Data Collector
# Summarizes recent log activity for advisory analysis
#
# Security: Read-only, no execution, no modification
#

set -e

SANDBOX_LOG="/var/log/carina-sandbox.log"
MISSIONLAB_LOG="/var/log/carina-missionlab.log"
MAX_ENTRIES=10

collect_log_data() {
    echo "=== LOG DATA ==="
    
    # Sandbox log summary
    echo "SANDBOX_LOG_SUMMARY:"
    if [[ -f "$SANDBOX_LOG" ]]; then
        total_lines=$(wc -l < "$SANDBOX_LOG" 2>/dev/null || echo "0")
        echo "  Total entries: $total_lines"
        
        # Last N sandbox actions
        echo "  Recent actions (last $MAX_ENTRIES):"
        tail -$MAX_ENTRIES "$SANDBOX_LOG" 2>/dev/null | while read -r line; do
            action=$(echo "$line" | grep -oP 'action=\K[^ ]+' || echo "unknown")
            sandbox=$(echo "$line" | grep -oP 'sandbox=\K[^ ]+' || echo "unknown")
            timestamp=$(echo "$line" | awk '{print $1}')
            echo "    - $timestamp: $action $sandbox"
        done
        
        # Errors/warnings
        echo "  Errors/Warnings:"
        error_count=$(grep -ciE "(error|fail|warn)" "$SANDBOX_LOG" 2>/dev/null || echo "0")
        echo "    Count: $error_count"
        if [[ $error_count -gt 0 ]]; then
            grep -iE "(error|fail|warn)" "$SANDBOX_LOG" 2>/dev/null | tail -5 | while read -r line; do
                echo "    - $line"
            done
        fi
    else
        echo "  Log file not found: $SANDBOX_LOG"
    fi
    
    # MissionLab log summary
    echo "MISSIONLAB_LOG_SUMMARY:"
    if [[ -f "$MISSIONLAB_LOG" ]]; then
        total_lines=$(wc -l < "$MISSIONLAB_LOG" 2>/dev/null || echo "0")
        echo "  Total entries: $total_lines"
        
        # Last N missionlab installs
        echo "  Recent actions (last $MAX_ENTRIES):"
        tail -$MAX_ENTRIES "$MISSIONLAB_LOG" 2>/dev/null | while read -r line; do
            action=$(echo "$line" | grep -oP 'action=\K[^ ]+' || echo "unknown")
            tool=$(echo "$line" | grep -oP 'tool=\K[^ ]+' || echo "unknown")
            timestamp=$(echo "$line" | awk '{print $1}')
            echo "    - $timestamp: $action $tool"
        done
        
        # Errors/warnings
        echo "  Errors/Warnings:"
        error_count=$(grep -ciE "(error|fail|warn)" "$MISSIONLAB_LOG" 2>/dev/null || echo "0")
        echo "    Count: $error_count"
        if [[ $error_count -gt 0 ]]; then
            grep -iE "(error|fail|warn)" "$MISSIONLAB_LOG" 2>/dev/null | tail -5 | while read -r line; do
                echo "    - $line"
            done
        fi
    else
        echo "  Log file not found: $MISSIONLAB_LOG"
    fi
    
    # System journal errors (CARINA-related only)
    echo "SYSTEM_JOURNAL_CARINA:"
    if command -v journalctl &>/dev/null; then
        carina_errors=$(journalctl --since "24 hours ago" -p err 2>/dev/null | grep -ci carina || echo "0")
        echo "  CARINA-related errors (24h): $carina_errors"
        if [[ $carina_errors -gt 0 ]]; then
            journalctl --since "24 hours ago" -p err 2>/dev/null | grep -i carina | tail -5 | while read -r line; do
                echo "    - $line"
            done
        fi
    else
        echo "  journalctl not available"
    fi
    
    echo "=== END LOG DATA ==="
}

# Run collector
collect_log_data
