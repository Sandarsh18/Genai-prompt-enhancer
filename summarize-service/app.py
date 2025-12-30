"""
Summarize microservice using Gemini with a graceful extractive fallback.
"""

import os
import asyncio
from typing import Optional

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from prometheus_fastapi_instrumentator import Instrumentator
from dotenv import load_dotenv

# ------------------------------------------------------------
# Environment
# ------------------------------------------------------------

load_dotenv()

GENAI_PROVIDER = os.getenv("GENAI_PROVIDER", "gemini").lower()
GENAI_API_KEY = os.getenv("GENAI_API_KEY")
GEMINI_API_BASE_URL = os.getenv(
    "GENAI_GEMINI_BASE_URL",
    "https://generativelanguage.googleapis.com/v1beta"
)
GENAI_MODEL = os.getenv("GENAI_MODEL", "gemini-2.5-flash")
TIMEOUT_SECONDS = float(os.getenv("GENAI_TIMEOUT", "10"))

# ------------------------------------------------------------
# App
# ------------------------------------------------------------

app = FastAPI(title="Summarize Service", version="1.0.0")
Instrumentator().instrument(app).expose(app)

# ------------------------------------------------------------
# Models
# ------------------------------------------------------------

class TextPayload(BaseModel):
    text: str
    ratio: Optional[float] = 0.3

# ------------------------------------------------------------
# Health
# ------------------------------------------------------------

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "summarize"}

# ------------------------------------------------------------
# Fallback summarizer
# ------------------------------------------------------------

def _fallback_summary(text: str, ratio: float) -> str:
    import re
    sentences = re.split(r"[.!?]+", text)
    sentences = [s.strip() for s in sentences if len(s.strip()) > 10]

    if not sentences:
        return "No content to summarize."

    keep = max(1, int(len(sentences) * ratio))
    return ". ".join(sentences[:keep]) + "."

# ------------------------------------------------------------
# Gemini Call (CORRECT)
# ------------------------------------------------------------

async def _call_gemini(prompt: str, temperature: float, max_tokens: int) -> Optional[str]:
    endpoint = (
        f"{GEMINI_API_BASE_URL.rstrip('/')}/models/"
        f"{GENAI_MODEL}:generateContent"
        f"?key={GENAI_API_KEY}"
    )

    payload = {
        "contents": [
            {
                "role": "user",
                "parts": [{"text": prompt}]
            }
        ],
        "generationConfig": {
            "temperature": temperature,
            "maxOutputTokens": max_tokens
        }
    }

    try:
        async with httpx.AsyncClient(timeout=TIMEOUT_SECONDS) as client:
            response = await client.post(endpoint, json=payload)

        if response.status_code >= 400:
            print("Gemini API error:", response.text[:500])
            return None

        data = response.json()
        candidates = data.get("candidates", [])
        if not candidates:
            return None

        parts = candidates[0].get("content", {}).get("parts", [])
        return parts[0].get("text") if parts else None

    except Exception as e:
        print("Gemini unexpected error:", repr(e))
        return None

# ------------------------------------------------------------
# Provider Router
# ------------------------------------------------------------

async def _invoke_genai(text: str, ratio: float) -> Optional[str]:
    ratio_pct = int((ratio or 0.3) * 100)

    prompt = (
        f"Summarize the following text clearly and comprehensively. "
        f"Target length: about {ratio_pct}% of the original.\n\n"
        f"{text}\n\nSummary:"
    )

    if GENAI_PROVIDER == "gemini":
        return await _call_gemini(prompt, temperature=0.3, max_tokens=2048)

    return None

# ------------------------------------------------------------
# API Endpoint
# ------------------------------------------------------------

@app.post("/summarize")
async def summarize_text(payload: TextPayload):
    if not payload.text.strip():
        raise HTTPException(status_code=400, detail="Text is required")

    if not GENAI_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="GenAI API key not configured. Please set GENAI_API_KEY."
        )

    summary = await _invoke_genai(payload.text, payload.ratio)

    if summary is None:
        summary = _fallback_summary(payload.text, payload.ratio or 0.3)

    return {"result": summary}
