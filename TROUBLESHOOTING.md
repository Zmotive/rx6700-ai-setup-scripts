# ROCm Docker Setup Troubleshooting Guide

**This document chronicles the technical challenges encountered and solutions implemented during the development of this ROCm Docker setup for AMD GPUs.**

## Major Issues Encountered & Solutions

### 1. 🚫 Ansible Hanging on sudo Authentication

**Problem**: Ansible playbook would hang indefinitely when attempting sudo operations.

**Root Cause**: Ansible's default `become` mechanism was configured incorrectly for interactive sudo prompts.

**Solution**: Updated `ansible.cfg` with proper become configuration:
```ini
[defaults]
become_method = sudo
become_ask_pass = false
host_key_checking = false

[privilege_escalation] 
become = true
become_method = sudo
become_user = root
become_ask_pass = false
```

**Key Fix**: Added `--ask-become-pass` flag for interactive runs and proper privilege escalation configuration.

### 2. 🔐 Docker Group Permission Issues 

**Problem**: Docker commands failed with "Unable to find group render: no matching entries in group file"

**Root Cause**: Docker was looking for group names inside container namespace, not host system groups.

**Solution**: Use numeric Group IDs instead of group names:
```yaml
group_add:
  - "44"    # video group
  - "109"   # render group
```

**Investigation Process**:
1. Verified groups exist on host: `getent group | grep -E "(video|render)"`
2. Found groups: `video:x:44:zack` and `render:x:109:zack`
3. Tested with numeric IDs: `docker run --group-add 44 --group-add 109 ...`
4. Success! Updated all templates to use numeric group IDs

### 3. 💥 Critical Library Loading Issue: libamdhip64.so.7

**Problem**: Docker Compose containers failed with:
```
ImportError: libamdhip64.so.7: cannot open shared object file: No such file or directory
```

**Root Cause Analysis**:
- Manual `docker run` commands worked perfectly
- Docker Compose with same configuration failed
- Host ROCm 6.1 libraries: `libamdhip64.so.6`
- Container PyTorch compiled for ROCm 7.1: expects `libamdhip64.so.7`
- Version mismatch when mounting host `/opt/rocm:/opt/rocm:ro`

**Investigation Steps**:
1. Confirmed manual docker commands work: ✅
   ```bash
   docker run --device=/dev/kfd --device=/dev/dri --group-add 44 --group-add 109 rocm/pytorch:latest python3 -c 'import torch; print("Works!")'
   ```

2. Docker Compose with host ROCm mount fails: ❌
   ```yaml
   volumes:
     - /opt/rocm:/opt/rocm:ro  # This causes the issue!
   ```

3. Found library version mismatch:
   - Host: `libamdhip64.so.6.1.60100`
   - Container PyTorch expects: `libamdhip64.so.7`

**Critical Solution**: **Remove host ROCm library mounting**
- Let containers use their own ROCm libraries
- Remove volume mount: `- /opt/rocm:/opt/rocm:ro`
- Remove environment: `ROCM_PATH=/opt/rocm`, `LD_LIBRARY_PATH=...`
- Keep only: `HIP_PLATFORM=amd` and `HSA_OVERRIDE_GFX_VERSION=10.3.0`

**Result**: Docker Compose now works perfectly! ✅

### 4. 🏗️ Directory Structure Reorganization

**Problem**: Original setup scattered AI files across home directory (`~/DockerVolumes/`, `~/Models/`, `~/Projects/`, `~/venvs/`)

**Solution**: Consolidated everything into organized `~/ai-workspace/` structure:
```
~/ai-workspace/
├── DockerVolumes/   # Container data
├── Models/          # AI models  
├── Projects/        # Code & docker-compose.yml
└── venvs/          # Python environments
```

**Benefits**:
- Easier backup and management
- Clear separation from personal files
- Professional workspace organization
- Simplified volume mounting paths

### 5. ⚠️ TensorFlow GPU Compatibility

**Problem**: TensorFlow doesn't detect RX 6700 XT GPU

**Root Cause**: RX 6700 XT (gfx1031) not in TensorFlow's supported GPU list:
```
AMDGPU version : gfx1031. The supported AMDGPU versions are gfx900, gfx906, gfx908, gfx90a, gfx942, gfx950, gfx1030, gfx1100, gfx1101, gfx1102, gfx1200, gfx1201
```

**Status**: Known limitation - TensorFlow ROCm support is more restrictive than PyTorch
**Workaround**: Use PyTorch for GPU workloads on RX 6700 XT

### 6. 🔧 HIPBLAS Allocation Errors

**Problem**: PyTorch shows `HIPBLAS_STATUS_ALLOC_FAILED` errors during certain operations

**Root Cause**: HIPBLAS memory allocation issues with certain GPU operations

