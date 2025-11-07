# Available Tools in GitHub Actions Runner Image

Complete reference of all pre-installed tools and their versions in the runner image.

## Quick Reference

```bash
# Check installed versions
docker run github-actions-runner:latest go version
docker run github-actions-runner:latest ansible --version
docker run github-actions-runner:latest python3 --version
docker run github-actions-runner:latest node --version
docker run github-actions-runner:latest git --version
```

## Programming Languages

### Go
```bash
# Version check
go version

# Example: Build a Go binary
go build -o myapp main.go

# Example: Run tests
go test ./...

# Package managers
go get github.com/some/package
go install github.com/some/tool@latest
```

**Use Cases:**
- Infrastructure automation (Terraform, etc.)
- Microservices deployment
- CLI tool development
- Container management tools

**Workflow Example:**
```yaml
- name: Build Go binary
  run: |
    go version
    go build -o app ./cmd/main.go
    ./app --version
```

### Python 3
```bash
# Version check
python3 --version

# Package management
pip3 install package-name
pip3 install -r requirements.txt

# Virtual environments
python3 -m venv venv
source venv/bin/activate
```

**Pre-installed:**
- Python 3.10+ (from Ubuntu 22.04)
- pip3 (package manager)
- venv (virtual environments)

**Use Cases:**
- Scripts and automation
- Testing (pytest, etc.)
- Package building
- Configuration management

**Workflow Example:**
```yaml
- name: Run Python tests
  run: |
    pip3 install -r requirements.txt
    python3 -m pytest tests/
```

### Node.js & npm
```bash
# Version check
node --version
npm --version

# Package management
npm install
npm install package-name
npm ci

# Running scripts
npm run build
npm test
```

**Pre-installed:**
- Node.js (current LTS from Ubuntu 22.04)
- npm (package manager)

**Use Cases:**
- JavaScript/TypeScript projects
- Frontend builds
- Node.js applications
- Tool scripting

**Workflow Example:**
```yaml
- name: Build Node.js project
  run: |
    npm ci
    npm run build
    npm test
```

## Infrastructure & Automation

### Ansible
```bash
# Version check
ansible --version
ansible-playbook --version

# Run playbooks
ansible-playbook site.yml
ansible-playbook -i inventory hosts.yml

# Ad-hoc commands
ansible all -m ping
ansible webservers -m command -a "uptime"

# Dry run
ansible-playbook --check site.yml
```

**Pre-installed:**
- ansible (main package)
- ansible-core (core components)
- All standard modules

**Common Modules Available:**
- `apt`, `yum` - Package management
- `service` - Service management
- `file`, `directory` - File operations
- `command`, `shell` - Execute commands
- `copy`, `template` - File operations
- `docker_container`, `docker_image` - Docker management
- `git` - Git operations
- And 500+ more built-in modules

**Use Cases:**
- Infrastructure provisioning
- Configuration management
- Multi-machine deployments
- System administration
- Server configuration

**Workflow Example:**
```yaml
- name: Deploy with Ansible
  run: |
    ansible --version
    ansible-playbook deploy/site.yml -i inventory/hosts
```

**SSH Configuration:**
```yaml
- name: Configure SSH for Ansible
  run: |
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    echo "${{ secrets.ANSIBLE_SSH_KEY }}" > ~/.ssh/id_rsa
    chmod 600 ~/.ssh/id_rsa
    ssh-keyscan -H ${{ secrets.TARGET_HOST }} >> ~/.ssh/known_hosts
    ansible-playbook playbook.yml -i inventory/hosts -u ubuntu
```

### SSH
```bash
# SSH client
ssh user@host
ssh -i private_key user@host

# SSH server (running in container)
ssh-keyscan host.example.com >> ~/.ssh/known_hosts

# SCP (copy files)
scp file user@host:/path

# SSH utilities
ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ""
ssh-add ~/.ssh/id_rsa
```

**Pre-installed:**
- openssh-client (SSH client)
- openssh-server (SSH server)
- sshpass (non-interactive SSH passwords)

