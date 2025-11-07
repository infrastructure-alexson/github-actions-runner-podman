# GHA User Setup Guide

Configure the GitHub Actions runner to run under the `gha` user for security and resource isolation.

## Overview

Running podman under a dedicated `gha` user provides:
- **Security**: Non-privileged user execution
- **Isolation**: Dedicated user for runner operations
- **Auditability**: Clear ownership of runner processes
- **Permissions**: Granular access control for `/opt/gha` mount

## User Creation

### Create GHA User

```bash
# Create gha user with home directory
sudo useradd -m -s /bin/bash -d /home/gha gha

# Verify user created
id gha

# Expected output:
# uid=1001(gha) gid=1001(gha) groups=1001(gha)
```

### Add to Docker/Podman Group (if needed)

```bash
# Allow gha user to run podman without sudo
sudo usermod -aG podman gha

# For Docker (if using Docker instead of Podman)
sudo usermod -aG docker gha

# Verify
groups gha
```

### Enable Subuid/Subgid for Rootless Podman

```bash
# Configure user namespace remapping for rootless podman
sudo usermod --add-subuids 100000-165535 gha
sudo usermod --add-subgids 100000-165535 gha

# Verify
cat /etc/subuid | grep gha
cat /etc/subgid | grep gha

# Expected output:
# gha:100000:65536
```

## Storage Mount Permissions

### Setup /opt/gha for GHA User

```bash
# Create directories
sudo mkdir -p /opt/gha/work
sudo mkdir -p /opt/gha/logs
sudo mkdir -p /opt/gha/cache

# Set ownership to gha user
sudo chown -R gha:gha /opt/gha

# Set appropriate permissions
sudo chmod 755 /opt/gha
sudo chmod 755 /opt/gha/work
sudo chmod 755 /opt/gha/logs
sudo chmod 755 /opt/gha/cache

# Verify
ls -la /opt/gha/
stat /opt/gha

# Expected output:
# Access: (0755/drwxr-xr-x)  Uid: ( 1001/    gha)   Gid: ( 1001/    gha)
```

### Create Runner Home Directory

```bash
# Create runner working directory under gha home
sudo mkdir -p /home/gha/.runner
sudo mkdir -p /home/gha/.config
sudo mkdir -p /home/gha/.ssh

# Set ownership
sudo chown -R gha:gha /home/gha/.runner
sudo chown -R gha:gha /home/gha/.config
sudo chown -R gha:gha /home/gha/.ssh

# Set permissions
sudo chmod 700 /home/gha/.ssh
sudo chmod 755 /home/gha/.runner

# Verify
ls -la /home/gha/
```

## Podman Configuration for GHA User

### Configure Podman for GHA User

```bash
# Create podman config directory for gha user
sudo mkdir -p /home/gha/.config/containers

# Create containers.conf (optional, for rootless podman)
sudo tee /home/gha/.config/containers/containers.conf > /dev/null << 'EOF'
[containers]
cgroup_manager = "cgroupfs"
runtime = "runc"

[engine]
cgroup_manager = "cgroupfs"
events_backend = "file"
EOF

# Set ownership
sudo chown -R gha:gha /home/gha/.config

# Test podman works as gha user
sudo -u gha podman version

# Expected output:
# Client:       Podman Engine
# Version:      X.X.X
```

### Configure Podman Socket Access

```bash
# For rootless podman (if applicable)
sudo -u gha podman system service --time=0 &

# For rootless podman without sudo, create systemd user service
sudo -u gha systemctl --user enable podman.service
sudo -u gha systemctl --user start podman.service

# Verify socket exists
sudo -u gha ls -la /run/user/$(id -u gha)/podman/podman.sock
```

## Docker Compose as GHA User

### Deploy Runners as GHA User

```bash
# Navigate to project directory
cd github-actions-runner-podman

# Copy environment configuration
cp config/env.example .env

# Edit .env with your settings
nano .env

# Key settings:
# GITHUB_REPO_URL=https://github.com/YOUR-ORG/YOUR-REPO
# GITHUB_TOKEN=ghp_xxxx
# RUNNER_WORK_VOLUME=/opt/gha
# RUNNER_USER=gha
```

### Deploy as GHA User

**Option 1: User-level Docker Compose (Recommended)**

```bash
# Switch to gha user
sudo su - gha

# Navigate to project
cd /path/to/github-actions-runner-podman

# Source environment
export $(cat .env | xargs)

# Deploy
docker-compose up -d runner

# Or for multiple runners
docker-compose --profile multi-runner up -d

# Exit gha user
exit
```

**Option 2: Systemd User Service**

```bash
# Create systemd user service directory
sudo mkdir -p /home/gha/.config/systemd/user

# Copy and modify service file
sudo cp config/github-actions-runner.service \
  /home/gha/.config/systemd/user/

# Enable user service
sudo -u gha systemctl --user daemon-reload
sudo -u gha systemctl --user enable github-actions-runner.service
sudo -u gha systemctl --user start github-actions-runner.service

# Check status
sudo -u gha systemctl --user status github-actions-runner.service

# View logs
sudo -u gha journalctl --user-unit github-actions-runner.service -f
```

**Option 3: System Systemd Service (with sudo)**

```bash
# Install system service
sudo cp config/github-actions-runner.service \
  /etc/systemd/system/

# Edit service to set gha user (already configured)
sudo nano /etc/systemd/system/github-actions-runner.service

# Verify User=gha is set, then enable
sudo systemctl daemon-reload
sudo systemctl enable github-actions-runner
sudo systemctl start github-actions-runner

# Check status
sudo systemctl status github-actions-runner

# View logs
sudo journalctl -u github-actions-runner -f
```

## Permissions Reference

### Directory Permissions

