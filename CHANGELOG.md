# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-06

### Added
- Initial release of GitHub Actions Runner Podman image
- Support for self-hosted runner deployment via Docker/Podman
- Entrypoint script for automatic runner registration and configuration
- Deploy script with comprehensive CLI options
- Docker Compose configuration for multi-runner deployments
- Support for both repository-level and organization-level runners
- Ephemeral runner mode for automated cleanup
- Container-in-container support via Podman socket mounting
- Non-root user execution for security (runner user, gha deployment user)
- Dedicated gha user support with proper permissions
- 50GB /opt/gha storage mount support
- Health check configuration
- Systemd service support (configured for gha user)
- Comprehensive documentation and examples
- Built-in tools: 
  - Go (golang-go) for infrastructure and tool development
  - Ansible + Ansible-core for configuration management
  - Git, Git LFS, Docker, Podman, Python 3, Node.js
  - SSH server and client with sshpass
  - CLI tools: curl, wget, jq, yq, unzip, make
- Resource limits configuration via environment variables
- Support for private SSH keys mounting
- Multi-architecture build support documentation
- Logging configuration with rotation
- Security best practices and hardening guidelines
- Storage configuration guide for persistent data

### Features
- Easy one-command deployment: `./scripts/deploy-runner.sh --repo <url> --token <token>`
- Flexible configuration via environment variables
- Support for custom labels for runner targeting
- Auto-scaling ready with ephemeral mode
- Full GitHub Actions runner feature parity
- Graceful shutdown with signal handling
- Runner token management and cleanup

### Documentation
- README with quick start guide
- Environment variable reference
- Deployment options (single container, Docker Compose, systemd)
- Troubleshooting guide
- Security considerations and best practices
- Advanced configuration options
- Tool list and capabilities

## [Unreleased]

### Planned
- Kubernetes deployment support
- Multi-architecture image builds (amd64, arm64)
- Additional pre-installed tools (Terraform, Ansible, etc.)
- Custom base image options
- Integration with container registries
- Monitoring and metrics integration
- Performance optimization
- Windows runner support documentation

### Under Investigation
- Resource auto-scaling
- Distributed runner management
- Advanced networking options
- GPU support
- Custom authentication methods

