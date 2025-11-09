#!/bin/bash
# Verify AI System Setup Script
# This script runs the verification playbook with proper user context

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== AI System Verification ===${NC}"
echo -e "Running verification checks for user: ${GREEN}$(whoami)${NC}"
echo -e "Home directory: ${GREEN}$HOME${NC}"
echo ""

# Determine the script directory and ansible directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"

# Check if the ansible directory and verify-setup.yml exist
if [[ ! -d "$ANSIBLE_DIR" ]]; then
    echo -e "${RED}Error: ansible directory not found at $ANSIBLE_DIR${NC}"
    echo "Please ensure you're running this script from the ai-setup-scripts directory"
    exit 1
fi

if [[ ! -f "$ANSIBLE_DIR/verify-setup.yml" ]]; then
    echo -e "${RED}Error: verify-setup.yml not found in $ANSIBLE_DIR${NC}"
    echo "Please ensure the ansible playbook files are present"
    exit 1
fi

# Run the verification playbook with explicit user context
echo -e "${YELLOW}Running verification playbook from: ${ANSIBLE_DIR}${NC}"
echo ""

# Change to ansible directory and run the playbook
cd "$ANSIBLE_DIR"

# Use ansible-playbook with explicit user variables to avoid root context issues
ansible-playbook verify-setup.yml \
    --connection=local \
    --inventory=localhost, \
    --extra-vars "ansible_user=$(whoami)" \
    --extra-vars "ansible_user_dir=$HOME" \
    -v

RESULT=$?

echo ""
if [ $RESULT -eq 0 ]; then
    echo -e "${GREEN}=== Verification completed successfully! ===${NC}"
else
    echo -e "${RED}=== Verification failed with exit code $RESULT ===${NC}"
    echo -e "${YELLOW}This may be expected if directories haven't been created yet.${NC}"
fi

exit $RESULT