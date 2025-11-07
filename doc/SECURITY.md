# Security Guide

Comprehensive security considerations and best practices for GitHub Actions runners.

## Overview

Running GitHub Actions runners involves security considerations similar to any CI/CD system. This guide covers:
- Container security
- Credential management
- Network security
- Access control
- Vulnerability management

## Container Security

### 1. Non-Root Execution

The runner executes as non-root user `runner` (UID 1001):

```dockerfile
USER runner
```

**Why:** Limits damage from container escape or compromised code

### 2. Read-Only Filesystem (Optional)

```bash
podman run --read-only \
  --tmpfs /tmp:rw \
  --tmpfs /run:rw \
  --tmpfs /home/runner:rw \
  github-actions-runner:latest
```

**Trade-off:** Prevents persistent modification but may limit some workflows

### 3. Resource Limits

```bash
podman run \
  --memory 2G \
  --cpus 2 \
  --memory-swap 2G \
  github-actions-runner:latest
```

**Why:** Prevents resource exhaustion attacks (DoS)

### 4. Security Options

```bash
# Disable new privileges escalation
podman run --security-opt=no-new-privileges:true ...

# Drop unnecessary capabilities
podman run --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --cap-add=CHOWN \
  github-actions-runner:latest
```

### 5. Network Policies

```bash
# Run on isolated network
podman network create runner-net
podman run --network runner-net github-actions-runner:latest

# Or host network for performance (less secure)
podman run --network host github-actions-runner:latest
```

## Credential Management

### 1. GitHub Tokens

**Never hardcode tokens in:**
- Dockerfiles
- Docker Compose files
- Configuration files checked into git

**Secure approaches:**

```bash
# Use environment variables
export GITHUB_TOKEN=ghp_xxxx
./scripts/deploy-runner.sh --token "$GITHUB_TOKEN"

# Use secret management
podman secret create github-token - < ~/.github/token
podman run --secret github-token \
  -e GITHUB_TOKEN_FILE=/run/secrets/github-token \
  github-actions-runner:latest
```

### 2. Token Rotation

```bash
# Regenerate tokens regularly (monthly recommended)
# 1. Create new token at https://github.com/settings/tokens
# 2. Update all runners with new token
# 3. Delete old token
# 4. Verify runners still function
```

### 3. Token Scope Minimization

Required scopes for runners:
- `repo` - Full repository access (necessary for private repos)
- `workflow` - GitHub Actions workflows

**Do not grant:**
- `admin` - Not needed
- `delete_repo` - Not needed
- `delete_workflow` - Not needed

### 4. Secrets in Workflows

```yaml
# Use GitHub secrets for sensitive data
jobs:
  build:
    runs-on: self-hosted
    steps:
      - name: Use secret
        env:
          SECRET_KEY: ${{ secrets.SECRET_KEY }}
        run: |
          # Secret is masked in logs
          echo "Using secret"
```

**Best practices:**
- Use organization secrets for shared values
- Use repository secrets for repo-specific values
- Rotate secrets regularly
- Audit secret access in GitHub logs

## Network Security

### 1. Outbound Access Control

**Required outbound connections:**
- GitHub API: `api.github.com:443`
- GitHub Container Registry: `ghcr.io:443`
- GitHub Artifacts: `uploads.github.com:443`
- Package registries: Depends on your workflows

**Restrict other outbound:**

```bash
# UFW firewall example
sudo ufw default deny outgoing
sudo ufw allow out to any port 443
sudo ufw allow out 53  # DNS
```

### 2. Inbound Access Control

**Runners typically don't need inbound access** (GitHub initiates connection to runner)

If you need inbound access:
- Use VPN
- Use SSH tunneling
- Implement IP whitelisting
- Use private networks (Kubernetes)

### 3. Private Network Deployment

```yaml
# Kubernetes private network
apiVersion: v1
kind: NetworkPolicy
metadata:
  name: runner-network-policy
spec:
  podSelector:
    matchLabels:
      app: github-runner
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ci
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443  # HTTPS only
    - protocol: UDP
      port: 53   # DNS
```

### 4. VPN Integration

```bash
# Run runner through VPN
podman run \
  --network vpn-network \
  --dns 10.0.0.1 \
  github-actions-runner:latest
```

## Access Control

### 1. GitHub Organization Settings

1. Go to Organization Settings > Actions > Runners
2. Configure runner group permissions
3. Assign runners to specific repositories/teams
4. Use branch protection rules

### 2. Runner Labels for Access Control

```bash
# Deploy internal runner
./scripts/deploy-runner.sh \
  --org myorg \
  --token $TOKEN \
  --labels "self-hosted,internal,linux"

# Use in workflow
jobs:
  build:
    runs-on: [self-hosted, internal]  # Only on internal runners
```

### 3. Audit Access

```bash
# Monitor runner activity
# GitHub Settings > Actions > Runners > [runner name]
# Shows job history and status

# Check runner registration events
# Organization logs at Settings > Organization logs
```

