#!/bin/bash
###############################################################################
# GitHub Action Runner - Container Entrypoint
# Purpose: Initialize and start GitHub Action Runner in container
###############################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if running as root
if [[ "$EUID" == "0" ]]; then
    print_warning "Running as root - this is not recommended for GitHub Actions Runner"
fi

# Check required environment variables
if [[ -z "$GITHUB_REPOSITORY" ]] || [[ -z "$RUNNER_TOKEN" ]]; then
    print_error "Required environment variables not set"
    print_info "Required variables:"
    echo "  - GITHUB_REPOSITORY: Repository URL (e.g., owner/repo)"
    echo "  - RUNNER_TOKEN: GitHub runner registration token"
    echo ""
    print_info "Optional variables:"
    echo "  - RUNNER_NAME: Custom runner name (default: hostname)"
    echo "  - RUNNER_LABELS: Comma-separated labels (default: none)"
    echo "  - RUNNER_GROUPS: Comma-separated groups (default: default)"
    echo "  - RUNNER_WORKDIR: Working directory (default: /home/runner/_work)"
    exit 1
fi

# Set defaults
RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
RUNNER_WORKDIR="${RUNNER_WORKDIR:-/home/runner/_work}"
RUNNER_LABELS="${RUNNER_LABELS:-linux,${RUNNER_LABELS}}"

# Print configuration
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_info "GitHub Action Runner Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_info "Repository: $GITHUB_REPOSITORY"
print_info "Runner Name: $RUNNER_NAME"
print_info "Runner Labels: $RUNNER_LABELS"
print_info "Working Directory: $RUNNER_WORKDIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create working directory if it doesn't exist
mkdir -p "$RUNNER_WORKDIR"

# Change to runner directory
cd /opt/runner

# Configure runner
print_info "Configuring GitHub Action Runner..."

CONFIGURE_ARGS=(
    "--url" "https://github.com/$GITHUB_REPOSITORY"
    "--token" "$RUNNER_TOKEN"
    "--name" "$RUNNER_NAME"
    "--labels" "$RUNNER_LABELS"
    "--work" "$RUNNER_WORKDIR"
    "--unattended"
    "--replace"
)

# Add optional arguments
if [[ -n "$RUNNER_GROUPS" ]]; then
    CONFIGURE_ARGS+=("--runnergroup" "$RUNNER_GROUPS")
fi

# Run configuration
if ./config.sh "${CONFIGURE_ARGS[@]}"; then
    print_success "Runner configuration completed successfully"
else
    print_error "Failed to configure runner"
    exit 1
fi

echo ""

# Handle signals
trap_handler() {
    print_info "Received signal, shutting down runner..."
    
    # Run removal script to unregister runner
    if [[ -f "./remove.sh" ]]; then
        print_info "Unregistering runner from GitHub..."
        ./remove.sh --token "$RUNNER_TOKEN" || true
    fi
    
    print_info "Runner shutdown complete"
    exit 0
}

trap trap_handler SIGTERM SIGINT

# Start runner service
print_info "Starting GitHub Action Runner..."
print_success "Runner is ready to accept jobs"
echo ""

# Run the runner in foreground
./run.sh &
RUNNER_PID=$!

# Wait for runner process
wait $RUNNER_PID
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    print_success "Runner exited successfully"
else
    print_warning "Runner exited with code: $EXIT_CODE"
fi

exit $EXIT_CODE

