#!/bin/bash
#
# CARINA Control - AI Advisory Engine
# Read-only advisory system that observes and recommends, never executes
#
# Security Guarantees:
# - No exec calls
# - No shell spawning
# - No file modification (except logs)
# - No package installation
# - No network access required
#

set -e

CONTROL_DIR="/opt/carina/control"
COLLECT_DIR="$CONTROL_DIR/collect"
LOG_FILE="/var/log/carina-control.log"
VERSION="0.1"

# Colors
NC='\033[0m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'

log_advisory() {
    local status="$1"
    local sources="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local user=$(whoami)
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    
    # Log entry (does NOT log advisory content for privacy)
    echo "$timestamp user=$user action=advisory status=$status sources=\"$sources\"" >> "$LOG_FILE" 2>/dev/null || true
}

cmd_help() {
    echo -e "${CYAN}CARINA Control${NC} - AI Advisory System"
    echo ""
    echo "Usage: carina control <command>"
    echo ""
    echo "Commands:"
    echo "  status    Show Control subsystem status"
    echo "  advise    Generate advisory report"
    echo "  help      Show this help message"
    echo ""
    echo "Security:"
    echo "  - Read-only: No commands are executed"
    echo "  - Local: No network access required"
    echo "  - Transparent: All inputs are auditable"
    echo ""
}

cmd_status() {
    echo -e "${CYAN}CARINA Control Status${NC}"
    echo ""
    
    # Check system data availability
    echo -n "- System data: "
    if [[ -f /proc/loadavg && -f /proc/meminfo ]]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}PARTIAL${NC}"
    fi
    
    # Check sandbox data availability
    echo -n "- Sandbox data: "
    if [[ -d /var/lib/carina/sandbox ]] || [[ -f /var/log/carina-sandbox.log ]]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}NO DATA${NC}"
    fi
    
    # Check MissionLab data availability
    echo -n "- MissionLab data: "
    if command -v arduino-cli &>/dev/null || command -v pio &>/dev/null || [[ -f /var/log/carina-missionlab.log ]]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}NO DATA${NC}"
    fi
    
    # Check logs accessibility
    echo -n "- Logs accessible: "
    if [[ -r /var/log/carina-sandbox.log ]] || [[ -r /var/log/carina-missionlab.log ]] || [[ -w /var/log/carina-control.log ]] || [[ -w /var/log ]]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}LIMITED${NC}"
    fi
    
    # Execution capability (must always be DISABLED)
    echo -n "- Execution capability: "
    echo -e "${GREEN}DISABLED${NC}"
    
    echo ""
    echo "Control version: $VERSION"
    echo "Advisory mode: ENABLED"
}

