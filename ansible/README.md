# 🔧 Ansible Automation for GenAI Prompt Enhancer

## 📋 Overview

This directory contains Ansible playbooks for automating the setup, deployment, and monitoring of the GenAI Prompt Enhancer application. Ansible provides **Infrastructure as Code (IaC)** capabilities, making the entire DevOps pipeline repeatable and consistent.

---

## 📁 Directory Structure

```
ansible/
├── ansible.cfg              # Ansible configuration (behavior, logging, defaults)
├── inventory.ini            # Target hosts definition (localhost for lab/demo)
├── playbooks/               # Automation playbooks
│   ├── setup-environment.yml      # Install system dependencies
│   ├── install-docker.yml         # Install Docker & Docker Compose
│   ├── install-kubernetes.yml     # Install kubectl, minikube, helm
│   ├── deploy-application.yml     # Deploy the application (local/K8s)
│   └── monitoring-setup.yml       # Setup Prometheus & Grafana
└── README.md                # This file
```

---

## 🚀 Quick Start Guide

### Prerequisites
```bash
# Install Ansible (if not already installed)
sudo apt update
sudo apt install ansible -y

# Verify installation
ansible --version
```

### Execution Order

Run playbooks in this sequence:

```bash
# 1. Setup system environment (FIRST TIME ONLY)
ansible-playbook playbooks/setup-environment.yml

# 2. Install Docker (FIRST TIME ONLY)
ansible-playbook playbooks/install-docker.yml
# Note: Log out and log back in after this step

# 3. Install Kubernetes tools (FIRST TIME ONLY)
ansible-playbook playbooks/install-kubernetes.yml

# 4. Deploy the application
ansible-playbook playbooks/deploy-application.yml

# 5. Setup monitoring (OPTIONAL)
ansible-playbook playbooks/monitoring-setup.yml
```

---

## 📖 Playbook Details

### 1. setup-environment.yml
**Purpose:** Prepare the system with all required dependencies

**What it does:**
- Updates system packages
- Installs Python 3, pip, git, curl, wget
- Installs Node.js and npm for frontend
- Creates project directories
- Sets up .env file template

**When to run:** First time only, or when setting up a new machine

**Expected time:** 3-5 minutes

**Output:**
```
✓ System packages installed
✓ Python environment configured
✓ Node.js installed
✓ Project directories created
```

---

### 2. install-docker.yml
**Purpose:** Install Docker Engine and Docker Compose

**What it does:**
- Removes old Docker versions
- Adds Docker official repository
- Installs Docker CE and Docker Compose plugin
- Adds user to docker group
- Configures Docker daemon with best practices

**When to run:** First time only

**Expected time:** 3-5 minutes

**Important:** After running, **log out and log back in** for docker group changes to take effect

**Output:**
```
✓ Docker Engine installed
✓ Docker Compose plugin installed
✓ User added to docker group
✓ Hello-world container test passed
```

---

### 3. install-kubernetes.yml
**Purpose:** Install Kubernetes tools (kubectl, minikube, helm, k9s)

**What it does:**
- Installs kubectl (Kubernetes CLI)
- Installs minikube (local Kubernetes cluster)
- Installs helm (Kubernetes package manager)
- Installs k9s (Kubernetes CLI UI)
- Creates kubectl aliases for productivity

**When to run:** First time only

**Expected time:** 5-10 minutes

**Output:**
```
✓ kubectl installed
✓ minikube installed
✓ helm installed
✓ k9s installed
✓ Useful aliases added to .bashrc
```

**Useful aliases added:**
- `k` → `kubectl`
- `kgp` → `kubectl get pods`
- `kgs` → `kubectl get svc`
- `kga` → `kubectl get all`
- And many more...

---

### 4. deploy-application.yml
**Purpose:** Deploy GenAI Prompt Enhancer application

**Deployment modes:**
- **local**: Deploy using Docker containers on localhost (default)
- **kubernetes**: Deploy to minikube cluster

**What it does (local mode):**
- Stops any running services
- Builds Docker images for all services
- Starts services using start-dev.sh
- Waits for services to be ready
- Runs health checks
- Executes automated tests

**What it does (kubernetes mode):**
- Starts minikube if not running
- Builds and pushes images to minikube
- Applies Kubernetes manifests
- Waits for pods to be ready
- Displays service URLs

**When to run:** Anytime you want to deploy/redeploy

**Expected time:** 2-3 minutes

**Output (local mode):**
```
✓ Services deployed successfully
✓ Health checks passed
✓ Tests passed
Frontend:  http://localhost:5173
Gateway:   http://localhost:8088
```

---

### 5. monitoring-setup.yml
**Purpose:** Setup monitoring and observability stack

**What it does:**
- Creates Prometheus configuration
- Creates Grafana dashboards
- Defines alert rules
- Creates Docker Compose for monitoring stack
- Provides startup/stop scripts

**Components installed:**
- **Prometheus** (port 9090) - Metrics collection
- **Grafana** (port 3000) - Visualization
- **Node Exporter** (port 9100) - System metrics

**When to run:** Optional, after application deployment

