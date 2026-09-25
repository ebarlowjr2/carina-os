#!/bin/bash
#
# Tests for lib/device.sh and lib/hardware.sh
# Builds fake /sys and /proc trees for different machines and checks the
# detected traits and which hardware packs match.
#
# Run: bash tests/test-device.sh
#

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# shellcheck source=lib/device.sh
source "$REPO_DIR/lib/device.sh"
# shellcheck source=lib/packages.sh
source "$REPO_DIR/lib/packages.sh"
# shellcheck source=lib/hardware.sh
source "$REPO_DIR/lib/hardware.sh"
CARINA_HW_DIR="$REPO_DIR/hardware"

PASS=0
FAIL=0

check() {
    local name="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: $name: expected '$expected', got '$actual'"
    fi
}

# --- fixture helpers ---------------------------------------------------------

new_root() {
    local root="$WORK/$1"
    mkdir -p "$root/sys/class/dmi/id" "$root/sys/class/power_supply" \
        "$root/sys/class/net" "$root/sys/bus/pci/devices" "$root/proc"
    echo "processor : 0" > "$root/proc/cpuinfo"
    echo "$root"
}

dmi() { echo "$3" > "$1/sys/class/dmi/id/$2"; }

battery() {
    local root="$1" name="$2" scope="${3:-}"
    mkdir -p "$root/sys/class/power_supply/$name"
    echo "Battery" > "$root/sys/class/power_supply/$name/type"
    echo "87" > "$root/sys/class/power_supply/$name/capacity"
    echo "Discharging" > "$root/sys/class/power_supply/$name/status"
    [[ -n "$scope" ]] && echo "$scope" > "$root/sys/class/power_supply/$name/scope"
    return 0
}

ac_adapter() {
    mkdir -p "$1/sys/class/power_supply/AC"
    echo "Mains" > "$1/sys/class/power_supply/AC/type"
}

wifi() { mkdir -p "$1/sys/class/net/$2/wireless"; }
ethernet() { mkdir -p "$1/sys/class/net/$2"; }
bluetooth() { mkdir -p "$1/sys/class/bluetooth/hci0"; }

gpu() {
    local dir="$1/sys/bus/pci/devices/0000:0$2:00.0"
    mkdir -p "$dir"
    echo "0x030000" > "$dir/class"
    echo "$3" > "$dir/vendor"
}

pci_nic() {
    local dir="$1/sys/bus/pci/devices/0000:05:00.0"
    mkdir -p "$dir"
    echo "0x020000" > "$dir/class"
    echo "0x8086" > "$dir/vendor"
}

device_tree() {
    local root="$1"
    mkdir -p "$root/proc/device-tree"
    printf '%s\0' "$2" > "$root/proc/device-tree/model"
    if [[ -n "${3:-}" ]]; then
        printf '%s\0' "$3" > "$root/proc/device-tree/chassis-type"
    fi
}

detect() {
    CARINA_SYSROOT="$1"
    CARINA_DEVICE_OVERRIDE="${2:-$WORK/no-override}"
    device_collect
    device_apply_overrides
}

matches() {
    if hw_pack_matches "$1"; then echo yes; else echo no; fi
}

# --- scenarios ---------------------------------------------------------------

# Intel laptop: SMBIOS notebook, battery, Wi-Fi, Bluetooth, Intel iGPU
root=$(new_root laptop)
dmi "$root" chassis_type 10
dmi "$root" sys_vendor "LENOVO"
battery "$root" BAT0
ac_adapter "$root"
wifi "$root" wlp0s20f3
bluetooth "$root"
gpu "$root" 2 0x8086
detect "$root"
check "laptop chassis" laptop "$CHASSIS"
check "laptop virt" none "$VIRT_TYPE"
check "laptop battery" 1 "$HAS_BATTERY"
check "laptop wifi" 1 "$HAS_WIFI"
check "laptop bluetooth" 1 "$HAS_BLUETOOTH"
check "laptop gpu" intel "$GPU"
check "laptop sbc" 0 "$IS_SBC"
check "laptop cloud" none "$CLOUD"
check "laptop battery info" "87|Discharging" "$(device_battery_info)"
check "laptop matches hw-laptop" yes "$(matches hw-laptop)"

# Desktop tower: wireless mouse battery (scope=Device) must not count
root=$(new_root desktop)
dmi "$root" chassis_type 3
battery "$root" hidpp_battery_0 Device
ethernet "$root" enp3s0
gpu "$root" 1 0x10de
gpu "$root" 2 0x8086
pci_nic "$root"
detect "$root"
check "desktop chassis" desktop "$CHASSIS"
check "desktop ignores peripheral battery" 0 "$HAS_BATTERY"
check "desktop wifi" 0 "$HAS_WIFI"
check "desktop gpu list" "intel,nvidia" "$GPU"
check "desktop no hw-laptop" no "$(matches hw-laptop)"

