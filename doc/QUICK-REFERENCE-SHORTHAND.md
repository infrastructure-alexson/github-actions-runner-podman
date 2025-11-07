# Quick Reference - GitHub Actions Self-Hosted Runner

## TL;DR

```bash
# 1. Get runner token from GitHub
# https://github.com/YOUR-ORG/YOUR-REPO/settings/actions/runners

# 2. Run container
export GITHUB_REPOSITORY="owner/repo"
export GITHUB_TOKEN="ghs_xxxxx"

podman run -d \
  --name github-runner \
  -e GITHUB_REPOSITORY="$GITHUB_REPOSITORY" \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -e RUNNER_NAME="my-runner" \
  -e RUNNER_LABELS="podman,linux,amd64" \
  -v /var/run/podman/podman.sock:/var/run/podman/podman.sock \
  -v /opt/runner-work:/home/runner/_work \
  docker.io/salexson/github-actions-runner-podman:latest

# 3. Check GitHub - runner should appear as "Idle"
# https://github.com/YOUR-ORG/YOUR-REPO/settings/actions/runners
```

## Common Commands

### Run with Docker Compose
```bash
export GITHUB_REPOSITORY="owner/repo"
export GITHUB_TOKEN="ghs_xxxxx"
docker-compose up -d
```

### Build Image Locally
```bash
./scripts/build-and-push-podman.sh --no-push
```

### Push to Docker Hub
```bash
./scripts/build-and-push-podman.sh --tag v1.0.0
```

### View Logs
```bash
podman logs github-runner
# or
docker-compose logs github-runner
```

### Stop Runner
```bash
podman stop github-runner
# or
docker-compose down
```

## Environment Variables

### Required
- `GITHUB_REPOSITORY` - Repository (format: owner/repo)
- `GITHUB_TOKEN` - Token from GitHub (valid 1 hour)

### Optional
- `RUNNER_NAME` - Display name (default: hostname)
- `RUNNER_LABELS` - Tags (default: linux)
- `RUNNER_WORKDIR` - Working dir (default: /home/runner/_work)

## GitHub Actions Workflow

```yaml
name: Test
on: workflow_dispatch
jobs:
  test:
    runs-on: self-hosted  # Runs on your runner!
    steps:
      - run: echo "Works!"
```

## Quick Start Links
- Full docs: [BUILD-GUIDE.md](BUILD-GUIDE.md)
- Setup guide: [SETUP-GUIDE.md](SETUP-GUIDE.md)
- Checklist: [DEPLOYMENT-CHECKLIST.md](DEPLOYMENT-CHECKLIST.md)

