# GitHub Actions Self-Hosted Runner - Podman/Docker

![GitHub](https://img.shields.io/badge/GitHub-Actions-blue?logo=github)
![Podman](https://img.shields.io/badge/Container-Podman%20%2F%20Docker-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.0.0-brightgreen)
![Status](https://img.shields.io/badge/Status-Production%20Ready-success)

A production-ready, self-hosted GitHub Actions runner container image for Podman and Docker with multi-platform support (amd64, arm64).

**Registry**: `docker.io/salexson/github-actions-runner-podman`

---

## 🎯 Features

### Container Support
- ✅ **Podman** - Native container runtime
- ✅ **Docker** - Standard container runtime
- ✅ **Docker Compose** - Easy multi-runner deployment
- ✅ **Systemd** - Service-based deployment

### Multi-Platform
- ✅ **linux/amd64** - x86_64 processors
- ✅ **linux/arm64** - ARM 64-bit (RPi 5, M1/M2 Macs)

### Included Tools
- ✅ GitHub CLI (`gh`)
- ✅ Docker daemon
- ✅ Podman runtime
- ✅ Python 3 with pip
- ✅ Git & SSH
- ✅ Build essentials (gcc, make)
- ✅ Utilities (curl, wget, jq, unzip)

### Deployment Options
- ✅ Direct container run (Podman/Docker)
- ✅ Docker Compose orchestration
- ✅ Systemd service
- ✅ Kubernetes Pod (with modifications)

### Production Ready
- ✅ Health checks configured
- ✅ Graceful signal handling
- ✅ Resource limits support
- ✅ Comprehensive logging
- ✅ Security hardening
- ✅ Error recovery

---

## 🚀 Quick Start

### 1. Generate GitHub Runner Token

Go to: `https://github.com/YOUR-ORG/YOUR-REPO/settings/actions/runners`

Click **"New self-hosted runner"** and copy the registration token (valid 1 hour).

### 2. Run Container

```bash
export GITHUB_REPOSITORY="owner/repo"
export RUNNER_TOKEN="ghs_xxxxx"
export RUNNER_NAME="my-runner"
export RUNNER_LABELS="podman,linux,amd64"

podman run -d \
  --name github-runner \
  -e GITHUB_REPOSITORY="$GITHUB_REPOSITORY" \
  -e RUNNER_TOKEN="$RUNNER_TOKEN" \
  -e RUNNER_NAME="$RUNNER_NAME" \
  -e RUNNER_LABELS="$RUNNER_LABELS" \
  -v /var/run/podman/podman.sock:/var/run/podman/podman.sock \
  -v /opt/runner-work:/home/runner/_work \
  docker.io/salexson/github-actions-runner-podman:latest
```

### 3. Verify in GitHub

Runner should appear in your repository's Actions Runners settings as "Idle" or "Active".

### 4. Test with Workflow

Create `.github/workflows/test.yml`:
```yaml
name: Test Runner
on: workflow_dispatch
jobs:
  test:
    runs-on: self-hosted
    steps:
      - run: echo "Runner works!"
      - run: podman --version
```

---

## 📦 Deployment Methods

### Docker Compose (Recommended for Multiple Runners)

```bash
# Set environment variables
export GITHUB_REPOSITORY="owner/repo"
export RUNNER_TOKEN="ghs_xxxxx"
export RUNNER_NAME="runner-01"

# Deploy
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs github-runner
```

See `docker-compose.yml` for configuration.

### Systemd Service (Production Long-term)

```bash
# Copy service file
sudo cp systemd/github-runner.service /etc/systemd/system/

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable github-runner.service
sudo systemctl start github-runner.service

# Monitor
sudo systemctl status github-runner.service
sudo journalctl -u github-runner.service -f
```

### Kubernetes Pod

```bash
# Apply manifest
kubectl apply -f k8s/github-runner-pod.yaml

# Check pod status
kubectl get pods
kubectl logs github-runner
```

---

## 🔧 Configuration

### Required Environment Variables
```bash
GITHUB_REPOSITORY     # Repository in format: owner/repo
RUNNER_TOKEN          # GitHub runner registration token
```

### Optional Environment Variables
```bash
RUNNER_NAME           # Runner display name (default: hostname)
RUNNER_LABELS         # Comma-separated labels (default: linux)
RUNNER_GROUPS         # Runner group name (default: default)
RUNNER_WORKDIR        # Working directory (default: /home/runner/_work)
RUNNER_ALLOW_RUNASROOT # Allow root execution (default: false)
```

### Example: Custom Configuration
```bash
podman run -d \
  -e GITHUB_REPOSITORY="infrastructure-alexson/ldap-web-manager" \
  -e RUNNER_TOKEN="ghs_xxxxx" \
  -e RUNNER_NAME="podman-builder" \
  -e RUNNER_LABELS="podman,linux,amd64,builder" \
  -e RUNNER_WORKDIR="/mnt/runner-work" \
  -v /var/run/podman/podman.sock:/var/run/podman/podman.sock \
  -v /mnt/runner-work:/mnt/runner-work \
  docker.io/salexson/github-actions-runner-podman:latest
```

---

## 📚 Documentation

### Quick Reference
- **[QUICK-REFERENCE.md](docs/QUICK-REFERENCE.md)** - TL;DR guide (150 lines)

### Build & Push
- **[BUILD-GUIDE.md](docs/BUILD-GUIDE.md)** - Building container images (500+ lines)
- **[scripts/build-and-push-podman.sh](scripts/build-and-push-podman.sh)** - Build automation script

### Deployment
- **[SETUP-GUIDE.md](docs/SETUP-GUIDE.md)** - Complete setup guide (600+ lines)
- **[DEPLOYMENT-CHECKLIST.md](docs/DEPLOYMENT-CHECKLIST.md)** - Step-by-step checklist

### Container Files
- **[Dockerfile](Dockerfile)** - Multi-stage container build
- **[docker-compose.yml](docker-compose.yml)** - Compose orchestration
- **[systemd/github-runner.service](systemd/github-runner.service)** - Systemd service
- **[k8s/github-runner-pod.yaml](k8s/github-runner-pod.yaml)** - Kubernetes pod

---

## 🛠️ Building

### Build Locally
```bash
./scripts/build-and-push-podman.sh --no-push
```

### Build & Push to Docker Hub
```bash
./scripts/build-and-push-podman.sh --tag v1.0.0
```

### Build for Single Platform
```bash
./scripts/build-and-push-podman.sh --platform linux/amd64
```

### Build Script Options
```bash
--image IMAGE       # Container name (default: github-actions-runner-podman)
--tag TAG          # Version tag (default: latest)
--registry URL     # Registry URL (default: docker.io)
--username USER    # Registry username (default: salexson)
--dockerfile FILE  # Dockerfile path
--context DIR      # Build context directory
--platform PLAT    # Platforms (default: linux/amd64,linux/arm64)
--no-push          # Build only, no push
--verbose          # Verbose output
```

See [BUILD-GUIDE.md](docs/BUILD-GUIDE.md) for detailed build instructions.

---

## 🔐 Security

### Best Practices
- ✅ Use Personal Access Tokens (not passwords)
- ✅ Never commit credentials or tokens
- ✅ Use environment variables for secrets
- ✅ Run as non-root when possible
- ✅ Use read-only root filesystem
- ✅ Apply resource limits
- ✅ Regularly update base image

### GitHub Actions Integration
```yaml
jobs:
  build:
    runs-on: self-hosted  # Runs on self-hosted runner
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: ./build.sh
```

### Label-Based Runner Selection
```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, podman, amd64]
    steps:
      - run: echo "Running on specific runner"
```

---

## 📊 Performance

### Resource Usage
- **Startup**: 5-10 seconds
- **Memory (idle)**: 200-300 MB
- **CPU (idle)**: 10-20%
- **Disk Space**: 10+ GB recommended

### Optimization Tips
- Use persistent volumes for cache
- Pre-pull frequently-used images
- Enable layer caching
- Monitor with `podman stats`
- Scale runners for parallel workloads

---

## 🐛 Troubleshooting

### Runner Not Connecting
```bash
# Check runner logs
podman logs github-runner

# Verify token is valid (< 1 hour old)
# Generate new token if expired

# Check network connectivity
podman exec github-runner ping github.com
```

### Workflow Not Executing
```bash
# Verify runner online in GitHub
# Check runner labels match workflow requirements
# Verify firewall allows outbound HTTPS
```

### High Resource Usage
```bash
# Monitor resources
podman stats github-runner

# Check for stuck workflows
podman exec github-runner ps aux

# Limit resources if needed
podman update --cpus 2 --memory 4g github-runner
```

See [SETUP-GUIDE.md#Troubleshooting](docs/SETUP-GUIDE.md#troubleshooting) for detailed troubleshooting.

---

## 📈 Scaling

### Multiple Runners with Docker Compose
```yaml
services:
  runner-1:
    image: docker.io/salexson/github-actions-runner-podman:latest
    environment:
      RUNNER_NAME: runner-01
  runner-2:
    image: docker.io/salexson/github-actions-runner-podman:latest
    environment:
      RUNNER_NAME: runner-02
```

### Multiple Runners with Systemd
```bash
for i in {1..3}; do
  podman run -d \
    --name github-runner-$i \
    -e RUNNER_NAME="runner-0$i" \
    ...
done
```

### Load Balancing
Use workflow labels to distribute work across runners:
```yaml
jobs:
  parallel-1:
    runs-on: [self-hosted, label-a]
  parallel-2:
    runs-on: [self-hosted, label-b]
```

---

## 📦 Versioning

### Tags
- `latest` - Current stable release
- `v1.0.0` - Specific version
- `v1.0` - Minor version (latest patch)
- `v1` - Major version (latest release)

### Platforms
- `docker.io/salexson/github-actions-runner-podman:latest`
- `docker.io/salexson/github-actions-runner-podman:latest-amd64`
- `docker.io/salexson/github-actions-runner-podman:latest-arm64`

---

## 🔄 GitHub Actions Workflow

The repository includes automated CI/CD for building and pushing images:

**Workflow**: `.github/workflows/build-and-push.yml`

**Triggers**:
- Push to `main` branch
- Pull requests to `main`
- Git tags
- Manual dispatch

**Features**:
- Multi-platform builds (amd64, arm64)
- Automatic Docker Hub push
- Tag-based versioning
- Layer caching
- Security scanning

---

## 📋 Requirements

### System Requirements
- Podman 4.0+ or Docker 20.10+
- 2+ CPU cores
- 4GB+ RAM
- 10GB+ disk space
- Network access to github.com and docker.io

### GitHub Requirements
- GitHub account
- Repository admin access
- Personal Access Token (optional, for building)

---

## 📝 License

MIT License - See [LICENSE](LICENSE) for details

---

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

## 📞 Support

### Documentation
- [BUILD-GUIDE.md](docs/BUILD-GUIDE.md) - Building images
- [SETUP-GUIDE.md](docs/SETUP-GUIDE.md) - Setting up runners
- [DEPLOYMENT-CHECKLIST.md](docs/DEPLOYMENT-CHECKLIST.md) - Deployment steps
- [QUICK-REFERENCE.md](docs/QUICK-REFERENCE.md) - Quick commands

### External Resources
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Podman Documentation](https://docs.podman.io/)
- [Docker Documentation](https://docs.docker.com/)

### Reporting Issues
Please open an issue on GitHub with:
- Description of the problem
- Steps to reproduce
- System information (OS, Podman/Docker version)
- Relevant logs

---

## 📊 Statistics

| Category | Value |
|----------|-------|
| Base Image | Rocky Linux 8 |
| Platforms | 2 (amd64, arm64) |
| Container Size | ~500MB |
| Startup Time | 5-10 seconds |
| Included Tools | 15+ |
| Documentation | 1000+ lines |

---

## 🎊 Project Status

✅ **Production Ready**

- [x] Multi-platform builds working
- [x] Docker Compose support
- [x] Systemd service support
- [x] Comprehensive documentation
- [x] Security hardening
- [x] CI/CD automation
- [x] GitHub Actions integration

---

## 📅 Changelog

### v1.0.0 (2025-11-06)
- Initial release
- Multi-platform support (amd64, arm64)
- Docker and Podman support
- Docker Compose orchestration
- Systemd service integration
- Comprehensive documentation
- GitHub Actions CI/CD

---

## 👤 Author

Created by **Steven Alexson** for the [infrastructure-alexson](https://github.com/infrastructure-alexson) organization.

---

## 🌟 Docker Hub

Pull pre-built image:
```bash
podman pull docker.io/salexson/github-actions-runner-podman:latest
docker pull docker.io/salexson/github-actions-runner-podman:latest
```

View on Docker Hub: [salexson/github-actions-runner-podman](https://hub.docker.com/r/salexson/github-actions-runner-podman)

---

**Version**: 1.0.0  
**Status**: ✅ Production Ready  
**Last Updated**: 2025-11-06  

For quick start, see [QUICK-REFERENCE.md](docs/QUICK-REFERENCE.md)  
For detailed setup, see [SETUP-GUIDE.md](docs/SETUP-GUIDE.md)
