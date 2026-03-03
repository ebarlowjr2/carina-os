#!/bin/bash
#
# CARINA FlightDeck Profile Configuration
# GUI-enabled profile with desktop environment
#
# Uses XFCE for reliable xrdp compatibility
#

set -e

CARINA_BRANDING="/opt/carina/branding"

echo "Configuring FlightDeck profile..."

# Install XFCE desktop environment for xrdp compatibility
# GNOME Shell doesn't work reliably with xrdp's virtual X server
echo "Installing XFCE desktop environment..."
apt-get install -y -qq xfce4 xfce4-goodies 2>/dev/null || true

echo "Enabling GDM3 display manager..."
systemctl enable gdm3 2>/dev/null || true

echo "Enabling XRDP for remote desktop..."
systemctl enable xrdp 2>/dev/null || true
systemctl start xrdp 2>/dev/null || true

echo "Allowing RDP through firewall..."
ufw allow 3389/tcp 2>/dev/null || true

# Configure xrdp to use XFCE by default for all users
echo "Configuring XFCE as default xrdp session..."
mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml

# Create default .xsession for xrdp users
cat > /etc/skel/.xsession << 'XSESSION'
startxfce4
XSESSION
chmod +x /etc/skel/.xsession

# Create XFCE desktop config with CARINA wallpaper
cat > /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml << 'XFCEDESKTOP'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitorVNC-0" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/carina/carina-linux-banner.png"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/carina/carina-linux-banner.png"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
      <property name="monitorrdp0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/carina/carina-linux-banner.png"/>
        </property>
        <property name="workspace1" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/carina/carina-linux-banner.png"/>
        </property>
        <property name="workspace2" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/carina/carina-linux-banner.png"/>
        </property>
        <property name="workspace3" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/carina/carina-linux-banner.png"/>
        </property>
      </property>
    </property>
  </property>
</channel>
XFCEDESKTOP

# Install CARINA desktop entries
echo "Installing CARINA desktop entries..."
if [[ -d "${CARINA_BRANDING}/desktop" ]]; then
    cp "${CARINA_BRANDING}/desktop/"*.desktop /usr/share/applications/ 2>/dev/null || true
    echo "Desktop entries installed"
fi

# Install CARINA icons
echo "Installing CARINA icons..."
mkdir -p /usr/share/icons/hicolor/scalable/apps
if [[ -d "${CARINA_BRANDING}/icons" ]]; then
    cp "${CARINA_BRANDING}/icons/"*.svg /usr/share/icons/hicolor/scalable/apps/ 2>/dev/null || true
    echo "Icons installed"
fi

# Update desktop database and icon cache
echo "Updating desktop database..."
update-desktop-database /usr/share/applications 2>/dev/null || true
gtk-update-icon-cache /usr/share/icons/hicolor 2>/dev/null || true

# Create desktop icons in /etc/skel/Desktop for new users
echo "Setting up desktop icons for new users..."
mkdir -p /etc/skel/Desktop
if [[ -d "${CARINA_BRANDING}/desktop" ]]; then
    for desktop_file in "${CARINA_BRANDING}/desktop/"*.desktop; do
        if [[ -f "$desktop_file" ]]; then
            cp "$desktop_file" /etc/skel/Desktop/
            chmod +x "/etc/skel/Desktop/$(basename "$desktop_file")"
        fi
    done
    echo "Desktop icons staged for new users"
fi

# Also add a CARINA Terminal desktop icon
cat > /etc/skel/Desktop/carina-terminal.desktop << 'TERMINAL_DESKTOP'
[Desktop Entry]
Name=CARINA Terminal
Comment=Open a terminal with CARINA CLI
Exec=xfce4-terminal
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=System;TerminalEmulator;
TERMINAL_DESKTOP
chmod +x /etc/skel/Desktop/carina-terminal.desktop

# Create a script to add desktop icons for existing users
cat > /usr/local/bin/carina-setup-desktop-icons << 'SETUP_ICONS'
#!/bin/bash
# Setup CARINA desktop icons for the current user

DESKTOP_DIR="${HOME}/Desktop"
BRANDING_DIR="/opt/carina/branding/desktop"

mkdir -p "$DESKTOP_DIR"

if [[ -d "$BRANDING_DIR" ]]; then
    for desktop_file in "$BRANDING_DIR"/*.desktop; do
        if [[ -f "$desktop_file" ]]; then
            cp "$desktop_file" "$DESKTOP_DIR/"
            chmod +x "$DESKTOP_DIR/$(basename "$desktop_file")"
            # Mark as trusted for GNOME/XFCE
            gio set "$DESKTOP_DIR/$(basename "$desktop_file")" metadata::trusted true 2>/dev/null || true
        fi
    done
fi

# Add terminal icon
cat > "$DESKTOP_DIR/carina-terminal.desktop" << 'EOF'
[Desktop Entry]
Name=CARINA Terminal
Comment=Open a terminal with CARINA CLI
Exec=xfce4-terminal
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=System;TerminalEmulator;
EOF
chmod +x "$DESKTOP_DIR/carina-terminal.desktop"
gio set "$DESKTOP_DIR/carina-terminal.desktop" metadata::trusted true 2>/dev/null || true

echo "CARINA desktop icons installed to $DESKTOP_DIR"
SETUP_ICONS
chmod +x /usr/local/bin/carina-setup-desktop-icons

echo "FlightDeck profile configuration complete."
echo "Run 'carina-setup-desktop-icons' to add desktop icons for existing users."