**Use Cases:**
- Remote deployment
- Ansible operations
- Git over SSH
- Secure file transfer
- Key management

## Version Control

### Git
```bash
# Version check
git --version

# Clone repositories
git clone https://github.com/user/repo.git

# With SSH
git clone git@github.com:user/repo.git

# Shallow clone
git clone --depth 1 https://github.com/user/repo.git
```

**Pre-installed:**
- git (version control)
- git-lfs (large file support)
- SSH support included

**Use Cases:**
- Repository operations
- Submodule management
- Commit history inspection
- Branch operations

### Git LFS
```bash
# Version check
git lfs version

# Install for repo
git lfs install

# Track large files
git lfs track "*.bin"

# Clone with LFS
git clone https://github.com/user/repo-with-lfs.git
```

## Container Tools

### Podman
```bash
# Version check
podman version

# Image operations
podman build -t myimage:latest .
podman pull image:tag
podman push image:tag

# Container operations
podman run -d myimage:latest
podman ps
podman exec container-id command
podman logs container-id
```

**Pre-installed:**
- podman (container management)
- podman-compose (Docker Compose compatibility)

**Use Cases:**
- Building container images
- Running containers
- Container orchestration
- Image registry operations

### Skopeo
```bash
# Copy between registries
skopeo copy docker://image:tag oci:local-image

# Inspect remote images
skopeo inspect docker://ubuntu:latest

# Sync registries
skopeo sync --src docker --dest dir \
  quay.io/podman/stable /tmp/images
```

**Pre-installed:**
- skopeo (image operations)

**Use Cases:**
- Image inspection
- Registry operations
- Image copying
- Cross-platform image management

## CLI Tools & Utilities

### jq (JSON processor)
```bash
# Parse JSON
echo '{"name":"test"}' | jq '.name'

# Pretty print
cat file.json | jq .

# Complex queries
jq '.items[] | select(.status=="active") | .id' data.json
```

**Use Cases:**
- JSON parsing
- API response processing
- Data transformation
- Configuration file manipulation

**Workflow Example:**
```yaml
- name: Parse JSON
  run: |
    curl https://api.example.com/data | jq '.items[] | .id'
```

### yq (YAML processor)
```bash
# Parse YAML
yq '.spec.containers[0].image' deployment.yaml

# Modify YAML
yq '.metadata.name = "new-name"' deployment.yaml

# Convert to JSON
yq -o json deployment.yaml
```

**Use Cases:**
- YAML parsing
- Kubernetes configuration
- Configuration file manipulation
- Format conversion

### wget & curl
```bash
# Download files
wget https://example.com/file.tar.gz
curl -O https://example.com/file.tar.gz

# POST requests
curl -X POST -d data https://api.example.com

# With authentication
curl -u user:pass https://api.example.com

# Download with retry
wget --tries=3 https://example.com/file
```

**Use Cases:**
- File downloading
- API interactions
- Remote configuration
- Health checks

### unzip
```bash
# Extract archive
unzip file.zip

# List contents
unzip -l file.zip

# Extract to directory
unzip file.zip -d /path/to/extract
```

**Use Cases:**
- Archive extraction
- Release downloading
- File extraction

### make
```bash
# Run default target
make

# List targets
make help

# Specific target
make build
make test
make deploy
```

**Use Cases:**
- Build automation
- Task running
- Project automation

## System Utilities

### Basic Tools
```bash
# File operations
ls, cp, mv, rm, mkdir, chmod, chown

# Text processing
cat, grep, sed, awk, head, tail

# System info
uname, whoami, id, pwd

# Package management
apt-get (system packages)

# Process management
ps, top, kill

# Disk space
df, du

# Networking
netstat, ifconfig, ip

# Archive tools
tar, gzip, zip
```

## Tool Compatibility Matrix

| Task | Tool | Availability |
|------|------|--------------|
| Infrastructure Code | Terraform (not built-in) | Via Go |
| Configuration Mgmt | Ansible | ✅ Built-in |
| Container Build | Podman | ✅ Built-in |
| Build Automation | Make | ✅ Built-in |
| Language Support | Go, Python, Node.js | ✅ Built-in |
| API Integration | curl, jq | ✅ Built-in |
| File Operations | tar, unzip, wget | ✅ Built-in |

