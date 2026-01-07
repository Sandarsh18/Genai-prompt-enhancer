#!/bin/bash

# GenAI Prompt Enhancer - Stop Script
# Safely stops all services without deleting Docker images
#
# DEVOPS PRINCIPLES:
# 1. Safe to run multiple times (idempotent)
# 2. Preserves Docker images for offline operation
# 3. Only stops project-specific processes
# 4. Graceful shutdown with proper cleanup

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}Stopping GenAI Prompt Enhancer...${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# DEVOPS: Kill Python microservices gracefully
echo -e "${YELLOW}Stopping Python microservices...${NC}"
if pkill -f "uvicorn app:app"; then
    echo -e "${GREEN}✓ Python services stopped${NC}"
else
    echo -e "${YELLOW}⚠ No Python services running${NC}"
fi

# DEVOPS: Kill frontend dev server
echo -e "${YELLOW}Stopping frontend...${NC}"
if pkill -f "vite"; then
    echo -e "${GREEN}✓ Frontend stopped${NC}"
else
    echo -e "${YELLOW}⚠ Frontend not running${NC}"
fi

# DEVOPS: Stop and remove Docker container (but preserve image!)
echo -e "${YELLOW}Stopping NGINX gateway container...${NC}"
if docker stop genai-gateway 2>/dev/null; then
    echo -e "${GREEN}✓ Gateway container stopped${NC}"
else
    echo -e "${YELLOW}⚠ Gateway container not running${NC}"
fi

if docker rm genai-gateway 2>/dev/null; then
    echo -e "${GREEN}✓ Gateway container removed${NC}"
else
    echo -e "${YELLOW}⚠ Gateway container already removed${NC}"
fi

# DEVOPS: Clean up PID files
if [ -d "$PROJECT_ROOT/logs" ]; then
    rm -f "$PROJECT_ROOT/logs"/*.pid 2>/dev/null
fi

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}All services stopped successfully!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "${BLUE}Note: Docker images preserved for offline operation${NC}"
echo -e "  To verify: ${GREEN}docker images | grep genai-gateway${NC}"
echo -e "  To start again: ${GREEN}./start-dev.sh${NC}"
echo ""
