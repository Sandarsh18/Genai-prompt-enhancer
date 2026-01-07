#!/bin/bash

# GenAI Prompt Enhancer - Development Startup Script
# This script starts all microservices, the gateway, and the frontend
#
# DEVOPS PRINCIPLES IMPLEMENTED:
# 1. Idempotency: Safe to run multiple times without side effects
# 2. Offline-first: Works without internet after initial setup
# 3. Image caching: Reuses Docker images instead of re-pulling
# 4. Resource cleanup: Properly handles existing processes/containers
# 5. Fail-fast: Exits early on critical errors

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}GenAI Prompt Enhancer - Starting...${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Load environment variables
if [ -f .env ]; then
    echo -e "${GREEN}✓ Loading environment variables from .env${NC}"
    export $(grep -v '^#' .env | xargs)
else
    echo -e "${YELLOW}⚠ No .env file found. Creating from .env.example${NC}"
    cp .env.example .env
    echo -e "${RED}✗ Please edit .env and add your GENAI_API_KEY${NC}"
    echo -e "${YELLOW}  Get your API key from: https://aistudio.google.com/apikey${NC}"
    exit 1
fi

# Check if API key is set
if [ "$GENAI_API_KEY" = "your_api_key_here" ] || [ -z "$GENAI_API_KEY" ]; then
    echo -e "${YELLOW}⚠ GENAI_API_KEY is not configured${NC}"
    echo -e "${YELLOW}  The services will run with fallback mode (no actual AI)${NC}"
    echo -e "${YELLOW}  To enable AI features, edit .env and add your API key${NC}"
    echo ""
fi

# DEVOPS: Function to check if port is in use
# Ensures idempotency by gracefully handling existing services
check_port() {
    if lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
        echo -e "${YELLOW}⚠ Port $1 is already in use${NC}"
        echo -e "  Attempting to free port..."
        lsof -ti:$1 | xargs kill -9 2>/dev/null || true
        sleep 1
        
        # Double-check port is freed
        if lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
            echo -e "${RED}✗ Failed to free port $1${NC}"
            return 1
        fi
    fi
    return 0
}

# DEVOPS: Function to check if Docker image exists locally
# This enables offline-first operation and avoids unnecessary builds
check_docker_image() {
    local image_name=$1
    if docker image inspect "$image_name" >/dev/null 2>&1; then
        return 0  # Image exists
    else
        return 1  # Image does not exist
    fi
}

# DEVOPS: Function to wait for service readiness
# Production-grade wait loop with timeout
wait_for_service_ready() {
    local service_name=$1
    local port=$2
    local max_wait=30
    local elapsed=0
    
    echo -e "  ${YELLOW}⏳${NC} Waiting for $service_name to be ready..."
    
    while [ $elapsed -lt $max_wait ]; do
        if curl -s http://localhost:$port/ready > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} $service_name is ready (${elapsed}s)"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    
    echo -e "  ${RED}✗${NC} $service_name failed to become ready after ${max_wait}s"
    return 1
}

# DEVOPS: Function to validate gateway can reach backends
# Critical for preventing 502 errors
validate_gateway_routing() {
    local endpoint=$1
    local max_attempts=5
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        local response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -d '{"text":"health check"}' \
            -w "%{http_code}" \
            -o /dev/null \
            http://localhost:8088/$endpoint 2>&1)
        
        if [ "$response" = "200" ]; then
            return 0
        fi
        
        attempt=$((attempt + 1))
        sleep 1
    done
    
    return 1
}

# Clean up function
cleanup() {
    echo ""
    echo -e "${YELLOW}Shutting down services...${NC}"
    jobs -p | xargs kill 2>/dev/null || true
    # DEVOPS: Clean up docker container but preserve the image for offline use
    docker stop genai-gateway 2>/dev/null || true
    docker rm genai-gateway 2>/dev/null || true
    exit 0
}

trap cleanup SIGINT SIGTERM

# DEVOPS: Check and free ports - ensures idempotent operation
echo -e "${BLUE}Checking ports...${NC}"
for port in 8000 8001 8002 8088 5173; do
    if ! check_port $port; then
        echo -e "${RED}✗ Cannot free port $port. Please check manually.${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ All required ports are available${NC}"

# Create logs directory
mkdir -p logs

# Start microservices
echo ""
echo -e "${BLUE}Starting microservices...${NC}"

echo -e "${BLUE}Starting Rewrite Service on port 8000${NC}"
cd "$PROJECT_ROOT/rewrite-service"
uvicorn app:app --host 0.0.0.0 --port 8000 > "$PROJECT_ROOT/logs/rewrite.log" 2>&1 &
REWRITE_PID=$!

echo -e "${BLUE}Starting Summarize Service on port 8001${NC}"
cd "$PROJECT_ROOT/summarize-service"
uvicorn app:app --host 0.0.0.0 --port 8001 > "$PROJECT_ROOT/logs/summarize.log" 2>&1 &
SUMMARIZE_PID=$!

echo -e "${BLUE}Starting Email Service on port 8002${NC}"
cd "$PROJECT_ROOT/email-service"
uvicorn app:app --host 0.0.0.0 --port 8002 > "$PROJECT_ROOT/logs/email.log" 2>&1 &
EMAIL_PID=$!

# DEVOPS: Wait for each service to become ready (not just started)
echo ""
echo -e "${BLUE}Waiting for services to become ready...${NC}"

if ! wait_for_service_ready "Rewrite Service" 8000; then
    echo -e "${RED}✗ Rewrite Service failed to start${NC}"
    tail -20 "$PROJECT_ROOT/logs/rewrite.log"
    cleanup
    exit 1
fi

if ! wait_for_service_ready "Summarize Service" 8001; then
    echo -e "${RED}✗ Summarize Service failed to start${NC}"
    tail -20 "$PROJECT_ROOT/logs/summarize.log"
    cleanup
    exit 1
fi

if ! wait_for_service_ready "Email Service" 8002; then
    echo -e "${RED}✗ Email Service failed to start${NC}"
    tail -20 "$PROJECT_ROOT/logs/email.log"
    cleanup
    exit 1
fi

echo -e "${GREEN}✓ All microservices are ready${NC}"

# Start NGINX Gateway
echo ""
echo -e "${BLUE}Starting NGINX Gateway...${NC}"

# DEVOPS: Stop any existing container (idempotency)
docker stop genai-gateway 2>/dev/null || true
docker rm genai-gateway 2>/dev/null || true

# DEVOPS BEST PRACTICE: Image Caching Strategy
# Check if image exists locally before building
# This enables:
# 1. Offline operation after first build
# 2. Faster startup times
# 3. No dependency on network/internet
# 4. Production-grade reliability
cd "$PROJECT_ROOT/nginx-gateway"

if check_docker_image "genai-gateway"; then
    echo -e "${GREEN}✓ Using cached genai-gateway image (offline-friendly)${NC}"
else
    echo -e "${YELLOW}⚠ genai-gateway image not found. Building...${NC}"
    
    # DEVOPS: Use --pull=false to avoid re-pulling base images
    # This prevents network timeouts and uses locally cached nginx:alpine
    if docker build --pull=false -t genai-gateway . > "$PROJECT_ROOT/logs/docker-build.log" 2>&1; then
        echo -e "${GREEN}✓ Successfully built genai-gateway image${NC}"
    else
        echo -e "${RED}✗ Failed to build NGINX gateway image${NC}"
        echo -e "${YELLOW}Attempting build with base image pull (requires internet)...${NC}"
        
        # Fallback: try with --pull=true if --pull=false fails
        if ! docker build --pull=true -t genai-gateway . > "$PROJECT_ROOT/logs/docker-build.log" 2>&1; then
            echo -e "${RED}✗ Build failed even with image pull${NC}"
            cat "$PROJECT_ROOT/logs/docker-build.log"
            cleanup
            exit 1
        fi
        echo -e "${GREEN}✓ Successfully built genai-gateway image (with pull)${NC}"
    fi
fi

# DEVOPS: Start gateway container with configuration baked in
# Using host network mode on Linux for direct localhost access
# Container is ephemeral, but image is preserved for reuse
docker run -d --name genai-gateway \
    --network=host \
    -e GENAI_PROVIDER \
    -e GENAI_MODEL \
    -e GENAI_GEMINI_BASE_URL \
    -e GENAI_API_BASE_URL \
    -e GENAI_API_KEY \
    genai-gateway > /dev/null

sleep 2

if docker ps | grep genai-gateway > /dev/null; then
    echo -e "${GREEN}✓ NGINX Gateway container running${NC}"
else
    echo -e "${RED}✗ NGINX Gateway failed to start${NC}"
    docker logs genai-gateway
    cleanup
    exit 1
fi

# DEVOPS: Critical validation - ensure gateway can reach backends
# This prevents 502 errors and ensures system is truly ready
echo ""
echo -e "${BLUE}Validating gateway routing...${NC}"

if ! validate_gateway_routing "rewrite"; then
    echo -e "${RED}✗ Gateway cannot reach rewrite service${NC}"
    docker logs genai-gateway | tail -20
    cleanup
    exit 1
fi
echo -e "${GREEN}✓ Gateway → Rewrite Service: OK${NC}"

if ! validate_gateway_routing "summarize"; then
    echo -e "${RED}✗ Gateway cannot reach summarize service${NC}"
    docker logs genai-gateway | tail -20
    cleanup
    exit 1
fi
echo -e "${GREEN}✓ Gateway → Summarize Service: OK${NC}"

if ! validate_gateway_routing "email"; then
    echo -e "${RED}✗ Gateway cannot reach email service${NC}"
    docker logs genai-gateway | tail -20
    cleanup
    exit 1
fi
echo -e "${GREEN}✓ Gateway → Email Service: OK${NC}"

echo -e "${GREEN}✓ All gateway routes validated${NC}"

# Start Frontend
echo ""
echo -e "${BLUE}Starting Frontend...${NC}"
cd "$PROJECT_ROOT/frontend"
export VITE_GATEWAY_URL=http://localhost:8088
nohup npm run dev > "$PROJECT_ROOT/logs/frontend.log" 2>&1 &
FRONTEND_PID=$!

sleep 3

# Save PIDs to file for stop script
echo "$REWRITE_PID" > "$PROJECT_ROOT/logs/rewrite.pid"
echo "$SUMMARIZE_PID" > "$PROJECT_ROOT/logs/summarize.pid"
echo "$EMAIL_PID" > "$PROJECT_ROOT/logs/email.pid"
echo "$FRONTEND_PID" > "$PROJECT_ROOT/logs/frontend.pid"

# Display status
echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}✓ System Ready - All Validations Passed${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "${BLUE}Service URLs:${NC}"
echo -e "  Frontend:        ${GREEN}http://localhost:5173${NC}"
echo -e "  NGINX Gateway:   ${GREEN}http://localhost:8088${NC}"
echo -e "  Rewrite API:     http://localhost:8000/docs"
echo -e "  Summarize API:   http://localhost:8001/docs"
echo -e "  Email API:       http://localhost:8002/docs"
echo ""
echo -e "${BLUE}Readiness Endpoints:${NC}"
echo -e "  Rewrite:    http://localhost:8000/ready"
echo -e "  Summarize:  http://localhost:8001/ready"
echo -e "  Email:      http://localhost:8002/ready"
echo ""
echo -e "${BLUE}Logs:${NC}"
echo -e "  Check logs/ directory for service logs"
echo ""
echo -e "${BLUE}Process Management:${NC}"
echo -e "  Stop all services: ${GREEN}./stop-dev.sh${NC}"
echo -e "  Check status:      ${GREEN}./status.sh${NC}"
echo -e "  Run tests:         ${GREEN}./test-all.sh${NC}"
echo -e "  View logs:         ${GREEN}tail -f logs/*.log${NC}"
echo ""
echo -e "${GREEN}🚀 Production-grade DevOps: Idempotent, validated, ready!${NC}"
echo ""
