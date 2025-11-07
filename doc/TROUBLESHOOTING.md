# Troubleshooting Guide

Common issues and solutions for GitHub Actions runners.

## Runner Registration Issues

### Runner won't register with GitHub

**Symptoms:**
```
Error: Failed to register runner
Could not register runner
```

**Solutions:**

1. **Verify GitHub Token**
   ```bash
   # Check token exists and is valid
   curl -H "Authorization: token $GITHUB_TOKEN" \
     https://api.github.com/user
   
   # Should return your GitHub user info
   ```

2. **Verify Token Scopes**
   ```bash
   # Token must have:
   # - repo (full repository access)
   # - workflow (GitHub Actions workflows)
   
   # Check at: https://github.com/settings/tokens
   ```

3. **Verify Repository URL**
   ```bash
   # For repo-level runner:
   curl -H "Authorization: token $GITHUB_TOKEN" \
     https://api.github.com/repos/YOUR-ORG/YOUR-REPO
   
   # Should return repository info
   ```

4. **Verify Network Connectivity**
   ```bash
   # From runner container
   podman exec github-runner ping -c 3 api.github.com
   podman exec github-runner curl -I https://api.github.com
   ```

5. **Check Container Logs**
   ```bash
   podman logs github-runner
   
   # Look for specific error messages
   ```

### Solution Summary

```bash
# Redeploy with correct credentials
podman stop github-runner
podman rm github-runner

./scripts/deploy-runner.sh \
  --repo https://github.com/YOUR-ORG/YOUR-REPO \
  --token ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \
  --runner-name test-runner \
  --build  # Rebuild image if needed
```

## Container Startup Issues

### Container exits immediately

**Symptoms:**
```
Container exits with status 137 or 1
```

**Solutions:**

1. **Check Available Memory**
   ```bash
   free -h
   
   # Reduce memory limit
   RUNNER_MEMORY=1G ./scripts/deploy-runner.sh ...
   ```

2. **Check Disk Space**
   ```bash
   df -h /var/lib/containers
   
   # If full, clean up:
   podman system prune -f
   ```

3. **Verify Permissions**
   ```bash
   # Runner user needs write access to home directory
   ls -la /home/runner
   
   # Should be owned by runner:runner
   ```

4. **Check Image Exists**
   ```bash
   podman images | grep github-actions-runner
   
   # If not found, rebuild:
   podman build -t github-actions-runner:latest .
   ```

### Container starts but registration fails

**Solutions:**

```bash
# View full logs
podman logs -f github-runner

# Check environment variables
podman inspect github-runner | jq '.[0].Config.Env'

# Verify runner script exists
podman exec github-runner ls -la /opt/runner/
```

## Network Issues

### Can't connect to github.com

**Symptoms:**
```
Connection refused
Name resolution failed
Timeout connecting to api.github.com
```

**Solutions:**

1. **Check DNS Resolution**
   ```bash
   podman exec github-runner nslookup github.com
   podman exec github-runner ping -c 1 1.1.1.1
   ```

2. **Check Firewall Rules**
   ```bash
   # Allow outbound HTTPS
   sudo iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
   sudo iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
   ```

3. **Check Network Configuration**
   ```bash
   # View container network
   podman inspect github-runner | jq '.[0].NetworkSettings'
   
   # Test connectivity from container
   podman exec github-runner curl -I https://api.github.com
   ```

4. **Check Proxy Settings (if behind proxy)**
   ```bash
   # Set proxy in container
   podman run -e HTTP_PROXY=http://proxy:8080 \
     -e HTTPS_PROXY=http://proxy:8080 \
     github-actions-runner:latest
   ```

## Runner Status Issues

### Runner shows as "offline"

**Symptoms:**
- Runner appears in GitHub UI but shows offline status
- No jobs are assigned

**Solutions:**

1. **Check Runner is Running**
   ```bash
   podman ps | grep github-runner
   
   # If not running:
   podman start github-runner
   ```

2. **Check Runner Process**
   ```bash
   podman exec github-runner ps aux | grep Runner
   
   # Should see Runner.Listener process
   ```

3. **Check Listener Status**
   ```bash
   podman logs github-runner
   
   # Look for "Runner listener started"
   ```

4. **Restart Runner**
   ```bash
   podman restart github-runner
   
   # Wait 30 seconds for it to reconnect
   ```

### Runner shows as "offline" after job completes

**Solutions:**

```bash
# Check if runner exited
podman ps -a | grep github-runner

# If in Exited state, check logs
podman logs runner-container-name

# Restart with auto-restart policy
podman run -d --restart=unless-stopped ...
```

## Job Execution Issues

### Jobs not running on self-hosted runner

**Symptoms:**
```yaml
runs-on: self-hosted
# Workflow waits indefinitely
```

**Solutions:**

1. **Verify Runner Exists and is Online**
   ```bash
   # GitHub Settings > Actions > Runners
   # Should show runner with "Idle" status
   ```

2. **Check Runner Labels**
   ```bash
   # Workflow specifies wrong labels
   # Correct:
   runs-on: self-hosted
   
   # If you used labels:
   RUNNER_LABELS=ci,linux
   
   # Then in workflow:
   runs-on: [self-hosted, ci]
   ```

3. **Check Repository Access**
   ```bash
   # Runner must be registered to repository/organization
   # GitHub Settings > Actions > Runners > [runner name]
   # Should show repository association
   ```

