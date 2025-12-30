"""
Email drafting microservice using Gemini with a clean fallback.
"""

import os
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

app = FastAPI(title="Email Service", version="1.0.0")
Instrumentator().instrument(app).expose(app)

# ------------------------------------------------------------
# Models
# ------------------------------------------------------------

class EmailPayload(BaseModel):
    text: str
    recipient: Optional[str] = "team"
    goal: Optional[str] = "professional update"

# ------------------------------------------------------------
# Health
# ------------------------------------------------------------

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "email"}

# ------------------------------------------------------------
# Fallback Email Generator
# ------------------------------------------------------------

def _fallback_email(text: str, recipient: str, goal: str) -> str:
    recipient = (recipient or "there").title()
    goal = goal or "professional update"

    greeting = f"Dear {recipient},"

    body = text.strip()
    if body and body[0].islower():
        body = body[0].upper() + body[1:]

    context = ""
    if "update" in goal.lower():
        context = "I hope this email finds you well. I wanted to share the following update:\n\n"
    elif "request" in goal.lower():
        context = "I hope you are doing well. I am writing to request the following:\n\n"

    closing = "Please let me know if you have any questions.\n\nBest regards,\nGenAI Prompt Enhancer"

    return f"{greeting}\n\n{context}{body}\n\n{closing}"

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

async def _invoke_genai(text: str, recipient: str, goal: str) -> Optional[str]:
    prompt = (
        f"Write a complete, professional email.\n\n"
        f"Recipient: {recipient}\n"
        f"Purpose: {goal}\n\n"
        f"Key points:\n{text}\n\n"
        f"Include a subject line, greeting, body, and sign-off."
    )

    if GENAI_PROVIDER == "gemini":
        return await _call_gemini(prompt, temperature=0.6, max_tokens=2048)

    return None

# ------------------------------------------------------------
# API Endpoint
# ------------------------------------------------------------

@app.post("/email")
async def compose_email(payload: EmailPayload):
    if not payload.text.strip():
        raise HTTPException(status_code=400, detail="Text is required")

    if not GENAI_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="GenAI API key not configured. Please set GENAI_API_KEY."
        )

    draft = await _invoke_genai(payload.text, payload.recipient, payload.goal)

    if draft is None:
        draft = _fallback_email(payload.text, payload.recipient or "team", payload.goal or "")

    return {"result": draft}
