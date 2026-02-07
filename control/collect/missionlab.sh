#!/bin/bash
#
# CARINA Control - MissionLab Data Collector
# Collects MissionLab state for advisory analysis
#
# Security: Read-only, no execution, no modification
#

set -e

MISSIONLAB_LOG="/var/log/carina-missionlab.log"

collect_missionlab_data() {
    echo "=== MISSIONLAB DATA ==="
    
    # Installed tools
    echo "INSTALLED_TOOLS:"
    
    # Check Arduino CLI
    if command -v arduino-cli &>/dev/null; then
        version=$(arduino-cli version 2>/dev/null | head -1 || echo "unknown")
        echo "  arduino-cli: installed ($version)"
    else
        echo "  arduino-cli: not installed"
    fi
    
    # Check PlatformIO
    if command -v pio &>/dev/null || command -v platformio &>/dev/null; then
        version=$(pio --version 2>/dev/null || platformio --version 2>/dev/null || echo "unknown")
        echo "  platformio: installed ($version)"
    else
        echo "  platformio: not installed"
    fi
    
    # Check avrdude
    if command -v avrdude &>/dev/null; then
        echo "  avrdude: installed"
    else
        echo "  avrdude: not installed"
    fi
    
    # Check openocd
    if command -v openocd &>/dev/null; then
        echo "  openocd: installed"
    else
        echo "  openocd: not installed"
    fi
    
    # Check minicom
    if command -v minicom &>/dev/null; then
        echo "  minicom: installed"
    else
        echo "  minicom: not installed"
    fi
    
    # Commonly expected but missing tools
    echo "COMMONLY_EXPECTED:"
    missing=""
    command -v arduino-cli &>/dev/null || missing="$missing arduino-cli"
    command -v pio &>/dev/null || command -v platformio &>/dev/null || missing="$missing platformio"
    command -v avrdude &>/dev/null || missing="$missing avrdude"
    command -v openocd &>/dev/null || missing="$missing openocd"
    command -v minicom &>/dev/null || missing="$missing minicom"
    
    if [[ -z "$missing" ]]; then
        echo "  All common tools installed"
    else
        echo "  Missing:$missing"
    fi
    
    # Permission readiness (groups)
    echo "PERMISSION_READINESS:"
    current_user=$(whoami)
    
    # Check dialout group (serial access)
    if groups "$current_user" 2>/dev/null | grep -q dialout; then
        echo "  dialout: member (serial access OK)"
    else
        echo "  dialout: not member (serial access may fail)"
    fi
    
    # Check plugdev group (USB device access)
    if groups "$current_user" 2>/dev/null | grep -q plugdev; then
        echo "  plugdev: member (USB access OK)"
    else
        echo "  plugdev: not member (USB access may fail)"
    fi
    
    # Check carina group
    if groups "$current_user" 2>/dev/null | grep -q carina; then
        echo "  carina: member"
    else
        echo "  carina: not member"
    fi
    
    # udev rules status
    echo "UDEV_RULES:"
    if [[ -f /etc/udev/rules.d/99-carina-serial.rules ]]; then
        echo "  99-carina-serial.rules: present"
    else
        echo "  99-carina-serial.rules: missing"
    fi
    
    if [[ -f /etc/udev/rules.d/99-carina-usb.rules ]]; then
        echo "  99-carina-usb.rules: present"
    else
        echo "  99-carina-usb.rules: missing"
    fi
    
    # Connected devices (read-only check)
    echo "CONNECTED_DEVICES:"
    if [[ -d /dev/serial/by-id ]]; then
        device_count=$(ls /dev/serial/by-id 2>/dev/null | wc -l)
        echo "  Serial devices: $device_count"
        if [[ $device_count -gt 0 ]]; then
            ls /dev/serial/by-id 2>/dev/null | while read -r dev; do
                echo "    - $dev"
            done
        fi
    else
        echo "  Serial devices: 0 (no /dev/serial/by-id)"
    fi
    
    echo "=== END MISSIONLAB DATA ==="
}

# Run collector
collect_missionlab_data
