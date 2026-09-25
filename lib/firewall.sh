#!/bin/bash
#
# CARINA firewall policy helpers
# Shared by the core and flightdeck profiles and the hw-laptop pack so
# re-applying any of them converges on the same rules.
#
# Policy lives in /etc/carina/firewall.conf:
#   SSH_RULE=allow|limit|off   allow = open to all, limit = open but
#                              rate-limited, off = no inbound SSH
#   RDP_SCOPE=any|lan|off      any = open to all, lan = private address
#                              ranges only, off = no inbound RDP
# Missing file or keys keep the server defaults (allow / any).
#

CARINA_FIREWALL_CONF="${CARINA_FIREWALL_CONF:-/etc/carina/firewall.conf}"
CARINA_LAN_RANGES=(10.0.0.0/8 172.16.0.0/12 192.168.0.0/16)
# IPv6 unique-local and link-local; skipped quietly when ufw has IPv6 off
CARINA_LAN_RANGES_V6=(fc00::/7 fe80::/10)

carina_fw_load() {
    SSH_RULE="allow"
    RDP_SCOPE="any"
    if [[ -r "$CARINA_FIREWALL_CONF" ]]; then
        local line
        while IFS= read -r line || [[ -n "$line" ]]; do
            case "$line" in
                SSH_RULE=allow|SSH_RULE=limit|SSH_RULE=off) SSH_RULE="${line#*=}" ;;
                RDP_SCOPE=any|RDP_SCOPE=lan|RDP_SCOPE=off) RDP_SCOPE="${line#*=}" ;;
            esac
        done < "$CARINA_FIREWALL_CONF"
    fi
}

carina_fw_apply_ssh() {
    carina_fw_load
    command -v ufw &>/dev/null || return 0
    case "$SSH_RULE" in
        limit)
            # Add the new rule before removing the old one so an SSH session
            # applying this is never without a matching rule
            ufw limit ssh >/dev/null
            ufw delete allow ssh >/dev/null 2>&1 || true
            echo "  SSH: open, rate-limited"
            ;;
        off)
            ufw delete allow ssh >/dev/null 2>&1 || true
            ufw delete limit ssh >/dev/null 2>&1 || true
            echo "  SSH: closed (SSH_RULE=off in $CARINA_FIREWALL_CONF)"
            ;;
        *)
            ufw allow ssh >/dev/null
            ufw delete limit ssh >/dev/null 2>&1 || true
            echo "  SSH: open"
            ;;
    esac
}

carina_fw_apply_rdp() {
    carina_fw_load
    command -v ufw &>/dev/null || return 0
    local range
    case "$RDP_SCOPE" in
        lan)
            for range in "${CARINA_LAN_RANGES[@]}"; do
                ufw allow from "$range" to any port 3389 proto tcp >/dev/null
            done
            for range in "${CARINA_LAN_RANGES_V6[@]}"; do
                ufw allow from "$range" to any port 3389 proto tcp >/dev/null 2>&1 || true
            done
            ufw delete allow 3389/tcp >/dev/null 2>&1 || true
            echo "  RDP: private networks only"
            ;;
        off)
            ufw delete allow 3389/tcp >/dev/null 2>&1 || true
            for range in "${CARINA_LAN_RANGES[@]}" "${CARINA_LAN_RANGES_V6[@]}"; do
                ufw delete allow from "$range" to any port 3389 proto tcp >/dev/null 2>&1 || true
            done
            echo "  RDP: closed (RDP_SCOPE=off in $CARINA_FIREWALL_CONF)"
            ;;
        *)
            ufw allow 3389/tcp >/dev/null
            for range in "${CARINA_LAN_RANGES[@]}" "${CARINA_LAN_RANGES_V6[@]}"; do
                ufw delete allow from "$range" to any port 3389 proto tcp >/dev/null 2>&1 || true
            done
            echo "  RDP: open"
            ;;
    esac
}

# Re-apply RDP rules only if an RDP rule already exists (i.e. FlightDeck
# has been applied), so the laptop pack doesn't open RDP on headless boxes
carina_fw_rdp_configured() {
    command -v ufw &>/dev/null || return 1
    ufw status 2>/dev/null | grep -q '3389'
}
