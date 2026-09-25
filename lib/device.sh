#!/bin/bash
#
# CARINA Device Detection
# Detects what hardware CARINA is running on and records it as a set of
# traits (not a single "device type"), so a machine can be e.g. both ARM
# and a laptop at the same time.
#
# Sourced by the carina CLI. Every filesystem probe goes through
# CARINA_SYSROOT so tests can point detection at a fake /sys and /proc.
# When CARINA_SYSROOT is set, external commands (systemd-detect-virt,
# systemctl) are not consulted and the file-based fallbacks are used.
#

CARINA_SYSROOT="${CARINA_SYSROOT:-}"
CARINA_DEVICE_CONF="${CARINA_DEVICE_CONF:-/etc/carina/device.conf}"
CARINA_DEVICE_OVERRIDE="${CARINA_DEVICE_OVERRIDE:-/etc/carina/device.override}"

# Keys written to device.conf, in display order
DEVICE_KEYS=(ARCH CHASSIS VIRT VIRT_TYPE CLOUD HAS_BATTERY HAS_WIFI HAS_BLUETOOTH IS_SBC BOARD_MODEL GPU HAS_DESKTOP NETWORK_BACKEND)

# Keys a user may override with `carina device set`
DEVICE_OVERRIDABLE_KEYS=(CHASSIS VIRT_TYPE CLOUD HAS_BATTERY HAS_WIFI HAS_BLUETOOTH IS_SBC GPU HAS_DESKTOP)

_dev_path() {
    echo "${CARINA_SYSROOT}$1"
}

# Read the first line of a sysfs/procfs file, stripping NULs (device tree
# strings are NUL-terminated) and surrounding whitespace.
_dev_read() {
    local file
    file=$(_dev_path "$1")
    [[ -r "$file" ]] || return 1
    local value
    value=$(tr -d '\0' < "$file" 2>/dev/null | head -n 1)
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    echo "$value"
}

# Read a sysfs attribute file (path already resolved), whitespace stripped
_dev_attr() {
    [[ -r "$1" ]] || return 1
    tr -d '[:space:]' < "$1"
}

_dev_live() {
    [[ -z "$CARINA_SYSROOT" ]]
}

device_detect_arch() {
    if _dev_live && command -v dpkg &>/dev/null; then
        dpkg --print-architecture
        return
    fi
    case "$(uname -m)" in
        x86_64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l|armv6l) echo "armhf" ;;
        riscv64) echo "riscv64" ;;
        *) uname -m ;;
    esac
}

# Prints "<virt> <virt_type>", e.g. "kvm vm", "docker container", "none none"
device_detect_virt() {
    if _dev_live && command -v systemd-detect-virt &>/dev/null; then
        local name
        if name=$(systemd-detect-virt --container 2>/dev/null); then
            echo "$name container"
            return
        fi
        if name=$(systemd-detect-virt --vm 2>/dev/null); then
            echo "$name vm"
            return
        fi
        echo "none none"
        return
    fi

    # File-based fallback
    if [[ -e "$(_dev_path /.dockerenv)" ]]; then
        echo "docker container"
        return
    fi
    if [[ -e "$(_dev_path /run/.containerenv)" ]]; then
        echo "podman container"
        return
    fi

    local vendor product
    vendor=$(_dev_read /sys/class/dmi/id/sys_vendor || true)
    product=$(_dev_read /sys/class/dmi/id/product_name || true)
    case "$vendor|$product" in
        *"Amazon EC2"*) echo "amazon vm"; return ;;
        *QEMU*|*KVM*) echo "kvm vm"; return ;;
        *VMware*) echo "vmware vm"; return ;;
        *innotek*|*VirtualBox*) echo "oracle vm"; return ;;
        *Xen*) echo "xen vm"; return ;;
        *"Google Compute Engine"*) echo "kvm vm"; return ;;
        "Microsoft Corporation|Virtual Machine") echo "microsoft vm"; return ;;
    esac

    if grep -qw hypervisor "$(_dev_path /proc/cpuinfo)" 2>/dev/null; then
        echo "unknown vm"
        return
    fi
    echo "none none"
}

device_detect_cloud() {
    local sys_vendor bios_vendor product asset hv_uuid
    sys_vendor=$(_dev_read /sys/class/dmi/id/sys_vendor || true)
    bios_vendor=$(_dev_read /sys/class/dmi/id/bios_vendor || true)
    product=$(_dev_read /sys/class/dmi/id/product_name || true)
    asset=$(_dev_read /sys/class/dmi/id/chassis_asset_tag || true)
    hv_uuid=$(_dev_read /sys/hypervisor/uuid || true)

    if [[ "$sys_vendor" == *"Amazon EC2"* ]] || [[ "$bios_vendor" == *"Amazon EC2"* ]] || [[ "$hv_uuid" == ec2* ]]; then
        echo "aws"
    elif [[ "$product" == *"Google Compute Engine"* ]]; then
        echo "gcp"
    elif [[ "$asset" == "7783-7084-3265-9085-8269-3286-77" ]]; then
        echo "azure"
    elif [[ "$sys_vendor" == *"DigitalOcean"* ]]; then
        echo "digitalocean"
    elif [[ "$sys_vendor" == *"Hetzner"* ]]; then
        echo "hetzner"
    elif [[ "$product" == *"OpenStack"* ]] || [[ "$sys_vendor" == *"OpenStack"* ]]; then
        echo "openstack"
    else
        echo "none"
    fi
}

