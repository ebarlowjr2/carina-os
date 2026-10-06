#!/bin/bash
#
# CARINA OS Bootstrap Script
# Converts Ubuntu Server 24.04 → CARINA Core
#
# This script is idempotent and safe to re-run.
#

set -e

LOGFILE="/var/log/carina-bootstrap.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CARINA_VERSION="$(cat "$REPO_DIR/VERSION" 2>/dev/null || echo "0.4.0")"

# The pristine Ubuntu identity. /etc/os-release is diverted to CARINA's
# own file; this one stays owned by base-files and tracks Ubuntu updates.
UBUNTU_OS_RELEASE="/usr/lib/os-release"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "$LOGFILE"
}

error() {
    log "ERROR: $1"
    exit 1
}

# Print one field of an os-release file without polluting this shell
os_release_field() {
    (
        # shellcheck disable=SC1090
        . "$1" 2>/dev/null || exit 0
        printf '%s\n' "${!2:-}"
    )
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
    
    local current_id
    current_id=$(os_release_field /etc/os-release ID)
    if [[ "$current_id" != "ubuntu" ]] && [[ "$current_id" != "carina" ]]; then
        error "This script requires Ubuntu (found: $current_id)"
    fi
    
    if [[ "$current_id" == "carina" ]]; then
        log "CARINA OS already installed, continuing with update..."
    fi
    
    # Version check against the underlying Ubuntu release. On a system
    # converted by an older bootstrap this file may itself say CARINA;
    # apply_identity repairs that, so only enforce when it says Ubuntu.
    local ubuntu_id ubuntu_version
    ubuntu_id=$(os_release_field "$UBUNTU_OS_RELEASE" ID)
    if [[ "$ubuntu_id" == "ubuntu" ]]; then
        ubuntu_version=$(os_release_field "$UBUNTU_OS_RELEASE" VERSION_ID)
        if [[ "${ubuntu_version%%.*}" -lt 24 ]]; then
            error "Ubuntu 24.04 or later required (found: $ubuntu_version)"
        fi
        log "Ubuntu $ubuntu_version base detected"
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
    # Single apt-get update for the entire bootstrap (avoid redundant calls later)
    apt-get update -qq
    # Combined base + core profile packages in a single apt-get call
    # to avoid a second apt-get update + install cycle during profile apply
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
        dbus-x11 \
        rsyslog \
        logrotate
    log "Base packages installed"
}

