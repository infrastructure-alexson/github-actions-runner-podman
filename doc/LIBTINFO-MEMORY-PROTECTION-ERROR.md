# libtinfo.so.6 Memory Protection Error - Complete Fix Guide

**Date**: 2025-11-06  
**Issue**: `/bin/bash: error while loading shared libraries: libtinfo.so.6: cannot change memory protections`  
**Cause**: CPU instruction set limitation or security policy issue  
**Status**: ✅ Multiple Solutions Available

---

## Problem

When starting bash or running commands in container, you get:

```
/bin/bash: error while loading shared libraries: libtinfo.so.6: cannot change memory protections
```

This means the bash executable can't load the `libtinfo.so.6` library due to memory protection restrictions.

---

## Root Causes

### **Cause 1: Old CPU (Most Likely)**
- CPU doesn't support x86-64-v2 instruction set
- glibc/bash needs v2 or higher
- **Solution**: Use UBI 8 (already done!) or older base image

### **Cause 2: SELinux Enforcing**
- SELinux policy blocking memory operations
- **Solution**: Set to permissive mode

### **Cause 3: AppArmor Blocking**
- AppArmor profile restricting memory access
- **Solution**: Disable or modify profile

### **Cause 4: Kernel Security Features**
- SMACK or other security modules
- **Solution**: Temporarily disable for testing

---

## Quick Fixes (Try in Order)

### **Fix 1: Check SELinux Status**

```bash
# As root
getenforce

# If ENFORCING:
sudo setenforce Permissive

# Verify
getenforce
# Should show: Permissive
```

### **Fix 2: Temporarily Disable SELinux**

```bash
# Immediate (until reboot)
sudo setenforce 0

# Test container
docker-compose up -d
podman logs github-runner

# If works, SELinux was the issue
```

### **Fix 3: Run Container with SELinux Disabled**

Add to docker-compose.yml:

```yaml
services:
  github-runner:
    security_opt:
      - label=disable
```

Then:
```bash
docker-compose down
docker-compose up -d
```

### **Fix 4: Check CPU Capabilities**

```bash
# Check CPU flags
cat /proc/cpuinfo | grep flags | head -1

# Look for: sse3, sse4_1, sse4_2, popcnt, avx
# These are x86-64-v2 requirements

# If missing, you need older base image
```

---

## Comprehensive Fix Process

### **Step 1**: Check Current Environment

```bash
# Check SELinux
getenforce

# Check AppArmor
sudo aa-status 2>/dev/null || echo "AppArmor not installed"

# Check CPU
cat /proc/cpuinfo | grep -E "vendor_id|model name|flags" | head -3

# Check system
uname -a

# Check container
podman info | grep -i "security"
```

### **Step 2**: If SELinux is ENFORCING

```bash
# Temporarily switch to permissive
sudo setenforce Permissive

# Test
docker-compose down
docker-compose up -d
podman logs github-runner

# If it works now, SELinux is the problem
```

### **Step 3**: Permanent SELinux Fix

**Option A: Permissive mode** (less secure)

```bash
# Edit /etc/selinux/config
# Change: SELINUX=enforcing
# To:     SELINUX=permissive

# Then reboot
sudo reboot
```

**Option B: Container-specific** (more secure)

Update docker-compose.yml:

```yaml
services:
  github-runner:
    security_opt:
      - label=disable  # Disable SELinux for this container
```

Then:
```bash
docker-compose down
docker-compose up -d
```

### **Step 4**: If Still Not Working - Check CPU

```bash
# Get detailed CPU info
cat /proc/cpuinfo | grep flags | head -1

# Check for v2 instruction set
# Should have: sse3, sse4_1, sse4_2, popcnt, avx

# If missing, CPU is too old
# Solution: Use different base image
```

### **Step 5**: If CPU is the Issue

The image is already on UBI 8 (x86-64-v1 compatible). If still failing:

**Option A: Use Alpine (very minimal)**

```dockerfile
FROM alpine:latest
# Much smaller, fewer dependencies
```

**Option B: Use different architecture**

```bash
# Check available architectures
podman image inspect docker.io/salexson/github-action-runner:latest | grep -i arch

# May need to build for different arch
```

### **Step 6**: Rebuild Container if Needed

```bash
# If you modified security settings, rebuild
docker-compose down

# Remove old images
podman rmi docker.io/salexson/github-action-runner:latest

# Recreate
docker-compose up -d
```

---

## Docker-Compose Configuration for SELinux

### Update docker-compose.yml

Add security options:

```yaml
services:
  github-runner:
    image: docker.io/salexson/github-action-runner:latest
    container_name: github-runner
    
    # Add these lines:
    security_opt:
      - label=disable           # Disable SELinux for container
      - seccomp=unconfined      # Disable seccomp restrictions (optional)
    
    cap_add:
      - SYS_PTRACE             # Allow ptrace (may be needed)
    
    # ... rest of config
```

Then apply:

```bash
docker-compose down
docker-compose up -d
```

---

## Understanding the Error

### Why It Happens

