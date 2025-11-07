# Systemd Service Management Guide

Complete guide for managing GitHub Actions runners using systemd.

## Overview

Systemd provides automatic service management with:
- Automatic startup on boot
- Automatic restart on failure
- Integrated logging (journalctl)
- Resource limiting
- Dependency management
- Health monitoring

## Service Files

The project provides multiple systemd service options:

| File | Type | Use Case |
|------|------|----------|
| `github-actions-runner-podman.service` | Direct podman | Simple single-runner |
| `github-actions-runner-compose.service` | Docker Compose | Multi-runner setup |
| `github-actions-runner-override.conf` | Drop-in | Customization |
| `runner.env.example` | Environment | Configuration |

## Installation

### Option 1: Direct Podman Service (Recommended)

**Step 1: Copy service file**
```bash
sudo cp config/github-actions-runner-podman.service \
  /etc/systemd/system/github-actions-runner.service
```

**Step 2: Create environment file**
```bash
sudo cp config/runner.env.example /home/gha/.runner.env
sudo chown gha:gha /home/gha/.runner.env
chmod 600 /home/gha/.runner.env
```

**Step 3: Edit configuration**
```bash
sudo nano /home/gha/.runner.env
# Update:
# GITHUB_REPO_URL=https://github.com/YOUR-ORG/YOUR-REPO
# GITHUB_TOKEN=ghp_xxxx
```

**Step 4: Enable and start**
```bash
sudo systemctl daemon-reload
sudo systemctl enable github-actions-runner
sudo systemctl start github-actions-runner
```

**Step 5: Verify**
```bash
sudo systemctl status github-actions-runner
sudo journalctl -u github-actions-runner -f
```

### Option 2: Docker Compose Service

**Step 1: Copy service file**
```bash
sudo cp config/github-actions-runner-compose.service \
  /etc/systemd/system/github-actions-runner.service
```

**Step 2: Setup environment**
```bash
cp config/env.example /home/gha/github-actions-runner-podman/.env
chmod 600 /home/gha/github-actions-runner-podman/.env
```

**Step 3: Enable and start**
```bash
sudo systemctl daemon-reload
sudo systemctl enable github-actions-runner
sudo systemctl start github-actions-runner
```

### Option 3: With Custom Drop-in Configuration

**Step 1: Install base service**
```bash
sudo cp config/github-actions-runner-podman.service \
  /etc/systemd/system/github-actions-runner.service
```

**Step 2: Create drop-in directory**
```bash
sudo mkdir -p /etc/systemd/system/github-actions-runner.service.d
```

**Step 3: Install drop-in override**
```bash
sudo cp config/github-actions-runner-override.conf \
  /etc/systemd/system/github-actions-runner.service.d/override.conf
```

**Step 4: Customize override.conf**
```bash
sudo nano /etc/systemd/system/github-actions-runner.service.d/override.conf
# Adjust resource limits and other settings
```

**Step 5: Reload and restart**
```bash
sudo systemctl daemon-reload
sudo systemctl restart github-actions-runner
```

## Common Operations

### Start Service
```bash
sudo systemctl start github-actions-runner
```

### Stop Service
```bash
sudo systemctl stop github-actions-runner
```

### Restart Service
```bash
sudo systemctl restart github-actions-runner
```

### View Service Status
```bash
sudo systemctl status github-actions-runner
```

### View Logs
```bash
# Last 50 lines
sudo journalctl -u github-actions-runner -n 50

# Real-time logs
sudo journalctl -u github-actions-runner -f

# Since last boot
sudo journalctl -u github-actions-runner --since today

# With timestamps
sudo journalctl -u github-actions-runner -o short-iso
```

### Enable/Disable Auto-Start
```bash
# Enable (start on boot)
sudo systemctl enable github-actions-runner

# Disable (don't start on boot)
sudo systemctl disable github-actions-runner

# Check if enabled
sudo systemctl is-enabled github-actions-runner
```

### Check Service File
```bash
# Show service file
sudo systemctl cat github-actions-runner

# Show active configuration
sudo systemctl show github-actions-runner

# Show environment
sudo systemctl show github-actions-runner | grep Environment
```

### Reload Service Configuration
```bash
# Reload systemd configuration
sudo systemctl daemon-reload

# Reload service (if supports it)
sudo systemctl reload github-actions-runner

# Restart with new config
sudo systemctl restart github-actions-runner
```

