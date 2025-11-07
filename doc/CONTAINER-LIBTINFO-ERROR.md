# Container libtinfo.so.6 Memory Protection Error - Fix Guide

**Date**: 2025-11-06  
**Issue**: Container bash fails to load libtinfo.so.6 library  
**Error Source**: Inside the container (not host system)  
**Status**: ✅ Debugging & Fix Guide

---

## Problem

Container creates and starts, but immediately exits with:

```
/bin/bash: error while loading shared libraries: libtinfo.so.6: cannot change memory protections
```

This error appears in `podman logs github-runner`, meaning it's happening **inside the container**, not on the host.

---

## Root Causes (Container-Level)

### **Cause 1: Docker Hub Image Corrupted** (Most Likely)
- Image pull incomplete or interrupted
- Corrupted layers in registry
- Missing dependencies during build

### **Cause 2: libtinfo Library Missing**
- Not installed in image
- Wrong architecture binary
- Dependency installation failed

### **Cause 3: Image Build Issue**
- Dockerfile incomplete
- Base image doesn't have required libraries
- Build step skipped

---

## Quick Fix: Rebuild Locally

The fastest fix is to **build the image locally** instead of using the Docker Hub version:

```bash
# 1. Navigate to repo
cd /path/to/github-actions-runner-podman

# 2. Remove corrupted Docker Hub image
podman rmi docker.io/salexson/github-action-runner:latest

# 3. Rebuild from Dockerfile
podman build -t salexson/github-action-runner:latest .

# 4. Verify build succeeds
podman images | grep github-action-runner

# 5. Test the new image
podman run --rm salexson/github-action-runner:latest /bin/bash -c "echo 'Success!'"
```

If test succeeds, continue to Step 6.

---

## Step-by-Step Fix Process

### **Step 1: Remove Corrupted Image**

```bash
# Stop running container
docker-compose down

# Remove the corrupted image
podman rmi docker.io/salexson/github-action-runner:latest

# Verify it's removed
podman images | grep salexson
# Should show no results
```

### **Step 2: Rebuild Image**

```bash
# Navigate to repo
cd /path/to/github-actions-runner-podman

# Build locally (takes 5-10 minutes)
podman build -t salexson/github-action-runner:latest .

# Watch build output for errors
# Should end with: Successfully tagged salexson/github-action-runner:latest
```

### **Step 3: Verify Build**

```bash
# Check image was created
podman images | grep github-action-runner

# Test bash works
podman run --rm salexson/github-action-runner:latest /bin/bash -c "echo Test"

# Should output: Test

# If bash error: build failed, check logs
# If success: image is good!
```

### **Step 4: Update docker-compose.yml** (Optional)

If you want to use your local image instead of Docker Hub:

**Change**:
```yaml
image: docker.io/salexson/github-action-runner:latest
```

**To**:
```yaml
image: salexson/github-action-runner:latest
```

Or keep Docker Hub and push your build to it:

```bash
# Tag for Docker Hub
podman tag salexson/github-action-runner:latest docker.io/salexson/github-action-runner:latest

# Push (requires login)
podman login docker.io
podman push docker.io/salexson/github-action-runner:latest
```

### **Step 5: Start Container**

```bash
# Go to compose directory
cd /opt/gha

# Set environment (for org runner)
export GITHUB_ORG=my-org
export RUNNER_TOKEN=ghp_xxxx
export RUNNER_NAME=runner-01

# Start
docker-compose down
docker-compose up -d

# Check logs
podman logs github-runner

# Should show: [INFO] GitHub Actions Runner Entrypoint
```

### **Step 6: Verify Running**

```bash
# Check container status
podman ps

# Should show: Up X seconds (healthy)
# NOT: Exited

# Check logs for success
podman logs github-runner | tail -20

# Should show successful runner registration
```

---

## Diagnostic Commands

If you want to debug further:

### **Test Different Shells**

```bash
# Try built image with different shells
podman run --rm salexson/github-action-runner:latest /bin/sh -c "echo sh works"

# Try dash
podman run --rm salexson/github-action-runner:latest /bin/dash -c "echo dash works"
```

### **Check Container Libraries**

```bash
# See what libraries bash needs
podman run --rm salexson/github-action-runner:latest ldd /bin/bash

# Should show all libraries available
# If libtinfo.so.6 => not found: library missing
```

### **Check Image Details**

```bash
# Architecture
podman inspect salexson/github-action-runner:latest | grep -i arch
# Should show: "amd64"

# OS
podman inspect salexson/github-action-runner:latest | grep -i os
# Should show: "linux"
```

### **Run Entrypoint with Debug**

```bash
# Run with bash -x to see every command
podman run -e GITHUB_ORG=test -e RUNNER_TOKEN=test \
  salexson/github-action-runner:latest \
  bash -x /opt/runner/entrypoint.sh 2>&1 | head -50
```

---

## Why This Happens with Docker Hub

