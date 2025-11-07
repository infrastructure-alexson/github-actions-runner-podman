# Podman Socket Permission Issues - Complete Fix Guide

**Date**: 2025-11-06  
**Issue**: Permission denied accessing Podman socket in rootless mode  
**Error**: `statfs /run/podman/podman.sock: permission denied`  
**Affected**: Rootless Podman users trying to access system Podman socket

---

## Problem

When running `docker-compose up -d` as the `gha` user, you get:

```
Error: statfs /run/podman/podman.sock: permission denied

exit code: 125
```

Then:
```
Error: no container with name or ID "github-runner" found: no such container
```

---

## Root Cause

There are **two different Podman sockets** in a rootless setup:

| Socket | Owner | Access | Use Case |
|--------|-------|--------|----------|
| `/run/podman/podman.sock` | root | System-wide | Shared by all users (if enabled) |
| `/run/user/UID/podman/podman.sock` | user | User only | Per-user Podman (rootless) |

**The Error**: 
- docker-compose is trying to use `/run/podman/podman.sock` (system socket)
- But `gha` user doesn't have permission to access it
- **Solution**: Use the user's own Podman socket instead

---

## Three Solutions

### **Solution 1: Use User's Own Podman Socket** (Recommended for Rootless)

Set the `DOCKER_HOST` environment variable to the user's socket:

```bash
# For gha user (UID 1000), use:
export DOCKER_HOST=unix:///run/user/1000/podman/podman.sock

# Or programmatically:
export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock

# Then run docker-compose
docker-compose up -d
```

**Why this works**:
- Uses the user's own rootless Podman socket
- No permission issues
- Proper user isolation

**Permanent Setup** (add to `~/.bashrc`):
```bash
# Podman rootless configuration
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"
```

### **Solution 2: Enable Podman Socket Service (If Running as System User)**

If the `gha` user needs access to the system Podman socket:

```bash
# As root or with sudo:

# 1. Enable Podman socket for all users
sudo systemctl enable podman.socket
sudo systemctl start podman.socket

# 2. Give gha user access to the socket
sudo setfacl -m u:gha:rw /run/podman/podman.sock

# 3. Verify permissions
ls -la /run/podman/podman.sock
# Should show something like: srw-rw---- 1 root podman

# 4. Add gha to podman group (if it exists)
sudo usermod -aG podman gha
```

**Test**:
```bash
# As gha user
podman ps
# Should work without permission denied
```

### **Solution 3: Start Podman User Service (For User's Own Socket)**

Enable Podman per-user socket:

```bash
# As gha user:

# 1. Start the user Podman socket service
systemctl --user enable podman.socket
systemctl --user start podman.socket

# 2. Verify socket exists
ls -la /run/user/$(id -u)/podman/podman.sock

# 3. Set DOCKER_HOST
export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock

# 4. Test
podman ps

# 5. Run docker-compose
docker-compose up -d
```

---

## Quick Diagnosis

### Check Which Socket You're Using

```bash
# As the gha user, see what docker-compose is trying to do
docker-compose config | grep -i docker

# Check available sockets
ls -la /run/podman/podman.sock 2>/dev/null && echo "System socket exists"
ls -la /run/user/$(id -u)/podman/podman.sock 2>/dev/null && echo "User socket exists"

# Check what docker-compose defaults to
echo "DOCKER_HOST=${DOCKER_HOST:-not set}"
```

### Check Your Podman Setup

```bash
# Check which mode you're running in
podman info | grep -i "rootless"
# Should show: "Rootless: true"

# Check socket path
podman info | grep -i "socket"

# Check UID
id
# Should show: uid=1000(gha) gid=1000(gha)
```

---

## Recommended Setup for Rootless Podman

### Option A: User-Only Rootless Podman (Recommended)

**Use the user's own socket:**

```bash
# 1. Add to ~/.bashrc
cat >> ~/.bashrc <<'EOF'
# Podman rootless setup
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"

# Enable socket if not running
systemctl --user is-active --quiet podman.socket || systemctl --user start podman.socket
EOF

# 2. Reload shell
source ~/.bashrc

# 3. Test
podman ps
docker-compose up -d
```

**Advantages**:
- ✅ No permission issues
- ✅ Proper user isolation
- ✅ No system socket access needed
- ✅ Works with rootless Podman

### Option B: System Podman with User Access

**Give user access to system socket:**

