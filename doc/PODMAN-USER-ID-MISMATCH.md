# Podman User ID Mismatch Issue - Complete Fix Guide

**Date**: 2025-11-06  
**Issue**: Podman runtime directory mismatch between stored configuration and current user  
**Error**: `Failed to get rootless runtime dir for DefaultAPIAddress: lstat /run/user/984: no such file or directory`  
**Error**: `setting up the process: open libpod/tmp/pause.pid: no such file or directory`  
**Affected**: Rootless Podman after user ID or storage configuration changes

---

## Problem

When running Podman commands, you get errors like:

```
WARN[0000] Failed to get rootless runtime dir for DefaultAPIAddress: 
lstat /run/user/984: no such file or directory

error creating temporary file: No such file or directory

ERRO[0000] invalid internal status, try resetting the pause process with 
"podman system migrate": setting up the process: 
open libpod/tmp/pause.pid: no such file or directory
```

Then docker-compose fails:
```
Error: no container with name or ID "github-runner" found: no such container
```

---

## Root Cause

Podman's stored configuration is pointing to **the wrong user ID**:

| Item | Issue |
|------|-------|
| **Current User UID** | 1000 (gha) |
| **Stored Config UID** | 984 (different user?) |
| **Runtime Directory** | `/run/user/984` doesn't exist |
| **Storage Path** | Points to wrong location |

**Why it happens**:
1. User ID changed (UID migration)
2. Ran Podman as different user previously
3. Storage directory was moved or recreated
4. User was deleted and recreated with different UID

---

## Quick Fix: Run Podman System Migrate

The error message tells you the solution:

```bash
# As the current user (gha):
podman system migrate

# This reconfigures Podman for the current user
```

**Expected output**:
```
Checking for new default network...
migrating database /opt/gha/.local/share/containers/storage/libpod/libpod.db
```

---

## Step-by-Step Fix

### Step 1: Verify Your Current UID

```bash
# Check current user and UID
id

# Output should look like:
# uid=1000(gha) gid=1000(gha) groups=1000(gha)

# Note your UID (e.g., 1000)
```

### Step 2: Check What UID Podman Thinks You Are

```bash
# This will show the mismatch
podman info 2>&1 | head -20

# Look for errors mentioning /run/user/984
# That's the wrong UID
```

### Step 3: Clear Corrupted Podman State

```bash
# Stop all containers
podman kill -a 2>/dev/null || true

# Remove all containers
podman rm -a 2>/dev/null || true

# Remove all images (if needed)
podman rmi -a 2>/dev/null || true
```

### Step 4: Reset Podman Storage

```bash
# Option A: Reset without losing data (recommended)
podman system migrate

# Option B: Complete reset (loses all images/containers)
rm -rf ~/.local/share/containers/storage
podman system migrate
```

### Step 5: Verify Fix

```bash
# Check if it worked
podman info | grep -A5 "storage:"

# Should show correct paths now

# Test basic command
podman ps

# Should work without UID errors
```

### Step 6: Try Docker-Compose Again

```bash
# Now try docker-compose
docker-compose up -d

# Should work
docker-compose ps
```

---

## Complete Fix Script (Automated)

**Save as `fix-podman-uid-mismatch.sh`:**

```bash
#!/bin/bash
set -euo pipefail

echo "Fixing Podman user ID mismatch..."

# Step 1: Show current user info
echo ""
echo "Current user info:"
id
echo ""

# Step 2: Show Podman errors
echo "Current Podman state:"
podman info 2>&1 | head -20 || echo "Podman not responding - will fix"

# Step 3: Kill containers
echo ""
echo "Stopping containers..."
podman kill -a 2>/dev/null || true
sleep 1

# Step 4: Remove containers
echo "Removing containers..."
podman rm -a 2>/dev/null || true

# Step 5: Run migrate
echo ""
echo "Running podman system migrate..."
podman system migrate

# Step 6: Verify
echo ""
echo "Verifying fix..."
podman info | head -10

# Step 7: Test
echo ""
echo "Testing Podman..."
podman ps

echo ""
echo "✓ Fix complete!"
echo "You can now run: docker-compose up -d"
```