**Expected time:** 2-3 minutes

**Output:**
```
✓ Monitoring stack configured
Start: ./monitoring/start-monitoring.sh
Prometheus: http://localhost:9090
Grafana:    http://localhost:3000 (admin/admin)
```

---

## 🎯 Common Use Cases

### Scenario 1: Fresh Machine Setup
```bash
# Run all setup playbooks in sequence
ansible-playbook playbooks/setup-environment.yml
ansible-playbook playbooks/install-docker.yml
# Log out and log back in here
ansible-playbook playbooks/install-kubernetes.yml
ansible-playbook playbooks/deploy-application.yml
```

### Scenario 2: Deploy Application Only
```bash
# If environment is already set up
ansible-playbook playbooks/deploy-application.yml
```

### Scenario 3: Deploy to Kubernetes
```bash
# Edit deploy-application.yml and set: deployment_mode: kubernetes
ansible-playbook playbooks/deploy-application.yml
```

### Scenario 4: Setup Monitoring
```bash
ansible-playbook playbooks/monitoring-setup.yml
cd monitoring
./start-monitoring.sh
```

---

## 🔍 Troubleshooting

### Check Ansible Syntax
```bash
ansible-playbook playbooks/setup-environment.yml --syntax-check
```

### Dry Run (Check Mode)
```bash
ansible-playbook playbooks/setup-environment.yml --check
```

### Run Specific Tasks (Tags)
```bash
# Run only package installation tasks
ansible-playbook playbooks/setup-environment.yml --tags packages

# Run only Docker installation
ansible-playbook playbooks/install-docker.yml --tags install
```

### View Available Tags
```bash
ansible-playbook playbooks/setup-environment.yml --list-tags
```

### Verbose Output
```bash
ansible-playbook playbooks/setup-environment.yml -v   # Verbose
ansible-playbook playbooks/setup-environment.yml -vvv # Very verbose
```

### View Logs
```bash
# Ansible logs are stored in:
cat ansible.log
```

---

## 📝 Configuration

### Inventory File (inventory.ini)
- Defines target hosts (currently localhost)
- Can be extended for remote servers
- Contains project variables

### Ansible Configuration (ansible.cfg)
- Sets Ansible behavior
- Configures logging
- Enables YAML output format
- Disables host key checking for lab environments

---

## 🎓 For Viva/Exam Preparation

### Key Points to Remember:

1. **What is Ansible?**
   - Configuration management and automation tool
   - Uses YAML (human-readable)
   - Agentless (no software needed on target machines)
   - Idempotent (safe to run multiple times)

2. **Why Ansible in this project?**
   - Automates repetitive setup tasks
   - Ensures consistency across environments
   - Documents infrastructure as code
   - Makes the project repeatable

3. **Ansible vs Other Tools:**
   - **vs Shell Scripts**: More structured, idempotent, better error handling
   - **vs Terraform**: Terraform for infrastructure provisioning, Ansible for configuration
   - **vs Puppet/Chef**: Simpler, agentless, easier learning curve

4. **How Ansible fits in DevOps:**
   - **CI/CD Pipeline**: Automates deployment
   - **IaC**: Infrastructure as Code
   - **Configuration Management**: Consistent configurations
   - **Orchestration**: Coordinates multiple tasks

5. **Ansible Concepts:**
   - **Playbook**: YAML file with automation tasks
   - **Task**: Single unit of work
   - **Module**: Built-in Ansible functions (apt, copy, shell, etc.)
   - **Inventory**: List of target hosts
   - **Handler**: Tasks triggered by notifications

---

## 🔗 Integration with Project

### How Ansible Complements Docker
- **Docker**: Packages applications
- **Ansible**: Installs Docker, manages containers, orchestrates deployments

### How Ansible Complements Kubernetes
- **Kubernetes**: Orchestrates containers in production
- **Ansible**: Installs Kubernetes, deploys manifests, manages clusters

### How Ansible Fits DevOps Lifecycle
```
Code → Build → Test → Deploy → Monitor
  ↓       ↓       ↓       ↓        ↓
GitHub  Docker  Tests  Ansible  Prometheus
```

---

## 📚 Additional Resources

### Official Documentation
- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Galaxy](https://galaxy.ansible.com/) - Pre-built roles

### Useful Commands
```bash
# List all hosts
ansible all --list-hosts

# Ping all hosts
ansible all -m ping

# Run ad-hoc command
ansible local -m shell -a "docker ps"

# Get system facts
ansible local -m setup
```

---

## ✅ Success Criteria

After running all playbooks, you should have:
- ✓ Docker installed and running
- ✓ Kubernetes tools installed (kubectl, minikube)
- ✓ Application deployed and accessible
- ✓ Monitoring stack configured (optional)
- ✓ All automated tests passing

---

## 🆘 Need Help?

1. Check logs: `cat ansible.log`
2. Run with verbose: `ansible-playbook <playbook> -vvv`
3. Check playbook syntax: `ansible-playbook <playbook> --syntax-check`
4. Review task documentation in playbook comments

---

**Made with ❤️ for DevOps Excellence**
