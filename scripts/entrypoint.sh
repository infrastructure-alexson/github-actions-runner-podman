#!/bin/bash

################################################################################
# GitHub Actions Runner Entrypoint - Simplified
# 
# This is a minimal entrypoint that follows the official GitHub Actions runner
# approach as closely as possible while supporting persistent volumes.
#
# Environment Variables (Required):
#   - GITHUB_ORG or GITHUB_REPO_URL
#   - GITHUB_TOKEN (registration token, expires in 1 hour)
#
# Environment Variables (Optional):
#   - RUNNER_NAME (default: runner-01)
#   - RUNNER_LABELS (default: self-hosted,linux)
#   - RUNNER_WORKDIR (default: _work)
################################################################################

set -euo pipefail

# Configuration
RUNNER_HOME="${RUNNER_HOME:-/home/runner}"
RUNNER_DIR="/opt/runner"
GITHUB_REPO_URL="${GITHUB_REPO_URL:-}"
GITHUB_ORG="${GITHUB_ORG:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
RUNNER_NAME="${RUNNER_NAME:-runner-01}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,linux}"
RUNNER_WORKDIR="${RUNNER_WORKDIR:-./_work}"
RUNNER_EPHEMERAL="${RUNNER_EPHEMERAL:-false}"
RUNNER_REPLACE="${RUNNER_REPLACE:-true}"

# Logging
log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

# Validate required environment
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

# Build registration URL
REGISTER_URL="${GITHUB_REPO_URL:-https://github.com/$GITHUB_ORG}"

# Change to runner directory
cd "$RUNNER_DIR"

# Configure runner
log_info "Configuring runner..."
log_info "  Name: $RUNNER_NAME"
log_info "  Labels: $RUNNER_LABELS"
log_info "  URL: $REGISTER_URL"

# Prepare config arguments
config_args=(
    "--unattended"
    "--replace"
    "--url" "$REGISTER_URL"
    "--token" "$GITHUB_TOKEN"
    "--name" "$RUNNER_NAME"
    "--labels" "$RUNNER_LABELS"
    "--work" "$RUNNER_WORKDIR"
)

if [[ "$RUNNER_EPHEMERAL" == "true" ]]; then
    config_args+=("--ephemeral")
fi

# Run config.sh
log_info "Registering runner with GitHub..."
./config.sh "${config_args[@]}"

log_info "Runner registered successfully"

# Persist credentials to volume for container restarts
log_info "Persisting credentials to volume..."
mkdir -p "$RUNNER_HOME/.runner"
for file in .runner .credentials .credentials_rsaparams .env .path; do
    if [[ -f "$file" ]]; then
        cp "$file" "$RUNNER_HOME/.runner/$file" 2>/dev/null || true
    fi
done

# Start the runner
log_info "Starting runner..."
exec ./run.sh
