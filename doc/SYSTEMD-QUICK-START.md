# Systemd Quick Start

Fast setup guide for managing GitHub Actions runners with systemd.

## 5-Minute Setup

### 1. Create GHA User (already done?)
```bash
sudo useradd -m -s /bin/bash gha
sudo usermod -aG podman gha
sudo usermod --add-subuids 100000-165535 gha
sudo usermod --add-subgids 100000-165535 gha
```

### 2. Setup Storage
```bash
sudo mkdir -p /opt/gha/work /opt/gha/logs
sudo chown -R gha:gha /opt/gha
sudo chmod 755 /opt/gha
```

### 3. Install Service
```bash
# Copy service file
sudo cp config/github-actions-runner-podman.service \
  /etc/systemd/system/github-actions-runner.service

# Copy environment template
sudo cp config/runner.env.example /home/gha/.runner.env
sudo chown gha:gha /home/gha/.runner.env
chmod 600 /home/gha/.runner.env
```

### 4. Configure
```bash
# Edit environment file with your credentials
sudo nano /home/gha/.runner.env

# Update these required values:
# GITHUB_REPO_URL=https://github.com/YOUR-ORG/YOUR-REPO
# GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 5. Enable and Start
```bash
sudo systemctl daemon-reload
sudo systemctl enable github-actions-runner
sudo systemctl start github-actions-runner

# Verify
sudo systemctl status github-actions-runner
sudo journalctl -u github-actions-runner -f
```

## Service Files Provided

### 1. `github-actions-runner-podman.service` (RECOMMENDED)
- Direct podman container management
- Simplest setup
- Full control over podman options
- **Use this for most deployments**

### 2. `github-actions-runner-compose.service`
- Uses Docker Compose
- Good for multi-runner setups
- Requires docker-compose in working directory
- **Use this if you prefer Docker Compose**

### 3. `github-actions-runner-override.conf`
- Drop-in configuration for customization
- Doesn't replace service file
- Safe way to customize
- **Install in: `/etc/systemd/system/github-actions-runner.service.d/override.conf`**

## Configuration Files

### `runner.env.example`
Environment file with all variables. Copy to `/home/gha/.runner.env` and edit.

**Required:**
```bash
GITHUB_REPO_URL=https://github.com/YOUR-ORG/YOUR-REPO
GITHUB_TOKEN=ghp_xxxx
```

**Optional:**
```bash
RUNNER_NAME=runner-01
RUNNER_LABELS=podman,linux,ci
RUNNER_CPUS=4
RUNNER_MEMORY=4g
RUNNER_EPHEMERAL=false
```

## Common Commands

```bash
# Start service
sudo systemctl start github-actions-runner

# Stop service
sudo systemctl stop github-actions-runner

# Restart service
sudo systemctl restart github-actions-runner

# Check status
sudo systemctl status github-actions-runner

# Enable on boot
sudo systemctl enable github-actions-runner

# Disable auto-start
sudo systemctl disable github-actions-runner

# View logs
sudo journalctl -u github-actions-runner -f

# View last 50 lines
sudo journalctl -u github-actions-runner -n 50

# Check if enabled
sudo systemctl is-enabled github-actions-runner
```

## Customization

### Method 1: Edit Environment File (RECOMMENDED)
```bash
sudo nano /home/gha/.runner.env
sudo systemctl restart github-actions-runner
```

### Method 2: Use Drop-in Override
```bash
# Create drop-in directory
sudo mkdir -p /etc/systemd/system/github-actions-runner.service.d

# Copy override file
sudo cp config/github-actions-runner-override.conf \
  /etc/systemd/system/github-actions-runner.service.d/override.conf

# Edit customization
sudo nano /etc/systemd/system/github-actions-runner.service.d/override.conf

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart github-actions-runner
```

### Method 3: Direct Edit
```bash
sudo systemctl edit github-actions-runner
# Edit and save
sudo systemctl daemon-reload
sudo systemctl restart github-actions-runner
```

## Monitoring

```bash
# Real-time status
sudo systemctl status github-actions-runner

# Live logs
sudo journalctl -u github-actions-runner -f

# Container status
podman ps | grep github-runner

# Container stats
podman stats github-runner

# Check environment
sudo systemctl show github-actions-runner | grep Environment
```

## Troubleshooting

### Service won't start
```bash
# Check errors
sudo journalctl -u github-actions-runner -p err -n 20

# Verify syntax
systemd-analyze verify /etc/systemd/system/github-actions-runner.service

# Check dependencies
sudo systemctl status podman.service
```

### High resource usage
```bash
# Check limits
systemctl show github-actions-runner --property=MemoryLimit

# Edit override to reduce
sudo nano /etc/systemd/system/github-actions-runner.service.d/override.conf

# Update values:
# MemoryLimit=2G (reduce from 4G)
# CPUQuota=200% (reduce from 400%)

# Reload
sudo systemctl daemon-reload
sudo systemctl restart github-actions-runner
```

### Permission denied
```bash
# Check permissions
ls -la /opt/gha
stat /opt/gha | grep Uid

# Fix if needed
sudo chown -R gha:gha /opt/gha
sudo chmod 755 /opt/gha