```
bash executable
  ↓
Tries to load libtinfo.so.6 library
  ↓
Library needs to change memory page protections (PROT_EXEC, PROT_WRITE)
  ↓
SELinux / Kernel policy blocks this
  ↓
ERROR: cannot change memory protections
```

### Why UBI 8 Already Helps

- UBI 8 is designed for x86-64-v1
- More compatible with older CPUs
- But if SELinux is blocking, even UBI 8 won't help

---

## Diagnostic Commands

Run these to diagnose the exact issue:

```bash
# 1. Check SELinux
getenforce
# If ENFORCING: likely cause

# 2. Check if container runs with SELinux disabled
podman run --rm --security-opt label=disable alpine /bin/sh -c "echo SELinux disabled"

# 3. Check container logs
podman logs github-runner

# 4. Check system logs
sudo journalctl -u podman -n 20

# 5. Check SELinux denials
sudo ausearch -m avc -ts recent 2>/dev/null | tail -20

# 6. Check CPU
cat /proc/cpuinfo | grep -i "cpu flags"

# 7. Check glibc version
ldd /bin/bash | grep libtinfo
```

---

## If SELinux is the Problem

### Temporary Fix (Session)

```bash
sudo setenforce 0
```

### Permanent Fix (Reboot Required)

Edit `/etc/selinux/config`:

```bash
# Before:
SELINUX=enforcing
SELINUXTYPE=targeted

# After:
SELINUX=permissive
SELINUXTYPE=targeted

# Save and reboot
sudo reboot
```

### Container-Only Fix (No Root Change)

Update docker-compose.yml:

```yaml
security_opt:
  - label=disable
```

This disables SELinux **only for this container**, leaving system protected.

---

## If CPU is the Problem

### Check CPU Capabilities

```bash
cat /proc/cpuinfo | grep flags | head -1

# Look for these (x86-64-v2 requirements):
# - sse3 ✓
# - sse4_1 ✓
# - sse4_2 ✓
# - popcnt ✓
# - avx ✓

# If missing any, you need older base image
```

### CPU-Compatible Base Images

| Image | CPU Support | Glibc | Status |
|-------|---|---|---|
| UBI 8 Minimal | x86-64-v1 | 2.28 | ✅ Broadest |
| UBI 9 Minimal | x86-64-v2 | 2.34 | ⚠️ Requires newer CPU |
| Alpine | x86-64-v1 | musl | ✅ Minimal |
| CentOS 7 | x86-64-v1 | 2.17 | ✅ Legacy |

**Current setup**: UBI 8 (x86-64-v1) - should work on any CPU

---

## Complete Troubleshooting Checklist

- [ ] Check SELinux status: `getenforce`
- [ ] If ENFORCING, try: `sudo setenforce 0`
- [ ] Test container: `docker-compose down && docker-compose up -d`
- [ ] Check logs: `podman logs github-runner`
- [ ] If working: SELinux was the issue
- [ ] If not working: check CPU: `cat /proc/cpuinfo | grep flags`
- [ ] If CPU missing flags: need different base image
- [ ] Update docker-compose.yml with security options
- [ ] Rebuild container
- [ ] Test again

---

## Expected Output When Fixed

### Before (Error)

```
Starting container...
/bin/bash: error while loading shared libraries: libtinfo.so.6: cannot change memory protections
container exited with code 127
```

### After (Working)

```
Creating network "gha_github-runner-network"...
Creating github-runner...
[INFO] GitHub Actions Runner Entrypoint
[INFO] Runner registered successfully
[INFO] Starting GitHub Actions Runner listener
Container running healthily
```

---

## For Your Setup (gha user, UID 984, UBI 8)

### Most Likely Issue

SELinux is blocking memory protection operations.

### Quick Fix

```bash
# 1. Check SELinux
getenforce
# If ENFORCING, proceed to step 2

# 2. Temporarily disable
sudo setenforce 0

# 3. Test
docker-compose down
docker-compose up -d
podman logs github-runner

# 4. If works, make permanent
# Edit /etc/selinux/config and change ENFORCING to permissive
# Or add to docker-compose.yml:
#   security_opt:
#     - label=disable
```

---

## References

- [SELinux Project](https://selinuxproject.org/)
- [glibc Memory Protection](https://sourceware.org/glibc/)
- [x86-64 ABI Levels](https://gitlab.com/x86-psABI/x86-64-ABI)
- [Docker Security Options](https://docs.docker.com/engine/reference/run/#security-configuration)

---

## Related Documentation

- [CPU-COMPATIBILITY.md](CPU-COMPATIBILITY.md) - CPU instruction sets
- [CONTAINER-EXIT-CODE-127.md](CONTAINER-EXIT-CODE-127.md) - Container startup
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General troubleshooting

---

**Last Updated**: 2025-11-06  
**Status**: ✅ libtinfo Memory Protection Fix Guide  
**Most Likely Cause**: SELinux enforcing mode  
**Quick Fix**: `sudo setenforce 0` or add `security_opt: label=disable` to docker-compose.yml

