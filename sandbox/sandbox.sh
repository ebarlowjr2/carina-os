#!/bin/bash
#
# CARINA Sandbox Core Functions
# Provides sandbox management using Podman
#

set -e

SANDBOX_DIR="/opt/carina/sandbox"
TEMPLATES_DIR="/opt/carina/sandbox/templates"
STATE_FILE="/var/lib/carina/sandboxes.json"
LOG_FILE="/var/log/carina-sandbox.log"
IMAGE_PREFIX="carina-sandbox"

# CARINA Color Palette
CARINA_CYAN='\033[38;2;61;232;255m'
CARINA_MAGENTA='\033[38;2;177;76;255m'
CARINA_BLUE='\033[38;2;31;162;255m'
CARINA_TEXT='\033[38;2;230;236;255m'
CARINA_MUTED='\033[38;2;154;163;199m'
NC='\033[0m'

log_action() {
    local action="$1"
    local details="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local user="${SUDO_USER:-$USER}"
    echo "[$timestamp] [$user] $action: $details" >> "$LOG_FILE"
}

ensure_dirs() {
    mkdir -p /var/lib/carina
    mkdir -p /var/log/carina
    touch "$LOG_FILE"
    if [[ ! -f "$STATE_FILE" ]]; then
        echo '{"sandboxes":[]}' > "$STATE_FILE"
    fi
}

check_podman() {
    if ! command -v podman &>/dev/null; then
        echo -e "${CARINA_MAGENTA}ERROR${NC}: Podman is not installed"
        echo "Install with: sudo apt-get install -y podman"
        return 1
    fi
}

generate_id() {
    local template="$1"
    local suffix
    suffix=$(head -c 4 /dev/urandom | xxd -p)
    echo "${template}-${suffix}"
}

parse_ttl() {
    local ttl="$1"
    local seconds=0
    
    if [[ "$ttl" =~ ^([0-9]+)m$ ]]; then
        seconds=$((${BASH_REMATCH[1]} * 60))
    elif [[ "$ttl" =~ ^([0-9]+)h$ ]]; then
        seconds=$((${BASH_REMATCH[1]} * 3600))
    elif [[ "$ttl" =~ ^([0-9]+)s$ ]]; then
        seconds=${BASH_REMATCH[1]}
    elif [[ "$ttl" =~ ^([0-9]+)$ ]]; then
        seconds=$((ttl * 60))
    else
        echo "Invalid TTL format: $ttl (use: 10m, 1h, 300s)"
        return 1
    fi
    
    echo "$seconds"
}

add_sandbox_state() {
    local id="$1"
    local template="$2"
    local ttl_seconds="$3"
    local start_time
    start_time=$(date +%s)
    local expire_time=$((start_time + ttl_seconds))
    
    local tmp_file
    tmp_file=$(mktemp)
    jq --arg id "$id" \
       --arg template "$template" \
       --argjson start "$start_time" \
       --argjson ttl "$ttl_seconds" \
       --argjson expire "$expire_time" \
       '.sandboxes += [{"id": $id, "template": $template, "start_time": $start, "ttl": $ttl, "expire_time": $expire}]' \
       "$STATE_FILE" > "$tmp_file"
    mv "$tmp_file" "$STATE_FILE"
}

remove_sandbox_state() {
    local id="$1"
    local tmp_file
    tmp_file=$(mktemp)
    jq --arg id "$id" '.sandboxes = [.sandboxes[] | select(.id != $id)]' "$STATE_FILE" > "$tmp_file"
    mv "$tmp_file" "$STATE_FILE"
}

