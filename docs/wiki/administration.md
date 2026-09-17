# Administration

## Overview

This section covers operational procedures for managing a CARINA OS installation, including GUI management, logging, backups, and system updates.

## Enabling/Disabling GUI

### Enable FlightDeck

```bash
carina gui enable
sudo reboot
```

### Disable FlightDeck

```bash
carina gui disable
sudo reboot
```

### xRDP/XFCE Notes

- xRDP runs on port 3389 (auto-added to UFW)
- Connect via any standard RDP client
- Session type: XFCE (lightweight, suitable for remote)
- Multiple concurrent sessions supported

## Logs

### CARINA system logs

| Log | Location |
|-----|----------|
| Sandbox activity | `/var/log/carina/sandbox.log` |
| CARINA Control | `/var/log/carina-control.log` |
| First-boot | `journalctl -u carina-firstboot` |
| System | `/var/log/syslog` |

### Log rotation

Sandbox logs are rotated weekly with 4 weeks retention via `/etc/logrotate.d/carina-sandbox`.

## Backups

### What to back up

| Item | Location |
|------|----------|
| CARINA config | `/etc/carina/` |
| Profiles | `/opt/carina/profiles/` |
| Sandbox state | `/var/lib/carina/` |
| Logs | `/var/log/carina/` |

### Basic backup script

```bash
#!/bin/bash
BACKUP_DIR="/backup/carina-$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"
cp -r /etc/carina "$BACKUP_DIR/"
cp -r /opt/carina/profiles "$BACKUP_DIR/"
cp -r /var/lib/carina "$BACKUP_DIR/"
cp -r /var/log/carina "$BACKUP_DIR/"
echo "Backup complete: $BACKUP_DIR"
```

## Updating CARINA OS

```bash
cd /path/to/carina-os
git pull
sudo ./bootstrap/bootstrap-carina.sh
carina doctor
```

The bootstrap script is idempotent and safe to re-run.

## Managing Users and Permissions

### Add a user to CARINA groups

```bash
sudo usermod -aG carina,dialout,plugdev <username>
```

### Permission model

- **carina group** — Access to CARINA state and control files
- **dialout group** — Serial port access
- **plugdev group** — USB device access
- Directories: `root:carina` with `2775` (setgid)
- Files: `root:carina` with `664`

## Wiki Administration

### Starting/stopping the wiki

```bash
cd /home/ubuntu/wiki-deploy
sudo docker compose up -d      # Start
sudo docker compose down        # Stop
sudo docker compose restart     # Restart
```

### Updating Wiki.js

```bash
cd /home/ubuntu/wiki-deploy
sudo docker compose pull wiki
sudo docker compose up -d wiki
```

### Backing up the wiki database

```bash
sudo docker exec wiki-db pg_dump -U wiki wiki > wiki-backup-$(date +%Y%m%d).sql
```

### Restoring from backup

```bash
cat wiki-backup-YYYYMMDD.sql | sudo docker exec -i wiki-db psql -U wiki wiki
```

### Moving to another server

1. Back up the database (above)
2. Copy `wiki-deploy/` directory to new server
3. Install Docker on new server
4. Restore database
5. Start containers

---

*Related: [Mission Manual](mission-manual.md), [Getting Started](getting-started.md)*


<!-- Imported from the CARINA OS Wiki (Wiki.js). Original path: /administration · last updated 2026-04-16 -->
