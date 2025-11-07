# Quick Reference Card

Fast access to the most commonly used commands and configurations.

## 🚀 Get Started in 60 Seconds

```bash
# 1. Create GitHub token at https://github.com/settings/tokens
#    Scopes: repo, workflow

# 2. Build image
cd github-actions-runner-podman
podman build -t github-actions-runner:latest .

# 3. Deploy
./scripts/deploy-runner.sh \
  --repo https://github.com/YOUR-ORG/YOUR-REPO \
  --token ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# 4. Check in GitHub UI
#    Settings > Actions > Runners > [your runner name]
```

## 📋 Command Cheat Sheet

### Deployment
```bash
# Deploy to repository
./scripts/deploy-runner.sh --repo <url> --token <token>

# Deploy to organization
./scripts/deploy-runner.sh --org <name> --token <token>

# Deploy with custom name and labels
./scripts/deploy-runner.sh \
  --repo <url> \
  --token <token> \
  --runner-name custom-name \
  --labels ci,linux,docker

# Deploy with ephemeral mode
./scripts/deploy-runner.sh \
  --repo <url> \
  --token <token> \
  --ephemeral

# Dry run (preview without executing)
./scripts/deploy-runner.sh \
  --repo <url> \
  --token <token> \
  --dry-run
```

### Management
```bash
# View running containers
podman ps

# View logs
podman logs -f github-runner

# Stop runner
podman stop github-runner

# Start runner
podman start github-runner

# Restart runner
podman restart github-runner

# Remove runner
podman rm -f github-runner

# View container details
podman inspect github-runner
```

### Updates
```bash
# Update runner image
./scripts/update-runner.sh

# Update and restart running runners
./scripts/update-runner.sh --restart-runners

# Update with force (no confirmation)
./scripts/update-runner.sh --force
```

### Docker Compose
```bash
# Start single runner
docker-compose up -d runner

# Start multiple runners
docker-compose --profile multi-runner up -d

# Stop all runners
docker-compose down

# View logs
docker-compose logs -f runner

# Scale to N runners (for services with restart=always)
docker-compose up -d --scale runner=3
```

### Monitoring
```bash
# Real-time stats
podman stats github-runner

# Container memory usage
podman exec github-runner free -h

# Disk usage
df -h /var/lib/containers

# View network connections
podman exec github-runner netstat -an
```

### Cleanup
```bash
# Remove stopped containers
podman container prune -f

# Remove unused images
podman image prune -a

# Remove unused volumes
podman volume prune -f

# Full cleanup (aggressive)
podman system prune -a
```

## 🔧 Configuration Reference

### Essential Environment Variables

```bash
# Required
GITHUB_REPO_URL=https://github.com/YOUR-ORG/YOUR-REPO  # or use GITHUB_ORG
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Optional but recommended
RUNNER_NAME=my-runner-01
RUNNER_LABELS=podman,linux,docker
RUNNER_EPHEMERAL=false
RUNNER_MEMORY=2G
RUNNER_CPUS=2

# Storage Configuration (for 50GB mount at /opt/gha)
RUNNER_WORK_VOLUME=/opt/gha
RUNNER_WORK_DIR=./_work
```

### GitHub Token Scopes
✓ `repo` (full repository access)  
✓ `workflow` (GitHub Actions workflows)

### Common Labels for Workflows
```yaml
runs-on: self-hosted              # Any self-hosted runner
runs-on: [self-hosted, linux]     # Linux runners only
runs-on: [self-hosted, docker]    # Runners with Docker
runs-on: [self-hosted, ci]        # Runners labeled "ci"
```

## 📁 File Quick Reference

| File | Purpose |
|------|---------|
| Dockerfile | Container definition |
| docker-compose.yml | Multi-runner setup |
| scripts/deploy-runner.sh | Deploy runners |
| scripts/update-runner.sh | Update image |
| scripts/entrypoint.sh | Container startup |
| config/env.example | Configuration template |
| doc/QUICK-START.md | 5-minute setup |
| doc/INSTALLATION.md | Detailed setup |
| doc/DEPLOYMENT.md | Production options |
| doc/SECURITY.md | Security hardening |
| doc/TROUBLESHOOTING.md | Problem solving |

## 🔍 Troubleshooting Quick Links

