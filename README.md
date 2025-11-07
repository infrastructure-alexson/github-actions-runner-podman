# GitHub Actions Runner - Podman with Docker Compatibility

A production-ready, enterprise-grade containerized GitHub Actions self-hosted runner based on Ubuntu 22.04 LTS with Podman and docker compatibility.

**Base Image**: `ubuntu:22.04`  
**Container Tool**: Podman (with podman-docker for docker compatibility)  
**Image Size**: ~800MB (includes extensive tooling)  
**CPU Support**: x86-64-v1+ (broad processor compatibility - 2003+)  
**Official Recommendation**: ✅ Ubuntu 22.04 is the officially recommended base for GitHub Actions  
**Support**: Long-term support (LTS) until 2032  

## Overview

This project provides a comprehensive GitHub Actions self-hosted runner container image based on Ubuntu 22.04 LTS with **Podman as the primary container tool** and **podman-docker compatibility layer** for Docker command support.

Ubuntu 22.04 LTS was chosen as the **officially recommended base for GitHub Actions** with broad hardware compatibility and extensive tool ecosystem.

## Features

- ✅ **Ubuntu 22.04 LTS Base**: Official GitHub Actions recommended base, broad compatibility
- ✅ **Podman First**: Modern, secure, rootless-capable container runtime
- ✅ **Docker Compatible**: `docker` commands work via podman-docker wrapper
- ✅ **Self-Hosted Runner**: Full GitHub Actions runner support for CI/CD pipelines
- ✅ **Security Hardened**: Non-root user, rootless support, minimal attack surface
- ✅ **Advanced Tools**: Buildah (image building) and Skopeo (image utilities) included
- ✅ **Language Support**: Python 3, Node.js/npm, Go, and Ansible pre-installed
- ✅ **Multi-Platform**: Supports amd64 and arm64 architectures
- ✅ **Long-Term Support**: Ubuntu 22.04 LTS support until 2032
- ✅ **Comprehensive Tooling**: Git, SSH, curl, jq, findutils, procps, and more

## Quick Start

### Prerequisites

- **Container Runtime**: Podman 4.0+ (Docker 20.10+ also supported via podman-docker compatibility)
- **CPU**: x86-64 processor from 2003+ (x86-64-v1 baseline)
- **GitHub Token**: Registration token from organization (expires in 1 hour)
- **System**: Rocky Linux 8/9, RHEL 8/9, Ubuntu 20.04+, or compatible
- **Storage**: 15GB+ available for image and working directory
- **Network**: Outbound HTTPS to github.com and container registries
- **Memory**: 2GB+ RAM (4GB+ recommended for concurrent workflows)

### Basic Deployment

1. **Clone and navigate to the project:**

```bash
cd github-actions-runner-podman
```

2. **Build the image (Ubuntu 22.04 LTS + Podman):**

```bash
# Build with Podman
podman build -t salexson/github-action-runner:latest .

# Or use the build script
./scripts/build-and-push-podman.sh
```

3. **Deploy the runner with Podman:**

```bash
# Using Podman (recommended for rootless containers)
podman run -d \
  --name github-runner \
  -e GITHUB_ORG="organization-name" \
  -e GITHUB_TOKEN="your_registration_token" \
  -e RUNNER_NAME="org-runner-01" \
  -e RUNNER_LABELS="self-hosted,linux,podman" \
  -v /run/user/984/podman/podman.sock:/var/run/docker.sock:ro \
  -v /opt/gha/runner-work:/home/runner/_work \
  -v /opt/gha/runner-config:/home/runner/.runner \
  salexson/github-action-runner:latest
```

Or with **podman-compose** (recommended for production):

```bash
# Copy .env template and configure
cp config/env.example .env
nano .env

# Deploy with podman-compose
podman-compose up -d
```

### Podman Compose Deployment (Recommended)

```bash
# Copy environment template
cp config/env.example .env

# Edit with your GitHub credentials and registration token
nano .env

# Deploy the stack with podman-compose
podman-compose up -d

# Check status
podman-compose logs -f

# Or check with podman directly
podman ps
podman logs github-runner
```

## Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `GITHUB_ORG` | GitHub organization name (for org runners) | Yes* |
| `GITHUB_REPO_URL` | GitHub repository URL (for repo runners) | Yes* |
| `GITHUB_TOKEN` | Registration token from GitHub (expires in 1 hour) | Yes |
| `RUNNER_NAME` | Name for this runner instance | No (auto-generated) |
| `RUNNER_LABELS` | Comma-separated labels for the runner | No (includes: `self-hosted,linux,podman`) |
| `RUNNER_WORK_DIR` | Working directory for runner | No (default: `/_work`) |
| `RUNNER_GROUPS` | Runner group membership | No (default: `default`) |

