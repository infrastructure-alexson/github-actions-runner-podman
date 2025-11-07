# GHA User Deployment Guide

Complete setup guide for deploying GitHub Actions runners under the `gha` user with `/opt/gha` storage mount.

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│         System (root/sudo)                      │
├─────────────────────────────────────────────────┤
│  /opt/gha (50GB mount) - owned by gha:gha       │
│  ├── work/    (Runner work directory)           │
│  ├── logs/    (Runner logs)                     │
│  └── cache/   (Build cache)                     │
├─────────────────────────────────────────────────┤
│  gha user (UID ~1001)                           │
│  ├── /home/gha                                  │
│  ├── .config/containers/                       │
│  ├── .ssh/                                      │
│  └── .runner/                                   │
├─────────────────────────────────────────────────┤
│  Podman/Docker (runs under gha user)            │
│  └── GitHub Actions Runner Container           │
│      ├── RUNNER_WORK_VOLUME=/opt/gha           │
│      ├── RUNNER_USER=gha                       │
│      └── Connected to GitHub                   │
└─────────────────────────────────────────────────┘
```

## Complete Setup Steps

### Step 1: Create GHA User (5 minutes)

```bash
# Create gha user with home directory
sudo useradd -m -s /bin/bash -d /home/gha gha

# Add to podman group for container management
sudo usermod -aG podman gha

# Configure user namespaces for rootless podman
sudo usermod --add-subuids 100000-165535 gha
sudo usermod --add-subgids 100000-165535 gha

# Verify user creation
id gha
cat /etc/subuid | grep gha
cat /etc/subgid | grep gha

# Expected: uid=1001(gha) gid=1001(gha) groups=1001(gha),999(podman)
```

### Step 2: Setup Storage Mount (5 minutes)

```bash
# Verify mount exists
df -h /opt/gha
# Expected: 50G mounted at /opt/gha

# Create directory structure
sudo mkdir -p /opt/gha/work
sudo mkdir -p /opt/gha/logs
sudo mkdir -p /opt/gha/cache

# Set ownership to gha user (critical!)
sudo chown -R gha:gha /opt/gha

# Set proper permissions (755 = rwxr-xr-x)
sudo chmod 755 /opt/gha
sudo chmod 755 /opt/gha/work
sudo chmod 755 /opt/gha/logs

# Verify ownership and permissions
ls -la /opt/gha
stat /opt/gha | grep "Access:\|Uid\|Gid"

# Test write permission
sudo -u gha touch /opt/gha/write-test.txt && \
  echo "✓ Write test successful" || \
  echo "✗ Permission denied"
```

### Step 3: Prepare Project (5 minutes)

```bash
# Copy project to home directory (optional but recommended)
sudo cp -r github-actions-runner-podman /home/gha/
sudo chown -R gha:gha /home/gha/github-actions-runner-podman

# Or use from any location
cd /path/to/github-actions-runner-podman

# Copy environment template
sudo cp config/env.example config/.env.gha
sudo chown gha:gha config/.env.gha
```

### Step 4: Configure Environment (5 minutes)

Create `.env` file for GHA user:

```bash
# Create .env for gha user
sudo tee /home/gha/github-actions-runner-podman/.env > /dev/null << 'EOF'
# GitHub Configuration (REQUIRED)
GITHUB_REPO_URL=https://github.com/YOUR-ORG/YOUR-REPO
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Runner Configuration
RUNNER_NAME=runner-01
RUNNER_LABELS=podman,linux,ci,docker
RUNNER_EPHEMERAL=false
RUNNER_REPLACE=true

# User Configuration
RUNNER_USER=gha
RUNNER_GROUP=gha

# Storage Configuration
RUNNER_WORK_VOLUME=/opt/gha
RUNNER_WORK_DIR=./_work

# Resource Limits
RUNNER_CPUS=4
RUNNER_MEMORY=4G
RUNNER_CPUS_RESERVED=2
RUNNER_MEMORY_RESERVED=2G

