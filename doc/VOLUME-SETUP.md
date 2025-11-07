# Volume and Storage Setup Guide

This guide covers setting up volumes and directories for the GitHub Actions runner configuration and work directories.

## Quick Overview

The runner requires two persistent volumes:
1. **Config Volume** (`runner-config`): Stores runner registration and credentials
2. **Work Volume** (`runner-work`): Stores job artifacts and working data

## Directory Structure

```bash
/opt/gha/
├── runner-config/           # Runner configuration and credentials
│   ├── .runner              # Runner configuration file
│   └── .credentials         # GitHub runner credentials
└── runner-work/             # Job working directory
    ├── _work/               # Working directory for workflows
    │   ├── _actions/        # Cached actions
    │   ├── _temp/           # Temporary files
    │   └── run-X/           # Individual job runs
    └── logs/                # Runner logs
```

## Setup Methods

### Method 1: Host Bind Mounts (Simple, for single host)

```bash
# Create directories on host
sudo mkdir -p /opt/gha/runner-config
sudo mkdir -p /opt/gha/runner-work

# Set proper permissions (for rootless podman as user 'gha' with UID 984)
sudo chown -R 984:984 /opt/gha
sudo chmod 755 /opt/gha
sudo chmod 755 /opt/gha/runner-config
sudo chmod 755 /opt/gha/runner-work

# Verify
ls -la /opt/gha/
```

**In `docker-compose.yml`:**

```yaml
services:
  github-runner:
    volumes:
      - /opt/gha/runner-config:/home/runner/.runner
      - /opt/gha/runner-work:/home/runner/_work
```

**Pros:**
- ✅ Simple setup
- ✅ Direct host access
- ✅ Easy backup

**Cons:**
- ❌ Permission issues with rootless containers
- ❌ Not portable across hosts

---

### Method 2: Named Volumes (Recommended - managed by Podman)

Named volumes are automatically created and managed by Podman, handling permissions correctly for rootless containers.

**In `docker-compose.yml`:**

```yaml
services:
  github-runner:
    volumes:
      - gha_runner-config-vol:/home/runner/.runner
      - gha_runner-work-vol:/home/runner/_work

volumes:
  gha_runner-config-vol:
    driver: local
  gha_runner-work-vol:
    driver: local
```

**Setup:**

```bash
# Volumes are created automatically on first run
podman-compose up -d

# Verify volumes
podman volume ls | grep gha_runner

# Inspect volume location
podman volume inspect gha_runner-config-vol
```

**Output:**
```json
[
  {
    "Name": "gha_runner-config-vol",
    "Driver": "local",
    "Mountpoint": "/var/lib/containers/storage/volumes/gha_runner-config-vol/_data",
    "Labels": {},
    "Scope": "local"
  }
]
```

**Pros:**
- ✅ Automatically handles permissions
- ✅ Portable across hosts (same compose file works)
- ✅ Managed by Podman
- ✅ Works with rootless containers

**Cons:**
- ❌ Less direct host access
- ❌ Located in Podman's storage directory

**Recommended!** This is the best option for production.

---

### Method 3: NFS Mounts (Production - multiple hosts)

For deployment across multiple hosts or for high-availability setups:

```bash
# Mount NFS share
sudo mkdir -p /mnt/runner-storage
sudo mount -t nfs4 nfs-server.example.com:/export/runner-storage /mnt/runner-storage
sudo mkdir -p /mnt/runner-storage/{config,work}

# Set permissions
sudo chown 984:984 /mnt/runner-storage/{config,work}
sudo chmod 755 /mnt/runner-storage/{config,work}
```

**In `docker-compose.yml`:**

```yaml
services:
  github-runner:
    volumes:
      - /mnt/runner-storage/config:/home/runner/.runner
      - /mnt/runner-storage/work:/home/runner/_work
```

**Pros:**
- ✅ Shared across multiple hosts
- ✅ Persistent data
- ✅ Centralized backup

**Cons:**
- ❌ Complex setup
- ❌ Network dependency
- ❌ Performance overhead

---

## Permissions Setup

### For User 'gha' (UID 984)

If running as user `gha`:

```bash
# Check user mapping
id gha
# uid=984(gha) gid=984(gha) groups=984(gha)

# Check subuid/subgid mapping
grep gha /etc/subuid /etc/subgid
# /etc/subuid:gha:200000:65536
# /etc/subgid:gha:200000:65536
```

**For bind mounts:**

```bash
# Host directories must be owned by gha user
sudo chown 984:984 /opt/gha/runner-config
sudo chown 984:984 /opt/gha/runner-work
sudo chmod 755 /opt/gha/runner-config
sudo chmod 755 /opt/gha/runner-work
```

**Inside container (UID 1001):**

The runner user inside the container has UID 1001. When using named volumes, Podman automatically maps permissions correctly. With bind mounts, ensure the host directory is accessible.

---

## Viewing Volume Data

### Named Volumes

