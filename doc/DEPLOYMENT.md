# Deployment Guide

Comprehensive guide for deploying GitHub Actions runners in different environments.

## Deployment Options

### 1. Single Container (Development/Testing)

Best for: Testing, single-runner setups, development

```bash
./scripts/deploy-runner.sh \
  --repo https://github.com/org/repo \
  --token YOUR_TOKEN \
  --runner-name dev-runner
```

**Pros:**
- Simple to deploy
- Easy to debug
- Minimal resources

**Cons:**
- Single point of failure
- Limited scalability
- Cannot run concurrent jobs

### 2. Docker Compose (Multiple Runners)

Best for: Production deployments, multiple runners, easier management

```bash
# Setup
cp config/env.example .env
nano .env

# Deploy
docker-compose up -d

# Scale to multiple runners
docker-compose --profile multi-runner up -d
```

**Pros:**
- Multiple runners in one file
- Easy scaling
- Resource management
- Persistent volumes
- Centralized logging

**Cons:**
- Requires Docker Compose
- All containers on single host
- Manual replica management

### 3. Systemd Service (Production Linux)

Best for: Long-running infrastructure, automatic startup, system integration

```bash
# Create systemd service
sudo cp config/github-actions-runner.service /etc/systemd/system/

# Edit service file
sudo nano /etc/systemd/system/github-actions-runner.service

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable github-actions-runner
sudo systemctl start github-actions-runner

# Check status
sudo systemctl status github-actions-runner
```

**Example service file:**

```ini
[Unit]
Description=GitHub Actions Self-Hosted Runner
After=network.target docker.service podman.service

[Service]
Type=simple
User=runner
WorkingDirectory=/opt/runner
Environment="GITHUB_TOKEN=YOUR_TOKEN"
Environment="GITHUB_REPO_URL=https://github.com/org/repo"
Environment="RUNNER_NAME=%h-runner"
ExecStart=/usr/bin/podman run \
  --rm \
  --name github-runner \
  --env GITHUB_TOKEN \
  --env GITHUB_REPO_URL \
  --env RUNNER_NAME \
  --volume /run/podman/podman.sock:/var/run/docker.sock \
  github-actions-runner:latest
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**Pros:**
- System integration
- Automatic restarts
- Persistent storage
- Log journaling

**Cons:**
- Linux only (systemd)
- Manual configuration
- Requires system administration

### 4. Kubernetes Deployment

Best for: Enterprise, auto-scaling, high availability

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: github-actions-runner
spec:
  replicas: 3
  selector:
    matchLabels:
      app: github-runner
  template:
    metadata:
      labels:
        app: github-runner
    spec:
      containers:
      - name: runner
        image: github-actions-runner:latest
        env:
        - name: GITHUB_TOKEN
          valueFrom:
            secretKeyRef:
              name: github-runner-secret
              key: token
        - name: GITHUB_REPO_URL
          value: "https://github.com/org/repo"
        resources:
          requests:
            memory: "1Gi"
            cpu: "1"
          limits:
            memory: "2Gi"
            cpu: "2"
        volumeMounts:
        - name: podman-socket
          mountPath: /var/run/docker.sock
      volumes:
      - name: podman-socket
        hostPath:
          path: /run/podman/podman.sock
```

**Pros:**
- Native auto-scaling
- High availability
- Service mesh support
- Enterprise-grade

**Cons:**
- Kubernetes cluster required
- Complex configuration
- Operational overhead

## Production Best Practices

### Resource Allocation

```yaml
# Memory: 1-2GB minimum per runner
RUNNER_MEMORY=2G
RUNNER_CPUS=2

# For heavy CI jobs:
RUNNER_MEMORY=4G
RUNNER_CPUS=4
```

### Networking

1. **Outbound Access:**
   - GitHub API (api.github.com)
   - GitHub Container Registry (ghcr.io)
   - Package registries (npmjs.com, pypi.org, etc.)