**Run it:**
```bash
bash fix-podman-uid-mismatch.sh
```

---

## Understanding the UID Mismatch

### What is `/run/user/UID`?

```
/run/user/1000/          ← For user with UID 1000
├── podman/
│   └── podman.sock      ← Podman socket
├── dbus-daemon/         ← D-Bus
└── ...

/run/user/984/           ← Different user (UID 984)
├── podman/
│   └── podman.sock
└── ...
```

### Why Error Shows UID 984

Podman stored configuration points to `/run/user/984`:
- Either previous user had UID 984
- Or user ID was changed
- Or storage was moved

### How Migrate Fixes It

`podman system migrate`:
1. Reads current user UID (1000)
2. Updates storage configuration
3. Creates new paths `/run/user/1000/...`
4. Removes references to old UID (984)
5. Reconfigures Podman for current user

---

## Advanced Debugging

### Check Storage Configuration

```bash
# View storage settings
podman info --format json | jq '.store'

# Should show:
# {
#   "GraphRoot": "/opt/gha/.local/share/containers/storage",
#   "RunRoot": "/run/user/1000/libpod",
#   ...
# }

# Check that RunRoot path exists
ls -la /run/user/1000/

# Should exist after migrate
```

### Check Storage DB File

```bash
# Location of Podman database
ls -la ~/.local/share/containers/storage/libpod/libpod.db

# This file stores the configuration
# migrate updates this file
```

### Manual Storage Update

If `podman system migrate` doesn't work:

```bash
# 1. Backup existing storage
cp -r ~/.local/share/containers ~/.local/share/containers.backup

# 2. Remove corrupted database
rm ~/.local/share/containers/storage/libpod/libpod.db

# 3. Try migrate again
podman system migrate

# If still doesn't work:
# 4. Clear storage completely
rm -rf ~/.local/share/containers/storage

# 5. Migrate will recreate from scratch
podman system migrate

# 6. Images will be lost but Podman will work
```

---

## Prevention: Checking Before Issues Occur

### Check Podman Health Periodically

```bash
# Create ~/check-podman-health.sh
#!/bin/bash

# Check current UID
CURRENT_UID=$(id -u)

# Check if Podman matches
if ! podman info > /dev/null 2>&1; then
    echo "⚠️ Podman not responding"
    echo "Running: podman system migrate"
    podman system migrate
fi

# Verify paths
RUNTIME_DIR="/run/user/${CURRENT_UID}"
if [ ! -d "$RUNTIME_DIR" ]; then
    echo "⚠️ Runtime directory missing: $RUNTIME_DIR"
fi

echo "✓ Podman health check passed"
```

### Add to Crontab (Optional)

```bash
# Run health check daily
(crontab -l 2>/dev/null; echo "0 1 * * * ~/check-podman-health.sh") | crontab -
```

---

## When This Error Occurs

| Scenario | Cause | Fix |
|----------|-------|-----|
| First time running Podman | Config not set up | `podman system migrate` |
| After user ID change | UID mismatch | `podman system migrate` |
| After storage move | Path changed | `podman system migrate` |
| After Podman upgrade | Config format changed | `podman system migrate` |
| After container engine switch | Engine-specific config | `podman system migrate` |

---

## Related Errors and Fixes

### Error: "invalid internal status"

```
ERRO[0000] invalid internal status, try resetting the pause process with 
"podman system migrate"
```

**Fix**: Run `podman system migrate`

### Error: "pause.pid not found"

```
open libpod/tmp/pause.pid: no such file or directory
```

**Fix**: Run `podman system migrate`

### Error: "lstat /run/user/XXX: no such file or directory"

```
lstat /run/user/984: no such file or directory
```

**Fix**: Run `podman system migrate`

---

## Verification Checklist

After running the fix, verify:

