#!/bin/bash
#
# CARINA Hardware Packs
# A hardware pack is the "what am I running on" layer that sits under the
# regular profiles. Each pack lives in <hardware dir>/<name>/ and contains:
#
#   pack.conf            DESCRIPTION="..." and a pack_matches() function
#                        that returns 0 when the pack fits this device.
#                        Device facts (CHASSIS, HAS_BATTERY, ARCH, ...) are
#                        available as variables.
#   packages.txt         optional, see lib/packages.sh
#   packages.<arch>.txt  optional, per-architecture extras
#   config.sh            optional, run as root after packages are installed
#                        with the device facts exported as env variables
#
# Requires lib/device.sh and lib/packages.sh to be sourced first.
#

CARINA_HW_STATE="${CARINA_HW_STATE:-/var/lib/carina/hardware-packs}"

hw_pack_names() {
    local dir
    for dir in "$CARINA_HW_DIR"/*/; do
        [[ -f "$dir/pack.conf" ]] && basename "$dir"
    done
    return 0
}

hw_pack_exists() {
    [[ -n "$1" ]] && [[ "$1" != */* ]] && [[ -f "$CARINA_HW_DIR/$1/pack.conf" ]]
}

hw_pack_description() {
    (
        DESCRIPTION=""
        # shellcheck disable=SC1090
        source "$CARINA_HW_DIR/$1/pack.conf"
        echo "$DESCRIPTION"
    )
}

# Returns 0 if the pack matches the currently loaded device facts.
# Runs in a subshell so pack.conf can't leak state into the CLI.
hw_pack_matches() {
    (
        unset -f pack_matches
        # shellcheck disable=SC1090
        source "$CARINA_HW_DIR/$1/pack.conf"
        declare -F pack_matches >/dev/null || exit 1
        pack_matches
    )
}

hw_pack_is_applied() {
    [[ -f "$CARINA_HW_STATE" ]] && grep -qx "$1" "$CARINA_HW_STATE"
}

hw_matching_packs() {
    local name
    while IFS= read -r name; do
        hw_pack_matches "$name" && echo "$name"
    done < <(hw_pack_names)
    return 0
}

hw_mark_applied() {
    mkdir -p "$(dirname "$CARINA_HW_STATE")"
    touch "$CARINA_HW_STATE"
    if ! grep -qx "$1" "$CARINA_HW_STATE"; then
        echo "$1" >> "$CARINA_HW_STATE"
    fi
}

# Install a pack's packages and run its config script
hw_apply_pack() {
    local name="$1"
    local dir="$CARINA_HW_DIR/$name"

    carina_install_packages_from_dir "$dir" "$ARCH"

    if [[ -f "$dir/config.sh" ]]; then
        echo "Running configuration..."
        (
            device_export
            export CARINA_LIB_DIR
            bash "$dir/config.sh"
        )
        echo "Configuration complete."
    fi

    hw_mark_applied "$name"
}
