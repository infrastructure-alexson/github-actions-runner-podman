# GitHub Organization Self-Hosted Runners - Setup Guide

**Date**: November 6, 2025  
**Purpose**: Adding self-hosted runners to GitHub organization  
**Organization**: infrastructure-alexson  
**Status**: ✅ Production Ready

---

## 📋 Overview

This guide covers adding GitHub Actions self-hosted runners at the **organization level**, making them available to **all repositories** in the organization.

### Benefits of Organization-Level Runners

✅ **Organization-Wide Access** - All repos can use these runners  
✅ **Centralized Management** - Manage all runners in one place  
✅ **Shared Resources** - Multiple projects share the same runners  
✅ **Cost Efficient** - One runner infrastructure for entire organization  
✅ **Consistent Environment** - All projects use same runner image  
✅ **Single Token** - Use organization secret `GHA_ACCESS_TOKEN`  
✅ **Easy Scaling** - Add more runners as needed  

---

## 🔑 Prerequisites

### Access Requirements
- [ ] Organization owner or member with runner management access
- [ ] GitHub account authenticated and authorized
- [ ] Access to organization settings

### Infrastructure Requirements
- [ ] Host machine with Docker/Podman 4.0+
- [ ] Minimum: 2 CPU cores, 4GB RAM, 10GB disk per runner
- [ ] Network access to github.com (outbound HTTPS)
- [ ] Docker Compose or Podman installed

### GitHub Setup Complete
- [ ] Organization secret `GHA_ACCESS_TOKEN` created
- [ ] Runner repository cloned: `infrastructure-alexson/github-actions-runner-podman`

---

## 🔧 Step 1: Create Organization Secret

### 1.1 Navigate to Organization Settings

1. Go to: https://github.com/organizations/infrastructure-alexson

2. Click **"Settings"** tab

3. Click **"Security"** → **"Secrets and variables"** → **"Actions"**

### 1.2 Create Secret

1. Click **"New organization secret"**

2. Configure:
   - **Name**: `GHA_ACCESS_TOKEN` (exact name)
   - **Value**: Your runner registration token
   - **Visibility**: "All repositories" (or select specific repos)

3. Click **"Add secret"**

**Note**: Token is valid for 1 hour. If needed, generate new token from:
https://github.com/organizations/infrastructure-alexson/settings/actions/runners

---

## 🎯 Step 2: Configure Runner Registration Token

### 2.1 Generate Registration Token

1. Go to: https://github.com/organizations/infrastructure-alexson/settings/actions/runners

2. Click **"New self-hosted runner"**

3. Select:
   - **Runner image**: Linux (or your OS)
   - **Architecture**: x64 or ARM64 (based on your host)

4. Copy the token from:
   ```
   ./config.sh --url https://github.com/infrastructure-alexson --token AICVO4YB3NFC6XFZNENMBV3JBVF34
   ```

5. **Important**: Token is valid for 1 hour. Use immediately or regenerate.

### 2.2 Store Token in Organization Secret

Store in `GHA_ACCESS_TOKEN` (already done ✅)

---

## 🚀 Step 3: Deploy Organization Runners

### Option A: Docker Compose (Recommended)

#### 3A.1 Create Configuration

Navigate to repository:
```bash
cd /opt/github-actions-runner-podman
# or wherever you cloned it
```

Create `.env` file:
```bash
cat > .env <<EOF
# Organization-Level Runner Configuration
GITHUB_REPOSITORY=infrastructure-alexson
RUNNER_TOKEN=<TOKEN_FROM_ORG_SECRET>
RUNNER_NAME=org-runner-01
RUNNER_LABELS=organization,podman,linux,amd64
WORK_DIR=/opt/runner-work-01
CONFIG_DIR=/opt/runner-config-01
RUNNER_CPUS=2
RUNNER_MEMORY=4G
EOF
```

#### 3A.2 Deploy Runner

```bash
# Deploy single runner
docker-compose up -d

# Or with specific name
docker-compose -p org-runner-01 up -d
```

#### 3A.3 Verify Deployment

```bash
# Check container
docker-compose ps

# View logs
docker-compose logs -f github-runner

# Check runner registered in GitHub
# https://github.com/organizations/infrastructure-alexson/settings/actions/runners
```

---

### Option B: Multiple Runners (Load Balanced)

For larger organizations, deploy multiple runners for parallel execution:

#### 3B.1 Create Separate Directories