## Configuration Management

### Update Environment Variables

**Method 1: Edit environment file**
```bash
sudo nano /home/gha/.runner.env
# Make changes
sudo systemctl restart github-actions-runner
```

**Method 2: Edit drop-in override**
```bash
sudo nano /etc/systemd/system/github-actions-runner.service.d/override.conf
# Make changes
sudo systemctl daemon-reload
sudo systemctl restart github-actions-runner
```

**Method 3: Direct service edit**
```bash
sudo systemctl edit github-actions-runner
# Edit environment variables
# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart github-actions-runner
```

### Change Resource Limits

Edit drop-in or override file:
```bash
sudo nano /etc/systemd/system/github-actions-runner.service.d/override.conf
```

Update these values:
```ini
MemoryLimit=4G          # Maximum memory
CPUQuota=400%           # CPU limit (100% per core)
CPUAccounting=yes       # Track CPU usage
MemoryAccounting=yes    # Track memory usage
TasksMax=512            # Maximum processes
```

Then reload:
```bash
sudo systemctl daemon-reload
sudo systemctl restart github-actions-runner
```

## Monitoring

### Real-time Status
```bash
# Watch service status
watch -n 1 'sudo systemctl status github-actions-runner'

# Watch resource usage
watch -n 1 'podman stats github-runner'
```

### Check for Errors
```bash
# Look for recent errors
sudo journalctl -u github-actions-runner -p err

# Show last error
sudo journalctl -u github-actions-runner -p err -n 1 -o verbose
```

### Service Metrics
```bash
# Show service properties
sudo systemctl show github-actions-runner -a

# Show memory usage
sudo systemctl status github-actions-runner | grep Memory

# Show CPU usage
systemctl show github-actions-runner --property=CPUUsageUSec
```

### Monitor Container
```bash
# Container status
podman ps -a | grep github-runner

# Container resource usage
podman stats github-runner

# Container logs
podman logs -f github-runner
```

## Troubleshooting

### Service Won't Start

**Check logs:**
```bash
sudo journalctl -u github-actions-runner -n 50 -p err
```

**Verify service file syntax:**
```bash
systemd-analyze verify /etc/systemd/system/github-actions-runner.service
```

**Check service dependencies:**
```bash
sudo systemctl status podman.service
sudo systemctl status docker.service
```

**Solution:**
```bash
# Fix issues and reload
sudo systemctl daemon-reload
sudo systemctl start github-actions-runner
```

### Service Exits Too Quickly

**Check exit code:**
```bash
sudo systemctl status github-actions-runner
# Look for exit code and message
```

**Check container logs:**
```bash
podman logs github-runner
```

**Increase timeout (in override.conf):**
```ini
TimeoutStartSec=300
```

### High CPU/Memory Usage

**Check resource limits:**
```bash
systemctl show github-actions-runner --property=MemoryLimit
systemctl show github-actions-runner --property=CPUQuota
```

**Reduce limits (in override.conf):**
```ini
MemoryLimit=2G
CPUQuota=200%
```

**Restart service:**
```bash
sudo systemctl restart github-actions-runner
```

### Permission Denied

**Check service user:**
```bash
grep "User=" /etc/systemd/system/github-actions-runner.service
```

**Verify user permissions:**
```bash
id gha
ls -la /opt/gha
ls -la /home/gha
```

**Fix permissions:**
```bash
sudo chown -R gha:gha /opt/gha
sudo chown -R gha:gha /home/gha/.runner.env
chmod 600 /home/gha/.runner.env
```

### Container Can't Access Storage

**Check volume mount:**
```bash
podman inspect github-runner | grep -A 5 Mounts
```

**Verify mount permissions:**
```bash
sudo -u gha ls -la /opt/gha
stat /opt/gha
```

**Fix if needed:**
```bash
sudo chown -R gha:gha /opt/gha
sudo chmod 755 /opt/gha
sudo systemctl restart github-actions-runner
```

## Advanced Configuration

### Multiple Runners

Create separate service instances:

```bash
# Copy base service
sudo cp /etc/systemd/system/github-actions-runner.service \
  /etc/systemd/system/github-actions-runner@.service

# Create environment for each runner
sudo cp config/runner.env.example /home/gha/.runner-1.env
sudo cp config/runner.env.example /home/gha/.runner-2.env
sudo cp config/runner.env.example /home/gha/.runner-3.env

# Edit each environment file with unique settings
sudo nano /home/gha/.runner-1.env  # Set RUNNER_NAME=runner-01
sudo nano /home/gha/.runner-2.env  # Set RUNNER_NAME=runner-02
sudo nano /home/gha/.runner-3.env  # Set RUNNER_NAME=runner-03

# Update service to use instance-specific environment
# In @.service: EnvironmentFile=/home/gha/.runner-%i.env

# Enable and start each instance
sudo systemctl enable github-actions-runner@1
sudo systemctl enable github-actions-runner@2
sudo systemctl enable github-actions-runner@3

sudo systemctl start github-actions-runner@{1,2,3}

# Check all instances
sudo systemctl status github-actions-runner@{1,2,3}
```

### Conditional Auto-Restart

Edit drop-in or override file:
```ini
# Restart only on specific exit codes
RestartForceExitStatus=1 2
RestartPreventExitStatus=0 3 4

# Or use RestartForceExitStatus for specific codes
RestartForceExitStatus=1
Restart=on-failure
RestartSec=30
StartLimitInterval=300
StartLimitBurst=2
```

### Custom Service Dependencies

Edit service file:
```ini
[Unit]
After=network-online.target docker.service podman.service some-setup.service
Wants=network-online.target
BindsTo=podman.service
```

### Timer for Regular Cleanup

Create `/etc/systemd/system/github-runner-cleanup.timer`:
```ini
[Unit]
Description=Cleanup GitHub Runner
After=network.target

[Timer]
OnBootSec=1h
OnUnitActiveSec=12h
AccuracySec=1m

[Install]
WantedBy=timers.target
```

Create `/etc/systemd/system/github-runner-cleanup.service`:
```ini
[Unit]
Description=Cleanup GitHub Runner Service
After=github-actions-runner.service

[Service]
Type=oneshot
User=gha
ExecStart=/usr/bin/podman system prune -f
ExecStart=/usr/bin/podman volume prune -f
```

Enable timer:
```bash
sudo systemctl enable github-runner-cleanup.timer
sudo systemctl start github-runner-cleanup.timer
```

## Best Practices

✅ **Do:**
- Use environment file for configuration
- Set resource limits based on system
- Use override.conf for customization
- Monitor logs regularly
- Enable auto-start on boot
- Use specific image tags
- Keep service files readable
- Document customizations
- Regular backup of configuration

❌ **Don't:**
- Hardcode secrets in service file
- Set unlimited resources
- Modify installed service files directly
- Run as root unnecessarily
- Ignore restart failures
- Use outdated image tags
- Mix environment sources (env file + inline)
- Skip monitoring logs

## Quick Reference

```bash
# Install service
sudo cp config/github-actions-runner-podman.service \
  /etc/systemd/system/github-actions-runner.service

# Configure environment
sudo cp config/runner.env.example /home/gha/.runner.env
sudo nano /home/gha/.runner.env

# Reload and start
sudo systemctl daemon-reload
sudo systemctl enable github-actions-runner
sudo systemctl start github-actions-runner

# Monitor
sudo systemctl status github-actions-runner
sudo journalctl -u github-actions-runner -f

# Restart
sudo systemctl restart github-actions-runner

# Stop
sudo systemctl stop github-actions-runner

# Customize
sudo mkdir -p /etc/systemd/system/github-actions-runner.service.d
sudo cp config/github-actions-runner-override.conf \
  /etc/systemd/system/github-actions-runner.service.d/override.conf
sudo nano /etc/systemd/system/github-actions-runner.service.d/override.conf
sudo systemctl daemon-reload
```

## Related Documentation

- [GHA-USER-SETUP.md](GHA-USER-SETUP.md) - GHA user configuration
- [INSTALLATION.md](INSTALLATION.md) - Installation guide
- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment options
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Problem solving

## External Resources

- [systemd.service documentation](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [systemd.unit documentation](https://www.freedesktop.org/software/systemd/man/systemd.unit.html)
- [Podman systemd integration](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [journalctl reference](https://www.freedesktop.org/software/systemd/man/journalctl.html)

---

**Systemd Service Management is production-ready!** ✅

