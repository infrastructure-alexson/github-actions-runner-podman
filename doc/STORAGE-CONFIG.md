# Storage Configuration - 50GB Mount at /opt/gha

Quick reference for configuring the GitHub Actions runners with the 50GB storage mount.

## Summary

Your deployment uses:
- **Mount Point**: `/opt/gha` (50GB)
- **Purpose**: Runner work directory, caches, artifacts, logs
- **Configuration**: Environment variables in `.env`

## Quick Setup (5 minutes)

### 1. Create GHA User (if not already done)

```bash
# Create dedicated gha user
sudo useradd -m -s /bin/bash gha

# Add to podman group
sudo usermod -aG podman gha

# Configure rootless podman
sudo usermod --add-subuids 100000-165535 gha
sudo usermod --add-subgids 100000-165535 gha
```

See [doc/GHA-USER-SETUP.md](doc/GHA-USER-SETUP.md) for detailed user setup.

### 2. Verify Mount

```bash
df -h /opt/gha
# Should show: 50G mounted at /opt/gha
```

### 3. Create Directories and Set Permissions

```bash
sudo mkdir -p /opt/gha/work
sudo mkdir -p /opt/gha/logs
sudo mkdir -p /opt/gha/cache

# Set ownership to gha user
sudo chown -R gha:gha /opt/gha

# Set permissions
sudo chmod 755 /opt/gha
```

### 4. Configure Environment

```bash
cp config/env.example .env
```

Edit `.env`:
```bash
# Storage mount configuration
RUNNER_WORK_VOLUME=/opt/gha
RUNNER_WORK_DIR=./_work
RUNNER_USER=gha
RUNNER_GROUP=gha

# Multiple runners example
RUNNER_NAME_2=runner-02
RUNNER_LABELS_2=ci,linux
```

### 5. Deploy as GHA User

```bash
# Switch to gha user
sudo su - gha

# Navigate to project
cd /path/to/github-actions-runner-podman

# Deploy single runner
docker-compose up -d runner

# Or for multiple runners
docker-compose --profile multi-runner up -d

# Exit gha user
exit
```

Or deploy with sudo:
```bash
sudo -u gha docker-compose -f /path/to/docker-compose.yml up -d runner
```

### 5. Verify

```bash
docker-compose ps
docker-compose logs -f runner
df -h /opt/gha
```

## Storage Usage

### Monitor Space

```bash
# Overall
df -h /opt/gha

# Per runner
du -sh /opt/gha/work/*

# Real-time watch
watch -n 1 'df -h /opt/gha'
```

### Expected Usage

| Component | Size | Notes |
|-----------|------|-------|
| Base tools | 2GB | Per container |
| Build outputs | 10-20GB | Per workflow |
| Docker images | 5-15GB | Accumulates |
| Caches | 5-10GB | Persistent |
| Logs | 1-5GB | Can grow |

### 50GB Allocation

```
Total: 50GB
├── 3-5GB: OS & tools (fixed)
├── 20-25GB: Active work/builds
├── 10-15GB: Caches
├── 3-5GB: Logs & temp
└── 5GB: Safety buffer (keep free)
```

## Cleanup Strategy

### Ephemeral Runners (Recommended)

Enable automatic cleanup after each job:

```bash
# In .env
RUNNER_EPHEMERAL=true

# Or deploy with
./scripts/deploy-runner.sh --ephemeral --repo <url> --token <token>
```

### Manual Cleanup

```bash
# Daily cleanup
docker system prune -f

# Weekly aggressive cleanup
docker system prune -a -f

# Emergency cleanup (last resort)
docker container prune -f
docker image prune -a -f
docker volume prune -f
```

### Automated Cleanup (Cron)

```bash
# Add to crontab -e
0 2 * * * docker system prune -f >> /var/log/docker-cleanup.log 2>&1
0 3 * * 0 docker system prune -a -f >> /var/log/docker-cleanup.log 2>&1
```

## Complete Configuration Example

### .env File

```bash
# GitHub Configuration
GITHUB_REPO_URL=https://github.com/YOUR-ORG/YOUR-REPO
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Runner Configuration
RUNNER_NAME=runner-01
RUNNER_LABELS=podman,linux,ci,docker
RUNNER_EPHEMERAL=false
RUNNER_REPLACE=true

# Storage Configuration
RUNNER_WORK_VOLUME=/opt/gha
RUNNER_WORK_DIR=./_work

# Resource Limits
RUNNER_CPUS=4
RUNNER_MEMORY=4G
RUNNER_CPUS_RESERVED=2
RUNNER_MEMORY_RESERVED=2G

# Multi-runner (optional)
RUNNER_NAME_2=runner-02
RUNNER_LABELS_2=podman,linux,ci
RUNNER_EPHEMERAL_2=false

RUNNER_NAME_3=runner-03
RUNNER_LABELS_3=podman,linux,ci
RUNNER_EPHEMERAL_3=false
```

