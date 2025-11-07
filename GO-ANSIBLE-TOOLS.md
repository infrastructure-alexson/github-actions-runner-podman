# Go and Ansible Integration Guide

Complete guide for using Go and Ansible in your GitHub Actions workflows with the runner image.

## Overview

The GitHub Actions Runner image now includes:
- **Go** (golang-go) - Latest stable version from Ubuntu 22.04
- **Ansible** (ansible + ansible-core) - Latest stable version from Ubuntu 22.04
- **SSH support** - SSH server, client, and sshpass for Ansible operations

## Go Support

### Quick Start

```bash
# Check Go version
go version

# Create a new project
go mod init github.com/user/project

# Build a binary
go build -o app ./cmd/main.go

# Run tests
go test ./...

# Install dependencies
go get github.com/lib/pq
```

### Use Cases

1. **Infrastructure Tools**
   - Terraform (written in Go)
   - Docker/Podman tools
   - Kubernetes tooling

2. **CLI Applications**
   - Build and test Go CLI tools
   - Cross-compile for multiple platforms

3. **Microservices**
   - Build and test Go microservices
   - Container-based deployments

4. **DevOps Automation**
   - Infrastructure automation scripts
   - Deployment tooling

### Example Workflows

#### Build Go Application
```yaml
name: Go Build and Test
on: [push, pull_request]

jobs:
  build:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      
      - name: Check Go version
        run: go version
      
      - name: Download dependencies
        run: go mod download
      
      - name: Build
        run: go build -v -o app ./cmd/main.go
      
      - name: Run tests
        run: go test -v -race -coverprofile=coverage.out ./...
      
      - name: Build for multiple platforms
        run: |
          GOOS=linux GOARCH=amd64 go build -o app-linux ./cmd
          GOOS=darwin GOARCH=amd64 go build -o app-darwin ./cmd
          GOOS=windows GOARCH=amd64 go build -o app.exe ./cmd
```

#### Build Docker Image with Go
```yaml
name: Build Container
on: [push]

jobs:
  build:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Go binary
        run: go build -o app ./cmd
      
      - name: Build container image
        run: podman build -t myapp:latest .
      
      - name: Push to registry
        run: podman push myapp:latest quay.io/myorg/myapp:latest
```

#### Install Go Tools
```yaml
name: Install Go Tools
steps:
  - name: Install golangci-lint
    run: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
  
  - name: Lint code
    run: $(go env GOPATH)/bin/golangci-lint run ./...
  
  - name: Install other tools
    run: |
      go install gotest.tools/gotestsum@latest
      go install github.com/securego/gosec/v2/cmd/gosec@latest
```

#### Build with Module Vendor
```yaml
name: Build with Vendor
steps:
  - uses: actions/checkout@v3
  
  - name: Verify modules
    run: go mod verify
  
  - name: Check for uncommitted changes
    run: git diff --exit-code
  
  - name: Build with vendored dependencies
    run: go build -mod=vendor -v ./...
```

## Ansible Support

### Quick Start

```bash
# Check Ansible version
ansible --version

# Check if hosts are reachable
ansible all -i inventory.yml -m ping

# Run a playbook
ansible-playbook site.yml -i inventory.yml

# Run ad-hoc command
ansible webservers -i inventory.yml -m command -a "uptime"

# Dry run (check mode)
ansible-playbook site.yml -i inventory.yml --check
```

### Prerequisites for Ansible

**SSH Configuration in Workflow:**
```yaml
- name: Setup SSH for Ansible
  run: |
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    # Add SSH key from secrets
    echo "${{ secrets.ANSIBLE_SSH_KEY }}" > ~/.ssh/id_rsa
    chmod 600 ~/.ssh/id_rsa
    
    # Disable SSH key checking (set to True for production)
    echo "Host *" >> ~/.ssh/config
    echo "    StrictHostKeyChecking no" >> ~/.ssh/config
    echo "    UserKnownHostsFile /dev/null" >> ~/.ssh/config
    
    # Or scan and add host keys
    ssh-keyscan -H ${{ secrets.TARGET_HOST }} >> ~/.ssh/known_hosts
```