4. **Increase GitHub Timeout**
   ```bash
   # GitHub waits ~30 minutes before timing out
   # If stuck longer, check runner logs:
   podman logs -f github-runner
   ```

### Job times out on runner

**Symptoms:**
```
Workflow job exceeds 360 minute limit
```

**Solutions:**

1. **Check Resource Usage**
   ```bash
   # Monitor while job runs
   podman stats github-runner
   
   # If CPU-bound: add more cores
   # If memory-bound: add more RAM
   ```

2. **Profile Workflow Performance**
   ```yaml
   steps:
     - name: Check resources
       run: |
         free -h
         df -h /
         top -b -n 1 | head -20
   ```

3. **Optimize Workflow**
   ```yaml
   # Use caching
   - uses: actions/cache@v3
     with:
       path: ~/.cache
       key: build-cache
   
   # Use matrix for parallelization
   strategy:
     matrix:
       node-version: [14, 16, 18]
   ```

### Container/Docker commands fail in workflow

**Symptoms:**
```
docker: command not found
Error response from daemon
```

**Solutions:**

1. **Verify Docker Socket Mount**
   ```bash
   # Check if socket is mounted
   podman inspect github-runner | grep -A 10 "Mounts"
   
   # Should show /var/run/docker.sock mounted
   ```

2. **Verify Permissions**
   ```bash
   # Runner user needs access to docker socket
   podman exec github-runner \
     docker ps
   
   # If permission denied, use sudo in workflow:
   - run: sudo docker ps
   ```

3. **Use Correct Docker Command**
   ```yaml
   - name: Build container
     run: |
       # When using docker socket mount:
       docker build -t myimage:latest .
       
       # Or use podman if available:
       podman build -t myimage:latest .
   ```

## Performance Issues

### Runner is slow/unresponsive

**Symptoms:**
- Jobs take much longer than expected
- Runner becomes unresponsive during jobs

**Solutions:**

1. **Check System Resources**
   ```bash
   # CPU and memory usage
   podman stats github-runner
   
   # Disk I/O
   iostat -x 1
   
   # Network
   iftop -n -P
   ```

2. **Check Runner Load**
   ```bash
   # Multiple jobs competing for resources
   podman exec github-runner \
     ps aux | grep -E "Runner|dotnet"
   
   # Add more resources or reduce concurrent jobs
   ```

3. **Check Disk Space**
   ```bash
   df -h /var/lib/containers
   
   # Clean up old containers
   podman system prune -f
   podman rmi $(podman images -q) -f
   ```

4. **Optimize for Performance**
   ```bash
   # Increase resource allocation
   RUNNER_CPUS=4
   RUNNER_MEMORY=4G
   ./scripts/deploy-runner.sh ...
   ```

### Out of disk space

**Symptoms:**
```
No space left on device
disk full
```

**Solutions:**

1. **Check Disk Usage**
   ```bash
   du -sh /var/lib/containers/*
   df -h /var/lib/containers
   ```

2. **Clean Up**
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

3. **Implement Cleanup in Workflow**
   ```yaml
   - name: Clean up space
     run: |
       docker system prune -f
       docker volume prune -f
   ```

4. **Increase Available Space**
   ```bash
   # Expand /var/lib/containers partition
   # Or redirect docker data:
   mkdir -p /mnt/large-disk/containers
   ln -s /mnt/large-disk/containers /var/lib/containers
   ```

## Logging and Debugging

### Enable Debug Logging

```bash
# View runner logs
podman logs -f github-runner

# View last 100 lines
podman logs -n 100 github-runner

# View with timestamps
podman logs -f --timestamps github-runner
```

### Inspect Runner Configuration

```bash
# Check environment variables
podman inspect github-runner | jq '.[0].Config.Env'

# Check mounted volumes
podman inspect github-runner | jq '.[0].Mounts'

# Check network settings
podman inspect github-runner | jq '.[0].NetworkSettings'
```

### Manual Testing

```bash
# Run image interactively
podman run -it --entrypoint /bin/bash \
  github-actions-runner:latest

# Test connectivity
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/user

# Check installed tools
docker version
podman version
git version
```

## Getting Help

1. **Check logs first:**
   ```bash
   podman logs github-runner
   ```

2. **Review troubleshooting guide:**
   - This file covers common issues
   - See specific section for your symptom

3. **Check GitHub documentation:**
   - https://docs.github.com/en/actions/hosting-your-own-runners

4. **Review security guidelines:**
   - Ensure GitHub token is correct
   - Verify network access
   - Check firewall rules

5. **Still stuck?**
   - Save logs: `podman logs github-runner > runner.log`
   - Check GitHub Actions logs in web UI
   - Review workflow YAML syntax
   - Verify runner registration in GitHub UI

## Prevention Tips

1. **Use Ephemeral Mode**
   ```bash
   RUNNER_EPHEMERAL=true
   ```
   - Automatic cleanup after jobs
   - Fresh environment each time

2. **Regular Updates**
   ```bash
   podman pull ubuntu:22.04
   podman build --pull -t github-actions-runner:latest .
   ```

3. **Monitor Health**
   ```bash
   # Set up monitoring
   podman stats github-runner
   ```

4. **Backup Configuration**
   ```bash
   # Keep runner configuration backed up
   podman cp github-runner:/opt/runner/.credentials ./backup/
   ```

## Related Documentation

- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment options
- [SECURITY.md](SECURITY.md) - Security considerations
- [../README.md](../README.md) - Full documentation

