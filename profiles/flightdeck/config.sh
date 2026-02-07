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

# Install CARINA desktop entries and icons
echo "Installing CARINA desktop entries..."

# Find the repo directory (relative to this script or from /opt/carina)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${SCRIPT_DIR}/../.."

# Check if we're running from repo or installed location
if [[ -d "$REPO_DIR/branding/desktop" ]]; then
    BRANDING_DIR="$REPO_DIR/branding"
elif [[ -d "/opt/carina/branding/desktop" ]]; then
    BRANDING_DIR="/opt/carina/branding"
else
    echo "Warning: CARINA branding directory not found, skipping desktop entries"
    BRANDING_DIR=""
fi

if [[ -n "$BRANDING_DIR" ]]; then
    # Install desktop entries
    if [[ -d "$BRANDING_DIR/desktop" ]]; then
        cp "$BRANDING_DIR/desktop/"*.desktop /usr/share/applications/ 2>/dev/null || true
        echo "Desktop entries installed to /usr/share/applications/"
    fi
    
    # Install icons
    if [[ -d "$BRANDING_DIR/icons" ]]; then
        mkdir -p /usr/share/icons/hicolor/scalable/apps
        cp "$BRANDING_DIR/icons/"*.svg /usr/share/icons/hicolor/scalable/apps/ 2>/dev/null || true
        echo "Icons installed to /usr/share/icons/hicolor/scalable/apps/"
    fi
    
    # Update icon cache
    gtk-update-icon-cache /usr/share/icons/hicolor 2>/dev/null || true
    
    # Update desktop database
    update-desktop-database /usr/share/applications 2>/dev/null || true
    
    echo "CARINA desktop integration complete."
fi

# Set CARINA wallpaper as default
echo "Configuring CARINA wallpaper..."
if [[ -f "/usr/share/backgrounds/carina/carina-linux.png" ]]; then
    # Set for GDM (login screen)
    mkdir -p /etc/dconf/db/gdm.d
    cat > /etc/dconf/db/gdm.d/01-carina-background << 'DCONF'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/carina/carina-linux.png'
picture-uri-dark='file:///usr/share/backgrounds/carina/carina-linux.png'
picture-options='zoom'
DCONF
    
    # Set system-wide default for new users
    mkdir -p /etc/dconf/db/local.d
    cat > /etc/dconf/db/local.d/01-carina-background << 'DCONF'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/carina/carina-linux.png'
picture-uri-dark='file:///usr/share/backgrounds/carina/carina-linux.png'
picture-options='zoom'

[org/gnome/desktop/interface]
color-scheme='prefer-dark'
DCONF
    
    # Update dconf database
    dconf update 2>/dev/null || true
    
    echo "CARINA wallpaper configured as default."
fi

echo "FlightDeck profile configuration complete."
