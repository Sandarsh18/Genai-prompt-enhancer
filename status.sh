#!/bin/bash

# Status check script for GenAI Prompt Enhancer

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}GenAI Prompt Enhancer - Status Check${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Check Python services
echo -e "${BLUE}Python Microservices:${NC}"
for port in 8000 8001 8002; do
    service_name=""
    case $port in
        8000) service_name="Rewrite" ;;
        8001) service_name="Summarize" ;;
        8002) service_name="Email" ;;
    esac
    
    if curl -s http://localhost:$port/docs > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $service_name service (port $port)"
    else
        echo -e "  ${RED}✗${NC} $service_name service (port $port)"
    fi
done

echo ""

# Check NGINX Gateway
echo -e "${BLUE}NGINX Gateway:${NC}"
if docker ps | grep genai-gateway > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Gateway container running (port 8088)"
    
    # Test gateway endpoints
    if curl -s -X POST http://localhost:8088/rewrite -H "Content-Type: application/json" -d '{"text":"test"}' > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Gateway routing working"
    else
        echo -e "  ${YELLOW}⚠${NC} Gateway running but routing issues"
    fi
else
    echo -e "  ${RED}✗${NC} Gateway not running"
fi

echo ""

# Check Frontend
echo -e "${BLUE}Frontend:${NC}"
if curl -s http://localhost:5173 > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Frontend accessible (port 5173)"
else
    echo -e "  ${RED}✗${NC} Frontend not accessible"
fi

echo ""

# Show service URLs
echo -e "${BLUE}Service URLs:${NC}"
echo -e "  Frontend:        ${GREEN}http://localhost:5173${NC}"
echo -e "  NGINX Gateway:   ${GREEN}http://localhost:8088${NC}"
echo -e "  Rewrite API:     http://localhost:8000/docs"
echo -e "  Summarize API:   http://localhost:8001/docs"
echo -e "  Email API:       http://localhost:8002/docs"

echo ""

# Check for logs
echo -e "${BLUE}Log Files:${NC}"
for log in rewrite summarize email frontend; do
    if [ -f "$PROJECT_ROOT/logs/$log.log" ]; then
        size=$(du -h "$PROJECT_ROOT/logs/$log.log" | cut -f1)
        echo -e "  $log.log (${size})"
    fi
done

echo ""

# Show running processes
echo -e "${BLUE}Running Processes:${NC}"
ps aux | grep -E "uvicorn|vite|genai-gateway" | grep -v grep | awk '{print "  " $2 " - " $11 " " $12 " " $13}' || echo "  No processes found"
