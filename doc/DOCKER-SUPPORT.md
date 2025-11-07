# Docker Support in GitHub Actions Runner

**Date**: November 6, 2025  
**Base Image**: UBI 9 Minimal  
**Docker Version**: Latest from UBI 9  
**Status**: ✅ Integrated & Ready

---

## 📋 Overview

The GitHub Actions runner container now includes **Docker support** alongside the existing Podman support, allowing you to build container images using either Docker or Podman.

### ✅ What's Included

- ✅ **Docker daemon** - Full Docker support
- ✅ **docker-compose** - Docker Compose for multi-container workflows
- ✅ **Podman** - Alternative container runtime
- ✅ **Buildah** - Low-level container image builder
- ✅ **Skopeo** - Container image utilities

---

## 🎯 Use Cases

### Docker in Workflows

**Build Docker images**:
```yaml
jobs:
  build:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      - name: Build Docker image
        run: |
          docker build -t myapp:latest .
          docker tag myapp:latest myrepo/myapp:latest
```

**Docker Compose orchestration**:
```yaml
jobs:
  test:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      - name: Start services
        run: docker-compose up -d
      - name: Run tests
        run: docker-compose exec app pytest
```

**Multi-architecture builds**:
```yaml
jobs:
  build-multiarch:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      - name: Build for multiple architectures
        run: |
          docker buildx build --platform linux/amd64,linux/arm64 \
            -t myrepo/app:latest .
```

### Podman in Workflows

**Build with Podman** (alternative to Docker):
```yaml
jobs:
  build:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      - name: Build Podman image
        run: |
          podman build -t myapp:latest .
          podman push myapp:latest
```

**Buildah for advanced builds**:
```yaml
jobs:
  buildah:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      - name: Build with Buildah
        run: |
          buildah bud -t myapp:latest .
          buildah push myapp:latest
```

---

## 🔧 Docker Configuration

### Docker Socket Access

The runner is configured to access the Docker socket. Workflows can use Docker by default:

```yaml
- name: Use Docker
  run: docker ps
```

### Docker Group Permissions

The `runner` user has Docker group permissions:

```bash
# Automatically available
docker run --rm hello-world
```

### Docker Daemon

Docker daemon is available and can be started if needed:

```yaml
- name: Start Docker if needed
  run: docker version
```

---

## 📦 Container Tools Summary

| Tool | Purpose | Usage |
|------|---------|-------|
| **Docker** | Container runtime & image builder | `docker build`, `docker run` |
| **docker-compose** | Multi-container orchestration | `docker-compose up -d` |
| **Podman** | Alternative container runtime | `podman build`, `podman run` |
| **Buildah** | Low-level container builder | `buildah bud`, advanced builds |
| **Skopeo** | Container image utilities | `skopeo copy`, image inspection |

---

## 🚀 Building Container Images

### Using Docker

```bash
# Build image
docker build -t myapp:latest .

# Tag image
docker tag myapp:latest myrepo/myapp:latest

# Push to registry
docker push myrepo/myapp:latest
```

### Using Podman

```bash
# Build image
podman build -t myapp:latest .

# Tag image
podman tag myapp:latest myrepo/myapp:latest

# Push to registry
podman push myrepo/myapp:latest
```

### Using Buildah

```bash
# Build image with Buildah
buildah bud -t myapp:latest .

# Push with Buildah
buildah push myapp:latest myrepo/myapp:latest
```

---

## 🔐 Security Considerations

### Docker Socket Mounting

When running the GitHub Actions runner, mount the Docker socket:

```bash
docker run -d \
  --name github-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e GITHUB_REPOSITORY="org/repo" \
  -e RUNNER_TOKEN="token" \
  github-action-runner:latest
```

### Podman Socket (Alternative)

For Podman-based systems:

```bash
podman run -d \
  --name github-runner \
  -v /var/run/podman/podman.sock:/var/run/podman/podman.sock \
  -e GITHUB_REPOSITORY="org/repo" \
  -e RUNNER_TOKEN="token" \
  github-action-runner:latest
```

### Security Best Practices

✅ **Don't expose credentials** in Dockerfiles  
✅ **Use Docker secrets** for sensitive data  
✅ **Keep images minimal** - avoid unnecessary packages  
✅ **Scan images** for vulnerabilities  
✅ **Use multi-stage builds** to reduce image size  

---

## 📋 Common Docker Workflows

### CI/CD Pipeline with Docker

```yaml
name: Build and Test
on: [push, pull_request]

jobs:
  build:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Docker image
        run: docker build -t myapp:${{ github.sha }} .
      
      - name: Run tests
        run: docker run --rm myapp:${{ github.sha }} pytest
      
      - name: Push to registry
        run: |
          docker tag myapp:${{ github.sha }} myrepo/myapp:latest
          docker push myrepo/myapp:latest
```

### Docker Compose Integration Testing

```yaml
name: Integration Tests
on: [push]

jobs:
  test:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      
      - name: Start services
        run: docker-compose up -d
      
      - name: Wait for services
        run: sleep 10
      
      - name: Run integration tests
        run: |
          docker-compose exec -T app \
            python -m pytest tests/integration/
      
      - name: Cleanup
        if: always()
        run: docker-compose down -v
```

### Multi-Architecture Build

```yaml
name: Multi-Arch Build
on: [push]

jobs:
  build:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Docker Buildx
        run: docker buildx create --use
      
      - name: Build and push
        run: |
          docker buildx build \
            --platform linux/amd64,linux/arm64 \
            -t myrepo/app:latest \
            --push .
```