```bash
# List volumes
podman volume ls

# Inspect specific volume
podman volume inspect gha_runner-config-vol

# Access volume data directly
sudo ls -la /var/lib/containers/storage/volumes/gha_runner-config-vol/_data/

# Or from container
podman exec github-runner ls -la /home/runner/.runner/
```

### Bind Mounts

```bash
# Direct host access
ls -la /opt/gha/runner-config/
ls -la /opt/gha/runner-work/

# From container
podman exec github-runner ls -la /home/runner/.runner/
```

---

## Backup and Recovery

### Backup Named Volumes

```bash
# Create tarball of config volume
podman run --rm \
  -v gha_runner-config-vol:/data \
  -v $(pwd):/backup \
  ubuntu tar czf /backup/runner-config-backup.tar.gz -C /data .

# Restore from backup
podman volume rm gha_runner-config-vol
podman volume create gha_runner-config-vol
podman run --rm \
  -v gha_runner-config-vol:/data \
  -v $(pwd):/backup \
  ubuntu tar xzf /backup/runner-config-backup.tar.gz -C /data
```

### Backup Bind Mounts

```bash
# Simple directory backup
sudo tar czf /backup/runner-config-$(date +%Y%m%d).tar.gz /opt/gha/runner-config/

# Restore
sudo tar xzf runner-config-20231115.tar.gz -C /
```

---

## Cleanup and Removal

### Stop and Remove Volumes

```bash
# Stop container
podman-compose down

# Remove named volumes (WARNING: Data is deleted!)
podman volume rm gha_runner-config-vol
podman volume rm gha_runner-work-vol

# Or remove all volumes for the project
podman volume rm $(podman volume ls | grep gha_runner | awk '{print $2}')
```

### Reuse Volumes with New Container

```bash
# Stop old container
podman-compose down

# Volumes persist, re-run with same compose file
podman-compose up -d

# Runner will use existing configuration
```

---

## Troubleshooting Volume Issues

### Permission Denied Errors

**Symptom:** `Permission denied` when accessing volume from container

```bash
# Check volume ownership
podman volume inspect gha_runner-config-vol

# If needed, recreate volume with proper permissions
podman volume rm gha_runner-config-vol
podman volume create gha_runner-config-vol
```

### Volume Not Found

**Symptom:** `Error: running volume driver: volume not found`

```bash
# List existing volumes
podman volume ls

# Create missing volume
podman volume create gha_runner-config-vol
```

### Container Can't Write to Volume

**Symptom:** `Read-only file system` errors

```bash
# Check mount options
podman inspect github-runner | grep -A 20 "Mounts"

# If read-only, update docker-compose.yml:
# volumes:
#   - gha_runner-config-vol:/home/runner/.runner:rw  # Add :rw
```

### Orphaned Volumes

**Cleanup unused volumes:**

```bash
# Find unused volumes
podman volume prune

# Or remove specific orphaned volume
podman volume rm orphaned-volume-name
```

---

## Storage Capacity Planning

### Typical Disk Usage

| Component | Typical Size | Notes |
|-----------|-------------|-------|
| Config (`.runner`, `.credentials`) | 1-10 MB | Small, contains registration data |
| Single job run | 50-500 MB | Depends on artifacts |
| Work directory (30 days of runs) | 20-100 GB | Archive old runs to reduce |
| Container image | 800 MB | Ubuntu 22.04 + tools |
| **Total per runner** | **25-150 GB** | Recommended: 50-100 GB |

### Recommended Disk Allocation

- **Development**: 20 GB minimum
- **Production (single runner)**: 50-100 GB
- **Production (multiple runners)**: 150+ GB

### Cleanup Old Runs

```bash
# Remove runs older than 30 days
find /opt/gha/runner-work -type d -name "run-*" -mtime +30 -exec rm -rf {} \;

# Or from container
podman exec github-runner bash -c 'find /home/runner/_work -type d -name "run-*" -mtime +30 -exec rm -rf {} \;'
```

---

## Performance Considerations

### Recommended Setup by Use Case

**Development/Testing:**
- Named volumes
- Single runner
- 20-30 GB storage

**Production - Single Host:**
- Named volumes
- Monitor storage with `df -h /var/lib/containers`
- Implement cleanup scripts

**Production - Multiple Hosts:**
- NFS or shared storage
- Separate config and work volumes
- Implement cleanup and backup procedures

---

## Environment Variables for Volumes

In `.env` or `docker-compose.yml`:

```bash
# Work directory configuration
RUNNER_WORK_DIR=./_work
RUNNER_WORKDIR=/home/runner/_work

# Volume mount points (for reference)
CONFIG_DIR=./runner-config
WORK_DIR=./runner-work

# Storage limits (optional)
STORAGE_QUOTA=100G
CLEANUP_AGE_DAYS=30
```

---

## See Also

- [ORG-RUNNER-SETUP.md](ORG-RUNNER-SETUP.md) - Organization runner setup
- [STORAGE-SETUP.md](STORAGE-SETUP.md) - Advanced storage configuration
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General troubleshooting