```bash
# 1. Check current UID
id
# Shows: uid=1000(gha)

# 2. Check podman info
podman info > /dev/null
# No UID errors

# 3. Check runtime directory
ls -la /run/user/$(id -u)/podman/podman.sock
# Socket exists

# 4. List containers
podman ps
# Works without errors

# 5. Check storage
podman info | grep RunRoot
# Points to correct /run/user/XXX

# 6. Test image pull
podman pull alpine:latest
# Works without errors

# 7. Run container
podman run --rm alpine echo "SUCCESS"
# Works

# 8. Cleanup
podman rmi alpine:latest

# 9. Try docker-compose
docker-compose up -d
# Works
```

---

## Comparison: Before and After Migrate

### Before (Broken)

```
WARN: Failed to get rootless runtime dir for DefaultAPIAddress: 
      lstat /run/user/984: no such file or directory
```

Podman configuration:
```json
{
  "RuntimePath": "/run/user/984/libpod",
  "TmpDir": "/run/user/984/libpod/tmp"
}
```

Current user:
```
uid=1000(gha)
```

Result: ❌ **Mismatch - 1000 vs 984**

### After (Fixed)

```
(no errors)
```

Podman configuration:
```json
{
  "RuntimePath": "/run/user/1000/libpod",
  "TmpDir": "/run/user/1000/libpod/tmp"
}
```

Current user:
```
uid=1000(gha)
```

Result: ✅ **Match - 1000 equals 1000**

---

## Troubleshooting: Migrate Still Failing

### If migrate hangs or fails:

```bash
# 1. Kill any stuck Podman processes
pkill -9 podman
pkill -9 conmon

# 2. Wait a moment
sleep 2

# 3. Try migrate again
podman system migrate

# 4. If still fails, check systemd
systemctl --user status podman.socket

# 5. Restart systemd user session
systemctl --user daemon-reexec

# 6. Try migrate again
podman system migrate
```

### If storage is corrupted:

```bash
# 1. Backup current storage
mv ~/.local/share/containers ~/.local/share/containers.old

# 2. Let migrate recreate storage
podman system migrate

# 3. Check if it worked
podman ps

# 4. If it worked, remove backup
rm -rf ~/.local/share/containers.old

# 5. If it didn't work, restore backup
mv ~/.local/share/containers.old ~/.local/share/containers
```

---

## Best Practices

### 1. Don't Switch Between Users

```bash
# ❌ Bad - running as different users
podman ps              # As gha (UID 1000)
sudo podman ps        # As root

# ✅ Good - stick to one user
podman ps             # Always as gha
```

### 2. Check UID Before Setup

```bash
# Get your UID
id -u

# Note it and use consistently:
export PODMAN_UID=$(id -u)
```

### 3. Monitor Podman Health

```bash
# Add to .bashrc
podman info > /dev/null || podman system migrate
```

### 4. Backup Storage Periodically

```bash
# Backup before major changes
cp -r ~/.local/share/containers ~/.local/share/containers.backup
```

---

## References

- [Podman System Migrate](https://docs.podman.io/en/latest/markdown/podman-system-migrate.1.html)
- [Podman Runtime Directory](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md)
- [User Namespaces](https://man7.org/linux/man-pages/man7/user_namespaces.7.html)

---

## Related Documentation

- [ROOTLESS-PODMAN-SETUP.md](ROOTLESS-PODMAN-SETUP.md) - Initial setup
- [ROOTLESS-PODMAN-UID-GID-ISSUE.md](ROOTLESS-PODMAN-UID-GID-ISSUE.md) - UID/GID mapping
- [PODMAN-SOCKET-PERMISSION-ISSUE.md](PODMAN-SOCKET-PERMISSION-ISSUE.md) - Socket permissions
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General troubleshooting

---

## Quick Reference

| Error | Cause | Fix |
|-------|-------|-----|
| `lstat /run/user/984: no such file or directory` | UID mismatch | `podman system migrate` |
| `invalid internal status` | Corrupted config | `podman system migrate` |
| `pause.pid: no such file or directory` | Storage path wrong | `podman system migrate` |
| `Failed to get rootless runtime dir` | UID changed | `podman system migrate` |

**TL;DR**: Run `podman system migrate` to fix 99% of these issues.

---

**Last Updated**: 2025-11-06  
**Status**: ✅ Comprehensive User ID Mismatch Guide  
**One-Line Fix**: `podman system migrate`

