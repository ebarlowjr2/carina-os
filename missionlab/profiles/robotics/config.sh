#!/bin/bash
#
# CARINA MissionLab - Robotics Profile Configuration
# Sets up ROS2 development environment (tooling only, not full desktop)
#

set -e

log() {
    echo "[CARINA MissionLab] $1"
}

# Get the actual user (not root if running via sudo)
ACTUAL_USER="${SUDO_USER:-$USER}"

log "Configuring robotics development environment for $ACTUAL_USER"

# Add user to required groups
log "Adding $ACTUAL_USER to dialout group (serial port access)"
usermod -aG dialout "$ACTUAL_USER"

log "Adding $ACTUAL_USER to plugdev group (USB device access)"
usermod -aG plugdev "$ACTUAL_USER"

# Initialize rosdep if available (non-destructive)
if command -v rosdep &>/dev/null; then
    log "Initializing rosdep"
    # Only init if not already initialized
    if [[ ! -d /etc/ros/rosdep/sources.list.d ]]; then
        rosdep init 2>/dev/null || log "rosdep already initialized or init failed"
    fi
    
    # Update rosdep as the actual user
    log "Updating rosdep database"
    sudo -u "$ACTUAL_USER" rosdep update 2>/dev/null || log "rosdep update skipped"
fi

# Setup ROS2 environment hints (but don't auto-source)
ROS2_SETUP_HINT="/etc/carina/ros2-setup-hint.sh"
mkdir -p /etc/carina

cat > "$ROS2_SETUP_HINT" << 'EOF'
# CARINA MissionLab - ROS2 Environment Setup Hint
#
# To use ROS2, source the appropriate setup file:
#
# For ROS2 Humble (Ubuntu 22.04):
#   source /opt/ros/humble/setup.bash
#
# For ROS2 Jazzy (Ubuntu 24.04):
#   source /opt/ros/jazzy/setup.bash
#
# Add to your ~/.bashrc for automatic sourcing:
#   echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
#
# CARINA does NOT auto-source ROS2 to avoid environment conflicts.
EOF

log "ROS2 setup hints written to $ROS2_SETUP_HINT"

# Install udev rules (shared with embedded)
UDEV_RULES_DIR="/etc/udev/rules.d"
MISSIONLAB_UDEV_DIR="/opt/carina/missionlab/udev"

if [[ -d "$MISSIONLAB_UDEV_DIR" ]]; then
    log "Installing udev rules for device access"
    cp "$MISSIONLAB_UDEV_DIR/99-carina-serial.rules" "$UDEV_RULES_DIR/" 2>/dev/null || true
    cp "$MISSIONLAB_UDEV_DIR/99-carina-usb.rules" "$UDEV_RULES_DIR/" 2>/dev/null || true
    
    udevadm control --reload-rules 2>/dev/null || true
    udevadm trigger 2>/dev/null || true
fi

log "Robotics profile configuration complete"
log ""
log "IMPORTANT: Log out and back in for group changes to take effect"
log "Then run: carina missionlab status"
log ""
log "Note: ROS2 is NOT auto-sourced. See $ROS2_SETUP_HINT for setup instructions."
