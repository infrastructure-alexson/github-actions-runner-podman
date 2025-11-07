# Rootless Podman Setup Guide

**Date**: 2025-11-06  
**Issue**: Permission denied creating Podman storage directory  
**Error**: `mkdir /opt/gha/.local: permission denied`

---

## Problem Description

When running `docker-compose up` (podman-compose) as a non-root user (e.g., `gha`), you get:

```
Error: creating runtime static files directory "/opt/gha/.local/share/containers/storage/libpod": mkdir /opt/gha/.local: permission denied
```

**Root Cause**: The user doesn't have permission to create `.local` directory in their home, or the home directory path has permission issues.

---

## Solution

### Step 1: Verify the User's Home Directory

```bash
# Check what the gha user's home directory is
grep ^gha /etc/passwd
# Should output something like: gha:x:1000:1000::/opt/gha:/bin/bash

# Verify home directory permissions
ls -ld /opt/gha
# Should show: drwxr-xr-x (755) or similar with write permission for owner

# Verify the gha user owns it
whoami
# Should be: gha
```

### Step 2: Ensure Home Directory Permissions

**If the home directory is not writable:**

```bash
# Option 1: Make user's home writable (if you own it or are root)
sudo chown gha:gha /opt/gha
sudo chmod 755 /opt/gha

# Option 2: If /opt/gha is shared, create a writable subdirectory
sudo mkdir -p /opt/gha/.local/share/containers
sudo chown -R gha:gha /opt/gha/.local
sudo chmod -R 755 /opt/gha/.local
```

### Step 3: Set Up User Namespaces (Required for Rootless Podman)

**For RHEL 8 / Fedora:**

```bash
# 1. Install required package
sudo dnf install -y uidmap

# 2. Configure user namespaces (add to /etc/sysctl.conf)
echo "user.max_user_namespaces=15000" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 3. Configure subuid/subgid for the gha user
# Check if already configured
grep ^gha /etc/subuid
grep ^gha /etc/subgid

# If not configured, add:
sudo usermod --add-subuids 100000-165535 gha
sudo usermod --add-subgids 100000-165535 gha

# Verify
grep ^gha /etc/subuid /etc/subgid
```

### Step 4: Create Podman Storage Directory

```bash
# As the gha user, create the storage directory
sudo -u gha mkdir -p /opt/gha/.local/share/containers/storage
sudo -u gha mkdir -p /opt/gha/.config/containers

# Verify permissions
ls -la /opt/gha/.local/share/containers/
ls -la /opt/gha/.config/containers/
```

### Step 5: Configure Podman for the User

**Create `/opt/gha/.config/containers/containers.conf`:**

```ini
# Container storage configuration
[storage]
driver = "overlay"
graphroot = "/opt/gha/.local/share/containers/storage"
runroot = "/opt/gha/.local/share/containers/run"

[storage.options.overlay]
mountopt = "nodev,fsync=off"

# Container configuration
[containers]
cgroup_manager = "cgroupfs"
runtime = "runc"

# Network configuration
[network]
network_backend = "netavark"
```

**Set Correct Permissions:**

```bash
sudo chown gha:gha /opt/gha/.config/containers/containers.conf
sudo chmod 644 /opt/gha/.config/containers/containers.conf
```

### Step 6: Test Rootless Podman

```bash
# Switch to gha user
su - gha

# Test podman
podman --version

# Test creating a simple container
podman run --rm alpine echo "Podman works!"

# If successful, you should see output without errors
```

### Step 7: Test Docker-Compose

```bash
# As gha user, test docker-compose
cd /path/to/github-actions-runner-podman
docker-compose config  # Verify syntax first
docker-compose up -d   # Start services
docker-compose ps      # Check status
```

---

## Troubleshooting

### Issue 1: Still Getting "Permission Denied"

**Check home directory:**
```bash
# As the gha user
stat ~
# Should show: Access: (0755/drwxr-xr-x) Uid: ( 1000/  gha)

# Try creating a test file
touch ~/.test-write
rm ~/.test-write
```