### Use Cases

1. **Infrastructure Provisioning**
   - Server setup and configuration
   - Dependency installation
   - Service deployment

2. **Configuration Management**
   - System configuration
   - Application deployment
   - Cluster management

3. **Multi-Host Deployments**
   - Coordinated deployments across servers
   - Rolling updates
   - Service orchestration

4. **CI/CD Integration**
   - Deploy from GitHub Actions
   - Automated infrastructure changes
   - Testing infrastructure setup

### Example Workflows

#### Basic Ansible Deployment
```yaml
name: Deploy with Ansible
on: [workflow_dispatch, push:tags]

jobs:
  deploy:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.DEPLOY_SSH_KEY }}" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa
          ssh-keyscan -H ${{ secrets.TARGET_HOST }} >> ~/.ssh/known_hosts
      
      - name: Check Ansible version
        run: ansible --version
      
      - name: Run Ansible playbook
        run: |
          ansible-playbook deploy/site.yml \
            -i inventory/production \
            -u ubuntu \
            -e "version=${{ github.ref_name }}"
      
      - name: Verify deployment
        run: |
          ansible all -i inventory/production \
            -m command -a "systemctl status myapp" \
            -u ubuntu
```

#### Multi-Host Deployment
```yaml
name: Deploy to Multiple Hosts
on: [push:tags]

jobs:
  deploy:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.SSH_KEY }}" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa
          echo "Host *" >> ~/.ssh/config
          echo "    StrictHostKeyChecking no" >> ~/.ssh/config
      
      - name: Deploy web tier
        run: |
          ansible-playbook deploy/web.yml \
            -i inventory/production \
            -l web_servers
      
      - name: Deploy database tier
        run: |
          ansible-playbook deploy/db.yml \
            -i inventory/production \
            -l db_servers
      
      - name: Post-deployment tests
        run: |
          ansible-playbook tests/smoke.yml \
            -i inventory/production \
            --check
```

#### Configuration Validation
```yaml
name: Validate Ansible Playbooks
on: [push, pull_request]

jobs:
  validate:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      
      - name: Validate playbook syntax
        run: |
          for playbook in deploy/*.yml; do
            ansible-playbook "$playbook" --syntax-check
          done
      
      - name: Lint with ansible-lint
        run: |
          pip3 install ansible-lint
          ansible-lint deploy/*.yml
      
      - name: Validate roles
        run: |
          for role in roles/*/; do
            ansible-playbook -i 'localhost,' \
              -c local roles/$role/tests/test.yml \
              --syntax-check
          done
```

#### Dry Run and Preview
```yaml
name: Preview Changes
on: [pull_request]

jobs:
  preview:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.SSH_KEY }}" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa
      
      - name: Run in check mode (dry run)
        run: |
          ansible-playbook deploy/site.yml \
            -i inventory/staging \
            --check \
            --diff
      
      - name: Generate change report
        run: |
          ansible-playbook deploy/site.yml \
            -i inventory/staging \
            --check \
            --diff > /tmp/changes.txt || true
      
      - name: Comment with changes
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const changes = fs.readFileSync('/tmp/changes.txt', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '```\n' + changes + '\n```'
            });
```

## Combining Go and Ansible

### Build Go App, Deploy with Ansible
```yaml
name: Build and Deploy
on: [push:tags]

jobs:
  build:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Go binary
        run: |
          go mod download
          go build -o app ./cmd/main.go
      
      - name: Build container
        run: podman build -t myapp:${{ github.ref_name }} .
      
      - name: Push image
        run: podman push myapp:${{ github.ref_name }}
  
  deploy:
    needs: build
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.SSH_KEY }}" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa
      
      - name: Deploy with Ansible
        run: |
          ansible-playbook deploy/site.yml \
            -i inventory/production \
            -e "version=${{ github.ref_name }}"
```

