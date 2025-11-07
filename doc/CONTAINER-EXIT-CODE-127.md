# Container Exit Code 127 - Complete Troubleshooting Guide

**Date**: 2025-11-06  
**Issue**: Container exits with code 127 after creation  
**Status**: Exited (127) 1 second ago (starting)  
**Meaning**: Command not found or missing dependency

---

## Problem

Container creates successfully but exits immediately:

```
CONTAINER ID  IMAGE                                      CREATED        STATUS
663d8e0c9d71  docker.io/salexson/github-action-runner    9 seconds ago  Exited (127)
```

Exit code 127 means: **"Command not found"**

---

## Root Causes

Exit code 127 can be caused by:

1. **Missing environment variables** (most likely)
   - `GITHUB_REPOSITORY` or `GITHUB_ORG` not set
   - `RUNNER_TOKEN` not set
   - Entrypoint script validation fails

2. **Missing shell or executable**
   - `/bin/bash` not in container
   - `/bin/sh` not available
   - Entrypoint script not found

3. **Missing dependencies**
   - .NET Core runtime missing
   - Required library not installed
   - Permissions issue on executable

4. **PATH issues**
   - Runner binary not in expected location
   - Config.sh not executable
   - Working directory not set

---

## Step 1: Check Container Logs

**Most Important Step!**

```bash
# View container logs
podman logs github-runner

# Follow logs in real-time (if container is running)
podman logs -f github-runner

# View recent logs
podman logs --tail 50 github-runner

# View with timestamps
podman logs --timestamps github-runner
```

**What to look for**:
- Error messages about missing variables
- "command not found" errors
- Path-related issues
- Permission denied errors

---

## Step 2: Check Container Details

```bash
# Get container details
podman inspect github-runner

# Focus on entrypoint
podman inspect github-runner | grep -i entrypoint

# Check working directory
podman inspect github-runner | grep -i workdir

# Check environment variables
podman inspect github-runner | grep -i env
```

---

## Step 3: Set Required Environment Variables

The entrypoint script requires:

```bash
# Required: Either GITHUB_REPOSITORY or GITHUB_ORG
export GITHUB_REPOSITORY=owner/repo
# OR
export GITHUB_ORG=my-org

# Required: GitHub personal access token
export RUNNER_TOKEN=ghs_xxxx
```

**Update docker-compose.yml or use .env file:**

**Option A: Create `.env` file** (recommended)

Create file: `/opt/gha/.env`

```bash
# GitHub Configuration (Required)
GITHUB_REPOSITORY=owner/repo
RUNNER_TOKEN=ghs_xxxx

# Runner Configuration (Optional)
RUNNER_NAME=runner-01
RUNNER_LABELS=podman,linux,docker,x86_64
RUNNER_EPHEMERAL=false

# Resource Limits
RUNNER_CPUS=2
RUNNER_MEMORY=4G
```

Then run:
```bash
cd /opt/gha
docker-compose up -d
```

**Option B: Export and run**

```bash
export GITHUB_REPOSITORY=owner/repo
export RUNNER_TOKEN=ghs_xxxx
export RUNNER_NAME=runner-01

docker-compose up -d
```

**Option C: Run with inline environment**

```bash
GITHUB_REPOSITORY=owner/repo RUNNER_TOKEN=ghs_xxxx docker-compose up -d
```

---

## Step 4: Remove Failed Container and Try Again

```bash
# Stop the container
docker-compose down

# Or manually
podman stop github-runner
podman rm github-runner

# Verify it's removed
podman ps -a | grep github-runner
# Should show no results

# Try again with proper environment
export GITHUB_REPOSITORY=owner/repo
export RUNNER_TOKEN=ghs_xxxx
docker-compose up -d

# Check status
podman ps
# Should show container RUNNING (not Exited)

# Check logs
podman logs github-runner
```

---

## Step 5: Verify Container is Running

Once started with proper environment:

```bash
# Check status
podman ps
# STATUS should show: Up X seconds (healthy) or Up X seconds

# NOT: Exited (127)
```

