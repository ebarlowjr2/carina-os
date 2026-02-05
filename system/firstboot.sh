#!/bin/bash
#
# CARINA OS First Boot Script
# Executes once at first boot to configure the system
#

set -e

LOGFILE="/var/log/carina-firstboot.log"
CONFIG_FILE="/etc/carina/firstboot.yaml"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "$LOGFILE"
}

error() {
    log "ERROR: $1"
    exit 1
}

parse_yaml_value() {
    local key="$1"
    local file="$2"
    grep "^${key}:" "$file" 2>/dev/null | sed "s/^${key}:[[:space:]]*//" | tr -d '"' | tr -d "'"
}

parse_yaml_list() {
    local key="$1"
    local file="$2"
    local in_list=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^${key}: ]]; then
            in_list=1
            continue
        fi
        if [[ $in_list -eq 1 ]]; then
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*(.*) ]]; then
                echo "${BASH_REMATCH[1]}" | tr -d '"' | tr -d "'"
            elif [[ ! "$line" =~ ^[[:space:]] ]]; then
                break
            fi
        fi
    done < "$file"
}

set_hostname() {
    local hostname="$1"
    if [[ -n "$hostname" ]]; then
        log "Setting hostname to: $hostname"
        hostnamectl set-hostname "$hostname"
        echo "$hostname" > /etc/hostname
        sed -i "s/127.0.1.1.*/127.0.1.1\t$hostname/" /etc/hosts 2>/dev/null || \
            echo "127.0.1.1	$hostname" >> /etc/hosts
        log "Hostname set successfully"
    fi
}

create_user() {
    local username="$1"
    if [[ -n "$username" ]]; then
        if id "$username" &>/dev/null; then
            log "User $username already exists"
        else
            log "Creating user: $username"
            useradd -m -s /bin/bash "$username"
            usermod -aG sudo "$username"
            log "User $username created and added to sudo group"
        fi
    fi
}

setup_ssh_keys() {
    local username="$1"
    shift
    local keys=("$@")
    
    if [[ ${#keys[@]} -eq 0 ]]; then
        return
    fi
    
    local target_user="${username:-root}"
    local ssh_dir
    
    if [[ "$target_user" == "root" ]]; then
        ssh_dir="/root/.ssh"
    else
        ssh_dir="/home/$target_user/.ssh"
    fi
    
    log "Setting up SSH keys for $target_user"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    for key in "${keys[@]}"; do
        if [[ -n "$key" ]]; then
            echo "$key" >> "$ssh_dir/authorized_keys"
        fi
    done
    
    chmod 600 "$ssh_dir/authorized_keys"
    
    if [[ "$target_user" != "root" ]]; then
        chown -R "$target_user:$target_user" "$ssh_dir"
    fi
    
    log "SSH keys configured"
}

enable_gui() {
    local enable="$1"
    if [[ "$enable" == "true" ]]; then
        log "Enabling GUI..."
        if command -v carina &>/dev/null; then
            carina gui enable
        else
            systemctl set-default graphical.target
        fi
        log "GUI enabled"
    fi
}

main() {
    log "========================================"
    log "CARINA OS First Boot Configuration"
    log "========================================"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log "No configuration file found at $CONFIG_FILE"
        log "Skipping first-boot configuration"
        exit 0
    fi
    
    log "Reading configuration from $CONFIG_FILE"
    
    local hostname
    hostname=$(parse_yaml_value "hostname" "$CONFIG_FILE")
    set_hostname "$hostname"
    
    local username
    username=$(parse_yaml_value "user" "$CONFIG_FILE")
    create_user "$username"
    
    local keys=()
    while IFS= read -r key; do
        keys+=("$key")
    done < <(parse_yaml_list "ssh_authorized_keys" "$CONFIG_FILE")
    setup_ssh_keys "$username" "${keys[@]}"
    
    local enable_gui_val
    enable_gui_val=$(parse_yaml_value "enable_gui" "$CONFIG_FILE")
    enable_gui "$enable_gui_val"
    
    log "========================================"
    log "First boot configuration complete"
    log "========================================"
}

main "$@"