# Restart
sudo systemctl restart github-actions-runner
```

## Multiple Runners

Create separate environment files for each runner:

```bash
# Create environments
sudo cp config/runner.env.example /home/gha/.runner-1.env
sudo cp config/runner.env.example /home/gha/.runner-2.env

# Edit each
sudo nano /home/gha/.runner-1.env  # RUNNER_NAME=runner-01
sudo nano /home/gha/.runner-2.env  # RUNNER_NAME=runner-02

# Edit override to use different env per instance
sudo mkdir -p /etc/systemd/system/github-actions-runner.service.d
sudo tee /etc/systemd/system/github-actions-runner.service.d/override.conf << 'EOF'
[Service]
EnvironmentFile=/home/gha/.runner-%i.env
EOF

# Create service template
sudo sed 's/github-actions-runner/github-actions-runner@/g' \
  /etc/systemd/system/github-actions-runner.service > \
  /etc/systemd/system/github-actions-runner@.service

# Start multiple instances
sudo systemctl daemon-reload
sudo systemctl enable github-actions-runner@1
sudo systemctl enable github-actions-runner@2
sudo systemctl start github-actions-runner@{1,2}

# Check all
sudo systemctl status github-actions-runner@{1,2}
```

## Systemd Service File Locations

| File | Purpose |
|------|---------|
| `/etc/systemd/system/github-actions-runner.service` | Main service file |
| `/etc/systemd/system/github-actions-runner.service.d/override.conf` | Drop-in overrides |
| `/home/gha/.runner.env` | Environment variables |

## Check Service Health

```bash
# Service status
sudo systemctl status github-actions-runner

# Is service running?
sudo systemctl is-active github-actions-runner

# Is service enabled?
sudo systemctl is-enabled github-actions-runner

# Show all properties
sudo systemctl show github-actions-runner

# Show CPU usage
systemctl show github-actions-runner --property=CPUUsageUSec

# Show memory usage
systemctl show github-actions-runner --property=MemoryCurrent
```

## Auto-restart Behavior

In the service file, restart is configured as:
```ini
Restart=on-failure
RestartSec=10
StartLimitInterval=600
StartLimitBurst=3
```

This means:
- **Auto-restart** on failure (non-zero exit)
- **Wait 10 seconds** between restarts
- **Max 3 restarts** in 10 minutes
- If exceeded, service enters **failed state**

To change, use override.conf:
```ini
[Service]
Restart=always
RestartSec=5
StartLimitBurst=5
```

## Logging Integration

The service uses `journald` for logging. View logs:

```bash
# Follow logs
sudo journalctl -u github-actions-runner -f

# Show last 100 lines
sudo journalctl -u github-actions-runner -n 100

# Show since boot
sudo journalctl -u github-actions-runner -b

# Show errors only
sudo journalctl -u github-actions-runner -p err

# With timestamps
sudo journalctl -u github-actions-runner -o short-iso

# Verbose format
sudo journalctl -u github-actions-runner -o verbose
```

## Complete Example

```bash
# 1. Create user
sudo useradd -m -s /bin/bash gha 2>/dev/null || true
sudo usermod -aG podman gha

# 2. Setup storage
sudo mkdir -p /opt/gha/{work,logs,cache}
sudo chown -R gha:gha /opt/gha
sudo chmod 755 /opt/gha

# 3. Install service
sudo cp config/github-actions-runner-podman.service \
  /etc/systemd/system/github-actions-runner.service

# 4. Configure
sudo cp config/runner.env.example /home/gha/.runner.env
sudo chown gha:gha /home/gha/.runner.env
chmod 600 /home/gha/.runner.env

# Edit with your GitHub token
# (Skip this for now - just verify setup works)

# 5. Enable
sudo systemctl daemon-reload
sudo systemctl enable github-actions-runner

# 6. Start
sudo systemctl start github-actions-runner

# 7. Verify
sudo systemctl status github-actions-runner
sudo journalctl -u github-actions-runner -n 20
```

## Next Steps

1. **Read full guide**: [doc/SYSTEMD-MANAGEMENT.md](doc/SYSTEMD-MANAGEMENT.md)
2. **Configure credentials**: Edit `/home/gha/.runner.env`
3. **Start service**: `sudo systemctl start github-actions-runner`
4. **Monitor**: `sudo journalctl -u github-actions-runner -f`
5. **Verify in GitHub**: Settings > Actions > Runners

## Quick Reference Card

```bash
# Install & enable
sudo cp config/github-actions-runner-podman.service /etc/systemd/system/
sudo cp config/runner.env.example /home/gha/.runner.env
sudo nano /home/gha/.runner.env
sudo systemctl daemon-reload
sudo systemctl enable --now github-actions-runner

# Monitor
sudo systemctl status github-actions-runner
sudo journalctl -u github-actions-runner -f

# Manage
sudo systemctl {start|stop|restart|reload} github-actions-runner
sudo systemctl {enable|disable} github-actions-runner

# Troubleshoot
systemd-analyze verify /etc/systemd/system/github-actions-runner.service
sudo journalctl -u github-actions-runner -p err
```

---

**Systemd management is production-ready!** ✅

See [doc/SYSTEMD-MANAGEMENT.md](doc/SYSTEMD-MANAGEMENT.md) for complete documentation.