If still shows Exited:
```bash
# Get last 20 lines of logs
podman logs --tail 20 github-runner

# Look for error messages
```

---

## Why This Happens

### Entrypoint Script Flow

```bash
1. Start entrypoint.sh
   ↓
2. Validate environment variables
   - Check GITHUB_REPOSITORY or GITHUB_ORG → MISSING!
   - Check RUNNER_TOKEN → MISSING!
   ↓
3. Exit with error (exit code 1)
   ↓
4. But docker sees exit code 127 (because bash can't run config.sh)
```

### Your Situation

Looking at your docker-compose output:

```
-e GITHUB_REPOSITORY= -e RUNNER_TOKEN=
```

Both are **empty**! The entrypoint script cannot proceed.

---

## Complete Fix Process

### **For Your Setup (gha user, UID 984)**

**1. Stop existing container:**

```bash
docker-compose down
```

**2. Create .env file in `/opt/gha/.env`:**

```bash
# Required
GITHUB_REPOSITORY=owner/repo
RUNNER_TOKEN=ghs_xxxx

# Runner config
RUNNER_NAME=runner-01
RUNNER_LABELS=podman,linux,docker,x86_64
RUNNER_EPHEMERAL=false
RUNNER_REPLACE=true

# Optional
RUNNER_WORKDIR=/home/runner/_work
RUNNER_GROUPS=default
```

**3. Update shell environment:**

```bash
# Add to ~/.bashrc
cat >> ~/.bashrc <<'EOF'
# Docker-Compose environment
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"
EOF

source ~/.bashrc
```

**4. Verify socket is running:**

```bash
systemctl --user status podman.socket
# Should show: active (running)

# If not:
systemctl --user start podman.socket
```

**5. Start container with environment:**

```bash
# From /opt/gha directory
cd /opt/gha

# Load .env and start
set -a
source .env
set +a
docker-compose up -d
```

Or simpler:

```bash
export GITHUB_REPOSITORY=owner/repo
export RUNNER_TOKEN=ghs_xxxx
export RUNNER_NAME=runner-01

docker-compose up -d
```

**6. Check status:**

```bash
# Container should be running
podman ps
# STATUS: Up X seconds (healthy)

# Check logs
podman logs github-runner
# Should show: GitHub Actions Runner Entrypoint and configuration messages
```

---

## Example .env File

**Create `/opt/gha/.env`:**

```bash
# ==============================================================================
# GitHub Actions Runner Configuration
# ==============================================================================

# GitHub Configuration (REQUIRED - change these!)
GITHUB_REPOSITORY=my-org/my-repo
# OR for organization runners:
# GITHUB_ORG=my-org

# GitHub Personal Access Token (REQUIRED - change this!)
# Generate at: https://github.com/settings/tokens
# Permissions: repo (full), workflow, admin:repo_hook
RUNNER_TOKEN=ghs_xxxx_your_token_here

# ==============================================================================
# Runner Configuration (Optional)
# ==============================================================================

# Runner display name
RUNNER_NAME=runner-01

# Comma-separated labels for the runner
RUNNER_LABELS=podman,linux,docker,x86_64

# Runner working directory
RUNNER_WORKDIR=/home/runner/_work

# Runner groups (for Enterprise)
RUNNER_GROUPS=default

# Ephemeral mode (auto-cleanup after each job)
RUNNER_EPHEMERAL=false

# Replace existing runner config
RUNNER_REPLACE=true

# Allow running as root
RUNNER_ALLOW_RUNASROOT=true

# ==============================================================================
# Resource Configuration
# ==============================================================================

# CPU limits (cores)
RUNNER_CPUS=2

# Memory limits
RUNNER_MEMORY=4G

# Memory reservation
RUNNER_MEMORY_RESERVE=2G

# ==============================================================================
# Directories
# ==============================================================================

WORK_DIR=./runner-work
CONFIG_DIR=./runner-config
CACHE_DIR=./runner-cache
```

---

## Testing Environment Variables

Before running docker-compose:

