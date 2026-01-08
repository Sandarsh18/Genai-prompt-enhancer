#!/bin/bash

# GenAI Prompt Enhancer - Docker Stop Script
# Safely stops all containers without deleting Docker images
#
# DEVOPS PRINCIPLES:
# 1. Safe to run multiple times (idempotent)
# 2. Preserves Docker images for offline operation
# 3. Only stops project-specific containers
# 4. Graceful shutdown with proper cleanup
# 5. Production-grade: Can be automated in CI/CD

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Stopping GenAI Prompt Enhancer...${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Stop Docker containers gracefully
echo -e "${CYAN}Stopping Docker containers...${NC}"

# Include old container name for backward compatibility
containers=("frontend" "nginx-gateway" "genai-gateway" "email-service" "summarize-service" "rewrite-service")

for container in "${containers[@]}"; do
    if docker ps -q -f name="$container" | grep -q .; then
        echo -e "${YELLOW}Stopping $container...${NC}"
        docker stop "$container" 2>/dev/null
        echo -e "${GREEN}✓ $container stopped${NC}"
    else
        echo -e "${YELLOW}⚠ $container not running${NC}"
    fi
done

echo ""

# Remove containers (but preserve images!)
echo -e "${CYAN}Removing containers...${NC}"

for container in "${containers[@]}"; do
    if docker ps -aq -f name="$container" | grep -q .; then
        docker rm "$container" 2>/dev/null
        echo -e "${GREEN}✓ $container removed${NC}"
    fi
done

echo ""

# Also stop any old host-based processes (for backward compatibility)
echo -e "${CYAN}Cleaning up any old host processes...${NC}"
if pkill -f "uvicorn app:app" 2>/dev/null; then
    echo -e "${GREEN}✓ Python services stopped${NC}"
else
    echo -e "${YELLOW}⚠ No Python services running${NC}"
fi

if pkill -f "vite" 2>/dev/null; then
    echo -e "${GREEN}✓ Frontend stopped${NC}"
else
    echo -e "${YELLOW}⚠ Frontend not running${NC}"
fi

echo ""

# Verify cleanup
running=$(docker ps --filter "name=rewrite-service" --filter "name=summarize-service" --filter "name=email-service" --filter "name=nginx-gateway" --filter "name=frontend" -q | wc -l)

if [ "$running" -eq 0 ]; then
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}✓ All services stopped successfully${NC}"
    echo -e "${GREEN}=========================================${NC}"
else
    echo -e "${YELLOW}⚠ Some containers may still be running${NC}"
    docker ps --filter "name=genai" --filter "name=frontend"
fi

echo ""
echo -e "${CYAN}Docker Images Preserved:${NC}"
docker images | grep -E "genai-|frontend" || echo -e "${YELLOW}  No project images found${NC}"
echo ""
echo -e "${BLUE}To restart: ${GREEN}./start-dev.sh${NC}"
echo ""
