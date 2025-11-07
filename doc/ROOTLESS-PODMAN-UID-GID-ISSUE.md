# Rootless Podman UID/GID Issue - Complete Fix Guide

**Date**: 2025-11-06  
**Issue**: User namespace UID/GID mismatch when pulling container image  
**Error**: `insufficient UIDs or GIDs available in user namespace`  
**Affected**: Rootless Podman (running as non-root user)

---

## Problem

When pulling a container image with rootless Podman, you get:

```
Error: writing blob: adding layer with blob "sha256:8393debac2ec...": 
processing tar file(potentially insufficient UIDs or GIDs available in user namespace 
(requested 0:12 for /var/spool/mail): 
Check /etc/subuid and /etc/subgid if configured locally and 
run "podman system migrate": lchown /var/spool/mail: invalid argument): 
exit status 1
```

Then container fails to start:
```
Error: no container with name or ID "github-runner" found: no such container
```

---

## Root Cause

When pulling a container image, Podman extracts layers that contain files with various UIDs and GIDs. 

**For rootless Podman**:
- The `gha` user can only access UIDs in their allowed namespace
- Typically: 0-999 (system) and 100000-165535 (user namespace)
- If image files need UID 0 (root) but mapping isn't configured → **ERROR**

**The Error Specifically**:
```
requested 0:12 for /var/spool/mail
```
- Requesting UID 0 (root) and GID 12 (mail)
- User `gha` isn't mapped to handle this
- Solution: Configure subuid/subgid properly

---

## Solution Overview

Fix the UID/GID namespace configuration:

1. ✅ Add subuid/subgid mappings for the user
2. ✅ Migrate Podman storage
3. ✅ Clear corrupted layers
4. ✅ Try pull again

---

## Step-by-Step Fix

### Step 1: Check Current Configuration

```bash
# Check if subuid/subgid are configured for gha user
grep ^gha /etc/subuid /etc/subgid

# Should show something like:
# /etc/subuid:gha:100000:65536
# /etc/subgid:gha:100000:65536
```

**If no output**: Configure them (see Step 2)

**If configured**: Go to Step 3

### Step 2: Configure subuid/subgid (If Not Present)

**As root or with sudo:**

```bash
# Add subuid/subgid mappings for gha user
sudo usermod --add-subuids 100000-165535 gha
sudo usermod --add-subgids 100000-165535 gha

# Verify
grep ^gha /etc/subuid /etc/subgid

# Should show:
# /etc/subuid:gha:100000:65536
# /etc/subgid:gha:100000:65536
```

### Step 3: Migrate Podman Storage

**As the gha user:**

```bash
# Run podman system migrate
podman system migrate

# This reconfigures storage with proper UID/GID mappings
```

**Expected output:**
```
Checking for new default network...
migrating database /opt/gha/.local/share/containers/storage/libpod/libpod.db
```

### Step 4: Clear Corrupted Image Layers

The partially pulled image is corrupted. Remove it:

```bash
# Remove the corrupted image
podman rmi docker.io/salexson/github-action-runner:latest 2>/dev/null || true

# Clear storage (WARNING: removes all local images)
podman system prune -a --force

# Or more aggressive:
rm -rf ~/.local/share/containers/storage/blobs
```

### Step 5: Clear Docker-Compose State

```bash
# Stop any lingering containers
docker-compose down

# Remove the failed container
podman rm -f github-runner 2>/dev/null || true
```

### Step 6: Try Pull Again

```bash
# Test pull manually first
podman pull docker.io/salexson/github-action-runner:latest

# If successful, then try docker-compose
docker-compose up -d
```

---

## Complete Fix Script (As Root)

Run this as root to fix everything at once:

```bash
#!/bin/bash
set -euo pipefail

GHA_USER="gha"
GHA_HOME="/opt/gha"

echo "Fixing rootless Podman UID/GID issue for user: $GHA_USER"

# Step 1: Configure subuid/subgid
echo "Step 1: Configuring subuid/subgid..."
if ! grep -q "^${GHA_USER}" /etc/subuid; then
    usermod --add-subuids 100000-165535 "$GHA_USER"
    echo "  ✓ Added subuid mapping"
else
    echo "  ✓ subuid already configured"
fi

if ! grep -q "^${GHA_USER}" /etc/subgid; then
    usermod --add-subgids 100000-165535 "$GHA_USER"
    echo "  ✓ Added subgid mapping"
else
    echo "  ✓ subgid already configured"
fi

# Step 2: Migrate Podman storage
echo "Step 2: Migrating Podman storage..."
sudo -u "$GHA_USER" podman system migrate
echo "  ✓ Podman storage migrated"

# Step 3: Clear corrupted layers
echo "Step 3: Clearing corrupted layers..."
sudo -u "$GHA_USER" podman system prune -a --force > /dev/null 2>&1 || true
echo "  ✓ Corrupted layers cleared"

# Step 4: Test pull
echo "Step 4: Testing pull..."
if sudo -u "$GHA_USER" podman pull docker.io/salexson/github-action-runner:latest; then
    echo "  ✓ Pull successful!"
else
    echo "  ✗ Pull failed - check error above"
    exit 1
fi

echo ""
echo "✓ All fixes applied!"
echo "You can now run: docker-compose up -d"
```

