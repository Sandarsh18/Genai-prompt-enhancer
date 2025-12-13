"""Summarize microservice with GenAI-first behavior and graceful fallback."""

import os
import asyncio
import json
from typing import List, Optional

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from prometheus_fastapi_instrumentator import Instrumentator
from dotenv import load_dotenv

load_dotenv()  # Load environment variables from .env file

GENAI_PROVIDER = os.getenv('GENAI_PROVIDER', 'openai').lower()
GENAI_API_BASE_URL = os.getenv('GENAI_API_BASE_URL', 'https://api.openai.com/v1/chat/completions')
GEMINI_API_BASE_URL = os.getenv('GENAI_GEMINI_BASE_URL', 'https://generativelanguage.googleapis.com/v1beta/models')
GENAI_MODEL = os.getenv('GENAI_MODEL', 'gpt-3.5-turbo')
GENAI_API_KEY = os.getenv('GENAI_API_KEY')
TIMEOUT_SECONDS = float(os.getenv('GENAI_TIMEOUT', '8'))

app = FastAPI(title='Summarize Service', version='1.0.0')
Instrumentator().instrument(app).expose(app)


@app.get('/health')
async def health_check():
  """Health check endpoint for Kubernetes probes."""
  return {'status': 'healthy', 'service': 'summarize'}


class TextPayload(BaseModel):
  text: str
  ratio: Optional[float] = 0.3


def _fallback_summary(text: str, ratio: Optional[float]) -> str:
  """Enhanced extractive summary with better sentence selection."""
  import re
  
  # Split into sentences more intelligently
  sentences = re.split(r'[.!?]+', text)
  sentences = [s.strip() for s in sentences if s.strip() and len(s.strip()) > 10]
  
  if not sentences:
    return 'No content to summarize.'
  
  # Calculate how many sentences to keep
  ratio = ratio or 0.3
  keep = max(1, min(len(sentences), int(len(sentences) * ratio)))
  
  # Simple scoring: prefer longer, more informative sentences
  scored = []
  for s in sentences:
    # Simple heuristic: longer sentences with key words score higher
    score = len(s.split())
    # Boost sentences with important indicators
    if any(word in s.lower() for word in ['important', 'key', 'main', 'significant', 'critical']):
      score *= 1.5
    scored.append((score, s))
  
  # Sort by score and take top sentences
  scored.sort(reverse=True)
  selected = [s for _, s in scored[:keep]]
  
  # Maintain original order
  result = []
  for s in sentences:
    if s in selected:
      result.append(s)
  
  summary = '. '.join(result)
  if not summary.endswith('.'):
    summary += '.'
  
  return summary


async def _call_openai(messages: List[dict], temperature: float, max_tokens: int) -> Optional[str]:
  headers = {
    'Authorization': f'Bearer {GENAI_API_KEY}',
    'Content-Type': 'application/json'
  }
  payload = {
    'model': GENAI_MODEL,
    'messages': messages,
    'temperature': temperature,
    'max_tokens': max_tokens
  }
  async with httpx.AsyncClient(timeout=TIMEOUT_SECONDS) as client:
    response = await client.post(GENAI_API_BASE_URL, headers=headers, json=payload)
  if response.status_code >= 400:
    raise HTTPException(status_code=502, detail='GenAI provider error')
  data = response.json()
  return data.get('choices', [{}])[0].get('message', {}).get('content')


async def _call_gemini(prompt: str, temperature: float, max_tokens: int) -> Optional[str]:
  endpoint = f"{GEMINI_API_BASE_URL.rstrip('/')}/{GENAI_MODEL}:generateContent?key={GENAI_API_KEY}"
  payload = {
    'contents': [
      {
        'role': 'user',
        'parts': [{'text': prompt}]
      }
    ],
    'generationConfig': {
      'temperature': temperature,
      'maxOutputTokens': max_tokens
    }
  }
  
  max_retries = 2
  for attempt in range(max_retries + 1):
    try:
      async with httpx.AsyncClient(timeout=TIMEOUT_SECONDS) as client:
        response = await client.post(endpoint, json=payload)
      
      if response.status_code == 429:  # Rate limit exceeded
        if attempt < max_retries:
          try:
            error_data = response.json()
            error_msg = error_data.get('error', {}).get('message', '')
            import re
            match = re.search(r'retry in ([\d.]+)s', error_msg)
            wait_time = float(match.group(1)) if match else 2 ** attempt
            wait_time = min(wait_time, 10)
          except:
            wait_time = 2 ** attempt
          
          print(f"Rate limit hit, retrying in {wait_time:.1f}s (attempt {attempt + 1}/{max_retries + 1})")
          await asyncio.sleep(wait_time)
          continue
        else:
          raise HTTPException(
            status_code=429, 
            detail='API rate limit exceeded. Please wait a moment and try again.'
          )
      
      if response.status_code >= 400:
        raise HTTPException(status_code=502, detail='GenAI provider error')
      
      data = response.json()
      candidates = data.get('candidates') or []
      if not candidates:
        return None
      parts = (candidates[0].get('content') or {}).get('parts') or []
      return parts[0].get('text') if parts else None
      
    except HTTPException:
      raise
    except Exception as e:
      if attempt < max_retries:
        await asyncio.sleep(2 ** attempt)
        continue
      raise
  
  return None


async def _invoke_genai(text: str, ratio: Optional[float]) -> Optional[str]:
  """Call GenAI provider and return the summarized text when possible."""
  if not GENAI_API_KEY or GENAI_API_KEY == 'your_api_key_here':
    return None
  
  try:
    ratio_desc = f"{int((ratio or 0.3) * 100)}%"
    prompt = f"Create a comprehensive summary of the following text, capturing all key points and maintaining clarity. Target length: {ratio_desc} of original:\n\n{text}\n\nSummary:"
    if GENAI_PROVIDER == 'gemini':
      return await _call_gemini(prompt, temperature=0.3, max_tokens=2048)
    messages = [
      {'role': 'system', 'content': 'You create comprehensive, clear summaries that capture key information.'},
      {'role': 'user', 'content': prompt}
    ]
    return await _call_openai(messages, temperature=0.2, max_tokens=400)
  except HTTPException:
    # API error (quota, auth, etc.) - fall back gracefully
    return None
  except Exception:
    # Any other error - fall back gracefully
    return None


@app.post('/summarize')
async def summarize_text(payload: TextPayload):
  if not payload.text.strip():
    raise HTTPException(status_code=400, detail='Text is required')

  if not GENAI_API_KEY or GENAI_API_KEY == 'your_api_key_here':
    raise HTTPException(status_code=503, detail='GenAI API key not configured. Please set GENAI_API_KEY environment variable.')

  summary = await _invoke_genai(payload.text, payload.ratio)
  if summary is None:
    raise HTTPException(status_code=502, detail='GenAI service unavailable. Please check your API key and network connection.')

  return {'result': summary}
