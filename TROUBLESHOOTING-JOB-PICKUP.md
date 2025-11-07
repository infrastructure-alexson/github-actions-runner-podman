# GitHub Actions Runner - Job Pickup Troubleshooting

**Date**: 2025-11-07  
**Status**: ⚠️ Runner registers and shows Online/Idle but doesn't pick up jobs  
**Runner Version**: 2.329.0  
**Base Image**: Rocky Linux 8

---

## Problem Summary

The self-hosted GitHub Actions runner:
- ✅ Builds successfully
- ✅ Starts in container
- ✅ Registers with GitHub
- ✅ Shows as "Online" and "Idle" in GitHub UI
- ✅ Listens for jobs (`Listening for Jobs` in logs)
- ✅ Can reach GitHub API (curl successful, TLS handshake works)
- ❌ **Does NOT pick up jobs when they're queued**
- ❌ Job remains in "waiting" state indefinitely

---

## What We've Tried

### 1. **Base Image Iterations**
- ❌ UBI 8 Minimal - Too minimal, missing libraries
- ❌ UBI 8 Full - Subscription manager issues, config.sh doesn't create files
- ✅ Rocky Linux 8 - Simplest, but same job pickup issue persists

### 2. **Volume Management**
- ❌ Bind mounts (./runner-config) - Permission issues with rootless Podman usernamespace
- ✅ Named volumes (runner-config-vol) - Better permissions, runner creates files

### 3. **File Persistence**
- Initial issue: No `.runner` or `.credentials` files created
- **Resolution**: Runner stores config in `.config/GitHub/ActionsService/8.0/` instead
- Files ARE being created, just in different location

### 4. **Network Connectivity**
- ✅ Container can reach GitHub API
- ✅ TLS handshake successful
- ✅ No firewall blocking

### 5. **Permissions & SELinux**
- ✅ SELinux label=disable applied in docker-compose.yml
- ✅ Named volumes handle permissions automatically

---

## Current State

```bash
# Runner status
podman ps
# Status: Up 10+ minutes (starting)

podman logs github-runner | tail -5
# [INFO] Listening for Jobs
# 2025-11-07 10:35:47Z: Listening for Jobs

# GitHub UI
# Status: Idle, Online
# Labels: self-hosted,podman,linux,docker,x86_64
```

---

## Hypothesis: Runner Registration Issue

The runner shows as online but may not have **complete registration credentials** even though `config.sh` reports success.

Evidence:
- `.runner` directory exists but is **empty**
- Config stored in `.config/GitHub/ActionsService/` instead
- Runner reports "Runner successfully added" but no credential files persist
- Runner listens but doesn't receive job assignments

---

## Next Steps to Try

### Option 1: Use GitHub API to Verify Registration
```bash
# Check if runner is truly registered
curl -s -H "Authorization: token YOUR_GITHUB_TOKEN" \
  https://api.github.com/orgs/infrastructure-alexson/actions/runners | \
  jq '.runners[] | {name, status, busy}'

# Check for any errors in runner registration
curl -s -H "Authorization: token YOUR_GITHUB_TOKEN" \
  https://api.github.com/orgs/infrastructure-alexson/actions/runners/runner-01
```

### Option 2: Manual Runner Registration
Instead of using the container's entrypoint, manually run config.sh and run.sh:
```bash
podman exec -u runner github-runner /opt/runner/config.sh \
  --url https://github.com/infrastructure-alexson \
  --token YOUR_REGISTRATION_TOKEN \
  --name runner-01 \
  --labels self-hosted,linux,podman \
  --replace

podman exec -u runner github-runner /opt/runner/run.sh
```

### Option 3: Use Official GitHub Runner Docker Image
```bash
# Try the official image for comparison
docker pull ghcr.io/actions/runner:latest

# Compare behavior with our image
```

### Option 4: Check GitHub Actions Runner Debug Logs
```bash
# Enable verbose logging in runner
podman exec github-runner \
  /opt/runner/bin/Runner.Listener run --startuptype service --verbose

# Look for detailed connection/registration logs
```

### Option 5: Simplify to Ubuntu Base
```bash
# Switch Dockerfile FROM to ubuntu:22.04
# This is the official base used by GitHub Actions docs
FROM ubuntu:22.04
```

---

## Files Created/Modified

- `Dockerfile` - Multiple iterations (UBI 8 Minimal → UBI 8 Full → Rocky 8)
- `docker-compose.yml` - Updated to use named volumes
- `scripts/entrypoint.sh` - Added permission fixes and debug logging
- Named volumes: `gha_runner-config-vol`, `gha_runner-work-vol`

---

## Key Observations

1. **Runner registration completes successfully** - GitHub accepts it
2. **Runner shows as online** - GitHub sees it active
3. **But job delivery fails** - Runner doesn't receive job assignment
4. **Credential files location changed** - Uses `.config/GitHub/` not `.runner/`
5. **Network works** - Container can reach GitHub API

This suggests the issue might be with:
- How the runner is configured AFTER registration
- The runner's job listener not being properly initialized
- Some incompatibility with the Rocky Linux 8 environment

---

## Resources

- [GitHub Actions Runner Repository](https://github.com/actions/runner)
- [Runner Release Notes](https://github.com/actions/runner/releases)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Self-hosted Runner Documentation](https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners)

---

## Related Issues

- [GitHub Issue #1264](https://github.com/actions/runner/issues/1264) - Runner not receiving jobs
- [Docker Image Issues](https://github.com/actions/runner/issues?q=docker+image)

---

**Last Updated**: 2025-11-07 10:40 UTC  
**Status**: 🔍 Investigation ongoing - root cause not yet identified

