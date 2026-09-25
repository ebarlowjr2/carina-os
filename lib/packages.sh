#!/bin/bash
#
# CARINA package list installer
# Shared by profiles and hardware packs.
#
# A directory may contain:
#   packages.txt          packages for every architecture
#   packages.<arch>.txt   extra packages for one dpkg architecture
#                         (e.g. packages.amd64.txt, packages.arm64.txt)
# One package per line; blank lines and # comments are ignored.
#

_pkg_read_list() {
    local file="$1" line
    [[ -f "$file" ]] || return 0
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line=$(echo "$line" | tr -d '[:space:]')
        [[ -n "$line" ]] && echo "$line"
    done < "$file"
}

# Print the package list for a directory and architecture
carina_package_list() {
    local dir="$1" arch="$2"
    _pkg_read_list "$dir/packages.txt"
    if [[ -n "$arch" ]]; then
        _pkg_read_list "$dir/packages.${arch}.txt"
    fi
}

carina_install_packages_from_dir() {
    local dir="$1" arch="$2"
    local packages=() to_install=() pkg

    while IFS= read -r pkg; do
        packages+=("$pkg")
    done < <(carina_package_list "$dir" "$arch")

    if [[ ${#packages[@]} -eq 0 ]]; then
        return 0
    fi

    echo "Installing packages..."
    # Filter out already-installed packages to skip unnecessary work
    for pkg in "${packages[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        echo "  All ${#packages[@]} packages already installed, skipping."
        return 0
    fi

    echo "  Installing ${#to_install[@]} packages (${#packages[@]} total, $((${#packages[@]} - ${#to_install[@]})) already installed)..."
    apt-get update -qq
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${to_install[@]}" 2>/dev/null; then
        echo "  Batch install failed, falling back to individual packages..."
        for pkg in "${to_install[@]}"; do
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg" || echo "  Warning: Failed to install $pkg"
        done
    fi
    echo "Packages installed."
}