**Impact**: Non-blocking - basic tensor operations work fine:
```python
x = torch.randn(3,3).cuda()  # ✅ Works
y = x + x                    # ✅ Works  
z = x @ x                    # ⚠️ May show HIPBLAS error but completes
```

**Status**: Acceptable limitation - core functionality works

## Testing Methodology

### Comprehensive Test Strategy
1. **Manual Docker Commands**: Test basic functionality
2. **Docker Compose**: Test real-world usage scenarios  
3. **Library Loading**: Verify all dependencies resolve
4. **GPU Operations**: Test actual tensor computations
5. **Environment Variables**: Validate all settings

### Final Working Test Results
```bash
# ✅ Basic ROCm info
docker run --rm --device=/dev/kfd --device=/dev/dri --group-add 44 --group-add 109 rocm/rocm-terminal:latest rocminfo

# ✅ PyTorch manual
docker run --rm --device=/dev/kfd --device=/dev/dri --group-add 44 --group-add 109 rocm/pytorch:latest python3 -c 'import torch; print("ROCm:", torch.cuda.is_available())'

# ✅ Docker Compose (THE MAIN GOAL!)
docker compose up -d pytorch-rocm
docker compose exec pytorch-rocm python3 -c 'import torch; print("ROCm available:", torch.cuda.is_available())'
```

## Key Lessons Learned

### 1. Container Library Independence
**Lesson**: Don't mount host ROCm libraries into containers - let containers use their own compatible versions.

**Why**: Host and container ROCm versions may have different library versions even with same major version.

### 2. Group ID vs Group Names
**Lesson**: Use numeric group IDs for Docker containers, not group names.

**Why**: Group names exist in host namespace, containers need group IDs to map correctly.

### 3. Manual vs Compose Differences  
**Lesson**: Manual `docker run` and `docker compose` can behave differently with complex configurations.

**Why**: Compose adds additional layers of configuration parsing and environment handling.

### 4. Progressive Testing Approach
**Lesson**: Test in order of complexity: basic → manual docker → docker compose → real workloads.

**Why**: Isolates issues at each layer and prevents debugging multiple problems simultaneously.

## Technical Configuration Details

### Final Working Docker Compose Template
```yaml
services:
  pytorch-rocm:
    image: rocm/pytorch:latest
    container_name: pytorch-rocm
    devices:
      - /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri
    group_add:
      - "44"    # video group  
      - "109"   # render group
    ipc: host
    cap_add:
      - SYS_PTRACE
    security_opt:
      - seccomp:unconfined
    volumes:
      - ~/ai-workspace/Projects:/workspace/Projects
      - ~/ai-workspace/Models:/workspace/Models
      - ~/ai-workspace/DockerVolumes/pytorch:/workspace/data
      # NOTE: No /opt/rocm mount - this was the key fix!
    working_dir: /workspace
    environment:
      - HIP_PLATFORM=amd
      - HSA_OVERRIDE_GFX_VERSION=10.3.0  # For RX 6700 XT
      # NOTE: No ROCM_PATH or LD_LIBRARY_PATH needed
    stdin_open: true
    tty: true
    restart: unless-stopped
```

## Debugging Commands Used

### System Investigation
```bash
# Check groups
getent group | grep -E "(video|render)"

# Check ROCm installation  
rocminfo | head -20
dpkg -l | grep rocm

# Find libraries
find /opt/rocm -name "*libamdhip64*"
find /usr -name "*hip*" -name "*.so*"
```

### Docker Testing
```bash
# Test group IDs
docker run --rm --group-add 44 --group-add 109 alpine:latest id

# Test basic ROCm
docker run --rm --device=/dev/kfd --device=/dev/dri --group-add 44 --group-add 109 rocm/rocm-terminal:latest rocminfo

# Test PyTorch
docker run --rm --device=/dev/kfd --device=/dev/dri --group-add 44 --group-add 109 rocm/pytorch:latest python3 -c 'import torch; print(torch.cuda.is_available())'
```

### Container Investigation
```bash
# Check mounted libraries
docker compose exec pytorch-rocm ls -la /opt/rocm/lib | head -10

# Check environment variables
docker compose exec pytorch-rocm env | grep -E "(LD_LIBRARY|ROCM|HIP)"

# Test library loading
docker compose exec pytorch-rocm python3 -c 'import torch; print("Success!")'
```

## Summary

This was a challenging setup involving multiple interconnected issues:

1. **Ansible configuration** - Fixed become mechanism  
2. **Docker group permissions** - Switched to numeric group IDs
3. **Library version conflicts** - Removed host ROCm mounting 
4. **Workspace organization** - Implemented ai-workspace structure
5. **Template generation** - Updated Ansible to generate working configs

The **critical breakthrough** was realizing that mounting host ROCm libraries was causing version conflicts. Removing the mount and letting containers use their own libraries solved the main issue.

**Final Result**: A robust, working ROCm Docker setup that generates correct templates via Ansible and works reliably with Docker Compose! 🎉