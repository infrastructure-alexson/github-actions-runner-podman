#!/bin/bash
# GitHub Actions Runner Entrypoint Script
# Handles runner registration and startup

set -euo pipefail

# Color output for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration from environment
GITHUB_REPO_URL="${GITHUB_REPO_URL:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GITHUB_ORG="${GITHUB_ORG:-}"
RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
RUNNER_LABELS="${RUNNER_LABELS:-podman,linux}"
RUNNER_WORK_DIR="${RUNNER_WORK_DIR:-./_work}"
RUNNER_EPHEMERAL="${RUNNER_EPHEMERAL:-false}"
RUNNER_REPLACE="${RUNNER_REPLACE:-true}"

RUNNER_HOME="${RUNNER_HOME:-/home/runner}"
RUNNER_DIR="/opt/runner"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Validate required environment variables
validate_environment() {
    log_info "Validating environment..."
    
    if [[ -z "$GITHUB_REPO_URL" ]] && [[ -z "$GITHUB_ORG" ]]; then
        log_error "Either GITHUB_REPO_URL or GITHUB_ORG must be set"
        exit 1
    fi
    
    if [[ -z "$GITHUB_TOKEN" ]]; then
        log_error "GITHUB_TOKEN must be set"
        exit 1
    fi
    
    log_info "Environment validation passed"
}

# Configure runner
configure_runner() {
    log_info "Configuring GitHub Actions runner..."
    
    cd "${RUNNER_DIR}"
    
    # Ensure .runner directory exists with permissive permissions
    # This is critical for mounted volumes where permissions might be wrong
    if [[ ! -d "${RUNNER_HOME}/.runner" ]]; then
        mkdir -p "${RUNNER_HOME}/.runner"
    fi
    
    # Make directory world-writable during registration
    # config.sh might create files as root, so we need to allow writes
    sudo chmod 777 "${RUNNER_HOME}/.runner" 2>/dev/null || chmod 777 "${RUNNER_HOME}/.runner" 2>/dev/null || true
    sudo chown runner:runner "${RUNNER_HOME}/.runner" 2>/dev/null || chown runner:runner "${RUNNER_HOME}/.runner" 2>/dev/null || true
    
    # Build registration URL
    local register_url="${GITHUB_REPO_URL:-https://github.com/$GITHUB_ORG}"
    
    # Debug: Show what URL we're using
    log_info "Registration URL: $register_url"
    log_info "Runner Name: $RUNNER_NAME"
    log_info "Runner Labels: $RUNNER_LABELS"
    
    # Prepare registration arguments
    local config_args=(
        "--url" "$register_url"
        "--token" "${GITHUB_TOKEN}"
        "--name" "${RUNNER_NAME}"
        "--labels" "${RUNNER_LABELS}"
        "--work" "${RUNNER_WORK_DIR}"
    )
    
    # Add ephemeral flag if enabled
    if [[ "${RUNNER_EPHEMERAL}" == "true" ]]; then
        config_args+=("--ephemeral")
        log_info "Ephemeral mode enabled - runner will cleanup after each job"
    fi
    
    # Replace existing runner configuration if enabled
    if [[ "${RUNNER_REPLACE}" == "true" ]]; then
        config_args+=("--replace")
    fi
    
    # Unattended configuration
    config_args+=("--unattended")
    config_args+=("--disableupdate")
    
    log_info "Registering runner with GitHub..."
    if ./config.sh "${config_args[@]}"; then
        log_info "Runner registered successfully"
        
        # Fix ownership and permissions after config.sh
        # config.sh might create files with wrong ownership
        sudo chown -R runner:runner "${RUNNER_HOME}/.runner" 2>/dev/null || chown -R runner:runner "${RUNNER_HOME}/.runner" 2>/dev/null || true
        
        # Make sure runner can read all files, even if created by root
        sudo chmod -R u+r,u+w,g-rwx,o-rwx "${RUNNER_HOME}/.runner" 2>/dev/null || chmod -R u+r,u+w,g-rwx,o-rwx "${RUNNER_HOME}/.runner" 2>/dev/null || true
        sudo find "${RUNNER_HOME}/.runner" -type f -exec chmod 600 {} \; 2>/dev/null || find "${RUNNER_HOME}/.runner" -type f -exec chmod 600 {} \; 2>/dev/null || true
        sudo find "${RUNNER_HOME}/.runner" -type d -exec chmod 700 {} \; 2>/dev/null || find "${RUNNER_HOME}/.runner" -type d -exec chmod 700 {} \; 2>/dev/null || true
        
        # Create configured flag
        touch "${RUNNER_HOME}/.configured"
        chmod 644 "${RUNNER_HOME}/.configured" 2>/dev/null || true
        
        log_info "Runner configuration persisted successfully"
    else
        log_error "Failed to register runner"
        exit 1
    fi
}

# Cleanup on exit
cleanup() {
    log_info "Cleaning up and removing runner registration..."
    
    if [[ -f "${RUNNER_DIR}/.runner" ]]; then
        cd "${RUNNER_DIR}"
        ./config.sh remove --token "${GITHUB_TOKEN}" || log_warn "Runner cleanup failed (may already be unregistered)"
    fi
    
    exit 0
}

# Setup signal handlers
setup_signals() {
    trap cleanup SIGTERM SIGINT EXIT
}

# Check if runner is already configured
is_configured() {
    [[ -f "${RUNNER_DIR}/.runner" ]] && [[ -f "${RUNNER_DIR}/.credentials" ]]
}

# Main execution
main() {
    log_info "GitHub Actions Runner Entrypoint"
    log_info "Runner Home: ${RUNNER_HOME}"
    log_info "Runner Directory: ${RUNNER_DIR}"
    
    # Setup signal handlers for graceful shutdown
    setup_signals
    
    # Validate environment
    validate_environment
    
    # Configure runner if not already configured
    if is_configured; then
        log_warn "Runner already configured, skipping registration"
    else
        configure_runner
    fi
    
    # Start the runner listener
    log_info "Starting GitHub Actions Runner listener..."
    cd "${RUNNER_DIR}"
    
    # Execute the runner with passed arguments or use default
    exec ./bin/Runner.Listener run --startuptype service "${@:---startuptype service}"
}

# Execute main function
main "$@"

