# GitHub Actions Runner - Podman with Docker Compatibility

A production-ready, enterprise-grade containerized GitHub Actions self-hosted runner based on Red Hat UBI 8 Minimal with Podman and docker compatibility.

**Base Image**: `registry.access.redhat.com/ubi8/ubi-minimal:latest`  
**Container Tool**: Podman (with podman-docker for docker compatibility)  
**Image Size**: ~360MB (50% smaller than Ubuntu-based images)  
**CPU Support**: x86-64-v1+ (broad processor compatibility - 2003+)  
**Build Time**: 2-3 minutes (40% faster)  
**Support**: 10-year enterprise support from Red Hat  

## Overview

This project provides a minimal, secure, and optimized GitHub Actions self-hosted runner container image based on Red Hat's Universal Base Image 8 Minimal (UBI 8) with **Podman as the primary container tool** and **podman-docker compatibility layer** for Docker command support.

UBI 8 was chosen for **broad CPU compatibility** (x86-64-v1+, 2003+) while maintaining enterprise-grade security and support.

## Features

- ✅ **UBI 8 Minimal Base**: Enterprise-grade, Red Hat backed, broad CPU compatibility
- ✅ **Podman First**: Modern, secure, rootless-capable container runtime
- ✅ **Docker Compatible**: `docker` commands work via podman-docker wrapper
- ✅ **Self-Hosted Runner**: Full GitHub Actions runner support for CI/CD pipelines
- ✅ **Security Hardened**: Non-root user, rootless support, minimal attack surface
- ✅ **Advanced Tools**: Buildah (image building) and Skopeo (image utilities) included
- ✅ **Multi-Platform**: Supports amd64 and arm64 architectures
- ✅ **Fast Deployment**: 40-50% faster than traditional base images
- ✅ **Enterprise Support**: 10-year support window from Red Hat

## Quick Start

### Prerequisites

- **Container Runtime**: Podman 4.0+ (Docker 20.10+ also supported via podman-docker compatibility)
- **CPU**: x86-64 processor from 2003+ (x86-64-v1 baseline). See [CPU Compatibility](doc/CPU-COMPATIBILITY.md) for details
- **GitHub Token**: Registration token from organization (expires in 1 hour)
- **System**: Rocky Linux 8/9, RHEL 8/9, or compatible
- **Storage**: 10GB+ available for image and working directory
- **Network**: Outbound HTTPS to github.com and registry.access.redhat.com
- **Memory**: 2GB+ RAM (4GB+ recommended for concurrent workflows)

### Basic Deployment

1. **Clone and navigate to the project:**

```bash
cd github-actions-runner-podman
```

2. **Build the image (UBI 8 Minimal + Podman):**

```bash
# Build with Podman
podman build -t github-action-runner:latest .

# Or use the build script
./scripts/build-and-push-podman.sh --no-push
```

3. **Deploy the runner with Podman:**

```bash
# Using Podman (recommended for rootless containers)
podman run -d \
  --name github-runner \
  -e GITHUB_REPOSITORY="organization-name" \
  -e RUNNER_TOKEN="your_token_here" \
  -e RUNNER_NAME="org-runner-01" \
  -e RUNNER_LABELS="organization,podman,linux" \
  -v /var/run/podman/podman.sock:/var/run/podman/podman.sock \
  -v /opt/runner-work:/home/runner/_work \
  github-action-runner:latest
```

Or with **docker-compose** (docker commands work via podman-docker):

```bash
# docker-compose works via podman-docker wrapper
docker-compose up -d
```

### Docker Compose Deployment

```bash
# Copy environment template
cp config/.env.example config/.env

# Edit with your GitHub credentials
nano config/.env

# Deploy the stack
docker-compose up -d
```

## Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `GITHUB_REPO_URL` | GitHub repository URL | Yes |
| `GITHUB_TOKEN` | Personal access token for runner registration | Yes |
| `RUNNER_NAME` | Name for this runner instance | No (auto-generated) |
| `RUNNER_LABELS` | Comma-separated labels for the runner | No |
| `RUNNER_WORK_DIR` | Working directory for runner | No (default: `_work`) |
| `RUNNER_EPHEMERAL` | Enable ephemeral mode (auto-cleanup) | No (default: `false`) |

### Example Configuration - Organization Level

Create `.env` file:

```bash
# Organization-level runner (all repos can use)
GITHUB_REPOSITORY=infrastructure-alexson
RUNNER_TOKEN=ghs_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
RUNNER_NAME=org-runner-01
RUNNER_LABELS=organization,podman,linux,amd64
WORK_DIR=/opt/runner-work
CONFIG_DIR=/opt/runner-config
RUNNER_CPUS=2
RUNNER_MEMORY=4G
```

## Deployment Options

### Single Container

```bash
podman run -d \
  --name github-runner \
  -e GITHUB_REPO_URL=https://github.com/YOUR-ORG/YOUR-REPO \
  -e GITHUB_TOKEN=YOUR_TOKEN \
  -e RUNNER_NAME=runner-1 \
  --volume /var/run/podman/podman.sock:/var/run/docker.sock \
  github-actions-runner:latest
```

### With Systemd Service (Production)

