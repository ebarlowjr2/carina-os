# CARINA Hardware Detection and Hardware Packs

## Overview

CARINA runs on laptops, desktops, ARM boards, VMs and cloud instances from one codebase. Instead of assuming a device type from the Ubuntu install type (Server vs Desktop), CARINA detects what the hardware actually is and applies the matching **hardware packs**.

There are two layers:

| Layer | Question it answers | Examples | Applied |
|-------|---------------------|----------|---------|
| Hardware packs | What am I running on? | `hw-laptop` | Automatically, when they match |
| Profiles | What do I want to do? | `core`, `flightdeck`, `missionlab-embedded` | By you |

## Device Traits

A device is described by a set of traits, not one label. A Snapdragon laptop is both `ARCH=arm64` and `CHASSIS=laptop`.

| Trait | Values | Source |
|-------|--------|--------|
| `ARCH` | `amd64`, `arm64`, `armhf`, ... | `dpkg --print-architecture` |
| `CHASSIS` | `laptop`, `desktop`, `server`, `tablet`, `convertible`, `embedded`, `vm`, `container`, `unknown` | SMBIOS chassis type, then device-tree `chassis-type`, then heuristics |
| `VIRT` / `VIRT_TYPE` | e.g. `kvm` / `vm`, `docker` / `container`, `none` / `none` | `systemd-detect-virt` |
| `CLOUD` | `aws`, `gcp`, `azure`, `digitalocean`, `hetzner`, `openstack`, `none` | DMI vendor strings |
| `HAS_BATTERY` | `0` / `1` | `/sys/class/power_supply` (peripheral batteries such as wireless mice are ignored) |
| `HAS_WIFI` | `0` / `1` | `/sys/class/net/*/wireless` |
| `HAS_BLUETOOTH` | `0` / `1` | `/sys/class/bluetooth` |
| `IS_SBC` | `0` / `1` | Device-tree machine that isn't a laptop/desktop (Raspberry Pi, Jetson, ...) |
| `BOARD_MODEL` | e.g. `Raspberry Pi 4 Model B Rev 1.4` | `/proc/device-tree/model` |
| `GPU` | comma list of `intel`, `amd`, `nvidia`, `other`, or `none` | PCI display controllers |
| `HAS_DESKTOP` | `0` / `1` | A display manager is enabled |
| `NETWORK_BACKEND` | `networkmanager`, `networkd`, `unknown` | Active network service |

Facts are saved to `/etc/carina/device.conf`. The `carina-detect` service refreshes them at every boot. Detection never installs anything on its own; `carina doctor` warns when a pack matches but hasn't been applied.

## Commands

```bash
carina device                     # Show detected traits
sudo carina device detect         # Re-detect and save
carina device packs               # List packs, whether they match and are applied
sudo carina device apply          # Apply all matching packs
sudo carina device apply --dry-run
sudo carina device apply hw-laptop
```

### Correcting detection

Some machines report misleading firmware data (e.g. a mini PC with a UPS battery looks like a laptop). Override a trait:

```bash
sudo carina device set HAS_BATTERY 0
sudo carina device set CHASSIS laptop
sudo carina device unset CHASSIS
```

Overrides are stored in `/etc/carina/device.override` and marked `(override)` in `carina device`.

## Bootstrap Behaviour

`bootstrap-carina.sh` detects hardware after applying the core profile and then applies every matching pack. To skip packs during bootstrap:

```bash
sudo CARINA_SKIP_HW=1 ./bootstrap/bootstrap-carina.sh
```

## hw-laptop

Matches bare-metal machines (not VMs or containers) that have a system battery or a laptop/convertible/tablet chassis.

**Packages:** network-manager, wpasupplicant, iw, rfkill, wireless-regdb, linux-firmware, power-profiles-daemon, upower, acpi, brightnessctl, fwupd, bluez, and thermald on amd64.

**Configuration:**

- **Networking:** switches netplan to NetworkManager (`/etc/netplan/01-carina-network-manager.yaml`) so Wi-Fi can roam, and disables the networkd boot wait. Existing netplan config, including Wi-Fi set up in the Ubuntu installer, is kept. Takes effect after a reboot.
- **Power:** enables power-profiles-daemon, and thermald on Intel CPUs only. Sets lid-switch behaviour and batches disk writeback to save battery.
- **Firmware:** enables the fwupd metadata refresh timer. Check for updates with `fwupdmgr get-updates`.
- **Bluetooth:** enabled when an adapter is present.
- **Firewall:** SSH stays open but rate-limited. If FlightDeck is installed, RDP is limited to private address ranges.

### Settings

Edit these files, then re-run `sudo carina device apply hw-laptop`:

`/etc/carina/laptop.conf`

```bash
LID_ACTION=suspend                 # suspend | hibernate | poweroff | lock | ignore
LID_ACTION_EXTERNAL_POWER=suspend
LID_ACTION_DOCKED=ignore
USE_NETWORKMANAGER=yes
```

To run the laptop headless with the lid shut (e.g. as an SSH target), set all three `LID_ACTION*` values to `ignore`.

`/etc/carina/firewall.conf`

```bash
SSH_RULE=limit    # allow | limit | off
RDP_SCOPE=lan     # any | lan | off
```

`lan` limits access to the local network. Public Wi-Fi also uses private address ranges, so this is not the same as "trusted networks".

### After applying

```bash
sudo reboot
nmcli device wifi list
nmcli device wifi connect <SSID> --ask
carina doctor
```

## Writing a Hardware Pack

Create `hardware/<name>/` with:

- `pack.conf` (required): a `DESCRIPTION` and a `pack_matches` function that returns 0 when the pack fits. All device traits are available as variables.
- `packages.txt`: packages for all architectures.
- `packages.<arch>.txt`: extra packages for one architecture, e.g. `packages.arm64.txt`. Profiles support this too.
- `config.sh`: runs as root after packages are installed. Device traits are exported as environment variables. It must be idempotent.

Example `pack.conf`:

```bash
DESCRIPTION="Raspberry Pi: GPIO/I2C/SPI access"

pack_matches() {
    [[ "$IS_SBC" == "1" ]] && [[ "$BOARD_MODEL" == Raspberry\ Pi* ]]
}
```

Add a scenario for the new pack to `tests/test-device.sh`.

## Planned Packs

- `hw-vm` / `hw-cloud`: guest agents; skip power and Wi-Fi tooling
- `hw-desktop`: performance power profile
- `hw-sbc`: GPIO/I2C/SPI groups, SD-card-friendly logging
- `hw-nvidia`: driver install via `ubuntu-drivers`
