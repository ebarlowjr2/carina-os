#!/bin/bash
#
# CARINA MissionLab - Common Library
# Shared functions for MissionLab installers
#

# CARINA Color Palette
CARINA_CYAN='\033[38;2;61;232;255m'
CARINA_MAGENTA='\033[38;2;177;76;255m'
CARINA_BLUE='\033[38;2;31;162;255m'
CARINA_TEXT='\033[38;2;230;236;255m'
CARINA_MUTED='\033[38;2;154;163;199m'
NC='\033[0m'

# Log file
MISSIONLAB_LOG="/var/log/carina-missionlab.log"

# Ensure log directory exists with proper permissions
ensure_log_dir() {
    if [[ ! -d /var/log ]]; then
        mkdir -p /var/log
    fi
    
    # Create log file if it doesn't exist
    if [[ ! -f "$MISSIONLAB_LOG" ]]; then
        touch "$MISSIONLAB_LOG"
        chmod 664 "$MISSIONLAB_LOG"
        
        # Set group ownership if carina group exists
        if getent group carina >/dev/null 2>&1; then
            chown root:carina "$MISSIONLAB_LOG" 2>/dev/null || true
        fi
    fi
}

# Log to file with timestamp
log_action() {
    local action="$1"
    local tool="$2"
    local status="$3"
    local version="${4:-}"
    local user="${SUDO_USER:-$USER}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    ensure_log_dir
    
    local log_line="$timestamp user=$user action=$action tool=$tool status=$status"
    if [[ -n "$version" ]]; then
        log_line="$log_line version=$version"
    fi
    
    echo "$log_line" >> "$MISSIONLAB_LOG" 2>/dev/null || true
}

# Print styled messages
ml_info() {
    echo -e "[${CARINA_CYAN}CARINA MissionLab${NC}] $1"
}

ml_ok() {
    echo -e "[${CARINA_CYAN}OK${NC}] $1"
}

ml_warn() {
    echo -e "[${CARINA_BLUE}WARN${NC}] $1"
}

ml_error() {
    echo -e "[${CARINA_MAGENTA}ERROR${NC}] $1"
}

ml_pass() {
    echo -e "[${CARINA_CYAN}PASS${NC}] $1"
}

ml_fail() {
    echo -e "[${CARINA_MAGENTA}FAIL${NC}] $1"
}

# Detect system architecture
detect_arch() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "64bit"
            ;;
        aarch64|arm64)
            echo "ARM64"
            ;;
        armv7l|armhf)
            echo "ARMv7"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Detect OS type
detect_os() {
    local os=$(uname -s)
    case "$os" in
        Linux)
            echo "Linux"
            ;;
        Darwin)
            echo "macOS"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        return 1
    fi
    return 0
}

# Check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Get the actual user (not root if running via sudo)
get_actual_user() {
    echo "${SUDO_USER:-$USER}"
}

# Get the actual user's home directory
get_actual_home() {
    local user=$(get_actual_user)
    eval echo "~$user"
}

# Ensure user is in a group
ensure_user_in_group() {
    local user="$1"
    local group="$2"
    
    if id -nG "$user" | grep -qw "$group"; then
        return 0
    fi
    
    usermod -aG "$group" "$user"
    return $?
}

# Download file with progress
download_file() {
    local url="$1"
    local output="$2"
    
    if command_exists curl; then
        curl -fsSL "$url" -o "$output"
    elif command_exists wget; then
        wget -q "$url" -O "$output"
    else
        ml_error "Neither curl nor wget available"
        return 1
    fi
}

# Verify checksum (SHA256)
verify_checksum() {
    local file="$1"
    local expected="$2"
    
    local actual=$(sha256sum "$file" | cut -d' ' -f1)
    
    if [[ "$actual" == "$expected" ]]; then
        return 0
    else
        return 1
    fi
}