collect_all_data() {
    local data=""
    
    # Collect system data
    if [[ -x "$COLLECT_DIR/system.sh" ]]; then
        data+=$("$COLLECT_DIR/system.sh" 2>/dev/null || echo "=== SYSTEM DATA === Error collecting ==="
)
        data+=$'\n'
    else
        # Inline collection if script not installed
        data+="=== SYSTEM DATA ==="$'\n'
        data+="OS_VERSION:"$'\n'
        if [[ -f /etc/os-release ]]; then
            data+=$(grep -E "^(NAME|VERSION|PRETTY_NAME)=" /etc/os-release 2>/dev/null || echo "  Unknown")
            data+=$'\n'
        fi
        data+="UPTIME:"$'\n'
        data+=$(uptime -p 2>/dev/null || echo "  Unknown")
        data+=$'\n'
        data+="LOAD_AVERAGES:"$'\n'
        if [[ -f /proc/loadavg ]]; then
            data+=$(cat /proc/loadavg | awk '{print "  1min: "$1", 5min: "$2", 15min: "$3}')
            data+=$'\n'
        fi
        data+="DISK_USAGE:"$'\n'
        data+=$(df -h / 2>/dev/null | tail -1 | awk '{print "  Total: "$2", Used: "$3", Available: "$4", Use%: "$5}' || echo "  Unknown")
        data+=$'\n'
        data+="=== END SYSTEM DATA ==="$'\n'
    fi
    
    # Collect sandbox data
    if [[ -x "$COLLECT_DIR/sandbox.sh" ]]; then
        data+=$("$COLLECT_DIR/sandbox.sh" 2>/dev/null || echo "=== SANDBOX DATA === Error collecting ==="
)
        data+=$'\n'
    else
        data+="=== SANDBOX DATA ==="$'\n'
        data+="ACTIVE_SANDBOXES:"$'\n'
        if [[ -d /var/lib/carina/sandbox ]]; then
            active_count=$(find /var/lib/carina/sandbox -name "*.state" 2>/dev/null | wc -l)
            data+="  Count: $active_count"$'\n'
        else
            data+="  Count: 0"$'\n'
        fi
        data+="=== END SANDBOX DATA ==="$'\n'
    fi
    
    # Collect MissionLab data
    if [[ -x "$COLLECT_DIR/missionlab.sh" ]]; then
        data+=$("$COLLECT_DIR/missionlab.sh" 2>/dev/null || echo "=== MISSIONLAB DATA === Error collecting ==="
)
        data+=$'\n'
    else
        data+="=== MISSIONLAB DATA ==="$'\n'
        data+="INSTALLED_TOOLS:"$'\n'
        command -v arduino-cli &>/dev/null && data+="  arduino-cli: installed"$'\n' || data+="  arduino-cli: not installed"$'\n'
        command -v pio &>/dev/null && data+="  platformio: installed"$'\n' || data+="  platformio: not installed"$'\n'
        data+="=== END MISSIONLAB DATA ==="$'\n'
    fi
    
    # Collect log data
    if [[ -x "$COLLECT_DIR/logs.sh" ]]; then
        data+=$("$COLLECT_DIR/logs.sh" 2>/dev/null || echo "=== LOG DATA === Error collecting ==="
)
        data+=$'\n'
    else
        data+="=== LOG DATA ==="$'\n'
        data+="SANDBOX_LOG_SUMMARY:"$'\n'
        if [[ -f /var/log/carina-sandbox.log ]]; then
            total_lines=$(wc -l < /var/log/carina-sandbox.log 2>/dev/null || echo "0")
            data+="  Total entries: $total_lines"$'\n'
        else
            data+="  Log file not found"$'\n'
        fi
        data+="=== END LOG DATA ==="$'\n'
    fi
    
    echo "$data"
}

