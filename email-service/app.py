"""Email drafting microservice that prefers GenAI but fails over cleanly."""

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

app = FastAPI(title='Email Service', version='1.0.0')
Instrumentator().instrument(app).expose(app)


@app.get('/health')
async def health_check():
  """Health check endpoint for Kubernetes probes."""
  return {'status': 'healthy', 'service': 'email'}


class EmailPayload(BaseModel):
  text: str
  recipient: Optional[str] = 'team'
  goal: Optional[str] = 'professional update'


def _fallback_email(text: str, recipient: Optional[str], goal: Optional[str]) -> str:
  """Generate a well-structured professional email."""
  recipient = (recipient or 'there').strip()
  goal = (goal or 'professional update').strip()
  
  # Capitalize recipient name
  recipient = recipient.title()
  
  # Determine greeting
  if recipient.lower() in ['team', 'all', 'everyone']:
    greeting = f'Dear {recipient},'
  else:
    greeting = f'Dear {recipient},'
  
  # Process the body text
  body = text.strip()
  if not body:
    body = 'I wanted to reach out regarding our recent discussion.'
  
  # Ensure proper capitalization
  if body and body[0].islower():
    body = body[0].upper() + body[1:]
  
  # Add context based on goal
  if 'update' in goal.lower():
    context = 'I hope this email finds you well. I wanted to provide you with an update:\n\n'
  elif 'request' in goal.lower():
    context = 'I hope you are doing well. I am writing to request:\n\n'
  elif 'reminder' in goal.lower():
    context = 'I hope this message finds you well. This is a friendly reminder regarding:\n\n'
  elif 'invitation' in goal.lower():
    context = 'I hope you are doing great. I would like to invite you to:\n\n'
  else:
    context = ''
  
  # Create closing
  if 'urgent' in text.lower() or 'asap' in text.lower():
    closing = 'Thank you for your prompt attention to this matter.\n\nBest regards,'
  elif 'thank' in text.lower():
    closing = 'I appreciate your time and consideration.\n\nWarm regards,'
  else:
    closing = 'Please let me know if you have any questions or concerns.\n\nBest regards,'
  
  # Assemble email
  email = f'{greeting}\n\n{context}{body}\n\n{closing}\nGenAI Prompt Enhancer'
  
  return email


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


async def _invoke_genai(text: str, recipient: Optional[str], goal: Optional[str]) -> Optional[str]:
  """Call the GenAI provider to craft the email; return None if disabled."""
  if not GENAI_API_KEY or GENAI_API_KEY == 'your_api_key_here':
    return None
  
  try:
    recipient_name = recipient or 'team'
    email_goal = goal or 'professional update'
    prompt = f"Write a complete, professional email to {recipient_name}. Purpose: {email_goal}. Include subject line, greeting, body, and sign-off.\n\nKey points to include:\n{text}\n\nEmail:"
    if GENAI_PROVIDER == 'gemini':
      return await _call_gemini(prompt, temperature=0.6, max_tokens=2048)
    messages = [
      {'role': 'system', 'content': 'You write complete, professional emails with subject lines, greetings, bodies, and sign-offs.'},
      {'role': 'user', 'content': prompt}
    ]
    return await _call_openai(messages, temperature=0.5, max_tokens=500)
  except HTTPException:
    # API error (quota, auth, etc.) - fall back gracefully
    return None
  except Exception:
    # Any other error - fall back gracefully
    return None


@app.post('/email')
async def compose_email(payload: EmailPayload):
  if not payload.text.strip():
    raise HTTPException(status_code=400, detail='Text is required')

  if not GENAI_API_KEY or GENAI_API_KEY == 'your_api_key_here':
    raise HTTPException(status_code=503, detail='GenAI API key not configured. Please set GENAI_API_KEY environment variable.')

  draft = await _invoke_genai(payload.text, payload.recipient, payload.goal)
  if draft is None:
    raise HTTPException(status_code=502, detail='GenAI service unavailable. Please check your API key and network connection.')

  return {'result': draft}
