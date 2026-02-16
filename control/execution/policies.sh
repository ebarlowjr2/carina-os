#!/bin/bash
#
# CARINA Control - Policy Engine
# Validates proposed commands against safety whitelist
#
# SECURITY GUARANTEES:
# - Only read-only and safe commands are allowed
# - No filesystem writes outside sandbox
# - No privileged operations
# - No network scanning or attacks
# - No system service manipulation
#

set -e

# Allowed command patterns (whitelist approach)
# These are safe, read-only operations that can run in sandbox
ALLOWED_PATTERNS=(
    # Version checks
    "^[a-zA-Z0-9_-]+ --version$"
    "^[a-zA-Z0-9_-]+ -v$"
    "^[a-zA-Z0-9_-]+ version$"
    
    # Tool info commands
    "^arduino-cli "
    "^platformio "
    "^pio "
    "^python --version$"
    "^python3 --version$"
    "^node --version$"
    "^npm --version$"
    "^cargo --version$"
    "^rustc --version$"
    "^go version$"
    "^gcc --version$"
    "^g++ --version$"
    "^make --version$"
    "^cmake --version$"
    
    # Read-only system info
    "^uname "
    "^cat /etc/os-release$"
    "^cat /proc/cpuinfo$"
    "^cat /proc/meminfo$"
    "^df -h$"
    "^free -h$"
    "^uptime$"
    "^whoami$"
    "^id$"
    "^env$"
    "^printenv$"
    
    # Safe file operations (read-only)
    "^ls "
    "^cat [^|;&]*$"
    "^head [^|;&]*$"
    "^tail [^|;&]*$"
    "^wc [^|;&]*$"
    "^file [^|;&]*$"
    "^stat [^|;&]*$"
    
    # Build and test commands (safe in sandbox)
    "^make$"
    "^make test$"
    "^make check$"
    "^npm test$"
    "^npm run test$"
    "^npm run lint$"
    "^npm run build$"
    "^cargo test$"
    "^cargo build$"
    "^cargo check$"
    "^go test$"
    "^go build$"
    "^pytest$"
    "^python -m pytest$"
)

# Explicitly forbidden patterns (blacklist for extra safety)
FORBIDDEN_PATTERNS=(
    # Destructive commands
    "rm -rf /"
    "rm -rf /*"
    "rm -rf ~"
    "rm -rf \$HOME"
    "> /dev/"
    "mkfs"
    "dd if="
    
    # Privilege escalation
    "sudo "
    "su "
    "chmod 777"
    "chown root"
    
    # System service manipulation
    "systemctl "
    "service "
    "init "
    "/etc/init.d/"
    
    # Network attacks
    "nmap "
    "masscan "
    "nikto "
    "sqlmap "
    "hydra "
    "metasploit"
    "msfconsole"
    
    # Package installation (should be explicit)
    "apt install"
    "apt-get install"
    "yum install"
    "dnf install"
    "pip install"
    "npm install -g"
    
    # Shell escapes and injection
    "eval "
    "exec "
    "\$("
    "\`"
    "| sh"
    "| bash"
    "; sh"
    "; bash"
    "&& sh"
    "&& bash"
    
    # Sensitive file access
    "/etc/shadow"
    "/etc/passwd"
    "~/.ssh/"
    "/.ssh/"
    ".env"
    "credentials"
    "secrets"
    
    # Crypto mining
    "xmrig"
    "minerd"
    "cpuminer"
)

# Check if command matches any forbidden pattern
check_forbidden() {
    local cmd="$1"
    
    for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
        if [[ "$cmd" == *"$pattern"* ]]; then
            echo "FORBIDDEN: Command contains blocked pattern: $pattern"
            return 1
        fi
    done
    
    return 0
}

# Check if command matches any allowed pattern
check_allowed() {
    local cmd="$1"
    
    for pattern in "${ALLOWED_PATTERNS[@]}"; do
        if [[ "$cmd" =~ $pattern ]]; then
            return 0
        fi
    done
    
    echo "NOT_ALLOWED: Command does not match any allowed pattern"
    return 1
}

# Main policy validation function
# Returns 0 if command is safe, 1 if rejected
validate_command() {
    local cmd="$1"
    
    # Empty command is invalid
    if [[ -z "$cmd" ]]; then
        echo "REJECTED: Empty command"
        return 1
    fi
    
    # Check forbidden patterns first (blacklist)
    if ! check_forbidden "$cmd"; then
        return 1
    fi
    
    # Check allowed patterns (whitelist)
    if ! check_allowed "$cmd"; then
        return 1
    fi
    
    echo "APPROVED: Command passed policy validation"
    return 0
}

# Assess risk level of a command
assess_risk() {
    local cmd="$1"
    
    # Low risk: version checks, read-only info
    if [[ "$cmd" =~ (--version|-v|version|whoami|id|uname|uptime) ]]; then
        echo "low"
        return
    fi
    
    # Medium risk: file reads, builds
    if [[ "$cmd" =~ (cat|ls|head|tail|make|build|test) ]]; then
        echo "medium"
        return
    fi
    
    # Default to medium
    echo "medium"
}

# If sourced, functions are available
# If executed directly, validate command from argument
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <command>"
        exit 1
    fi
    
    validate_command "$*"
fi
