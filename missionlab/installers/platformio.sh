#!/bin/bash
#
# CARINA MissionLab - PlatformIO Installer
# Installs PlatformIO using pipx for isolated environment
#

set -e

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

install_platformio() {
    ml_info "Installing PlatformIO..."
    
    local actual_user=$(get_actual_user)
    local actual_home=$(get_actual_home)
    
    # Check if already installed
    if sudo -u "$actual_user" bash -c 'command -v pio' &>/dev/null; then
        local current_version=$(sudo -u "$actual_user" pio --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        ml_warn "PlatformIO already installed (version $current_version)"
        ml_info "To reinstall, first run: carina missionlab uninstall platformio"
        return 0
    fi
    
    # Check for pipx in user's PATH
    local pipx_path=""
    if sudo -u "$actual_user" bash -c 'command -v pipx' &>/dev/null; then
        pipx_path=$(sudo -u "$actual_user" bash -c 'command -v pipx')
    fi
    
    # Install pipx if not available
    if [[ -z "$pipx_path" ]]; then
        ml_info "Installing pipx..."
        
        # Ensure python3-venv is installed
        if ! dpkg -l python3-venv &>/dev/null; then
            apt-get update -qq
            apt-get install -y -qq python3-venv python3-pip
        fi
        
        # Install pipx via apt
        if ! dpkg -l pipx &>/dev/null; then
            apt-get install -y -qq pipx
        fi
        
        # Ensure pipx path for user
        sudo -u "$actual_user" bash -c 'pipx ensurepath' 2>/dev/null || true
    fi
    
    # Install PlatformIO via pipx
    ml_info "Installing PlatformIO via pipx..."
    
    # Run as the actual user
    if ! sudo -u "$actual_user" bash -c 'pipx install platformio' 2>/dev/null; then
        ml_error "PlatformIO installation failed"
        log_action "install" "platformio" "failed"
        return 1
    fi
    
    # Verify installation
    local pio_path="$actual_home/.local/bin/pio"
    if [[ ! -f "$pio_path" ]]; then
        # Try to find it
        pio_path=$(sudo -u "$actual_user" bash -c 'command -v pio' 2>/dev/null || echo "")
    fi
    
    if [[ -z "$pio_path" ]] || [[ ! -f "$pio_path" ]]; then
        ml_warn "PlatformIO installed but 'pio' not found in PATH"
        ml_info "Add to your PATH: export PATH=\"\$PATH:\$HOME/.local/bin\""
        ml_info "Or add this line to ~/.bashrc for persistence"
        log_action "install" "platformio" "success-path-warning"
        return 0
    fi
    
    local installed_version=$(sudo -u "$actual_user" "$pio_path" --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    
    ml_ok "Installed PlatformIO v$installed_version"
    
    # Check if PATH needs updating
    if ! sudo -u "$actual_user" bash -c 'echo $PATH' | grep -q "$actual_home/.local/bin"; then
        echo ""
        ml_info "NOTE: Add ~/.local/bin to your PATH:"
        echo -e "  ${CARINA_TEXT}export PATH=\"\$PATH:\$HOME/.local/bin\"${NC}"
        echo ""
        ml_info "Add to ~/.bashrc for persistence:"
        echo -e "  ${CARINA_TEXT}echo 'export PATH=\"\$PATH:\$HOME/.local/bin\"' >> ~/.bashrc${NC}"
    fi
    
    log_action "install" "platformio" "success" "$installed_version"
    
    return 0
}

uninstall_platformio() {
    ml_info "Uninstalling PlatformIO..."
    
    local actual_user=$(get_actual_user)
    local actual_home=$(get_actual_home)
    
    # Check if installed
    if ! sudo -u "$actual_user" bash -c 'pipx list 2>/dev/null | grep -q platformio'; then
        ml_warn "PlatformIO is not installed via pipx"
        return 0
    fi
    
    # Uninstall via pipx
    if sudo -u "$actual_user" bash -c 'pipx uninstall platformio' 2>/dev/null; then
        ml_ok "PlatformIO uninstalled"
        log_action "uninstall" "platformio" "success"
    else
        ml_error "Failed to uninstall PlatformIO"
        log_action "uninstall" "platformio" "failed"
        return 1
    fi
    
    return 0
}

# Check if installed and return version
check_installed() {
    local actual_user=$(get_actual_user)
    local actual_home=$(get_actual_home)
    
    # Check via pipx list
    if sudo -u "$actual_user" bash -c 'pipx list 2>/dev/null | grep -q platformio'; then
        local version=$(sudo -u "$actual_user" bash -c 'pio --version 2>/dev/null' | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        echo "installed ($version)"
        return 0
    fi
    
    # Fallback: check if pio command exists
    if sudo -u "$actual_user" bash -c 'command -v pio' &>/dev/null; then
        local version=$(sudo -u "$actual_user" bash -c 'pio --version 2>/dev/null' | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        echo "installed ($version)"
        return 0
    fi
    
    echo "not installed"
    return 1
}

# Main entry point
main() {
    local action="${1:-install}"
    shift || true
    
    case "$action" in
        install)
            install_platformio "$@"
            ;;
        uninstall)
            uninstall_platformio "$@"
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