# Laptop with bogus SMBIOS chassis ("Other") falls back to battery
root=$(new_root cheap-laptop)
dmi "$root" chassis_type 1
battery "$root" BAT1
detect "$root"
check "unknown chassis + battery" laptop "$CHASSIS"
check "cheap laptop matches hw-laptop" yes "$(matches hw-laptop)"

# Mini PC with a UPS battery: user overrides detection
root=$(new_root minipc)
dmi "$root" chassis_type 35
battery "$root" BAT0
echo "HAS_BATTERY=0" > "$WORK/minipc.override"
detect "$root" "$WORK/minipc.override"
check "mini pc chassis" desktop "$CHASSIS"
check "override applied" 0 "$HAS_BATTERY"
check "override recorded" HAS_BATTERY "$DEVICE_OVERRIDES"
check "overridden mini pc no hw-laptop" no "$(matches hw-laptop)"

# Override file can't inject arbitrary keys or values
printf 'ARCH=evil\nCHASSIS=laptop;rm -rf /\nGPU=nvidia\n' > "$WORK/bad.override"
detect "$root" "$WORK/bad.override"
check "non-overridable key ignored" "$(device_detect_arch)" "$ARCH"
check "unsafe value ignored" desktop "$CHASSIS"
check "valid override kept" nvidia "$GPU"

# Raspberry Pi: device tree, no DMI
root=$(new_root rpi)
device_tree "$root" "Raspberry Pi 4 Model B Rev 1.4"
wifi "$root" wlan0
detect "$root"
check "rpi chassis" embedded "$CHASSIS"
check "rpi sbc" 1 "$IS_SBC"
check "rpi board model" "Raspberry Pi 4 Model B Rev 1.4" "$BOARD_MODEL"
check "rpi no hw-laptop" no "$(matches hw-laptop)"

# ARM laptop (e.g. Snapdragon): device tree with chassis-type laptop
root=$(new_root arm-laptop)
device_tree "$root" "Lenovo ThinkPad X13s" laptop
battery "$root" BAT0
wifi "$root" wlan0
detect "$root"
check "arm laptop chassis" laptop "$CHASSIS"
check "arm laptop not sbc" 0 "$IS_SBC"
check "arm laptop matches hw-laptop" yes "$(matches hw-laptop)"

# EC2 instance
root=$(new_root ec2)
dmi "$root" chassis_type 1
dmi "$root" sys_vendor "Amazon EC2"
dmi "$root" product_name "t3.medium"
detect "$root"
check "ec2 virt type" vm "$VIRT_TYPE"
check "ec2 chassis" vm "$CHASSIS"
check "ec2 cloud" aws "$CLOUD"
check "ec2 no hw-laptop" no "$(matches hw-laptop)"

# VM with a passed-through battery must not get the laptop pack
root=$(new_root vm-battery)
dmi "$root" sys_vendor "QEMU"
battery "$root" BAT0
detect "$root"
check "qemu virt" kvm "$VIRT"
check "vm with battery no hw-laptop" no "$(matches hw-laptop)"

# Container
root=$(new_root container)
touch "$root/.dockerenv"
detect "$root"
check "container chassis" container "$CHASSIS"

# Desktop installed
root=$(new_root with-desktop)
mkdir -p "$root/etc/systemd/system"
ln -s /lib/systemd/system/lightdm.service "$root/etc/systemd/system/display-manager.service"
detect "$root"
check "display manager means desktop" 1 "$HAS_DESKTOP"

# --- conf round trip ---------------------------------------------------------

root=$(new_root roundtrip)
device_tree "$root" "Raspberry Pi 5 Model B Rev 1.0"
detect "$root"
CARINA_DEVICE_CONF="$WORK/etc/device.conf"
device_write_conf
unset BOARD_MODEL CHASSIS
device_load
check "conf round trip board model" "Raspberry Pi 5 Model B Rev 1.0" "$BOARD_MODEL"
check "conf round trip chassis" embedded "$CHASSIS"
check "conf source" "$CARINA_DEVICE_CONF" "$DEVICE_SOURCE"

# --- package lists -----------------------------------------------------------

check "amd64 list includes thermald" 1 "$(carina_package_list "$REPO_DIR/hardware/hw-laptop" amd64 | grep -cx thermald)"
check "arm64 list excludes thermald" 0 "$(carina_package_list "$REPO_DIR/hardware/hw-laptop" arm64 | grep -cx thermald)"
check "comments stripped" 0 "$(carina_package_list "$REPO_DIR/hardware/hw-laptop" amd64 | grep -c '#')"

# --- applied-pack state ------------------------------------------------------

CARINA_HW_STATE="$WORK/state/hardware-packs"
hw_mark_applied hw-laptop
hw_mark_applied hw-laptop
check "applied recorded once" 1 "$(grep -cx hw-laptop "$CARINA_HW_STATE")"
check "applied check" yes "$(hw_pack_is_applied hw-laptop && echo yes || echo no)"
check "pack path traversal rejected" no "$(hw_pack_exists ../lib && echo yes || echo no)"

echo ""
echo "device tests: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
