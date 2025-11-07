# Podman-Only with Docker Compatibility - Design Decision

**Date**: November 6, 2025  
**Status**: ✅ Final Decision  
**Base Image**: UBI 9 Minimal  
**Container Tools**: Podman + podman-docker

---

## 📋 Overview

The GitHub Actions runner uses **Podman as the primary container tool** with **podman-docker compatibility layer** for Docker command support.

### Why This Approach?

✅ **Aligned with UBI 9** - Red Hat's native container solution  
✅ **Simpler** - One tool to manage, not two  
✅ **More Secure** - Podman supports rootless containers  
✅ **Cleaner** - Minimal image, no Docker daemon overhead  
✅ **Docker Compatible** - `docker` commands work via podman-docker  

---

## 🎯 What's Included

### **Primary: Podman**
- Native container runtime
- Rootless support (more secure)
- Drop-in Docker replacement
- Podman socket mounting support

### **Compatibility: podman-docker**
- Provides `docker` command wrapper
- Routes Docker commands to Podman
- Seamless compatibility for existing workflows
- No Docker daemon needed

### **Supporting Tools**
- **Buildah** - Advanced container image building
- **Skopeo** - Container image utilities (copy, inspect, etc.)

---

## ✅ Benefits

### **Simplicity**
- One container runtime to maintain
- Smaller image (~350MB)
- Fewer dependencies

### **Security**
- Podman supports rootless containers
- No daemon listening on socket
- Better isolation
- Recommended for CI/CD

### **Ecosystem Alignment**
- UBI 9 + Podman = Red Hat standard
- Long-term support consistency
- Enterprise-grade backing

### **Compatibility**
- `docker` commands work transparently
- Existing CI/CD workflows compatible
- No code changes needed

---

## 🔄 How Docker Compatibility Works

### **Docker Commands Work**
```bash
# These all work via podman-docker
docker build -t myapp .
docker push myrepo/myapp:latest
docker run --rm myapp:latest
docker-compose up -d
```

### **Transparent Translation**
```
docker command → podman-docker wrapper → podman execution
```

### **No Docker Daemon**
- No listening socket
- No separate daemon process
- More secure, lighter weight

---

## 📦 Container Tools Summary

| Tool | Purpose | Status |
|------|---------|--------|
| **Podman** | Container runtime | ✅ Primary |
| **podman-docker** | Docker compatibility | ✅ Wrapper |
| **Buildah** | Image building | ✅ Advanced option |
| **Skopeo** | Image utilities | ✅ Utility |

---

## 🚀 Usage Examples

### **Building Container Images**

```yaml
# Works with podman or docker command
jobs:
  build:
    runs-on: self-hosted
    steps:
      - name: Build container image
        run: |
          docker build -t myapp:latest .
          docker push myrepo/myapp:latest
```

### **Docker Compose**

```yaml
# docker-compose works via podman-docker
jobs:
  test:
    runs-on: self-hosted
    steps:
      - name: Start services
        run: docker-compose up -d
      
      - name: Run tests
        run: docker-compose exec app pytest
      
      - name: Cleanup
        run: docker-compose down
```

### **Using Podman Directly (Recommended)**

```yaml
# Can also use podman directly for rootless benefits
jobs:
  build:
    runs-on: self-hosted
    steps:
      - name: Build with Podman
        run: |
          podman build -t myapp:latest .
          podman push myapp:latest
```

### **Advanced Builds with Buildah**

```yaml
# Buildah for low-level image construction
jobs:
  advanced:
    runs-on: self-hosted
    steps:
      - name: Build with Buildah
        run: |
          buildah bud -t myapp:latest .
          buildah push myapp:latest
```

---

## 🔐 Security Advantages

### **Rootless Containers**
- Podman can run without root
- Containers don't escalate privileges
- Safer for shared environments

### **No Daemon**
- Podman runs containers as separate processes
- No listening socket to exploit
- Better security isolation

### **Pod Support**
- Podman natively supports pods (multiple containers)
- Better resource management
- Container grouping capabilities

---

## 📊 Size & Performance

### **Image Size**
- **Podman-only**: ~350MB (optimal)
- Docker included would be: ~360MB (+10MB)
- Still 50% smaller than Ubuntu-based alternatives

### **Performance**
- ✅ Same speed as Docker
- ✅ Faster socket access (no daemon overhead)
- ✅ Lower memory footprint

---

## 🔄 Migration Path

### **If You Have Docker Workflows**

**Good news**: They work unchanged!

```yaml
# This continues to work
- run: docker build -t app .

# podman-docker translates it to:
- run: podman build -t app .
```

### **To Use Podman Directly (Recommended)**

Simply use `podman` instead of `docker`:

```yaml
# Leverage Podman's advantages
- run: podman build -t app .
- run: podman push app:latest
```

---

## 📚 Documentation

### **For Podman Usage**
→ `doc/QUICK-REFERENCE.md`  
→ `doc/ORGANIZATION-SETUP.md`

### **For Building Images**
→ See workflow examples above

### **For Advanced Use**
→ [Podman Documentation](https://podman.io/)  
→ [Buildah Documentation](https://buildah.io/)

---

## ✨ Why This Design?

### **Decision Factors**

1. **UBI 9 + Podman** = Recommended pairing
   - Red Hat's official combination
   - Long-term support aligned
   - Security-first design

2. **Simplicity > Feature Bloat**
   - One tool is easier to maintain
   - Fewer potential conflicts
   - Clearer mental model

3. **Security First**
   - Rootless containers
   - No daemon attack surface
   - Better for CI/CD environments

4. **Compatibility**
   - podman-docker makes transition seamless
   - Existing workflows continue working
   - Users can gradually adopt Podman benefits

---

## 🎯 When to Use Each Command

### **Use `docker` command when...**
- Converting existing Docker workflows
- Teams familiar with Docker commands
- Compatibility with Docker tooling

### **Use `podman` command when...**
- Building new workflows
- Leveraging rootless features
- Long-term maintainability
- Performance optimization

### **Use `buildah` when...**
- Advanced image building
- Fine-grained control
- Complex layer operations

---

## 🔐 Best Practices

### **For Workflow Authors**
```yaml
# Podman is recommended for new workflows
- run: podman build -t myapp .
- run: podman push myapp:latest

# But docker commands also work
- run: docker build -t myapp .  # Works via podman-docker
```

### **For Configuration**
```bash
# Mount Podman socket for container operations
-v /var/run/podman/podman.sock:/var/run/podman/podman.sock

# Or use rootless mode (even more secure)
-v $XDG_RUNTIME_DIR/podman/podman.sock:/run/podman/podman.sock
```

---

## 📋 Checklist

- [x] Podman installed as primary tool
- [x] podman-docker for compatibility
- [x] Buildah for advanced builds
- [x] Skopeo for utilities
- [x] UBI 9 aligned approach
- [x] Simpler, cleaner design
- [x] More secure
- [x] Docker compatibility maintained

---

## ✅ Summary

✅ **Primary**: Podman (secure, rootless capable)  
✅ **Compatibility**: podman-docker (docker commands work)  
✅ **Advanced**: Buildah (powerful image building)  
✅ **Utilities**: Skopeo (image operations)  
✅ **Aligned**: UBI 9 + Podman = Red Hat standard  
✅ **Secure**: Rootless support, no daemon overhead  
✅ **Simple**: One tool, fewer dependencies  

---

**Status**: ✅ Podman-Only with Docker Compatibility  
**Date**: November 6, 2025  
**Base Image**: UBI 9 Minimal  
**Design**: Enterprise-grade, secure, aligned


