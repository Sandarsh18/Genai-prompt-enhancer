#!/bin/bash
# ========================================
# Ansible Quick Start Demo Script
# ========================================
# This script demonstrates how to use Ansible
# to automate the entire project setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Ansible Quick Start Demo${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if Ansible is installed
if ! command -v ansible &> /dev/null; then
    echo -e "${YELLOW}Ansible is not installed.${NC}"
    echo -e "${YELLOW}Install it with: sudo apt install ansible -y${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Ansible is installed${NC}"
ansible --version | head -1
echo ""

# Change to ansible directory
cd "$ANSIBLE_DIR"

# Function to run playbook with summary
run_playbook() {
    local playbook=$1
    local description=$2
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Running: $playbook${NC}"
    echo -e "${BLUE}Purpose: $description${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Ask for confirmation
    read -p "Do you want to run this playbook? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ansible-playbook "playbooks/$playbook" || {
            echo -e "${RED}✗ Playbook failed${NC}"
            return 1
        }
        echo -e "${GREEN}✓ Playbook completed successfully${NC}"
        echo ""
    else
        echo -e "${YELLOW}⊘ Skipped${NC}"
        echo ""
    fi
}

# Show menu
echo -e "${YELLOW}What would you like to do?${NC}"
echo ""
echo "1) Run complete setup (all playbooks)"
echo "2) Run setup-environment.yml only"
echo "3) Run install-docker.yml only"
echo "4) Run install-kubernetes.yml only"
echo "5) Run deploy-application.yml only"
echo "6) Run monitoring-setup.yml only"
echo "7) Check Ansible syntax (all playbooks)"
echo "8) View Ansible configuration"
echo "9) Exit"
echo ""
read -p "Choose an option (1-9): " choice

case $choice in
    1)
        echo -e "${BLUE}Running complete setup...${NC}"
        echo ""
        run_playbook "setup-environment.yml" "Install system dependencies"
        run_playbook "install-docker.yml" "Install Docker and Docker Compose"
        
        echo -e "${YELLOW}========================================${NC}"
        echo -e "${YELLOW}IMPORTANT: You need to log out and log back in${NC}"
        echo -e "${YELLOW}for Docker group changes to take effect${NC}"
        echo -e "${YELLOW}========================================${NC}"
        echo ""
        read -p "Press Enter to continue after logging back in..."
        
        run_playbook "install-kubernetes.yml" "Install Kubernetes tools"
        run_playbook "deploy-application.yml" "Deploy the application"
        run_playbook "monitoring-setup.yml" "Setup monitoring stack"
        ;;
    2)
        run_playbook "setup-environment.yml" "Install system dependencies"
        ;;
    3)
        run_playbook "install-docker.yml" "Install Docker and Docker Compose"
        echo -e "${YELLOW}⚠ Remember to log out and log back in${NC}"
        ;;
    4)
        run_playbook "install-kubernetes.yml" "Install Kubernetes tools"
        ;;
    5)
        run_playbook "deploy-application.yml" "Deploy the application"
        ;;
    6)
        run_playbook "monitoring-setup.yml" "Setup monitoring stack"
        ;;
    7)
        echo -e "${BLUE}Checking syntax of all playbooks...${NC}"
        echo ""
        for playbook in playbooks/*.yml; do
            echo -e "${YELLOW}Checking: $(basename $playbook)${NC}"
            ansible-playbook "$playbook" --syntax-check
            echo -e "${GREEN}✓ Syntax OK${NC}"
            echo ""
        done
        ;;
    8)
        echo -e "${BLUE}Ansible Configuration:${NC}"
        echo ""
        cat ansible.cfg
        echo ""
        echo -e "${BLUE}Inventory:${NC}"
        echo ""
        cat inventory.ini
        ;;
    9)
        echo "Goodbye!"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Demo Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Useful Commands:${NC}"
echo "  Check logs:     cat $ANSIBLE_DIR/ansible.log"
echo "  View playbook:  cat $ANSIBLE_DIR/playbooks/deploy-application.yml"
echo "  Run with tags:  ansible-playbook playbooks/deploy-application.yml --tags test"
echo "  Dry run:        ansible-playbook playbooks/deploy-application.yml --check"
echo "  Verbose:        ansible-playbook playbooks/deploy-application.yml -vvv"
echo ""
