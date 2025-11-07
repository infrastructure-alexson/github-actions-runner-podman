# GitHub Actions Runner - Podman Documentation

**Current Version**: 1.2.1  
**Base Image**: UBI 8 Minimal (x86-64-v1 compatible)  
**Status**: ✅ Production Ready

---

## 📚 Documentation Guide

### Getting Started

- **[ORG-RUNNER-SETUP.md](ORG-RUNNER-SETUP.md)** ⭐ **START HERE**
  - Complete setup guide for organization-level runners
  - Token generation and environment variables
  - Verification and testing

- **[QUICK-START.md](QUICK-START.md)**
  - Quick reference for basic setup
  - For experienced users

### Deployment & Configuration

- **[DEPLOYMENT.md](DEPLOYMENT.md)**
  - Production deployment guide
  - Resource configuration
  - Scaling multiple runners

- **[INSTALLATION.md](INSTALLATION.md)**
  - Detailed installation steps
  - System requirements

### Troubleshooting

- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** 🔧 **PRIMARY TROUBLESHOOTING**
  - Common issues and solutions
  - 404 errors, startup failures, permissions
  - SELinux issues

- **[HOST-SELINUX-FIX.md](HOST-SELINUX-FIX.md)**
  - SELinux enforcing mode fix
  - Container-only vs system-wide approaches

- **[QUICK-FIX-PODMAN-STARTUP.md](QUICK-FIX-PODMAN-STARTUP.md)**
  - Quick fixes for startup issues
  - User socket initialization

- **[DBUS-SYSTEMD-SESSION-FIX.md](DBUS-SYSTEMD-SESSION-FIX.md)**
  - D-Bus session initialization
  - systemd user services

### Rootless Podman

- **[ROOTLESS-PODMAN-SETUP.md](ROOTLESS-PODMAN-SETUP.md)**
  - Rootless Podman configuration
  - User namespaces and subuid/subgid
  - Socket configuration

- **[ROOTLESS-PODMAN-UID-GID-ISSUE.md](ROOTLESS-PODMAN-UID-GID-ISSUE.md)**
  - UID/GID namespace mapping errors
  - Podman system migrate

- **[PODMAN-SOCKET-PERMISSION-ISSUE.md](PODMAN-SOCKET-PERMISSION-ISSUE.md)**
  - Socket permission errors
  - DOCKER_HOST configuration

### System Configuration

- **[SYSTEMD-MANAGEMENT.md](SYSTEMD-MANAGEMENT.md)**
  - Systemd service management
  - Running runners as system services

- **[SYSTEMD-QUICK-START.md](SYSTEMD-QUICK-START.md)**
  - Quick systemd setup

- **[GHA-USER-SETUP.md](GHA-USER-SETUP.md)**
  - Creating `gha` user for runners
  - User permissions and sudo access

### Security & Analysis

- **[SECURITY.md](SECURITY.md)**
  - Security best practices
  - Running as non-root
  - Network security

- **[SECURITY-ANALYSIS.md](SECURITY-ANALYSIS.md)**
  - Snyk security analysis results
  - Identified vulnerabilities
  - Remediation steps

### Technical Details

- **[PODMAN-COMPOSE-COMPATIBILITY.md](PODMAN-COMPOSE-COMPATIBILITY.md)**
  - Podman-compose version compatibility
  - Healthcheck format issues

- **[DOCKER-REGISTRY-AUTHENTICATION.md](DOCKER-REGISTRY-AUTHENTICATION.md)**
  - Docker/Podman registry authentication
  - Private registry access

- **[PODMAN-ONLY-APPROACH.md](PODMAN-ONLY-APPROACH.md)**
  - Why Podman-only (not Docker)
  - podman-docker compatibility layer

- **[CPU-COMPATIBILITY.md](CPU-COMPATIBILITY.md)**
  - x86-64 CPU instruction sets
  - UBI 8 compatibility (x86-64-v1)

- **[LIBTINFO-MEMORY-PROTECTION-ERROR.md](LIBTINFO-MEMORY-PROTECTION-ERROR.md)**
  - libtinfo.so.6 memory protection errors
  - Root causes and solutions

- **[STORAGE-SETUP.md](STORAGE-SETUP.md)**
  - Storage configuration for runners
  - Volume management

- **[AVAILABLE-TOOLS.md](AVAILABLE-TOOLS.md)**
  - Tools included in the runner image
  - Version information

### Project Information

- **[PROJECT-STATUS.md](PROJECT-STATUS.md)**
  - Current project status
  - Feature completeness

- **[IMPLEMENTATION-COMPLETE.md](IMPLEMENTATION-COMPLETE.md)**
  - Implementation summary
  - What's included

- **[FILES-GUIDE.md](FILES-GUIDE.md)**
  - Project file structure
  - Directory layout

---

## 🚀 Quick Links

| Task | Document |
|------|----------|
| **New to this project?** | [ORG-RUNNER-SETUP.md](ORG-RUNNER-SETUP.md) |
| **Want to deploy?** | [DEPLOYMENT.md](DEPLOYMENT.md) |
| **Having issues?** | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |
| **Need security info?** | [SECURITY.md](SECURITY.md) |
| **Using rootless Podman?** | [ROOTLESS-PODMAN-SETUP.md](ROOTLESS-PODMAN-SETUP.md) |
| **SELinux causing problems?** | [HOST-SELINUX-FIX.md](HOST-SELINUX-FIX.md) |

---

## 📊 Documentation Status

| Category | Status | Notes |
|----------|--------|-------|
| Getting Started | ✅ Complete | ORG-RUNNER-SETUP.md is comprehensive |
| Deployment | ✅ Complete | Production-ready guides available |
| Troubleshooting | ✅ Complete | Covers most common issues |
| Security | ✅ Complete | Best practices documented |
| Rootless Podman | ✅ Complete | Full setup and troubleshooting |
| SELinux | ✅ Complete | Container-only and system-wide options |

---

## 🔄 Documentation Maintenance

Last updated: 2025-11-07  
Version: 1.2.1  
Base image: UBI 8 Minimal

All documentation reflects the current state of the project with:
- ✅ UBI 8 Minimal base image
- ✅ Podman + podman-docker for compatibility
- ✅ Organization-level runner support
- ✅ SELinux hardening recommendations
- ✅ Production deployment practices

---

## 💡 Documentation Philosophy

- **Comprehensive**: Detailed explanations, not just quick fixes
- **Practical**: Real-world scenarios and tested solutions
- **Organized**: Clear structure and cross-references
- **Updated**: Reflects current project state
- **Accessible**: From beginners to advanced users

---

## 📝 Contributing to Documentation

When adding new documentation:
1. Add brief description to this README
2. Place in `/doc` directory
3. Use clear, practical examples
4. Include troubleshooting section where relevant
5. Link to related documents

---

**Quick Help**: Start with [ORG-RUNNER-SETUP.md](ORG-RUNNER-SETUP.md) if you're new! 🚀

