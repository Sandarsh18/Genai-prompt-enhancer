# GenAI Prompt Enhancer

Production-ready, Kubernetes-native GenAI prompt enhancement platform featuring three FastAPI microservices, an NGINX API gateway, a React single-page application, full observability, and GitHub Actions powered CI/CD.

```
                        ┌──────────────────────┐
                        │    React Frontend    │
                        └──────────┬───────────┘
                                   │
                            Ingress (genai.local)
                                   │
                     ┌─────────────┴────────────┐
                     │      NGINX Gateway       │
                     ├─────────┬───────┬────────┤
                     │         │       │        │
              /rewrite   /summarize  /email   Metrics
                 │           │         │         │
      ┌──────────┴───┐ ┌─────┴────┐ ┌──┴────────┐
      │ Rewrite Svc │ │ Summ Svc │ │ Email Svc │
      └──────────────┘ └──────────┘ └───────────┘
                 │           │         │
          Prometheus scraping via ServiceMonitors (Helm stack)
```

## Components
- **frontend/** – React + Vite SPA with Axios-powered service calls.
- **rewrite/summarize/email services** – FastAPI + Uvicorn microservices instrumented via `prometheus-fastapi-instrumentator` and GenAI API shims.
- **nginx-gateway/** – Hardened reverse proxy with JSON logs, stub metrics, and path-based routing for the microservices.
- **k8s/** – Deployments, Services, Ingress, HPAs, and shared ConfigMap/Secret for GenAI credentials.
- **ci-cd/** – Build pipeline builds and pushes Docker images; deploy pipeline updates the running cluster.
- **load-test/** – `hey` helper script for driving sustained load and demonstrating HPA behavior.

## Local Development
1. Install Node 20+, Python 3.12+, Docker, and `hey`.
2. Configure your GenAI credentials (Gemini example shown, works for any FastAPI process you launch):
   ```bash
   export GENAI_PROVIDER=gemini
   export GENAI_MODEL=gemini-1.5-flash
   export GENAI_GEMINI_BASE_URL=https://generativelanguage.googleapis.com/v1beta/models
   export GENAI_API_KEY=YOUR_GEMINI_FLASH_KEY
   export GENAI_TIMEOUT=12
   ```
   For OpenAI usage switch `GENAI_PROVIDER=openai`, set `GENAI_API_BASE_URL`, and choose any chat-completion model.
3. Install dependencies per service once:
   ```bash
   pip install -r rewrite-service/requirements.txt
   pip install -r summarize-service/requirements.txt
   pip install -r email-service/requirements.txt
   (cd frontend && npm install)
   ```
4. Start services in separate terminals:
   ```bash
   # Rewrite microservice
   cd rewrite-service && uvicorn app:app --reload --port 8000

   # Summarize microservice
   cd summarize-service && uvicorn app:app --reload --port 8001

   # Email microservice
   cd email-service && uvicorn app:app --reload --port 8002

   # Gateway (Docker)
    docker build -t genai-gateway ./nginx-gateway
    docker run --add-host host.docker.internal:host-gateway \  # needed on Linux
       -v $PWD/nginx-gateway/nginx.local.conf:/etc/nginx/nginx.conf:ro \
       -e GENAI_PROVIDER -e GENAI_MODEL -e GENAI_GEMINI_BASE_URL \
       -e GENAI_API_BASE_URL -e GENAI_API_KEY -p 8080:8080 genai-gateway

   # Frontend (points to gateway via Vite env var)
   cd frontend && VITE_GATEWAY_URL=http://localhost:8080 npm run dev
   ```
5. Visit `http://localhost:5173`, or directly hit the gateway (`curl -X POST http://localhost:8080/rewrite ...`).

## Docker Images
Each Dockerfile uses a slim runtime and multi-stage build. Example build commands:
```bash
# Frontend
cd frontend
npm install
DOCKER_BUILDKIT=1 docker build -t your-dockerhub/genai-frontend:latest .

# Rewrite microservice
cd ../rewrite-service
DOCKER_BUILDKIT=1 docker build -t your-dockerhub/genai-rewrite:latest .
```
Push the images to your registry so the Kubernetes manifests can pull them.

## Kubernetes Deployment
1. Create namespace (optional): `kubectl create namespace genai`.
2. Apply shared config + secrets after editing `k8s/configmap.yaml` with your API URL/model and replacing the secret value.
   ```bash
   kubectl apply -n genai -f k8s/configmap.yaml
   kubectl apply -n genai -f k8s
   ```
3. Update image references to match your registry (or patch via `kubectl set image`).
4. Expose ingress locally:
   ```bash
   kubectl port-forward svc/nginx-gateway 8080:8080 -n genai
   kubectl port-forward svc/frontend 3000:80 -n genai
   ```
5. Map `genai.local` to `127.0.0.1` in `/etc/hosts`, then browse to `https://genai.local` via your ingress controller.

## Horizontal Pod Autoscaling Demo
1. Ensure the HPAs (`k8s/hpa-*.yaml`) are applied and the metrics server is available.
2. Run sustained load:
   ```bash
   cd load-test
   chmod +x hey-load.sh
   ./hey-load.sh http://<node-ip>:32080/rewrite
   ```
3. Watch scaling events:
   ```bash
   kubectl get hpa -n genai --watch
   kubectl top pods -n genai
   ```

## Observability Stack
Install the kube-prometheus-stack chart (Prometheus, Alertmanager, Grafana, node exporter, kube-state-metrics):
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```
Key Grafana dashboards to import:
- *Kubernetes / Compute Resources / Pod*
- *Horizontal Pod Autoscaler*
- *NGINX Overview* (ID 12708)

Expose Grafana locally:
```bash
kubectl port-forward svc/monitoring-grafana 3001:80 -n monitoring
```
Set `http://localhost:3001` → Dashboards → Import ID. Capture screenshots and store under `docs/` (placeholder references in this README: `docs/grafana-hpa.png`, `docs/grafana-nginx.png`).

## CI/CD
1. **Build Pipeline (`ci-cd/build.yml`)**
   - Triggers on pushes to `main`.
   - Matrix builds/pushes Docker images for frontend, microservices, and gateway using Docker Buildx.
2. **Deploy Pipeline (`ci-cd/deploy.yml`)**
   - Triggers on manual dispatch or manifest changes.
   - Loads kubeconfig from `KUBE_CONFIG_BASE64` secret.
   - Applies manifests, sets images to the latest commit SHA, and waits for rollouts.

Prepare GitHub repository secrets:
- `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`
- `KUBE_CONFIG_BASE64` (base64-encoded kubeconfig with deploy permissions)

## Testing
- **API Smoke Tests:**
  ```bash
  curl -X POST http://localhost:32080/rewrite -H 'Content-Type: application/json' -d '{"text":"make this sharper"}'
  ```
- **Frontend E2E:** Use Playwright/Cypress to automate button clicks and response rendering checks.
- **Load Testing:** Use `load-test/hey-load.sh` to generate CPU pressure and validate HPA + Prometheus metrics.

## Troubleshooting
- Pods pending → run `kubectl describe pod/<name>` for scheduling issues (CPU/memory requests too high?).
- 502 errors from gateway → verify downstream services are healthy; check `kubectl logs deployment/nginx-gateway` for proxy failures.
- Prometheus scrape failures → ensure `prometheus-fastapi-instrumentator` exposes `/metrics` (enabled by default) and ServiceMonitors target the right namespace.
- HPAs not scaling → confirm metrics-server or kube-prometheus-stack is healthy via `kubectl top nodes`.
- GitHub Actions image pulls failing → confirm Docker Hub rate limits and credentials, or switch to GHCR + PAT.

## TODO / Enhancements
- Add ServiceMonitor CRDs for each backend (post Helm install).
- Integrate API key rotation with external secret manager (Vault, SOPS).
- Extend CI with automated load tests before deployment.
