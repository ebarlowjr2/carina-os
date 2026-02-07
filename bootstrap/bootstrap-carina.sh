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
        xxd
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
    
    # Install MissionLab installers and lib
    mkdir -p /opt/carina/missionlab/installers
    mkdir -p /opt/carina/missionlab/lib
    
    if [[ -d "$REPO_DIR/missionlab/installers" ]]; then
        cp -r "$REPO_DIR/missionlab/installers/"* /opt/carina/missionlab/installers/
        chmod +x /opt/carina/missionlab/installers/*.sh 2>/dev/null || true
        log "MissionLab installers installed"
    fi
    
    if [[ -d "$REPO_DIR/missionlab/lib" ]]; then
        cp -r "$REPO_DIR/missionlab/lib/"* /opt/carina/missionlab/lib/
        chmod +x /opt/carina/missionlab/lib/*.sh 2>/dev/null || true
        log "MissionLab lib installed"
    fi
    
    # Setup MissionLab log file
    touch /var/log/carina-missionlab.log
    chown root:carina /var/log/carina-missionlab.log 2>/dev/null || true
    chmod 664 /var/log/carina-missionlab.log
    log "MissionLab log file created"
    
    # Setup logrotate for MissionLab logs
    cat > /etc/logrotate.d/carina-missionlab << 'LOGROTATE'
/var/log/carina-missionlab.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    create 664 root carina
}
LOGROTATE
    log "Logrotate configured for MissionLab logs"
    
    # Link MissionLab profiles to main profiles directory
    if [[ -d /opt/carina/missionlab/profiles/embedded ]]; then
        ln -sf /opt/carina/missionlab/profiles/embedded /opt/carina/profiles/missionlab-embedded
    fi
    if [[ -d /opt/carina/missionlab/profiles/robotics ]]; then
        ln -sf /opt/carina/missionlab/profiles/robotics /opt/carina/profiles/missionlab-robotics
    fi
    log "MissionLab profiles linked"
    
    # Install MissionLab installers and lib
    mkdir -p /opt/carina/missionlab/installers
    mkdir -p /opt/carina/missionlab/lib
    
    if [[ -d "$REPO_DIR/missionlab/installers" ]]; then
        cp -r "$REPO_DIR/missionlab/installers/"* /opt/carina/missionlab/installers/
        chmod +x /opt/carina/missionlab/installers/*.sh 2>/dev/null || true
        log "MissionLab installers installed"
    fi
    
    if [[ -d "$REPO_DIR/missionlab/lib" ]]; then
        cp -r "$REPO_DIR/missionlab/lib/"* /opt/carina/missionlab/lib/
        chmod +x /opt/carina/missionlab/lib/*.sh 2>/dev/null || true
        log "MissionLab lib installed"
    fi
    
    # Setup MissionLab log file
    touch /var/log/carina-missionlab.log
    chown root:carina /var/log/carina-missionlab.log 2>/dev/null || true
    chmod 664 /var/log/carina-missionlab.log
    log "MissionLab log file created"
    
    # Setup logrotate for MissionLab logs
    cat > /etc/logrotate.d/carina-missionlab << 'LOGROTATE'
/var/log/carina-missionlab.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    create 664 root carina
}
LOGROTATE
    log "Logrotate configured for MissionLab logs"
    
    # Install branding assets (desktop entries, icons)
    mkdir -p /opt/carina/branding/desktop
    mkdir -p /opt/carina/branding/icons
    
    if [[ -d "$REPO_DIR/branding/desktop" ]]; then
        cp -r "$REPO_DIR/branding/desktop/"* /opt/carina/branding/desktop/
        log "Desktop entries staged"
    fi
    
    if [[ -d "$REPO_DIR/branding/icons" ]]; then
        cp -r "$REPO_DIR/branding/icons/"* /opt/carina/branding/icons/
        log "Icons staged"
    fi
    
    # Install Mission Manual documentation
    mkdir -p /usr/share/doc/carina/manual
    if [[ -d "$REPO_DIR/docs/manual" ]]; then
        cp -r "$REPO_DIR/docs/manual/"* /usr/share/doc/carina/manual/
        log "Mission Manual installed to /usr/share/doc/carina/manual/"
    fi
    
    # Create HTML version of Mission Manual if pandoc is available
    if command -v pandoc &>/dev/null && [[ -f /usr/share/doc/carina/manual/mission-manual.md ]]; then
        pandoc /usr/share/doc/carina/manual/mission-manual.md \
            -o /usr/share/doc/carina/manual/mission-manual.html \
            --standalone \
            --metadata title="CARINA Mission Manual" \
            2>/dev/null || true
        log "Mission Manual HTML generated"
    fi
    
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

disable_ubuntu_telemetry() {
    log "Disabling Ubuntu telemetry and error reporting..."
    
    # Disable apport (crash reporting)
    if [[ -f /etc/default/apport ]]; then
        echo "enabled=0" > /etc/default/apport
    fi
    systemctl stop apport 2>/dev/null || true
    systemctl disable apport 2>/dev/null || true
    systemctl mask apport 2>/dev/null || true
    
    # Disable motd-news (Ubuntu news in MOTD)
    systemctl stop motd-news.timer 2>/dev/null || true
    systemctl disable motd-news.timer 2>/dev/null || true
    systemctl mask motd-news.timer 2>/dev/null || true
    systemctl mask motd-news.service 2>/dev/null || true
    
    # Remove Ubuntu telemetry packages
    apt-get remove -y whoopsie ubuntu-report popularity-contest 2>/dev/null || true
    
    # Clear any existing crash reports
    rm -f /var/crash/* 2>/dev/null || true
    
    log "Ubuntu telemetry disabled"
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
    disable_ubuntu_telemetry
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