```bash
# Create directories for each runner
mkdir -p /opt/runners/{runner-01,runner-02,runner-03}
cd /opt/runners

# Copy repository to each
for i in {1..3}; do
  cp -r /path/to/github-actions-runner-podman runner-0${i}/
done
```

#### 3B.2 Create .env Files

```bash
# runner-01/.env
cat > runner-01/.env <<EOF
GITHUB_REPOSITORY=infrastructure-alexson
RUNNER_TOKEN=<YOUR_TOKEN>
RUNNER_NAME=org-runner-01
RUNNER_LABELS=organization,podman,linux,amd64
WORK_DIR=/opt/runner-work-01
CONFIG_DIR=/opt/runner-config-01
EOF

# runner-02/.env
cat > runner-02/.env <<EOF
GITHUB_REPOSITORY=infrastructure-alexson
RUNNER_TOKEN=<YOUR_TOKEN>
RUNNER_NAME=org-runner-02
RUNNER_LABELS=organization,podman,linux,amd64
WORK_DIR=/opt/runner-work-02
CONFIG_DIR=/opt/runner-config-02
EOF

# runner-03/.env (and so on)
```

#### 3B.3 Deploy All Runners

```bash
# Deploy all runners
for i in {1..3}; do
  cd runner-0${i}
  docker-compose -p org-runner-0${i} up -d
  cd ..
done

# Check all runners
docker ps | grep github-runner

# View status
for i in {1..3}; do
  echo "=== Runner 0${i} ==="
  docker-compose -p org-runner-0${i} ps
done
```

---

### Option C: GitHub Actions Workflow (Automated)

Deploy runners automatically via GitHub Actions workflow.

#### 3C.1 Create Workflow File

**Location**: `.github/workflows/deploy-org-runners.yml`

```yaml
name: Deploy Organization Runners
on:
  workflow_dispatch:
    inputs:
      runner_count:
        description: 'Number of runners to deploy'
        required: false
        default: '1'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Deploy runners
        env:
          RUNNER_TOKEN: ${{ secrets.GHA_ACCESS_TOKEN }}
          GITHUB_REPOSITORY: infrastructure-alexson
        run: |
          RUNNER_COUNT=${{ github.event.inputs.runner_count || 1 }}
          
          for i in $(seq 1 $RUNNER_COUNT); do
            RUNNER_NAME="org-runner-$(printf '%02d' $i)"
            
            echo "Deploying $RUNNER_NAME..."
            
            export RUNNER_NAME="$RUNNER_NAME"
            export RUNNER_TOKEN="${RUNNER_TOKEN}"
            export RUNNER_LABELS="organization,podman,linux,amd64"
            
            docker-compose -p "$RUNNER_NAME" up -d
            
            echo "Deployed: $RUNNER_NAME"
          done

      - name: Verify deployment
        run: |
          echo "Running containers:"
          docker ps | grep github-runner

      - name: Create deployment summary
        run: |
          echo "## Deployment Summary" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Runners Deployed**: ${{ github.event.inputs.runner_count || 1 }}" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Status**: Verify in Organization Settings" >> $GITHUB_STEP_SUMMARY
          echo "https://github.com/organizations/infrastructure-alexson/settings/actions/runners" >> $GITHUB_STEP_SUMMARY
```

#### 3C.2 Manually Trigger Workflow

1. Go to: https://github.com/infrastructure-alexson/github-actions-runner-podman/actions

2. Select **"Deploy Organization Runners"** workflow

3. Click **"Run workflow"**

4. Enter number of runners to deploy

5. Click **"Run workflow"**

---

## ✅ Step 4: Verify Runners Registered

### 4.1 Check in GitHub UI

1. Go to: https://github.com/organizations/infrastructure-alexson/settings/actions/runners

2. You should see:
   - Runner name (e.g., "org-runner-01")
   - Status: "Idle" or "Active"
   - OS: Linux
   - Architecture: X64 or ARM64
   - Runner group: "Default"
   - Labels: your configured labels

### 4.2 Check Docker Status

```bash
# List running containers
docker ps | grep github-runner

# Check logs
docker-compose logs github-runner | tail -50

# Check runner process
docker-compose exec github-runner ps aux | grep -i runner
```

### 4.3 Check Network Connectivity

```bash
# Verify GitHub connectivity from runner
docker-compose exec github-runner curl -I https://github.com

# Check DNS resolution
docker-compose exec github-runner nslookup github.com
```

---

## 🧪 Step 5: Test Organization Runners

