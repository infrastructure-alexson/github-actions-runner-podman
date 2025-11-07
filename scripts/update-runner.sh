#!/bin/bash
# Update GitHub Actions Runner Image
# Rebuilds the image with latest runner and base OS updates

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
IMAGE_NAME="${IMAGE_NAME:-github-actions-runner}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-}"
BACKUP_OLD=true
PULL_BASE=true
RESTART_RUNNERS=false

print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Update GitHub Actions Runner Image

Options:
    --image-name NAME       Container image name (default: github-actions-runner)
    --image-tag TAG        Container image tag (default: latest)
    --runtime RUNTIME      Container runtime: docker or podman (auto-detect)
    --no-backup            Don't backup old image
    --no-pull              Don't pull base image before building
    --restart-runners      Restart running containers after update
    --force                Force rebuild without confirmation
    -h, --help             Show this help message

Examples:
    # Update image with new runner version
    $0

    # Update and restart running runners
    $0 --restart-runners

    # Force update without confirmation
    $0 --force

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

# Detect container runtime
detect_runtime() {
    if [[ -n "$CONTAINER_RUNTIME" ]]; then
        echo "$CONTAINER_RUNTIME"
        return
    fi
    
    if command -v podman &> /dev/null; then
        echo "podman"
    elif command -v docker &> /dev/null; then
        echo "docker"
    else
        log_error "Neither podman nor docker found"
        exit 1
    fi
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --image-name)
                IMAGE_NAME="$2"
                shift 2
                ;;
            --image-tag)
                IMAGE_TAG="$2"
                shift 2
                ;;
            --runtime)
                CONTAINER_RUNTIME="$2"
                shift 2
                ;;
            --no-backup)
                BACKUP_OLD=false
                shift
                ;;
            --no-pull)
                PULL_BASE=false
                shift
                ;;
            --restart-runners)
                RESTART_RUNNERS=true
                shift
                ;;
            --force)
                FORCE=true
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

# Get current image info
get_current_image_info() {
    local runtime="$1"
    local image="${IMAGE_NAME}:${IMAGE_TAG}"
    
    log_info "Checking current image: $image"
    
    if $runtime images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image}$"; then
        local current_id=$($runtime images --filter "reference=${image}" --format "{{.ID}}")
        local current_created=$($runtime images --filter "reference=${image}" --format "{{.CreatedAt}}")
        
        log_info "Current image ID: $current_id"
        log_info "Created: $current_created"
        echo "$current_id"
        return 0
    else
        log_warn "No current image found"
        return 1
    fi
}

# Backup old image
backup_image() {
    local runtime="$1"
    local image="${IMAGE_NAME}:${IMAGE_TAG}"
    local backup_tag="${IMAGE_TAG}-backup-$(date +%Y%m%d-%H%M%S)"
    local backup_image="${IMAGE_NAME}:${backup_tag}"
    
    if [[ "$BACKUP_OLD" != "true" ]]; then
        return
    fi
    
    if $runtime images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image}$"; then
        log_info "Backing up current image as: $backup_image"
        
        if $runtime tag "$image" "$backup_image"; then
            log_info "Backup created: $backup_image"
        else
            log_error "Failed to create backup"
            exit 1
        fi
    fi
}

# Build new image
build_image() {
    local runtime="$1"
    local image="${IMAGE_NAME}:${IMAGE_TAG}"
    local build_args=""
    
    log_info "Building new image: $image"
    
    if [[ "$PULL_BASE" == "true" ]]; then
        build_args="--pull"
        log_info "Pulling base image..."
    fi
    
    if ! $runtime build $build_args -t "$image" -f "${PROJECT_DIR}/Dockerfile" "${PROJECT_DIR}"; then
        log_error "Build failed!"
        exit 1
    fi
    
    log_info "Image built successfully"
    
    local new_id=$($runtime images --filter "reference=${image}" --format "{{.ID}}")
    log_info "New image ID: $new_id"
}

# Find and restart runners
restart_runners() {
    local runtime="$1"
    
    if [[ "$RESTART_RUNNERS" != "true" ]]; then
        return
    fi
    
    log_info "Finding running runners..."
    
    local containers=$($runtime ps --filter "ancestor=${IMAGE_NAME}" --format "{{.Names}}")
    
    if [[ -z "$containers" ]]; then
        log_warn "No running runners found"
        return
    fi
    
    for container in $containers; do
        log_info "Restarting container: $container"
        
        if $runtime restart "$container"; then
            log_info "Restarted: $container"
        else
            log_error "Failed to restart: $container"
        fi
    done
    
    log_info "Giving runners time to reconnect..."
    sleep 30
}

# Show update summary
show_summary() {
    local runtime="$1"
    local image="${IMAGE_NAME}:${IMAGE_TAG}"
    
    log_info "=== Update Summary ==="
    log_info "Image: $image"
    
    if $runtime images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image}$"; then
        local image_id=$($runtime images --filter "reference=${image}" --format "{{.ID}}")
        local size=$($runtime images --filter "reference=${image}" --format "{{.Size}}")
        local created=$($runtime images --filter "reference=${image}" --format "{{.CreatedAt}}")
        
        log_info "Image ID: $image_id"
        log_info "Size: $size"
        log_info "Created: $created"
    fi
    
    if [[ "$BACKUP_OLD" == "true" ]]; then
        local backups=$($runtime images --format "{{.Repository}}:{{.Tag}}" | grep "${IMAGE_NAME}.*backup" | wc -l)
        log_info "Backup images kept: $backups"
    fi
    
    if [[ "$RESTART_RUNNERS" == "true" ]]; then
        local running=$($runtime ps --filter "ancestor=${IMAGE_NAME}" --format "{{.Names}}" | wc -l)
        log_info "Runners restarted: $running"
    fi
    
    log_info "Update completed successfully!"
}

# Cleanup old backups (keep only 3)
cleanup_old_backups() {
    local runtime="$1"
    
    log_info "Cleaning up old backups..."
    
    local backups=$($runtime images --format "{{.Repository}}:{{.Tag}}" | grep "${IMAGE_NAME}.*backup" | sort -r)
    local count=0
    
    while IFS= read -r backup; do
        count=$((count + 1))
        if [[ $count -gt 3 ]]; then
            log_info "Removing old backup: $backup"
            $runtime rmi "$backup" || log_warn "Failed to remove: $backup"
        fi
    done <<< "$backups"
}

# Main
main() {
    log_info "GitHub Actions Runner Update Script"
    log_info "Starting update..."
    
    parse_args "$@"
    
    local runtime=$(detect_runtime)
    log_info "Using runtime: $runtime"
    
    # Show current state
    get_current_image_info "$runtime" || true
    
    # Confirm update
    if [[ "${FORCE:-false}" != "true" ]]; then
        read -p "Continue with update? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warn "Update cancelled"
            exit 0
        fi
    fi
    
    # Perform update
    backup_image "$runtime"
    build_image "$runtime"
    restart_runners "$runtime"
    cleanup_old_backups "$runtime"
    
    # Show summary
    show_summary "$runtime"
}

main "$@"