**If still not working:**
```bash
# Create as root, then transfer ownership
sudo mkdir -p /opt/gha/.local/share/containers/storage
sudo mkdir -p /opt/gha/.config/containers
sudo chown -R gha:gha /opt/gha/.local
sudo chown -R gha:gha /opt/gha/.config
sudo chmod -R 755 /opt/gha/.local
sudo chmod -R 755 /opt/gha/.config
```

### Issue 2: "User Namespaces Not Available"

**Error**: `user namespaces are not enabled`

**Solution:**
```bash
# Check kernel support
grep user_namespaces /boot/config-$(uname -r)
# Should show: CONFIG_USER_NS=y

# If not, enable via sysctl
sudo sysctl -w user.max_user_namespaces=15000

# Make permanent
echo "user.max_user_namespaces=15000" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Issue 3: "Cannot Get New Session"

**Error**: `getSession: Cannot get new session`

**Solution:**
```bash
# Kill existing podman processes
podman system prune -a

# Clear storage
rm -rf ~/.local/share/containers/storage/*

# Restart
podman run --rm alpine echo "test"
```

### Issue 4: SELinux Issues (If Enabled)

```bash
# Check if SELinux is enforcing
getenforce

# If ENFORCING, set to PERMISSIVE temporarily for testing
sudo setenforce Permissive

# For permanent fix, check podman SELinux policies
getsebool -a | grep podman
```

---

## Docker-Compose with Rootless Podman

### Using podman-compose

**Installation:**
```bash
sudo pip3 install podman-compose

# Or on RHEL/Fedora
sudo dnf install -y podman-compose
```

**Configuration File**: `~/.docker/config.json`

```json
{
    "auths": {},
    "credsStore": "pass",
    "experimental": "enabled"
}
```

**Run docker-compose as regular user:**

```bash
# Set Podman as the compose engine
export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock

# Or in docker-compose override
DOCKER_HOST=unix:///run/user/1000/podman/podman.sock docker-compose up -d
```

### Environment Setup Script

**Create `~/.bashrc` additions:**

```bash
# Podman configuration for rootless operation
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"
export PODMAN_USERNS=keep-id

# Enable Podman socket if not running
systemctl --user status podman.socket || systemctl --user start podman.socket
```

---

## Permanent Setup (Recommended)

### 1. Create Setup Script

**File**: `/usr/local/bin/setup-gha-podman.sh`

```bash
#!/bin/bash
set -euo pipefail

GHA_USER="${1:-gha}"
GHA_HOME="${2:-/opt/gha}"

echo "Setting up rootless Podman for user: $GHA_USER"

# Ensure subuid/subgid are configured
if ! grep -q "^${GHA_USER}" /etc/subuid; then
    echo "Configuring subuid/subgid..."
    sudo usermod --add-subuids 100000-165535 "$GHA_USER"
    sudo usermod --add-subgids 100000-165535 "$GHA_USER"
fi

# Create directories
echo "Creating Podman storage directories..."
sudo mkdir -p "${GHA_HOME}/.local/share/containers/storage"
sudo mkdir -p "${GHA_HOME}/.config/containers"

# Set permissions
echo "Setting permissions..."
sudo chown -R "${GHA_USER}:${GHA_USER}" "${GHA_HOME}/.local"
sudo chown -R "${GHA_USER}:${GHA_USER}" "${GHA_HOME}/.config"
sudo chmod -R 755 "${GHA_HOME}/.local"
sudo chmod -R 755 "${GHA_HOME}/.config"

# Create containers.conf
echo "Creating containers.conf..."
cat > "${GHA_HOME}/.config/containers/containers.conf" <<'EOF'
[storage]
driver = "overlay"
graphroot = "$HOME/.local/share/containers/storage"
runroot = "$HOME/.local/share/containers/run"

[storage.options.overlay]
mountopt = "nodev,fsync=off"

[containers]
cgroup_manager = "cgroupfs"
runtime = "runc"

[network]
network_backend = "netavark"
EOF

sudo chown "${GHA_USER}:${GHA_USER}" "${GHA_HOME}/.config/containers/containers.conf"
sudo chmod 644 "${GHA_HOME}/.config/containers/containers.conf"

# Enable user namespaces
echo "Configuring user namespaces..."
echo "user.max_user_namespaces=15000" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo "Setup complete!"
echo "Test with: su - $GHA_USER -c 'podman run --rm alpine echo test'"
```

### 2. Run Setup Script

```bash
sudo bash /usr/local/bin/setup-gha-podman.sh gha /opt/gha
```

---

## Docker-Compose File Configuration

### Recommended `docker-compose.yml` for Rootless

```yaml
version: '3.8'

services:
  github-runner:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: github-actions-runner
    hostname: github-runner
    
    # Allow access to Podman socket for container-in-container
    volumes:
      - /run/user/1000/podman/podman.sock:/var/run/docker.sock:ro
      - runner-work:/home/runner/_work
    
    environment:
      # These should be set as secrets or environment variables
      GITHUB_REPO_URL: "${GITHUB_REPO_URL}"
      GITHUB_ORG: "${GITHUB_ORG}"
      GITHUB_TOKEN: "${GITHUB_TOKEN}"
      RUNNER_NAME: "${RUNNER_NAME:-runner-podman-1}"
      RUNNER_LABELS: "podman,linux,docker-compat"
      RUNNER_EPHEMERAL: "false"
      
      # Podman-specific settings
      PODMAN_USERNS: "keep-id"
      XDG_RUNTIME_DIR: "/run/user/1000"
    
    # Restart policy
    restart: unless-stopped
    
    # Health check
    healthcheck:
      test: ["CMD", "test", "-f", "/home/runner/.configured"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  runner-work:
    driver: local
```

---

## Systemd User Service (Alternative to Docker-Compose)

**File**: `~/.config/systemd/user/podman-runner.service`

```ini
[Unit]
Description=GitHub Actions Runner (Podman)
After=podman.socket
Requires=podman.socket

[Service]
Type=simple
Restart=always
RestartSec=10s

ExecStart=/usr/bin/podman run \
  --rm \
  --name github-actions-runner \
  -e GITHUB_REPO_URL=%i \
  -e GITHUB_TOKEN=%i \
  -e RUNNER_NAME=%i \
  -v /run/user/%U/podman/podman.sock:/var/run/docker.sock \
  docker.io/salexson/github-action-runner:latest

[Install]
WantedBy=default.target
```

**Enable and start:**
```bash
systemctl --user daemon-reload
systemctl --user enable podman-runner.service
systemctl --user start podman-runner.service
```

---

## Verification Checklist

- [ ] User has writable home directory
- [ ] User namespace support enabled (`user.max_user_namespaces=15000`)
- [ ] subuid/subgid configured for user
- [ ] `.local/share/containers/storage` directory exists with correct permissions
- [ ] `.config/containers/containers.conf` properly configured
- [ ] `podman run --rm alpine echo test` works as regular user
- [ ] `docker-compose config` shows no errors
- [ ] `docker-compose up -d` completes successfully
- [ ] `docker-compose ps` shows running services
- [ ] Container logs accessible: `docker-compose logs runner`

---

## References

- [Podman Rootless Documentation](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md)
- [Podman-Compose GitHub](https://github.com/containers/podman-compose)
- [RHEL Rootless Containers](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/building_running_and_managing_containers/using-podman_building-running-and-managing-containers#intro-to-rootless-containers_using-podman)

---

## Quick Reference Commands

```bash
# Check Podman version
podman --version

# Test basic Podman
podman run --rm alpine echo "works"

# View Podman storage location
podman info | grep graphRoot

# List all containers (including stopped)
podman ps -a

# View container logs
podman logs <container-name>

# Remove container
podman rm <container-name>

# Test docker-compose
docker-compose version
docker-compose config
docker-compose up -d
docker-compose ps
docker-compose logs -f

# Stop services
docker-compose down

# Clean up everything
podman system prune -a --force
```

---

## Additional Resources

See also:
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General troubleshooting
- [QUICK-START.md](QUICK-START.md) - Quick start guide
- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment instructions
- [STORAGE-SETUP.md](STORAGE-SETUP.md) - Storage configuration

---

**Last Updated**: 2025-11-06  
**Status**: ✅ Ready for Production