```bash
# 1. As root, enable socket
sudo systemctl enable podman.socket
sudo systemctl start podman.socket

# 2. Add user to podman group
sudo usermod -aG podman gha

# 3. Set permissions
sudo setfacl -m u:gha:rw /run/podman/podman.sock

# 4. Test (as gha user)
podman ps
docker-compose up -d
```

**Disadvantages**:
- ⚠️ System socket requires setup
- ⚠️ Less user isolation
- ⚠️ Not the rootless way

---

## Understanding the Socket Paths

### System Podman Socket
```
/run/podman/podman.sock
├── Owner: root
├── Group: podman (if exists)
├── Permissions: 0660 (rw------- + g)
└── Use: Shared by multiple users (if allowed)
```

### User Podman Socket (Rootless)
```
/run/user/1000/podman/podman.sock
├── Owner: gha (1000)
├── Group: gha (1000)
├── Permissions: 0700 (rwx------)
└── Use: User-only, isolated
```

### Why the Difference

**System socket** (`/run/podman/podman.sock`):
- Created by system Podman daemon
- Starts as root
- Shared resource
- Requires explicit permission

**User socket** (`/run/user/UID/podman/podman.sock`):
- Created by user's Podman session
- Starts as the user
- Isolated to that user
- Automatic permission

---

## Step-by-Step Fix for Your Situation

### You're Running As: `gha` (non-root, rootless)

### Recommended Path: Use User's Own Socket

```bash
# 1. Add to ~/.bashrc (as gha user)
cat >> ~/.bashrc <<'EOF'
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"
EOF

# 2. Reload
source ~/.bashrc

# 3. Verify socket exists
ls -la /run/user/1000/podman/podman.sock

# 4. If socket doesn't exist, start service
systemctl --user start podman.socket

# 5. Verify again
ls -la /run/user/1000/podman/podman.sock

# 6. Test
podman ps

# 7. Now try docker-compose
docker-compose up -d

# 8. Verify
docker-compose ps
```

### If Socket Still Doesn't Exist

```bash
# As gha user:

# 1. Check if systemd user session is active
systemctl --user status

# 2. Enable podman socket
systemctl --user enable podman.socket

# 3. Start podman socket
systemctl --user start podman.socket

# 4. Verify
systemctl --user status podman.socket
# Should show: active (running)

# 5. Check socket
ls -la /run/user/$(id -u)/podman/podman.sock

# 6. Export DOCKER_HOST and test
export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock
podman ps
docker-compose up -d
```

---

## Update docker-compose.yml Documentation

Add a note to the docker-compose.yml file to document socket usage:

```yaml
###############################################################################
# IMPORTANT: For rootless Podman users
#
# Set DOCKER_HOST environment variable before running docker-compose:
#
#   export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock
#
# Or add to ~/.bashrc:
#
#   export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"
#
# For system Podman with user access:
#
#   export DOCKER_HOST=unix:///run/podman/podman.sock
#
###############################################################################
```

---

## Systemd User Session Setup

### Persistent Setup (Add to ~/.bashrc)

```bash
#!/bin/bash

# Podman rootless configuration
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"

# Enable Podman user socket if not running
systemctl --user is-active --quiet podman.socket || \
    systemctl --user start podman.socket
```

### One-Time Setup (Manual)

```bash
# 1. Enable podman user socket
systemctl --user enable podman.socket

# 2. Start podman user socket  
systemctl --user start podman.socket

# 3. Verify it's running
systemctl --user status podman.socket

# 4. Export for this session
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"

# 5. Test
podman ps
docker-compose up -d
```

---

## Verification Commands

### Check Socket Permissions

```bash
# System socket (if using Option B)
ls -la /run/podman/podman.sock
stat /run/podman/podman.sock

# User socket (if using Option A)
ls -la /run/user/$(id -u)/podman/podman.sock
stat /run/user/$(id -u)/podman/podman.sock
```

### Check User/Group Membership

```bash
# Check if gha is in podman group
id gha
# Look for: groups=1000(gha),... (if in podman group)

# Check podman group exists
getent group podman

# Check podman group members
getent group podman | cut -d: -f4
```

### Test Podman Access

```bash
# Test as gha user
podman ps

# If permission denied, check DOCKER_HOST
echo $DOCKER_HOST

# Check socket exists
ls -la $DOCKER_HOST | sed 's/unix:\/\///'

# Check permissions
stat $(echo $DOCKER_HOST | sed 's/unix:\/\///')
```

---

## Troubleshooting

### Issue 1: Socket Still Says Permission Denied

