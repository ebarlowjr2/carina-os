# MissionLab Embedded Development Guide

This guide covers embedded development tooling in CARINA MissionLab.

## Arduino CLI

### Installation

Install Arduino CLI via CARINA:

```bash
sudo carina missionlab install arduino-cli
```

This downloads the official release from Arduino's GitHub and installs to `/usr/local/bin/arduino-cli`.

### Verify Installation

```bash
arduino-cli version
```

### Initialize Configuration

Configuration is auto-initialized during install. To manually initialize:

```bash
arduino-cli config init
```

Config location: `~/.arduino15/arduino-cli.yaml`

### Update Core Index

```bash
arduino-cli core update-index
```

### Install Board Support

For Arduino AVR boards (Uno, Mega, Nano):

```bash
arduino-cli core install arduino:avr
```

For ESP32:

```bash
arduino-cli config add board_manager.additional_urls https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
arduino-cli core update-index
arduino-cli core install esp32:esp32
```

### List Connected Boards

```bash
arduino-cli board list
```

### Compile a Sketch

```bash
arduino-cli compile --fqbn arduino:avr:uno MySketch
```

### Upload to Board

```bash
arduino-cli upload -p /dev/ttyUSB0 --fqbn arduino:avr:uno MySketch
```

### Uninstall

```bash
sudo carina missionlab uninstall arduino-cli
```

To also remove user configuration:

```bash
sudo carina missionlab uninstall arduino-cli --purge
```

Config location removed with purge: `~/.arduino15/`

## PlatformIO

### Installation

Install PlatformIO via CARINA:

```bash
carina missionlab install platformio
```

This uses pipx to install PlatformIO in an isolated environment.

### PATH Setup

If `pio` command is not found, add to your PATH:

```bash
export PATH="$PATH:$HOME/.local/bin"
```

Add this line to `~/.bashrc` for persistence:

```bash
echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
source ~/.bashrc
```

### Verify Installation

```bash
pio --version
```

### Initialize a Project

```bash
mkdir my-project && cd my-project
pio project init --board uno
```

### Build

```bash
pio run
```

### Upload

```bash
pio run --target upload
```

### List Connected Devices

```bash
pio device list
```

### Serial Monitor

```bash
pio device monitor
```

### Uninstall

```bash
carina missionlab uninstall platformio
```

## Flashing Examples

### Arduino Uno with Arduino CLI

```bash
# Create sketch directory
mkdir -p ~/Blink && cd ~/Blink

# Create sketch file
cat > Blink.ino << 'EOF'
void setup() {
  pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
  digitalWrite(LED_BUILTIN, HIGH);
  delay(1000);
  digitalWrite(LED_BUILTIN, LOW);
  delay(1000);
}
EOF

# Install board support
arduino-cli core install arduino:avr

# Compile
arduino-cli compile --fqbn arduino:avr:uno .

# Upload (adjust port as needed)
arduino-cli upload -p /dev/ttyACM0 --fqbn arduino:avr:uno .
```

### ESP32 with PlatformIO

```bash
# Create project
mkdir -p ~/esp32-blink && cd ~/esp32-blink
pio project init --board esp32dev

# Create source file
cat > src/main.cpp << 'EOF'
#include <Arduino.h>

void setup() {
  pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
  digitalWrite(LED_BUILTIN, HIGH);
  delay(1000);
  digitalWrite(LED_BUILTIN, LOW);
  delay(1000);
}
EOF

# Build and upload
pio run --target upload
```

## Configuration Locations

| Tool | Config Location |
|------|-----------------|
| Arduino CLI | `~/.arduino15/arduino-cli.yaml` |
| Arduino libraries | `~/Arduino/libraries/` |
| PlatformIO | `~/.platformio/` |
| PlatformIO projects | `platformio.ini` in project root |

## Serial Port Access

### Check Group Membership

```bash
groups
```

You should see `dialout` and `plugdev`.

### Add Yourself to Groups

```bash
sudo usermod -aG dialout $USER
sudo usermod -aG plugdev $USER
```

Log out and back in for changes to take effect.

### Verify Access

```bash
ls -la /dev/ttyUSB0
ls -la /dev/ttyACM0
```

You should be able to read/write without sudo.

## Troubleshooting

See [troubleshooting.md](troubleshooting.md) for common issues.
