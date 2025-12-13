# GenAI Prompt Enhancer - Quick Start Guide

## 🚀 Running the Project

### Prerequisites
- Python 3.10+
- Node.js 20+
- Docker
- curl (for testing)

### Quick Start (Recommended)

1. **Install dependencies:**
   ```bash
   make install
   # OR manually:
   pip3 install -r rewrite-service/requirements.txt -r summarize-service/requirements.txt -r email-service/requirements.txt
   cd frontend && npm install && cd ..
   ```

2. **Configure API Key (Optional):**
   Edit `.env` file and add your GenAI API key:
   ```bash
   nano .env
   # Set GENAI_API_KEY=your_actual_key_here
   ```
   Get a free API key from: https://aistudio.google.com/apikey
   
   **Note:** The app works without an API key using fallback mode (simulated responses).

3. **Start all services:**
   ```bash
   ./start-dev.sh
   ```
   
   This will start:
   - Rewrite service on port 8000
   - Summarize service on port 8001
   - Email service on port 8002
   - NGINX Gateway on port 8080
   - Frontend on port 5173

4. **Access the application:**
   - **Frontend UI:** http://localhost:5173
   - **API Gateway:** http://localhost:8080
   - **API Documentation:** 
     - Rewrite: http://localhost:8000/docs
     - Summarize: http://localhost:8001/docs
     - Email: http://localhost:8002/docs

### Alternative: Manual Start

Start each service individually in separate terminals:

```bash
# Terminal 1: Rewrite Service
cd rewrite-service && uvicorn app:app --host 0.0.0.0 --port 8000

# Terminal 2: Summarize Service
cd summarize-service && uvicorn app:app --host 0.0.0.0 --port 8001

# Terminal 3: Email Service
cd email-service && uvicorn app:app --host 0.0.0.0 --port 8002

# Terminal 4: NGINX Gateway
docker build -t genai-gateway ./nginx-gateway
docker run --add-host host.docker.internal:host-gateway \
  -v $PWD/nginx-gateway/nginx.local.conf:/etc/nginx/nginx.conf:ro \
  -p 8080:8080 genai-gateway

# Terminal 5: Frontend
cd frontend && VITE_GATEWAY_URL=http://localhost:8080 npm run dev
```

## 📊 Management Commands

### Using Make (Recommended)
```bash
make help       # Show all available commands
make install    # Install all dependencies
make start      # Start all services
make stop       # Stop all services
make status     # Check status of all services
make logs       # Show logs from all services
make test       # Test all endpoints
make clean      # Clean up logs and temp files
```

### Using Scripts
```bash
./start-dev.sh  # Start all services
./stop-dev.sh   # Stop all services
./status.sh     # Check status
```

## 🧪 Testing

### Quick Test
```bash
make test
```

### Manual Testing

Test individual services:
```bash
# Test Rewrite Service
curl -X POST http://localhost:8080/rewrite \
  -H "Content-Type: application/json" \
  -d '{"text":"Make this professional","tone":"formal"}'

# Test Summarize Service
curl -X POST http://localhost:8080/summarize \
  -H "Content-Type: application/json" \
  -d '{"text":"Long text here. Multiple sentences. Need summary."}'

# Test Email Service
curl -X POST http://localhost:8080/email \
  -H "Content-Type: application/json" \
  -d '{"text":"Meeting tomorrow","recipient":"team","goal":"reminder"}'
```

## 🛠️ Troubleshooting

### Port Already in Use
```bash
# Free up ports
./stop-dev.sh
# OR manually:
lsof -ti:8000,8001,8002,8080,5173 | xargs kill -9
```

### Services Not Starting
```bash
# Check status
./status.sh

# View logs
tail -f logs/*.log
# OR
make logs
```

### Docker Issues
```bash
# Restart gateway
docker stop genai-gateway && docker rm genai-gateway
./start-dev.sh
```

### Frontend Not Loading
```bash
# Check if Vite is running
curl http://localhost:5173

# Restart frontend
pkill -f vite
cd frontend && VITE_GATEWAY_URL=http://localhost:8080 npm run dev
```

## 📝 Project Structure

```
.
├── start-dev.sh          # Main startup script
├── stop-dev.sh           # Shutdown script
├── status.sh             # Status checker
├── Makefile              # Make commands
├── .env                  # Environment variables
├── rewrite-service/      # Text rewriting microservice
├── summarize-service/    # Text summarization microservice
├── email-service/        # Email drafting microservice
├── nginx-gateway/        # API gateway
├── frontend/             # React frontend
├── k8s/                  # Kubernetes manifests
└── logs/                 # Service logs
```

## 🔐 Environment Variables

Edit `.env` to configure:

```bash
# Provider: 'gemini' or 'openai'
GENAI_PROVIDER=gemini

# Model name
GENAI_MODEL=gemini-1.5-flash

# API endpoints
GENAI_GEMINI_BASE_URL=https://generativelanguage.googleapis.com/v1beta/models
# GENAI_API_BASE_URL=https://api.openai.com/v1/chat/completions

# Your API key (required for AI features)
GENAI_API_KEY=your_api_key_here

# Request timeout
GENAI_TIMEOUT=12
```

## 🎯 Features

- **Rewrite Service**: Improve text clarity and tone
- **Summarize Service**: Extract key points from long text
- **Email Service**: Draft professional emails
- **Fallback Mode**: Works without API key using mock responses
- **API Gateway**: NGINX reverse proxy with CORS support
- **Monitoring**: Prometheus metrics on all services
- **Documentation**: Auto-generated OpenAPI docs

## 📦 Deployment

For Kubernetes deployment, see the original `README.md` file.

## ℹ️ Additional Information

- All services include Prometheus metrics at `/metrics`
- API documentation available at `/docs` endpoint
- CORS enabled for local development
- Logs stored in `logs/` directory
- No API key required for testing (uses fallback mode)

## 🆘 Getting Help

If you encounter issues:
1. Run `./status.sh` to check service status
2. Check logs: `tail -f logs/*.log`
3. Verify ports are free: `lsof -i :8000,8001,8002,8080,5173`
4. Restart services: `./stop-dev.sh && ./start-dev.sh`