### 5.1 Create Test Workflow

Create `.github/workflows/test-org-runner.yml`:

```yaml
name: Test Organization Runner
on:
  workflow_dispatch:

jobs:
  test:
    name: Test on Organization Runner
    runs-on: self-hosted
    steps:
      - name: System Info
        run: |
          echo "=== System Information ==="
          uname -a
          echo ""
          echo "=== CPU Info ==="
          nproc
          echo ""
          echo "=== Memory Info ==="
          free -h

      - name: Container Tools
        run: |
          echo "=== Container Tools ==="
          podman --version
          docker --version || echo "Docker not found"
          echo ""
          echo "=== Build Tools ==="
          gcc --version
          python3 --version

      - name: GitHub CLI
        run: |
          echo "=== GitHub CLI ==="
          gh --version
          gh auth status

      - name: Success
        run: echo "✅ Organization runner is working!"
```

### 5.2 Trigger Test Workflow

1. Go to: https://github.com/infrastructure-alexson/github-actions-runner-podman/actions

2. Select **"Test Organization Runner"**

3. Click **"Run workflow"**

4. Wait for execution

5. Verify successful completion

---

## 🔄 Step 6: Using Runners in Repositories

### 6.1 In Your Workflows

Use organization runners in any repository workflow:

```yaml
jobs:
  build:
    runs-on: self-hosted  # Default: any org runner
    steps:
      - uses: actions/checkout@v3
      - run: echo "Running on organization runner"
```

### 6.2 With Specific Labels

Target specific runners by labels:

```yaml
jobs:
  build:
    runs-on: [self-hosted, organization, podman]
    steps:
      - run: podman --version

  test:
    runs-on: [self-hosted, organization, linux]
    steps:
      - run: uname -a

  parallel:
    runs-on: self-hosted  # Distributes across available runners
    strategy:
      matrix:
        runner: [1, 2, 3]
    steps:
      - run: echo "Running in parallel on runner ${{ matrix.runner }}"
```

### 6.3 Load Balancing

GitHub automatically distributes jobs across runners with matching labels:

```yaml
jobs:
  parallel-jobs:
    name: Job
    runs-on: [self-hosted, organization]
    strategy:
      matrix:
        job: [1, 2, 3, 4, 5]
    steps:
      - run: echo "Job ${{ matrix.job }} running on organization runner"
```

---

## 📊 Managing Organization Runners

### View All Runners

```bash
# GitHub UI
# https://github.com/organizations/infrastructure-alexson/settings/actions/runners

# Via GitHub CLI
gh api organizations/infrastructure-alexson/actions/runners
```

### Monitor Runner Health

```bash
# Check container status
docker ps -a

# View logs for all runners
for container in $(docker ps -a -q -f "label=app=github-action-runner"); do
  echo "=== Container: $(docker inspect -f '{{.Name}}' $container) ==="
  docker logs --tail 20 $container
done

# Check resource usage
docker stats
```

### Restart Runner

```bash
# Single runner
docker-compose restart github-runner

# Multiple runners
docker-compose -p org-runner-01 restart github-runner
docker-compose -p org-runner-02 restart github-runner
docker-compose -p org-runner-03 restart github-runner
```

### Stop Runner

```bash
# Single runner
docker-compose down

# Multiple runners
docker-compose -p org-runner-01 down
docker-compose -p org-runner-02 down
docker-compose -p org-runner-03 down
```

### Remove Runner from GitHub

1. Go to: https://github.com/organizations/infrastructure-alexson/settings/actions/runners

2. Click **"..."** next to runner name

3. Click **"Remove"**

4. Confirm removal

---

## 🔐 Organization-Level Security

### Runner Access Control

```yaml
# Only accessible to specific repositories
# Set via organization secret visibility settings

# All repositories can use (default)
RUNNER_VISIBILITY: all

# Specific repositories only
# (Set when creating the organization secret)
```

### Runner Permissions

**Organization Owners** can:
- ✅ Create/remove runners
- ✅ Manage runner groups
- ✅ View runner activity
- ✅ Create organization secrets

**Repository Admins** can:
- ✅ Use runners in workflows
- ✅ View runner logs (if accessible)

### Audit Trail

View runner activity:
1. Go to: https://github.com/organizations/infrastructure-alexson/settings/audit-log
2. Filter by "Actions" for runner-related events
3. See all runner registration, usage, and removal

---

## 📈 Scaling Guidelines

### Recommended Configuration

