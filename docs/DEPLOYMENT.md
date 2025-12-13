# 🚀 Deployment Guide

Complete guide for deploying GenAI Prompt Enhancer in various environments.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Local Development](#local-development)
- [Minikube Deployment](#minikube-deployment)
- [Production Kubernetes](#production-kubernetes)
- [Cloud Deployments](#cloud-deployments)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software

| Tool | Version | Purpose |
|------|---------|---------|
| Docker | 20.10+ | Container runtime |
| Kubernetes | 1.24+ | Orchestration |
| kubectl | 1.24+ | K8s CLI |
| Minikube | 1.30+ | Local K8s cluster |
| Helm | 3.10+ | Package manager |
| Git | 2.30+ | Version control |

### System Requirements

**Minimum**:
- CPU: 4 cores
- RAM: 8 GB
- Disk: 20 GB free

**Recommended**:
- CPU: 8 cores
- RAM: 16 GB
- Disk: 50 GB free

## Local Development

### Quick Start

```bash
# Clone repository
git clone https://github.com/Sandarsh18/genai-prompt-enhancer.git
cd genai-prompt-enhancer

# Configure environment
cp .env.example .env
# Edit .env with your API keys

# Start all services
./start-dev.sh

# Check status
./status.sh
```

### Manual Setup

#### 1. Backend Services

```bash
# Rewrite Service
cd rewrite-service
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app:app --host 0.0.0.0 --port 8000 --reload

# Summarize Service
cd ../summarize-service
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app:app --host 0.0.0.0 --port 8001 --reload

# Email Service
cd ../email-service
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app:app --host 0.0.0.0 --port 8002 --reload
```

#### 2. Frontend

```bash
cd frontend
npm install
npm run dev
```

#### 3. NGINX Gateway

```bash
cd nginx-gateway
docker build -t genai-gateway:latest .
docker run -p 8088:8080 genai-gateway:latest
```

### Docker Compose (Alternative)

```bash
# Build images
docker-compose build

# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## Minikube Deployment

### 1. Start Minikube

```bash
# Start cluster with sufficient resources
minikube start \
  --cpus=4 \
  --memory=8192 \
  --disk-size=20g \
  --driver=docker

# Verify cluster
kubectl cluster-info
kubectl get nodes
```

### 2. Enable Required Addons

```bash
# Enable metrics for HPA
minikube addons enable metrics-server

# Enable ingress (optional)
minikube addons enable ingress

# Verify addons
minikube addons list
```

### 3. Configure Docker Environment

```bash
# Point Docker to Minikube's Docker daemon
eval $(minikube docker-env)

# Verify
docker ps | grep k8s
```

### 4. Build Docker Images

```bash
# Build all images
docker build -t rewrite-service:latest ./rewrite-service
docker build -t summarize-service:latest ./summarize-service
docker build -t email-service:latest ./email-service
docker build -t genai-gateway:latest ./nginx-gateway
docker build -t frontend:latest ./frontend

# Verify images
docker images | grep -E 'rewrite|summarize|email|gateway|frontend'
```

### 5. Configure Environment

```bash
# Edit ConfigMap with your settings
nano k8s/configmap.yaml

# Update with your GenAI API key
GENAI_API_KEY: "your-api-key-here"
```

### 6. Deploy to Kubernetes

```bash
# Create ConfigMap first
kubectl apply -f k8s/configmap.yaml

# Deploy all resources
kubectl apply -f k8s/

# Alternatively, deploy individually
kubectl apply -f k8s/rewrite-deploy.yaml
kubectl apply -f k8s/rewrite-svc.yaml
kubectl apply -f k8s/hpa-rewrite.yaml
# ... repeat for other services
```

### 7. Verify Deployment

```bash
# Check pods
kubectl get pods
# All pods should be Running with 1/1 Ready

# Check services
kubectl get svc

# Check HPAs
kubectl get hpa

# View logs
kubectl logs -f deployment/rewrite-deploy
```

### 8. Access Services

```bash
# Get Minikube IP
minikube ip

# Access frontend
# http://<minikube-ip>:30080

# Access gateway
# http://<minikube-ip>:32080

# Alternative: Use minikube service
minikube service frontend
minikube service nginx-gateway
```

## Production Kubernetes

### Prerequisites

- Managed Kubernetes cluster (EKS, GKE, AKS)
- kubectl configured with cluster access
- Container registry (ECR, GCR, ACR, DockerHub)
- Domain name and TLS certificates

### 1. Setup Container Registry

#### Docker Hub
```bash
# Login
docker login

# Tag images
docker tag rewrite-service:latest username/rewrite-service:v1.0.0
docker tag summarize-service:latest username/summarize-service:v1.0.0
docker tag email-service:latest username/email-service:v1.0.0
docker tag genai-gateway:latest username/genai-gateway:v1.0.0
docker tag frontend:latest username/frontend:v1.0.0

# Push images
docker push username/rewrite-service:v1.0.0
docker push username/summarize-service:v1.0.0
docker push username/email-service:v1.0.0
docker push username/genai-gateway:v1.0.0
docker push username/frontend:v1.0.0
```

#### AWS ECR
```bash
# Login
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin \
  123456789.dkr.ecr.us-west-2.amazonaws.com

# Create repositories
aws ecr create-repository --repository-name rewrite-service
aws ecr create-repository --repository-name summarize-service
aws ecr create-repository --repository-name email-service

# Tag and push
docker tag rewrite-service:latest \
  123456789.dkr.ecr.us-west-2.amazonaws.com/rewrite-service:v1.0.0
docker push 123456789.dkr.ecr.us-west-2.amazonaws.com/rewrite-service:v1.0.0
```

### 2. Update Kubernetes Manifests

```yaml
# Update image references in deployments
spec:
  template:
    spec:
      containers:
      - name: rewrite-service
        image: username/rewrite-service:v1.0.0
        imagePullPolicy: Always  # Change from Never
```

### 3. Create Kubernetes Secrets

```bash
# Create secret for GenAI API key
kubectl create secret generic genai-secret \
  --from-literal=api-key=your-actual-api-key

# Create secret for image pull (if private registry)
kubectl create secret docker-registry regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=your-username \
  --docker-password=your-password \
  --docker-email=your-email
```

### 4. Setup TLS/SSL

```bash
# Create TLS secret
kubectl create secret tls genai-tls \
  --cert=path/to/cert.pem \
  --key=path/to/key.pem

# Or use cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

### 5. Deploy with Helm (Recommended)

```bash
# Create Helm chart structure
helm create genai-prompt-enhancer

# Deploy
helm install genai-prompt-enhancer ./genai-prompt-enhancer \
  --namespace production \
  --create-namespace \
  --set image.tag=v1.0.0

# Upgrade
helm upgrade genai-prompt-enhancer ./genai-prompt-enhancer \
  --namespace production
```

### 6. Configure Ingress

```yaml
# k8s/ingress-production.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: genai-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - genai.yourdomain.com
    secretName: genai-tls
  rules:
  - host: genai.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: nginx-gateway
            port:
              number: 8080
```

## Cloud Deployments

### AWS EKS

```bash
# Create EKS cluster
eksctl create cluster \
  --name genai-cluster \
  --region us-west-2 \
  --nodes 3 \
  --node-type t3.large

# Configure kubectl
aws eks update-kubeconfig --name genai-cluster --region us-west-2

# Deploy
kubectl apply -f k8s/
```

### Google GKE

```bash
# Create GKE cluster
gcloud container clusters create genai-cluster \
  --num-nodes=3 \
  --machine-type=n1-standard-2 \
  --zone=us-central1-a

# Get credentials
gcloud container clusters get-credentials genai-cluster \
  --zone=us-central1-a

# Deploy
kubectl apply -f k8s/
```

### Azure AKS

```bash
# Create resource group
az group create --name genai-rg --location eastus

# Create AKS cluster
az aks create \
  --resource-group genai-rg \
  --name genai-cluster \
  --node-count 3 \
  --node-vm-size Standard_DS2_v2

# Get credentials
az aks get-credentials \
  --resource-group genai-rg \
  --name genai-cluster

# Deploy
kubectl apply -f k8s/
```

## Monitoring Setup

### Install Prometheus & Grafana

```bash
# Add Helm repository
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts
helm repo update

# Install monitoring stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# Verify installation
kubectl get pods -n monitoring

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Get Grafana password
kubectl get secret -n monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode
```

## Troubleshooting

### Common Issues

#### Pods Not Starting

```bash
# Check pod status
kubectl get pods

# View pod details
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Common causes:
# - Image pull errors: Check imagePullPolicy and image name
# - Resource limits: Increase CPU/memory requests
# - Failed health checks: Verify /health endpoints work
```

#### ImagePullBackOff

```bash
# For local Minikube
eval $(minikube docker-env)
docker build -t service-name:latest .

# Ensure imagePullPolicy: Never in deployment
```

#### HPA Not Scaling

```bash
# Check metrics-server
kubectl get apiservice v1beta1.metrics.k8s.io

# View HPA status
kubectl describe hpa <hpa-name>

# Check if metrics are available
kubectl top pods
```

#### Service Not Accessible

```bash
# Check service
kubectl get svc
kubectl describe svc <service-name>

# Check endpoints
kubectl get endpoints <service-name>

# Test from within cluster
kubectl run test-pod --image=curlimages/curl -it --rm -- sh
curl http://rewrite-service:8000/health
```

### Debug Commands

```bash
# Get all resources
kubectl get all

# View events
kubectl get events --sort-by='.lastTimestamp'

# Check resource usage
kubectl top nodes
kubectl top pods

# Exec into pod
kubectl exec -it <pod-name> -- /bin/sh

# Port forward for debugging
kubectl port-forward pod/<pod-name> 8000:8000
```

### Reset and Clean Up

```bash
# Delete all resources
kubectl delete -f k8s/

# Or delete by label
kubectl delete all -l app=genai-prompt-enhancer

# Delete monitoring
helm uninstall prometheus -n monitoring

# Delete Minikube cluster
minikube delete

# Clean Docker
docker system prune -a
```

## Next Steps

- [Configure CI/CD Pipeline](#cicd-configuration)
- [Setup Monitoring Dashboards](./MONITORING.md)
- [Security Hardening](../SECURITY.md)
- [Performance Tuning](#performance-optimization)

---

Last Updated: December 13, 2025
