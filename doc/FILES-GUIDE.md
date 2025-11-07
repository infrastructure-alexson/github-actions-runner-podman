# Files Guide

Quick reference for all files in the GitHub Actions Runner Podman project.

## 📋 Root Level Files

### README.md
**Purpose**: Main project documentation  
**Contents**:
- Project overview and features
- Quick start instructions
- Configuration reference
- Deployment options
- Troubleshooting links
- Security considerations

**When to read**: First time setup, project overview

---

### Dockerfile
**Purpose**: Container image definition  
**Contents**:
- Ubuntu 22.04 base image
- Dependency installation
- GitHub Actions runner setup
- User configuration (non-root)
- Health check configuration

**Key sections**:
- Lines 1-20: Labels and environment setup
- Lines 22-44: System dependencies
- Lines 46-52: User creation
- Lines 54-66: Runner installation
- Lines 68-84: Configuration

**When to edit**: Add custom tools, change base image, modify runtime

---

### docker-compose.yml
**Purpose**: Multi-container orchestration  
**Contents**:
- Single runner service definition
- Multi-runner extensions (profiles)
- Environment variables
- Resource limits
- Volume definitions
- Logging configuration
- Health checks
- Network setup

**Profiles**:
- Default: Single runner
- `multi-runner`: Additional runners (runner-2, runner-3)

**When to use**: Production deployments with multiple runners

---

### CHANGELOG.md
**Purpose**: Version history and release notes  
**Contents**:
- Version 1.0.0 initial release
- Features added
- Planned features (unreleased)

**When to read**: Check what's new, upgrading notes

---

### LICENSE
**Purpose**: MIT License text  
**Contents**: Full MIT license terms

**When to read**: Legal requirements, license terms

---

### PROJECT-SUMMARY.md
**Purpose**: Executive summary and quick reference  
**Contents**:
- Project overview
- File structure
- Quick start guide
- Feature list
- Deployment options table
- Next steps
- Support resources

**When to read**: Quick overview before diving in

---

### FILES-GUIDE.md
**Purpose**: This file - navigation guide

---

### .gitignore
**Purpose**: Git ignore patterns  
**Contents**:
- Environment files (`.env`)
- Sensitive files (tokens, keys)
- Build artifacts
- Cache files
- IDE files
- Container runtime files

**When to review**: Before committing to git

---

## 📁 scripts/ Directory

### entrypoint.sh
**Purpose**: Container startup and initialization script  
**Language**: Bash  
**Size**: ~150 lines  
**Execution**: Runs automatically when container starts

**Key functions**:
- `validate_environment()`: Checks required variables
- `configure_runner()`: Registers with GitHub
- `setup_signals()`: Graceful shutdown handling
- `is_configured()`: Checks if runner already registered

**Environment variables used**:
- `GITHUB_REPO_URL` or `GITHUB_ORG` (required)
- `GITHUB_TOKEN` (required)
- `RUNNER_NAME`
- `RUNNER_LABELS`
- `RUNNER_EPHEMERAL`
- `RUNNER_REPLACE`

**When to modify**: Change registration logic, add custom initialization