# Multi-runner configuration (optional)
RUNNER_NAME_2=runner-02
RUNNER_LABELS_2=podman,linux
RUNNER_EPHEMERAL_2=false

RUNNER_NAME_3=runner-03
RUNNER_LABELS_3=podman,linux
RUNNER_EPHEMERAL_3=false
EOF

# Set ownership
sudo chown gha:gha /home/gha/github-actions-runner-podman/.env

# Verify (from gha user perspective)
sudo -u gha cat /home/gha/github-actions-runner-podman/.env
```

### Step 5: Deploy Runners (5 minutes)

**Option A: Direct deployment as GHA user**

```bash
# Switch to gha user
sudo su - gha

# Navigate to project
cd github-actions-runner-podman

# Deploy single runner
docker-compose up -d runner

# Or deploy multiple runners
docker-compose --profile multi-runner up -d

# Verify deployment
docker-compose ps

# Check logs
docker-compose logs -f runner

# Exit gha user shell
exit
```

**Option B: One-liner deployment with sudo**

```bash
sudo -u gha bash -c 'cd /home/gha/github-actions-runner-podman && docker-compose up -d runner'
```

**Option C: Systemd service (automatic startup)**

```bash
# Install service file
sudo cp config/github-actions-runner.service /etc/systemd/system/

# Verify User=gha is set (it is by default)
grep "User=" /etc/systemd/system/github-actions-runner.service

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable github-actions-runner
sudo systemctl start github-actions-runner

# Check status
sudo systemctl status github-actions-runner

# View logs
sudo journalctl -u github-actions-runner -f
```

### Step 6: Verification (2 minutes)

```bash
# Check GHA user can run podman
sudo -u gha podman version

# Check runners are running
docker-compose ps
# OR
sudo -u gha docker-compose -f /home/gha/github-actions-runner-podman/docker-compose.yml ps

# Check storage access
sudo -u gha ls -la /opt/gha/work

# Check Docker Compose sees the environment
sudo -u gha docker-compose config | grep RUNNER_WORK_VOLUME

# Monitor container
docker stats runner
# OR
sudo -u gha docker stats runner

# Verify in GitHub UI
# Go to: Settings → Actions → Runners
# Should see your runner listed as "Idle"
```

## Configuration Summary

### Key Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `RUNNER_USER` | `gha` | Container runs under gha user |
| `RUNNER_GROUP` | `gha` | Container runs under gha group |
| `RUNNER_WORK_VOLUME` | `/opt/gha` | 50GB mount point |
| `RUNNER_WORK_DIR` | `./_work` | Work directory inside container |
| `RUNNER_EPHEMERAL` | `false` or `true` | Auto-cleanup after jobs |

### Permissions Summary

| Path | Owner | Mode | Purpose |
|------|-------|------|---------|
| `/opt/gha` | gha:gha | 755 | Mount root |
| `/opt/gha/work` | gha:gha | 755 | Runner work |
| `/home/gha` | gha:gha | 755 | User home |
| `/home/gha/.ssh` | gha:gha | 700 | SSH keys |

## Common Operations

### View Logs

```bash
# Docker Compose logs
sudo -u gha docker-compose logs -f runner

# Systemd logs
sudo journalctl -u github-actions-runner -f

# Container logs directly
sudo -u gha podman logs -f github-runner

# Storage usage
sudo -u gha du -sh /opt/gha/work
```

### Stop/Start Runners

```bash
# As gha user
sudo su - gha
cd github-actions-runner-podman
docker-compose down      # Stop
docker-compose up -d     # Start
exit

# Or with sudo
sudo -u gha docker-compose -f ... stop
sudo -u gha docker-compose -f ... start
```

### Monitor Storage

```bash
# Real-time monitoring
watch -n 1 'sudo -u gha du -sh /opt/gha/work'