sandbox_templates() {
    echo -e "${CARINA_CYAN}Available CARINA Sandbox Templates${NC}"
    echo -e "${CARINA_MUTED}===================================${NC}"
    echo ""
    
    if [[ ! -d "$TEMPLATES_DIR" ]]; then
        echo "No templates directory found at $TEMPLATES_DIR"
        return 1
    fi
    
    for template_dir in "$TEMPLATES_DIR"/*/; do
        if [[ -d "$template_dir" ]] && [[ -f "$template_dir/Containerfile" ]]; then
            local name
            name=$(basename "$template_dir")
            echo -e "  ${CARINA_CYAN}-${NC} $name"
        fi
    done
}

sandbox_list() {
    echo -e "${CARINA_CYAN}Active CARINA Sandboxes${NC}"
    echo -e "${CARINA_MUTED}=======================${NC}"
    echo ""
    
    ensure_dirs
    
    local current_time
    current_time=$(date +%s)
    
    local count
    count=$(jq '.sandboxes | length' "$STATE_FILE")
    
    if [[ "$count" -eq 0 ]]; then
        echo "No active sandboxes"
        return 0
    fi
    
    printf "%-14s %-10s %-8s %-8s\n" "ID" "TEMPLATE" "AGE" "TTL"
    printf "%-14s %-10s %-8s %-8s\n" "--" "--------" "---" "---"
    
    jq -r '.sandboxes[] | "\(.id)|\(.template)|\(.start_time)|\(.expire_time)"' "$STATE_FILE" | while IFS='|' read -r id template start_time expire_time; do
        local age=$((current_time - start_time))
        local ttl_remaining=$((expire_time - current_time))
        
        local age_str
        if [[ $age -lt 60 ]]; then
            age_str="${age}s"
        else
            age_str="$((age / 60))m"
        fi
        
        local ttl_str
        if [[ $ttl_remaining -le 0 ]]; then
            ttl_str="expired"
        elif [[ $ttl_remaining -lt 60 ]]; then
            ttl_str="${ttl_remaining}s"
        else
            ttl_str="$((ttl_remaining / 60))m"
        fi
        
        printf "%-14s %-10s %-8s %-8s\n" "$id" "$template" "$age_str" "$ttl_str"
    done
}

sandbox_up() {
    local template="$1"
    local ttl="${2:-10m}"
    local name="$3"
    
    check_podman || return 1
    ensure_dirs
    
    if [[ -z "$template" ]]; then
        echo "Usage: carina sandbox up <template> [--ttl 10m] [--name <name>]"
        sandbox_templates
        return 1
    fi
    
    local template_dir="$TEMPLATES_DIR/$template"
    if [[ ! -d "$template_dir" ]] || [[ ! -f "$template_dir/Containerfile" ]]; then
        echo -e "${CARINA_MAGENTA}ERROR${NC}: Template '$template' not found"
        sandbox_templates
        return 1
    fi
    
    local ttl_seconds
    ttl_seconds=$(parse_ttl "$ttl") || return 1
    
    local sandbox_id
    if [[ -n "$name" ]]; then
        sandbox_id="$name"
    else
        sandbox_id=$(generate_id "$template")
    fi
    
    local image_name="${IMAGE_PREFIX}-${template}:latest"
    
    echo -e "Building sandbox image: ${CARINA_CYAN}$template${NC}"
    log_action "BUILD" "template=$template image=$image_name"
    
    podman build -t "$image_name" -f "$template_dir/Containerfile" "$template_dir" >/dev/null 2>&1
    
    echo -e "Starting sandbox: ${CARINA_CYAN}$sandbox_id${NC}"
    log_action "START" "id=$sandbox_id template=$template ttl=${ttl_seconds}s"
    
    podman run -d \
        --name "$sandbox_id" \
        --security-opt no-new-privileges:true \
        --cap-drop ALL \
        --read-only \
        --tmpfs /tmp:rw,noexec,nosuid,size=100m \
        --tmpfs /home/sandbox:rw,noexec,nosuid,size=100m \
        --network bridge \
        --memory 512m \
        --cpus 1 \
        "$image_name" \
        sleep infinity >/dev/null
    
    add_sandbox_state "$sandbox_id" "$template" "$ttl_seconds"
    
    local ttl_display
    if [[ $ttl_seconds -lt 60 ]]; then
        ttl_display="${ttl_seconds} seconds"
    else
        ttl_display="$((ttl_seconds / 60)) minutes"
    fi
    
    echo ""
    echo -e "${CARINA_CYAN}Sandbox started:${NC} $sandbox_id"
    echo -e "${CARINA_TEXT}TTL:${NC} $ttl_display"
}

sandbox_exec() {
    local sandbox_id="$1"
    shift
    local cmd=("$@")
    
    check_podman || return 1
    
    if [[ -z "$sandbox_id" ]]; then
        echo "Usage: carina sandbox exec <name|id> <command>"
        return 1
    fi
    
    if [[ ${#cmd[@]} -eq 0 ]]; then
        cmd=("bash")
    fi
    
    if ! podman container exists "$sandbox_id" 2>/dev/null; then
        echo -e "${CARINA_MAGENTA}ERROR${NC}: Sandbox '$sandbox_id' not found"
        return 1
    fi
    
    log_action "EXEC" "id=$sandbox_id cmd=${cmd[*]}"
    
    podman exec -it "$sandbox_id" "${cmd[@]}"
}

sandbox_down() {
    local sandbox_id="$1"
    
    check_podman || return 1
    ensure_dirs
    
    if [[ -z "$sandbox_id" ]]; then
        echo "Usage: carina sandbox down <name|id>"
        return 1
    fi
    
    echo -e "Stopping sandbox: ${CARINA_CYAN}$sandbox_id${NC}"
    log_action "STOP" "id=$sandbox_id"
    
    podman stop "$sandbox_id" >/dev/null 2>&1 || true
    podman rm -f "$sandbox_id" >/dev/null 2>&1 || true
    
    remove_sandbox_state "$sandbox_id"
    
    echo -e "${CARINA_CYAN}Sandbox destroyed:${NC} $sandbox_id"
}

sandbox_cleanup() {
    check_podman || return 1
    ensure_dirs
    
    echo -e "${CARINA_CYAN}CARINA Sandbox Cleanup${NC}"
    echo -e "${CARINA_MUTED}======================${NC}"
    echo ""
    
    local current_time
    current_time=$(date +%s)
    local cleaned=0
    
    jq -r '.sandboxes[] | "\(.id)|\(.expire_time)"' "$STATE_FILE" 2>/dev/null | while IFS='|' read -r id expire_time; do
        if [[ $current_time -ge $expire_time ]]; then
            echo -e "Removing expired sandbox: ${CARINA_MAGENTA}$id${NC}"
            log_action "CLEANUP" "id=$id reason=expired"
            podman stop "$id" >/dev/null 2>&1 || true
            podman rm -f "$id" >/dev/null 2>&1 || true
            remove_sandbox_state "$id"
            cleaned=$((cleaned + 1))
        fi
    done
    
    echo ""
    echo "Removing orphaned containers..."
    local orphans
    orphans=$(podman ps -a --filter "name=${IMAGE_PREFIX}" --format "{{.Names}}" 2>/dev/null || true)
    
    for container in $orphans; do
        if ! jq -e --arg id "$container" '.sandboxes[] | select(.id == $id)' "$STATE_FILE" >/dev/null 2>&1; then
            echo -e "Removing orphan: ${CARINA_MAGENTA}$container${NC}"
            log_action "CLEANUP" "id=$container reason=orphan"
            podman rm -f "$container" >/dev/null 2>&1 || true
        fi
    done
    
    echo ""
    echo -e "${CARINA_CYAN}Cleanup complete${NC}"
}
