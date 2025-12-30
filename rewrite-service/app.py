"""
Rewrite microservice that upgrades user prompts through Gemini (default)
with a graceful fallback.
"""

import os
import asyncio
from typing import List, Optional

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

# Gemini config (CORRECT)
GENAI_API_KEY = os.getenv("GENAI_API_KEY")
GEMINI_API_BASE_URL = os.getenv(
    "GENAI_GEMINI_BASE_URL",
    "https://generativelanguage.googleapis.com/v1beta/models"
)

# IMPORTANT: Gemini model (NOT OpenAI)
GENAI_MODEL = os.getenv("GENAI_MODEL", "gemini-1.5-flash")

TIMEOUT_SECONDS = float(os.getenv("GENAI_TIMEOUT", "10"))

# ------------------------------------------------------------
# App
# ------------------------------------------------------------

app = FastAPI(title="Rewrite Service", version="1.0.0")
Instrumentator().instrument(app).expose(app)

# ------------------------------------------------------------
# Models
# ------------------------------------------------------------

class TextPayload(BaseModel):
    text: str
    tone: Optional[str] = None

# ------------------------------------------------------------
# Health
# ------------------------------------------------------------

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "rewrite"}

# ------------------------------------------------------------
# Gemini Call (REST – CORRECT)
# ------------------------------------------------------------

async def _call_gemini(prompt: str, temperature: float, max_tokens: int) -> Optional[str]:
    if not GENAI_API_KEY:
        return None

    endpoint = (
        f"{GEMINI_API_BASE_URL.rstrip('/')}/models/"
        f"{GENAI_MODEL}:generateContent"
        f"?key={GENAI_API_KEY}"
    )
    print("=== GEMINI SERVICE DEBUG ===")
    print("BASE URL:", GEMINI_API_BASE_URL)
    print("MODEL:", GENAI_MODEL)
    print("FULL URL:", endpoint)
    print("============================")


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
        if not parts:
            return None

        return parts[0].get("text")

    except Exception as e:
        print("Gemini unexpected error:", repr(e))
        return None

# ------------------------------------------------------------
# Provider Router
# ------------------------------------------------------------

async def _invoke_genai(text: str, tone: Optional[str]) -> Optional[str]:
    tone_desc = tone or "professional"

    prompt = (
        f"Rewrite the following text to be more {tone_desc}, clear, detailed, "
        f"and polished while preserving the original meaning:\n\n"
        f"{text}\n\nRewritten version:"
    )

    if GENAI_PROVIDER == "gemini":
        return await _call_gemini(prompt, temperature=0.5, max_tokens=2048)

    # Safety: OpenAI explicitly disabled unless implemented
    print("ERROR: OpenAI provider selected but not implemented")
    return None

# ------------------------------------------------------------
# API Endpoint
# ------------------------------------------------------------

@app.post("/rewrite")
async def rewrite_text(payload: TextPayload):
    if not payload.text.strip():
        raise HTTPException(status_code=400, detail="Text is required")

    if not GENAI_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="GenAI API key not configured. Please set GENAI_API_KEY."
        )

    rewritten = await _invoke_genai(payload.text, payload.tone)

    if rewritten is None:
        raise HTTPException(
            status_code=502,
            detail="GenAI service unavailable. Please check API key, model, and network."
        )

    return {"result": rewritten}
