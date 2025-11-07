# Deploying GitHub Actions Runner with Organization Secret

**Date**: November 6, 2025  
**Status**: ✅ Best Practice Guide

This guide shows how to deploy the GitHub Actions self-hosted runner using an organization secret (`GHA_ACCESS_TOKEN`) for secure token management.

---

## ✅ Security Best Practice

Storing the runner token as an **organization secret** (`GHA_ACCESS_TOKEN`) is the recommended approach because:

✅ **Token is not exposed** in .env files or version control  
✅ **Centralized management** - one place for all organization tokens  
✅ **Access control** - can be restricted by team  
✅ **Audit trail** - GitHub logs access to secrets  
✅ **Easy rotation** - update once, affects all runners  
✅ **No local storage** - token only exists in GitHub  

---

## Setup Steps

### Step 1: Create Organization Secret

1. Go to: https://github.com/organizations/infrastructure-alexson/settings/secrets/actions

2. Click **"New organization secret"**

3. Configure:
   - **Name**: `GHA_ACCESS_TOKEN`
   - **Value**: Your runner registration token (from `https://github.com/organizations/infrastructure-alexson/settings/actions/runners`)

4. **Visibility**: Select which repositories have access (or "All repositories")

5. Click **"Add secret"**

---

### Step 2: Create .env for Local Deployment

Create a local `.env` file (never commit this):

```bash
cat > .env <<EOF
GITHUB_REPOSITORY=infrastructure-alexson
RUNNER_TOKEN=<PASTE_YOUR_TOKEN_HERE>
RUNNER_NAME=runner-01
RUNNER_LABELS=podman,linux,amd64,infrastructure
WORK_DIR=/opt/runner-work
CONFIG_DIR=/opt/runner-config
RUNNER_CPUS=2
RUNNER_MEMORY=4G
EOF
```

Or use the example:
```bash
cp config/runner.env.example .env
# Edit .env and fill in values
```

---

### Step 3: Deploy with Docker Compose

```bash
# Load environment from .env
docker-compose up -d

# Or manually set variables
export GITHUB_REPOSITORY="infrastructure-alexson"
export RUNNER_TOKEN="ghs_xxxxx"
export RUNNER_NAME="runner-01"
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs github-runner

# View real-time logs
docker-compose logs -f github-runner
```

---

### Step 4: Verify in GitHub

1. Go to: https://github.com/organizations/infrastructure-alexson/settings/actions/runners

2. Your runner should appear with status **"Idle"** or **"Active"**

3. Verify labels are correct

4. Check "Last Activity" is recent

---

## Using in GitHub Actions Workflows

### Option 1: Use Organization Secret (Recommended)

**In your workflow file** (`.github/workflows/deploy-runner.yml`):

```yaml
name: Deploy Self-Hosted Runner
on:
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Deploy runner
        env:
          RUNNER_TOKEN: ${{ secrets.GHA_ACCESS_TOKEN }}
          GITHUB_REPOSITORY: infrastructure-alexson
          RUNNER_NAME: github-runner-prod
          RUNNER_LABELS: podman,linux,amd64
        run: |
          export RUNNER_TOKEN="${RUNNER_TOKEN}"
          export GITHUB_REPOSITORY="${GITHUB_REPOSITORY}"
          export RUNNER_NAME="${RUNNER_NAME}"
          export RUNNER_LABELS="${RUNNER_LABELS}"
          docker-compose up -d

      - name: Verify runner
        run: |
          docker-compose ps
          docker-compose logs github-runner
```

### Option 2: Run on Self-Hosted (If already deployed)

```yaml
name: Example Workflow
on: push

jobs:
  build:
    runs-on: [self-hosted, podman, linux]  # Runs on your runner!
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: |
          echo "Running on self-hosted runner"
          podman --version
          gh --version
```

---

## Environment Configuration

### Required Variables

```bash
# GitHub organization (for org-level runners)
GITHUB_REPOSITORY=infrastructure-alexson

# Runner token (from GHA_ACCESS_TOKEN secret or direct token)
RUNNER_TOKEN=${{ secrets.GHA_ACCESS_TOKEN }}

# Runner display name
RUNNER_NAME=runner-01

# Labels for workflow targeting
RUNNER_LABELS=podman,linux,amd64
```

### Optional Variables

```bash
# Working directories
WORK_DIR=/opt/runner-work
CONFIG_DIR=/opt/runner-config

# Resource limits
RUNNER_CPUS=2
RUNNER_MEMORY=4G
RUNNER_CPUS_RESERVE=1
RUNNER_MEMORY_RESERVE=2G

# Runner groups (if using runner groups)
RUNNER_GROUPS=default

# Allow root execution
RUNNER_ALLOW_RUNASROOT=true
```

---

## Docker Compose Usage

### Start Runner
```bash
# With environment variables
export RUNNER_TOKEN="${{ secrets.GHA_ACCESS_TOKEN }}"
docker-compose up -d

# With .env file
docker-compose up -d

# With specific configuration
RUNNER_NAME=my-runner RUNNER_LABELS=custom docker-compose up -d
```

### Stop Runner
```bash
docker-compose down
```

### View Logs
```bash
# Current logs
docker-compose logs github-runner

# Follow logs (live)
docker-compose logs -f github-runner

# Last 100 lines
docker-compose logs --tail=100 github-runner
```

### Restart Runner
```bash
docker-compose restart github-runner
```

### Get Status
```bash
docker-compose ps
```

---

## Multiple Runners

### Deploy Multiple Runners

To run multiple runners on the same host:

