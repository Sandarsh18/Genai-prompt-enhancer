.PHONY: help install start stop clean test logs status

PROJECT_ROOT := $(shell pwd)

help:
	@echo "GenAI Prompt Enhancer - Development Commands"
	@echo "============================================="
	@echo "make install    - Install all dependencies"
	@echo "make start      - Start all services"
	@echo "make stop       - Stop all services"
	@echo "make status     - Check status of all services"
	@echo "make logs       - Show logs from all services"
	@echo "make clean      - Clean up logs and temporary files"
	@echo "make test       - Run a quick test of all endpoints"

install:
	@echo "Installing Python dependencies..."
	@pip3 install -r rewrite-service/requirements.txt
	@pip3 install -r summarize-service/requirements.txt
	@pip3 install -r email-service/requirements.txt
	@echo "Installing frontend dependencies..."
	@cd frontend && npm install
	@echo "✓ All dependencies installed"

start:
	@echo "Starting all services..."
	@./start-dev.sh

stop:
	@echo "Stopping all services..."
	@./stop-dev.sh

status:
	@echo "Checking service status..."
	@echo ""
	@echo "Python Services:"
	@ps aux | grep "uvicorn app:app" | grep -v grep || echo "  No Python services running"
	@echo ""
	@echo "Docker Containers:"
	@docker ps | grep genai-gateway || echo "  NGINX Gateway not running"
	@echo ""
	@echo "Node Processes:"
	@ps aux | grep "vite" | grep -v grep || echo "  Frontend not running"
	@echo ""
	@echo "Port Status:"
	@lsof -i :8000 -sTCP:LISTEN | tail -n +2 || echo "  Port 8000: free"
	@lsof -i :8001 -sTCP:LISTEN | tail -n +2 || echo "  Port 8001: free"
	@lsof -i :8002 -sTCP:LISTEN | tail -n +2 || echo "  Port 8002: free"
	@lsof -i :8080 -sTCP:LISTEN | tail -n +2 || echo "  Port 8080: free"
	@lsof -i :5173 -sTCP:LISTEN | tail -n +2 || echo "  Port 5173: free"

logs:
	@echo "Recent logs from all services:"
	@echo ""
	@if [ -f logs/rewrite.log ]; then echo "=== Rewrite Service ==="; tail -10 logs/rewrite.log; echo ""; fi
	@if [ -f logs/summarize.log ]; then echo "=== Summarize Service ==="; tail -10 logs/summarize.log; echo ""; fi
	@if [ -f logs/email.log ]; then echo "=== Email Service ==="; tail -10 logs/email.log; echo ""; fi
	@if [ -f logs/frontend.log ]; then echo "=== Frontend ==="; tail -10 logs/frontend.log; echo ""; fi
	@if docker ps | grep genai-gateway > /dev/null; then echo "=== NGINX Gateway ==="; docker logs --tail 10 genai-gateway; fi

clean:
	@echo "Cleaning up..."
	@rm -rf logs/
	@rm -rf frontend/node_modules/.vite
	@rm -rf rewrite-service/__pycache__
	@rm -rf summarize-service/__pycache__
	@rm -rf email-service/__pycache__
	@echo "✓ Cleanup complete"

test:
	@echo "Testing all services..."
	@echo ""
	@echo "Testing Rewrite Service:"
	@curl -s -X POST http://localhost:8000/rewrite -H "Content-Type: application/json" -d '{"text":"hello world"}' | jq -r '.result' || echo "  ✗ Failed"
	@echo ""
	@echo "Testing Summarize Service:"
	@curl -s -X POST http://localhost:8001/summarize -H "Content-Type: application/json" -d '{"text":"This is a long text. It has many sentences. We want to make it shorter."}' | jq -r '.result' || echo "  ✗ Failed"
	@echo ""
	@echo "Testing Email Service:"
	@curl -s -X POST http://localhost:8002/email -H "Content-Type: application/json" -d '{"text":"Meeting tomorrow"}' | jq -r '.result' || echo "  ✗ Failed"
	@echo ""
	@echo "Testing Gateway:"
	@curl -s -X POST http://localhost:8080/rewrite -H "Content-Type: application/json" -d '{"text":"test via gateway"}' | jq -r '.result' || echo "  ✗ Failed"
	@echo ""
	@echo "Testing Frontend:"
	@curl -s http://localhost:5173 > /dev/null && echo "  ✓ Frontend is accessible" || echo "  ✗ Frontend not accessible"
