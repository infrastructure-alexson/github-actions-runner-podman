#!/bin/bash

###############################################################################
# Podman Build and Push Script
# Purpose: Build container image with Podman and push to Docker Hub
# 
# Usage: ./build-and-push-podman.sh [OPTIONS]
# 
# Options:
#   --image IMAGE           Container image name (default: github-action-runner)
#   --tag TAG              Image tag (default: latest)
#   --registry REGISTRY    Docker registry (default: docker.io)
#   --username USERNAME    Docker Hub username (default: salexson)
#   --dockerfile FILE      Dockerfile path (default: Dockerfile)
#   --context DIR          Build context directory (default: .)
#   --platform PLATFORM    Platform (default: linux/amd64,linux/arm64)
#   --no-push              Build only, don't push
#   --help                 Show this help message
#
# Examples:
#   ./build-and-push-podman.sh
#   ./build-and-push-podman.sh --tag v1.0.0
#   ./build-and-push-podman.sh --no-push
###############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
IMAGE_NAME="github-action-runner"
IMAGE_TAG="latest"
REGISTRY="docker.io"
USERNAME="salexson"
DOCKERFILE="Dockerfile"
BUILD_CONTEXT="."
PLATFORM="linux/amd64,linux/arm64"
PUSH_IMAGE=true
VERBOSE=false

# Function to print colored output
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

# Function to print help
print_help() {
    head -n 30 "$0" | tail -n +4
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --image)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        --username)
            USERNAME="$2"
            shift 2
            ;;
        --dockerfile)
            DOCKERFILE="$2"
            shift 2
            ;;
        --context)
            BUILD_CONTEXT="$2"
            shift 2
            ;;
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --no-push)
            PUSH_IMAGE=false
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            print_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            print_help
            exit 1
            ;;
    esac
done

# Validate that Podman is installed
if ! command -v podman &> /dev/null; then
    print_error "Podman is not installed. Please install Podman first."
    exit 1
fi

# Validate that Dockerfile exists
if [ ! -f "$DOCKERFILE" ]; then
    print_error "Dockerfile not found at: $DOCKERFILE"
    exit 1
fi

# Build full image name
FULL_IMAGE_NAME="${REGISTRY}/${USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

print_info "Building container image with Podman"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_info "Image Name:     $IMAGE_NAME"
print_info "Tag:            $IMAGE_TAG"
print_info "Registry:       $REGISTRY"
print_info "Username:       $USERNAME"
print_info "Dockerfile:     $DOCKERFILE"
print_info "Build Context:  $BUILD_CONTEXT"
print_info "Platforms:      $PLATFORM"
print_info "Full Image:     $FULL_IMAGE_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Build the image
print_info "Step 1: Building image locally..."
echo ""

if [ "$VERBOSE" = true ]; then
    VERBOSE_FLAG="--verbose"
else
    VERBOSE_FLAG=""
fi

podman build \
    --tag "$FULL_IMAGE_NAME" \
    --tag "${REGISTRY}/${USERNAME}/${IMAGE_NAME}:latest" \
    --file "$DOCKERFILE" \
    $VERBOSE_FLAG \
    "$BUILD_CONTEXT"

if [ $? -eq 0 ]; then
    print_success "Image built successfully: $FULL_IMAGE_NAME"
else
    print_error "Failed to build image"
    exit 1
fi

echo ""

# Step 2: Verify image
print_info "Step 2: Verifying image..."
podman inspect "$FULL_IMAGE_NAME" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    print_success "Image verification successful"
    
    # Show image details
    echo ""
    print_info "Image Details:"
    podman images "$REGISTRY/$USERNAME/$IMAGE_NAME" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
else
    print_error "Failed to verify image"
    exit 1
fi

echo ""

# Step 3: Check authentication if pushing
if [ "$PUSH_IMAGE" = true ]; then
    print_info "Step 3: Checking Docker Hub authentication..."
    
    # Try to check if logged in by attempting a simple operation
    if podman push --dry-run "$FULL_IMAGE_NAME" &> /dev/null || \
       podman run --rm "$FULL_IMAGE_NAME" echo "Image is valid" &> /dev/null; then
        print_success "Authentication check passed"
    else
        print_warning "May not be authenticated to Docker Hub"
        print_info "Attempting to login to Docker Hub..."
        
        if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_PASSWORD" ]; then
            print_warning "Environment variables DOCKER_USERNAME and DOCKER_PASSWORD not set"
            print_info "Please login manually:"
            echo "  podman login docker.io"
            print_info "Then run this script again"
            exit 1
        else
            # Use environment variables for automated login
            echo "$DOCKER_PASSWORD" | podman login -u "$DOCKER_USERNAME" --password-stdin docker.io
            if [ $? -eq 0 ]; then
                print_success "Successfully logged in to Docker Hub"
            else
                print_error "Failed to login to Docker Hub"
                exit 1
            fi
        fi
    fi
    
    echo ""
    
    # Step 4: Push the image
    print_info "Step 4: Pushing image to Docker Hub..."
    echo ""
    
    podman push "$FULL_IMAGE_NAME"
    
    if [ $? -eq 0 ]; then
        print_success "Image pushed successfully to: $FULL_IMAGE_NAME"
    else
        print_error "Failed to push image"
        exit 1
    fi
    
    echo ""
    
    # Also push latest tag
    print_info "Pushing 'latest' tag..."
    podman push "${REGISTRY}/${USERNAME}/${IMAGE_NAME}:latest"
    
    if [ $? -eq 0 ]; then
        print_success "Latest tag pushed successfully"
    else
        print_warning "Failed to push latest tag (may already exist)"
    fi
    
else
    print_warning "Skipping push (--no-push flag used)"
    echo ""
    print_info "To push the image manually, run:"
    echo "  podman push $FULL_IMAGE_NAME"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_success "Build and push process completed successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Print final instructions
print_info "Image is now available at:"
echo "  🐳 Docker Hub: $FULL_IMAGE_NAME"
echo ""

print_info "To use this image, run:"
echo "  podman run $FULL_IMAGE_NAME"
echo ""

print_info "To pull this image on another system, run:"
echo "  podman pull $FULL_IMAGE_NAME"
echo ""

exit 0