**Usage**: Automatic (don't run directly)

---

### deploy-runner.sh
**Purpose**: Deploy runner container with flexible options  
**Language**: Bash  
**Size**: ~300 lines  
**Execution**: Run from command line

**Key functions**:
- `parse_args()`: CLI argument parsing
- `validate_args()`: Input validation
- `check_runtime()`: Auto-detect Docker/Podman
- `build_image()`: Build container image
- `run_container()`: Start container with settings
- `show_status()`: Display deployment info

**Command line options**:
- `--repo URL`: Repository URL
- `--org NAME`: Organization name
- `--token TOKEN`: GitHub token (required)
- `--runner-name NAME`: Custom runner name
- `--labels LABELS`: Comma-separated labels
- `--ephemeral`: Enable ephemeral mode
- `--image-name NAME`: Custom image name
- `--container-name NAME`: Custom container name
- `--build`: Build image before deploy
- `--pull`: Pull base image before building
- `--dry-run`: Show commands without executing

**When to use**: Deploy runners, update configurations, manage runners

**Example usage**:
```bash
./scripts/deploy-runner.sh \
  --repo https://github.com/org/repo \
  --token ghp_xxxx \
  --runner-name runner-1 \
  --build
```

---

### update-runner.sh
**Purpose**: Update runner image with latest version  
**Language**: Bash  
**Size**: ~250 lines  
**Execution**: Run from command line

**Key functions**:
- `detect_runtime()`: Find Docker/Podman
- `get_current_image_info()`: Check current image
- `backup_image()`: Create backup of old image
- `build_image()`: Build new image
- `restart_runners()`: Restart affected runners
- `cleanup_old_backups()`: Remove old backup images

**Command line options**:
- `--image-name NAME`: Image name to update
- `--image-tag TAG`: Image tag to update
- `--runtime RUNTIME`: Force Docker or Podman
- `--no-backup`: Skip backup creation
- `--no-pull`: Don't pull base image
- `--restart-runners`: Restart running containers
- `--force`: Skip confirmation prompt

**When to use**: Update to latest runner version, rebuild after Dockerfile changes

**Example usage**:
```bash
./scripts/update-runner.sh --restart-runners --force
```

---

## 📁 config/ Directory

### env.example
**Purpose**: Environment variable template  
**Format**: Shell environment file (key=value)  
**Size**: ~80 lines

**Sections**:
1. GitHub Configuration (required)
   - `GITHUB_REPO_URL`: Repository URL
   - `GITHUB_ORG`: Organization name
   - `GITHUB_TOKEN`: Personal access token

2. Runner Configuration
   - `RUNNER_NAME`: Display name
   - `RUNNER_LABELS`: Workflow targeting labels
   - `RUNNER_WORK_DIR`: Job directory
   - `RUNNER_EPHEMERAL`: Auto-cleanup mode
   - `RUNNER_REPLACE`: Replace existing config

3. Multi-runner Configuration
   - `RUNNER_NAME_2`, `RUNNER_NAME_3`: Additional runners
   - Corresponding labels and settings

4. Resource Limits
   - `RUNNER_CPUS`: CPU allocation
   - `RUNNER_MEMORY`: RAM allocation
   - Reserved resources

5. Volume Configuration
   - `RUNNER_WORK_VOLUME`: Storage
   - `SSH_KEY_PATH`: SSH credentials

6. Docker/Podman Settings
   - `IMAGE_NAME`: Custom image name
   - `IMAGE_TAG`: Version tag
   - `REGISTRY`: Container registry

7. Advanced Configuration
   - Systemd settings
   - Service parameters

**When to use**: Copy to `.env` and customize for your environment

**Usage**:
```bash
cp config/env.example .env
nano .env  # Edit with your values
source .env  # Load into environment
```

---

### github-actions-runner.service
**Purpose**: Systemd service unit file  
**Language**: INI (systemd format)  
**Size**: ~60 lines

**Key sections**:
- `[Unit]`: Service metadata and dependencies
- `[Service]`: Execution configuration
- `[Install]`: Installation target

**Environment variables**:
- `GITHUB_TOKEN`: GitHub PAT (edit before use)
- `GITHUB_REPO_URL`: Repository URL
- `RUNNER_NAME`: Runner identifier
- `RUNNER_LABELS`: Workflow labels
- `RUNNER_EPHEMERAL`: Auto-cleanup

**Execution settings**:
- Restart policy: `on-failure`
- Resource limits: 2 CPU, 2GB memory
- User: `root` (can be changed to dedicated user)

**When to use**: Linux production deployments with systemd

**Installation**:
```bash
sudo cp config/github-actions-runner.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable github-actions-runner
sudo systemctl start github-actions-runner
```

---

## 📁 podman/ Directory

### pod.yaml
**Purpose**: Kubernetes/Podman pod configuration  
**Language**: Kubernetes YAML  
**Size**: ~200 lines

**Contains**:
1. Pod specification for single runner
   - Name and namespace
   - DNS configuration
   - Container definition
   - Volume mounts
   - Health probes

2. Kubernetes StatefulSet alternative
   - Deployment configuration
   - Service account
   - Init containers
   - Persistent volumes

**Key configurations**:
- Environment variables (GitHub credentials)
- Resource requests and limits
- Security context
- Liveness and readiness probes
- Volume mounts for socket and storage

**When to use**: Kubernetes deployments, Pod-based orchestration

**Usage**:
```bash
# Apply to Kubernetes
kubectl apply -f podman/pod.yaml

# Or run with Podman
podman play kube podman/pod.yaml
```

---

## 📁 doc/ Directory

All documentation files located here:

### QUICK-START.md
**Purpose**: 5-minute setup guide  
**Contents**: Fast track to running your first runner

**Sections**:
- Prerequisites checklist
- Step-by-step instructions
- Verification steps
- Common tasks
- Troubleshooting quick links

**When to read**: First time users, quick reference

---

### INSTALLATION.md
**Purpose**: Detailed installation guide  
**Contents**: Comprehensive setup instructions

**Sections**:
- System requirements matrix
- Prerequisites (Podman/Docker installation)
- Step-by-step installation
- Systemd setup
- Post-installation verification
- Troubleshooting

**When to read**: Setting up on new system, production deployment

---

### DEPLOYMENT.md
**Purpose**: Production deployment strategies  
**Contents**: Advanced deployment options

**Deployment options**:
1. Single Container (dev)
2. Docker Compose (multiple runners)
3. Systemd Service (production Linux)
4. Kubernetes (enterprise)

**Covers**:
- Resource allocation
- Networking setup
- Storage configuration
- Logging integration
- High availability
- Updates and maintenance
- Disaster recovery

**When to read**: Setting up production environments, HA setup

---

### SECURITY.md
**Purpose**: Security best practices and hardening  
**Contents**: ~400 lines of security guidance

**Topics**:
- Container security (non-root, limits)
- Credential management (tokens, rotation)
- Network security (firewalls, policies)
- Access control (GitHub settings)
- Workflow security (action verification)
- Vulnerability management
- Ephemeral runners
- Secrets scanning
- Compliance considerations
- Incident response

**When to read**: Before production deployment, security review

---

### TROUBLESHOOTING.md
**Purpose**: Common issues and solutions  
**Contents**: ~350 lines of troubleshooting

**Issues covered**:
- Runner registration failures
- Container startup issues
- Network connectivity
- Runner status problems
- Job execution issues
- Performance problems
- Disk space issues
- Logging and debugging
- Cleanup procedures

**Format**: Problem description → Diagnosis → Solutions

**When to read**: Runner not working, debugging issues

---

## 🔍 File Usage Quick Reference

| File | Frequency | Purpose |
|------|-----------|---------|
| README.md | First time | Project overview |
| Dockerfile | Monthly | Customize tools |
| docker-compose.yml | Weekly | Multi-runner setup |
| scripts/deploy-runner.sh | Deploy | Initial deployment |
| scripts/update-runner.sh | Monthly | Maintain image |
| scripts/entrypoint.sh | Never (auto) | Runner init |
| config/env.example | Setup | Configuration |
| config/github-actions-runner.service | Setup | Linux production |
| doc/QUICK-START.md | First time | Get started fast |
| doc/INSTALLATION.md | Setup | Detailed setup |
| doc/DEPLOYMENT.md | Planning | Production setup |
| doc/SECURITY.md | Pre-prod | Security review |
| doc/TROUBLESHOOTING.md | As needed | Fix issues |

## 📝 Editing Guidelines

### Safe to Edit
- ✅ `.env` (copy of env.example)
- ✅ Dockerfile (add tools, change versions)
- ✅ env.example (document options)
- ✅ docker-compose.yml (adjust settings)
- ✅ config/github-actions-runner.service (credentials)

### Don't Edit
- ❌ entrypoint.sh (change container logic)
- ❌ deploy-runner.sh (essential for deployment)
- ❌ update-runner.sh (maintenance critical)
- ❌ LICENSE (legal file)

### Document Changes
- Update CHANGELOG.md when making changes
- Add comments to Dockerfile modifications
- Document any customizations

## 📚 Documentation Structure

```
doc/
├── QUICK-START.md         → 5 min setup
├── INSTALLATION.md        → Detailed setup
├── DEPLOYMENT.md          → Production deployment
├── SECURITY.md            → Security hardening
└── TROUBLESHOOTING.md     → Problem solving
```

**Reading path for new users**:
1. README.md (overview)
2. QUICK-START.md (fast setup)
3. INSTALLATION.md (if needed)
4. SECURITY.md (before production)
5. TROUBLESHOOTING.md (if issues)

---

**For questions about specific files, check the relevant documentation section or review the file directly.**

