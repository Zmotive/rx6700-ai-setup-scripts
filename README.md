# AI ROCm Docker Setup

Complete installation scripts for setting up a minimal Ubuntu 22.04 LTS system optimized for AI workloads using AMD GPUs with ROCm and Docker.

## System Requirements

- **Ubuntu 22.04 LTS** (Jammy Jellyfish)
- **AMD GPU** (RDNA, RDNA2, or newer recommended)
- **Minimum 8GB RAM** (16GB+ recommended for AI workloads)
- **50GB+ free disk space**
- **Internet connection** for package downloads
- **sudo privileges**

## Supported AMD GPUs

- RX 6000 series (RDNA2) - **Recommended**
- RX 7000 series (RDNA3) - **Recommended**  
- RX 5000 series (RDNA)
- Vega series (limited support)

## Why Ansible?

This project uses **Ansible** for infrastructure as code, providing several key benefits:

### ✅ **Idempotent Operations**
- **Safe to run multiple times** - Won't break if re-executed
- **Only changes what's needed** - Skips already-configured items
- **No side effects** - Predictable, consistent results

### 🎯 **Declarative Configuration**
- **Describe desired state** - Not step-by-step instructions
- **Self-documenting** - YAML clearly shows what's configured
- **Version controlled** - Track all changes in Git

### 🏷️ **Modular Execution**
- **Tagged tasks** - Run only specific components
- **Granular control** - Install ROCm without Docker, etc.
- **Easy debugging** - Test individual sections

### 📊 **Professional Reporting**
- **Detailed output** - See exactly what changed
- **Task-level feedback** - Know which steps succeeded/failed
- **Dry-run capability** - Preview changes before applying

## What Gets Installed

### System Components
- **ROCm 6.1** - AMD's ROCm platform for GPU computing
- **Docker CE** - Latest Docker Community Edition
- **Docker Compose** - Container orchestration
- **Base development tools** - build-essential, git, python3, etc.

### ROCm Packages
- Core ROCm runtime and libraries
- HIP development environment
- rocBLAS, rocFFT, rocSolver (math libraries)
- RCCL (communication library)
- MIOpen (deep learning primitives)

### Docker Configuration
- ROCm device access (`/dev/kfd`, `/dev/dri`)
- Proper group permissions (render, video, docker)
- Optimized daemon configuration
- AI-focused container templates

### Workspace Organization
- **Structured directories** - Organized project layout
- **Template files** - Ready-to-use Docker Compose configurations
- **Test scripts** - Verify everything works correctly

## Quick Start

```bash
git clone <repository-url> ai-setup-scripts
cd ai-setup-scripts/ansible
./bootstrap.sh
```

> **🎯 Why Ansible?** Idempotent, declarative, safe to run multiple times, and industry-standard for infrastructure management.

### 2. After Installation
**IMPORTANT**: Reboot your system after installation
```bash
sudo reboot
```

### 3. Verify Installation
```bash
cd ai-setup-scripts/ansible
ansible-playbook verify-setup.yml
```

Or test Docker integration:
```bash
cd ai-setup-scripts
./tests/test-rocm-docker.sh
```

## Ansible Playbook Features

### Run Complete Setup
```bash
cd ansible/
./bootstrap.sh  # Installs Ansible and runs full setup
```

### Run Specific Components
```bash
# Only install ROCm
ansible-playbook setup-ai-system.yml --tags rocm --ask-become-pass

# Only setup Docker
ansible-playbook setup-ai-system.yml --tags docker --ask-become-pass

# Only create workspace directories
ansible-playbook setup-ai-system.yml --tags workspace --ask-become-pass

# Only cleanup old installations
ansible-playbook setup-ai-system.yml --tags cleanup --ask-become-pass
```

### Verify Installation
```bash
# Full verification
ansible-playbook verify-setup.yml

# Check specific components
ansible-playbook verify-setup.yml --tags rocm,docker
```

## Usage Examples

### Start PyTorch Container
```bash
docker run -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add video \
  --group-add render \
  -v ~/Projects:/workspace/projects \
  -v ~/Models:/workspace/models \
  -v ~/DockerVolumes/jupyter:/workspace/jupyter \
  rocm/pytorch:latest
```