| Problem | Solution |
|---------|----------|
| Runner won't register | [See TROUBLESHOOTING.md](doc/TROUBLESHOOTING.md#runner-registration-issues) |
| Container won't start | [See TROUBLESHOOTING.md](doc/TROUBLESHOOTING.md#container-startup-issues) |
| Can't reach GitHub | [See TROUBLESHOOTING.md](doc/TROUBLESHOOTING.md#network-issues) |
| Out of disk space | [See TROUBLESHOOTING.md](doc/TROUBLESHOOTING.md#out-of-disk-space) |
| Jobs not running | [See TROUBLESHOOTING.md](doc/TROUBLESHOOTING.md#job-execution-issues) |

## 🎯 Common Scenarios

### Scenario 1: Single Repository Runner
```bash
./scripts/deploy-runner.sh \
  --repo https://github.com/myorg/myrepo \
  --token ghp_xxxx \
  --runner-name myrepo-runner
```

### Scenario 2: Organization-Level Runners
```bash
./scripts/deploy-runner.sh \
  --org myorg \
  --token ghp_xxxx \
  --runner-name org-runner-1 \
  --labels ci,shared
```

### Scenario 3: Multiple Runners for Load Distribution
```bash
docker-compose --profile multi-runner up -d
```

### Scenario 4: Production with Systemd
```bash
sudo cp config/github-actions-runner.service /etc/systemd/system/
sudo systemctl enable github-actions-runner
sudo systemctl start github-actions-runner
```

### Scenario 5: Ephemeral Runners (Auto-cleanup)
```bash
./scripts/deploy-runner.sh \
  --repo <url> \
  --token <token> \
  --ephemeral
```

## 📊 Resource Recommendations

| Workload | CPU | Memory | Storage |
|----------|-----|--------|---------|
| Light builds | 2 | 2GB | 10GB |
| Standard CI/CD | 4 | 4GB | 30GB |
| Heavy builds | 8+ | 8GB+ | 50GB+ |
| Docker builds | 4 | 4GB | 40GB |

## 🔐 Security Checklist

- [ ] GitHub token has correct scopes (repo, workflow)
- [ ] Token stored securely (not in code)
- [ ] Only necessary outbound access allowed
- [ ] Regular token rotation (quarterly)
- [ ] Monitoring and logging enabled
- [ ] Security.md reviewed
- [ ] Resource limits configured
- [ ] Ephemeral mode for sensitive workflows

## 📞 Support Matrix

| Issue | Best Resource |
|-------|---------------|
| Getting started | [QUICK-START.md](doc/QUICK-START.md) |
| Installation | [INSTALLATION.md](doc/INSTALLATION.md) |
| Production setup | [DEPLOYMENT.md](doc/DEPLOYMENT.md) |
| Security | [SECURITY.md](doc/SECURITY.md) |
| Troubleshooting | [TROUBLESHOOTING.md](doc/TROUBLESHOOTING.md) |
| File descriptions | [FILES-GUIDE.md](FILES-GUIDE.md) |
| Overall overview | [README.md](README.md) |

## 🛠️ Available Languages & Tools

| Tool | Version | Use Cases |
|------|---------|-----------|
| **Go** | Latest | Infrastructure code, CLI tools, services |
| **Python** | 3.10+ | Scripts, automation, testing |
| **Node.js** | LTS | JavaScript, TypeScript, frontend |
| **Ansible** | Latest | Configuration management, deployment |
| **Git/LFS** | Latest | Version control, large files |
| **Podman** | Latest | Container building and management |
| **SSH** | Latest | Remote access, deployment |
| **jq/yq** | Latest | JSON/YAML processing |

## 📦 Example Workflows

### Go Project
```yaml
- name: Build Go app
  run: |
    go version
    go mod download
    go build -o app ./cmd
```

### Ansible Deployment
```yaml
- name: Deploy infrastructure
  run: |
    ansible-playbook site.yml -i inventory/hosts
```

### Multi-language Build
```yaml
- name: Build everything
  run: |
    go build ./...
    npm install && npm run build
    python3 -m pip install -r requirements.txt
```

## 🎓 Learning Path

1. **Beginner (5 min)**: Read [QUICK-START.md](doc/QUICK-START.md)
2. **Intermediate (30 min)**: Read [INSTALLATION.md](doc/INSTALLATION.md)
3. **Tools Reference**: Check [doc/AVAILABLE-TOOLS.md](doc/AVAILABLE-TOOLS.md)
4. **Production (1 hour)**: Read [DEPLOYMENT.md](doc/DEPLOYMENT.md) + [SECURITY.md](doc/SECURITY.md)
5. **Troubleshooting**: Reference [TROUBLESHOOTING.md](doc/TROUBLESHOOTING.md) as needed

## 🔄 Regular Maintenance

### Weekly
```bash
# Check runner status
podman ps | grep github-runner

# Review logs
podman logs github-runner | tail -20
```

### Monthly
```bash
# Update runner image
./scripts/update-runner.sh

# Clean up old backups
podman image prune -a
```

### Quarterly
```bash
# Rotate GitHub token
# 1. Create new token at https://github.com/settings/tokens
# 2. Update GITHUB_TOKEN in environment
# 3. Redeploy runners
# 4. Delete old token
```

## 📌 Key Files to Bookmark

1. **[README.md](README.md)** - Start here
2. **[QUICK-START.md](doc/QUICK-START.md)** - Fast setup
3. **[TROUBLESHOOTING.md](doc/TROUBLESHOOTING.md)** - Fix issues
4. **[SECURITY.md](doc/SECURITY.md)** - Before production

---

**Need more details?** See [FILES-GUIDE.md](FILES-GUIDE.md) for comprehensive file descriptions.

