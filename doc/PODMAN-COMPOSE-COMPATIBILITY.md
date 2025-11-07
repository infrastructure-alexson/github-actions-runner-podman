# Podman-Compose Compatibility Guide

**Date**: 2025-11-06  
**Issue**: Healthcheck format incompatibility with podman-compose  
**Affected Versions**: podman-compose 1.0.6 and earlier  

---

## Problem

When running `docker-compose up -d` with podman-compose 1.0.6, you get:

```
ValueError: unknown healthcheck test type [/bin/bash],                     
expecting NONE, CMD or CMD-SHELL.
```

**Traceback shows**:
```
File "/usr/lib/python3.6/site-packages/podman_compose.py", line 1004, in container_to_args
    expecting NONE, CMD or CMD-SHELL."
```

---

## Root Cause

podman-compose 1.0.6 has limited support for Docker Compose healthcheck format:

| Format | Docker Compose | podman-compose 1.0.6 | Status |
|--------|---|---|---|
| Array: `["/bin/bash", "-c", "cmd"]` | ✅ Supported | ❌ NOT Supported | Causes error |
| CMD-SHELL: `["CMD-SHELL", "cmd"]` | ✅ Supported | ✅ Supported | ✅ Works |
| CMD: `["CMD", "executable", "param"]` | ✅ Supported | ✅ Supported | ✅ Works |
| String: `"command string"` | ✅ Supported | ⚠️ Deprecated | Use CMD-SHELL |

---

## Solution

### Change the Healthcheck Format

**Before (Docker Compose compatible, but podman-compose incompatible)**:
```yaml
healthcheck:
  test: ["/bin/bash", "-c", "pgrep -f 'Runner.Server' || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 10s
```

**After (Compatible with both)**:
```yaml
healthcheck:
  test: ["CMD-SHELL", "pgrep -f 'Runner.Server' || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 10s
```

### Key Change
```diff
- test: ["/bin/bash", "-c", "pgrep -f 'Runner.Server' || exit 1"]
+ test: ["CMD-SHELL", "pgrep -f 'Runner.Server' || exit 1"]
```

---

## Healthcheck Format Reference

### CMD-SHELL Format (Recommended)

**Use when**: You need shell features (pipes, redirects, conditionals)

```yaml
healthcheck:
  test: ["CMD-SHELL", "command | another_command"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

**Examples**:
```yaml
# Check if process is running
test: ["CMD-SHELL", "pgrep -f 'Runner.Server' || exit 1"]

# Check if port is listening
test: ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]

# Check multiple conditions
test: ["CMD-SHELL", "test -f /health && curl http://localhost:8080 || exit 1"]

# Check file exists
test: ["CMD-SHELL", "test -f /home/runner/.configured || exit 1"]
```

### CMD Format (Alternative)

**Use when**: You want to run a command without shell interpretation

```yaml
healthcheck:
  test: ["CMD", "/bin/check-health"]
```

**Examples**:
```yaml
# Run an executable directly
test: ["CMD", "/opt/runner/healthcheck.sh"]

# Run with arguments
test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
```

### None Format

**Use when**: You want to disable health checking

```yaml
healthcheck:
  test: NONE