---

## 🐛 Troubleshooting

### Docker Command Not Found

**Check if Docker is installed**:
```yaml
- name: Check Docker
  run: docker --version
```

**Install Docker if needed** (in workflow):
```yaml
- name: Install Docker
  run: |
    sudo apt-get update
    sudo apt-get install -y docker.io
```

### Permission Denied

**Problem**: `permission denied while trying to connect to Docker daemon`

**Solution**: Ensure Docker socket is mounted and runner user is in docker group:
```bash
docker run -d \
  -v /var/run/docker.sock:/var/run/docker.sock \
  github-action-runner:latest
```

### Docker Daemon Not Running

**Check daemon status**:
```yaml
- name: Docker daemon status
  run: docker ps
```

**Start daemon if needed**:
```yaml
- name: Start Docker daemon
  run: sudo systemctl start docker
```

### Out of Disk Space

**Problem**: Docker build fails with "No space left on device"

**Solution**: Clean up Docker resources:
```yaml
- name: Clean up Docker
  if: always()
  run: |
    docker system prune -af
    docker volume prune -f
```

---

## 🔄 Docker vs Podman in Runner

### Docker Advantages
✅ Industry standard  
✅ Widely supported  
✅ Docker Hub integration  
✅ Docker Compose stable  

### Podman Advantages
✅ Rootless containers  
✅ Better security isolation  
✅ Daemonless architecture  
✅ Drop-in Docker replacement  

### Using Both

You can use both Docker and Podman in the same workflow:

```yaml
jobs:
  test:
    runs-on: self-hosted
    steps:
      - name: Build with Docker
        run: docker build -t app-docker:latest .
      
      - name: Build with Podman
        run: podman build -t app-podman:latest .
      
      - name: Compare
        run: |
          echo "Docker images:"
          docker images
          echo "Podman images:"
          podman images
```

---

## 📚 Configuration Examples

### Docker Compose Setup

**docker-compose.yml**:
```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8000:8000"
    environment:
      - DEBUG=true
    volumes:
      - .:/app

  db:
    image: postgres:14
    environment:
      POSTGRES_PASSWORD: secret
    volumes:
      - db_data:/var/lib/postgresql/data

volumes:
  db_data:
```

**Workflow**:
```yaml
- name: Run with Docker Compose
  run: |
    docker-compose up -d
    docker-compose exec -T app python manage.py migrate
    docker-compose exec -T app pytest
    docker-compose down
```

---

## 🔐 Best Practices

### 1. Use Environment Variables

```yaml
- name: Build image
  env:
    REGISTRY: ${{ secrets.REGISTRY_URL }}
    IMAGE_TAG: ${{ github.sha }}
  run: docker build -t $REGISTRY/app:$IMAGE_TAG .
```

### 2. Clean Up Resources

```yaml
- name: Cleanup
  if: always()
  run: |
    docker system prune -af
    docker volume prune -f
    podman system prune -af
```

### 3. Use .dockerignore

```dockerfile
.git
.github
__pycache__
.pytest_cache
*.pyc
node_modules
dist
build
```

### 4. Multi-Stage Builds

```dockerfile
FROM node:18 as builder
WORKDIR /app
COPY . .
RUN npm install && npm run build

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
CMD ["node", "dist/index.js"]
```

### 5. Registry Authentication

```yaml
- name: Login to Docker Hub
  run: |
    echo ${{ secrets.DOCKERHUB_TOKEN }} | \
    docker login -u ${{ secrets.DOCKERHUB_USER }} --password-stdin

- name: Push image
  run: docker push myrepo/myapp:latest
```

---

## 📦 What's Available in Runner

```bash
# Check installed versions
docker --version
docker-compose --version
podman --version
buildah --version
skopeo --version
```

---

## 🚀 Performance Tips

### Image Caching

```yaml
- name: Build with cache
  run: |
    docker build \
      --cache-from myrepo/myapp:latest \
      -t myrepo/myapp:${{ github.sha }} .
```

### Parallel Builds

```yaml
jobs:
  build-amd64:
    runs-on: self-hosted
    steps:
      - name: Build amd64
        run: docker build -t app:amd64 .

  build-arm64:
    runs-on: self-hosted
    steps:
      - name: Build arm64
        run: docker build -t app:arm64 .
```

### Layer Optimization

```dockerfile
# Expensive operations early, frequently changing late
FROM node:18-alpine
RUN apk add --no-cache python3 make g++
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
```

---

## 📞 Support

### Documentation
- **Docker**: https://docs.docker.com/
- **Podman**: https://podman.io/
- **Buildah**: https://buildah.io/
- **Skopeo**: https://github.com/containers/skopeo

### Runner Setup
- `doc/ORGANIZATION-SETUP.md` - Organization deployment
- `doc/QUICK-REFERENCE.md` - Quick commands
- `README.md` - Project overview

---

## ✅ Summary

✅ **Docker installed** - Full Docker support  
✅ **docker-compose included** - Multi-container workflows  
✅ **Podman available** - Alternative runtime  
✅ **Buildah for advanced builds** - Low-level image building  
✅ **Skopeo for utilities** - Image inspection and copying  
✅ **Socket mounting supported** - Full functionality  
✅ **User permissions configured** - No special setup needed  

---

**Status**: ✅ Docker & Podman Support Ready  
**Base Image**: UBI 9 Minimal  
**Version**: 1.1.0  
**Ready for**: Production container image builds

