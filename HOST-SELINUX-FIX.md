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

## Quick Fixes (Try in Order)

### **Fix 1: Check SELinux Status**

```bash
getenforce
```

**If output is `Enforcing`**: SELinux is blocking it (most likely)

**If output is `Permissive`**: Something else is wrong

**If output is `Disabled`**: SELinux isn't the issue

### **Fix 2: Temporarily Disable SELinux**

```bash
# Disable SELinux immediately (until reboot)
sudo setenforce 0

# Verify
getenforce
# Should now show: Permissive
```

### **Fix 3: Test Container**

```bash
# Test if container works now
podman run --rm salexson/github-action-runner:latest /bin/bash -c "echo works"

# Should output: works

# If it works: SELinux was definitely the issue
# If still fails: skip to Fix 5
```

### **Fix 4: Make SELinux Change Permanent**

**Edit `/etc/selinux/config` as root:**

```bash
sudo vi /etc/selinux/config
```

**Find this line:**
```
SELINUX=enforcing
```

**Change to:**
```
SELINUX=permissive
```

**Save and reboot:**
```bash
sudo reboot
```

After reboot, SELinux will stay in permissive mode.

### **Fix 5: Alternative - Disable Only for This Container**

If you don't want to change system-wide SELinux:

**Update `/opt/gha/docker-compose.yml`:**

```yaml
services:
  github-runner:
    image: salexson/github-action-runner:latest
    container_name: github-runner
    
    # Add these lines:
    security_opt:
      - label=disable
    
    # ... rest of config stays same
```

**Then restart:**

```bash
cd /opt/gha
docker-compose down
docker-compose up -d
```

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
export RUNNER_TOKEN=ghp_xxxx
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

- [ ] Ran `getenforce` and saw the mode
- [ ] If ENFORCING: ran `sudo setenforce 0`
- [ ] Tested container: `podman run --rm salexson/github-action-runner:latest /bin/bash -c "echo test"`
- [ ] Container bash worked (no libtinfo error)
- [ ] Made SELinux change permanent OR updated docker-compose.yml
- [ ] Started org runner: `docker-compose up -d`
- [ ] Verified container running: `podman ps`
- [ ] Checked GitHub org runners page
- [ ] Runner appears and shows "Online"

---

## Your Immediate Action

```bash
# 1. Check SELinux right now
getenforce

# 2. If ENFORCING, fix it
sudo setenforce 0

# 3. Test
podman run --rm salexson/github-action-runner:latest /bin/bash -c "echo test"

# If that works, SELinux was the issue!
# Then make permanent (reboot or edit /etc/selinux/config)
```

---

**Summary**: This is a **host system issue** (SELinux), not an image issue. The fix is system-level, not container-level.

The image is correct. The host needs configuration.