```bash
# Verify variables are set
echo "GITHUB_REPOSITORY=$GITHUB_REPOSITORY"
echo "RUNNER_TOKEN=$RUNNER_TOKEN"
echo "RUNNER_NAME=$RUNNER_NAME"

# All should have values, not be empty
```

If empty, they're not exported. Fix with:

```bash
export GITHUB_REPOSITORY=owner/repo
export RUNNER_TOKEN=ghs_xxxx
echo $GITHUB_REPOSITORY  # Should show value now
```

---

## Exit Code Reference

| Code | Meaning | Common Cause |
|------|---------|------------|
| 0 | Success | Container running fine |
| 1 | General error | Script error, validation failed |
| 127 | Command not found | Missing executable or script |
| 128 | Invalid argument | Invalid signal or argument |
| 255 | Exit status out of range | Unhandled error |

Exit code 127 specifically means the shell couldn't find the command to execute.

---

## Debugging Inside Container

If you want to inspect the container:

```bash
# Run container with interactive shell
podman run -it docker.io/salexson/github-action-runner:latest /bin/bash

# Check what's in /opt/runner
ls -la /opt/runner/

# Check if config.sh exists
ls -la /opt/runner/config.sh

# Check if .NET is installed
which dotnet
dotnet --version

# Check bash
which bash
```

---

## If You Need to Create GitHub Token

1. Go to: https://github.com/settings/tokens
2. Click "Generate new token"
3. Select **Classic** (not Fine-grained)
4. Scopes needed:
   - ✅ `repo` (full)
   - ✅ `workflow`
   - ✅ `admin:repo_hook` (if organization)
5. Copy the token (shown only once!)
6. Set: `export RUNNER_TOKEN=ghp_...`

---

## Common Scenarios

### Scenario 1: Container Exits, No Logs

```bash
# Check if entrypoint script exists
podman inspect github-runner | grep -A5 '"Cmd"'

# Run manually to see what happens
podman run -it --rm \
  -e GITHUB_REPOSITORY=test/test \
  -e RUNNER_TOKEN=test \
  docker.io/salexson/github-action-runner:latest
```

### Scenario 2: Permission Denied on config.sh

```bash
# Check permissions in container
podman exec github-runner ls -la /opt/runner/config.sh

# Should show: -rwxr-xr-x (executable)
```

### Scenario 3: .NET Runtime Error

```bash
# Check .NET
podman exec github-runner dotnet --version

# If fails, check .NET installation
podman exec github-runner find / -name "dotnet" 2>/dev/null
```

---

## Successful Startup Output

When working correctly, logs should show:

```
[INFO] GitHub Actions Runner Entrypoint
[INFO] Runner Home: /home/runner
[INFO] Runner Directory: /opt/runner
[INFO] Validating environment...
[INFO] Environment validation passed
[INFO] Registering runner with GitHub...
[INFO] Runner registered successfully
[INFO] Starting GitHub Actions Runner listener...
```

---

## Next Steps

1. **Set GITHUB_REPOSITORY and RUNNER_TOKEN** (required!)
2. **Create .env file** or export environment variables
3. **Stop current container**: `docker-compose down`
4. **Start with environment**: `docker-compose up -d`
5. **Check logs**: `podman logs github-runner`
6. **Verify running**: `podman ps` (should show Up, not Exited)

---

## References

- [GitHub Actions Runner Setup](https://github.com/actions/runner)
- [Docker Environment Variables](https://docs.docker.com/compose/environment-variables/)
- [Podman Environment](https://docs.podman.io/en/latest/markdown/podman-run.1.html#environment)

---

## Related Documentation

- [QUICK-FIX-PODMAN-STARTUP.md](QUICK-FIX-PODMAN-STARTUP.md) - Podman startup
- [DBUS-SYSTEMD-SESSION-FIX.md](DBUS-SYSTEMD-SESSION-FIX.md) - D-Bus session
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General troubleshooting

---

**Last Updated**: 2025-11-06  
**Status**: ✅ Container Exit Code 127 Fix Guide  
**Key Issue**: Missing required environment variables