**Save and run:**
```bash
sudo bash fix-podman-uid-gid.sh
```

---

## Detailed Explanation: UID/GID Mapping

### What is subuid/subgid?

For **rootless Podman**, the user needs:
- **subuid**: Range of UIDs the user can use (for container processes)
- **subgid**: Range of GIDs the user can use (for container processes)

### Example Configuration

```bash
# /etc/subuid
gha:100000:65536

# Meaning:
# User 'gha' can use UIDs 100000-165535 (65536 UIDs)
# UID 100000 in container maps to UID 100000 on host

# /etc/subgid  
gha:100000:65536

# Meaning:
# User 'gha' can use GIDs 100000-165535 (65536 GIDs)
# GID 100000 in container maps to GID 100000 on host
```

### Why the Error Occurs

Container image has files owned by:
- UID 0 (root)
- GID 12 (mail group)

When rootless Podman tries to extract:
```
requested 0:12 for /var/spool/mail
```

But user `gha` isn't mapped to UID 0 → **ERROR**

### How the Fix Works

With proper `podman system migrate`:
- UID 0 in image → UID 100000 on host (for gha user)
- GID 12 in image → GID 100012 on host (for gha user)
- No conflicts → extraction succeeds

---

## Verification Steps

### After Applying the Fix

```bash
# As gha user:

# 1. Check subuid/subgid
grep ^gha /etc/subuid /etc/subgid

# 2. Verify Podman storage location
podman info | grep graphRoot
# Should show: graphRoot: /opt/gha/.local/share/containers/storage

# 3. Test pull
podman pull docker.io/salexson/github-action-runner:latest

# 4. Verify image
podman images | grep github-action-runner

# 5. Test local image run
podman run --rm github-action-runner:latest echo "SUCCESS"

# 6. Try docker-compose
docker-compose up -d

# 7. Check status
docker-compose ps
```

---

## Alternative: Use --userns=keep-id

If you still have issues, you can use user namespace keep-id mode:

### In docker-compose.yml

Add to service:
```yaml
userns_mode: "keep-id"
```

**Example**:
```yaml
services:
  github-runner:
    image: docker.io/salexson/github-action-runner:latest
    userns_mode: "keep-id"  # Add this line
    # ... rest of config
```

**What it does**:
- Keeps user IDs the same inside and outside container
- Bypasses some UID/GID mapping issues
- Trade-off: Less isolation

---

## Prevention: Use UBI-Based Images

The GitHub Actions Runner image is based on UBI 8 Minimal, which is designed for rootless Podman.

**However**, if you're still having issues:

### Option 1: Build with Explicit User Namespace Support

Update the Dockerfile:
```dockerfile
# Ensure proper user setup for rootless Podman
RUN groupadd -g 1001 runner && \
    useradd -m -u 1001 -g 1001 -s /bin/bash runner

USER runner
```

This ensures the runner UID/GID is consistent.

### Option 2: Use Alpine Linux (Smaller)

```dockerfile
FROM alpine:latest
# Alpine is even smaller and has fewer UID/GID issues
```

### Option 3: Cache Image Locally

Build and cache locally to avoid re-pulling:
```bash
podman build -t github-action-runner:latest .
# Now it's local, no pull needed
```

---

## Troubleshooting: Still Having Issues?

### Issue 1: "podman system migrate" fails

```
Error: error while running runtime delegate hooks: custom hook /usr/libexec/podman/crun-wasm failed with exit code 126
```

**Solution**:
```bash
# Clear storage and try again
rm -rf ~/.local/share/containers/storage
podman system migrate
```

### Issue 2: Pull still fails after migrate

```bash
# Check Podman info
podman info

# Look for storage and user namespace settings
# storage.driver: overlay
# user namespace: true
```

