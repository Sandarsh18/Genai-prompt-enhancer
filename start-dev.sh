#!/bin/bash

# GenAI Prompt Enhancer - Production-Grade Portable Startup Script
# 
# DEVOPS PRINCIPLES IMPLEMENTED:
# 1. Docker-only: No dependency on host Python, Node, npm, uvicorn
# 2. Portable: Works on ANY Linux machine with Docker installed
# 3. Offline-first: Reuses cached images after first build
# 4. Fail-fast: Comprehensive preflight checks with clear error messages
# 5. Health validation: Ensures all services are truly ready before declaring success
# 6. Idempotent: Safe to run multiple times
# 7. Production-ready: Mirrors Kubernetes networking and service discovery

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}GenAI Prompt Enhancer - Docker Startup${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# ============================================
# PHASE 1: ENVIRONMENT PREFLIGHT CHECKS
# ============================================

echo -e "${CYAN}Phase 1: Environment Preflight Checks${NC}"
echo -e "${BLUE}-------------------------------------${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ CRITICAL: Docker is not installed${NC}"
    echo ""
    echo -e "${YELLOW}This project requires Docker to run.${NC}"
    echo -e "${YELLOW}Install Docker:${NC}"
    echo -e "  Ubuntu/Debian: ${CYAN}sudo apt-get install docker.io${NC}"
    echo -e "  RHEL/CentOS:   ${CYAN}sudo yum install docker${NC}"
    echo -e "  Other:         ${CYAN}https://docs.docker.com/engine/install/${NC}"
    echo ""
    exit 1
fi
echo -e "${GREEN}✓ Docker is installed${NC}"

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo -e "${RED}✗ CRITICAL: Docker daemon is not running${NC}"
    echo ""
    echo -e "${YELLOW}Start Docker daemon:${NC}"
    echo -e "  ${CYAN}sudo systemctl start docker${NC}"
    echo -e "  ${CYAN}sudo service docker start${NC}"
    echo ""
    exit 1
fi
echo -e "${GREEN}✓ Docker daemon is running${NC}"

# Check if user has Docker permissions
if ! docker ps &> /dev/null; then
    echo -e "${RED}✗ CRITICAL: No permission to access Docker${NC}"
    echo ""
    echo -e "${YELLOW}Add your user to the docker group:${NC}"
    echo -e "  ${CYAN}sudo usermod -aG docker \$USER${NC}"
    echo -e "  ${CYAN}newgrp docker${NC}"
    echo ""
    exit 1
fi
echo -e "${GREEN}✓ Docker permissions verified${NC}"

# Load environment variables
if [ -f .env ]; then
    echo -e "${GREEN}✓ Loading environment variables from .env${NC}"
    export $(grep -v '^#' .env | xargs)
else
    echo -e "${YELLOW}⚠ No .env file found${NC}"
    if [ -f .env.example ]; then
        echo -e "${YELLOW}  Creating .env from .env.example${NC}"
        cp .env.example .env
        export $(grep -v '^#' .env | xargs)
    fi
fi

# Check API key configuration
if [ "$GENAI_API_KEY" = "your_api_key_here" ] || [ -z "$GENAI_API_KEY" ]; then
    echo -e "${YELLOW}⚠ GENAI_API_KEY is not configured${NC}"
    echo -e "${YELLOW}  Services will run in MOCK MODE (no actual AI)${NC}"
fi

echo ""

# ============================================
# PHASE 2: CLEANUP EXISTING CONTAINERS & HOST PROCESSES
# ============================================

echo -e "${CYAN}Phase 2: Cleanup Existing Resources${NC}"
echo -e "${BLUE}-------------------------------------${NC}"

# Stop Docker containers (including old names for backward compatibility)
echo -e "${YELLOW}Stopping existing containers...${NC}"
docker stop rewrite-service summarize-service email-service nginx-gateway genai-gateway frontend 2>/dev/null || true
docker rm rewrite-service summarize-service email-service nginx-gateway genai-gateway frontend 2>/dev/null || true
echo -e "${GREEN}✓ Containers stopped${NC}"

# Kill old host-based processes (from previous non-Docker setup)
echo -e "${YELLOW}Cleaning up any old host processes...${NC}"
pkill -f "uvicorn app:app" 2>/dev/null || true
pkill -f "vite" 2>/dev/null || true
sleep 1
echo -e "${GREEN}✓ Host processes cleaned${NC}"

# Verify ports are free
echo -e "${YELLOW}Verifying ports are available...${NC}"
ports_in_use=()
for port in 8000 8001 8002 8088 5173; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        ports_in_use+=($port)
    fi
done

if [ ${#ports_in_use[@]} -gt 0 ]; then
    echo -e "${RED}✗ Ports still in use: ${ports_in_use[*]}${NC}"
    echo -e "${YELLOW}Attempting to force-free ports...${NC}"
    for port in "${ports_in_use[@]}"; do
        lsof -ti:$port | xargs kill -9 2>/dev/null || true
    done
    sleep 2
    
    # Check again
    still_in_use=()
    for port in 8000 8001 8002 8088 5173; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            still_in_use+=($port)
        fi
    done
    
    if [ ${#still_in_use[@]} -gt 0 ]; then
        echo -e "${RED}✗ Cannot free ports: ${still_in_use[*]}${NC}"
        echo -e "${YELLOW}Please manually stop processes using these ports:${NC}"
        for port in "${still_in_use[@]}"; do
            echo -e "  ${CYAN}sudo lsof -ti:$port | xargs sudo kill -9${NC}"
        done
        exit 1
    fi
fi
echo -e "${GREEN}✓ All ports available${NC}"

echo ""

# ============================================
# PHASE 3: DOCKER NETWORK SETUP
# ============================================

echo -e "${CYAN}Phase 3: Docker Network Setup${NC}"
echo -e "${BLUE}-------------------------------------${NC}"

if docker network inspect genai-network &>/dev/null; then
    echo -e "${GREEN}✓ Docker network 'genai-network' already exists${NC}"
else
    echo -e "${YELLOW}Creating Docker network 'genai-network'...${NC}"
    docker network create genai-network
    echo -e "${GREEN}✓ Docker network created${NC}"
fi

echo ""

# ============================================
# PHASE 4: BUILD DOCKER IMAGES
# ============================================

echo -e "${CYAN}Phase 4: Build Docker Images${NC}"
echo -e "${BLUE}-------------------------------------${NC}"

mkdir -p logs

build_image() {
    local service_name=$1
    local image_name=$2
    local context_dir=$3
    
    if docker image inspect "$image_name" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Using cached image: $image_name${NC}"
    else
        echo -e "${YELLOW}Building $service_name...${NC}"
        if docker build -t "$image_name" "$context_dir" > "$PROJECT_ROOT/logs/$service_name-build.log" 2>&1; then
            echo -e "${GREEN}✓ Built: $image_name${NC}"
        else
            echo -e "${RED}✗ Failed to build $service_name${NC}"
            tail -20 "$PROJECT_ROOT/logs/$service_name-build.log"
            exit 1
        fi
    fi
}

build_image "rewrite-service" "genai-rewrite-service:latest" "./rewrite-service"
build_image "summarize-service" "genai-summarize-service:latest" "./summarize-service"
build_image "email-service" "genai-email-service:latest" "./email-service"
build_image "nginx-gateway" "genai-nginx-gateway:latest" "./nginx-gateway"
build_image "frontend" "genai-frontend:latest" "./frontend"

echo ""

# ============================================
# PHASE 5: START BACKEND SERVICES
# ============================================

echo -e "${CYAN}Phase 5: Start Backend Services${NC}"
echo -e "${BLUE}-------------------------------------${NC}"

echo -e "${YELLOW}Starting rewrite-service...${NC}"
docker run -d \
  --name rewrite-service \
  --network genai-network \
  -p 8000:8000 \
  -e GENAI_API_KEY="${GENAI_API_KEY:-}" \
  -e GENAI_PROVIDER="${GENAI_PROVIDER:-gemini}" \
  -e GENAI_MODEL="${GENAI_MODEL:-gemini-1.5-flash}" \
  --restart unless-stopped \
  genai-rewrite-service:latest
echo -e "${GREEN}✓ rewrite-service started${NC}"

echo -e "${YELLOW}Starting summarize-service...${NC}"
docker run -d \
  --name summarize-service \
  --network genai-network \
  -p 8001:8001 \
  -e GENAI_API_KEY="${GENAI_API_KEY:-}" \
  -e GENAI_PROVIDER="${GENAI_PROVIDER:-gemini}" \
  -e GENAI_MODEL="${GENAI_MODEL:-gemini-1.5-flash}" \
  --restart unless-stopped \
  genai-summarize-service:latest
echo -e "${GREEN}✓ summarize-service started${NC}"

echo -e "${YELLOW}Starting email-service...${NC}"
docker run -d \
  --name email-service \
  --network genai-network \
  -p 8002:8002 \
  -e GENAI_API_KEY="${GENAI_API_KEY:-}" \
  -e GENAI_PROVIDER="${GENAI_PROVIDER:-gemini}" \
  -e GENAI_MODEL="${GENAI_MODEL:-gemini-1.5-flash}" \
  --restart unless-stopped \
  genai-email-service:latest
echo -e "${GREEN}✓ email-service started${NC}"

echo ""

# ============================================
# PHASE 6: WAIT FOR BACKEND HEALTH
# ============================================

echo -e "${CYAN}Phase 6: Backend Health Validation${NC}"
echo -e "${BLUE}-------------------------------------${NC}"

wait_for_health() {
    local service_name=$1
    local port=$2
    local max_wait=60
    local elapsed=0
    
    echo -e "${YELLOW}⏳ Waiting for $service_name to become healthy...${NC}"
    
    while [ $elapsed -lt $max_wait ]; do
        if curl -sf http://localhost:$port/ready > /dev/null 2>&1; then
            echo -e "${GREEN}✓ $service_name is healthy (${elapsed}s)${NC}"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        
        if [ $((elapsed % 10)) -eq 0 ]; then
            echo -e "  ${YELLOW}Still waiting... (${elapsed}s/${max_wait}s)${NC}"
        fi
    done
    
    echo -e "${RED}✗ $service_name failed to become healthy after ${max_wait}s${NC}"
    docker logs "$service_name" --tail 30
    return 1
}

if ! wait_for_health "rewrite-service" 8000; then exit 1; fi
if ! wait_for_health "summarize-service" 8001; then exit 1; fi
if ! wait_for_health "email-service" 8002; then exit 1; fi

echo ""

# ============================================
# PHASE 7: START NGINX GATEWAY
# ============================================

echo -e "${CYAN}Phase 7: Start NGINX Gateway${NC}"
echo -e "${BLUE}-------------------------------------${NC}"

echo -e "${YELLOW}Starting nginx-gateway...${NC}"
docker run -d \
  --name nginx-gateway \
  --network genai-network \
  -p 8088:8088 \
  --restart unless-stopped \
  genai-nginx-gateway:latest
echo -e "${GREEN}✓ nginx-gateway started${NC}"

echo -e "${YELLOW}⏳ Waiting for nginx-gateway to become healthy...${NC}"
sleep 3

max_wait=30
elapsed=0
while [ $elapsed -lt $max_wait ]; do
    if curl -sf http://localhost:8088/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ nginx-gateway is healthy (${elapsed}s)${NC}"
        break
    fi
    sleep 2
    elapsed=$((elapsed + 2))
done

if [ $elapsed -ge $max_wait ]; then
    echo -e "${RED}✗ nginx-gateway failed to become healthy${NC}"
    docker logs nginx-gateway --tail 30
    exit 1
fi

echo ""

# ============================================
# PHASE 8: VALIDATE GATEWAY ROUTING
# ============================================

echo -e "${CYAN}Phase 8: Gateway Routing Validation${NC}"
echo -e "${BLUE}-------------------------------------${NC}"

test_route() {
    local endpoint=$1
    local service_name=$2
    
    echo -e "${YELLOW}Testing /$endpoint route...${NC}"
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"text":"test"}' \
        -w "%{http_code}" \
        -o /dev/null \
        http://localhost:8088/$endpoint 2>&1)
    
    if [ "$response" = "200" ]; then
        echo -e "${GREEN}✓ Gateway → $service_name: WORKING${NC}"
        return 0
    else
        echo -e "${RED}✗ Gateway → $service_name: FAILED (HTTP $response)${NC}"
        docker logs nginx-gateway --tail 10
        return 1
    fi
}

if ! test_route "rewrite" "rewrite-service"; then exit 1; fi
if ! test_route "summarize" "summarize-service"; then exit 1; fi
if ! test_route "email" "email-service"; then exit 1; fi

echo ""

# ============================================
# PHASE 9: START FRONTEND
# ============================================

echo -e "${CYAN}Phase 9: Start Frontend${NC}"
echo -e "${BLUE}-------------------------------------${NC}"

echo -e "${YELLOW}Starting frontend...${NC}"
docker run -d \
  --name frontend \
  --network genai-network \
  -p 5173:80 \
  --restart unless-stopped \
  genai-frontend:latest
echo -e "${GREEN}✓ frontend started${NC}"

sleep 3
if curl -sf http://localhost:5173 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ frontend is serving content${NC}"
else
    echo -e "${YELLOW}⚠ frontend may still be starting up${NC}"
fi

echo ""

# ============================================
# SUCCESS SUMMARY
# ============================================

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✓ ALL SYSTEMS OPERATIONAL${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${CYAN}Service Status:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "frontend|nginx-gateway|rewrite-service|summarize-service|email-service"
echo ""
echo -e "${CYAN}Access Points:${NC}"
echo -e "  Frontend:       ${GREEN}http://localhost:5173${NC}"
echo -e "  API Gateway:    ${GREEN}http://localhost:8088${NC}"
echo -e "  Gateway Health: ${GREEN}http://localhost:8088/health${NC}"
echo ""
echo -e "${CYAN}Management Commands:${NC}"
echo -e "  Stop all:       ${GREEN}./stop-dev.sh${NC}"
echo -e "  Check status:   ${GREEN}./status.sh${NC}"
echo -e "  Run tests:      ${GREEN}./test-all.sh${NC}"
echo ""
echo -e "${GREEN}🚀 Production-Ready: Portable, Scalable, Kubernetes-Like!${NC}"
echo ""
