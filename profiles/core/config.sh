#!/bin/bash
#
# CARINA Core Profile Configuration
#

set -e

echo "Configuring core profile..."

echo "Enabling SSH..."
systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null || true
systemctl start ssh 2>/dev/null || systemctl start sshd 2>/dev/null || true

echo "Enabling chrony (time sync)..."
systemctl enable chrony 2>/dev/null || true
systemctl start chrony 2>/dev/null || true

echo "Configuring UFW firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable

echo "Setting sane sysctl defaults..."
cat > /etc/sysctl.d/99-carina.conf << 'EOF'
# CARINA OS sysctl defaults

# Network security
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Performance
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
vm.swappiness = 10

# File handles
fs.file-max = 2097152
EOF

sysctl -p /etc/sysctl.d/99-carina.conf 2>/dev/null || true

echo "Core profile configuration complete."
