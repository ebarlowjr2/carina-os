#!/bin/bash
#
# CARINA FlightDeck Profile Configuration
# GUI-enabled profile with desktop environment
#
# Uses XFCE for reliable xrdp compatibility
#

set -e

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
          <property name="last-image" type="string" value="/usr/share/backgrounds/carina/carina-linux.png"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/carina/carina-linux.png"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
      <property name="monitorrdp0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/carina/carina-linux.png"/>
        </property>
        <property name="workspace1" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/carina/carina-linux.png"/>
        </property>
        <property name="workspace2" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/carina/carina-linux.png"/>
        </property>
        <property name="workspace3" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/carina/carina-linux.png"/>
        </property>
      </property>
    </property>
  </property>
</channel>
XFCEDESKTOP

echo "FlightDeck profile configuration complete."
