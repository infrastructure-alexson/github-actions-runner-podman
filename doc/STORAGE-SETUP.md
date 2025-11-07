# Storage Setup Guide

Configure and manage storage for GitHub Actions runners with the 50GB `/opt/gha` mount.

## Overview

The GitHub Actions runners require persistent storage for:
- Build artifacts and caches
- Workflow logs
- Docker/container images
- Intermediate build files

With a dedicated 50GB mount at `/opt/gha`, you can efficiently manage runner storage.

## Storage Mount Configuration

### Mount Point Structure

```
/opt/gha/                          (50GB total mount)
├── work/                          (Runner work directory)
│   ├── runner-1/
│   ├── runner-2/
│   └── runner-3/
├── logs/                          (Runner logs)
├── cache/                         (Optional caching)
└── backups/                       (Optional backups)
```

### Initial Setup

**1. Verify mount exists:**

```bash
# Check if /opt/gha is mounted
df -h /opt/gha

# Expected output:
# Filesystem      Size  Used Avail Use% Mounted on
# /dev/sdb1        50G     0   50G   0% /opt/gha
```

**2. Create directory structure:**

```bash
# Create work directory for runners
sudo mkdir -p /opt/gha/work
sudo mkdir -p /opt/gha/logs
sudo mkdir -p /opt/gha/cache

# Set permissions (runner user can write)
sudo chmod 755 /opt/gha
sudo chmod 755 /opt/gha/work
sudo chmod 755 /opt/gha/logs
sudo chmod 755 /opt/gha/cache

# Verify
ls -lah /opt/gha
```

**3. Set up for rootless podman (optional but recommended):**

```bash
# Check current permissions
stat /opt/gha

# For rootless podman access
sudo usermod --add-subuids 100000-165535 runner
sudo usermod --add-subgids 100000-165535 runner

# Set directory ownership (if not using rootless)
sudo chown -R runner:runner /opt/gha
```

## Docker Compose Deployment with Storage

### Configure Environment File

Create `.env` file from template:

```bash
cp config/env.example .env
```

Edit `.env` with storage mount:

```bash
# GitHub Configuration
GITHUB_REPO_URL=https://github.com/YOUR-ORG/YOUR-REPO
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
RUNNER_NAME=runner-01

# Storage Configuration - CRITICAL
RUNNER_WORK_VOLUME=/opt/gha
RUNNER_WORK_DIR=./_work

# Resource Configuration
RUNNER_CPUS=4
RUNNER_MEMORY=4G
RUNNER_CPUS_RESERVED=2
RUNNER_MEMORY_RESERVED=2G

# Optional: Multiple runners
RUNNER_NAME_2=runner-02
RUNNER_NAME_3=runner-03
```

### Deploy with Docker Compose

**Single runner:**

```bash
docker-compose up -d runner
```

**Multiple runners:**

```bash
docker-compose --profile multi-runner up -d
```

**Verify:**

```bash
docker-compose ps
docker-compose logs -f runner
```

### Monitor Storage Usage

```bash
# Overall usage
df -h /opt/gha

# Per-runner usage
du -sh /opt/gha/work/*

# Real-time usage
watch -n 1 'du -sh /opt/gha/work/*'

# Docker/Podman stats
docker stats runner

# Container disk usage
docker exec runner df -h /opt/gha
```

## Storage Planning

### Usage Patterns

| Type | Size | Notes |
|------|------|-------|
| Base OS + Tools | 2GB | Fixed per runner |
| Workflow artifacts | 5-10GB/run | Temporary, cleaned up |
| Build caches | 10-20GB | Persistent across runs |
| Docker images | 5-15GB | Per image, accumulates |
| Logs | 1-5GB | Retained based on policy |

### 50GB Allocation Recommendation

| Runners | Work Dir | Cache | Logs | Total |
|---------|----------|-------|------|-------|
| 1 | 15GB | 15GB | 5GB | 35GB |
| 2 | 20GB | 15GB | 5GB | 40GB |
| 3 | 25GB | 15GB | 5GB | 45GB |

**Leave 5-10% free** (2.5-5GB) for filesystem operations.

## Cleanup Strategies

### Automatic Cleanup (Ephemeral Mode)

Enable ephemeral runners for automatic cleanup:

```yaml
# docker-compose.yml
environment:
  RUNNER_EPHEMERAL: 'true'
```

```bash
# Or deploy script
./scripts/deploy-runner.sh \
  --repo <url> \
  --token <token> \
  --ephemeral
```

**Ephemeral benefits:**
- Runner cleans up after each job
- No state persists between runs
- Prevents storage accumulation
- Fresh environment for each job

### Manual Cleanup

**Clean workflow artifacts:**

```bash
# Remove old artifacts (older than 7 days)
find /opt/gha/work -type f -mtime +7 -delete

# Or use in workflow:
- name: Cleanup artifacts
  run: |
    docker system prune -f
    docker image prune -a -f
```

**Docker/Podman cleanup:**

```bash
# Remove stopped containers
docker container prune -f

# Remove unused images
docker image prune -a -f

# Remove unused volumes
docker volume prune -f

# Full cleanup (aggressive)
docker system prune -a
```

**Runner-specific cleanup:**

```bash
# SSH to runner
docker exec -it runner bash

# Inside container
cd ~/.runner
rm -rf _work/*
docker system prune -f

# Or use automated script
./scripts/cleanup-storage.sh
```

### Scheduled Cleanup (Cron)

Create scheduled cleanup job:

```bash
# Edit crontab
crontab -e

# Add daily cleanup at 2 AM
0 2 * * * /usr/bin/docker system prune -f >> /var/log/docker-cleanup.log 2>&1

# Add weekly aggressive cleanup at 3 AM Sunday
0 3 * * 0 /usr/bin/docker system prune -a -f >> /var/log/docker-cleanup.log 2>&1
```