### Docker Compose Usage

```bash
# Deploy from configured .env
docker-compose up -d runner

# Deploy multiple runners
docker-compose --profile multi-runner up -d

# Scale (for services with restart=always)
docker-compose up -d --scale runner=3

# Monitor
docker-compose ps
docker-compose logs -f

# Stop
docker-compose down
```

## Troubleshooting Storage

### "Disk Full" Error

```bash
# Check usage
df -h /opt/gha
du -sh /opt/gha/*

# Clean up
docker system prune -a -f
docker container prune -f

# Find large files
find /opt/gha -type f -size +100M -exec ls -lh {} \;
```

### Slow Performance

```bash
# Check I/O
iostat -x 1 5

# Monitor resource usage
docker stats runner
watch -n 1 'docker exec runner df -h /opt/gha'

# Solutions:
# - Enable ephemeral mode
# - Implement caching in workflows
# - Distribute load across runners
```

### Permission Issues

```bash
# Check permissions
ls -la /opt/gha

# Fix permissions
sudo chmod 755 /opt/gha
sudo chmod 755 /opt/gha/work

# For specific user
sudo chown -R runner:runner /opt/gha
```

## Backup Strategy

### Backup Configuration

```bash
# Create backup directory
mkdir -p /mnt/backup

# Backup work directory
rsync -av --delete /opt/gha/work /mnt/backup/

# Or compress
tar czf /mnt/backup/gha-backup-$(date +%Y%m%d).tar.gz /opt/gha
```

### Scheduled Backup

```bash
# Add to crontab -e
# Daily backup at 3 AM
0 3 * * * rsync -av --delete /opt/gha/work /mnt/backup/ >> /var/log/gha-backup.log 2>&1
```

## Performance Tips

### Best Practices

1. **Use SSD**: Faster I/O than HDD
2. **Enable Ephemeral**: Auto-cleanup between jobs
3. **Implement Caching**: Workflows should use GitHub caching
4. **Distribute Load**: Use multiple runners
5. **Monitor Space**: Watch for filling disk

### Workflow Optimization

```yaml
# Use caching to reduce space
- uses: actions/cache@v3
  with:
    path: ~/.cache
    key: build-cache-${{ runner.os }}

# Clean artifacts after upload
- uses: actions/upload-artifact@v3
  with:
    path: dist/
    retention-days: 30  # Auto-delete after 30 days
```

## Monitoring Setup

### Manual Monitoring

```bash
# Check daily
df -h /opt/gha

# Check what's using space
du -sh /opt/gha/*
find /opt/gha -type f -mtime +7  # Files older than 7 days
```

### Automated Monitoring Script

```bash
#!/bin/bash
# /opt/gha/monitor.sh

THRESHOLD=80
USED=$(df /opt/gha | awk 'NR==2 {print $5}' | sed 's/%//')

if [ $USED -gt $THRESHOLD ]; then
    echo "WARNING: /opt/gha is $USED% full"
    # Send alert (email, webhook, etc.)
fi
```

Add to crontab:
```bash
0 * * * * /opt/gha/monitor.sh
```

## References

- [STORAGE-SETUP.md](doc/STORAGE-SETUP.md) - Comprehensive storage guide
- [INSTALLATION.md](doc/INSTALLATION.md) - Installation with storage
- [DEPLOYMENT.md](doc/DEPLOYMENT.md) - Deployment strategies
- [TROUBLESHOOTING.md](doc/TROUBLESHOOTING.md) - Problem solving

## Quick Commands

```bash
# Setup
sudo mkdir -p /opt/gha/work
cp config/env.example .env
# Edit .env with storage settings

# Deploy
docker-compose up -d runner

# Monitor
df -h /opt/gha
du -sh /opt/gha/work/*
docker stats runner

# Clean
docker system prune -f

# Stop
docker-compose down
```

---

**Need more details?** See [doc/STORAGE-SETUP.md](doc/STORAGE-SETUP.md) for comprehensive storage management guide.

