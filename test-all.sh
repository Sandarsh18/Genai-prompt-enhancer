#!/bin/bash

# Comprehensive test script for GenAI Prompt Enhancer

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}GenAI Prompt Enhancer - Complete Test${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Test 1: Check all services are running
echo -e "${BLUE}Test 1: Service Health Checks${NC}"
services_ok=true

for port in 8000 8001 8002; do
    if curl -s http://localhost:$port/docs > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Port $port responding"
    else
        echo -e "  ${RED}✗${NC} Port $port not responding"
        services_ok=false
    fi
done

if docker ps | grep genai-gateway > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Gateway container running"
else
    echo -e "  ${RED}✗${NC} Gateway container not running"
    services_ok=false
fi

if curl -s http://localhost:5173 > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Frontend accessible"
else
    echo -e "  ${RED}✗${NC} Frontend not accessible"
    services_ok=false
fi

echo ""

# Test 2: CORS Configuration
echo -e "${BLUE}Test 2: CORS Configuration${NC}"
cors_ok=true

response=$(curl -s -X OPTIONS http://localhost:8088/rewrite \
    -H "Origin: http://localhost:5173" \
    -H "Access-Control-Request-Method: POST" \
    -H "Access-Control-Request-Headers: content-type" \
    -i 2>&1)

if echo "$response" | grep -q "Access-Control-Allow-Origin: \*"; then
    echo -e "  ${GREEN}✓${NC} CORS Allow-Origin header present"
else
    echo -e "  ${RED}✗${NC} CORS Allow-Origin header missing"
    cors_ok=false
fi

if echo "$response" | grep -q "Access-Control-Allow-Methods"; then
    echo -e "  ${GREEN}✓${NC} CORS Allow-Methods header present"
else
    echo -e "  ${RED}✗${NC} CORS Allow-Methods header missing"
    cors_ok=false
fi

echo ""

# Test 3: Functional Tests
echo -e "${BLUE}Test 3: Functional Tests${NC}"
functional_ok=true

# DEVOPS: Test Rewrite (accept both mock and GenAI responses)
result=$(curl -s -X POST http://localhost:8088/rewrite \
    -H "Content-Type: application/json" \
    -d '{"text":"test message"}' 2>&1)

# Check if result field exists (service is working)
if echo "$result" | grep -q '"result"'; then
    mode=$(echo "$result" | jq -r '.mode' 2>/dev/null || echo "unknown")
    echo -e "  ${GREEN}✓${NC} Rewrite service functional (mode: $mode)"
    if [ "$mode" = "mock" ]; then
        reason=$(echo "$result" | jq -r '.reason' 2>/dev/null || echo "unknown")
        echo -e "    ${YELLOW}ℹ${NC} Using mock mode (reason: $reason)"
    fi
else
    echo -e "  ${RED}✗${NC} Rewrite service failed"
    echo "    Response: $result"
    functional_ok=false
fi

# DEVOPS: Test Summarize (accept both mock and GenAI responses)
result=$(curl -s -X POST http://localhost:8088/summarize \
    -H "Content-Type: application/json" \
    -d '{"text":"First. Second. Third. Fourth. Fifth."}' 2>&1)

if echo "$result" | grep -q '"result"'; then
    mode=$(echo "$result" | jq -r '.mode' 2>/dev/null || echo "unknown")
    echo -e "  ${GREEN}✓${NC} Summarize service functional (mode: $mode)"
    if [ "$mode" = "mock" ]; then
        reason=$(echo "$result" | jq -r '.reason' 2>/dev/null || echo "unknown")
        echo -e "    ${YELLOW}ℹ${NC} Using mock mode (reason: $reason)"
    fi
else
    echo -e "  ${RED}✗${NC} Summarize service failed"
    echo "    Response: $result"
    functional_ok=false
fi

# DEVOPS: Test Email (accept both mock and GenAI responses)
result=$(curl -s -X POST http://localhost:8088/email \
    -H "Content-Type: application/json" \
    -d '{"text":"Meeting tomorrow"}' 2>&1)

if echo "$result" | grep -q '"result"'; then
    mode=$(echo "$result" | jq -r '.mode' 2>/dev/null || echo "unknown")
    echo -e "  ${GREEN}✓${NC} Email service functional (mode: $mode)"
    if [ "$mode" = "mock" ]; then
        reason=$(echo "$result" | jq -r '.reason' 2>/dev/null || echo "unknown")
        echo -e "    ${YELLOW}ℹ${NC} Using mock mode (reason: $reason)"
    fi
else
    echo -e "  ${RED}✗${NC} Email service failed"
    echo "    Response: $result"
    functional_ok=false
fi

echo ""

# Test 4: Gateway Routing
echo -e "${BLUE}Test 4: Gateway Routing${NC}"
routing_ok=true

for endpoint in rewrite summarize email; do
    status=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        http://localhost:8088/$endpoint \
        -H "Content-Type: application/json" \
        -d '{"text":"test"}' 2>&1)
    
    if [ "$status" = "200" ]; then
        echo -e "  ${GREEN}✓${NC} /$endpoint endpoint returning 200"
    else
        echo -e "  ${RED}✗${NC} /$endpoint endpoint returning $status"
        routing_ok=false
    fi
done

echo ""

# Summary
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}==========================================${NC}"

if $services_ok && $cors_ok && $functional_ok && $routing_ok; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    echo ""
    echo -e "${GREEN}The application is fully functional!${NC}"
    echo ""
    echo -e "${BLUE}Access the application at:${NC}"
    echo -e "  Frontend: ${GREEN}http://localhost:5173${NC}"
    echo -e "  Gateway:  ${GREEN}http://localhost:8088${NC}"
    echo ""
    echo -e "${YELLOW}Note:${NC} If the frontend shows errors, try:"
    echo -e "  1. Hard refresh the browser (Ctrl+Shift+R or Cmd+Shift+R)"
    echo -e "  2. Clear browser cache"
    echo -e "  3. Open browser DevTools and check Network tab"
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    echo ""
    echo "Failed checks:"
    $services_ok || echo "  - Service health checks"
    $cors_ok || echo "  - CORS configuration"
    $functional_ok || echo "  - Functional tests"
    $routing_ok || echo "  - Gateway routing"
    echo ""
    echo "Run './status.sh' for more details"
    exit 1
fi
