#!/bin/bash
#
# CARINA OS Bootstrap Script
# Converts Ubuntu Server 24.04 → CARINA Core
#
# This script is idempotent and safe to re-run.
#

set -e

LOGFILE="/var/log/carina-bootstrap.log"
CARINA_VERSION="0.3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "$LOGFILE"
}

error() {
    log "ERROR: $1"
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

check_ubuntu() {
    log "Checking Ubuntu version..."
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot determine OS version"
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]] && [[ "$ID" != "carina" ]]; then
        error "This script requires Ubuntu (found: $ID)"
    fi
    
    if [[ "$ID" == "ubuntu" ]]; then
        local version="${VERSION_ID%%.*}"
        if [[ "$version" -lt 24 ]]; then
            error "Ubuntu 24.04 or later required (found: $VERSION_ID)"
        fi
        log "Ubuntu $VERSION_ID detected"
    else
        log "CARINA OS already installed, continuing with update..."
    fi
}

create_directories() {
    log "Creating CARINA directories..."
    mkdir -p /etc/carina
    mkdir -p /opt/carina
    mkdir -p /var/log/carina
    log "Directories created"
}

install_base_packages() {
    log "Installing base packages..."
    apt-get update -qq
    apt-get install -y -qq \
        git \
        curl \
        wget \
        vim \
        tmux \
        htop \
        jq \
        unzip \
        ca-certificates \
        gnupg \
        openssh-server \
        chrony \
        ufw \
        xxd \
        dbus-x11
    log "Base packages installed"
}

install_podman() {
    log "Installing Podman for sandbox support..."
    
    if command -v podman &>/dev/null; then
        log "Podman already installed: $(podman --version)"
        return 0
    fi
    
    apt-get install -y -qq podman
    
    if command -v podman &>/dev/null; then
        log "Podman installed: $(podman --version)"
    else
        log "WARN: Podman installation may have failed"
    fi
}

