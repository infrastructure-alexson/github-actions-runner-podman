# Quick Start Guide

Get your GitHub Actions runner up and running in minutes!

## Prerequisites

- Docker or Podman installed
- GitHub personal access token with `repo` and `workflow` scopes
- Linux or macOS (Windows with WSL2)

## Step 1: Generate GitHub Token

1. Go to [GitHub Personal Access Tokens](https://github.com/settings/tokens)
2. Click "Generate new token"
3. Select scopes:
   - ✓ `repo` (Full control)
   - ✓ `workflow`
4. Click "Generate token"
5. **Copy the token** (you'll only see it once!)

## Step 2: Clone and Build

```bash
cd github-actions-runner-podman

# Build the image
podman build -t github-actions-runner:latest .
```

## Step 3: Deploy Runner

### Option A: Single Repository

```bash
./scripts/deploy-runner.sh \
  --repo https://github.com/YOUR-ORG/YOUR-REPO \
  --token ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \
  --runner-name my-runner-01
```

### Option B: Organization Level

```bash
./scripts/deploy-runner.sh \
  --org YOUR-ORG \
  --token ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \
  --runner-name my-runner-01
```

## Step 4: Verify Deployment

```bash
# Check container status
podman ps | grep github-runner

# View logs
podman logs -f github-runner

# Check GitHub - go to Settings > Actions > Runners
# You should see your new runner listed as "idle"
```

## Step 5: Run Your First Workflow

Create `.github/workflows/test.yml`:

```yaml
name: Test Runner

on: [push]

jobs:
  test:
    runs-on: [self-hosted, my-runner-01]
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Run test
        run: |
          echo "Hello from GitHub Actions Runner!"
          docker version
          podman version
```

## Using Docker Compose

### 1. Setup Environment

```bash
# Copy and edit environment file
cp config/env.example .env

# Edit .env with your values
nano .env
```

### 2. Deploy

```bash
# Single runner
docker-compose up -d runner

# Multiple runners
docker-compose --profile multi-runner up -d
```

### 3. Monitor

```bash
# View logs
docker-compose logs -f runner

# Check status
docker-compose ps
```

## Common Tasks

### Stop Runner

```bash
podman stop github-runner
```

### View Logs

```bash
podman logs -f github-runner
```

### Remove Runner

```bash
# Stop container
podman stop github-runner
podman rm github-runner

# Unregister from GitHub (automatic on cleanup)
# Check Settings > Actions > Runners to confirm removal
```

### Add Custom Labels

```bash
./scripts/deploy-runner.sh \
  --repo https://github.com/YOUR-ORG/YOUR-REPO \
  --token YOUR_TOKEN \
  --labels "podman,linux,ci,deployment"
```

Then in your workflow:
```yaml
runs-on: [self-hosted, deployment]
```

### Enable Ephemeral Mode

```bash
./scripts/deploy-runner.sh \
  --repo https://github.com/YOUR-ORG/YOUR-REPO \
  --token YOUR_TOKEN \
  --ephemeral
```

## Troubleshooting

### Runner not showing up in GitHub

1. Check logs: `podman logs github-runner`
2. Verify token is correct and has right scopes
3. Verify repository URL is correct
4. Check network connectivity to github.com

### Container fails to start

1. Check disk space: `df -h`
2. Check logs: `podman logs github-runner`
3. Verify environment variables: `podman inspect github-runner`
4. Try rebuilding image: `podman build -t github-actions-runner:latest .`

### Out of memory

1. Check current usage: `podman stats github-runner`
2. Increase memory limit in environment or deployment script
3. Check for stuck processes in workflows

### Permission denied errors

1. Verify runner user has proper permissions
2. Check volume mount permissions
3. Try with `--privileged` flag (development only)

## Next Steps

- Read [DEPLOYMENT.md](DEPLOYMENT.md) for production deployment
- Read [SECURITY.md](SECURITY.md) for hardening options
- Read [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for advanced issues
- Check [../README.md](../README.md) for full documentation

## Getting Help

1. Check logs: `podman logs -f github-runner`
2. Review troubleshooting guide: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
3. Check GitHub Actions runner docs: https://docs.github.com/en/actions/hosting-your-own-runners