| Path | Owner | Group | Mode | Purpose |
|------|-------|-------|------|---------|
| `/opt/gha` | gha | gha | 755 | Mount root |
| `/opt/gha/work` | gha | gha | 755 | Runner work dir |
| `/opt/gha/logs` | gha | gha | 755 | Runner logs |
| `/home/gha` | gha | gha | 755 | User home |
| `/home/gha/.config` | gha | gha | 755 | Config |
| `/home/gha/.ssh` | gha | gha | 700 | SSH keys |

### Check Current Permissions

```bash
# Check /opt/gha permissions
ls -la /opt/gha/
stat /opt/gha

# Check gha user directories
ls -la /home/gha/
stat /home/gha/.runner

# Verify ownership
find /opt/gha -type d -exec stat -c '%U:%G %n' {} \;
```

### Fix Permissions Issues

```bash
# Fix ownership
sudo chown -R gha:gha /opt/gha
sudo chown -R gha:gha /home/gha

# Fix directory permissions (755 = rwxr-xr-x)
sudo find /opt/gha -type d -exec chmod 755 {} \;
sudo find /home/gha -type d -exec chmod 755 {} \;

# Fix file permissions (644 = rw-r--r--)
sudo find /opt/gha -type f -exec chmod 644 {} \;

# SSH key special permissions (600 = rw-------)
sudo chmod 600 /home/gha/.ssh/*
```

## Sudo Configuration (Optional)

If you need gha user to run certain commands with sudo:

```bash
# Edit sudoers (always use visudo!)
sudo visudo

# Add these lines at the end:
# Allow gha user to run podman without password
gha ALL=(ALL) NOPASSWD: /usr/bin/podman

# Allow gha user to manage own systemd services
gha ALL=(ALL) NOPASSWD: /usr/bin/systemctl --user *

# Or allow docker (if using Docker)
gha ALL=(ALL) NOPASSWD: /usr/bin/docker
```

## Verification Checklist

```bash
# 1. Verify user exists
id gha

# 2. Verify user can run podman
sudo -u gha podman version

# 3. Verify storage mount
sudo -u gha ls -la /opt/gha/

# 4. Verify ownership
stat /opt/gha | grep "Uid\|Gid"

# 5. Verify Docker Compose works as gha
sudo su - gha -c "cd /path/to/project && docker-compose ps"

# 6. Verify service (if using systemd)
sudo systemctl status github-actions-runner

# 7. Check permissions are correct
sudo -u gha test -w /opt/gha/work && echo "Writable" || echo "Not writable"
```

## Troubleshooting GHA User

### Permission Denied Errors

**Problem**: `Permission denied` when accessing `/opt/gha`

```bash
# Solution 1: Check ownership
ls -la /opt/gha
sudo chown -R gha:gha /opt/gha

# Solution 2: Check permissions
sudo chmod 755 /opt/gha

# Solution 3: Verify user is member of correct group
groups gha
sudo usermod -aG podman gha
```

### Cannot Access Podman Socket

**Problem**: `Cannot connect to Podman. Please verify your connection to the Linux system using ssh`

```bash
# Solution 1: Check if user can run podman
sudo -u gha podman ps

# Solution 2: Verify subuid/subgid
cat /etc/subuid | grep gha
cat /etc/subgid | grep gha

# Solution 3: Add to podman group
sudo usermod -aG podman gha

# Solution 4: Restart podman service
sudo systemctl restart podman
```

### Systemd Service Won't Start

**Problem**: Systemd service fails to start

```bash
# Check service status
sudo systemctl status github-actions-runner

# Check logs
sudo journalctl -u github-actions-runner -n 50

# Check service file for User=gha
cat /etc/systemd/system/github-actions-runner.service | grep User

# Verify working directory exists and is writable by gha
sudo -u gha test -w /opt/gha && echo "OK" || echo "Not writable"
```

## Running Commands as GHA User

### Switch to GHA User

```bash
# Become gha user (interactive)
sudo su - gha

# Run single command as gha user
sudo -u gha <command>

# Example: Check Docker Compose
sudo -u gha docker-compose ps
```

### Common GHA User Commands

```bash
# Check podman
sudo -u gha podman ps
sudo -u gha podman images

# Check Docker Compose
sudo -u gha docker-compose ps
sudo -u gha docker-compose logs -f runner

# Check storage
sudo -u gha du -sh /opt/gha/work

# View runner status
sudo -u gha cat /opt/gha/.runner

# Manage service (user level)
sudo -u gha systemctl --user status github-actions-runner
```

## Security Best Practices

✅ **Do**:
- Use dedicated `gha` user
- Use non-root execution
- Limit file permissions
- Use SSH keys with restricted permissions
- Rotate tokens regularly
- Monitor gha user activity
- Keep subuid/subgid configured

❌ **Don't**:
- Run as root user
- Use overly permissive permissions (777)
- Store tokens in plain text files
- Share SSH keys
- Run untrusted workflows as gha user
- Disable security options

## Related Documentation

- [STORAGE-CONFIG.md](../STORAGE-CONFIG.md) - Storage setup for /opt/gha
- [INSTALLATION.md](INSTALLATION.md) - Installation guide
- [SECURITY.md](SECURITY.md) - Security best practices
- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment options
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Problem solving

## Quick Reference

```bash
# Create gha user
sudo useradd -m -s /bin/bash gha

# Add to podman group
sudo usermod -aG podman gha

# Configure rootless podman
sudo usermod --add-subuids 100000-165535 gha
sudo usermod --add-subgids 100000-165535 gha

# Setup storage
sudo chown -R gha:gha /opt/gha
sudo chmod 755 /opt/gha

# Deploy runners as gha
sudo su - gha
cd /path/to/github-actions-runner-podman
docker-compose up -d runner

# Verify
id gha
sudo -u gha podman version
```

