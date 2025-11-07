# Installation Guide

Complete installation instructions for GitHub Actions runners with Podman.

## System Requirements

### Minimum Requirements
- **OS**: Linux or macOS with Podman/Docker
- **CPU**: 2 cores
- **Memory**: 2GB RAM
- **Storage**: 10GB for base image and work files
- **Network**: Outbound HTTPS access to GitHub

### Recommended for Production
- **CPU**: 4+ cores
- **Memory**: 4GB+ RAM
- **Storage**: 50GB+ for build artifacts and cache
- **Network**: Dedicated network interface

### Supported Operating Systems

| OS | Support | Notes |
|---|---------|-------|
| Ubuntu 22.04 LTS | ✓ | Tested and recommended |
| Ubuntu 20.04 LTS | ✓ | Fully supported |
| Debian 11/12 | ✓ | Podman via backports |
| CentOS/Rocky 8/9 | ✓ | Full support |
| macOS 11+ | ✓ | Using Docker Desktop |
| Windows 10/11 | ✓ | WSL2 + Podman/Docker |
| Fedora 35+ | ✓ | Native support |

## Prerequisites

### 1. Install Podman or Docker

**Ubuntu/Debian:**
```bash
# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install Podman
sudo apt-get install -y podman

# Or install Docker
sudo apt-get install -y docker.io

# Start service
sudo systemctl start podman  # or docker
sudo systemctl enable podman  # or docker

# Verify installation
podman version  # or docker version
```

**macOS (using Docker Desktop):**
```bash
# Install Docker Desktop
# Download from: https://www.docker.com/products/docker-desktop

# Or using Homebrew
brew install docker

# Verify installation
docker version
```

**Windows (WSL2):**
```powershell
# Install WSL2
wsl --install

# Inside WSL2, install Podman or Docker
sudo apt-get install -y podman  # or docker.io

# Verify
podman version
```

### 2. Create GitHub Personal Access Token

1. Go to https://github.com/settings/tokens
2. Click "Generate new token"
3. Select scopes:
   - ✓ `repo` (Full control of private repositories)
   - ✓ `workflow` (Full control of workflows)
