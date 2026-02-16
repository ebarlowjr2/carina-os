#!/bin/bash
#
# CARINA Control - Executor
# Executes approved proposals inside sandboxes
#
# SECURITY GUARANTEES:
# - Execution ONLY occurs via 'carina sandbox up' (no direct shell)
# - No host mounts allowed
# - No privileged containers
# - No write access to host filesystem
# - All execution is logged and auditable
# - Sandbox is destroyed after execution
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTROL_DIR="$(dirname "$SCRIPT_DIR")"
PROPOSALS_FILE="/var/lib/carina/control/proposals.json"
LOG_FILE="/var/log/carina-control.log"

# Source policy engine
source "$SCRIPT_DIR/policies.sh"

# Log function
log_action() {
    local user="${SUDO_USER:-$(whoami)}"
    local action="$1"
    local proposal_id="$2"
    local status="$3"
    local sandbox="${4:-none}"
    local extra="${5:-}"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="$timestamp user=$user action=$action proposal=$proposal_id status=$status sandbox=$sandbox"
    
    if [[ -n "$extra" ]]; then
        log_entry="$log_entry $extra"
    fi
    
    echo "$log_entry" >> "$LOG_FILE"
}

# Initialize proposals file if it doesn't exist
init_proposals() {
    local dir=$(dirname "$PROPOSALS_FILE")
    
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        chown root:carina "$dir" 2>/dev/null || true
        chmod 2775 "$dir"
    fi
    
    if [[ ! -f "$PROPOSALS_FILE" ]]; then
        echo '{"proposals":[],"next_id":1}' > "$PROPOSALS_FILE"
        chown root:carina "$PROPOSALS_FILE" 2>/dev/null || true
        chmod 664 "$PROPOSALS_FILE"
    fi
}

# Get next proposal ID
get_next_id() {
    init_proposals
    jq -r '.next_id' "$PROPOSALS_FILE"
}

# Increment next ID
increment_id() {
    local current=$(get_next_id)
    local next=$((current + 1))
    
    local tmp=$(mktemp)
    jq ".next_id = $next" "$PROPOSALS_FILE" > "$tmp"
    mv "$tmp" "$PROPOSALS_FILE"
    chmod 664 "$PROPOSALS_FILE"
}

# Add a new proposal
add_proposal() {
    local description="$1"
    local command="$2"
    local sandbox_template="${3:-ubuntu}"
    
    init_proposals
    
    # Validate command against policy
    local policy_result
    policy_result=$(validate_command "$command" 2>&1) || {
        echo "Policy rejected: $policy_result"
        return 1
    }
    
    # Assess risk level
    local risk_level=$(assess_risk "$command")
    
    # Get next ID
    local id=$(get_next_id)
    
    # Create proposal JSON
    local proposal=$(jq -n \
        --argjson id "$id" \
        --arg desc "$description" \
        --arg cmd "$command" \
        --arg template "$sandbox_template" \
        --arg risk "$risk_level" \
        '{
            id: $id,
            description: $desc,
            command: $cmd,
            sandbox_template: $template,
            risk_level: $risk,
            status: "pending",
            created_at: (now | strftime("%Y-%m-%d %H:%M:%S"))
        }')
    
    # Add to proposals file
    local tmp=$(mktemp)
    jq ".proposals += [$proposal]" "$PROPOSALS_FILE" > "$tmp"
    mv "$tmp" "$PROPOSALS_FILE"
    chmod 664 "$PROPOSALS_FILE"
    
    # Increment ID
    increment_id
    
    # Log the proposal
    log_action "propose" "$id" "created" "$sandbox_template"
    
    echo "$id"
}

# List all proposals
list_proposals() {
    local status_filter="${1:-all}"
    
    init_proposals
    
    if [[ "$status_filter" == "all" ]]; then
        jq -r '.proposals[] | "[\(.id)] \(.description)\n     Command: \(.command)\n     Risk: \(.risk_level | ascii_upcase)\n     Sandbox: \(.sandbox_template)\n     Status: \(.status)\n"' "$PROPOSALS_FILE"
    else
        jq -r --arg status "$status_filter" '.proposals[] | select(.status == $status) | "[\(.id)] \(.description)\n     Command: \(.command)\n     Risk: \(.risk_level | ascii_upcase)\n     Sandbox: \(.sandbox_template)\n     Status: \(.status)\n"' "$PROPOSALS_FILE"
    fi
}

# Get a specific proposal
get_proposal() {
    local id="$1"
    
    init_proposals
    jq -r --argjson id "$id" '.proposals[] | select(.id == $id)' "$PROPOSALS_FILE"
}

# Update proposal status
update_proposal_status() {
    local id="$1"
    local new_status="$2"
    
    local tmp=$(mktemp)
    jq --argjson id "$id" --arg status "$new_status" \
        '(.proposals[] | select(.id == $id)).status = $status' \
        "$PROPOSALS_FILE" > "$tmp"
    mv "$tmp" "$PROPOSALS_FILE"
    chmod 664 "$PROPOSALS_FILE"
}

