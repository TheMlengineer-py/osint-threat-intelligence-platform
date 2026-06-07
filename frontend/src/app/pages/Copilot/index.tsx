import React, { useState, useRef, useEffect } from 'react'
import { useCopilotStatus } from '@/hooks'
import type { ChatMessage } from '@/types'
import { apiClient } from '@/services/api'

const STARTERS = [
  'What are the top critical threats right now?',
  'Summarise recent ransomware activity',
  'Which CVEs have been exploited this week?',
  'What threat actors are most active?',
  'Show IOCs I should add to detection rules',
]

export default function Copilot() {
  const [input,   setInput]   = useState('')
  const [history, setHistory] = useState<ChatMessage[]>([])
  const [loading, setLoading] = useState(false)
  const bottomRef             = useRef<HTMLDivElement>(null)
  const inputRef              = useRef<HTMLInputElement>(null)
  const { data: status }      = useCopilotStatus()

  // Derive states cleanly from API response
  const groqReady    = status?.ollama_available === true
  const contextOnly  = !groqReady
  const providerLabel = groqReady
    ? `Groq · ${status?.model ?? 'llama3-8b-8192'}`
    : 'Context mode'

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [history, loading])

  const send = async (q?: string) => {
    const query = (q ?? input).trim()
    if (!query || loading) return
    setInput('')
    setLoading(true)

    const userMsg: ChatMessage = {
      role:      'user',
      content:   query,
      timestamp: new Date().toISOString(),
    }
    setHistory(h => [...h, userMsg])

    try {
      const { data } = await apiClient.post('/copilot/ask', {
        query,
        conversation_history: history.slice(-6),
        max_context_docs: 5,
      })
      setHistory(h => [...h, {
        role:      'assistant',
        content:   data.answer,
        timestamp: new Date().toISOString(),
        sources:   data.sources,
        provider:  data.provider,
        model:     data.model,
      } as any])
    } catch {
      setHistory(h => [...h, {
        role:      'assistant',
        content:   '⚠ Request failed. Please check the backend is running.',
        timestamp: new Date().toISOString(),
      }])
    } finally {
      setLoading(false)
      setTimeout(() => inputRef.current?.focus(), 100)
    }
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', maxWidth: 900, margin: '0 auto', width: '100%' }}>

      {/* ── Header ──────────────────────────────────────────────────────────── */}
      <div style={{ padding: '20px 24px 16px', borderBottom: '1px solid var(--bg-border)', flexShrink: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <div style={{ width: 44, height: 44, borderRadius: 12, background: 'rgba(6,182,212,0.15)', border: '1px solid rgba(6,182,212,0.3)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22 }}>
            🤖
          </div>
          <div style={{ flex: 1 }}>
            <h1 style={{ color: 'var(--ink-primary)', fontSize: 22, fontWeight: 800, margin: 0 }}>
              AI Threat Analyst Copilot
            </h1>
            <p style={{ color: 'var(--ink-muted)', fontSize: 12, marginTop: 3 }}>
              Powered by {providerLabel} · searches your OSINT database
            </p>
          </div>
          {/* Status pill */}
          <div style={{
            padding: '6px 14px', borderRadius: 20, fontSize: 12, fontWeight: 600,
            background: groqReady ? 'rgba(34,197,94,0.15)' : 'rgba(234,179,8,0.15)',
            border:     `1px solid ${groqReady ? 'rgba(34,197,94,0.4)' : 'rgba(234,179,8,0.4)'}`,
            color:      groqReady ? '#22c55e' : '#eab308',
            whiteSpace: 'nowrap',
          }}>
            {groqReady ? '🟢 Groq Connected' : '🟡 Context Mode'}
          </div>
        </div>

        {/* Context-only info banner */}
        {contextOnly && (
          <div style={{ marginTop: 12, padding: '10px 16px', borderRadius: 8, background: 'rgba(234,179,8,0.07)', border: '1px solid rgba(234,179,8,0.25)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8 }}>
            <div>
              <p style={{ color: '#eab308', fontSize: 12, fontWeight: 600, margin: 0 }}>
                Groq API key not configured — running in Context mode
              </p>
              <p style={{ color: 'var(--ink-muted)', fontSize: 11, margin: '3px 0 0' }}>
                Add <code style={{ color: 'var(--cyan)', fontFamily: 'monospace' }}>GROQ_API_KEY</code> to{' '}
                <code style={{ color: 'var(--cyan)', fontFamily: 'monospace' }}>backend/.env</code> and restart the server
              </p>
            </div>
            <a href="/settings" style={{ color: 'var(--cyan)', fontSize: 11, textDecoration: 'none', whiteSpace: 'nowrap', padding: '4px 10px', borderRadius: 6, border: '1px solid rgba(6,182,212,0.3)', background: 'rgba(6,182,212,0.08)' }}>
              View Setup →
            </a>
          </div>
        )}
      </div>

      {/* ── Chat area ───────────────────────────────────────────────────────── */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '20px 24px', display: 'flex', flexDirection: 'column', gap: 16 }}>

        {/* Empty state */}
        {history.length === 0 && (
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', flex: 1, gap: 24, padding: '32px 0' }}>
            <div style={{ fontSize: 52 }}>🤖</div>
            <div style={{ textAlign: 'center' }}>
              <p style={{ color: 'var(--ink-primary)', fontSize: 17, fontWeight: 700 }}>
                Ask me about your threat intelligence
              </p>
              <p style={{ color: 'var(--ink-muted)', fontSize: 13, marginTop: 6 }}>
                I'll search your OSINT database and generate a response
              </p>
            </div>
            {/* Starter prompts */}
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, justifyContent: 'center', maxWidth: 640 }}>
              {STARTERS.map(s => (
                <button key={s} onClick={() => send(s)} style={{
                  padding: '8px 16px', borderRadius: 20, fontSize: 12, cursor: 'pointer',
                  background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)',
                  color: 'var(--ink-secondary)', transition: 'all 0.15s',
                }}>
                  {s}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Messages */}
        {history.map((msg: any, i) => (
          <div key={i} style={{ display: 'flex', justifyContent: msg.role === 'user' ? 'flex-end' : 'flex-start', gap: 10 }}>
            {msg.role === 'assistant' && (
              <div style={{ width: 30, height: 30, borderRadius: 8, background: 'rgba(6,182,212,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 15, flexShrink: 0, marginTop: 2 }}>🤖</div>
            )}
            <div style={{ maxWidth: '78%' }}>
              <div style={{
                padding: '12px 16px', fontSize: 13, lineHeight: 1.7, whiteSpace: 'pre-wrap',
                borderRadius: msg.role === 'user' ? '16px 16px 4px 16px' : '16px 16px 16px 4px',
                background: msg.role === 'user' ? 'rgba(6,182,212,0.15)' : 'var(--bg-card)',
                border: `1px solid ${msg.role === 'user' ? 'rgba(6,182,212,0.35)' : 'var(--bg-border)'}`,
                color: 'var(--ink-primary)',
              }}>
                {msg.content}
              </div>

              {/* Sources panel */}
              {msg.sources?.length > 0 && (
                <div style={{ marginTop: 8, padding: '10px 14px', borderRadius: 8, background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)' }}>
                  <p style={{ color: 'var(--ink-muted)', fontSize: 10, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 6 }}>
                    Sources ({msg.sources.length})
                  </p>
                  {msg.sources.map((s: any, j: number) => (
                    <div key={j} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
                      <span style={{ color: 'var(--ink-secondary)', fontSize: 11, flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {s.title}
                      </span>
                      <span style={{ color: 'var(--cyan)', fontSize: 11, fontFamily: 'monospace', flexShrink: 0, marginLeft: 8 }}>
                        {s.risk_score ? `Risk: ${s.risk_score.toFixed(2)}` : ""}
                      </span>
                    </div>
                  ))}
                </div>
              )}

              <div style={{ color: 'var(--ink-muted)', fontSize: 10, marginTop: 4, textAlign: msg.role === 'user' ? 'right' : 'left' }}>
                {msg.timestamp ? new Date(msg.timestamp).toLocaleTimeString() : ''}
                {msg.model && <span> · {msg.model}</span>}
              </div>
            </div>
          </div>
        ))}

        {/* Loading */}
        {loading && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ width: 30, height: 30, borderRadius: 8, background: 'rgba(6,182,212,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 15 }}>🤖</div>
            <div style={{ padding: '12px 16px', borderRadius: '16px 16px 16px 4px', background: 'var(--bg-card)', border: '1px solid var(--bg-border)', display: 'flex', gap: 5, alignItems: 'center' }}>
              {[0,1,2].map(i => (
                <div key={i} style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--cyan)', animation: 'bounce 1.2s infinite', animationDelay: `${i*0.2}s` }} />
              ))}
              <span style={{ color: 'var(--ink-muted)', fontSize: 12, marginLeft: 4 }}>
                {groqReady ? 'Generating with Groq…' : 'Searching knowledge base…'}
              </span>
            </div>
          </div>
        )}
        <div ref={bottomRef} />
      </div>

      {/* ── Input area ──────────────────────────────────────────────────────── */}
      <div style={{ padding: '16px 24px', borderTop: '1px solid var(--bg-border)', flexShrink: 0 }}>
        <div style={{ display: 'flex', gap: 10 }}>
          <input
            ref={inputRef}
            value={input}
            onChange={e => setInput(e.target.value)}
            onKeyDown={e => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send() } }}
            placeholder="Ask about threats, CVEs, threat actors, IOCs…"
            style={{ flex: 1, padding: '12px 16px', borderRadius: 12, fontSize: 13, outline: 'none', background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)', color: 'var(--ink-primary)' }}
          />
          <button onClick={() => send()} disabled={!input.trim() || loading} style={{
            width: 48, height: 48, borderRadius: 12, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20, transition: 'all 0.2s',
            background: input.trim() && !loading ? 'var(--cyan)' : 'var(--bg-elevated)',
            border:     `1px solid ${input.trim() && !loading ? 'var(--cyan)' : 'var(--bg-border)'}`,
            color:      input.trim() && !loading ? '#050c18' : 'var(--ink-muted)',
            cursor:     input.trim() && !loading ? 'pointer' : 'not-allowed',
          }}>
            ➤
          </button>
        </div>
        <p style={{ color: 'var(--ink-muted)', fontSize: 10, marginTop: 8, textAlign: 'center' }}>
          {groqReady
            ? `Connected to Groq · ${status?.model} · ${import.meta.env.VITE_API_BASE_URL ?? 'localhost:8000'}`
            : `Context-only mode · ${import.meta.env.VITE_API_BASE_URL ?? 'localhost:8000'} · Add GROQ_API_KEY to enable LLM`
          }
        </p>
      </div>
    </div>
  )
}
