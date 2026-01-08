#!/bin/bash

# Status check script for GenAI Prompt Enhancer (Docker Version)
# Checks Docker container health instead of processes

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}GenAI Prompt Enhancer - Status Check${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check Docker daemon
if ! docker info &> /dev/null; then
    echo -e "${RED}✗ Docker daemon is not running${NC}"
    exit 1
fi

echo -e "${CYAN}Container Status:${NC}"
echo ""

# Check each container
check_container() {
    local container_name=$1
    local port=$2
    local display_name=$3
    
    if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        local status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null)
        local health=$(docker inspect -f '{{.State.Health.Status}}' "$container_name" 2>/dev/null)
        
        if [ "$status" = "running" ]; then
            # Test endpoint
            if curl -sf "http://localhost:$port" > /dev/null 2>&1 || curl -sf "http://localhost:$port/ready" > /dev/null 2>&1 || curl -sf "http://localhost:$port/health" > /dev/null 2>&1; then
                echo -e "  ${GREEN}✓${NC} $display_name (port $port) - Running & Healthy"
            else
                echo -e "  ${YELLOW}⚠${NC} $display_name (port $port) - Running but not responding"
            fi
        else
            echo -e "  ${RED}✗${NC} $display_name - Status: $status"
        fi
    else
        echo -e "  ${RED}✗${NC} $display_name - Not running"
    fi
}

echo -e "${BLUE}Backend Services:${NC}"
check_container "rewrite-service" 8000 "Rewrite Service"
check_container "summarize-service" 8001 "Summarize Service"
check_container "email-service" 8002 "Email Service"

echo ""
echo -e "${BLUE}Gateway:${NC}"
check_container "nginx-gateway" 8088 "NGINX Gateway"

# Test gateway routing
if docker ps --format "{{.Names}}" | grep -q "^nginx-gateway$"; then
    echo -e "  ${YELLOW}Testing gateway routing...${NC}"
    
    if curl -s -X POST http://localhost:8088/rewrite -H "Content-Type: application/json" -d '{"text":"test"}' > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Gateway routing: WORKING"
    else
        echo -e "  ${YELLOW}⚠${NC} Gateway routing: May have issues"
    fi
fi

echo ""
echo -e "${BLUE}Frontend:${NC}"
check_container "frontend" 5173 "Frontend"

echo ""
echo -e "${CYAN}Docker Network:${NC}"
if docker network inspect genai-network &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} genai-network exists"
    echo -e "  ${BLUE}Connected containers:${NC}"
    docker network inspect genai-network --format '{{range .Containers}}    - {{.Name}}{{"\n"}}{{end}}' 2>/dev/null || echo "    None"
else
    echo -e "  ${RED}✗${NC} genai-network not found"
fi

echo ""
echo -e "${CYAN}Quick Stats:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "frontend|nginx-gateway|rewrite-service|summarize-service|email-service" || echo "No containers running"

echo ""
echo -e "${BLUE}Management Commands:${NC}"
echo -e "  View logs:      ${GREEN}docker logs <container-name>${NC}"
echo -e "  Stop all:       ${GREEN}./stop-dev.sh${NC}"
echo -e "  Restart:        ${GREEN}./stop-dev.sh && ./start-dev.sh${NC}"
echo -e "  Run tests:      ${GREEN}./test-all.sh${NC}"
echo ""
