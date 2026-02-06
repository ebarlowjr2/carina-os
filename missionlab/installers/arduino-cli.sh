#!/bin/bash
#
# CARINA MissionLab - Arduino CLI Installer
# Downloads and installs Arduino CLI from official GitHub releases
#

set -e

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

INSTALL_PATH="/usr/local/bin/arduino-cli"
ARDUINO_CLI_VERSION="latest"

# Get latest release version from GitHub API
get_latest_version() {
    local version
    version=$(curl -fsSL "https://api.github.com/repos/arduino/arduino-cli/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')
    echo "$version"
}

# Build download URL based on architecture
get_download_url() {
    local version="$1"
    local arch=$(detect_arch)
    local os=$(detect_os)
    
    local os_name=""
    local arch_name=""
    
    case "$os" in
        Linux)
            os_name="Linux"
            ;;
        macOS)
            os_name="macOS"
            ;;
        *)
            ml_error "Unsupported OS: $os"
            return 1
            ;;
    esac
    
    case "$arch" in
        64bit)
            arch_name="64bit"
            ;;
        ARM64)
            arch_name="ARM64"
            ;;
        ARMv7)
            arch_name="ARMv7"
            ;;
        *)
            ml_error "Unsupported architecture: $arch"
            return 1
            ;;
    esac
    
    echo "https://downloads.arduino.cc/arduino-cli/arduino-cli_${version}_${os_name}_${arch_name}.tar.gz"
}

install_arduino_cli() {
    ml_info "Installing arduino-cli..."
    
    # Check if already installed
    if [[ -f "$INSTALL_PATH" ]]; then
        local current_version=$("$INSTALL_PATH" version 2>/dev/null | grep -oP 'Version: \K[0-9.]+' || echo "unknown")
        ml_warn "arduino-cli already installed (version $current_version)"
        ml_info "To reinstall, first run: carina missionlab uninstall arduino-cli"
        return 0
    fi
    
    # Get latest version
    ml_info "Fetching latest version..."
    local version=$(get_latest_version)
    if [[ -z "$version" ]]; then
        ml_error "Failed to determine latest version"
        log_action "install" "arduino-cli" "failed"
        return 1
    fi
    ml_info "Latest version: $version"
    
    # Get download URL
    local url=$(get_download_url "$version")
    if [[ $? -ne 0 ]]; then
        log_action "install" "arduino-cli" "failed"
        return 1
    fi
    
    # Create temp directory
    local tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT
    
    # Download
    ml_info "Downloading from $url..."
    local tarball="$tmp_dir/arduino-cli.tar.gz"
    if ! download_file "$url" "$tarball"; then
        ml_error "Download failed"
        log_action "install" "arduino-cli" "failed"
        return 1
    fi
    
    # Extract
    ml_info "Extracting..."
    tar -xzf "$tarball" -C "$tmp_dir"
    
    # Install binary
    ml_info "Installing to $INSTALL_PATH..."
    mv "$tmp_dir/arduino-cli" "$INSTALL_PATH"
    chmod +x "$INSTALL_PATH"
    
    # Verify installation
    if ! command_exists arduino-cli; then
        ml_error "Installation verification failed"
        log_action "install" "arduino-cli" "failed"
        return 1
    fi
    
    local installed_version=$("$INSTALL_PATH" version 2>/dev/null | grep -oP 'Version: \K[0-9.]+' || echo "$version")
    
    # Initialize config for the actual user (not root)
    local actual_user=$(get_actual_user)
    local actual_home=$(get_actual_home)
    
    if [[ ! -f "$actual_home/.arduino15/arduino-cli.yaml" ]]; then
        ml_info "Initializing arduino-cli configuration for $actual_user..."
        sudo -u "$actual_user" "$INSTALL_PATH" config init 2>/dev/null || true
    fi
    
    # Update core index
    ml_info "Updating core index..."
    sudo -u "$actual_user" "$INSTALL_PATH" core update-index 2>/dev/null || true
    
    ml_ok "Installed arduino-cli v$installed_version to $INSTALL_PATH"
    log_action "install" "arduino-cli" "success" "$installed_version"
    
    return 0
}

uninstall_arduino_cli() {
    local purge="${1:-false}"
    
    ml_info "Uninstalling arduino-cli..."
    
    if [[ ! -f "$INSTALL_PATH" ]]; then
        ml_warn "arduino-cli is not installed"
        return 0
    fi
    
    # Remove binary
    rm -f "$INSTALL_PATH"
    ml_ok "Removed $INSTALL_PATH"
    
    # Purge user config if requested
    if [[ "$purge" == "true" ]] || [[ "$purge" == "--purge" ]]; then
        local actual_home=$(get_actual_home)
        if [[ -d "$actual_home/.arduino15" ]]; then
            rm -rf "$actual_home/.arduino15"
            ml_ok "Removed user configuration at $actual_home/.arduino15"
        fi
    fi
    
    log_action "uninstall" "arduino-cli" "success"
    ml_ok "arduino-cli uninstalled"
    
    return 0
}

# Check if installed and return version
check_installed() {
    if [[ -f "$INSTALL_PATH" ]]; then
        local version=$("$INSTALL_PATH" version 2>/dev/null | grep -oP 'Version: \K[0-9.]+' || echo "unknown")
        echo "installed ($version)"
        return 0
    else
        echo "not installed"
        return 1
    fi
}

# Main entry point
main() {
    local action="${1:-install}"
    shift || true
    
    case "$action" in
        install)
            install_arduino_cli "$@"
            ;;
        uninstall)
            uninstall_arduino_cli "$@"
            ;;
        check)
            check_installed
            ;;
        *)
            ml_error "Unknown action: $action"
            echo "Usage: $0 [install|uninstall|check]"
            return 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