```

---

## Common Healthcheck Patterns

### 1. Check Process is Running

```yaml
healthcheck:
  test: ["CMD-SHELL", "pgrep -f 'Runner.Server' || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### 2. Check HTTP Endpoint

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### 3. Check File Exists

```yaml
healthcheck:
  test: ["CMD-SHELL", "test -f /home/runner/.configured || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### 4. Check Multiple Conditions

```yaml
healthcheck:
  test: ["CMD-SHELL", "test -f /home/runner/.configured && test -f /home/runner/.runner || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### 5. Disable Health Check

```yaml
healthcheck:
  test: NONE
```

---

## For the GitHub Actions Runner

### Current Configuration (Fixed)

```yaml
healthcheck:
  test: ["CMD-SHELL", "pgrep -f 'Runner.Server' || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 10s
```

**Explanation**:
- **test**: Checks if Runner.Server process is running
- **interval**: Check every 30 seconds
- **timeout**: Wait 10 seconds for response
- **retries**: Mark unhealthy after 3 failed checks
- **start_period**: Wait 10 seconds before first check

### Interpretation

```
Healthy:   ✅ Runner.Server process is running
Unhealthy: ❌ Runner.Server process is not running or check timed out
Starting:  ⏳ First 10 seconds - don't mark unhealthy yet
```

---

## Testing Healthcheck

### Check Status

```bash
# View container status
docker-compose ps
# or
podman ps

# Expected output:
# NAME              STATUS
# github-runner     Up 2 seconds (healthy)
```

### View Health Status Details

```bash
# Detailed container info
docker-compose exec github-runner podman inspect github-runner --format='{{.State.Health}}'

# Or with podman directly
podman inspect github-runner --format='{{.State.Health}}'
```

### Manually Test Health Command

```bash
# Run the healthcheck command directly
docker-compose exec github-runner pgrep -f 'Runner.Server'

# Or from host
podman exec github-runner pgrep -f 'Runner.Server'

# Should show the PID if running, e.g.: 42
```

---

## Podman-Compose Version Compatibility

### Version History

| Version | Healthcheck Support | Status |
|---------|---|---|
| 1.0.6 | CMD-SHELL, CMD only | Current in RHEL 8 |
| 1.0.5 | CMD-SHELL, CMD only | ✅ Compatible |
| 1.0.4 | Limited | ✅ Use CMD-SHELL |
| 1.0.3 | Limited | ✅ Use CMD-SHELL |
| 1.1.0+ | Full Docker Compose support | ✅ All formats |

### Check Your Version

```bash
docker-compose --version
# or
podman-compose --version

# Output: podman-compose version 1.0.6
```

### Upgrade Podman-Compose (If Needed)

**On RHEL 8 / Fedora**:
```bash
# Using pip (recommended)
pip3 install --upgrade podman-compose

# Or using dnf (if available)
sudo dnf update podman-compose
```

**After upgrade**:
```bash
# Verify version
podman-compose --version

# All healthcheck formats will work with 1.1.0+
```

---

## Docker Compose vs Podman-Compose Differences

### Healthcheck Support

| Feature | Docker Compose | Podman-Compose 1.0.6 | Podman-Compose 1.1.0+ |
|---------|---|---|---|
| `test: ["/bin/bash", "-c", "cmd"]` | ✅ Full | ❌ Error | ✅ Full |
| `test: ["CMD-SHELL", "cmd"]` | ✅ Full | ✅ Full | ✅ Full |
| `test: ["CMD", "cmd"]` | ✅ Full | ✅ Full | ✅ Full |
| `test: "string"` | ✅ Full | ⚠️ Limited | ✅ Full |
| `NONE` | ✅ Full | ⚠️ Limited | ✅ Full |

### Workaround

Use **CMD-SHELL format** for compatibility with all versions:

```yaml
# Works everywhere
test: ["CMD-SHELL", "your command here"]
```

---

## Troubleshooting

### Error: "unknown healthcheck test type"

**Cause**: Using array format with `/bin/bash`

**Fix**: Use CMD-SHELL format instead
```yaml
# ❌ Wrong
test: ["/bin/bash", "-c", "command"]

# ✅ Correct
test: ["CMD-SHELL", "command"]
```

### Healthcheck Always Fails

**Possible causes**:
1. Process name doesn't match exactly
2. Command has wrong permissions
3. Timeout too short for slow operations

**Solutions**:
```bash
# Test the command directly
podman exec github-runner pgrep -f 'Runner.Server'

# Check exact process name
podman exec github-runner ps aux | grep Runner

# Increase timeout if needed
timeout: 30s  # Was 10s
```

### Container Marked as Unhealthy

**Symptoms**:
```
STATUS: Up 5 seconds (unhealthy)
```

**Investigation**:
```bash
# Check health status
podman inspect github-runner --format='{{.State.Health.Status}}'

# View health log
podman inspect github-runner --format='{{range .State.Health.Log}}{{.ExitCode}} {{.Output}}{{end}}'

# Check actual logs
podman logs github-runner
```

**Common fixes**:
1. Increase `start_period` (wait longer before first check)
2. Increase `timeout` (give process more time to respond)
3. Verify process name is correct
4. Check process is actually running

---

## Best Practices

### 1. Use CMD-SHELL for Shell Commands
```yaml
# ✅ Good
test: ["CMD-SHELL", "curl -f http://localhost:8080 || exit 1"]

# ❌ Avoid
test: ["/bin/sh", "-c", "curl -f http://localhost:8080 || exit 1"]
```

### 2. Set Appropriate Timeouts
```yaml
# Quick checks
timeout: 5s
interval: 10s

# Slow checks
timeout: 30s
interval: 60s
```

### 3. Use start_period for Long Startups
```yaml
# Application takes 30 seconds to fully start
start_period: 40s
```

### 4. Add Explicit Exit Codes
```yaml
# ✅ Good - explicit exit code
test: ["CMD-SHELL", "command || exit 1"]

# ⚠️ Less clear
test: ["CMD-SHELL", "command"]
```

### 5. Keep Commands Simple
```yaml
# ✅ Good - single check
test: ["CMD-SHELL", "pgrep -f 'Runner.Server' || exit 1"]

# ⚠️ Complex
test: ["CMD-SHELL", "test -f /health && curl http://localhost/health && pgrep runner || exit 1"]
```

---

## References

- [Docker Compose Healthcheck Reference](https://docs.docker.com/compose/compose-file/compose-file-v3/#healthcheck)
- [Podman-Compose GitHub](https://github.com/containers/podman-compose)
- [Podman Health Check Documentation](https://docs.podman.io/en/latest/markdown/podman-healthcheck.1.html)

---

## Related Documentation

- [ROOTLESS-PODMAN-SETUP.md](ROOTLESS-PODMAN-SETUP.md) - Rootless Podman configuration
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General troubleshooting
- [QUICK-START.md](QUICK-START.md) - Quick start guide
- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment guide

---

**Last Updated**: 2025-11-06  
**Status**: ✅ Fixed in docker-compose.yml  
**Compatible**: podman-compose 1.0.6+ and Docker Compose

