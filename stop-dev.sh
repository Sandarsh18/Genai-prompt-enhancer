#!/bin/bash

# Kill script for GenAI Prompt Enhancer services

echo "Stopping all services..."

# Kill Python services
pkill -f "uvicorn app:app" || true

# Kill frontend
pkill -f "vite" || true

# Stop and remove docker container
docker stop genai-gateway 2>/dev/null || true
docker rm genai-gateway 2>/dev/null || true

echo "All services stopped."