install_podman() {
    log "Installing Podman for sandbox support..."
    
    if command -v podman &>/dev/null; then
        log "Podman already installed: $(podman --version)"
        return 0
    fi
    
    # apt-get update already ran in install_base_packages, no need to repeat
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
    
    cp "$REPO_DIR/VERSION" /opt/carina/VERSION
    
    # Shared libraries (device detection, package lists, firewall policy)
    mkdir -p /opt/carina/lib
    cp "$REPO_DIR/lib/"*.sh /opt/carina/lib/
    log "CARINA libraries installed"
    
    # Hardware packs (replace wholesale so removed packs don't linger)
    rm -rf /opt/carina/hardware
    mkdir -p /opt/carina/hardware
    if [[ -d "$REPO_DIR/hardware" ]]; then
        cp -r "$REPO_DIR/hardware/"* /opt/carina/hardware/
        chmod +x /opt/carina/hardware/*/config.sh 2>/dev/null || true
        log "Hardware packs installed"
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

# Fill a branding template's @PLACEHOLDERS@ into a temp file in /etc and
# print its path
render_branding() {
    local template="$1" ubuntu_version="$2" ubuntu_codename="$3" tmp
    tmp=$(mktemp /etc/.carina-branding.XXXXXX)
    sed -e "s/@CARINA_VERSION@/${CARINA_VERSION}/g" \
        -e "s/@UBUNTU_VERSION_ID@/${ubuntu_version}/g" \
        -e "s/@UBUNTU_CODENAME@/${ubuntu_codename}/g" \
        "$template" > "$tmp"
    chmod 644 "$tmp"
    echo "$tmp"
}

# Replace a base-files owned file with CARINA's version. The package's copy
# is diverted to <file>.ubuntu, so Ubuntu upgrades update that copy and
# leave CARINA's file alone. Writing over these files directly (as older
# bootstraps did with /etc/os-release, writing through its symlink into
# /usr/lib/os-release) gets reverted by every base-files update.
install_diverted() {
    local target="$1" new_file="$2"
    if ! dpkg-divert --list "$target" | grep -q "${target}.ubuntu"; then
        # Keep Ubuntu's file (or symlink) alongside before diverting, so the
        # target is never missing (--no-rename leaves it in place)
        if [[ -e "$target" || -L "$target" ]] && [[ ! -e "${target}.ubuntu" && ! -L "${target}.ubuntu" ]]; then
            cp -P -p "$target" "${target}.ubuntu"
        fi
        dpkg-divert --local --no-rename --divert "${target}.ubuntu" --add "$target" >/dev/null
        log "Diverted $target (Ubuntu copy kept at ${target}.ubuntu)"
    fi
    # Atomic replace
    mv "$new_file" "$target"
}

apply_identity() {
    log "Applying CARINA identity..."
    
    repair_ubuntu_os_release
    
    local ubuntu_version ubuntu_codename
    ubuntu_version=$(os_release_field "$UBUNTU_OS_RELEASE" VERSION_ID)
    ubuntu_codename=$(os_release_field "$UBUNTU_OS_RELEASE" UBUNTU_CODENAME)
    [[ -n "$ubuntu_codename" ]] || ubuntu_codename=$(os_release_field "$UBUNTU_OS_RELEASE" VERSION_CODENAME)
    if [[ -z "$ubuntu_codename" ]]; then
        error "Cannot determine Ubuntu codename from $UBUNTU_OS_RELEASE"
    fi
    
    # Keep ID_LIKE and the codenames so tooling that keys off them (ROS,
    # Docker and NodeSource apt setup, ubuntu-drivers, PPAs) still works
    local tmp
    tmp=$(render_branding "$REPO_DIR/branding/os-release" "$ubuntu_version" "$ubuntu_codename")
    install_diverted /etc/os-release "$tmp"
    log "os-release updated (CARINA $CARINA_VERSION on Ubuntu $ubuntu_version $ubuntu_codename)"
    
    # Console login banner (/etc/issue) and network login banner
    local issue
    for issue in issue issue.net; do
        if [[ -f "$REPO_DIR/branding/$issue" ]]; then
            tmp=$(render_branding "$REPO_DIR/branding/$issue" "$ubuntu_version" "$ubuntu_codename")
            install_diverted "/etc/$issue" "$tmp"
        fi
    done
    log "Login banners updated"
    
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

# Older bootstraps copied CARINA's os-release through the /etc/os-release
# symlink, overwriting /usr/lib/os-release. Put Ubuntu's back.
repair_ubuntu_os_release() {
    if [[ "$(os_release_field "$UBUNTU_OS_RELEASE" ID)" == "ubuntu" ]]; then
        return 0
    fi
    log "Restoring Ubuntu identity in $UBUNTU_OS_RELEASE (overwritten by an older bootstrap)..."
    if [[ -f /etc/os-release.ubuntu.bak ]] && [[ "$(os_release_field /etc/os-release.ubuntu.bak ID)" == "ubuntu" ]]; then
        cp /etc/os-release.ubuntu.bak "$UBUNTU_OS_RELEASE"
    else
        apt-get install -y -qq --reinstall base-files >/dev/null
    fi
    if [[ "$(os_release_field "$UBUNTU_OS_RELEASE" ID)" != "ubuntu" ]]; then
        error "Could not restore $UBUNTU_OS_RELEASE (try: sudo apt-get install --reinstall base-files)"
    fi
    rm -f /etc/os-release.ubuntu.bak
    log "Ubuntu identity restored"
}

setup_gnome_branding() {
    log "Setting up GNOME desktop branding..."
    
    # Install wallpaper to system location and track which file was installed
    local WALLPAPER_FILE=""
    mkdir -p /usr/share/backgrounds/carina
    if [[ -f "$REPO_DIR/branding/wallpapers/carina-linux-banner.png" ]]; then
        cp "$REPO_DIR/branding/wallpapers/carina-linux-banner.png" /usr/share/backgrounds/carina/
        WALLPAPER_FILE="carina-linux-banner.png"
        log "Wallpaper installed to /usr/share/backgrounds/carina/"
    elif [[ -f "$REPO_DIR/branding/wallpapers/carina-void.jpg" ]]; then
        cp "$REPO_DIR/branding/wallpapers/carina-void.jpg" /usr/share/backgrounds/carina/
        WALLPAPER_FILE="carina-void.jpg"
        log "Fallback wallpaper installed to /usr/share/backgrounds/carina/"
    else
        log "WARN: No wallpaper found, skipping GNOME branding"
        return 0
    fi
    
    local WALLPAPER_PATH="/usr/share/backgrounds/carina/${WALLPAPER_FILE}"
    
    # Create GNOME background XML for wallpaper picker
    mkdir -p /usr/share/gnome-background-properties
    cat > /usr/share/gnome-background-properties/carina.xml << BGXML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
<wallpapers>
  <wallpaper deleted="false">
    <name>CARINA Linux</name>
    <filename>${WALLPAPER_PATH}</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#0D0D0D</pcolor>
    <scolor>#0D0D0D</scolor>
  </wallpaper>
</wallpapers>
BGXML
    log "GNOME wallpaper picker entry created"
    
    # Set up dconf profile for system-wide defaults
    mkdir -p /etc/dconf/profile
    cat > /etc/dconf/profile/user << 'DCONF_PROFILE'
user-db:user
system-db:carina
DCONF_PROFILE
    log "dconf profile created"
    
    # Create dconf database with CARINA defaults
    mkdir -p /etc/dconf/db/carina.d
    cat > /etc/dconf/db/carina.d/00-background << DCONF_BG
[org/gnome/desktop/background]
picture-uri='file://${WALLPAPER_PATH}'
picture-uri-dark='file://${WALLPAPER_PATH}'
picture-options='zoom'
primary-color='#0D0D0D'
secondary-color='#0D0D0D'

[org/gnome/desktop/screensaver]
picture-uri='file://${WALLPAPER_PATH}'
picture-options='zoom'
primary-color='#0D0D0D'
secondary-color='#0D0D0D'
DCONF_BG
    log "dconf background settings created"
    
    # Lock the background settings (optional - comment out if users should be able to change)
    # mkdir -p /etc/dconf/db/carina.d/locks
    # echo "/org/gnome/desktop/background/picture-uri" > /etc/dconf/db/carina.d/locks/background
    
    # Update dconf database
    if command -v dconf &>/dev/null; then
        dconf update 2>/dev/null || true
        log "dconf database updated"
    else
        log "WARN: dconf not available, will be applied on next boot with GUI"
    fi
    
    # Also set GDM (login screen) background if GDM is installed
    if [[ -d /etc/gdm3 ]]; then
        mkdir -p /etc/dconf/db/gdm.d
        cat > /etc/dconf/db/gdm.d/00-carina-background << GDM_BG
[org/gnome/desktop/background]
picture-uri='file://${WALLPAPER_PATH}'
picture-options='zoom'
primary-color='#0D0D0D'
GDM_BG
        dconf update 2>/dev/null || true
        log "GDM login screen background configured"
    fi
    
    log "GNOME desktop branding configured"
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
    
    # Hardware detection refreshes /etc/carina/device.conf on every boot
    if [[ -f "$REPO_DIR/system/carina-detect.service" ]]; then
        cp "$REPO_DIR/system/carina-detect.service" /etc/systemd/system/carina-detect.service
        systemctl daemon-reload
        systemctl enable carina-detect.service 2>/dev/null || true
        log "Hardware detection service enabled"
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
    
    # Run core profile config directly instead of through CLI to avoid
    # a redundant apt-get update + package install cycle.
    # Base packages from core/packages.txt overlap with install_base_packages()
    # so we only need to run the config.sh portion.
    local core_config="/opt/carina/profiles/core/config.sh"
    if [[ -f "$core_config" ]]; then
        log "Running core profile configuration..."
        bash "$core_config"
        log "Core profile configuration complete"
    elif command -v carina &>/dev/null; then
        carina profile apply core
    else
        log "WARN: Core profile config not available, skipping"
    fi
}

apply_hardware_packs() {
    log "Detecting hardware..."
    carina device detect --quiet || log "WARN: Hardware detection failed"
    
    if [[ "${CARINA_SKIP_HW:-0}" == "1" ]]; then
        log "CARINA_SKIP_HW=1, not applying hardware packs"
        return 0
    fi
    
    # Apply every pack that matches this machine (e.g. hw-laptop)
    if carina device apply; then
        log "Hardware packs applied"
    else
        log "WARN: Hardware pack apply failed; re-run with: sudo carina device apply"
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
    setup_gnome_branding
    setup_firstboot
    apply_core_profile
    apply_hardware_packs
    
    log "========================================"
    log "CARINA OS bootstrap complete!"
    log "========================================"
    log ""
    log "Run 'carina doctor' to verify installation"
    log "Run 'carina profile list' to see available profiles"
    
    echo ""
    echo "Bootstrap complete. Please log out and back in to see CARINA branding."
}

# Allow tests to source this file for its functions
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