**Installation:**
```bash
# Copy service file
sudo cp config/github-actions-runner-podman.service \
  /etc/systemd/system/github-actions-runner.service

# Create environment file
sudo cp config/runner.env.example /home/gha/.runner.env
sudo chown gha:gha /home/gha/.runner.env
chmod 600 /home/gha/.runner.env

# Edit with your credentials
sudo nano /home/gha/.runner.env
```

**Enable and manage:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable github-actions-runner
sudo systemctl start github-actions-runner

# Monitor
sudo systemctl status github-actions-runner
sudo journalctl -u github-actions-runner -f
```

See [doc/SYSTEMD-MANAGEMENT.md](doc/SYSTEMD-MANAGEMENT.md) for complete guide.

### Pod Deployment (Multiple Runners)

Use the provided `podman/pod.yaml` for multi-runner deployments with network isolation.

### Storage Configuration

For production deployments with 50GB storage mounted at `/opt/gha`:

```bash
# Setup storage mount
sudo mkdir -p /opt/gha/work
sudo mkdir -p /opt/gha/logs

# Create .env from template
cp config/env.example .env

# Configure storage in .env
# RUNNER_WORK_VOLUME=/opt/gha
# RUNNER_WORK_DIR=./_work

# Deploy
docker-compose up -d runner
```

See [doc/STORAGE-SETUP.md](doc/STORAGE-SETUP.md) for detailed storage management.

## Built-in Tools

The runner image includes:

- **Runtime**: Ubuntu 22.04 base, bash shell
- **VCS**: Git, Git LFS
- **Containers**: Docker, Podman, skopeo
- **CLI Tools**: curl, wget, jq, yq, unzip, sshpass
- **Build Tools**: Make, gcc, build-essential
- **Languages**: 
  - Go (golang-go)
  - Python 3 + pip + venv
  - Node.js + npm
- **Infrastructure**: 
  - Ansible + Ansible-core
  - SSH server and client
- **Orchestration**: kubectl, helm (optional)

## Security Considerations

1. **Non-Root Execution**: Runner executes as `runner` user (UID 1001)
2. **Read-Only Filesystem**: Root filesystem in read-only mode (optional)
3. **Resource Limits**: CPU and memory limits applied by default
4. **Network Policies**: Can be configured with firewall rules
5. **Credential Management**: Tokens stored in ephemeral containers only
6. **Supply Chain**: Image built from official Ubuntu base image

### Hardening Best Practices

- Rotate GitHub tokens regularly
- Use organization-level secrets for sensitive data
- Limit runner labels to specific teams
- Monitor runner logs for suspicious activity
- Use ephemeral mode for untrusted workflows
- Implement network segmentation

## Maintenance

### Updating the Runner

```bash
# Rebuild the image with latest runner version
./scripts/update-runner.sh

# Redeploy containers
podman pull github-actions-runner:latest
podman container rm -f github-runner
./scripts/deploy-runner.sh
```

### Viewing Logs

```bash
# Docker Compose
docker-compose logs -f runner

# Systemd
journalctl -u github-actions-runner -f

# Podman
podman logs -f github-runner
```

### Cleanup

```bash
# Stop and remove container
podman stop github-runner
podman rm github-runner

# Remove image
podman rmi github-actions-runner:latest
```

## Troubleshooting

### Runner fails to register

- Verify GitHub token has correct permissions (`repo` and `workflow` scopes)
- Check token hasn't expired
- Verify repository URL is correct
- Check network connectivity to github.com

### Out of disk space

- Monitor `/var/lib/containers` directory
- Implement image/container cleanup policies
- Use ephemeral mode to auto-cleanup after jobs

### High CPU/Memory usage

- Review active workflow jobs
- Adjust resource limits in systemd service
- Consider distributing load across multiple runners

### Container won't start

- Check Podman daemon is running
- Review logs: `podman logs <container-id>`
- Verify environment variables are set correctly
- Ensure sufficient disk space

## Advanced Configuration

### Custom Base Image

Edit `Dockerfile` to use different base image:

```dockerfile
FROM rocky:9
# or
FROM debian:bookworm
```

### Additional Tools

Add tools to the `RUN` section in Dockerfile:

```dockerfile
RUN apt-get update && apt-get install -y \
    tool-name \
    another-tool
```

### Network Configuration

See `doc/NETWORKING.md` for advanced networking setups including:
- Host network mode
- Custom network namespaces
- VPN integration

### Multi-Architecture Builds

```bash
podman buildx build \
  --platform linux/amd64,linux/arm64 \
  -t github-actions-runner:latest \
  .
```

## Contributing

Please refer to the main infrastructure suite guidelines. For issues specific to this project:

1. Check existing documentation in `doc/`
2. Review troubleshooting section above
3. Check GitHub issues on the main repository

## License

See LICENSE file for details.

## Support

For issues or questions:
- Review documentation in `doc/` directory
- Check CHANGELOG.md for version-specific information
- Consult troubleshooting guides

## Related Projects

- [389DS LDAP Server](../389ds-ldap-server)
- [HAProxy + Podman](../haproxy-podman)
- [LDAP Web Manager](../ldap-web-manager)

