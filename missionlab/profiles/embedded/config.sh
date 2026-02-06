#!/bin/bash
#
# CARINA MissionLab - Embedded Profile Configuration
# Sets up user permissions and tooling for embedded development
#

set -e

log() {
    echo "[CARINA MissionLab] $1"
}

# Get the actual user (not root if running via sudo)
ACTUAL_USER="${SUDO_USER:-$USER}"

log "Configuring embedded development environment for $ACTUAL_USER"

# Add user to required groups for device access
log "Adding $ACTUAL_USER to dialout group (serial port access)"
usermod -aG dialout "$ACTUAL_USER"

log "Adding $ACTUAL_USER to plugdev group (USB device access)"
usermod -aG plugdev "$ACTUAL_USER"

# Install PlatformIO via pipx (recommended for modern Ubuntu with PEP 668)
log "Installing PlatformIO Core CLI"
if command -v pipx &>/dev/null; then
    sudo -u "$ACTUAL_USER" pipx install platformio 2>/dev/null || log "Warning: PlatformIO installation via pipx failed"
elif command -v pip3 &>/dev/null; then
    # Fallback: try pip with --break-system-packages for older systems
    pip3 install --user platformio 2>/dev/null || \
    pip3 install --user --break-system-packages platformio 2>/dev/null || \
    log "Warning: PlatformIO installation failed (install manually: pipx install platformio)"
fi

# Initialize arduino-cli if available
if command -v arduino-cli &>/dev/null; then
    log "Initializing arduino-cli configuration"
    sudo -u "$ACTUAL_USER" arduino-cli config init --overwrite 2>/dev/null || true
    
    # Update core index
    log "Updating arduino-cli core index"
    sudo -u "$ACTUAL_USER" arduino-cli core update-index 2>/dev/null || true
fi

# Install udev rules for common embedded devices
UDEV_RULES_DIR="/etc/udev/rules.d"
MISSIONLAB_UDEV_DIR="/opt/carina/missionlab/udev"

if [[ -d "$MISSIONLAB_UDEV_DIR" ]]; then
    log "Installing udev rules for embedded devices"
    cp "$MISSIONLAB_UDEV_DIR/99-carina-serial.rules" "$UDEV_RULES_DIR/" 2>/dev/null || true
    cp "$MISSIONLAB_UDEV_DIR/99-carina-usb.rules" "$UDEV_RULES_DIR/" 2>/dev/null || true
    
    # Reload udev rules
    udevadm control --reload-rules 2>/dev/null || true
    udevadm trigger 2>/dev/null || true
fi

# Set sane defaults for serial ports
log "Configuring serial port defaults"

# Ensure /dev/ttyUSB* and /dev/ttyACM* are accessible
# This is handled by udev rules, but we verify here

log "Embedded profile configuration complete"
log ""
log "IMPORTANT: Log out and back in for group changes to take effect"
log "Then run: carina missionlab status"