```bash
# Check which socket you're using
echo "Using: $DOCKER_HOST"

# Check if socket exists
ls -la /run/user/$(id -u)/podman/podman.sock
ls -la /run/podman/podman.sock

# If user socket doesn't exist, start service
systemctl --user start podman.socket

# If system socket needs access
sudo setfacl -m u:gha:rw /run/podman/podman.sock
```

### Issue 2: DOCKER_HOST Not Set

```bash
# Verify it's exported
echo $DOCKER_HOST
# If empty, set it:
export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock

# Make it permanent
echo 'export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock' >> ~/.bashrc
source ~/.bashrc
```

### Issue 3: User Socket Service Not Starting

```bash
# Check systemd user session
loginctl list-sessions
loginctl show-session c1 -p ActiveState
# Should show: ActiveState=active

# If no active session, login properly
# Try: su - gha (not su gha)

# Check podman.socket status
systemctl --user status podman.socket

# If not found, check podman is installed
podman --version

# Start service
systemctl --user start podman.socket
```

### Issue 4: Permission Denied on System Socket

```bash
# Check socket permissions
ls -la /run/podman/podman.sock

# If gha doesn't have access:
# Option A: Add to podman group
sudo usermod -aG podman gha

# Option B: Add ACL
sudo setfacl -m u:gha:rw /run/podman/podman.sock

# Option C: Use user socket instead
export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock
```

---

## Resource Limits Warning

The message:
```
Resource limits are not supported and ignored on cgroups V1 rootless systems
```

This is **normal and can be ignored**. It means:
- RHEL 8 uses cgroups v1
- Rootless Podman has limited cgroup support in v1
- Memory and CPU limits won't work as expected
- But container will still run

**Solution** (if needed):
- Upgrade to RHEL 9 (uses cgroups v2)
- Or ignore the warning (it's just a warning)

---

## Docker-Compose Commands with Socket

### Set Socket for Single Command

```bash
DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock docker-compose up -d
```

### Set Socket for Session

```bash
export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock
docker-compose up -d
docker-compose ps
docker-compose logs
```

### Set Socket Permanently

```bash
# Add to ~/.bashrc
export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock

# Or create ~/.docker/config.json
mkdir -p ~/.docker
cat > ~/.docker/config.json <<'EOF'
{
    "auths": {}
}
EOF
```

---

## Best Practices

### 1. Use User Socket for Rootless Podman
```bash
# ✅ Good
export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock

# ❌ Avoid
export DOCKER_HOST=unix:///run/podman/podman.sock  # Needs permissions
```

### 2. Add to Shell Profile
```bash
# ~/.bashrc or ~/.zshrc
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"
```

### 3. Verify Before Running
```bash
# Check socket
ls -la $DOCKER_HOST | sed 's/unix:\/\///'

# Test podman
podman ps

# Then run docker-compose
docker-compose up -d
```

### 4. Don't Mix Rootless and Root Podman
```bash
# Bad: mixing
podman ps                    # User (rootless)
sudo podman ps              # Root (system)

# Good: use one or the other
podman ps                    # Always user

# Or:
sudo podman ps              # Always root
```

---

## Summary

| Problem | Solution |
|---------|----------|
| Permission denied `/run/podman/podman.sock` | Use user socket or add permissions |
| Don't know which socket to use | For rootless: use `/run/user/$UID/podman/podman.sock` |
| Socket path environment variable | Set `DOCKER_HOST=unix://...podman.sock` |
| docker-compose can't access socket | Export `DOCKER_HOST` before running |
| Systemd user service not running | `systemctl --user start podman.socket` |

---

## References

- [Podman Rootless Sockets](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md#using-sockets)
- [XDG Runtime Directory](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
- [Systemd User Services](https://www.freedesktop.org/software/systemd/man/systemd.unit.html)

---

## Related Documentation

- [ROOTLESS-PODMAN-SETUP.md](ROOTLESS-PODMAN-SETUP.md) - Initial setup
- [ROOTLESS-PODMAN-UID-GID-ISSUE.md](ROOTLESS-PODMAN-UID-GID-ISSUE.md) - UID/GID mapping
- [PODMAN-COMPOSE-COMPATIBILITY.md](PODMAN-COMPOSE-COMPATIBILITY.md) - Compose compatibility
- [DOCKER-REGISTRY-AUTHENTICATION.md](DOCKER-REGISTRY-AUTHENTICATION.md) - Registry auth

---

**Last Updated**: 2025-11-06  
**Status**: ✅ Comprehensive Socket Permission Guide  
**Applies To**: Rootless Podman socket access issues