## Adding Additional Tools

### Via pip3 (Python packages)
```bash
- name: Install Python packages
  run: |
    pip3 install --upgrade pip
    pip3 install requests boto3 paramiko
```

### Via npm (Node packages)
```bash
- name: Install npm packages
  run: |
    npm install -g @angular/cli
    npm install -g typescript
```

### Via go (Go tools)
```bash
- name: Install Go tools
  run: |
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
    go install github.com/koalaman/shellcheck-py/shellcheck@latest
```

### Via apt (System packages)
```bash
- name: Install system packages
  run: |
    sudo apt-get update
    sudo apt-get install -y package-name
```

## Workflow Examples

### Go Project
```yaml
- name: Build and test Go
  run: |
    go version
    go mod download
    go build -v ./...
    go test -v ./...
```

### Python Project
```yaml
- name: Test Python
  run: |
    python3 -m venv venv
    source venv/bin/activate
    pip3 install -r requirements.txt
    pytest tests/
```

### Node.js Project
```yaml
- name: Build Node.js
  run: |
    node --version
    npm ci
    npm run lint
    npm run build
    npm test
```

### Ansible Deployment
```yaml
- name: Deploy with Ansible
  env:
    ANSIBLE_HOST_KEY_CHECKING: 'false'
  run: |
    mkdir -p ~/.ssh
    echo "${{ secrets.SSH_KEY }}" > ~/.ssh/id_rsa
    chmod 600 ~/.ssh/id_rsa
    ansible-playbook deploy/site.yml -i inventory/hosts
```

### Multi-tool Workflow
```yaml
- name: Complete CI/CD
  run: |
    # Build Go service
    go build -o service ./cmd
    
    # Build Node.js frontend
    npm ci && npm run build
    
    # Build container
    podman build -t myapp:latest .
    
    # Run Ansible deployment
    ansible-playbook deploy.yml
    
    # Test with Python
    pip3 install pytest
    pytest tests/
```

## Version Information

All versions are from Ubuntu 22.04 LTS repositories (latest stable):

- **Ubuntu**: 22.04 LTS
- **Go**: Latest from ubuntu packages
- **Python**: 3.10+ 
- **Node.js**: Latest LTS from ubuntu packages
- **Ansible**: Latest stable from ubuntu packages
- **Git**: Latest from ubuntu packages

To get exact versions in your workflow:

```yaml
- name: Check tool versions
  run: |
    echo "=== Go ==="
    go version
    echo "=== Python ==="
    python3 --version
    echo "=== Node.js ==="
    node --version && npm --version
    echo "=== Ansible ==="
    ansible --version
    echo "=== Git ==="
    git --version
```

## Customization

### Add More Tools to Image

Edit `Dockerfile` and add to the apt-get install section:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    # ... existing tools ...
    # New tools
    ruby \
    perl \
    # ... more tools ...
```

Then rebuild:
```bash
podman build -t github-actions-runner:latest .
```

### Runtime Tool Installation

In your workflow:

```yaml
- name: Install runtime tools
  run: |
    # Python packages
    pip3 install package-name
    
    # Go tools
    go install github.com/tool/path@latest
    
    # npm packages
    npm install -g package-name
    
    # System packages (requires sudo)
    sudo apt-get update
    sudo apt-get install -y tool-name
```

## Related Documentation

- [README.md](../README.md) - Project overview
- [INSTALLATION.md](INSTALLATION.md) - Installation guide
- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment options
- [QUICK-REFERENCE.md](../QUICK-REFERENCE.md) - Quick commands

## Support

For tool-specific issues, refer to:
- Go: https://golang.org/doc/
- Python: https://docs.python.org/3/
- Node.js: https://nodejs.org/docs/
- Ansible: https://docs.ansible.com/
- Git: https://git-scm.com/doc
- Podman: https://docs.podman.io/