# Overall usage
df -h /opt/gha
du -sh /opt/gha/*

# Per-runner usage
du -sh /opt/gha/work/*
```

### Cleanup

```bash
# As gha user
sudo -u gha docker system prune -f

# Aggressive cleanup
sudo -u gha docker system prune -a -f
```

## Troubleshooting

### "Permission denied" accessing /opt/gha

```bash
# Check ownership
ls -la /opt/gha
stat /opt/gha

# Fix ownership
sudo chown -R gha:gha /opt/gha

# Test write access
sudo -u gha touch /opt/gha/test.txt
```

### Systemd service fails to start

```bash
# Check service status
sudo systemctl status github-actions-runner

# View error logs
sudo journalctl -u github-actions-runner -n 50

# Verify working directory
sudo -u gha test -w /opt/gha && echo "OK" || echo "Not writable"

# Verify user exists
id gha
```

### Docker Compose permission error

```bash
# Verify gha user is in podman group
groups gha

# Add to group if needed
sudo usermod -aG podman gha

# Test podman works
sudo -u gha podman ps
```

### Cannot access Docker socket

```bash
# Check socket exists
ls -la /run/podman/podman.sock

# Verify permissions
stat /run/podman/podman.sock

# Test access as gha user
sudo -u gha podman ps

# Restart podman if needed
sudo systemctl restart podman
```

## Maintenance

### Daily
```bash
# Check runner status
sudo systemctl status github-actions-runner

# Monitor storage
df -h /opt/gha
```

### Weekly
```bash
# Cleanup old containers
sudo -u gha docker system prune -f

# Check logs for errors
sudo journalctl -u github-actions-runner --since "1 week ago" | grep ERROR
```

### Monthly
```bash
# Update runner
./scripts/update-runner.sh

# Review storage usage
du -sh /opt/gha/*

# Rotate GitHub token
# Create new token, update .env, redeploy, delete old token
```

## Security Checklist

✅ **Implementation**
- [ ] GHA user created with home directory
- [ ] GHA user added to podman group
- [ ] Subuid/subgid configured for rootless podman
- [ ] /opt/gha owned by gha:gha
- [ ] /opt/gha permissions set to 755
- [ ] Environment variables configured
- [ ] GitHub token has correct scopes (repo, workflow)
- [ ] Service file uses User=gha

✅ **Ongoing**
- [ ] Regularly check storage usage
- [ ] Rotate GitHub tokens quarterly
- [ ] Monitor logs for errors/security issues
- [ ] Keep system packages updated
- [ ] Review runner permissions periodically

## Next Steps

1. **For detailed user setup**: Read [doc/GHA-USER-SETUP.md](doc/GHA-USER-SETUP.md)
2. **For storage management**: Read [STORAGE-CONFIG.md](STORAGE-CONFIG.md)
3. **For troubleshooting**: Read [doc/TROUBLESHOOTING.md](doc/TROUBLESHOOTING.md)
4. **For security**: Read [doc/SECURITY.md](doc/SECURITY.md)

## Quick Reference Commands

```bash
# Complete setup in order
sudo useradd -m -s /bin/bash gha
sudo usermod -aG podman gha
sudo usermod --add-subuids 100000-165535 gha
sudo usermod --add-subgids 100000-165535 gha

sudo mkdir -p /opt/gha/work /opt/gha/logs
sudo chown -R gha:gha /opt/gha
sudo chmod 755 /opt/gha

cp config/env.example .env
# Edit .env with your settings

sudo su - gha
cd github-actions-runner-podman
docker-compose up -d runner
exit

# Verify
docker-compose ps
sudo systemctl status github-actions-runner
```

---

**Project:** GitHub Actions Runner Podman  
**User:** gha (UID ~1001)  
**Storage:** /opt/gha (50GB)  
**Version:** 1.0.0  
**Status:** Production Ready ✅

