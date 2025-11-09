#!/bin/bash
# Bootstrap script to install Ansible and run the AI setup playbook

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check Ubuntu version
    if [[ $(lsb_release -rs) != "22.04" ]]; then
        error "This script requires Ubuntu 22.04 LTS"
    fi
    
    # Check internet connectivity
    if ! curl -s --connect-timeout 5 https://google.com > /dev/null 2>&1; then
        error "Internet connectivity required"
    fi
    
    # Check sudo access
    if ! sudo true; then
        error "This script requires sudo privileges"
    fi
    
    log "Prerequisites check passed"
}

install_ansible() {
    log "Installing Ansible..."
    
    # Update package cache
    sudo apt update
    
    # Install Ansible
    sudo apt install -y ansible
    
    # Verify installation
    ansible --version
    
    log "Ansible installed successfully"
}

run_playbook() {
    log "Running AI system setup playbook..."
    
    cd "$(dirname "$0")"
    
    # Detect the real user (not root even when running with sudo)
    REAL_USER="${SUDO_USER:-${USER}}"
    if [[ "$REAL_USER" == "root" ]]; then
        # Last resort: get user from /home directory
        REAL_USER=$(ls /home | head -1)
    fi
    
    info "Detected real user: $REAL_USER"
    info "Using the fixed playbook that avoids become hanging issues..."
    info "Running with maximum verbosity to debug any hanging issues..."
    
    # Check if we can sudo without password
    if sudo -n true 2>/dev/null; then
        info "Passwordless sudo detected. Running playbook..."
        ansible-playbook setup-ai-system.yml -v --extra-vars "target_user=$REAL_USER"
    else
        info "Sudo password will be requested by the playbook when needed."
        # Run the playbook that handles sudo internally
        ansible-playbook setup-ai-system.yml -v --extra-vars "target_user=$REAL_USER"
    fi
    
    log "Playbook execution completed"
}

show_completion_message() {
    echo -e "\n${GREEN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║              ANSIBLE SETUP COMPLETED!                        ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo -e "${BLUE}=== IMPORTANT NEXT STEPS ===${NC}"
    echo -e "1. ${YELLOW}REBOOT YOUR SYSTEM${NC} to ensure all changes take effect"
    echo -e "2. After reboot, test the installation:"
    echo -e "   ${GREEN}cd $(pwd)/../tests${NC}"
    echo -e "   ${GREEN}./test-rocm-docker.sh${NC}"
    echo -e ""
    echo -e "3. Start using your AI environment:"
    echo -e "   ${GREEN}cd ~/Projects${NC}"
    echo -e "   ${GREEN}cp $(pwd)/../templates/docker-compose.ai-template.yml docker-compose.yml${NC}"
    echo -e "   ${GREEN}docker compose up -d pytorch-rocm${NC}"
    echo -e ""
    echo -e "${BLUE}=== TO RE-RUN THIS SETUP ===${NC}"
    echo -e "Simply run: ${GREEN}./bootstrap.sh${NC}"
    echo -e "Ansible is idempotent - safe to run multiple times!"
}

main() {
    echo -e "${BLUE}AI ROCm Docker Setup - Ansible Bootstrap${NC}"
    echo -e "This will install Ansible and run the setup playbook\n"
    
    check_prerequisites
    
    # Check if Ansible is already installed
    if ! command -v ansible &> /dev/null; then
        install_ansible
    else
        info "Ansible already installed: $(ansible --version | head -1)"
    fi
    
    run_playbook
    show_completion_message
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi