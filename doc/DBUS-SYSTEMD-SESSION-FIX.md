# D-Bus and Systemd User Session Fix

**Date**: 2025-11-06  
**Issue**: "Failed to connect to bus: No such file or directory"  
**Cause**: Systemd user session not initialized  
**Status**: ✅ Simple Fix

---

## Problem

When running commands, you get:

```
Failed to connect to bus: No such file or directory
```

This happens with:
- `systemctl --user start podman.socket`
- `systemctl --user enable podman.socket`
- `systemctl --user status podman.socket`

**Root cause**: The systemd user D-Bus session isn't running.

---

## Quick Fix

### **Option 1: Start D-Bus Session** (One Command)

```bash
# Initialize systemd user session
systemctl --user daemon-reexec

# Or more direct:
dbus-daemon --session &
```

### **Option 2: Re-login** (Most Reliable)

```bash
# Exit the current session
exit

# Log back in
ssh gha@hostname  # or su - gha

# Or locally:
su - gha
```

### **Option 3: Use loginctl** (Recommended)

```bash
# Check active sessions
loginctl list-sessions

# If no gha session, activate one
loginctl enable-linger gha

# Verify
loginctl list-users
```

---

## Step-by-Step Fix

### **Step 1**: Check Current Session Status

```bash
# Check if D-Bus is running
echo $DBUS_SESSION_BUS_ADDRESS

# Should show something like: unix:path=/run/user/984/bus
# If empty, D-Bus isn't initialized
```

### **Step 2**: Initialize User Linger (Persistent)

```bash
# Enable user linger (keeps session running even when logged out)
loginctl enable-linger gha

# Verify
loginctl show-user gha | grep Linger
# Should show: Linger=yes
```

### **Step 3**: Re-Initialize D-Bus Session

```bash
# Method 1: Re-login (most reliable)
exit
su - gha

# Method 2: Start D-Bus manually
dbus-daemon --session &

# Method 3: Reload systemd
systemctl --user daemon-reexec
```

### **Step 4**: Verify D-Bus is Running

```bash
# Check D-Bus address
echo $DBUS_SESSION_BUS_ADDRESS
# Should show: unix:path=/run/user/984/bus

# Check if systemd user session is active
systemctl --user status
# Should show: running
```

### **Step 5**: Update ~/.bashrc to Auto-Fix

```bash
# Add this to ~/.bashrc

# Initialize D-Bus if not already running
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval "$(dbus-launch --sh-syntax)"
fi

# Podman configuration
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"

# Auto-start services
systemctl --user is-active --quiet podman.socket || \
    systemctl --user start podman.socket
podman system migrate > /dev/null 2>&1 || true
```

### **Step 6**: Reload and Test

```bash
# Reload bashrc
source ~/.bashrc

# Verify D-Bus
echo $DBUS_SESSION_BUS_ADDRESS

# Test systemctl
systemctl --user status podman.socket

# Test podman
podman ps
```

---

## Why This Happens

### When You SSH In

```
SSH Login
  ↓
Shell starts (/bin/bash)
  ↓
D-Bus NOT initialized ← Problem
  ↓
systemctl --user fails
```

### When You Use su

```
su - gha (with dash)
  ↓
Full login shell
  ↓
D-Bus initialized ← Good
  ↓
systemctl --user works

vs.

su gha (without dash)
  ↓
Non-login shell
  ↓
D-Bus NOT initialized ← Problem
```

---

## Complete Fix for Your Situation

### **You're running as gha (UID 984)**

**Do this one time:**

```bash
# As root or with sudo:
sudo loginctl enable-linger gha

# Then as gha user, log out and back in:
exit

# Log back in (new shell will have D-Bus)
su - gha
```

**Then verify:**

```bash
# Check D-Bus
echo $DBUS_SESSION_BUS_ADDRESS
# Should show: unix:path=/run/user/984/bus

# Check systemd
systemctl --user status podman.socket
# Should work

# Try startup sequence
systemctl --user start podman.socket
podman system migrate
podman ps
```

---

## The ~/.bashrc Update

Add this to your `~/.bashrc` to auto-initialize D-Bus:

```bash
#!/bin/bash

# ===== D-Bus Session Management =====
# Initialize D-Bus if not already running
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval "$(dbus-launch --sh-syntax)"
fi

# ===== Podman Configuration =====
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"

# ===== Podman Startup =====
# Enable and start podman socket
systemctl --user is-enabled --quiet podman.socket || \
    systemctl --user enable podman.socket

systemctl --user is-active --quiet podman.socket || \
    systemctl --user start podman.socket

# Initialize Podman if needed
podman system migrate > /dev/null 2>&1 || true
```

---

## Testing Each Part

### **Test 1: D-Bus**

```bash
echo $DBUS_SESSION_BUS_ADDRESS
# Should NOT be empty

# If empty:
eval "$(dbus-launch --sh-syntax)"
echo $DBUS_SESSION_BUS_ADDRESS
# Should now show path
```

### **Test 2: Systemd User**

```bash
systemctl --user status
# Should show "running"

# If fails: re-login or run:
systemctl --user daemon-reexec
```

### **Test 3: Podman Socket**

```bash
systemctl --user status podman.socket
# Should show "active (running)"

# If not:
systemctl --user start podman.socket
```

