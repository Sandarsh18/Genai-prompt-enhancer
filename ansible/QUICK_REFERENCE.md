# 🎯 Quick Reference Card - Keep This Handy!

## 🚀 Essential Commands (One-Page Cheat Sheet)

### Docker Commands
```bash
# Build image
docker build -t genai-rewrite ./rewrite-service

# Run container
docker run -d --name genai-rewrite -p 8000:8000 genai-rewrite

# View logs
docker logs genai-rewrite -f

# Stop container
docker stop genai-rewrite

# Remove container
docker rm genai-rewrite

# List running containers
docker ps

# List all containers
docker ps -a

# Execute command in container
docker exec -it genai-rewrite bash
```

### Kubernetes Commands
```bash
# Apply all manifests
kubectl apply -f k8s/

# Get all resources
kubectl get all

# Get pods
kubectl get pods

# Get services
kubectl get svc

# Describe pod
kubectl describe pod <pod-name>

# View logs
kubectl logs <pod-name>

# Scale deployment
kubectl scale deployment rewrite-deployment --replicas=5

# Delete resources
kubectl delete -f k8s/

# Port forward
kubectl port-forward svc/rewrite-service 8000:8000
```

### Ansible Commands
```bash
# Run playbook
ansible-playbook playbooks/deploy-application.yml

# Dry run (check mode)
ansible-playbook playbooks/deploy-application.yml --check

# Run with specific tags
ansible-playbook playbooks/deploy-application.yml --tags test

# Verbose output
ansible-playbook playbooks/deploy-application.yml -vvv

# List tasks
ansible-playbook playbooks/deploy-application.yml --list-tasks

# Syntax check
ansible-playbook playbooks/deploy-application.yml --syntax-check

# List hosts
ansible all --list-hosts
```

### Project Scripts
```bash
# Start local development
./start-dev.sh

# Stop local development
./stop-dev.sh

# Check status
./status.sh

# Run all tests
./test-all.sh

# Run Ansible demo
cd ansible && ./ansible-demo.sh
```

---

## 🎓 Quick Answers to Common Questions

### Q: What is Docker?
**A:** Containerization platform that packages apps with dependencies into isolated containers.

### Q: What is Kubernetes?
**A:** Container orchestration system that manages, scales, and heals containerized applications.

### Q: What is Ansible?
**A:** Agentless automation tool that uses SSH to configure servers with YAML playbooks.

### Q: What is microservices?
**A:** Architecture where application is split into small, independent services that communicate via APIs.

### Q: What is NGINX?
**A:** High-performance web server and reverse proxy used as API gateway.

### Q: What is CI/CD?
**A:** Continuous Integration/Continuous Deployment - automated testing and deployment pipeline.

### Q: What is HPA?
**A:** Horizontal Pod Autoscaler - automatically scales pods based on CPU/memory metrics.

### Q: What is Prometheus?
**A:** Open-source monitoring system that collects and stores metrics as time-series data.

### Q: What is Grafana?
**A:** Analytics and visualization platform that creates dashboards from Prometheus data.

### Q: What is IaC?
**A:** Infrastructure as Code - managing infrastructure through machine-readable files.

---

## 📊 Project Statistics

| Component | Count | Description |
|-----------|-------|-------------|
| Microservices | 3 | rewrite, summarize, email |
| Docker Images | 4 | 3 services + gateway |
| Kubernetes Pods | 12 | 3 replicas × 4 services |
| Ansible Playbooks | 5 | Full automation |
| Endpoints | 4 | /rewrite, /summarize, /email, /health |
| Ports Used | 5 | 8000-8002, 5173, 8088 |
| Configuration Files | 15+ | YAML, NGINX, Docker |

---

## 🏗️ Architecture Flow

```
User → Frontend (5173) → NGINX (8088) → Services (8000-8002) → Gemini AI
```

**Ports:**
- 5173: React Frontend
- 8088: NGINX Gateway
- 8000: Rewrite Service
- 8001: Summarize Service
- 8002: Email Service
- 9090: Prometheus
- 3000: Grafana

---

## 🔍 Troubleshooting Guide

### Container won't start
```bash
docker logs <container-name>  # Check logs
docker inspect <container-name>  # Check config
docker ps -a  # List all containers
```

### Kubernetes pod failing
```bash
kubectl describe pod <pod-name>  # Check events
kubectl logs <pod-name>  # Check logs
kubectl get events  # Check cluster events
```

### Ansible playbook fails
```bash
cat ansible/ansible.log  # Check Ansible logs
ansible-playbook <playbook> -vvv  # Verbose mode
ansible-playbook <playbook> --check  # Dry run
```

### Service unreachable
```bash
curl http://localhost:8000/health  # Test direct
curl http://localhost:8088/rewrite/health  # Test via gateway
docker exec -it genai-gateway curl http://localhost:8000/health  # Test from container
```

---

## 🎯 Demo Sequence (5 minutes)

1. **Show Application** (1 min)
   - Open http://localhost:5173
   - Enter text, click Rewrite
   - Show AI-enhanced output

2. **Show Docker** (1 min)
   - `docker ps` - Show 4 running containers
   - `docker logs genai-rewrite -n 20` - Show logs

3. **Show Kubernetes** (1.5 min)
   - `kubectl get pods` - Show 12 pods
   - `kubectl scale deployment rewrite-deployment --replicas=5`
   - `kubectl get pods -w` - Watch scaling

4. **Show Ansible** (1 min)
   - `cd ansible && ./ansible-demo.sh`
   - Choose option 7 (syntax check)

5. **Show Tests** (30 sec)
   - `./test-all.sh` - All tests pass

---

## 💡 Key Talking Points

✅ **Microservices:** Scalable, resilient, independent deployment
✅ **Docker:** Platform-independent, consistent environments
✅ **Kubernetes:** Auto-scaling, self-healing, declarative config
✅ **Ansible:** Idempotent, agentless, version-controlled infrastructure
✅ **CI/CD:** Automated testing, fast feedback, zero-downtime deployment
✅ **Monitoring:** Proactive issue detection, performance optimization

---

## 🚨 Red Flags to Avoid

❌ "I don't know" → ✅ "Let me demonstrate by checking logs"
❌ "It just works" → ✅ "It works because of health checks and auto-restart"
❌ "I copied everything" → ✅ "I researched and adapted best practices"
❌ "Monolithic is bad" → ✅ "Microservices suit this project's requirements"

---

## 📝 Before Viva Checklist

- [ ] Run `./start-dev.sh` - All services up
- [ ] Run `./test-all.sh` - All tests pass
- [ ] Run `docker ps` - 4 containers running
- [ ] Open http://localhost:5173 - Frontend loads
- [ ] Test rewrite functionality - Works correctly
- [ ] Run `kubectl get pods` - If using k8s, pods running
- [ ] Review ansible/VIVA_CHEATSHEET.md
- [ ] Practice demo sequence 2-3 times
- [ ] Prepare answers to expected questions
- [ ] Have terminal ready with project directory open

---

## 🎤 Opening Line

> "This project demonstrates end-to-end DevOps with microservices, Docker, Kubernetes, Ansible, and CI/CD. It's production-ready and fully automated."

## 🏁 Closing Line

> "The application scales from local development to production, handles failures gracefully, and deploys with zero downtime. Thank you!"

---

**Print this page and keep it with you! 📄**
