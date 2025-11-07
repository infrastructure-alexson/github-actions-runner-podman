# Docker Registry Authentication Guide

**Date**: 2025-11-06  
**Issue**: Docker image pull failures with podman-compose  
**Error**: `requested access to the resource is denied`

---

## Problem

When running `docker-compose up -d`, you get:

```
Error: initializing source docker://salexson/github-action-runner:latest: 
reading manifest latest in docker.io/salexson/github-action-runner: 
requested access to the resource is denied

exit code: 125
```

Then container creation fails:
```
Error: no container with name or ID "github-runner" found: no such container
```

---

## Root Causes

| Cause | Symptoms | Solution |
|-------|----------|----------|
| Image doesn't exist | "requested access denied" | Build and push image first |
| Not authenticated to Docker Hub | Can't access private repos | Login to Docker Hub |
| Registry credentials expired | Access suddenly denied | Refresh credentials |
| Wrong registry/username | Image not found | Verify registry URL |
| Rate limiting (Docker Hub) | Intermittent failures | Wait or use authentication |

---

## Solution 1: Build the Image First

The image `docker.io/salexson/github-action-runner:latest` must exist before you can run it.

### Step 1: Build the Image

```bash
# Navigate to the repository
cd /path/to/github-actions-runner-podman

# Build the image
podman build -t salexson/github-action-runner:latest .

# Or use the build script
./scripts/build-and-push-podman.sh --no-push
```

### Step 2: Verify Image Was Built

```bash
# List local images
podman images | grep github-action-runner

# Expected output:
# REPOSITORY                              TAG      IMAGE ID     CREATED
# localhost/salexson/github-action-runner latest   abc123def    2 minutes ago
```

### Step 3: Tag for Docker Hub (If Pushing)

```bash
# Tag for Docker Hub
podman tag localhost/salexson/github-action-runner:latest docker.io/salexson/github-action-runner:latest
```

### Step 4: Now Try Docker-Compose

```bash
# This should work now
docker-compose up -d

# Verify
docker-compose ps
```

---

## Solution 2: Authenticate to Docker Hub

If you want to pull from Docker Hub directly (after pushing):

### Step 1: Login to Docker Hub

```bash
# As the gha user (or whoever runs docker-compose)
podman login docker.io

# Prompted for:
# Username: salexson
# Password: (your Docker Hub password or token)
```

### Step 2: Verify Authentication

```bash
# Check login was successful
cat ~/.docker/config.json

# Should show:
# {
#     "auths": {
#         "docker.io": {
#             "auth": "base64_encoded_credentials"
#         }
#     }
# }
```

### Step 3: Try Docker-Compose Again

```bash
docker-compose up -d
```

---

## Solution 3: Use Personal Access Token (Recommended)

Instead of password, use a Docker Hub Personal Access Token for better security.

### Step 1: Generate Token on Docker Hub

1. Go to https://hub.docker.com/settings/security
2. Click "New Access Token"
3. Name: `github-actions-runner`
4. Permissions: `Read & Write`
5. Generate and copy the token

### Step 2: Login with Token

```bash
# Use the token instead of password
echo "YOUR_TOKEN_HERE" | podman login -u salexson --password-stdin docker.io

# Or interactively
podman login docker.io
# Username: salexson
# Password: (paste your token)
```

### Step 3: Verify

```bash
# Test access
podman pull docker.io/salexson/github-action-runner:latest

# Should work without errors
```

---

## Solution 4: Use Local Image (No Registry)

If you don't want to push to Docker Hub, use the locally built image:

### Step 1: Build Locally

```bash
podman build -t github-action-runner:latest .
```

### Step 2: Update docker-compose.yml

Change the image reference:

**Before**:
```yaml
image: docker.io/salexson/github-action-runner:latest
```

**After**:
```yaml
image: github-action-runner:latest
```

Or with local registry prefix:
```yaml
image: localhost/github-action-runner:latest
```

### Step 3: Run Docker-Compose

```bash
docker-compose up -d
```

---

## Complete Workflow: Build and Run Locally

### If you want a complete local setup:

