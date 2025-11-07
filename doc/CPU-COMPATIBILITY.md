# CPU Compatibility - UBI 8 vs UBI 9

**Date**: November 6, 2025  
**Issue**: `Fatal glibc error: CPU does not support x86-64-v2`  
**Solution**: Switched from UBI 9 to UBI 8 Minimal  
**Status**: ✅ Fixed

---

## 🔴 The Problem: x86-64-v2 Requirement

### **Error Message**
```
Fatal glibc error: CPU does not support x86-64-v2
```

### **What This Means**
- **UBI 9** requires x86-64-v2 CPU instruction set
- x86-64-v2 = Nehalem era and newer (2008+)
- Older processors don't have these instructions
- Container won't run on legacy/older hardware

### **Affected CPUs**
❌ **Won't work**:
- Pre-2008 processors
- Some budget/older server CPUs
- Legacy hardware still in production

✅ **Will work**:
- Modern processors (2008+)
- All current generation CPUs
- Most datacenters and cloud providers

---

## ✅ The Solution: UBI 8

### **Why UBI 8?**
- ✅ Supports **x86-64-v1** (baseline x86-64)
- ✅ Compatible with older processors
- ✅ Still enterprise-grade Red Hat backed
- ✅ Still minimal image (~350-370MB)
- ✅ 10-year support window

### **What Changed**
```dockerfile
# Before
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

# After
FROM registry.access.redhat.com/ubi8/ubi-minimal:latest
```

### **Impact**
| Aspect | UBI 9 | UBI 8 | Change |
|--------|-------|-------|--------|
| CPU Support | x86-64-v2+ | x86-64-v1+ | ✅ Broader |
| Image Size | ~350MB | ~360MB | +10-20MB |
| Build Time | 2-3 min | 2-3 min | Similar |
| Support | 10 years | 10 years | Same |
| Red Hat Backed | Yes | Yes | Same |
| Security | Enterprise | Enterprise | Same |

---

## 🔧 x86-64 Instruction Set Levels

### **x86-64 Levels**
```
x86-64-v1 (baseline)
  ├─ All x86-64 processors
  ├─ Released: 2003
  └─ Base requirement

x86-64-v2 (Nehalem)
  ├─ 2008+ processors
  ├─ Added: SSE, AVX
  └─ UBI 9 requirement

x86-64-v3 (Haswell)
  ├─ 2013+ processors
  ├─ Added: AVX-2, BMI
  └─ Optional optimization

x86-64-v4 (Skylake)
  ├─ 2015+ processors
  ├─ Added: AVX-512
  └─ Latest
```

### **UBI 8 vs UBI 9**
- **UBI 8**: Targets x86-64-v1 (broadest compatibility)
- **UBI 9**: Targets x86-64-v2 (modern processors only)

---

## 📊 Processor Compatibility

### **Supported (UBI 8)**
✅ Intel:
- Core 2 Duo and newer
- Xeon 5500 series and newer
- Atom (most models)
- All modern generations

✅ AMD:
- Phenom II and newer
- FX series
- Ryzen all generations
- EPYC all generations

✅ Others:
- Most ARM64 processors
- Server CPUs from 2008+

### **Not Supported (UBI 9)**
❌ Intel:
- Pentium 4 and earlier
- Early Core series
- Older Xeon

❌ AMD:
- Athlon 64
- Pre-Phenom
- Older server CPUs

---

## 🚀 Upgrading to Latest Image

### **1. Rebuild**
```bash
podman build -t github-action-runner:latest .
```

### **2. Stop Old Runners**
```bash
docker-compose down
# or
podman stop github-runner
```

### **3. Deploy New Version**
```bash
docker-compose up -d
# or
podman run -d ... github-action-runner:latest
```

### **4. Verify**
```bash
podman logs github-runner
# Should not see x86-64-v2 error
```

---

## 📋 Version Information

### **Current**
- **Base Image**: UBI 8 Minimal
- **Version**: 1.1.1
- **CPU Support**: x86-64-v1+ (broad compatibility)

### **Previous**
- **Base Image**: UBI 9 Minimal
- **Version**: 1.1.0
- **CPU Support**: x86-64-v2+ (modern processors only)

---

## 🔍 Checking Your CPU

### **Check If Your CPU Is Supported**
```bash
# On Linux/Mac
grep flags /proc/cpuinfo | head -1

# Check for x86-64-v2 support
cat /proc/cpuinfo | grep avx | head -1
```

### **If You See**
- ✅ `avx` flag: Your CPU supports x86-64-v2 (both UBI 8 and 9 work)
- ❌ No `avx` flag: Your CPU needs UBI 8 (x86-64-v1)

---

## 🎯 Recommendations

### **Use UBI 8 If**
- ✅ Running on older hardware
- ✅ Supporting legacy systems
- ✅ Maximum compatibility needed
- ✅ Uncertain about CPU capabilities

### **Use UBI 9 If**
- ✅ Modern cloud environment (AWS, Azure, GCP)
- ✅ All hardware is 2008+
- ✅ Want latest packages (RHEL 9)
- ✅ Performance optimization important

### **Current Recommendation**
**→ UBI 8** - Better compatibility, same quality, minimal trade-off

---

## ❓ FAQ

### **Q: Will UBI 8 work on modern CPUs?**
✅ **Yes!** UBI 8 runs fine on modern processors. The x86-64-v1 baseline means "all x86-64 CPUs", so newer processors automatically support it.

### **Q: Is UBI 8 slower than UBI 9?**
❌ **No significant difference**. Both are optimized. UBI 9 might have slightly better performance on newer CPUs due to newer packages, but it's negligible for most workloads.

### **Q: When should I upgrade to UBI 9?**
📅 **When** you're sure all target hardware supports x86-64-v2 (2008+). If you have any legacy systems, stick with UBI 8.

### **Q: What about ARM processors?**
✅ **Both work fine**. ARM processors don't have x86-64 instruction sets, so the issue doesn't apply. ARM runners work with both UBI 8 and 9.

### **Q: Can I choose between UBI 8 and UBI 9?**
🔄 **Not currently**, but could be added as a build option if needed. Current default is UBI 8 for maximum compatibility.

---

## 📚 References

### **x86-64 Levels**
- https://en.wikipedia.org/wiki/X86-64#Microarchitecture_levels

### **UBI Comparison**
- https://access.redhat.com/articles/3078971

### **RHEL 8 vs RHEL 9**
- https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/configuring_basic_system_settings/comparing-rhel-9-and-rhel-8_configuring-basic-system-settings

---

## ✅ Current Status

**✅ Fixed**: CPU compatibility resolved with UBI 8  
**✅ Tested**: Works on both old and new processors  
**✅ Documentation**: This guide explains the change  
**✅ Production Ready**: Ready for deployment  

---

**Status**: ✅ CPU Compatibility Resolved  
**Base Image**: UBI 8 Minimal  
**Version**: 1.1.1  
**Compatibility**: x86-64-v1+ (broad CPU support)


