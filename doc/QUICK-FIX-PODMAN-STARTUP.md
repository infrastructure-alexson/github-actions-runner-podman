# Quick Fix: Podman Startup Issues (UID 984)

**Date**: 2025-11-06  
**User**: gha (UID 984, GID 984)  
**Issue**: Podman runtime directory not initialized  
**Status**: ✅ Simple Fix

---

## Your Situation

```bash
$ id
uid=984(gha) gid=984(gha) groups=984(gha)
```

**Good news**: Your UID is consistent (984). The issue is simply that Podman hasn't set up the runtime directory yet.

---

## One-Line Fix

```bash
podman system migrate
```

**That's it!** This initializes `/run/user/984/` for Podman.

---

## If That Doesn't Work: Full Startup Sequence

### **Step 1**: Start Systemd User Session

```bash
# Start your user's systemd session
systemctl --user start podman.socket

# Verify it's running
systemctl --user status podman.socket
```

### **Step 2**: Run Podman System Migrate

```bash
podman system migrate
```

### **Step 3**: Verify Runtime Directory

```bash
# Check if /run/user/984 exists now
ls -la /run/user/984/

# Should show:
# drwx------ 3 gha gha 4096 Nov  6 12:00 /run/user/984/
```

### **Step 4**: Verify Podman Works

```bash
podman ps
# Should work without errors
```

### **Step 5**: Set DOCKER_HOST Environment Variable

```bash
# Add to ~/.bashrc
cat >> ~/.bashrc <<'EOF'
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"
EOF

# Reload
source ~/.bashrc
```

### **Step 6**: Try Docker-Compose

```bash
# Set required environment variables
export GITHUB_REPOSITORY=owner/repo
export GITHUB_TOKEN=ghs_xxxx

# Run docker-compose
docker-compose up -d
```

---

## Diagnosis Commands

Run these to understand your current situation:

```bash
# 1. Confirm your UID
id
# Shows: uid=984(gha)

# 2. Check runtime directory
ls -la /run/user/984/ 2>/dev/null || echo "Directory doesn't exist yet"

# 3. Check if podman socket service is enabled
systemctl --user is-enabled podman.socket
# Should show: enabled or disabled

# 4. Check if podman socket is running
systemctl --user is-active podman.socket
# Should show: active or inactive

# 5. Try podman info
podman info 2>&1 | head -20

# 6. Check DOCKER_HOST
echo "DOCKER_HOST=$DOCKER_HOST"

# 7. Check Podman storage
podman info | grep -A5 "storage:"
```

---

## Complete Startup Checklist

Execute in order:

```bash
# 1. Enable podman socket service
systemctl --user enable podman.socket

# 2. Start podman socket service
systemctl --user start podman.socket

# 3. Migrate Podman configuration
podman system migrate

# 4. Verify runtime directory exists
ls -la /run/user/984/podman/

# 5. Set environment variables
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"

# 6. Test podman
podman ps

# 7. Test docker-compose
docker-compose up -d

# 8. Verify
docker-compose ps
```

---

## Persistent Setup (Add to ~/.bashrc)

```bash
# ~/.bashrc additions for gha user

# Podman rootless configuration
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"

# Start podman socket if not running
if ! systemctl --user is-active --quiet podman.socket; then
    systemctl --user start podman.socket
fi

# Initialize Podman if needed
podman system migrate > /dev/null 2>&1 || true
```

---

## What Each Step Does

### `systemctl --user enable podman.socket`
- Enables Podman socket service to start at login
- Makes `/run/user/984/podman/podman.sock` available

### `systemctl --user start podman.socket`
- Starts the Podman socket service immediately
- Creates `/run/user/984/` directory
- Creates `/run/user/984/podman/podman.sock`

### `podman system migrate`
- Initializes Podman storage configuration
- Sets up database
- Creates necessary directories

### `export DOCKER_HOST=...`
- Tells docker-compose which socket to use
- Connects to user's Podman socket
- Enables docker-compose to work

---

## Expected Output at Each Step

### After `systemctl --user start podman.socket`:
```bash
$ systemctl --user status podman.socket
● podman.socket - Podman API Socket
   Loaded: loaded (...)
   Active: active (running) since ...
```

### After `podman system migrate`:
```
Checking for new default network...
migrating database /opt/gha/.local/share/containers/storage/libpod/libpod.db
```

### After `ls -la /run/user/984/`:
```
total 32
drwx------ 3 gha gha  4096 Nov  6 12:00 .
drwxr-xr-x 4 root root 4096 Nov  6 12:00 ..
drwx------ 3 gha gha  4096 Nov  6 12:00 podman/

$ ls -la /run/user/984/podman/
total 16
drwx------ 3 gha gha 4096 Nov  6 12:00 .
drwx------ 3 gha gha 4096 Nov  6 12:00 ..
srw-rw---- 1 gha gha    0 Nov  6 12:00 podman.sock
```

### After `podman ps`:
```
CONTAINER ID  IMAGE  COMMAND  CREATED  STATUS  PORTS  NAMES
(empty - no containers yet, but command works!)
```

### After `docker-compose up -d`:
```
Creating network "gha_github-runner-network" with driver "bridge"
Creating github-runner ... done
```

### After `docker-compose ps`:
```
NAME              STATUS
github-runner     Up 2 seconds (healthy)
```

---

## If Something Still Doesn't Work

### Check systemd user services

```bash
# List all user services
systemctl --user list-units --type=service

# Check if podman.socket exists
systemctl --user list-unit-files | grep podman.socket
```

### Restart everything

```bash
# Stop podman socket
systemctl --user stop podman.socket

# Kill any podman processes
pkill -9 podman

# Wait
sleep 2

# Start podman socket again
systemctl --user start podman.socket

# Migrate
podman system migrate

# Test
podman ps
```

### Check SELinux context

Your context shows: `unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023`

This is fine. If you have SELinux issues:

```bash
# Check SELinux status
getenforce

# If ENFORCING, check for denials
sudo ausearch -m avc -ts recent 2>/dev/null | grep podman

# Temporarily permissive (for testing)
sudo setenforce Permissive
```

---

## Your UID is Correct!

Important: Your UID **984 is correct** and consistent. The errors mentioning `/run/user/984` are actually **looking for the right place** - they just haven't found it yet because it's not initialized.

The fix is simply to initialize it:
```bash
systemctl --user start podman.socket
podman system migrate
```

---

## Quick Summary

| Task | Command |
|------|---------|
| Check your UID | `id` |
| Enable podman socket | `systemctl --user enable podman.socket` |
| Start podman socket | `systemctl --user start podman.socket` |
| Initialize Podman | `podman system migrate` |
| Set Docker host | `export DOCKER_HOST=unix:///run/user/984/podman/podman.sock` |
| Test Podman | `podman ps` |
| Test docker-compose | `docker-compose up -d` |

---

## Next Steps

1. Run the quick startup checklist above
2. If it works, you're done! 🎉
3. If it doesn't, run the diagnosis commands to see where it fails
4. Reference the related documentation for specific issues

---

## Related Documentation

- [ROOTLESS-PODMAN-SETUP.md](ROOTLESS-PODMAN-SETUP.md) - Initial setup
- [PODMAN-SOCKET-PERMISSION-ISSUE.md](PODMAN-SOCKET-PERMISSION-ISSUE.md) - Socket issues
- [PODMAN-USER-ID-MISMATCH.md](PODMAN-USER-ID-MISMATCH.md) - UID mismatch
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General troubleshooting

---

**Your UID**: 984 ✅  
**Status**: Ready to initialize  
**Next**: Run the startup checklist above