### Use Docker Compose Template
```bash
### Use Pre-configured Workspace
The installation automatically creates an organized folder structure:
```bash
# Folders created during installation:
~/DockerVolumes/     # Docker container persistent storage
├── jupyter/         # Jupyter notebooks and configs
├── tensorboard/     # TensorBoard logs
├── datasets/        # Training datasets
├── checkpoints/     # Model checkpoints
└── logs/           # Training logs

~/Models/           # AI models and weights
├── pytorch/        # PyTorch models
├── tensorflow/     # TensorFlow models
├── onnx/          # ONNX format models
└── huggingface/   # Hugging Face models

~/Projects/         # Your AI projects
├── ai-experiments/ # Experimental projects
├── training/      # Training scripts
└── inference/     # Inference projects

~/venvs/           # Python virtual environments
```

### Start with Docker Compose
```bash
cd ~/Projects
cp ~/ai-setup-scripts/templates/docker-compose.ai-template.yml docker-compose.yml
docker compose up -d pytorch-rocm
docker compose exec pytorch-rocm bash
```
```

### Test GPU in PyTorch
```python
import torch
print(f"ROCm available: {torch.cuda.is_available()}")
print(f"GPU device: {torch.cuda.get_device_name(0)}")

# Test GPU computation
x = torch.randn(1000, 1000).cuda()
y = torch.randn(1000, 1000).cuda()
z = torch.mm(x, y)
print(f"GPU computation successful: {z.shape}")
```

## Troubleshooting

### Common Issues

1. **No ROCm devices detected**
   - Ensure you're in the `render` and `video` groups
   - Reboot after installation
   - Check GPU compatibility

2. **Docker permission denied**
   - Ensure you're in the `docker` group
   - Log out and back in after installation
   - Or use `newgrp docker`

3. **Container can't access GPU**
   - Verify device mounting: `--device=/dev/kfd --device=/dev/dri`
   - Check group additions: `--group-add video --group-add render`

### Verification Commands
```bash
# Check ROCm installation
rocminfo | head -20
rocm-smi

# Check Docker access
docker run --rm hello-world

# Check GPU access in container
docker run --rm --device=/dev/kfd --device=/dev/dri \
  --group-add video --group-add render \
  rocm/rocm-terminal:latest rocminfo
```

### Clean Reinstallation
If you need to start over:
```bash
# Remove Docker
sudo apt remove -y docker-ce docker-ce-cli containerd.io
sudo rm -rf /var/lib/docker

# Remove ROCm
sudo apt remove -y rocm-dev rocm-libs
sudo rm -rf /opt/rocm*

# Run Ansible setup again
cd ansible/
ansible-playbook setup-ai-system.yml --ask-become-pass
```

### Preview Changes Before Applying
```bash
# See what would change without making changes
cd ansible/
ansible-playbook setup-ai-system.yml --check --diff
```

## File Structure

### Installation Scripts
```
ai-setup-scripts/
├── ansible/                        # Ansible playbooks for system setup
│   ├── bootstrap.sh                # Auto-install Ansible and run setup
│   ├── setup-ai-system.yml        # Main Ansible playbook
│   ├── verify-setup.yml           # Verification playbook
│   ├── inventory                   # Ansible inventory
│   ├── ansible.cfg                 # Ansible configuration
│   └── README.md                   # Ansible documentation
├── templates/                      # Templates and configuration files
│   └── docker-compose.ai-template.yml  # Docker Compose template
├── tests/                          # Test scripts
│   └── test-rocm-docker.sh         # ROCm Docker integration test
├── setup.log                       # Installation log (from previous runs)
├── .dockerignore                   # Docker ignore file
└── README.md                       # This file
```

### Created Workspace Structure
```
$HOME/
├── DockerVolumes/          # Docker volume mounts
│   ├── pytorch/           # PyTorch container data
│   ├── tensorflow/        # TensorFlow container data
│   ├── jupyter/           # Jupyter Lab data
│   └── shared/            # Shared data between containers
├── Models/                # AI model storage
├── Projects/              # Project workspaces
└── venvs/                 # Python virtual environments
```

## Support

- **ROCm Documentation**: https://rocm.docs.amd.com/
- **Docker Documentation**: https://docs.docker.com/
- **PyTorch ROCm**: https://pytorch.org/get-started/locally/

## Notes

- Installation requires internet connection for package downloads
- Total installation time: 15-30 minutes depending on internet speed
- Disk space required: ~25GB for full ROCm and AI framework installation
- System reboot required after installation for all changes to take effect