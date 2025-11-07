#!/bin/bash
# Deploy GitHub Actions Runner Container
# Builds and runs the GitHub Actions runner image

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
REPO_URL=""
ORG_NAME=""
TOKEN=""
RUNNER_NAME=""
LABELS="podman,linux"
EPHEMERAL=false
REPLACE=true
IMAGE_NAME="github-actions-runner"
IMAGE_TAG="latest"
CONTAINER_NAME="github-runner"
REGISTRY=""
BUILD=false
PULL=false
DRY_RUN=false

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy GitHub Actions Runner Container

Options:
    --repo URL                Repository URL (e.g., https://github.com/user/repo)
    --org ORGANIZATION        Organization name (alternative to --repo)
    --token TOKEN            GitHub personal access token (required)
    --runner-name NAME       Runner name (default: auto-generated)
    --labels LABELS          Comma-separated runner labels (default: podman,linux)
    --ephemeral              Enable ephemeral mode (auto-cleanup after jobs)
    --no-replace             Don't replace existing runner configuration
    --image-name NAME        Container image name (default: github-actions-runner)
    --image-tag TAG          Container image tag (default: latest)
    --container-name NAME    Container name (default: github-runner)
    --registry REGISTRY      Container registry (optional)
    --build                  Build image before deployment
    --pull                   Pull latest base image before building
    --dry-run                Show commands without executing
    -h, --help              Show this help message

Examples:
    # Deploy to specific repository
    $0 --repo https://github.com/myorg/myrepo --token ghp_xxxx --runner-name runner-1

    # Deploy to organization with labels
    $0 --org myorg --token ghp_xxxx --labels podman,linux,x86_64 --build

    # Ephemeral runner (auto-cleanup)
    $0 --repo https://github.com/myorg/myrepo --token ghp_xxxx --ephemeral --build

EOF
    exit 0
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $*"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo)
                REPO_URL="$2"
                shift 2
                ;;
            --org)
                ORG_NAME="$2"
                shift 2
                ;;
            --token)
                TOKEN="$2"
                shift 2
                ;;
            --runner-name)
                RUNNER_NAME="$2"
                shift 2
                ;;
            --labels)
                LABELS="$2"
                shift 2
                ;;
            --ephemeral)
                EPHEMERAL=true
                shift
                ;;
            --no-replace)
                REPLACE=false
                shift
                ;;
            --image-name)
                IMAGE_NAME="$2"
                shift 2
                ;;
            --image-tag)
                IMAGE_TAG="$2"
                shift 2
                ;;
            --container-name)
                CONTAINER_NAME="$2"
                shift 2
                ;;
            --registry)
                REGISTRY="$2"
                shift 2
                ;;
            --build)
                BUILD=true
                shift
                ;;
            --pull)
                PULL=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                print_usage
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                ;;
        esac
    done
}

# Validate required arguments
validate_args() {
    if [[ -z "$REPO_URL" ]] && [[ -z "$ORG_NAME" ]]; then
        log_error "Either --repo or --org is required"
        print_usage
        exit 1
    fi
    
    if [[ -z "$TOKEN" ]]; then
        log_error "--token is required"
        print_usage
        exit 1
    fi
    
    # Auto-generate runner name if not provided
    if [[ -z "$RUNNER_NAME" ]]; then
        RUNNER_NAME="runner-$(date +%s)"
    fi
}

# Check if container runtime is available
check_runtime() {
    local runtime=""
    
    if command -v podman &> /dev/null; then
        runtime="podman"
    elif command -v docker &> /dev/null; then
        runtime="docker"
    else
        log_error "Neither podman nor docker is available"
        exit 1
    fi
    
    log_info "Using container runtime: $runtime"
    echo "$runtime"
}

# Build container image
build_image() {
    local runtime="$1"
    local image="${REGISTRY:+$REGISTRY/}${IMAGE_NAME}:${IMAGE_TAG}"
    local build_args=""
    
    log_info "Building container image: $image"
    
    if [[ "$PULL" == "true" ]]; then
        build_args="${build_args} --pull"
    fi
    
    local cmd="$runtime build $build_args -t $image -f ${PROJECT_DIR}/Dockerfile ${PROJECT_DIR}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "$cmd"
    else
        if ! eval "$cmd"; then
            log_error "Failed to build image"
            exit 1
        fi
        log_info "Image built successfully"
    fi
}

# Stop and remove existing container
cleanup_existing() {
    local runtime="$1"
    
    if $runtime ps -a --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
        log_warn "Container $CONTAINER_NAME already exists, removing..."
        
        local cmd="$runtime rm -f $CONTAINER_NAME"
        if [[ "$DRY_RUN" == "true" ]]; then
            log_debug "$cmd"
        else
            if ! eval "$cmd"; then
                log_error "Failed to remove existing container"
                exit 1
            fi
        fi
    fi
}

# Run container
run_container() {
    local runtime="$1"
    local image="${REGISTRY:+$REGISTRY/}${IMAGE_NAME}:${IMAGE_TAG}"
    
    log_info "Starting container: $CONTAINER_NAME"
    
    local run_cmd="$runtime run -d"
    run_cmd="$run_cmd --name $CONTAINER_NAME"
    run_cmd="$run_cmd --restart unless-stopped"
    run_cmd="$run_cmd -e GITHUB_REPO_URL='${REPO_URL:-https://github.com/$ORG_NAME}'"
    run_cmd="$run_cmd -e GITHUB_TOKEN='$TOKEN'"
    run_cmd="$run_cmd -e RUNNER_NAME='$RUNNER_NAME'"
    run_cmd="$run_cmd -e RUNNER_LABELS='$LABELS'"
    run_cmd="$run_cmd -e RUNNER_EPHEMERAL='$EPHEMERAL'"
    run_cmd="$run_cmd -e RUNNER_REPLACE='$REPLACE'"
    
    # Mount podman socket for container-in-container support
    if [[ "$runtime" == "podman" ]]; then
        run_cmd="$run_cmd --volume /run/podman/podman.sock:/var/run/docker.sock"
    else
        run_cmd="$run_cmd --volume /var/run/docker.sock:/var/run/docker.sock"
    fi
    
    run_cmd="$run_cmd $image"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "$run_cmd"
    else
        if ! eval "$run_cmd"; then
            log_error "Failed to start container"
            exit 1
        fi
        log_info "Container started successfully"
    fi
}

# Show container status
show_status() {
    local runtime="$1"
    
    log_info "Container status:"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        $runtime ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        log_info "View logs with: $runtime logs -f $CONTAINER_NAME"
    fi
}

# Main execution
main() {
    log_info "GitHub Actions Runner Deployment Script"
    
    parse_args "$@"
    validate_args
    
    local runtime=$(check_runtime)
    
    if [[ "$BUILD" == "true" ]]; then
        build_image "$runtime"
    fi
    
    cleanup_existing "$runtime"
    run_container "$runtime"
    show_status "$runtime"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        log_info "Deployment completed successfully!"
        log_info "Runner: $RUNNER_NAME"
        log_info "Repository: ${REPO_URL:-https://github.com/$ORG_NAME}"
        log_info "Ephemeral: $EPHEMERAL"
    else
        log_info "Dry run completed (no changes made)"
    fi
}

main "$@"

