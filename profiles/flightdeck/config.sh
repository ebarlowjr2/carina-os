#!/bin/bash
#
# CARINA FlightDeck Profile Configuration
# GUI-enabled profile with desktop environment
#

set -e

echo "Configuring FlightDeck profile..."

echo "Enabling GDM3 display manager..."
systemctl enable gdm3 2>/dev/null || true

echo "Enabling XRDP for remote desktop..."
systemctl enable xrdp 2>/dev/null || true
systemctl start xrdp 2>/dev/null || true

# Fix xrdp key permissions (common issue)
if [[ -f /etc/xrdp/key.pem ]]; then
    chmod 640 /etc/xrdp/key.pem
    chown root:xrdp /etc/xrdp/key.pem
    echo "XRDP key permissions fixed"
fi

# Configure PAM for GNOME keyring with xrdp
cat > /etc/pam.d/xrdp-sesman << 'PAM'
#%PAM-1.0
auth       required     pam_env.so readenv=1
auth       required     pam_env.so readenv=1 envfile=/etc/default/locale
@include common-auth
auth       optional     pam_gnome_keyring.so
@include common-account
session    required     pam_limits.so
@include common-session
session    optional     pam_gnome_keyring.so auto_start
@include common-password
PAM
echo "GNOME keyring PAM configured for xrdp"

echo "Allowing RDP through firewall..."
ufw allow 3389/tcp 2>/dev/null || true

echo "FlightDeck profile configuration complete."
