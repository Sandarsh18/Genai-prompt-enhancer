#!/bin/bash

# Demo script to showcase improved outputs

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  GenAI Prompt Enhancer - Demo${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Test 1: Professional Rewrite
echo -e "${CYAN}📝 Test 1: Professional Rewrite${NC}"
echo "Input: 'i wanna write a sick leave letter. im not feeling good today.'"
echo ""
echo -e "${GREEN}Output:${NC}"
curl -s -X POST http://localhost:8088/rewrite \
  -H "Content-Type: application/json" \
  -d '{"text":"i wanna write a sick leave letter. im not feeling good today.","tone":"professional"}' | jq -r '.result'
echo ""
echo "---"
echo ""

# Test 2: Formal Rewrite
echo -e "${CYAN}✍️ Test 2: Formal Rewrite${NC}"
echo "Input: 'we can't attend the meeting. we won't be available.'"
echo ""
echo -e "${GREEN}Output:${NC}"
curl -s -X POST http://localhost:8088/rewrite \
  -H "Content-Type: application/json" \
  -d '{"text":"we cant attend the meeting. we wont be available.","tone":"formal"}' | jq -r '.result'
echo ""
echo "---"
echo ""

# Test 3: Smart Summarization
echo -e "${CYAN}📊 Test 3: Smart Summarization${NC}"
echo "Input: Long paragraph about project milestones..."
echo ""
echo -e "${GREEN}Output:${NC}"
curl -s -X POST http://localhost:8088/summarize \
  -H "Content-Type: application/json" \
  -d '{"text":"The project has three main phases. The critical first phase involves planning. The second phase is important for implementation. Some minor tasks can be deferred. The key deliverable is the final report. The significant achievement would be completing on time. Additional resources may be needed.","ratio":0.4}' | jq -r '.result'
echo ""
echo "---"
echo ""

# Test 4: Professional Email
echo -e "${CYAN}📧 Test 4: Professional Email (Update)${NC}"
echo "Input: 'project milestone completed successfully ahead of schedule'"
echo ""
echo -e "${GREEN}Output:${NC}"
curl -s -X POST http://localhost:8088/email \
  -H "Content-Type: application/json" \
  -d '{"text":"project milestone completed successfully ahead of schedule","recipient":"Team","goal":"update"}' | jq -r '.result'
echo ""
echo "---"
echo ""

# Test 5: Urgent Email
echo -e "${CYAN}🚨 Test 5: Urgent Email${NC}"
echo "Input: 'critical bug found in production. need immediate attention asap'"
echo ""
echo -e "${GREEN}Output:${NC}"
curl -s -X POST http://localhost:8088/email \
  -H "Content-Type: application/json" \
  -d '{"text":"critical bug found in production. need immediate attention asap","recipient":"Development Team","goal":"urgent request"}' | jq -r '.result'
echo ""
echo "---"
echo ""

echo -e "${GREEN}✨ Demo Complete!${NC}"
echo ""
echo -e "${BLUE}The application now provides:${NC}"
echo "  ✓ Better text processing and capitalization"
echo "  ✓ Tone-aware rewriting (professional, formal, casual, friendly)"
echo "  ✓ Smart sentence selection in summaries"
echo "  ✓ Context-aware email generation"
echo "  ✓ Proper email formatting with greetings and closings"
echo ""
echo -e "${CYAN}Open http://localhost:5173 to try the enhanced UI!${NC}"
