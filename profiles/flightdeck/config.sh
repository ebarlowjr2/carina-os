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

echo "Allowing RDP through firewall..."
ufw allow 3389/tcp 2>/dev/null || true

echo "FlightDeck profile configuration complete."