## Workflow Security

### 1. Third-Party Action Verification

```yaml
# Use specific commit SHA (most secure)
- uses: actions/checkout@6d193bf28034eafb982f69a989df1e81ff3ef659

# Or use tags with verification
- uses: actions/checkout@v3  # Use tags, but pin versions

# Avoid using @master
```

### 2. Dependency Scanning

```yaml
jobs:
  security:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      
      - name: Run Snyk
        run: |
          npm install -g snyk
          snyk test
```

### 3. Supply Chain Security

```yaml
jobs:
  build:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      
      - name: Generate SBOM
        run: |
          npm install -g cyclonedx
          cyclonedx-npm > sbom.json
      
      - name: Scan dependencies
        run: snyk sbom test sbom.json
```

## Vulnerability Management

### 1. Base Image Security

```dockerfile
# Scan base image for vulnerabilities
# Before building, scan Ubuntu base image
RUN apt-get update && apt-get upgrade -y

# Regular rebuilds to get security patches
```

### 2. Container Image Scanning

```bash
# Scan with Snyk
snyk container test github-actions-runner:latest

# Scan with Trivy
trivy image github-actions-runner:latest

# Scan before pushing to registry
podman build -t github-actions-runner:latest .
trivy image github-actions-runner:latest
```

### 3. Dependency Updates

```bash
# Regular updates to base image
podman pull ubuntu:22.04
podman build --pull -t github-actions-runner:latest .

# Rebuild monthly with:
./scripts/update-runner.sh
```

## Monitoring and Logging

### 1. Container Logs

```bash
# View runner logs
podman logs -f github-runner

# Export logs for audit
podman logs github-runner > runner-audit.log
```

### 2. GitHub Audit Log

```bash
# Monitor in GitHub UI
# Organization Settings > Audit log

# Filter by:
- Actor (user who initiated action)
- Action (what happened)
- Date range
- Resource type
```

### 3. System Logs

```bash
# For systemd-based deployment
journalctl -u github-actions-runner -f

# For Docker Compose
docker-compose logs --follow runner

# Export for analysis
journalctl -u github-actions-runner > runner-system.log
```

## Ephemeral Runners

Ephemeral mode provides additional security:

```bash
# Enable ephemeral mode
RUNNER_EPHEMERAL=true

# Runner cleans up after each job
# - No state persists between jobs
- No accumulated temporary files
- Fresh environment for each job
- Automatic removal after job completion
```

**Benefits:**
- Prevents workflow pollution
- Reduces attack surface
- Simplifies cleanup
- Better resource utilization

## Secrets Scanning

### 1. Prevent Secret Leaks

```yaml
jobs:
  test:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      
      - name: Scan for secrets
        uses: gitleaks/gitleaks-action@v2
```

### 2. Rotate Leaked Secrets

1. Detect secret in logs or code
2. Immediately regenerate (delete and recreate)
3. Audit usage in logs
4. Update dependent systems
5. Document incident

## Compliance Considerations

### 1. Data Residency

- Runners store artifacts locally
- CI/CD data may be regulated
- Consider data center location
- Implement data retention policies

### 2. Audit Trail

```bash
# Maintain audit logs
# GitHub provides:
# - Organization audit log
# - Repository audit log
# - Deployment activity log
# - Security logs
```

### 3. Compliance Best Practices

- Enable branch protection
- Require code review
- Use required status checks
- Enable signed commits
- Maintain audit logs
- Regular security assessment

## Incident Response

### 1. If Token is Compromised

```bash
# IMMEDIATELY:
# 1. Delete compromised token at github.com/settings/tokens
# 2. Stop all runners using that token
# 3. Create new token
# 4. Redeploy runners with new token
# 5. Check GitHub logs for unauthorized activity
# 6. Check artifact registry for malicious builds
```

### 2. If Container is Compromised

```bash
# 1. Stop container immediately
# 2. Investigate logs for suspicious activity
# 3. Analyze any artifacts produced
# 4. Rebuild image from clean source
# 5. Rotate all secrets used by runner
# 6. Redeploy with new image
```

## Security Checklist

- [ ] Tokens stored securely (not in code/files)
- [ ] Tokens rotated regularly (monthly)
- [ ] Runner uses non-root user
- [ ] Resource limits configured
- [ ] Network access restricted
- [ ] GitHub audit logs reviewed
- [ ] Container image scanned
- [ ] Base image kept updated
- [ ] Workflow actions pinned to commits
- [ ] Secrets properly scoped
- [ ] Monitoring and logging enabled
- [ ] Incident response plan documented

## Related Documentation

- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment with security
- [../README.md](../README.md) - Full documentation
- [GitHub Security Hardening](https://docs.github.com/en/actions/security-guides)
- [GitHub Actions Best Practices](https://docs.github.com/en/actions/security-for-github-actions)