## Available Ansible Modules

The runner includes these commonly used Ansible modules:

### Package Management
- `apt` - Debian/Ubuntu package management
- `yum` - RedHat/CentOS package management
- `pip` - Python package management

### File Operations
- `copy` - Copy files
- `template` - Render templates
- `file` - File/directory management
- `lineinfile` - Manage lines in files
- `blockinfile` - Manage blocks in files

### System
- `command` - Execute commands
- `shell` - Execute shell commands
- `service` - Manage services
- `systemd` - Manage systemd units
- `user` - Manage users
- `group` - Manage groups

### Container
- `docker_container` - Manage Docker containers
- `docker_image` - Manage Docker images
- `podman_container` - Manage Podman containers (if installed)

### Version Control
- `git` - Manage git repositories
- `github_key` - GitHub SSH key management

### Web
- `uri` - HTTP request module
- `curl` - cURL requests
- `get_url` - Download files

### And 500+ more!

See [Ansible Module Index](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/) for complete list.

## Best Practices

### Go
1. **Version Pinning**: Use `go.mod` for dependency management
2. **Testing**: Include unit tests in CI/CD
3. **Linting**: Use golangci-lint to enforce code style
4. **Security**: Use gosec to check for security issues
5. **Cross-compilation**: Build for target platforms

### Ansible
1. **Idempotency**: Ensure playbooks are idempotent
2. **Dry Runs**: Test with `--check` flag first
3. **Vault**: Use Ansible Vault for secrets
4. **Inventory**: Organize hosts in meaningful groups
5. **Roles**: Structure playbooks as roles for reusability
6. **Error Handling**: Use `failed_when`, `changed_when`, `block/rescue`

## Security Considerations

### For Go
```yaml
- name: Security scan Go code
  run: |
    go install github.com/securego/gosec/v2/cmd/gosec@latest
    gosec ./...
```

### For Ansible
```yaml
- name: Secure Ansible setup
  run: |
    # Disable host key checking safely
    echo "StrictHostKeyChecking no" >> ~/.ssh/config
    
    # Use SSH key authentication
    # Never hardcode passwords or API keys
    
    # Use Ansible Vault for secrets
    ansible-playbook site.yml --vault-password-file .vault
```

## Troubleshooting

### Go Issues

```bash
# Check GOPATH
go env GOPATH

# Clear module cache
go clean -modcache

# Verify modules
go mod verify

# Update dependencies
go get -u ./...
```

### Ansible Issues

```bash
# Check Python compatibility
python3 -c "import ansible; print(ansible.__version__)"

# Test connection
ansible all -i inventory.yml -m ping

# Increase verbosity
ansible-playbook site.yml -vvv

# Check syntax
ansible-playbook site.yml --syntax-check

# Run in check mode
ansible-playbook site.yml --check --diff
```

## Related Documentation

- [AVAILABLE-TOOLS.md](doc/AVAILABLE-TOOLS.md) - Complete tool reference
- [README.md](README.md) - Project overview
- [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - Quick commands
- [Go Documentation](https://golang.org/doc/)
- [Ansible Documentation](https://docs.ansible.com/)

## Example Repository Structure

```
project/
├── .github/workflows/
│   ├── build-go.yml
│   ├── deploy-ansible.yml
│   └── test-all.yml
├── cmd/
│   └── main.go
├── deploy/
│   ├── site.yml
│   ├── roles/
│   │   ├── web/
│   │   ├── db/
│   │   └── cache/
│   └── inventory/
│       ├── production
│       └── staging
├── go.mod
├── go.sum
├── Dockerfile
└── Makefile
```

---

**Go Version**: Latest from Ubuntu 22.04  
**Ansible Version**: Latest from Ubuntu 22.04  
**SSH Support**: Yes (server, client, sshpass)  
**Status**: Production Ready ✅