# Approve and execute a proposal
# SECURITY: This is the ONLY path to execution
# Execution MUST go through sandbox, never direct shell
approve_and_execute() {
    local id="$1"
    
    init_proposals
    
    # Get proposal
    local proposal=$(get_proposal "$id")
    
    if [[ -z "$proposal" || "$proposal" == "null" ]]; then
        echo "Error: Proposal $id not found"
        log_action "approve" "$id" "not_found"
        return 1
    fi
    
    # Check status
    local status=$(echo "$proposal" | jq -r '.status')
    if [[ "$status" != "pending" ]]; then
        echo "Error: Proposal $id is not pending (status: $status)"
        log_action "approve" "$id" "invalid_status"
        return 1
    fi
    
    # Extract proposal details
    local command=$(echo "$proposal" | jq -r '.command')
    local template=$(echo "$proposal" | jq -r '.sandbox_template')
    local description=$(echo "$proposal" | jq -r '.description')
    
    # Re-validate command (defense in depth)
    local policy_result
    policy_result=$(validate_command "$command" 2>&1) || {
        echo "Policy rejected on re-validation: $policy_result"
        update_proposal_status "$id" "rejected"
        log_action "approve" "$id" "policy_rejected" "$template"
        return 1
    fi
    
    echo "Approving proposal $id: $description"
    echo ""
    
    # Update status to approved
    update_proposal_status "$id" "approved"
    log_action "approve" "$id" "approved" "$template"
    
    # SECURITY: Execute ONLY via sandbox
    # This is the critical security boundary
    echo "Spawning sandbox..."
    
    # Create sandbox with TTL
    local sandbox_name
    sandbox_name=$(carina sandbox up "$template" --ttl 5m 2>&1) || {
        echo "Error: Failed to create sandbox"
        update_proposal_status "$id" "failed"
        log_action "execute" "$id" "sandbox_failed" "$template"
        return 1
    }
    
    # Extract sandbox name from output
    sandbox_name=$(echo "$sandbox_name" | grep -oP 'Sandbox \K[a-z]+-[a-zA-Z0-9]+' | head -1)
    
    if [[ -z "$sandbox_name" ]]; then
        echo "Error: Could not determine sandbox name"
        update_proposal_status "$id" "failed"
        log_action "execute" "$id" "sandbox_name_failed" "$template"
        return 1
    fi
    
    echo "Executing command in sandbox $sandbox_name..."
    echo ""
    
    # Execute command inside sandbox
    # SECURITY: Command runs ONLY inside container, not on host
    local result
    local exit_code
    
    result=$(carina sandbox exec "$sandbox_name" $command 2>&1)
    exit_code=$?
    
    echo "Result:"
    echo "$result"
    echo ""
    
    # Destroy sandbox
    echo "Destroying sandbox..."
    carina sandbox destroy "$sandbox_name" --force 2>/dev/null || true
    
    # Update status based on result
    if [[ $exit_code -eq 0 ]]; then
        update_proposal_status "$id" "executed"
        log_action "execute" "$id" "success" "$template" "result=success"
        echo "Sandbox destroyed."
    else
        update_proposal_status "$id" "failed"
        log_action "execute" "$id" "failed" "$template" "result=failed exit_code=$exit_code"
        echo "Sandbox destroyed. (command failed with exit code $exit_code)"
    fi
    
    return $exit_code
}

# Reject a proposal
reject_proposal() {
    local id="$1"
    local reason="${2:-User rejected}"
    
    init_proposals
    
    # Get proposal
    local proposal=$(get_proposal "$id")
    
    if [[ -z "$proposal" || "$proposal" == "null" ]]; then
        echo "Error: Proposal $id not found"
        log_action "reject" "$id" "not_found"
        return 1
    fi
    
    # Check status
    local status=$(echo "$proposal" | jq -r '.status')
    if [[ "$status" != "pending" ]]; then
        echo "Error: Proposal $id is not pending (status: $status)"
        log_action "reject" "$id" "invalid_status"
        return 1
    fi
    
    # Update status
    update_proposal_status "$id" "rejected"
    log_action "reject" "$id" "rejected"
    
    echo "Proposal $id rejected: $reason"
}

# Clear completed/rejected proposals
clear_proposals() {
    local tmp=$(mktemp)
    jq '.proposals = [.proposals[] | select(.status == "pending")]' "$PROPOSALS_FILE" > "$tmp"
    mv "$tmp" "$PROPOSALS_FILE"
    chmod 664 "$PROPOSALS_FILE"
    
    echo "Cleared completed and rejected proposals"
    log_action "clear" "all" "cleared"
}

# Main entry point when executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        add)
            shift
            add_proposal "$@"
            ;;
        list)
            shift
            list_proposals "$@"
            ;;
        approve)
            shift
            approve_and_execute "$@"
            ;;
        reject)
            shift
            reject_proposal "$@"
            ;;
        clear)
            clear_proposals
            ;;
        *)
            echo "Usage: $0 {add|list|approve|reject|clear}"
            exit 1
            ;;
    esac
fi
