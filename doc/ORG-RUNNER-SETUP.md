# Organization Runner Setup Guide

**Date**: 2025-11-06  
**Type**: Organization Runner (not repository-specific)  
**Runner Scope**: Available to all repositories in the organization  
**Status**: ✅ Setup Guide

---

## What's Different: Org Runner vs Repo Runner

### Repository Runner
- Specific to one repository
- Uses: `GITHUB_REPOSITORY=owner/repo`
- Access: Only that repo's workflows
- Token scope: Repository-level

### Organization Runner
- Available to **all repos** in organization
- Uses: `GITHUB_ORG=my-org`
- Access: All repos (if they're configured to use it)
- Token scope: Organization-level
- Requires: `admin:org_self_hosted_runners` permission

---

## Quick Setup for Org Runner

### **Step 1**: Generate Organization Registration Token

⚠️ **IMPORTANT**: You need a **REGISTRATION TOKEN**, not a PAT!

1. Go to: https://github.com/organizations/YOUR_ORG/settings/actions/runners/new
2. Select: **Linux** (for Rocky Linux)
3. GitHub shows a **Registration Token** (NOT a ghp_ token)
   - Example: `AICVO4YB3NFC6XFZNENMBV3JBVF34`
   - ⚠️ **Expires in 1 hour!**
4. **Copy immediately** (you must use it within 1 hour!)

**Note**: This is different from a Personal Access Token (PAT). The registration token is specifically for registering runners.

### **Step 2**: Set Environment Variables for Org Runner

```bash
# For organization runner (NOT repository)
export GITHUB_ORG=infrastructure-alexson

# Registration token (from Step 1, NOT a ghp_ token)
# Example: AICVO4YB3NFC6XFZNENMBV3JBVF34
export GITHUB_TOKEN=AICVO4YB3NFC6XFZNENMBV3JBVF34

# Runner configuration
export RUNNER_NAME=runner-01
export RUNNER_LABELS=podman,linux,docker,x86_64
```

⚠️ **Hurry!** You have **1 hour** to deploy the runner with this token before it expires!

### **Step 3**: Verify Variables

```bash
# Check they're set
echo "GITHUB_ORG=$GITHUB_ORG"
echo "GITHUB_TOKEN=$GITHUB_TOKEN"
echo "RUNNER_NAME=$RUNNER_NAME"

# Both should have values, NOT be empty
```

### **Step 4**: Start Container

```bash
cd /opt/gha

# Stop any existing container
docker-compose down

# Start with environment variables
docker-compose up -d

# Check logs
podman logs github-runner

# Verify running
podman ps
# STATUS should show: Up X seconds (healthy)
```

---

## .env File for Org Runner

**File**: `/opt/gha/.env`

```bash
# ==============================================================================
# GitHub Actions Organization Runner Configuration
# ==============================================================================

# Organization Runner Setup (NOT repo runner)
GITHUB_ORG=my-org

# Organization-level REGISTRATION TOKEN (NOT a PAT!)
# Generate at: https://github.com/organizations/YOUR_ORG/settings/actions/runners/new
# ⚠️ EXPIRES IN 1 HOUR - Must be used immediately!
# Example: AICVO4YB3NFC6XFZNENMBV3JBVF34
GITHUB_TOKEN=AICVO4YB3NFC6XFZNENMBV3JBVF34

# ==============================================================================
# Runner Configuration
# ==============================================================================

# Runner display name
RUNNER_NAME=runner-01

# Labels for this runner (comma-separated)
RUNNER_LABELS=podman,linux,docker,x86_64

# Runner working directory
RUNNER_WORKDIR=/home/runner/_work

# Runner groups (for Enterprise - usually "default")
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

RUNNER_CPUS=2
RUNNER_MEMORY=4G
RUNNER_MEMORY_RESERVE=2G

# ==============================================================================
# Directories
# ==============================================================================

WORK_DIR=./runner-work
CONFIG_DIR=./runner-config
CACHE_DIR=./runner-cache
```

---

## Complete Org Runner Setup Process

### For Your Setup (gha user, UID 984)

```bash
# 1. Generate token at https://github.com/settings/tokens
#    Scopes: admin:org_self_hosted_runners, repo, workflow

# 2. Get registration token from GitHub (expires in 1 hour!)
# Go to: https://github.com/organizations/YOUR_ORG/settings/actions/runners/new
# Copy the token shown

# 3. Set environment
export GITHUB_ORG=infrastructure-alexson
export GITHUB_TOKEN=AICVO4YB3NFC6XFZNENMBV3JBVF34
export RUNNER_NAME=runner-01
export RUNNER_LABELS=podman,linux,docker,x86_64

# 3. Verify socket is running
systemctl --user status podman.socket
# If not running:
systemctl --user start podman.socket

# 4. Verify Docker host
export DOCKER_HOST=unix:///run/user/984/podman/podman.sock

# 5. Navigate to project
cd /opt/gha

# 6. Stop any existing container
docker-compose down

# 7. Start new container
docker-compose up -d

# 8. Watch logs
podman logs -f github-runner

# 9. Verify running
podman ps

# 10. Once running, check GitHub web interface
#     Organization > Settings > Actions > Runners
#     Should see your runner in the list
```

---

## Verifying Org Runner Registration

### In GitHub Web Interface

1. Go to: https://github.com/organizations/YOUR-ORG/settings/actions/runners
2. You should see your runner:
   ```
   runner-01  (Idle)
   Online  •  Podman  •  podman,linux,docker,x86_64
   ```

### In Container Logs

```bash
podman logs github-runner

# Look for:
[INFO] GitHub Actions Runner Entrypoint
[INFO] Validating environment...
[INFO] Environment validation passed
[INFO] Registering runner with GitHub...
[INFO] Runner registered successfully
[INFO] Starting GitHub Actions Runner listener...
```

### Via podman ps

```bash
podman ps

# Should show:
CONTAINER ID  IMAGE                                    STATUS
abc123def     docker.io/salexson/github-action-runner  Up 2 minutes (healthy)
```

---

## Using Your Org Runner in Workflows

Once registered, use in GitHub Actions workflows:

```yaml
name: Test Org Runner

on: [push]

jobs:
  test:
    runs-on: [self-hosted, podman, linux]
    steps:
      - uses: actions/checkout@v3
      - name: Run test
        run: echo "Running on org runner!"
```

**Runner selector options**:
- `self-hosted` - Any self-hosted runner
- `podman` - This runner's label
- `linux` - This runner's label
- `docker,x86_64` - Additional labels
- `runner-01` - Specific runner name (if you set it)

---

## Token Scopes Explained

### For Organization Runners

| Scope | Required | Purpose |
|-------|----------|---------|
| `admin:org_self_hosted_runners` | ✅ YES | Register/manage org runners |
| `repo` | ✅ YES | Access repos for workflows |
| `workflow` | ✅ YES | Run workflows |
| `read:org` | ⚠️ Optional | Read org info |
| `admin:repo_hook` | ⚠️ Optional | Webhooks (if needed) |

---

## Troubleshooting Org Runner

### Issue: Token rejected / 404 error

```bash
# Check token has correct scopes
# Regenerate with admin:org_self_hosted_runners scope

# Verify token is set
echo $GITHUB_TOKEN | head -c 20
# Should show: ghp_xxxxxxxx
```

### Issue: Runner shows "offline"

```bash
# Check container is running
podman ps
# STATUS should show: Up X seconds (healthy)

# Check logs
podman logs github-runner

# Restart if needed
docker-compose down
docker-compose up -d
```

### Issue: Runner doesn't appear in GitHub

```bash
# Wait 30 seconds (sometimes takes time)
# Then refresh the page

# Or check logs
podman logs github-runner | grep -i "register"
```

---

## Docker-Compose Configuration for Org Runner

The `docker-compose.yml` automatically supports both:

```yaml
environment:
  # Repository runner (if set)
  GITHUB_REPOSITORY: ${GITHUB_REPOSITORY}
  
  # Organization runner (if GITHUB_REPOSITORY not set)
  GITHUB_ORG: ${GITHUB_ORG}
  
  GITHUB_TOKEN: ${GITHUB_TOKEN}
```

The entrypoint script checks for either one (in that order).

---

## Environment Variables Summary

### Required for Org Runner

```bash
# One of these (use GITHUB_ORG for org runner):
export GITHUB_ORG=my-org

# Your organization token:
export GITHUB_TOKEN=ghp_xxxx
```

### Optional but Recommended

```bash
export RUNNER_NAME=runner-01
export RUNNER_LABELS=podman,linux,docker,x86_64
export RUNNER_EPHEMERAL=false
export RUNNER_REPLACE=true
```

---

## Comparison: Repo Runner vs Org Runner

| Feature | Repo Runner | Org Runner |
|---------|------------|-----------|
| **Scope** | Single repo | All org repos |
| **Variable** | `GITHUB_REPOSITORY` | `GITHUB_ORG` |
| **Token Type** | Repo token | Org token |
| **Setup** | Simpler | Requires org scope |
| **Use Case** | Dedicated to one project | Shared infrastructure |
| **Cost** | Single project | Multiple projects |

---

## For Multiple Org Runners

If you want multiple runners for the organization:

```bash
# Runner 1
export RUNNER_NAME=runner-01
docker-compose -f docker-compose.yml -p runner01 up -d

# Runner 2 (different project name)
export RUNNER_NAME=runner-02
docker-compose -f docker-compose.yml -p runner02 up -d

# Both register to same org
```

---

## Complete Startup Checklist

- [ ] Generated organization token with `admin:org_self_hosted_runners` scope
- [ ] Set `GITHUB_ORG` environment variable
- [ ] Set `GITHUB_TOKEN` environment variable
- [ ] Set `RUNNER_NAME` environment variable
- [ ] Podman socket running: `systemctl --user status podman.socket`
- [ ] `DOCKER_HOST` set to user socket
- [ ] Removed any previous containers: `docker-compose down`
- [ ] Started new container: `docker-compose up -d`
- [ ] Container is running: `podman ps` shows "Up"
- [ ] Logs show "Runner registered successfully"
- [ ] Runner appears in GitHub: `https://github.com/organizations/YOUR-ORG/settings/actions/runners`

---

## Next Steps

1. **Generate organization token** at https://github.com/settings/tokens
2. **Create .env file** in `/opt/gha/.env` with `GITHUB_ORG` and `GITHUB_TOKEN`
3. **Start container** with `docker-compose up -d`
4. **Verify in GitHub** at organization runners page
5. **Use in workflows** by selecting `self-hosted` runner

---

## Related Documentation

- [CONTAINER-EXIT-CODE-127.md](CONTAINER-EXIT-CODE-127.md) - Container startup
- [QUICK-FIX-PODMAN-STARTUP.md](QUICK-FIX-PODMAN-STARTUP.md) - Podman startup
- [DBUS-SYSTEMD-SESSION-FIX.md](DBUS-SYSTEMD-SESSION-FIX.md) - D-Bus session
- [DOCKER-REGISTRY-AUTHENTICATION.md](DOCKER-REGISTRY-AUTHENTICATION.md) - Registry auth

---

## ✅ **SUCCESS: Organization Runner Deployed**

Once your runner is registered and running:

1. ✅ Runner appears in GitHub UI at `https://github.com/organizations/YOUR_ORG/settings/actions/runners`
2. ✅ Status shows "Idle" or "Running a job"
3. ✅ Ready to receive and execute workflow jobs

---

**Type**: Organization Runner  
**Status**: ✅ Production Ready  
**Next**: Create test workflows to verify runner functionality