```bash
# 1. Navigate to repo
cd /path/to/github-actions-runner-podman

# 2. Build the image
podman build -t github-action-runner:latest .

# 3. Update docker-compose.yml
# Change: image: docker.io/salexson/github-action-runner:latest
# To: image: github-action-runner:latest

# 4. Set environment variables
export GITHUB_REPOSITORY=owner/repo
export GITHUB_TOKEN=ghs_xxxx
export RUNNER_NAME=runner-01
export RUNNER_LABELS=podman,linux,docker

# 5. Start services
docker-compose up -d

# 6. Verify
docker-compose ps
```

---

## Complete Workflow: Build, Push, and Run from Registry

### If you want to push to Docker Hub:

```bash
# 1. Ensure you're logged in
podman login docker.io
# Username: salexson
# Password: (token or password)

# 2. Navigate to repo
cd /path/to/github-actions-runner-podman

# 3. Build and push
./scripts/build-and-push-podman.sh --tag latest

# Or manually:
podman build -t docker.io/salexson/github-action-runner:latest .
podman push docker.io/salexson/github-action-runner:latest

# 4. Set environment variables
export GITHUB_REPOSITORY=owner/repo
export GITHUB_TOKEN=ghs_xxxx

# 5. Start services (will pull from Docker Hub)
docker-compose up -d

# 6. Verify
docker-compose ps
```

---

## Troubleshooting

### Error: "requested access to the resource is denied"

**Cause 1**: Image doesn't exist
```bash
# Check if image exists on Docker Hub
podman pull docker.io/salexson/github-action-runner:latest
# If it fails, you need to build and push first
```

**Cause 2**: Not authenticated
```bash
# Login to Docker Hub
podman login docker.io

# Then try pull again
podman pull docker.io/salexson/github-action-runner:latest
```

**Cause 3**: Wrong registry/username
```bash
# Verify the full image reference
echo "docker.io/salexson/github-action-runner:latest"

# Check it exists
podman search salexson
```

### Error: "no such container"

**Cause**: Previous step (pull) failed

**Solution**:
1. Fix the pull error first
2. Try `docker-compose up -d` again

```bash
# Debug steps
docker-compose config  # Verify config
docker-compose pull     # Try pulling first
docker-compose up -d    # Then create container
```

### Docker Hub Rate Limiting

**Error**: Intermittent "access denied" errors

**Solution**:
- Authenticate to Docker Hub (you get higher rate limits)
- Or wait a few minutes before retrying

```bash
# Login increases rate limit from 100 to 200 pulls per 6 hours
podman login docker.io
```

---

## Container Registry Options

### Option 1: Docker Hub (Public)
**URL**: `docker.io/salexson/github-action-runner:latest`  
**Pros**: Free, easy to share  
**Cons**: Public, rate limiting  
**Setup**: Push to Docker Hub

### Option 2: Docker Hub (Private)
**URL**: `docker.io/salexson/github-action-runner:latest`  
**Pros**: Secure, authenticated access  
**Cons**: Requires token/password  
**Setup**: Create private repo, login with token

### Option 3: Quay.io (Red Hat)
**URL**: `quay.io/salexson/github-action-runner:latest`  
**Pros**: Enterprise-grade, good for RHEL  
**Cons**: Different registry  
**Setup**: Create account at quay.io

### Option 4: Local Registry
**URL**: `localhost/github-action-runner:latest`  
**Pros**: No internet needed, no authentication  
**Cons**: Image only available locally  
**Setup**: Build locally

### Option 5: Private Registry (Enterprise)
**URL**: `registry.example.com/github-action-runner:latest`  
**Pros**: Full control, secure  
**Cons**: Must maintain registry  
**Setup**: Run your own registry

---

## Setting Environment Variables for Docker-Compose

### Create `.env` File

**File**: `.env` (in same directory as docker-compose.yml)

```bash
# GitHub configuration
GITHUB_REPOSITORY=owner/repo
GITHUB_TOKEN=ghs_xxxx
RUNNER_NAME=runner-01
RUNNER_LABELS=podman,linux,docker,x86_64

# Resource limits
RUNNER_CPUS=2
RUNNER_MEMORY=4G
RUNNER_CPUS_RESERVE=1
RUNNER_MEMORY_RESERVE=2G

# Work directories
WORK_DIR=./runner-work
CONFIG_DIR=./runner-config
```