**If namespace is false**:
```bash
# Check kernel support
grep user_namespaces /boot/config-$(uname -r)
# Should show: CONFIG_USER_NS=y

# Enable if needed
echo "user.max_user_namespaces=15000" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Issue 3: Permission denied on ~/.local/share/containers

```bash
# Fix permissions
rm -rf ~/.local/share/containers
mkdir -p ~/.local/share/containers
chmod 755 ~/.local/share/containers

# Then migrate
podman system migrate
```

### Issue 4: SELinux Blocking

```
denied setattr dir ...
```

**Solution**:
```bash
# Temporary (for testing)
sudo setenforce Permissive

# Permanent (edit /etc/selinux/config):
# SELINUX=permissive
```

---

## Complete Setup From Scratch

If you want to start completely fresh:

```bash
# As root:
sudo bash

# 1. Remove old mappings (if corrupted)
usermod --del-subuids 100000-165535 gha 2>/dev/null || true
usermod --del-subgids 100000-165535 gha 2>/dev/null || true

# 2. Add new mappings
usermod --add-subuids 100000-165535 gha
usermod --add-subgids 100000-165535 gha

# 3. Clear storage as user
sudo -u gha rm -rf /opt/gha/.local/share/containers/storage
sudo -u gha mkdir -p /opt/gha/.local/share/containers

# 4. Migrate
sudo -u gha podman system migrate

# 5. Test
sudo -u gha podman pull docker.io/salexson/github-action-runner:latest

exit  # Exit from sudo

# As gha user:
docker-compose up -d
```

---

## Reference: UID/GID Namespace Ranges

### Standard Configuration

```
User      subuid Start  subuid Count  subgid Start  subgid Count
========  ==============  ==============  ==============
gha       100000          65536           100000          65536
```

### What You Can Access

```
UID Range in container: 0-65535
Maps to UID Range on host: 100000-165535
```

### Typical System UIDs (Don't Use These)

```
UID 0     = root
UID 1-999 = system users
```

---

## Best Practices

### 1. Always Configure subuid/subgid Before First Use
```bash
usermod --add-subuids 100000-165535 gha
usermod --add-subgids 100000-165535 gha
```

### 2. Run podman system migrate After Configuration
```bash
podman system migrate
```

### 3. Don't Mix Root and Rootless Podman
```bash
# Bad: mixing
sudo podman pull ...      # As root
podman pull ...           # As user

# Good: use one or the other
podman pull ...           # Always as user (rootless)
```

### 4. Verify Configuration Before Pulling Large Images
```bash
# Test with small image first
podman pull alpine:latest

# Then try your image
podman pull docker.io/salexson/github-action-runner:latest
```

### 5. Keep Storage Directory Writable
```bash
chmod 755 ~/.local/share/containers
chmod 755 ~/.local/share/containers/storage
```

---

## Reference: Related Files

- `/etc/subuid` - User ID mappings
- `/etc/subgid` - Group ID mappings
- `~/.local/share/containers/storage` - Podman storage directory
- `~/.config/containers/storage.conf` - Podman storage config

---

## Advanced: Check Storage Configuration

```bash
# View current storage configuration
podman info --format json | jq '.store'

# Should show:
# {
#   "GraphRoot": "/opt/gha/.local/share/containers/storage",
#   "RunRoot": "/opt/gha/.local/share/containers/run",
#   "DriverName": "overlay",
#   ...
# }
```

---

## When to Use Which Solution

| Situation | Solution |
|-----------|----------|
| First time setup | Step 1-6 (Full process) |
| Pull fails after upgrade | Step 3-5 (Migrate + clear) |
| Permission denied errors | Fix ownership (Step 2) |
| Still failing | Alternative: keep-id mode |
| Repeated issues | Complete fresh start |

---

## References

- [Podman Rootless Documentation](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md)
- [User Namespaces Linux](https://man7.org/linux/man-pages/man7/user_namespaces.7.html)
- [Subuid/Subgid Configuration](https://docs.docker.com/engine/security/userns-remap/)

---

## Related Documentation

- [ROOTLESS-PODMAN-SETUP.md](ROOTLESS-PODMAN-SETUP.md) - General rootless setup
- [PODMAN-COMPOSE-COMPATIBILITY.md](PODMAN-COMPOSE-COMPATIBILITY.md) - Compose compatibility
- [DOCKER-REGISTRY-AUTHENTICATION.md](DOCKER-REGISTRY-AUTHENTICATION.md) - Registry auth
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General troubleshooting

---

**Last Updated**: 2025-11-06  
**Status**: ✅ Comprehensive Fix Guide  
**Applies To**: Rootless Podman with UID/GID mapping issues