2. **Firewall Rules:**
   ```bash
   # Allow outbound HTTPS
   iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
   
   # Allow DNS
   iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
   ```

### Storage

```bash
# Monitor work directory
df -h /var/lib/containers

# Implement cleanup policies
# In ephemeral mode, automatic cleanup happens
RUNNER_EPHEMERAL=true

# For persistent runners, manual cleanup
podman system prune -f
```

### Logging

```bash
# Centralized logging (Docker)
version: '3.8'
services:
  runner:
    # ... other config ...
    logging:
      driver: syslog
      options:
        syslog-address: udp://localhost:514
        syslog-facility: local0
        tag: "github-runner"

# Or JSON file with rotation
    logging:
      driver: json-file
      options:
        max-size: 100m
        max-file: 5
        labels: "runner"
```

### Monitoring

1. **Container Metrics:**
   ```bash
   podman stats github-runner
   ```

2. **Integration with Prometheus:**
   ```yaml
   # Add to prometheus.yml
   scrape_configs:
     - job_name: 'github-runners'
       static_configs:
         - targets: ['localhost:8888']
   ```

3. **Health Checks:**
   ```bash
   # Manual health check
   podman ps --filter "name=github-runner" --format "{{.Status}}"
   ```

## High Availability Setup

### Multiple Hosts

```bash
# Host 1
./scripts/deploy-runner.sh --repo <url> --token <token> --runner-name runner-1

# Host 2
./scripts/deploy-runner.sh --repo <url> --token <token> --runner-name runner-2

# Host 3
./scripts/deploy-runner.sh --repo <url> --token <token> --runner-name runner-3
```

Target in workflow:
```yaml
runs-on: self-hosted  # Runs on any available runner
```

### Load Balancing

Use GitHub's automatic load balancing:
- Multiple runners with same labels
- GitHub distributes jobs automatically
- Ephemeral mode for cleanup between jobs

## Updates and Maintenance

### Rolling Updates

```bash
# For Docker Compose
docker-compose up -d --force-recreate --no-deps runner

# For Single Container
podman stop github-runner
podman rm github-runner
./scripts/deploy-runner.sh --repo <url> --token <token>
```

### Version Pinning

```dockerfile
# Pin specific runner version
ARG RUNNER_VERSION=2.310.0

RUN curl -L -O https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/...
```

## Disaster Recovery

### Backup

```bash
# Backup runner credentials (keep secure!)
podman cp github-runner:/opt/runner/.credentials ./backup/

# Backup Docker volumes
docker run --rm -v runner-work:/data \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/runner-work.tar.gz -C /data .
```

### Recovery

```bash
# Restore from backup
podman cp ./backup/.credentials github-runner:/opt/runner/

# Restore volumes
docker run --rm -v runner-work:/data \
  -v $(pwd)/backup:/backup \
  alpine tar xzf /backup/runner-work.tar.gz -C /data
```

## Security Hardening

See [SECURITY.md](SECURITY.md) for comprehensive security guidelines including:
- Network isolation
- Credential management
- Access control
- Container security policies
- Secrets management

## Troubleshooting Deployments

### Container won't start

```bash
# Check logs
podman logs github-runner

# Verify environment
podman inspect github-runner | jq '.[0].Config.Env'

# Test image manually
podman run -it github-actions-runner:latest /bin/bash
```

### Runner registration fails

```bash
# Verify credentials
echo $GITHUB_TOKEN
echo $GITHUB_REPO_URL

# Test GitHub connectivity
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/user

# Check runner logs
podman exec github-runner tail -f /var/log/runner.log
```

### Performance issues

```bash
# Monitor resources
podman stats --no-stream

# Check disk space
df -h /var/lib/containers

# Review workflow logs in GitHub UI
```

## Related Documentation

- [QUICK-START.md](QUICK-START.md) - Get started in 5 minutes
- [SECURITY.md](SECURITY.md) - Security best practices
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Solve common issues
- [../README.md](../README.md) - Full documentation