### Common Reasons

1. **Interrupted Pull** - Connection lost during download
2. **Corrupted Registry** - Registry has bad layers
3. **Build Failed** - Image built with errors but still uploaded
4. **Architecture Mismatch** - Image built for different CPU
5. **Old Version** - Docker Hub has outdated image

### Why Local Build Fixes It

- **Fresh Build** - Downloaded fresh from GitHub
- **Your System** - Built for your exact CPU/OS
- **Clean Layers** - No corruption from registry
- **Verifiable** - You can see build output

---

## Complete Org Runner Setup with Local Build

```bash
# 1. Build image locally
cd /path/to/github-actions-runner-podman
podman build -t salexson/github-action-runner:latest .

# 2. Test image
podman run --rm salexson/github-action-runner:latest echo "Test"

# 3. Prepare org runner setup
cd /opt/gha

# 4. Create .env file
cat > .env <<'EOF'
GITHUB_ORG=my-org
RUNNER_TOKEN=ghp_xxxx
RUNNER_NAME=runner-01
RUNNER_LABELS=podman,linux,docker,x86_64
RUNNER_EPHEMERAL=false
RUNNER_REPLACE=true
RUNNER_CPUS=2
RUNNER_MEMORY=4G
EOF

# 5. Update docker-compose.yml if needed (optional)
# If using Docker Hub: leave as is
# If using local: change image: to salexson/github-action-runner:latest

# 6. Start container
docker-compose down
docker-compose up -d

# 7. Verify
podman logs github-runner
podman ps

# 8. Check GitHub
# https://github.com/organizations/MY-ORG/settings/actions/runners
```

---

## Troubleshooting Build Failures

### If Build Fails

```bash
# Check build output carefully
podman build -t salexson/github-action-runner:latest . 2>&1 | tail -50

# Common failures:
# 1. "No package matches" - package manager issue
# 2. "Cannot download" - network issue
# 3. "Invalid checksum" - corrupted download
# 4. "Command not found" - missing tool
```

### If Build Takes Too Long

```bash
# Normal build time: 5-10 minutes
# Building takes time the first time (downloading all packages)
# Subsequent builds faster (cached layers)

# Monitor progress
podman build -v -t salexson/github-action-runner:latest .
```

### If Build Succeeds But Container Still Fails

```bash
# Try running bash directly
podman run -it salexson/github-action-runner:latest /bin/bash

# If this works: entrypoint script has issues
# If this fails: image still has problems
```

---

## When to Use Local vs Docker Hub

| Scenario | Use |
|----------|-----|
| Quick testing | Local build |
| Production | Push to Docker Hub after local test |
| Sharing | Docker Hub (after verification) |
| CI/CD | Docker Hub (stable) |
| Troubleshooting | Local (debug build) |

---

## Dockerfile Verification

The Dockerfile is designed to:

```dockerfile
FROM registry.access.redhat.com/ubi8/ubi-minimal:latest
# UBI 8 - x86-64-v1 compatible, minimal

RUN microdnf install -y \
    ...bash... \
    ...libtinfo...  # Should be included
    
COPY --chown=runner:runner ./scripts/entrypoint.sh /opt/runner/entrypoint.sh
RUN chmod +x /opt/runner/entrypoint.sh

ENTRYPOINT ["/opt/runner/entrypoint.sh"]
```

The Dockerfile is correct. If you build from it, the image should work.

---

## Your Next Steps

1. **Build image locally**
   ```bash
   cd /path/to/github-actions-runner-podman
   podman build -t salexson/github-action-runner:latest .
   ```

2. **Test it works**
   ```bash
   podman run --rm salexson/github-action-runner:latest /bin/bash -c "echo works"
   ```

3. **Start org runner**
   ```bash
   cd /opt/gha
   export GITHUB_ORG=my-org
   export RUNNER_TOKEN=ghp_xxxx
   docker-compose up -d
   ```

4. **Verify**
   ```bash
   podman logs github-runner
   podman ps
   ```

---

## References

- [GitHub Actions Runner](https://github.com/actions/runner)
- [Podman Build](https://docs.podman.io/en/latest/markdown/podman-build.1.html)
- [UBI 8 Minimal](https://www.redhat.com/en/blog/introducing-red-hat-universal-base-image)

---

## Related Documentation

- [CONTAINER-EXIT-CODE-127.md](CONTAINER-EXIT-CODE-127.md) - Container startup issues
- [DOCKER-REGISTRY-AUTHENTICATION.md](DOCKER-REGISTRY-AUTHENTICATION.md) - Registry auth
- [ORG-RUNNER-SETUP.md](ORG-RUNNER-SETUP.md) - Org runner configuration

---

**Last Updated**: 2025-11-06  
**Status**: ✅ Container libtinfo Error Fix Guide  
**Solution**: Rebuild image locally from Dockerfile  
**Expected Fix Time**: 10-15 minutes
