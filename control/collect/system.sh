#!/bin/bash
#
# CARINA Control - System Data Collector
# Collects basic system metadata for advisory analysis
#
# Security: Read-only, no execution, no modification
#

set -e

collect_system_data() {
    echo "=== SYSTEM DATA ==="
    
    # OS version
    echo "OS_VERSION:"
    if [[ -f /etc/os-release ]]; then
        grep -E "^(NAME|VERSION|PRETTY_NAME)=" /etc/os-release 2>/dev/null || echo "  Unknown"
    fi
    
    # Uptime
    echo "UPTIME:"
    uptime -p 2>/dev/null || echo "  Unknown"
    
    # Load averages
    echo "LOAD_AVERAGES:"
    if [[ -f /proc/loadavg ]]; then
        cat /proc/loadavg | awk '{print "  1min: "$1", 5min: "$2", 15min: "$3}'
    else
        echo "  Unknown"
    fi
    
    # Disk usage (root partition only)
    echo "DISK_USAGE:"
    df -h / 2>/dev/null | tail -1 | awk '{print "  Total: "$2", Used: "$3", Available: "$4", Use%: "$5}' || echo "  Unknown"
    
    # Memory usage (basic)
    echo "MEMORY_USAGE:"
    if [[ -f /proc/meminfo ]]; then
        total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        if [[ -n "$total" && -n "$available" ]]; then
            total_mb=$((total / 1024))
            available_mb=$((available / 1024))
            used_mb=$((total_mb - available_mb))
            echo "  Total: ${total_mb}MB, Used: ${used_mb}MB, Available: ${available_mb}MB"
        else
            echo "  Unknown"
        fi
    else
        echo "  Unknown"
    fi
    
    echo "=== END SYSTEM DATA ==="
}

# Run collector
collect_system_data