generate_advisory() {
    local data="$1"
    
    echo -e "${CYAN}CARINA Control Advisory Report${NC}"
    echo ""
    echo -e "${BLUE}Observations:${NC}"
    
    # Parse and analyze collected data
    local observations=""
    local recommendations=""
    
    # System observations
    if echo "$data" | grep -q "LOAD_AVERAGES:"; then
        load=$(echo "$data" | grep -A1 "LOAD_AVERAGES:" | tail -1 | grep -oP '1min: \K[0-9.]+' || echo "0")
        if [[ -n "$load" ]]; then
            load_int=${load%.*}
            if [[ $load_int -gt 2 ]]; then
                observations+="- System load is elevated ($load)"$'\n'
                recommendations+="1. Consider reviewing running processes or scaling resources."$'\n'
            else
                observations+="- System load is normal ($load)"$'\n'
            fi
        fi
    fi
    
    # Disk usage observations
    if echo "$data" | grep -q "DISK_USAGE:"; then
        disk_pct=$(echo "$data" | grep -A1 "DISK_USAGE:" | tail -1 | grep -oP 'Use%: \K[0-9]+' || echo "0")
        if [[ -n "$disk_pct" && $disk_pct -gt 80 ]]; then
            observations+="- Disk usage is high (${disk_pct}%)"$'\n'
            recommendations+="- Consider cleaning up old files or expanding storage."$'\n'
        elif [[ -n "$disk_pct" ]]; then
            observations+="- Disk usage is healthy (${disk_pct}%)"$'\n'
        fi
    fi
    
    # Sandbox observations
    if echo "$data" | grep -q "ACTIVE_SANDBOXES:"; then
        sandbox_count=$(echo "$data" | grep -A1 "ACTIVE_SANDBOXES:" | grep "Count:" | grep -oP 'Count: \K[0-9]+' || echo "0")
        if [[ $sandbox_count -gt 0 ]]; then
            observations+="- $sandbox_count active sandbox(es) running"$'\n'
        else
            observations+="- No active sandboxes"$'\n'
        fi
    fi
    
    # Check for expired sandboxes
    if echo "$data" | grep -q "RECENTLY_EXPIRED:"; then
        expired=$(echo "$data" | grep -A1 "Total destroyed:" | grep "Total destroyed:" | grep -oP 'Total destroyed: \K[0-9]+' || echo "0")
        if [[ $expired -gt 5 ]]; then
            observations+="- $expired sandboxes have been destroyed (cleanup working)"$'\n'
        fi
    fi
    
    # MissionLab observations
    arduino_installed=$(echo "$data" | grep -q "arduino-cli: installed" && echo "yes" || echo "no")
    platformio_installed=$(echo "$data" | grep -q "platformio: installed" && echo "yes" || echo "no")
    
    if [[ "$arduino_installed" == "yes" ]]; then
        observations+="- Arduino CLI is installed"$'\n'
    else
        observations+="- Arduino CLI is not installed"$'\n'
        recommendations+="- Consider installing Arduino CLI with: carina missionlab install arduino-cli"$'\n'
    fi
    
    if [[ "$platformio_installed" == "yes" ]]; then
        observations+="- PlatformIO is installed"$'\n'
    fi
    
    # Permission observations
    if echo "$data" | grep -q "dialout: not member"; then
        observations+="- User is not in dialout group (serial access may fail)"$'\n'
        recommendations+="- Add user to dialout group for serial device access: sudo usermod -aG dialout \$USER"$'\n'
    fi
    
    if echo "$data" | grep -q "plugdev: not member"; then
        observations+="- User is not in plugdev group (USB access may fail)"$'\n'
        recommendations+="- Add user to plugdev group for USB device access: sudo usermod -aG plugdev \$USER"$'\n'
    fi
    
    # Device observations
    if echo "$data" | grep -q "Serial devices: 0"; then
        observations+="- No serial devices detected"$'\n'
    fi
    
    # Log observations
    if echo "$data" | grep -q "Errors/Warnings:" && echo "$data" | grep -A1 "Errors/Warnings:" | grep -q "Count: [1-9]"; then
        error_count=$(echo "$data" | grep -A1 "Errors/Warnings:" | grep "Count:" | head -1 | grep -oP 'Count: \K[0-9]+' || echo "0")
        if [[ $error_count -gt 0 ]]; then
            observations+="- $error_count errors/warnings found in logs"$'\n'
            recommendations+="- Review log files for details: /var/log/carina-sandbox.log, /var/log/carina-missionlab.log"$'\n'
        fi
    fi
    
    # Print observations
    if [[ -n "$observations" ]]; then
        echo "$observations"
    else
        echo "- System appears healthy"
        echo "- No issues detected in collected data"
    fi
    
    echo ""
    echo -e "${BLUE}Recommendations:${NC}"
    
    # Print recommendations
    if [[ -n "$recommendations" ]]; then
        echo "$recommendations"
    else
        echo "- No immediate actions recommended"
        echo "- Continue monitoring system health with: carina doctor"
    fi
    
    echo ""
    echo -e "${MAGENTA}No actions were taken.${NC}"
}

cmd_advise() {
    echo "Collecting system data..."
    echo ""
    
    # Collect all data
    local collected_data
    collected_data=$(collect_all_data)
    
    # Log the advisory run (not the content)
    log_advisory "success" "system,sandbox,missionlab,logs"
    
    # Generate and display advisory
    generate_advisory "$collected_data"
}

# Main entry point
main() {
    local cmd="${1:-help}"
    
    case "$cmd" in
        status)
            cmd_status
            ;;
        advise)
            cmd_advise
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            echo -e "${MAGENTA}ERROR${NC}: Unknown command: $cmd"
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