### **Test 4: Podman**

```bash
podman ps
# Should work

# If not:
podman system migrate
podman ps
```

### **Test 5: Docker-Compose**

```bash
docker-compose ps
# Should work

# If not:
docker-compose up -d
docker-compose ps
```

---

## If Re-Login Doesn't Work

### Check for stale processes

```bash
# Kill any old podman processes
pkill -9 podman

# Kill any old dbus processes
pkill -9 dbus-daemon

# Wait a moment
sleep 2

# Log out and back in
exit
su - gha
```

### Check /run/user/984

```bash
# Verify directory exists
ls -la /run/user/984/

# If doesn't exist, create it
mkdir -p /run/user/984
chmod 700 /run/user/984

# Or restart systemd
systemctl --user daemon-reexec
```

### Force recreate session

```bash
# Disable and re-enable linger
sudo loginctl disable-linger gha
sleep 1
sudo loginctl enable-linger gha

# Then log out and in
exit
su - gha
```

---

## SSH-Specific Fix

If accessing via SSH and getting D-Bus errors:

### **Option 1: Use su - gha** (Preferred)

```bash
ssh hostname
su - gha    # Note the dash!
# Now D-Bus will be initialized
```

### **Option 2: SSH as gha user directly**

```bash
ssh gha@hostname
# This starts a login shell
# D-Bus should initialize
```

### **Option 3: SSH command with D-Bus**

```bash
ssh gha@hostname 'eval "$(dbus-launch --sh-syntax)" && podman ps'
# Initializes D-Bus for the command
```

---

## Permanent Solution: systemd User Slice

Make the session persistent across reboots:

```bash
# As root or sudo:
sudo loginctl enable-linger gha

# Verify
loginctl list-users
# gha should show LINGER: yes
```

Then even after reboot:
```bash
su - gha
systemctl --user status
# Will show: running
```

---

## Diagnostic Commands

Run these to understand your situation:

```bash
# 1. Check D-Bus
echo "D-Bus: $DBUS_SESSION_BUS_ADDRESS"
# Should NOT be empty

# 2. Check systemd user session
systemctl --user status 2>&1 | head -5
# Should show "running"

# 3. Check user linger
loginctl list-users | grep gha
# Should show LINGER: yes

# 4. Check /run/user/984 exists
ls -la /run/user/984/
# Should exist

# 5. Check active sessions
loginctl list-sessions | grep gha
# Should show gha session
```

---

## Before and After

### **Before (Broken)**

```bash
$ systemctl --user status podman.socket
Failed to connect to bus: No such file or directory
```

Cause:
- D-Bus not running
- systemd user session not initialized

### **After (Fixed)**

```bash
$ systemctl --user status podman.socket
● podman.socket - Podman API Socket
   Loaded: loaded
   Active: active (running)
```

Cause fixed:
- D-Bus initialized
- systemd user session running
- User linger enabled

---

## Quick Reference

| Command | Purpose | When to Use |
|---------|---------|------------|
| `loginctl enable-linger gha` | Keep session persistent | Once, as root |
| `exit` and `su - gha` | Re-initialize session | After linger enable |
| `eval "$(dbus-launch --sh-syntax)"` | Start D-Bus | Emergency fix |
| `systemctl --user daemon-reexec` | Reload systemd | Session stuck |
| `source ~/.bashrc` | Reload config | After editing |

---

## Your Next Steps

1. **Run as root**:
   ```bash
   sudo loginctl enable-linger gha
   ```

2. **Exit and re-login**:
   ```bash
   exit
   su - gha
   ```

3. **Verify D-Bus**:
   ```bash
   echo $DBUS_SESSION_BUS_ADDRESS
   ```

4. **Test systemd**:
   ```bash
   systemctl --user status podman.socket
   ```

5. **Initialize Podman**:
   ```bash
   systemctl --user start podman.socket
   podman system migrate
   ```

6. **Try docker-compose**:
   ```bash
   docker-compose up -d
   ```

---

## Why This Matters

D-Bus is needed for:
- systemd user services
- Service management (enable/start/stop)
- User session management
- Container runtimes

Without D-Bus:
- ❌ `systemctl --user` fails
- ❌ `podman.socket` can't start
- ❌ docker-compose can't run

With D-Bus:
- ✅ Full systemd user support
- ✅ Persistent sessions
- ✅ Service management
- ✅ Podman works

---

## References

- [Systemd User Sessions](https://www.freedesktop.org/software/systemd/man/systemd.unit.html)
- [D-Bus Session Bus](https://dbus.freedesktop.org/)
- [loginctl Documentation](https://www.freedesktop.org/software/systemd/man/loginctl.html)

---

## Related Documentation

- [QUICK-FIX-PODMAN-STARTUP.md](QUICK-FIX-PODMAN-STARTUP.md) - Podman startup
- [ROOTLESS-PODMAN-SETUP.md](ROOTLESS-PODMAN-SETUP.md) - Initial setup
- [PODMAN-SOCKET-PERMISSION-ISSUE.md](PODMAN-SOCKET-PERMISSION-ISSUE.md) - Socket issues

---

**Last Updated**: 2025-11-06  
**Status**: ✅ D-Bus/Systemd Session Fix  
**One-Command Fix**: `sudo loginctl enable-linger gha` then re-login

