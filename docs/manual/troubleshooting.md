# CARINA MissionLab Troubleshooting

Common issues and solutions for embedded development with CARINA.

## Serial Device Not Detected

### Symptom

`carina missionlab devices` shows no serial ports, or `arduino-cli board list` shows nothing.

### Solutions

1. Check if device is connected:

```bash
lsusb
```

Look for your device (Arduino, ESP32, etc.).

2. Check if serial port exists:

```bash
ls -la /dev/ttyUSB* /dev/ttyACM*
```

3. Check kernel messages:

```bash
dmesg | tail -20
```

Look for USB device detection messages.

4. Try a different USB cable. Data cables look identical to charge-only cables.

5. Try a different USB port. Some hubs don't provide enough power.

## Permission Denied on Serial Port

### Symptom

```
Error: cannot open /dev/ttyUSB0: Permission denied
```

### Solutions

1. Check group membership:

```bash
groups
```

You need `dialout` for serial access.

2. Add yourself to the dialout group:

```bash
sudo usermod -aG dialout $USER
```

3. Log out and back in for the change to take effect.

4. Verify:

```bash
groups | grep dialout
```

5. Check device permissions:

```bash
ls -la /dev/ttyUSB0
```

Should show `crw-rw----` with group `dialout`.

## User Not in Required Groups

### Symptom

`carina missionlab status` shows FAIL for group membership.

### Solution

Add yourself to the required groups:

```bash
sudo usermod -aG dialout $USER
sudo usermod -aG plugdev $USER
```

Log out and back in. Verify with:

```bash
groups
```

## udev Rules Not Working

### Symptom

Device permissions are wrong even after adding groups.

### Solutions

1. Check if CARINA udev rules are installed:

```bash
ls /etc/udev/rules.d/99-carina-*
```

2. If missing, apply the MissionLab profile:

```bash
sudo carina profile apply missionlab-embedded
```

3. Reload udev rules:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

4. Unplug and replug the device.

5. Check rule syntax:

```bash
sudo udevadm test /sys/class/tty/ttyUSB0
```

## Port Busy or Cannot Open /dev/ttyUSB0

### Symptom

```
Error: Port /dev/ttyUSB0 is busy
```

or

```
avrdude: ser_open(): can't open device "/dev/ttyUSB0": Device or resource busy
```

### Solutions

1. Check what's using the port:

```bash
sudo lsof /dev/ttyUSB0
```

2. Kill the process using the port:

```bash
sudo kill <PID>
```

3. Common culprits:
   - Serial monitor still open (close it)
   - ModemManager grabbing the device
   - Another upload in progress

4. Disable ModemManager if it keeps grabbing devices:

```bash
sudo systemctl stop ModemManager
sudo systemctl disable ModemManager
```

5. Wait a few seconds and try again. Some boards need time to reset.

## Arduino CLI Issues

### Board Not Found

```bash
# Update core index
arduino-cli core update-index

# List installed cores
arduino-cli core list

# Install missing core
arduino-cli core install arduino:avr
```

### Compilation Errors

```bash
# Check board FQBN
arduino-cli board listall | grep -i uno

# Use correct FQBN
arduino-cli compile --fqbn arduino:avr:uno MySketch
```

### Upload Fails

1. Check port:

```bash
arduino-cli board list
```

2. Use correct port:

```bash
arduino-cli upload -p /dev/ttyACM0 --fqbn arduino:avr:uno MySketch
```

3. Press reset button on board just before upload starts.

## PlatformIO Issues

### Command Not Found

Add to PATH:

```bash
export PATH="$PATH:$HOME/.local/bin"
```

Add to `~/.bashrc` for persistence:

```bash
echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
source ~/.bashrc
```

### Upload Permission Denied

Same as serial port permission issues above. Check groups and udev rules.

### Build Fails

```bash
# Clean and rebuild
pio run --target clean
pio run

# Update PlatformIO
pipx upgrade platformio
```

## Collecting Logs for Support

When reporting issues, collect these logs:

```bash
# System info
carina doctor
carina missionlab status

# MissionLab logs
cat /var/log/carina-missionlab.log

# Kernel messages for USB
dmesg | grep -i usb | tail -50

# Device info
lsusb
ls -la /dev/ttyUSB* /dev/ttyACM* 2>/dev/null

# Group membership
groups

# udev rules
ls -la /etc/udev/rules.d/99-carina-*
```

## Quick Reference

| Issue | Quick Fix |
|-------|-----------|
| Permission denied | `sudo usermod -aG dialout $USER` then logout/login |
| Device not detected | Check USB cable, try different port |
| Port busy | `sudo lsof /dev/ttyUSB0` and kill process |
| udev not working | `sudo udevadm control --reload-rules && sudo udevadm trigger` |
| pio not found | `export PATH="$PATH:$HOME/.local/bin"` |
| arduino-cli board not found | `arduino-cli core update-index` |