### Or Set in Shell

```bash
export GITHUB_REPOSITORY=owner/repo
export GITHUB_TOKEN=ghs_xxxx
export RUNNER_NAME=runner-01
docker-compose up -d
```

### Or Use `-e` Flag

```bash
docker-compose up -d \
  -e GITHUB_REPOSITORY=owner/repo \
  -e GITHUB_TOKEN=ghs_xxxx
```

---

## Pre-Flight Checklist

Before running `docker-compose up -d`:

- [ ] Image exists locally OR you're authenticated to registry
  ```bash
  podman images | grep github-action-runner
  # OR
  podman login docker.io
  ```

- [ ] docker-compose.yml points to correct image
  ```bash
  grep "image:" docker-compose.yml
  ```

- [ ] Environment variables are set
  ```bash
  echo $GITHUB_REPOSITORY
  echo $GITHUB_TOKEN
  ```

- [ ] Directories are writable
  ```bash
  ls -la runner-work runner-config 2>/dev/null || mkdir -p runner-work runner-config
  ```

- [ ] Podman socket is accessible
  ```bash
  ls -la /run/podman/podman.sock
  ```

- [ ] docker-compose config is valid
  ```bash
  docker-compose config > /dev/null
  ```

---

## Verification Steps

### After Successful `docker-compose up -d`

```bash
# 1. Check container status
docker-compose ps
# STATUS should show: Up X seconds (healthy)

# 2. View logs
docker-compose logs -f github-runner

# 3. Check environment variables
docker-compose exec github-runner env | grep GITHUB

# 4. Verify runner registered
docker-compose exec github-runner test -f /home/runner/.configured && echo "Configured!" || echo "Not configured"

# 5. Check Podman access
docker-compose exec github-runner podman ps

# 6. Stop services
docker-compose down
```

---

## Docker-Compose Commands Reference

```bash
# View configuration
docker-compose config

# Pull images (without running)
docker-compose pull

# Start services
docker-compose up -d

# View running services
docker-compose ps

# View logs
docker-compose logs -f github-runner

# Execute command in container
docker-compose exec github-runner bash

# Restart service
docker-compose restart github-runner

# Stop services (keep data)
docker-compose stop

# Stop and remove services (remove data)
docker-compose down

# Remove images too
docker-compose down --rmi all

# Show resource usage
docker-compose stats

# Build image
docker-compose build
```

---

## Best Practices

### 1. Always Authenticate
```bash
podman login docker.io
# Increases rate limits and enables private repos
```

### 2. Use Tokens Not Passwords
```bash
# Generate at https://hub.docker.com/settings/security
echo "token" | podman login -u username --password-stdin docker.io
```

### 3. Tag Images Consistently
```bash
# Version tags
podman build -t github-action-runner:1.0.0 .
podman build -t github-action-runner:latest .

# Registry tags
podman tag github-action-runner:latest docker.io/salexson/github-action-runner:latest
```

### 4. Verify Before Pushing
```bash
podman run --rm github-action-runner:latest echo "Testing"
# Then push
podman push docker.io/salexson/github-action-runner:latest
```

### 5. Keep Credentials Secure
```bash
# Docker credentials stored in ~/.docker/config.json
# Protect this file
chmod 600 ~/.docker/config.json

# For CI/CD, use tokens not passwords
# Consider container registries with better security (Quay, ECR)
```

---

## References

- [Podman Documentation](https://docs.podman.io/)
- [Docker Hub](https://hub.docker.com/)
- [Podman-Compose GitHub](https://github.com/containers/podman-compose)
- [Container Registry Best Practices](https://docs.docker.com/docker-hub/best-practices/)

---

## Related Documentation

- [QUICK-START.md](QUICK-START.md) - Quick start guide
- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment instructions
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General troubleshooting
- [PODMAN-COMPOSE-COMPATIBILITY.md](PODMAN-COMPOSE-COMPATIBILITY.md) - Compose compatibility

---

**Last Updated**: 2025-11-06  
**Status**: ✅ Ready for Production

