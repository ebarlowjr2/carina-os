#!/bin/bash
#
# CARINA hw-laptop pack configuration
# Runs as root after packages.txt is installed. Device facts (CHASSIS,
# HAS_WIFI, HAS_BLUETOOTH, HAS_DESKTOP, NETWORK_BACKEND, ...) are exported
# by 'carina device apply'.
#
# User-tunable settings live in /etc/carina/laptop.conf and
# /etc/carina/firewall.conf. Edit them, then re-run:
#   sudo carina device apply hw-laptop
#

set -e

CARINA_LIB_DIR="${CARINA_LIB_DIR:-/opt/carina/lib}"
LAPTOP_CONF="/etc/carina/laptop.conf"
FIREWALL_CONF="/etc/carina/firewall.conf"
NEEDS_REBOOT=0

log() {
    echo "[CARINA hw-laptop] $1"
}

mkdir -p /etc/carina

# ----------------------------------------------------------------------------
# Settings files (written once; user edits are preserved)
# ----------------------------------------------------------------------------

if [[ ! -f "$LAPTOP_CONF" ]]; then
    cat > "$LAPTOP_CONF" << 'EOF'
# CARINA laptop settings. Re-apply with: sudo carina device apply hw-laptop
#
# Lid close action: suspend | hibernate | poweroff | lock | ignore
# Use ignore on all three to run the laptop headless with the lid shut.
LID_ACTION=suspend
LID_ACTION_EXTERNAL_POWER=suspend
LID_ACTION_DOCKED=ignore

# Hand networking to NetworkManager (needed for Wi-Fi roaming): yes | no
USE_NETWORKMANAGER=yes
EOF
    log "Wrote $LAPTOP_CONF"
fi

if [[ ! -f "$FIREWALL_CONF" ]]; then
    cat > "$FIREWALL_CONF" << 'EOF'
# CARINA firewall policy. Re-apply with: sudo carina device apply hw-laptop
#
# SSH_RULE:  allow (open) | limit (open, rate-limited) | off (closed)
# RDP_SCOPE: any (open) | lan (private networks only) | off (closed)
#
# Note: public Wi-Fi also uses private address ranges, so "lan" limits
# exposure to the local network, not to networks you trust.
SSH_RULE=limit
RDP_SCOPE=lan
EOF
    log "Wrote $FIREWALL_CONF (roaming defaults)"
fi

LID_ACTION=suspend
LID_ACTION_EXTERNAL_POWER=suspend
LID_ACTION_DOCKED=ignore
USE_NETWORKMANAGER=yes
while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^(LID_ACTION|LID_ACTION_EXTERNAL_POWER|LID_ACTION_DOCKED)=(suspend|hibernate|poweroff|lock|ignore)$ ]] \
        || [[ "$line" =~ ^(USE_NETWORKMANAGER)=(yes|no)$ ]]; then
        printf -v "${BASH_REMATCH[1]}" '%s' "${BASH_REMATCH[2]}"
    fi
done < "$LAPTOP_CONF"

# ----------------------------------------------------------------------------
# Networking: NetworkManager
# ----------------------------------------------------------------------------

if [[ "$USE_NETWORKMANAGER" == "yes" ]] && [[ -d /etc/netplan ]]; then
    if grep -rqsi 'renderer:[[:space:]]*NetworkManager' /etc/netplan/; then
        log "Netplan already renders via NetworkManager"
    else
        # Same approach as Ubuntu Desktop: a global renderer switch. Existing
        # netplan definitions (including Wi-Fi set up in the installer) are
        # kept and become NetworkManager connections.
        cat > /etc/netplan/01-carina-network-manager.yaml << 'EOF'
# Written by CARINA hw-laptop pack: let NetworkManager manage all devices
network:
  version: 2
  renderer: NetworkManager
EOF
        chmod 600 /etc/netplan/01-carina-network-manager.yaml
        log "Netplan switched to NetworkManager (takes effect after reboot)"
        NEEDS_REBOOT=1
    fi
    systemctl enable NetworkManager 2>/dev/null || true
    # networkd no longer manages any links; waiting on it only adds a
    # timeout to every boot without a cable plugged in
    systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
fi

if [[ "${HAS_WIFI:-0}" == "1" ]] && command -v rfkill &>/dev/null; then
    rfkill unblock wifi 2>/dev/null || true
fi

# ----------------------------------------------------------------------------
# Power management
# ----------------------------------------------------------------------------

log "Enabling power management"
systemctl enable power-profiles-daemon 2>/dev/null || true
systemctl start power-profiles-daemon 2>/dev/null || true

# thermald only supports Intel CPUs; on others it fails at every boot
if systemctl list-unit-files thermald.service &>/dev/null; then
    if grep -q GenuineIntel /proc/cpuinfo 2>/dev/null; then
        systemctl enable thermald 2>/dev/null || true
        systemctl start thermald 2>/dev/null || true
    else
        systemctl disable --now thermald 2>/dev/null || true
    fi
fi

log "Configuring lid switch (lid=$LID_ACTION, on AC=$LID_ACTION_EXTERNAL_POWER, docked=$LID_ACTION_DOCKED)"
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/50-carina-laptop.conf << EOF
# Written by CARINA hw-laptop pack from $LAPTOP_CONF
[Login]
HandleLidSwitch=$LID_ACTION
HandleLidSwitchExternalPower=$LID_ACTION_EXTERNAL_POWER
HandleLidSwitchDocked=$LID_ACTION_DOCKED
EOF
# logind re-reads its config on SIGHUP without ending sessions
systemctl kill -s HUP systemd-logind 2>/dev/null || true

# Batch disk writeback to cut wakeups on battery (default is 5s)
cat > /etc/sysctl.d/60-carina-laptop.conf << 'EOF'
# CARINA hw-laptop pack
vm.dirty_writeback_centisecs = 1500
EOF
sysctl -p /etc/sysctl.d/60-carina-laptop.conf >/dev/null 2>&1 || true

# ----------------------------------------------------------------------------
# Firmware updates and Bluetooth
# ----------------------------------------------------------------------------

log "Enabling firmware update metadata refresh"
systemctl enable fwupd-refresh.timer 2>/dev/null || true

if [[ "${HAS_BLUETOOTH:-0}" == "1" ]]; then
    log "Enabling Bluetooth"
    systemctl enable bluetooth 2>/dev/null || true
    systemctl start bluetooth 2>/dev/null || true
fi

# ----------------------------------------------------------------------------
# Roaming firewall
# ----------------------------------------------------------------------------

if [[ -f "$CARINA_LIB_DIR/firewall.sh" ]] && command -v ufw &>/dev/null; then
    log "Applying firewall policy from $FIREWALL_CONF"
    # shellcheck source=lib/firewall.sh
    source "$CARINA_LIB_DIR/firewall.sh"
    carina_fw_apply_ssh
    if carina_fw_rdp_configured; then
        carina_fw_apply_rdp
    fi
fi

log "Laptop configuration complete"
if [[ $NEEDS_REBOOT -eq 1 ]]; then
    log ""
    log "IMPORTANT: Reboot to hand networking to NetworkManager."
    log "Afterwards, connect to Wi-Fi with: nmcli device wifi connect <SSID> --ask"
fi
