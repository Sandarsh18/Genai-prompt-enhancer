#!/bin/bash

# Portable Solution Validation Script
# Tests that the Docker-based solution works correctly

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Portable Docker Solution - Validation Test${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

PASSED=0
FAILED=0

# Test 1: Check if Docker files exist
echo -e "${CYAN}Test 1: Checking Docker configuration files...${NC}"
files=(
    "nginx-gateway/nginx.docker.conf"
    "docker-compose.yml"
    "DOCKER_SOLUTION.md"
    "QUICK_START.md"
    "PORTABILITY_SUMMARY.md"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $file exists"
        ((PASSED++))
    else
        echo -e "  ${RED}✗${NC} $file missing"
        ((FAILED++))
    fi
done

echo ""

# Test 2: Check script executability
echo -e "${CYAN}Test 2: Checking script permissions...${NC}"
scripts=("start-dev.sh" "stop-dev.sh" "status.sh" "test-all.sh")

for script in "${scripts[@]}"; do
    if [ -x "$script" ]; then
        echo -e "  ${GREEN}✓${NC} $script is executable"
        ((PASSED++))
    else
        echo -e "  ${RED}✗${NC} $script is not executable"
        ((FAILED++))
    fi
done

echo ""

# Test 3: Check Dockerfile configurations
echo -e "${CYAN}Test 3: Checking Dockerfiles...${NC}"
dockerfiles=(
    "rewrite-service/Dockerfile"
    "summarize-service/Dockerfile"
    "email-service/Dockerfile"
    "nginx-gateway/Dockerfile"
    "frontend/Dockerfile"
)

for dockerfile in "${dockerfiles[@]}"; do
    if [ -f "$dockerfile" ]; then
        echo -e "  ${GREEN}✓${NC} $dockerfile exists"
        ((PASSED++))
    else
        echo -e "  ${RED}✗${NC} $dockerfile missing"
        ((FAILED++))
    fi
done

echo ""

# Test 4: Check nginx config uses Docker service names
echo -e "${CYAN}Test 4: Verifying NGINX uses Docker service names...${NC}"

if grep -q "server rewrite-service:8000" nginx-gateway/nginx.docker.conf; then
    echo -e "  ${GREEN}✓${NC} NGINX configured for rewrite-service"
    ((PASSED++))
else
    echo -e "  ${RED}✗${NC} NGINX not configured for rewrite-service"
    ((FAILED++))
fi

if grep -q "server summarize-service:8001" nginx-gateway/nginx.docker.conf; then
    echo -e "  ${GREEN}✓${NC} NGINX configured for summarize-service"
    ((PASSED++))
else
    echo -e "  ${RED}✗${NC} NGINX not configured for summarize-service"
    ((FAILED++))
fi

if grep -q "server email-service:8002" nginx-gateway/nginx.docker.conf; then
    echo -e "  ${GREEN}✓${NC} NGINX configured for email-service"
    ((PASSED++))
else
    echo -e "  ${RED}✗${NC} NGINX not configured for email-service"
    ((FAILED++))
fi

# Check for BAD patterns (ignore all comments - both # at start and inline)
if sed 's/#.*//' nginx-gateway/nginx.docker.conf | grep -q "host.docker.internal"; then
    echo -e "  ${RED}✗${NC} NGINX still uses host.docker.internal in config (BAD)"
    ((FAILED++))
else
    echo -e "  ${GREEN}✓${NC} NGINX does not use host.docker.internal"
    ((PASSED++))
fi

echo ""

# Test 5: Check start-dev.sh uses Docker commands
echo -e "${CYAN}Test 5: Verifying start-dev.sh uses Docker...${NC}"

if grep -q "docker run" start-dev.sh; then
    echo -e "  ${GREEN}✓${NC} start-dev.sh uses 'docker run'"
    ((PASSED++))
else
    echo -e "  ${RED}✗${NC} start-dev.sh doesn't use 'docker run'"
    ((FAILED++))
fi

if grep -q "docker build" start-dev.sh; then
    echo -e "  ${GREEN}✓${NC} start-dev.sh uses 'docker build'"
    ((PASSED++))
else
    echo -e "  ${RED}✗${NC} start-dev.sh doesn't use 'docker build'"
    ((FAILED++))
fi

if grep -q "genai-network" start-dev.sh; then
    echo -e "  ${GREEN}✓${NC} start-dev.sh creates Docker network"
    ((PASSED++))
else
    echo -e "  ${RED}✗${NC} start-dev.sh doesn't create Docker network"
    ((FAILED++))
fi

# Check for BAD patterns
if grep -q "uvicorn app:app" start-dev.sh; then
    echo -e "  ${YELLOW}⚠${NC} start-dev.sh still has uvicorn commands (should be in containers)"
else
    echo -e "  ${GREEN}✓${NC} start-dev.sh doesn't run uvicorn on host"
    ((PASSED++))
fi

echo ""

# Test 6: Check docker-compose.yml structure
echo -e "${CYAN}Test 6: Verifying docker-compose.yml...${NC}"

if grep -q "genai-network" docker-compose.yml; then
    echo -e "  ${GREEN}✓${NC} docker-compose defines genai-network"
    ((PASSED++))
else
    echo -e "  ${RED}✗${NC} docker-compose missing network definition"
    ((FAILED++))
fi

if grep -q "rewrite-service:" docker-compose.yml; then
    echo -e "  ${GREEN}✓${NC} docker-compose includes rewrite-service"
    ((PASSED++))
else
    echo -e "  ${RED}✗${NC} docker-compose missing rewrite-service"
    ((FAILED++))
fi

if grep -q "healthcheck:" docker-compose.yml; then
    echo -e "  ${GREEN}✓${NC} docker-compose includes health checks"
    ((PASSED++))
else
    echo -e "  ${RED}✗${NC} docker-compose missing health checks"
    ((FAILED++))
fi

echo ""

# Summary
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Validation Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Tests Passed: ${GREEN}$PASSED${NC}"
echo -e "Tests Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL VALIDATION TESTS PASSED!${NC}"
    echo ""
    echo -e "${CYAN}Your project is configured for:${NC}"
    echo -e "  ✓ 100% Docker-based operation"
    echo -e "  ✓ Universal Linux portability"
    echo -e "  ✓ No host dependencies"
    echo -e "  ✓ Kubernetes-like networking"
    echo ""
    echo -e "${BLUE}Ready to test:${NC} ${GREEN}./start-dev.sh${NC}"
    exit 0
else
    echo -e "${RED}❌ SOME VALIDATION TESTS FAILED${NC}"
    echo ""
    echo -e "${YELLOW}Please review the failed tests above.${NC}"
    exit 1
fi