*Use either `GITHUB_ORG` (organization runner) or `GITHUB_REPO_URL` (repository runner), not both

### Example Configuration - Organization Level

Create `.env` file:

```bash
# Organization-level runner (all repos can use)
GITHUB_ORG=infrastructure-alexson
GITHUB_TOKEN=ghr_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
RUNNER_NAME=org-runner-01
RUNNER_LABELS=self-hosted,linux,podman,x86_64
RUNNER_WORK_DIR=./_work
CONFIG_DIR=./runner-config
RUNNER_CPUS=2
RUNNER_MEMORY=2g
```

## Deployment Options

### Single Container

```bash
podman run -d \
  --name github-runner \
  -e GITHUB_ORG=your-organization \
  -e GITHUB_TOKEN=your_token \
  -e RUNNER_NAME=runner-1 \
  --volume /run/user/984/podman/podman.sock:/var/run/docker.sock:ro \
  salexson/github-action-runner:latest
```

### With Systemd Service (Production)

**Installation:**
```bash
# Copy service file
sudo cp config/github-actions-runner-podman.service \
  /etc/systemd/system/github-actions-runner.service

# Create environment file
sudo cp config/env.example /home/gha/.runner.env
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
podman-compose up -d runner
```

See [doc/STORAGE-SETUP.md](doc/STORAGE-SETUP.md) for detailed storage management.

## Built-in Tools

The runner image includes:

- **Runtime**: Ubuntu 22.04 LTS base, bash shell, locales support
- **VCS**: Git, Git LFS
- **Containers**: Podman, podman-docker (docker compatibility), Buildah, Skopeo
- **CLI Tools**: curl, wget, jq, unzip, sshpass, rsync, vim-tiny, find, ps/pgrep
- **Build Tools**: Make, gcc, g++, pkg-config
- **Languages**: 
  - Python 3 + pip + venv
  - Node.js + npm
  - Go (golang)
  - Ansible
- **Infrastructure**: SSH server and client
- **System**: sudo, dbus, hostname, findutils (find), procps (ps/pgrep)

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
podman pull salexson/github-action-runner:latest
podman container rm -f github-runner
./scripts/deploy-runner.sh
```

### Viewing Logs

```bash
# Podman Compose
podman-compose logs -f

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
podman rmi salexson/github-action-runner:latest
```

## Documentation

**Complete documentation is in the `doc/` directory.** Start with:

- **[doc/ORG-RUNNER-SETUP.md](doc/ORG-RUNNER-SETUP.md)** - Organization runner setup (recommended starting point)
- **[doc/README.md](doc/README.md)** - Documentation index
- **[doc/TROUBLESHOOTING.md](doc/TROUBLESHOOTING.md)** - Comprehensive troubleshooting guide
- **[doc/HOST-SELINUX-FIX.md](doc/HOST-SELINUX-FIX.md)** - SELinux issues on enforcing systems

## Quick Troubleshooting

### 404 Not Found during registration

- **Cause**: Using PAT instead of registration token
- **Fix**: Use registration token from `https://github.com/organizations/YOUR-ORG/settings/actions/runners/new`
- **Note**: Registration tokens expire in 1 hour
- See [doc/ORG-RUNNER-SETUP.md](doc/ORG-RUNNER-SETUP.md)

### /bin/bash: error while loading shared libraries: libtinfo.so.6

- **Cause**: SELinux enforcing mode on host
- **Fix**: Add `security_opt: - label=disable` to docker-compose.yml (already in place)
- See [doc/HOST-SELINUX-FIX.md](doc/HOST-SELINUX-FIX.md)

### Container won't start

- Check: `podman logs github-runner`
- Verify: `podman-compose` environment variables are set
- See: [doc/TROUBLESHOOTING.md](doc/TROUBLESHOOTING.md)

### For all other issues

→ **[doc/TROUBLESHOOTING.md](doc/TROUBLESHOOTING.md)** - Comprehensive troubleshooting guide

## Advanced Configuration

### Custom Base Image

Edit `Dockerfile` to use different base image:

```dockerfile
FROM ubuntu:24.04
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
  -t salexson/github-action-runner:latest \
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
