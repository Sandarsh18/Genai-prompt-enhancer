# 🏗️ Architecture Documentation

## Overview

GenAI Prompt Enhancer is built on a cloud-native microservices architecture designed for scalability, resilience, and observability.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     External Access Layer                    │
│  ┌────────────┐              ┌──────────────┐               │
│  │  Browser   │─────────────▶│   Ingress    │               │
│  └────────────┘              └──────┬───────┘               │
└─────────────────────────────────────┼─────────────────────────┘
                                      │
┌─────────────────────────────────────┼─────────────────────────┐
│              Kubernetes Cluster     │                         │
│  ┌──────────────────────────────────▼──────────────────┐     │
│  │             NGINX API Gateway                       │     │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │     │
│  │  │ Routing  │  │ Load     │  │ Rate     │          │     │
│  │  │          │  │ Balancing│  │ Limiting │          │     │
│  │  └──────────┘  └──────────┘  └──────────┘          │     │
│  └────────┬──────────────┬──────────────┬──────────────┘     │
│           │              │              │                    │
│  ┌────────▼──────┐  ┌───▼──────┐  ┌────▼────────┐          │
│  │   Rewrite     │  │Summarize │  │   Email     │          │
│  │   Service     │  │ Service  │  │  Service    │          │
│  │  (FastAPI)    │  │(FastAPI) │  │ (FastAPI)   │          │
│  │               │  │          │  │             │          │
│  │  [HPA 1-5]    │  │[HPA 1-5] │  │ [HPA 1-5]   │          │
│  └───────────────┘  └──────────┘  └─────────────┘          │
│                                                              │
│  ┌─────────────────────────────────────────────────┐        │
│  │             Frontend Service (React)             │        │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────────┐     │        │
│  │  │   UI    │  │  State  │  │  API Client  │     │        │
│  │  └─────────┘  └─────────┘  └─────────────┘     │        │
│  └─────────────────────────────────────────────────┘        │
│                                                              │
│  ┌─────────────────────────────────────────────────┐        │
│  │         Observability Stack                      │        │
│  │  ┌───────────┐  ┌──────────┐  ┌─────────┐      │        │
│  │  │Prometheus │  │ Grafana  │  │ Metrics  │      │        │
│  │  │           │  │          │  │ Server   │      │        │
│  │  └───────────┘  └──────────┘  └─────────┘      │        │
│  └─────────────────────────────────────────────────┘        │
└──────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Frontend Layer

**Technology**: React + Vite

**Responsibilities**:
- User interface rendering
- State management
- API communication
- Real-time updates

**Key Features**:
- Responsive design
- Component-based architecture
- Modern build tooling
- Hot module replacement

**Port**: 80 (inside container), exposed via NodePort 30080

### 2. API Gateway (NGINX)

**Technology**: NGINX 1.27-alpine

**Responsibilities**:
- Request routing to backend services
- Load balancing
- SSL termination (when configured)
- Rate limiting
- Request/response transformation

**Configuration Files**:
- `nginx.local.conf` - For local Docker development
- `nginx.k8s.conf` - For Kubernetes deployment

**Routing Rules**:
```
/rewrite    → rewrite-service:8000
/summarize  → summarize-service:8000
/email      → email-service:8000
/health     → NGINX status endpoint
```

**Port**: 8080 (inside container), exposed via NodePort 32080

### 3. Microservices

#### Rewrite Service
**Technology**: FastAPI + Python 3.12 + Uvicorn

**Purpose**: AI-powered text rewriting and enhancement

**Endpoints**:
- `POST /rewrite` - Rewrite text with specified tone
- `GET /health` - Health check endpoint

**Auto-scaling**: HPA configured with 50% CPU threshold, 1-5 replicas

**Resource Limits**:
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

#### Summarize Service
**Technology**: FastAPI + Python 3.12 + Uvicorn

**Purpose**: Intelligent text summarization

**Endpoints**:
- `POST /summarize` - Summarize long text
- `GET /health` - Health check endpoint

**Auto-scaling**: HPA configured with 50% CPU threshold, 1-5 replicas

#### Email Service
**Technology**: FastAPI + Python 3.12 + Uvicorn

**Purpose**: Professional email generation

**Endpoints**:
- `POST /email` - Generate email from prompt
- `GET /health` - Health check endpoint

**Auto-scaling**: HPA configured with 50% CPU threshold, 1-5 replicas

### 4. Observability Stack

#### Prometheus
**Purpose**: Metrics collection and storage

**Scraped Metrics**:
- Kubernetes cluster metrics
- Pod CPU/memory usage
- HTTP request rates
- Custom application metrics

**Port**: 9090

#### Grafana
**Purpose**: Metrics visualization and dashboards

**Pre-configured Dashboards**:
- Kubernetes cluster overview
- Pod resource usage
- HTTP request metrics
- Auto-scaling behavior

**Port**: 3000 (default credentials: admin/admin)

#### Metrics Server
**Purpose**: Provide resource metrics for HPA

**Metrics**:
- CPU usage per pod
- Memory usage per pod

## Data Flow

### Request Flow