4. Click "Generate token"
5. **Copy and save the token** (you'll only see it once!)

### 3. Create GHA User and Configure Permissions

**Create dedicated gha user (for security and isolation):**

```bash
# Create gha user
sudo useradd -m -s /bin/bash -d /home/gha gha

# Add gha user to podman group
sudo usermod -aG podman gha

# Configure rootless podman support
sudo usermod --add-subuids 100000-165535 gha
sudo usermod --add-subgids 100000-165535 gha

# Verify
id gha
cat /etc/subuid | grep gha
```

See [GHA-USER-SETUP.md](GHA-USER-SETUP.md) for comprehensive user configuration guide.

**Create working directory:**

```bash
# If using default location
sudo mkdir -p /opt/github-runner
sudo chown -R $(whoami):$(whoami) /opt/github-runner
```

**Setup 50GB Storage Mount (Recommended):**

If you have 50GB mounted at `/opt/gha`:

```bash
# Verify mount exists
df -h /opt/gha

# Create runner subdirectory
sudo mkdir -p /opt/gha/work
sudo mkdir -p /opt/gha/logs
sudo mkdir -p /opt/gha/cache

# Set ownership to gha user
sudo chown -R gha:gha /opt/gha

# Set appropriate permissions
sudo chmod 755 /opt/gha
sudo chmod 755 /opt/gha/work
sudo chmod 755 /opt/gha/logs

# Verify ownership and permissions
ls -lah /opt/gha
stat /opt/gha | grep "Uid\|Gid"
df -h /opt/gha

# Verify gha user can write
sudo -u gha touch /opt/gha/test.txt && echo "Write test successful" || echo "Permission denied"
```

**Update environment configuration:**

```bash
# Copy environment file
cp config/env.example .env

# Edit to use /opt/gha mount
nano .env

# Set these values:
# RUNNER_WORK_VOLUME=/opt/gha
# RUNNER_WORK_DIR=./_work
```

## Installation Steps

### Step 1: Clone Repository

```bash
# Clone the infrastructure repository
cd ~/Code/infrastructure  # or your workspace

# The project is already in:
# github-actions-runner-podman/

cd github-actions-runner-podman
```

### Step 2: Build Container Image

```bash
# Build the image
podman build -t github-actions-runner:latest .

# Verify image built successfully
podman images | grep github-actions-runner

# Expected output:
# REPOSITORY                        TAG       IMAGE ID      CREATED       SIZE
# localhost/github-actions-runner   latest    abc123...     2 seconds ago  ...
```

### Step 3: Prepare Environment

```bash
# Copy environment template
cp config/env.example .env

# Edit with your values
nano .env  # or use your preferred editor

# Required values to update:
# GITHUB_REPO_URL=https://github.com/YOUR-ORG/YOUR-REPO
# GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Step 4: Deploy Runner

#### Option A: Using Deployment Script

```bash
# Make script executable
chmod +x scripts/deploy-runner.sh

# Deploy with command line arguments
./scripts/deploy-runner.sh \
  --repo https://github.com/YOUR-ORG/YOUR-REPO \
  --token ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \
  --runner-name runner-01 \
  --labels podman,linux,ci

# Verify deployment
podman ps | grep github-runner
```

#### Option B: Using Docker Compose (As GHA User)

```bash
# Switch to gha user
sudo su - gha

# Navigate to project directory
cd /path/to/github-actions-runner-podman

# Make scripts executable
chmod +x scripts/deploy-runner.sh

# Deploy with environment file
docker-compose up -d runner

# Or with multiple runners
docker-compose --profile multi-runner up -d

# Verify
docker-compose ps

# Exit gha user
exit
```

**Alternatively, run as root with sudo:**
```bash
sudo -u gha docker-compose -f /path/to/docker-compose.yml up -d runner
```

#### Option C: Manual Docker/Podman Command

```bash
podman run -d \
  --name github-runner \
  --restart unless-stopped \
  -e GITHUB_REPO_URL=https://github.com/YOUR-ORG/YOUR-REPO \
  -e GITHUB_TOKEN=YOUR_TOKEN \
  -e RUNNER_NAME=runner-01 \
  -e RUNNER_LABELS=podman,linux \
  --volume /run/podman/podman.sock:/var/run/docker.sock \
  github-actions-runner:latest
```

### Step 5: Verify Registration

```bash
# Check container logs
podman logs -f github-runner

# Look for message: "Runner listener started"

# Check on GitHub:
# 1. Go to your repository
# 2. Settings > Actions > Runners
# 3. You should see your runner in the list (may take 30 seconds to appear)
# 4. Status should show "Idle" once running
```

## Systemd Installation (Linux)

For production Linux deployments using systemd:

```bash
# Copy service file
sudo cp config/github-actions-runner.service \
  /etc/systemd/system/

# Edit to set your credentials
sudo nano /etc/systemd/system/github-actions-runner.service

# Set the following environment variables:
# GITHUB_TOKEN=your_token
# GITHUB_REPO_URL=your_repo_url
# RUNNER_NAME=your_runner_name

# Reload systemd
sudo systemctl daemon-reload

# Enable and start service
sudo systemctl enable github-actions-runner
sudo systemctl start github-actions-runner

# Check status
sudo systemctl status github-actions-runner

# View logs
sudo journalctl -u github-actions-runner -f
```

## Post-Installation Configuration

### 1. Verify Runner in GitHub

```bash
# Go to: https://github.com/YOUR-ORG/YOUR-REPO/settings/actions/runners
# 
# Your runner should appear as:
# - Name: (the name you specified)
# - Status: Idle (green dot)
# - OS: Linux
# - Architecture: X64
# - Labels: (labels you specified)
```

### 2. Test with a Workflow

Create `.github/workflows/test.yml`:

```yaml
name: Test Runner
on: [push]

jobs:
  test:
    runs-on: self-hosted
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Test container tools
        run: |
          echo "Testing podman..."
          podman version
          
          echo "Testing docker..."
          docker version
          
          echo "Testing git..."
          git version
          
          echo "All tools working!"
```

Push to trigger the workflow and verify it runs on your runner.

### 3. Monitor and Manage

```bash
# View running containers
podman ps

# View logs
podman logs github-runner

# Stop runner
podman stop github-runner

# Start runner
podman start github-runner

# Remove runner
podman rm -f github-runner
```

## Troubleshooting Installation

### Build Fails

```bash
# Check Docker/Podman is running
systemctl status podman  # or docker

# Try building with more verbosity
podman build --progress=plain -t github-actions-runner:latest .

# Check disk space
df -h /var/lib/containers

# Try with --pull to update base image
podman build --pull -t github-actions-runner:latest .
```

### Runner won't register

1. **Verify token:**
   ```bash
   curl -H "Authorization: token YOUR_TOKEN" \
     https://api.github.com/user
   ```

2. **Check network:**
   ```bash
   podman exec github-runner curl -I https://api.github.com
   ```

3. **View logs:**
   ```bash
   podman logs github-runner
   ```

### Permission errors

```bash
# Verify user can access Docker socket
podman exec github-runner stat /var/run/docker.sock

# May need to add runner user to docker group
# (or use privileged mode in development)
```

## Next Steps

1. **Run your first workflow**
   - Create a test workflow
   - Push to trigger it
   - Verify it runs on your runner

2. **Set up additional runners**
   - For load distribution
   - For different labels/environments

3. **Configure monitoring**
   - Set up logging
   - Monitor resource usage
   - Set up alerts

4. **Review security**
   - Read [SECURITY.md](SECURITY.md)
   - Rotate tokens regularly
   - Use ephemeral mode for untrusted workflows

5. **Optimize for your workflows**
   - Install additional tools if needed
   - Customize base image
   - Configure resource limits

## Getting Help

- Read [QUICK-START.md](QUICK-START.md) for quick reference
- Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
- Review [DEPLOYMENT.md](DEPLOYMENT.md) for advanced setups
- See [../README.md](../README.md) for full documentation

## Uninstallation

To remove the runner:

```bash
# Stop container
podman stop github-runner

# Remove container
podman rm github-runner

# Remove image (optional)
podman rmi github-actions-runner:latest

# Note: Runner will automatically unregister from GitHub
# within 24 hours. To speed up:
# 1. Go to Settings > Actions > Runners > [runner name]
# 2. Click "Remove"
```

## Advanced Topics

- See [DEPLOYMENT.md](DEPLOYMENT.md) for Kubernetes, HA setups
- See [../README.md](../README.md) for advanced configuration
- See [SECURITY.md](SECURITY.md) for hardening and security

