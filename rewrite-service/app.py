"""Rewrite microservice that upgrades user prompts through GenAI or a fallback."""

import os
import random
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

app = FastAPI(title='Rewrite Service', version='1.0.0')
Instrumentator().instrument(app).expose(app)


@app.get('/health')
async def health_check():
  """Health check endpoint for Kubernetes probes."""
  return {'status': 'healthy', 'service': 'rewrite'}


@app.get('/ready')
async def readiness_check():
  """Readiness check - service is ready even without GenAI API."""
  genai_status = 'configured' if GENAI_API_KEY and GENAI_API_KEY != 'your_api_key_here' else 'fallback_mode'
  return {
    'status': 'ready',
    'service': 'rewrite',
    'genai_provider': GENAI_PROVIDER,
    'genai_status': genai_status,
    'mode': 'production' if genai_status == 'configured' else 'mock'
  }


class TextPayload(BaseModel):
  text: str
  tone: Optional[str] = None


def _fake_rewrite(text: str, tone: Optional[str]) -> str:
  """Enhanced fallback with better text processing."""
  tone = (tone or 'professional').lower()
  
  # Split into sentences more intelligently
  import re
  sentences = re.split(r'[.!?]+', text)
  sentences = [s.strip() for s in sentences if s.strip()]
  
  # Capitalize first letter of each sentence
  sentences = [s[0].upper() + s[1:] if s else s for s in sentences]
  
  # Apply tone-based transformations
  if tone == 'professional':
    # Remove casual language
    processed = []
    for s in sentences:
      s = s.replace(' gonna ', ' going to ')
      s = s.replace(' wanna ', ' want to ')
      s = s.replace(' gotta ', ' have to ')
      processed.append(s)
    sentences = processed
  elif tone == 'casual':
    processed = [s.lower().capitalize() for s in sentences]
    sentences = processed
  elif tone == 'formal':
    processed = []
    for s in sentences:
      s = s.replace(" don't", " do not")
      s = s.replace(" can't", " cannot")
      s = s.replace(" won't", " will not")
      processed.append(s)
    sentences = processed
  
  rewritten = '. '.join(sentences)
  if not rewritten.endswith('.'):
    rewritten += '.'
  
  return rewritten or 'Please provide content to rewrite.'


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
          # Extract retry delay from error message if available
          try:
            error_data = response.json()
            error_msg = error_data.get('error', {}).get('message', '')
            # Parse "Please retry in X.Xs" from error message
            import re
            match = re.search(r'retry in ([\d.]+)s', error_msg)
            wait_time = float(match.group(1)) if match else 2 ** attempt
            wait_time = min(wait_time, 10)  # Cap at 10 seconds max
          except:
            wait_time = 2 ** attempt  # Exponential backoff: 1s, 2s, 4s
          
          print(f"Rate limit hit, retrying in {wait_time:.1f}s (attempt {attempt + 1}/{max_retries + 1})")
          await asyncio.sleep(wait_time)
          continue
        else:
          # Final attempt failed, return user-friendly message
          raise HTTPException(
            status_code=429, 
            detail='API rate limit exceeded. Please wait a moment and try again.'
          )
      
      if response.status_code >= 400:
        error_detail = response.text
        print(f"ERROR: Gemini API returned {response.status_code}: {error_detail[:500]}")
        raise HTTPException(status_code=502, detail='GenAI provider error')
      
      data = response.json()
      candidates = data.get('candidates') or []
      if not candidates:
        return None
      content = candidates[0].get('content') or {}
      parts = content.get('parts') or []
      if parts:
        result = parts[0].get('text', '')
        return result
      return None
      
    except HTTPException:
      raise
    except Exception as e:
      if attempt < max_retries:
        await asyncio.sleep(2 ** attempt)
        continue
      raise
  
  return None


async def _invoke_genai(text: str, tone: Optional[str]) -> Optional[str]:
  """Call configured GenAI provider; return None if no key is set or on error."""
  if not GENAI_API_KEY or GENAI_API_KEY == 'your_api_key_here':
    return None
  
  try:
    tone_desc = tone or 'professional'
    prompt = f"Transform this text to be more {tone_desc}, detailed and polished. Keep the core meaning but enhance clarity and impact:\n\n{text}\n\nEnhanced version:"
    if GENAI_PROVIDER == 'gemini':
      return await _call_gemini(prompt, temperature=0.5, max_tokens=2048)
    messages = [
      {'role': 'system', 'content': f'You enhance text to be more {tone_desc} and impactful. Provide detailed, polished versions.'},
      {'role': 'user', 'content': text}
    ]
    return await _call_openai(messages, temperature=0.4, max_tokens=500)
  except HTTPException as e:
    # API error (quota, auth, etc.) - log and fall back gracefully
    print(f"GenAI API error: {e.detail}")
    return None
  except Exception as e:
    # Any other error - log and fall back gracefully
    print(f"GenAI unexpected error: {str(e)}")
    return None


@app.post('/rewrite')
async def rewrite_text(payload: TextPayload):
  """Rewrite endpoint with automatic GenAI fallback."""
  if not payload.text.strip():
    raise HTTPException(status_code=400, detail='Text is required')

  # DEVOPS: Graceful degradation - try GenAI, fall back to mock
  if not GENAI_API_KEY or GENAI_API_KEY == 'your_api_key_here':
    # No API key configured - use mock immediately
    result = _fake_rewrite(payload.text, payload.tone)
    return {
      'result': result,
      'mode': 'mock',
      'reason': 'no_api_key'
    }

  # Try GenAI with automatic fallback
  rewritten = await _invoke_genai(payload.text, payload.tone)
  
  if rewritten is None:
    # GenAI failed (rate limit, network, etc.) - use fallback
    result = _fake_rewrite(payload.text, payload.tone)
    return {
      'result': result,
      'mode': 'mock',
      'reason': 'genai_unavailable'
    }

  return {
    'result': rewritten,
    'mode': 'genai',
    'provider': GENAI_PROVIDER
  }