1. **User Request** → Browser sends HTTP request
2. **Ingress/Service** → Kubernetes routes to NGINX Gateway
3. **API Gateway** → NGINX routes based on path
4. **Backend Service** → FastAPI processes request
5. **AI Processing** → GenAI API call (Gemini/OpenAI)
6. **Response** → Results flow back through the stack

### Metrics Flow

1. **Application Metrics** → Exposed by FastAPI services
2. **Prometheus Scraping** → Prometheus collects metrics
3. **Grafana Query** → Grafana queries Prometheus
4. **Dashboard Display** → Visualized in Grafana UI

### Auto-scaling Flow

1. **Metrics Server** → Collects pod CPU/memory metrics
2. **HPA Controller** → Monitors metrics vs target
3. **Scaling Decision** → Scale up/down based on threshold
4. **Deployment Update** → Kubernetes adjusts replica count
5. **Load Balancing** → NGINX distributes load to new pods

## Deployment Architecture

### Local Development

```
Docker Network (bridge)
├── rewrite-service (8000)
├── summarize-service (8001)
├── email-service (8002)
├── nginx-gateway (8088)
└── frontend (5173)
```

**Communication**: `host.docker.internal` for inter-service calls

### Kubernetes Production

```
Kubernetes Cluster
├── Namespace: default
│   ├── Deployments
│   │   ├── rewrite-deploy (1-5 replicas)
│   │   ├── summarize-deploy (1-5 replicas)
│   │   ├── email-deploy (1-5 replicas)
│   │   ├── frontend-deploy (1 replica)
│   │   └── gateway-deploy (1 replica)
│   ├── Services (ClusterIP)
│   │   ├── rewrite-service (8000)
│   │   ├── summarize-service (8000)
│   │   └── email-service (8000)
│   ├── Services (NodePort)
│   │   ├── frontend (30080)
│   │   └── nginx-gateway (32080)
│   └── HPAs
│       ├── hpa-rewrite
│       ├── hpa-summarize
│       └── hpa-email
└── Namespace: monitoring
    ├── Prometheus
    ├── Grafana
    └── Metrics Server
```

**Communication**: Kubernetes DNS (e.g., `rewrite-service.default.svc.cluster.local`)

## Scaling Strategy

### Horizontal Pod Autoscaler (HPA)

**Configuration**:
```yaml
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: rewrite-deploy
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 50
```

**Scaling Behavior**:
- **Scale Up**: When CPU > 50% for 30 seconds
- **Scale Down**: When CPU < 50% for 5 minutes
- **Step**: Add/remove 1 replica at a time

**Example Scaling Event**:
```
Time    CPU     Replicas    Action
0:00    20%     1           Stable
0:30    80%     1           → Scaling up
1:00    60%     2           → Scaling up
1:30    45%     3           Stable
6:30    25%     3           → Scaling down
7:00    20%     2           Stable
```

## Network Architecture

### Service Types

1. **ClusterIP** (Internal):
   - Backend microservices
   - Only accessible within cluster

2. **NodePort** (External):
   - Frontend (30080)
   - API Gateway (32080)
   - Exposed on all nodes

3. **LoadBalancer** (Future):
   - Production ingress
   - External load balancer

### DNS Resolution

**Internal**:
```
rewrite-service.default.svc.cluster.local:8000
summarize-service.default.svc.cluster.local:8000
email-service.default.svc.cluster.local:8000
```

**External** (via Minikube):
```
http://<minikube-ip>:30080  (Frontend)
http://<minikube-ip>:32080  (Gateway)
```

## Security Architecture

### Current Implementation

- ✅ Environment-based secrets
- ✅ Non-root container users
- ✅ Resource limits
- ✅ Health checks
- ✅ RBAC (default service account)

### Recommended Enhancements

- [ ] Network Policies
- [ ] Pod Security Standards
- [ ] TLS/SSL everywhere
- [ ] OAuth2 authentication
- [ ] API rate limiting
- [ ] Secret management (Vault)

## Monitoring Architecture

### Metrics Collection

**Application Metrics**:
- HTTP request count
- Request duration
- Error rates
- Response status codes

**Infrastructure Metrics**:
- CPU usage
- Memory usage
- Network I/O
- Disk I/O

**Custom Metrics**:
- GenAI API latency
- Token usage
- Queue depth

### Alerting Rules

**Planned Alerts**:
- High error rate (> 5%)
- High latency (> 2s p99)
- Pod crash loops
- High CPU/memory usage
- HPA at max replicas

## CI/CD Architecture

### Build Pipeline

```
GitHub Push → GitHub Actions → Docker Build → Image Push → Registry
```

### Deploy Pipeline

```
Tag Release → GitHub Actions → Kubectl Apply → Kubernetes → Health Check
```

## Future Enhancements

### Planned Architecture Improvements

1. **Service Mesh**: Istio/Linkerd for advanced traffic management
2. **Caching Layer**: Redis for response caching
3. **Message Queue**: RabbitMQ/Kafka for async processing
4. **Database**: PostgreSQL for persistent storage
5. **CDN**: CloudFlare for static assets
6. **Multi-Region**: Geographic distribution
7. **Disaster Recovery**: Backup and restore procedures

---

Last Updated: December 13, 2025
