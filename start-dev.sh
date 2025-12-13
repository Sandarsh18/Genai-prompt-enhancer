#!/bin/bash

# GenAI Prompt Enhancer - Development Startup Script
# This script starts all microservices, the gateway, and the frontend

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

# Function to check if port is in use
check_port() {
    if lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
        echo -e "${YELLOW}⚠ Port $1 is already in use${NC}"
        echo -e "  Attempting to free port..."
        lsof -ti:$1 | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
}

# Clean up function
cleanup() {
    echo ""
    echo -e "${YELLOW}Shutting down services...${NC}"
    jobs -p | xargs kill 2>/dev/null || true
    # Clean up docker container
    docker stop genai-gateway 2>/dev/null || true
    docker rm genai-gateway 2>/dev/null || true
    exit 0
}

trap cleanup SIGINT SIGTERM

# Check and free ports
echo -e "${BLUE}Checking ports...${NC}"
check_port 8000
check_port 8001
check_port 8002
check_port 8088
check_port 5173

# Create logs directory
mkdir -p logs

# Start microservices
echo ""
echo -e "${BLUE}Starting microservices...${NC}"

echo -e "${GREEN}✓ Starting Rewrite Service on port 8000${NC}"
cd "$PROJECT_ROOT/rewrite-service"
uvicorn app:app --host 0.0.0.0 --port 8000 > "$PROJECT_ROOT/logs/rewrite.log" 2>&1 &
REWRITE_PID=$!
sleep 2

echo -e "${GREEN}✓ Starting Summarize Service on port 8001${NC}"
cd "$PROJECT_ROOT/summarize-service"
uvicorn app:app --host 0.0.0.0 --port 8001 > "$PROJECT_ROOT/logs/summarize.log" 2>&1 &
SUMMARIZE_PID=$!
sleep 2

echo -e "${GREEN}✓ Starting Email Service on port 8002${NC}"
cd "$PROJECT_ROOT/email-service"
uvicorn app:app --host 0.0.0.0 --port 8002 > "$PROJECT_ROOT/logs/email.log" 2>&1 &
EMAIL_PID=$!
sleep 2

# Check if services are running
echo ""
echo -e "${BLUE}Checking service health...${NC}"
for port in 8000 8001 8002; do
    if curl -s http://localhost:$port/docs > /dev/null; then
        echo -e "${GREEN}✓ Service on port $port is healthy${NC}"
    else
        echo -e "${RED}✗ Service on port $port failed to start${NC}"
    fi
done

# Start NGINX Gateway
echo ""
echo -e "${BLUE}Starting NGINX Gateway...${NC}"

# Stop any existing container
docker stop genai-gateway 2>/dev/null || true
docker rm genai-gateway 2>/dev/null || true

# Build gateway image
cd "$PROJECT_ROOT/nginx-gateway"
if ! docker build -t genai-gateway . > "$PROJECT_ROOT/logs/docker-build.log" 2>&1; then
    echo -e "${RED}✗ Failed to build NGINX gateway image${NC}"
    cat "$PROJECT_ROOT/logs/docker-build.log"
    cleanup
    exit 1
fi

# Start gateway container (config is baked into image via Dockerfile)
docker run -d --name genai-gateway \
    --add-host host.docker.internal:host-gateway \
    -e GENAI_PROVIDER \
    -e GENAI_MODEL \
    -e GENAI_GEMINI_BASE_URL \
    -e GENAI_API_BASE_URL \
    -e GENAI_API_KEY \
    -p 8088:8080 \
    genai-gateway > /dev/null

sleep 2

if docker ps | grep genai-gateway > /dev/null; then
    echo -e "${GREEN}✓ NGINX Gateway started on port 8088${NC}"
else
    echo -e "${RED}✗ NGINX Gateway failed to start${NC}"
    docker logs genai-gateway
    cleanup
    exit 1
fi

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
echo -e "${GREEN}All services started successfully!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "${BLUE}Service URLs:${NC}"
echo -e "  Frontend:        ${GREEN}http://localhost:5173${NC}"
echo -e "  NGINX Gateway:   ${GREEN}http://localhost:8088${NC}"
echo -e "  Rewrite API:     http://localhost:8000/docs"
echo -e "  Summarize API:   http://localhost:8001/docs"
echo -e "  Email API:       http://localhost:8002/docs"
echo ""
echo -e "${BLUE}Logs:${NC}"
echo -e "  Check logs/ directory for service logs"
echo ""
echo -e "${BLUE}Process Management:${NC}"
echo -e "  Stop all services: ${GREEN}./stop-dev.sh${NC}"
echo -e "  Check status:      ${GREEN}./status.sh${NC}"
echo -e "  View logs:         ${GREEN}tail -f logs/*.log${NC}"
echo ""
echo -e "${GREEN}Services running in background. Terminal is now free.${NC}"
echo ""