| Use Case | Runner Count | CPU | Memory | Notes |
|----------|--------------|-----|--------|-------|
| **Small Org** (1-5 repos) | 1-2 | 2-4 | 4-8GB | Start small |
| **Medium Org** (5-20 repos) | 3-5 | 4-8 | 8-16GB | Parallel execution |
| **Large Org** (20+ repos) | 5+ | 8+ | 16+ GB | Load balancing |

### Capacity Planning

```
Concurrent Jobs = Number of Runners

Example:
- 3 runners = 3 concurrent jobs
- Each runner: 2 CPU, 4GB RAM
- Total: 6 CPU, 12GB RAM reserved
```

### Performance Tips

✅ Use runner labels for efficient distribution  
✅ Configure appropriate resource limits  
✅ Monitor CPU/memory usage  
✅ Add runners before hitting capacity  
✅ Use multiple runners for parallel workflows  

---

## 🔧 Maintenance Tasks

### Weekly
- [ ] Check runner status in GitHub UI
- [ ] Review runner logs for errors
- [ ] Verify network connectivity

### Monthly
- [ ] Pull latest runner image
  ```bash
  docker pull docker.io/salexson/github-actions-runner-podman:latest
  ```
- [ ] Rotate organization secret (if needed)
- [ ] Review runner usage statistics

### Quarterly
- [ ] Rotate `GHA_ACCESS_TOKEN` secret
- [ ] Update organization secret settings
- [ ] Review and adjust runner labels
- [ ] Plan capacity for next quarter

---

## 🚨 Troubleshooting

### Runner Not Appearing

**Check**:
1. Token is valid (< 1 hour old) ✅
2. Runner registration completed ✅
3. Docker container is running ✅
4. Network connectivity to github.com ✅

**Solution**:
```bash
# Regenerate token
# Update RUNNER_TOKEN in .env
# Restart runner
docker-compose restart github-runner
```

### Runner Offline

**Check**:
1. Container is running: `docker ps`
2. Logs for errors: `docker-compose logs`
3. GitHub connectivity: `curl https://github.com`

**Solution**:
```bash
# Restart runner
docker-compose down
docker-compose up -d

# Or restart container
docker-compose restart github-runner
```

### Workflows Not Running

**Check**:
1. Runner has matching labels ✅
2. Only organization runners available ✅
3. Runner is in "Idle" status ✅

**Solution**:
```yaml
# Verify workflow labels match runner labels
runs-on: [self-hosted, organization]  # Match your runner labels
```

---

## 📚 Related Documentation

### Organization Setup
- **[DEPLOYMENT-WITH-ORG-SECRET.md](DEPLOYMENT-WITH-ORG-SECRET.md)** - Secure token setup
- **[ORG-SECRET-DEPLOYMENT-SUMMARY.md](ORG-SECRET-DEPLOYMENT-SUMMARY.md)** - Quick reference

### General Deployment
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - All deployment options
- **[SECURITY.md](SECURITY.md)** - Security best practices
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Troubleshooting guide

### All Documentation
- **[INDEX.md](INDEX.md)** - Full documentation index

---

## ✅ Organization Setup Checklist

- [ ] Organization secret `GHA_ACCESS_TOKEN` created
- [ ] Runner registration token generated
- [ ] Repository cloned
- [ ] .env file configured
- [ ] Runners deployed (docker-compose up -d)
- [ ] Runners appear in GitHub settings
- [ ] Test workflow created and passed
- [ ] Labels configured correctly
- [ ] Workflows using organization runners
- [ ] Monitoring and maintenance plan in place

---

## 🎯 Next Steps

1. **Deploy First Runner**
   ```bash
   docker-compose up -d
   ```

2. **Verify in GitHub**
   - https://github.com/organizations/infrastructure-alexson/settings/actions/runners

3. **Run Test Workflow**
   - Create and trigger test workflow

4. **Start Using Runners**
   - Update repository workflows to use `runs-on: self-hosted`

5. **Monitor and Scale**
   - Monitor runner usage
   - Add more runners as needed

---

## 📞 Support

### Documentation
- Quick Start: [QUICK-REFERENCE.md](QUICK-REFERENCE.md)
- This Guide: [ORGANIZATION-SETUP.md](ORGANIZATION-SETUP.md)
- All Docs: [INDEX.md](INDEX.md)

### GitHub Resources
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Organization Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

---

**Status**: ✅ Ready for Organization Deployment  
**Date**: November 6, 2025  
**Version**: 1.0.0