# Map an SMBIOS chassis type number to a CARINA chassis name
_dev_smbios_chassis() {
    case "$1" in
        3|4|5|6|7|13|15|16|24|35|36) echo "desktop" ;;
        8|9|10|11|14) echo "laptop" ;;
        30) echo "tablet" ;;
        31|32) echo "convertible" ;;
        17|23|25|28|29) echo "server" ;;
        33|34) echo "embedded" ;;
        *) echo "unknown" ;;
    esac
}

device_detect_board_model() {
    _dev_read /proc/device-tree/model 2>/dev/null \
        || _dev_read /sys/firmware/devicetree/base/model 2>/dev/null \
        || true
}

device_has_battery() {
    local supply
    for supply in "$(_dev_path /sys/class/power_supply)"/*; do
        [[ -d "$supply" ]] || continue
        [[ "$(_dev_attr "$supply/type")" == "Battery" ]] || continue
        # Peripherals (wireless mice, keyboards) report scope=Device; only
        # count batteries that power the machine itself.
        [[ "$(_dev_attr "$supply/scope")" == "Device" ]] && continue
        return 0
    done
    return 1
}

# Prints "<capacity>|<status>" for the first system battery
device_battery_info() {
    local supply
    for supply in "$(_dev_path /sys/class/power_supply)"/*; do
        [[ -d "$supply" ]] || continue
        [[ "$(_dev_attr "$supply/type")" == "Battery" ]] || continue
        [[ "$(_dev_attr "$supply/scope")" == "Device" ]] && continue
        local capacity status
        capacity=$(_dev_attr "$supply/capacity" || echo "?")
        status=$(_dev_attr "$supply/status" || echo "Unknown")
        echo "${capacity}|${status}"
        return 0
    done
    return 1
}

device_has_wifi() {
    local iface
    for iface in "$(_dev_path /sys/class/net)"/*; do
        if [[ -d "$iface/wireless" ]] || [[ -e "$iface/phy80211" ]]; then
            return 0
        fi
    done
    return 1
}

device_has_bluetooth() {
    compgen -G "$(_dev_path /sys/class/bluetooth)/hci*" >/dev/null
}

# Comma-separated list of GPU vendors found on the PCI bus, or "none"
device_detect_gpu() {
    local dev class vendor found=()
    for dev in "$(_dev_path /sys/bus/pci/devices)"/*; do
        [[ -r "$dev/class" ]] || continue
        class=$(_dev_attr "$dev/class")
        # PCI class 0x03xxxx = display controller
        [[ "$class" == 0x03* ]] || continue
        vendor=$(_dev_attr "$dev/vendor" || true)
        case "$vendor" in
            0x10de) found+=("nvidia") ;;
            0x1002) found+=("amd") ;;
            0x8086) found+=("intel") ;;
            *) found+=("other") ;;
        esac
    done
    if [[ ${#found[@]} -eq 0 ]]; then
        echo "none"
    else
        printf '%s\n' "${found[@]}" | sort -u | paste -sd, -
    fi
}

# A desktop is installed if a display manager is enabled. (The default
# target is no signal: Ubuntu Server also defaults to graphical.target.)
device_has_desktop() {
    local link
    link=$(_dev_path /etc/systemd/system/display-manager.service)
    [[ -e "$link" ]] || [[ -L "$link" ]]
}

device_detect_network_backend() {
    if _dev_live && command -v systemctl &>/dev/null; then
        if systemctl is-active --quiet NetworkManager 2>/dev/null; then
            echo "networkmanager"
            return
        fi
        if systemctl is-active --quiet systemd-networkd 2>/dev/null; then
            echo "networkd"
            return
        fi
    fi
    echo "unknown"
}

_dev_bool() {
    if "$@"; then echo 1; else echo 0; fi
}

# Detect all traits into global variables (one per DEVICE_KEYS entry)
device_collect() {
    ARCH=$(device_detect_arch)

    local virt_out
    virt_out=$(device_detect_virt)
    VIRT="${virt_out% *}"
    VIRT_TYPE="${virt_out##* }"

    CLOUD=$(device_detect_cloud)
    HAS_BATTERY=$(_dev_bool device_has_battery)
    HAS_WIFI=$(_dev_bool device_has_wifi)
    HAS_BLUETOOTH=$(_dev_bool device_has_bluetooth)
    BOARD_MODEL=$(device_detect_board_model)
    GPU=$(device_detect_gpu)
    HAS_DESKTOP=$(_dev_bool device_has_desktop)
    NETWORK_BACKEND=$(device_detect_network_backend)

    # Chassis: virtualization first, then firmware tables, then heuristics
    CHASSIS="unknown"
    if [[ "$VIRT_TYPE" == "container" ]]; then
        CHASSIS="container"
    elif [[ "$VIRT_TYPE" == "vm" ]]; then
        CHASSIS="vm"
    else
        local smbios dt_chassis
        smbios=$(_dev_read /sys/class/dmi/id/chassis_type || true)
        if [[ -n "$smbios" ]]; then
            CHASSIS=$(_dev_smbios_chassis "$smbios")
        fi
        if [[ "$CHASSIS" == "unknown" ]]; then
            dt_chassis=$(_dev_read /proc/device-tree/chassis-type 2>/dev/null \
                || _dev_read /sys/firmware/devicetree/base/chassis-type 2>/dev/null || true)
            case "$dt_chassis" in
                laptop|desktop|tablet|convertible|server|embedded) CHASSIS="$dt_chassis" ;;
                handset|watch) CHASSIS="embedded" ;;
            esac
        fi
        if [[ "$CHASSIS" == "unknown" ]] && [[ -n "$BOARD_MODEL" ]]; then
            CHASSIS="embedded"
        fi
        if [[ "$CHASSIS" == "unknown" ]] && [[ "$HAS_BATTERY" == "1" ]]; then
            CHASSIS="laptop"
        fi
    fi

    # A single-board computer is a device-tree machine that isn't a
    # laptop/desktop/tablet (e.g. Raspberry Pi, Jetson, BeagleBone)
    IS_SBC=0
    if [[ -n "$BOARD_MODEL" ]] && [[ "$CHASSIS" == "embedded" ]]; then
        IS_SBC=1
    fi

    DEVICE_OVERRIDES=""
}

_dev_is_overridable() {
    local key="$1" k
    for k in "${DEVICE_OVERRIDABLE_KEYS[@]}"; do
        [[ "$k" == "$key" ]] && return 0
    done
    return 1
}

_dev_valid_value() {
    [[ "$1" =~ ^[A-Za-z0-9_.,:+-]+$ ]]
}

# Apply user overrides from device.override on top of detected values.
# The file is parsed, never sourced.
device_apply_overrides() {
    [[ -r "$CARINA_DEVICE_OVERRIDE" ]] || return 0
    local line key value
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
        if [[ "$line" =~ ^([A-Z_]+)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            if _dev_is_overridable "$key" && _dev_valid_value "$value"; then
                printf -v "$key" '%s' "$value"
                DEVICE_OVERRIDES="${DEVICE_OVERRIDES:+$DEVICE_OVERRIDES }$key"
            fi
        fi
    done < "$CARINA_DEVICE_OVERRIDE"
}

# Print device facts in sourceable KEY=value form
device_render_conf() {
    local key
    echo "# CARINA device facts - generated by 'carina device detect'."
    echo "# Do not edit. Use 'carina device set <KEY> <value>' to override."
    printf 'DETECTED_AT=%q\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    for key in "${DEVICE_KEYS[@]}"; do
        printf '%s=%q\n' "$key" "${!key}"
    done
    printf 'DEVICE_OVERRIDES=%q\n' "$DEVICE_OVERRIDES"
}

device_write_conf() {
    local dir tmp
    dir=$(dirname "$CARINA_DEVICE_CONF")
    mkdir -p "$dir"
    tmp=$(mktemp "$dir/.device.conf.XXXXXX")
    device_render_conf > "$tmp"
    chmod 644 "$tmp"
    mv "$tmp" "$CARINA_DEVICE_CONF"
}

# Load device facts: from device.conf if present, otherwise detect live
device_load() {
    if [[ -r "$CARINA_DEVICE_CONF" ]]; then
        # shellcheck disable=SC1090
        source "$CARINA_DEVICE_CONF"
        DEVICE_SOURCE="$CARINA_DEVICE_CONF"
    else
        device_collect
        device_apply_overrides
        DEVICE_SOURCE="live"
    fi
}

# Export device facts so child processes (pack config scripts) can use them
device_export() {
    local key
    for key in "${DEVICE_KEYS[@]}"; do
        export "${key?}"
    done
}

# Set or clear a user override. Pass an empty value to clear.
device_set_override() {
    local key="$1" value="$2"
    local tmp dir
    dir=$(dirname "$CARINA_DEVICE_OVERRIDE")
    mkdir -p "$dir"
    tmp=$(mktemp "$dir/.device.override.XXXXXX")
    if [[ -f "$CARINA_DEVICE_OVERRIDE" ]]; then
        grep -v "^${key}=" "$CARINA_DEVICE_OVERRIDE" > "$tmp" || true
    else
        echo "# CARINA device overrides - managed by 'carina device set/unset'" > "$tmp"
    fi
    if [[ -n "$value" ]]; then
        echo "${key}=${value}" >> "$tmp"
    fi
    chmod 644 "$tmp"
    mv "$tmp" "$CARINA_DEVICE_OVERRIDE"
}
