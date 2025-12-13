import { useState, useEffect } from 'react'
import axios from 'axios'

const ACTIONS = [
  { 
    key: 'rewrite', 
    label: '✨ Rewrite', 
    endpoint: '/rewrite',
    icon: '✍️',
    description: 'Enhance clarity and tone'
  },
  { 
    key: 'summarize', 
    label: '📝 Summarize', 
    endpoint: '/summarize',
    icon: '📊',
    description: 'Extract key points'
  },
  { 
    key: 'email', 
    label: '📧 Email', 
    endpoint: '/email',
    icon: '✉️',
    description: 'Draft professional email'
  }
]

const THEMES = [
  { id: 'dark', name: 'Dark', icon: '🌙' },
  { id: 'light', name: 'Light', icon: '☀️' },
  { id: 'cyberpunk', name: 'Cyberpunk', icon: '🎮' }
]

const API_BASE = import.meta.env.VITE_GATEWAY_URL || ''

function App () {
  const [text, setText] = useState('')
  const [loading, setLoading] = useState(false)
  const [result, setResult] = useState('')
  const [error, setError] = useState('')
  const [activeService, setActiveService] = useState(null)
  const [tone, setTone] = useState('professional')
  const [recipient, setRecipient] = useState('team')
  const [theme, setTheme] = useState('dark')
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    const savedTheme = localStorage.getItem('theme') || 'dark'
    setTheme(savedTheme)
    document.body.className = `theme-${savedTheme}`
  }, [])

  const changeTheme = (newTheme) => {
    setTheme(newTheme)
    localStorage.setItem('theme', newTheme)
    document.body.className = `theme-${newTheme}`
  }

  const callService = async (endpoint, actionKey) => {
    setLoading(true)
    setError('')
    setActiveService(actionKey)
    setResult('')
    
    try {
      const url = `${API_BASE}${endpoint}`
      let payload = { text }
      
      // Add additional parameters based on service
      if (actionKey === 'rewrite') {
        payload.tone = tone
      } else if (actionKey === 'email') {
        payload.recipient = recipient
        payload.goal = 'professional update'
      } else if (actionKey === 'summarize') {
        payload.ratio = 0.3
      }
      
      const response = await axios.post(url, payload)
      setResult(response.data.result)
    } catch (err) {
      setError(err.response?.data?.detail || 'Service unavailable. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <main className="app-shell">
      <header>
        <div className="logo">🤖</div>
        <h1>GenAI Prompt Enhancer</h1>
        <p className="subtitle">Transform your text with AI-powered rewriting, summarization, and email drafting</p>
        <div className="theme-switcher">
          {THEMES.map((t) => (
            <button
              key={t.id}
              onClick={() => changeTheme(t.id)}
              className={`theme-btn ${theme === t.id ? 'active' : ''}`}
              title={`Switch to ${t.name} theme`}
            >
              {t.icon}
            </button>
          ))}
        </div>
        <div className="theme-indicator">
          <span className="theme-badge">{THEMES.find(t => t.id === theme)?.icon} {THEMES.find(t => t.id === theme)?.name} Mode</span>
        </div>
      </header>

      <section className="card input-section">
        <label className="input-label">
          <span>✍️ Your Text</span>
          <span className="char-count">{text.length} characters</span>
        </label>
        <textarea
          value={text}
          onChange={(event) => setText(event.target.value)}
          placeholder="Enter your text here... Try something like: 'Write a professional email about project completion' or 'Summarize this long document...'"
          rows={8}
          className="enhanced-textarea"
        />
        
        {/* Service-specific options */}
        <div className="options-panel">
          <div className="option-group">
            <label className="option-label">
              📝 Rewrite Tone:
              <select value={tone} onChange={(e) => setTone(e.target.value)} className="option-select">
                <option value="professional">Professional</option>
                <option value="casual">Casual</option>
                <option value="formal">Formal</option>
                <option value="friendly">Friendly</option>
              </select>
            </label>
          </div>
          
          <div className="option-group">
            <label className="option-label">
              📧 Email Recipient:
              <input 
                type="text" 
                value={recipient} 
                onChange={(e) => setRecipient(e.target.value)}
                placeholder="e.g., Team, Manager, Client"
                className="option-input"
              />
            </label>
          </div>
        </div>

        <div className="actions">
          {ACTIONS.map((action) => (
            <button
              key={action.key}
              disabled={loading || !text.trim()}
              onClick={() => callService(action.endpoint, action.key)}
              className={`action-button ${activeService === action.key && loading ? 'active' : ''}`}
              title={action.description}
            >
              <span className="button-icon">{action.icon}</span>
              <span className="button-content">
                <span className="button-label">{loading && activeService === action.key ? 'Processing...' : action.label}</span>
                <span className="button-desc">{action.description}</span>
              </span>
            </button>
          ))}
        </div>
      </section>

      {(result || error) && (
        <section className="card output-section">
          <div className="output-header">
            <h2>
              {activeService === 'rewrite' && '✨ Rewritten Text'}
              {activeService === 'summarize' && '📝 Summary'}
              {activeService === 'email' && '📧 Email Draft'}
            </h2>
            {result && !error && (
              <button 
                className="copy-button"
                onClick={() => {
                  navigator.clipboard.writeText(result)
                  setCopied(true)
                  setTimeout(() => setCopied(false), 2000)
                }}
              >
                {copied ? '✅ Copied!' : '📋 Copy'}
              </button>
            )}
          </div>
          {error ? (
            <div className="error-box">
              <span className="error-icon">⚠️</span>
              <p className="error">{error}</p>
            </div>
          ) : (
            <div className="result-box">
              <pre>{result}</pre>
            </div>
          )}
        </section>
      )}

      <footer className="app-footer">
        <p>💡 Tip: For best results, provide clear and detailed text. The more context, the better the output!</p>
      </footer>
    </main>
  )
}

export default App
