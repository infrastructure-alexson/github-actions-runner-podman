# Host System SELinux Fix for libtinfo Error

**Date**: 2025-11-06  
**Issue**: libtinfo.so.6 memory protection error persists after image rebuild  
**Root Cause**: Host system (SELinux or kernel) blocking memory operations  
**Status**: ✅ Host-Level Fix

---

## Problem

Even after rebuilding the image locally, you still get:

```
/bin/bash: error while loading shared libraries: libtinfo.so.6: cannot change memory protections
```

This means the **host system is blocking the container**, not an image issue.

---

## Root Cause

The container bash needs to change memory page protections, but the **host system is denying this**.

Usually: **SELinux in enforcing mode**

---

## Recommended Fix: SELinux Label Disable (Container-Only)

⭐ **This is the BEST approach** - Only disables SELinux for this container, keeps system protection intact.

### **Step 1: Update docker-compose.yml**

Edit `/opt/gha/docker-compose.yml` and add `security_opt`:

```yaml
services:
  github-runner:
    image: salexson/github-action-runner:latest
    container_name: github-runner
    hostname: github-runner
    
    # Add these lines (after hostname, before restart_policy):
    security_opt:
      - label=disable
    
    # ... rest of config stays the same
```

### **Step 2: Restart Container**

```bash
cd /opt/gha
docker-compose down
docker-compose up -d
```

### **Step 3: Verify**

```bash
podman logs github-runner

# Should show:
# [INFO] GitHub Actions Runner Entrypoint
# [INFO] Runner registered successfully
```

---

## Alternative: System-Wide SELinux Changes (Not Recommended)

If you need to disable SELinux system-wide (not recommended):

### **Temporary Fix (Until Reboot)**

```bash
# Check current status
getenforce

# If "Enforcing", temporarily disable
sudo setenforce 0

# Verify
getenforce
# Should show: Permissive
```

### **Permanent Fix (Requires Reboot)**

```bash
# Edit SELinux config
sudo vi /etc/selinux/config

# Find this line:
# SELINUX=enforcing

# Change to:
# SELINUX=permissive

# Save: Esc, :wq, Enter

# Reboot to apply
sudo reboot
```

⚠️ **Note**: This disables SELinux for the **entire system**, affecting all containers and services. Use the docker-compose fix above instead.

---

## Why This Happens

```
Your command:
  podman run /bin/bash

Container bash tries to:
  Load libtinfo.so.6 library

Library needs to:
  Change memory page protections (PROT_EXEC + PROT_WRITE)

Host system (SELinux):
  Denies this operation ← BLOCKS HERE

Error:
  "cannot change memory protections"
```

The image is fine. The host system is preventing the operation.

---

## Complete Fix Process

```bash
# Step 1: Check SELinux
getenforce

# Step 2: If ENFORCING, disable temporarily
sudo setenforce 0

# Step 3: Test
podman run --rm salexson/github-action-runner:latest /bin/bash -c "echo test"

# Step 4a: If works - make permanent
# Edit /etc/selinux/config: SELINUX=permissive
# Or use docker-compose security_opt

# Step 4b: If still doesn't work - check CPU
cat /proc/cpuinfo | grep flags | head -1
```

---

## Expected Results

### Before (With SELinux Enforcing)

```bash
$ podman run --rm salexson/github-action-runner:latest /bin/bash

/bin/bash: error while loading shared libraries: libtinfo.so.6: cannot change memory protections
```

### After (With SELinux Permissive)

```bash
$ podman run --rm salexson/github-action-runner:latest /bin/bash

bash-4.4#  ← Interactive bash prompt!
```

---

## For Organization Runner Deployment

Once SELinux is fixed:

```bash
# 1. Verify SELinux is permissive or disabled
getenforce

# 2. Go to deploy directory
cd /opt/gha

# 3. Set org environment
export GITHUB_ORG=my-org
export GITHUB_TOKEN=ghp_xxxx
export RUNNER_NAME=runner-01

# 4. Start
docker-compose down
docker-compose up -d

# 5. Verify
podman logs github-runner
# Should show: [INFO] GitHub Actions Runner Entrypoint

podman ps
# Should show: Up X seconds (healthy)

# 6. Check GitHub
# https://github.com/organizations/MY-ORG/settings/actions/runners
# Your runner should appear!
```

---

## SELinux Modes Explained

| Mode | What It Does | Security | Performance |
|------|------------|----------|-------------|
| **Enforcing** | Blocks denied actions | ✅ High | ⚠️ Can block valid ops |
| **Permissive** | Logs denied actions | ⚠️ Medium | ✅ Better |
| **Disabled** | No restrictions | ❌ Low | ✅ Fastest |

For containers: **Permissive is usually best** (logs issues without blocking)

---

## If CPU is the Problem (Less Likely)

Check CPU flags:

```bash
cat /proc/cpuinfo | grep flags | head -1

# Look for: sse3, sse4_1, sse4_2, popcnt, avx
```

If missing flags, your CPU is too old. But this is **unlikely** since the image rebuilt successfully.

---

## Verification Checklist

**Recommended Approach (Container-Only):**
- [ ] Edited `/opt/gha/docker-compose.yml`
- [ ] Added `security_opt: - label=disable` under the github-runner service
- [ ] Ran: `docker-compose down && docker-compose up -d`
- [ ] Verified logs: `podman logs github-runner`
- [ ] Checked container status: `podman ps` (should show "Up" and "healthy")
- [ ] Runner appears on GitHub org runners page
- [ ] Runner shows "Online" status

**Alternative (System-Wide - Not Recommended):**
- [ ] Ran `getenforce` and checked mode
- [ ] If ENFORCING: ran `sudo setenforce 0` (temporary)
- [ ] Tested container works
- [ ] Edited `/etc/selinux/config` (permanent)
- [ ] Rebooted system
- [ ] Verified SELinux stayed in permissive mode

---

## Your Immediate Action (Recommended)

```bash
# 1. Edit docker-compose.yml
cd /opt/gha
nano docker-compose.yml

# 2. Find the github-runner service section
# 3. Add these lines after "hostname: github-runner":
#    security_opt:
#      - label=disable

# 4. Save and exit (Ctrl+X, Y, Enter)

# 5. Restart container
docker-compose down
docker-compose up -d

# 6. Verify
podman logs github-runner
# Should show: [INFO] Runner registered successfully
```

---

**Summary**: 
- ✅ **This is a host system issue** (SELinux), not an image issue
- ✅ **Best fix**: Add `security_opt: label=disable` to docker-compose.yml (container-only)
- ✅ **Why**: Keeps SELinux enabled for other system services, only disables for this container
- ❌ **Don't disable SELinux system-wide** - that weakens security for everything

The image is correct. The docker-compose.yml just needs one line!

