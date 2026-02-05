#!/bin/bash
#
# CARINA OS Bootstrap Script
# Converts Ubuntu Server 24.04 → CARINA Core
#
# This script is idempotent and safe to re-run.
#

set -e

LOGFILE="/var/log/carina-bootstrap.log"
CARINA_VERSION="0.1"
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
        ufw
    log "Base packages installed"
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