## Monitoring and Alerts

### Monitor Storage

**Set up monitoring:**

```bash
# Create monitoring script
cat > /opt/gha/monitor.sh << 'EOF'
#!/bin/bash

THRESHOLD=80  # Alert when 80% used
MOUNT="/opt/gha"

USED=$(df $MOUNT | awk 'NR==2 {print $5}' | sed 's/%//')

if [ $USED -gt $THRESHOLD ]; then
    echo "WARNING: $MOUNT is $USED% full"
    # Add notification (email, webhook, etc.)
fi
EOF

chmod +x /opt/gha/monitor.sh

# Add to crontab
crontab -e
# 0 * * * * /opt/gha/monitor.sh
```

**Check usage with metrics:**

```bash
# Prometheus-compatible metrics
cat > /tmp/storage_metrics.txt << 'EOF'
# HELP storage_bytes Storage usage in bytes
# TYPE storage_bytes gauge
storage_bytes{mount="/opt/gha",type="used"} $(df /opt/gha | awk 'NR==2 {print $3 * 1024}')
storage_bytes{mount="/opt/gha",type="available"} $(df /opt/gha | awk 'NR==2 {print $4 * 1024}')
EOF
```

## Backup Strategy

### Why Backup?

- Preserve workflow artifacts
- Disaster recovery
- Audit trail
- Historical data

### Backup Methods

**1. Incremental Backup:**

```bash
# Backup only changed files
rsync -av --delete /opt/gha /mnt/backup/gha-backup-$(date +%Y%m%d)/

# Or with compression
tar czf /mnt/backup/gha-backup-$(date +%Y%m%d).tar.gz /opt/gha/work
```

**2. Automated Backup Script:**

```bash
#!/bin/bash
# /opt/gha/backup.sh

BACKUP_DIR="/mnt/backup"
SOURCE="/opt/gha"
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p $BACKUP_DIR

# Full backup weekly
if [ $(date +%u) -eq 1 ]; then
    tar czf $BACKUP_DIR/gha-full-$DATE.tar.gz $SOURCE
fi

# Incremental daily
rsync -av --delete $SOURCE $BACKUP_DIR/gha-incremental/

# Keep only recent backups (30 days)
find $BACKUP_DIR -name "gha-full-*.tar.gz" -mtime +30 -delete
```

**3. Scheduled Backup:**

```bash
# Add to crontab
0 2 * * * /opt/gha/backup.sh >> /var/log/gha-backup.log 2>&1
```

## Troubleshooting Storage

### Issue: Disk Full

**Symptoms:**
```
No space left on device
Cannot write file
```

**Solution:**

```bash
# Check usage
df -h /opt/gha
du -sh /opt/gha/*

# Find large files
find /opt/gha -type f -size +1G -exec ls -lh {} \;

# Clean up
docker system prune -a
rm -rf /opt/gha/work/*/

# Monitor for immediate issues
watch -n 1 'df -h /opt/gha'
```

### Issue: Slow Performance

**Symptoms:**
```
Workflows run slowly
High disk I/O
```

**Causes & Solutions:**

```bash
# Check I/O performance
iostat -x 1 5

# Check disk health
smartctl -a /dev/sdb

# Monitor processes
iotop -b -o -n 1

# Reduce I/O load:
# - Use ephemeral runners
# - Implement caching
# - Distribute across multiple runners
```

### Issue: Permission Denied

**Symptoms:**
```
Permission denied writing to /opt/gha
```

**Solution:**

```bash
# Check permissions
ls -la /opt/gha
stat /opt/gha

# Fix permissions
sudo chmod 755 /opt/gha
sudo chmod 755 /opt/gha/work

# For rootless podman
sudo chown -R 100000:100000 /opt/gha
```

## Performance Optimization

### SSD vs HDD

| Type | Speed | Reliability | Cost |
|------|-------|-------------|------|
| SSD | Fast | Good | Higher |
| NVMe | Very Fast | Good | Highest |
| HDD | Slow | Variable | Lower |

**Recommendation:** SSD for `/opt/gha` provides best balance

### Filesystem Choice

```bash
# Check current filesystem
df -T /opt/gha

# ext4: Good stability and performance
# xfs: Better for large files
# btrfs: Advanced features, snapshot support
```

### I/O Tuning

```bash
# Check I/O scheduler
cat /sys/block/sdb/queue/scheduler

# For SSD, use noop or mq-deadline
echo "mq-deadline" > /sys/block/sdb/queue/scheduler

# Make persistent (in /etc/rc.local or similar)
```

## Capacity Planning

### Usage Calculation

```
Capacity = (Base + ConcurrentRuns × PerRunSize) + Buffer
```

Example:
```
Capacity = (2GB + 2 runs × 10GB) + 5GB buffer = 27GB

For 50GB mount:
- 2 GB: Base system + tools
- 40 GB: 4 concurrent runs × 10GB
- 8 GB: Buffer for safety

Safe utilization: < 80%
```

## Migration Guide

### Move from Default to /opt/gha

```bash
# 1. Stop runners
docker-compose down

# 2. Backup current work
cp -r /opt/github-runner/_work /mnt/backup/

# 3. Create new structure
mkdir -p /opt/gha/work
cp -r /mnt/backup/_work/* /opt/gha/work/

# 4. Update environment
# Edit .env to point to /opt/gha

# 5. Restart
docker-compose up -d runner
```

## Related Documentation

- [INSTALLATION.md](INSTALLATION.md) - Initial setup
- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment strategies
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Solve issues
- [README.md](../README.md) - Project overview