```bash
# Create multiple services in docker-compose.yml
# Or run separate instances with different names

export RUNNER_NAME="runner-01"
docker-compose -p runner01 up -d

export RUNNER_NAME="runner-02"
docker-compose -p runner02 up -d

export RUNNER_NAME="runner-03"
docker-compose -p runner03 up -d

# Manage separately
docker-compose -p runner01 logs -f
docker-compose -p runner02 ps
docker-compose -p runner03 down
```

### Runner Distribution

Use labels to distribute work:

```yaml
jobs:
  job1:
    runs-on: [self-hosted, runner-01]
    steps:
      - run: echo "Running on runner-01"

  job2:
    runs-on: [self-hosted, runner-02]
    steps:
      - run: echo "Running on runner-02"

  job3:
    runs-on: [self-hosted, runner-03]
    steps:
      - run: echo "Running on runner-03"
```

---

## Troubleshooting

### Issue: Runner Not Connecting

```bash
# Check logs
docker-compose logs github-runner

# Verify environment variables
docker-compose config | grep -A 5 environment

# Ensure token is valid (tokens expire after 1 hour)
# Generate new token if needed
```

### Issue: Runner Appears Offline

```bash
# Check container is running
docker-compose ps

# Restart runner
docker-compose restart github-runner

# Check network connectivity
docker-compose exec github-runner ping github.com

# Check logs for errors
docker-compose logs --tail=50 github-runner
```

### Issue: Workflows Not Running on Runner

```bash
# Verify runner labels match workflow
# Example workflow:
#   runs-on: [self-hosted, podman, linux]

# Check runner has correct labels in GitHub
# Settings → Actions → Runners → Your Runner

# Make sure only one runner per labels
# Multiple runners with same labels = load balancing (good!)
```

---

## Security Considerations

### ✅ Do's
- ✅ Use organization secrets for tokens
- ✅ Rotate tokens regularly
- ✅ Use separate tokens per environment
- ✅ Limit secret access by repository
- ✅ Enable secret scanning
- ✅ Use non-root runners when possible
- ✅ Apply resource limits
- ✅ Monitor runner activity

### ❌ Don'ts
- ❌ Commit .env files with tokens
- ❌ Share tokens in messages/logs
- ❌ Hardcode tokens in workflows
- ❌ Use personal access tokens for runners
- ❌ Allow untrusted code on runners
- ❌ Disable health checks
- ❌ Run without resource limits

---

## Systemd Service Deployment

For persistent deployment, use systemd:

```bash
# Create service file
sudo nano /etc/systemd/system/github-runner-compose.service
```

Content:
```ini
[Unit]
Description=GitHub Actions Self-Hosted Runner (Docker Compose)
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/path/to/github-actions-runner-podman
EnvironmentFile=/path/to/.env
ExecStart=/usr/bin/docker-compose up
ExecStop=/usr/bin/docker-compose down
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable github-runner-compose.service
sudo systemctl start github-runner-compose.service
sudo systemctl status github-runner-compose.service
```

---

## Automated Deployment Workflow

Create a workflow to automatically update runners:

**File**: `.github/workflows/update-runners.yml`

```yaml
name: Update Self-Hosted Runners
on:
  schedule:
    - cron: '0 2 * * 0'  # Weekly at 2 AM UTC
  workflow_dispatch:

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Update runner image
        env:
          RUNNER_TOKEN: ${{ secrets.GHA_ACCESS_TOKEN }}
        run: |
          # Pull latest image
          docker pull docker.io/salexson/github-actions-runner-podman:latest
          
          # Restart runners with new image
          docker-compose down
          docker-compose up -d
          
          # Verify
          docker-compose ps
```

---

## Monitoring & Maintenance

### Monitor Runner Health

```bash
# Check runner status
docker-compose ps

# Monitor resource usage
docker stats

# Check logs for errors
docker-compose logs | grep -i error

# Verify GitHub connectivity
docker-compose exec github-runner ping github.com
```

### Regular Maintenance

```bash
# Weekly: Update image
docker pull docker.io/salexson/github-actions-runner-podman:latest

# Monthly: Restart runners
docker-compose restart github-runner

# Quarterly: Rotate tokens
# Update GHA_ACCESS_TOKEN organization secret
# Recreate runners with new token

# As needed: Clean up old images
docker image prune -a
```

---

## Reference

### Useful Commands

```bash
# Deploy
docker-compose up -d

# Stop
docker-compose down

# View logs
docker-compose logs -f

# Check status
docker-compose ps

# Restart
docker-compose restart

# Update configuration
docker-compose config

# Execute command in container
docker-compose exec github-runner bash
```

### Environment Variables Summary

| Variable | Required | Default | Purpose |
|----------|----------|---------|---------|
| `GITHUB_REPOSITORY` | Yes | - | GitHub org or repo |
| `RUNNER_TOKEN` | Yes | - | Registration token |
| `RUNNER_NAME` | No | hostname | Display name |
| `RUNNER_LABELS` | No | linux | Runner labels |
| `WORK_DIR` | No | ./runner-work | Work directory |
| `CONFIG_DIR` | No | ./runner-config | Config directory |
| `RUNNER_CPUS` | No | 2 | CPU limit |
| `RUNNER_MEMORY` | No | 4G | Memory limit |

---

## Related Documentation

- [README.md](../README.md) - Project overview
- [INSTALLATION.md](INSTALLATION.md) - Installation guide
- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment options
- [SECURITY.md](SECURITY.md) - Security best practices
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Troubleshooting guide

---

**Status**: ✅ Production Ready  
**Last Updated**: 2025-11-06  
**Version**: 1.0.0