install_cli() {
    log "Installing CARINA CLI..."
    
    if [[ -f "$REPO_DIR/cli/carina" ]]; then
        cp "$REPO_DIR/cli/carina" /usr/local/bin/carina
        chmod +x /usr/local/bin/carina
        log "CLI installed from repo"
    else
        error "CLI not found at $REPO_DIR/cli/carina"
    fi
    
    mkdir -p /opt/carina/profiles
    if [[ -d "$REPO_DIR/profiles" ]]; then
        cp -r "$REPO_DIR/profiles/"* /opt/carina/profiles/
        log "Profiles installed"
    fi
    
    mkdir -p /opt/carina/sandbox/templates
    if [[ -d "$REPO_DIR/sandbox/templates" ]]; then
        cp -r "$REPO_DIR/sandbox/templates/"* /opt/carina/sandbox/templates/
        log "Sandbox templates installed"
    fi
    
    if [[ -f "$REPO_DIR/sandbox/sandbox.sh" ]]; then
        cp "$REPO_DIR/sandbox/sandbox.sh" /opt/carina/sandbox/sandbox.sh
        chmod +x /opt/carina/sandbox/sandbox.sh
    fi
    
    if [[ -f "$REPO_DIR/sandbox/cleanup.sh" ]]; then
        cp "$REPO_DIR/sandbox/cleanup.sh" /opt/carina/sandbox/cleanup.sh
        chmod +x /opt/carina/sandbox/cleanup.sh
    fi
    
    # Install MissionLab files
    mkdir -p /opt/carina/missionlab/profiles
    mkdir -p /opt/carina/missionlab/udev
    
    if [[ -d "$REPO_DIR/missionlab/profiles" ]]; then
        cp -r "$REPO_DIR/missionlab/profiles/"* /opt/carina/missionlab/profiles/
        # Make config scripts executable
        chmod +x /opt/carina/missionlab/profiles/*/config.sh 2>/dev/null || true
        log "MissionLab profiles installed"
    fi
    
    if [[ -d "$REPO_DIR/missionlab/udev" ]]; then
        cp -r "$REPO_DIR/missionlab/udev/"* /opt/carina/missionlab/udev/
        log "MissionLab udev rules staged"
    fi
    
    if [[ -f "$REPO_DIR/missionlab/device-detect.sh" ]]; then
        cp "$REPO_DIR/missionlab/device-detect.sh" /opt/carina/missionlab/device-detect.sh
        chmod +x /opt/carina/missionlab/device-detect.sh
        log "MissionLab device-detect installed"
    fi
    
    # Link MissionLab profiles to main profiles directory
    if [[ -d /opt/carina/missionlab/profiles/embedded ]]; then
        ln -sf /opt/carina/missionlab/profiles/embedded /opt/carina/profiles/missionlab-embedded
    fi
    if [[ -d /opt/carina/missionlab/profiles/robotics ]]; then
        ln -sf /opt/carina/missionlab/profiles/robotics /opt/carina/profiles/missionlab-robotics
    fi
    log "MissionLab profiles linked"
    
    # Create carina group for sandbox state/log access
    if ! getent group carina >/dev/null 2>&1; then
        groupadd carina
        log "Created carina group"
    fi
    
    # Add current sudo user to carina group if running via sudo
    if [[ -n "${SUDO_USER:-}" ]]; then
        usermod -aG carina "$SUDO_USER"
        log "Added $SUDO_USER to carina group"
    fi
    
    # Setup state directory with proper group permissions
    mkdir -p /var/lib/carina
    chown root:carina /var/lib/carina
    chmod 2775 /var/lib/carina  # setgid keeps group sticky
    if [[ ! -f /var/lib/carina/sandboxes.json ]]; then
        echo '{"sandboxes":[]}' > /var/lib/carina/sandboxes.json
    fi
    chown root:carina /var/lib/carina/sandboxes.json
    chmod 664 /var/lib/carina/sandboxes.json
    
    # Setup log directory with proper group permissions
    mkdir -p /var/log/carina
    chown root:carina /var/log/carina
    chmod 2775 /var/log/carina
    touch /var/log/carina/sandbox.log
    chown root:carina /var/log/carina/sandbox.log
    chmod 664 /var/log/carina/sandbox.log
    
    # Setup logrotate for sandbox logs
    cat > /etc/logrotate.d/carina-sandbox << 'LOGROTATE'
/var/log/carina/sandbox.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    create 664 root carina
}
LOGROTATE
    log "Logrotate configured for sandbox logs"
    
    log "Sandbox support installed"
    
    # Setup CARINA Control directories (Sprint 5A)
    mkdir -p /var/lib/carina/control
    chown root:carina /var/lib/carina/control
    chmod 2775 /var/lib/carina/control
    if [[ ! -f /var/lib/carina/control/proposals.json ]]; then
        echo '{"proposals":[],"next_id":1}' > /var/lib/carina/control/proposals.json
    fi
    chown root:carina /var/lib/carina/control/proposals.json
    chmod 664 /var/lib/carina/control/proposals.json
    
    # Setup control log file
    touch /var/log/carina-control.log
    chown root:carina /var/log/carina-control.log
    chmod 664 /var/log/carina-control.log
    
    # Setup logrotate for control logs
    cat > /etc/logrotate.d/carina-control << 'LOGROTATE'
/var/log/carina-control.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    create 664 root carina
}
LOGROTATE
    log "CARINA Control directories and logging configured"
    
    # Install control module files
    mkdir -p /opt/carina/control
    if [[ -d "$REPO_DIR/control" ]]; then
        cp -r "$REPO_DIR/control/"* /opt/carina/control/
        chmod +x /opt/carina/control/*.sh 2>/dev/null || true
        chmod +x /opt/carina/control/execution/*.sh 2>/dev/null || true
        chmod +x /opt/carina/control/collect/*.sh 2>/dev/null || true
        log "CARINA Control module installed"
    fi
    
    # Stage branding assets for FlightDeck profile
    mkdir -p /opt/carina/branding/desktop
    mkdir -p /opt/carina/branding/icons
    
    if [[ -d "$REPO_DIR/branding/desktop" ]]; then
        cp -r "$REPO_DIR/branding/desktop/"* /opt/carina/branding/desktop/ 2>/dev/null || true
        log "Desktop entries staged"
    fi
    
    if [[ -d "$REPO_DIR/branding/icons" ]]; then
        cp -r "$REPO_DIR/branding/icons/"* /opt/carina/branding/icons/ 2>/dev/null || true
        log "Icons staged"
    fi
}

apply_identity() {
    log "Applying CARINA identity..."
    
    if [[ -f "$REPO_DIR/branding/os-release" ]]; then
        cp /etc/os-release /etc/os-release.ubuntu.bak 2>/dev/null || true
        cp "$REPO_DIR/branding/os-release" /etc/os-release
        log "os-release updated"
    fi
    
    if [[ -f "$REPO_DIR/branding/motd" ]]; then
        cp "$REPO_DIR/branding/motd" /etc/motd
        log "MOTD updated"
    fi
    
    rm -f /etc/update-motd.d/00-header 2>/dev/null || true
    rm -f /etc/update-motd.d/10-help-text 2>/dev/null || true
    rm -f /etc/update-motd.d/50-motd-news 2>/dev/null || true
    rm -f /etc/update-motd.d/91-release-upgrade 2>/dev/null || true
    chmod -x /etc/update-motd.d/* 2>/dev/null || true
    
    log "Ubuntu branding removed"
}

setup_firstboot() {
    log "Setting up first-boot system..."
    
    if [[ -f "$REPO_DIR/system/firstboot.service" ]]; then
        cp "$REPO_DIR/system/firstboot.service" /etc/systemd/system/carina-firstboot.service
        log "Firstboot service installed"
    fi
    
    if [[ -f "$REPO_DIR/system/firstboot.sh" ]]; then
        cp "$REPO_DIR/system/firstboot.sh" /opt/carina/firstboot.sh
        chmod +x /opt/carina/firstboot.sh
        log "Firstboot script installed"
    fi
    
    if [[ ! -f /etc/carina/firstboot.done ]]; then
        systemctl daemon-reload
        systemctl enable carina-firstboot.service 2>/dev/null || true
        log "Firstboot service enabled"
    else
        log "Firstboot already completed, skipping enable"
    fi
}

apply_core_profile() {
    log "Applying core profile..."
    
    if command -v carina &>/dev/null; then
        carina profile apply core
    else
        log "WARN: CLI not available, skipping profile application"
    fi
}

main() {
    echo "========================================"
    echo "  CARINA OS Bootstrap"
    echo "  Version: $CARINA_VERSION"
    echo "========================================"
    
    mkdir -p "$(dirname "$LOGFILE")"
    touch "$LOGFILE"
    
    log "Starting CARINA bootstrap..."
    
    check_root
    check_ubuntu
    create_directories
    install_base_packages
    install_podman
    install_cli
    apply_identity
    setup_firstboot
    apply_core_profile
    
    log "========================================"
    log "CARINA OS bootstrap complete!"
    log "========================================"
    log ""
    log "Run 'carina doctor' to verify installation"
    log "Run 'carina profile list' to see available profiles"
    
    echo ""
    echo "Bootstrap complete. Please log out and back in to see CARINA branding."
}

main "$@"
