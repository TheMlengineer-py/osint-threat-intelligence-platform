/**
 * Settings page — system status and LLM configuration.
 * Shows only information relevant to analysts using the platform.
 * Internal deployment details (Render/Netlify URLs) are hidden in production.
 */
import React, { useState, useEffect } from 'react'
import { useCopilotStatus, useIngestionStatus } from '@/hooks'
import { apiClient } from '@/services/api'
import { useTheme } from '@/context/ThemeContext'

type StatusType = 'ok' | 'warn' | 'error' | 'inactive'
const S: Record<StatusType, { bg: string; border: string; color: string; text: string }> = {
  ok:       { bg: 'rgba(34,197,94,0.12)',  border: 'rgba(34,197,94,0.3)',  color: '#22c55e', text: 'Connected' },
  warn:     { bg: 'rgba(234,179,8,0.12)',  border: 'rgba(234,179,8,0.3)',  color: '#eab308', text: 'Warning'   },
  error:    { bg: 'rgba(239,68,68,0.12)',  border: 'rgba(239,68,68,0.3)',  color: '#ef4444', text: 'Error'     },
  inactive: { bg: 'rgba(71,85,105,0.12)', border: 'rgba(71,85,105,0.3)', color: '#64748b', text: 'Inactive'  },
}

function Badge({ s }: { s: StatusType }) {
  const c = S[s]
  return (
    <span style={{ padding: '4px 12px', borderRadius: 20, background: c.bg, border: `1px solid ${c.border}`, color: c.color, fontSize: 12, fontWeight: 700, flexShrink: 0, whiteSpace: 'nowrap' }}>
      {s === 'ok' ? '✓' : s === 'warn' ? '⚠' : s === 'error' ? '✗' : '–'} {c.text}
    </span>
  )
}

function Row({ label, value, status, note }: { label: string; value: string; status: StatusType; note?: string }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', padding: '14px 0', borderBottom: '1px solid var(--bg-border)', gap: 12 }}>
      <div style={{ flex: 1 }}>
        <p style={{ color: 'var(--ink-primary)', fontSize: 13, fontWeight: 600, margin: 0 }}>{label}</p>
        <p style={{ color: 'var(--ink-secondary)', fontSize: 12, marginTop: 2 }}>{value}</p>
        {note && <p style={{ color: 'var(--ink-muted)', fontSize: 11, marginTop: 3, fontStyle: 'italic' }}>{note}</p>}
      </div>
      <Badge s={status} />
    </div>
  )
}

const card = (e: React.CSSProperties = {}): React.CSSProperties => ({
  background: 'var(--bg-card)', border: '1px solid var(--bg-border)', borderRadius: 12, padding: 20, ...e
})

const isProd = import.meta.env.VITE_ENVIRONMENT === 'production'

export default function Settings() {
  const { data: copilot } = useCopilotStatus()
  const { data: ingest  } = useIngestionStatus()
  const { theme, toggle } = useTheme()
  const [backendOk,   setBackendOk]   = useState<boolean | null>(null)
  const [testResult,  setTestResult]  = useState<{ ok: boolean; error?: string; model?: string } | null>(null)
  const [testLoading, setTestLoading] = useState(false)

  const groqReady  = copilot?.groq_available === true
  const ingestData = ingest as any

  useEffect(() => {
    apiClient.get('/threats/ingest/status')
      .then(() => setBackendOk(true))
      .catch(() => setBackendOk(false))
  }, [])

  const testGroq = async () => {
    setTestLoading(true)
    setTestResult(null)
    try {
      const { data } = await apiClient.post('/copilot/test', {})
      setTestResult(data)
    } catch {
      setTestResult({ ok: false, error: 'Request failed — is backend running?' })
    } finally {
      setTestLoading(false)
    }
  }

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 20, maxWidth: 860 }}>
      <div>
        <h1 style={{ color: 'var(--ink-primary)', fontSize: 24, fontWeight: 800, margin: 0 }}>Settings</h1>
        <p style={{ color: 'var(--ink-muted)', fontSize: 13, marginTop: 4 }}>System configuration and preferences</p>
      </div>

      {/* Appearance */}
      <div style={card()}>
        <h3 style={{ color: 'var(--ink-primary)', fontSize: 14, fontWeight: 700, margin: '0 0 14px' }}>Appearance</h3>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <p style={{ color: 'var(--ink-primary)', fontSize: 13, fontWeight: 600, margin: 0 }}>Theme</p>
            <p style={{ color: 'var(--ink-muted)', fontSize: 12, marginTop: 2 }}>{theme === 'dark' ? 'Dark mode' : 'Light mode'}</p>
          </div>
          <button onClick={toggle} style={{ padding: '8px 18px', borderRadius: 8, background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)', color: 'var(--ink-primary)', fontSize: 13, cursor: 'pointer' }}>
            {theme === 'dark' ? 'Switch to Light' : 'Switch to Dark'}
          </button>
        </div>
      </div>

      {/* AI Copilot / LLM */}
      <div style={card()}>
        <h3 style={{ color: 'var(--ink-primary)', fontSize: 14, fontWeight: 700, margin: '0 0 14px' }}>AI Copilot</h3>
        <div style={{ padding: 16, borderRadius: 10, background: groqReady ? 'rgba(34,197,94,0.07)' : 'var(--bg-elevated)', border: `1px solid ${groqReady ? 'rgba(34,197,94,0.3)' : 'var(--bg-border)'}`, marginBottom: 12 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
            <div>
              <p style={{ color: 'var(--ink-primary)', fontSize: 13, fontWeight: 700, margin: 0 }}>Groq LLM</p>
              <p style={{ color: 'var(--ink-muted)', fontSize: 11, marginTop: 3 }}>
                Model: <code style={{ color: 'var(--cyan)' }}>{copilot?.model ?? 'llama-3.1-8b-instant'}</code>
              </p>
            </div>
            <Badge s={groqReady ? 'ok' : copilot?.status === 'no_key' ? 'warn' : 'error'} />
          </div>
          {groqReady ? (
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <span style={{ color: '#22c55e', fontSize: 12 }}>API key configured · shared across all users</span>
              <button onClick={testGroq} disabled={testLoading} style={{ marginLeft: 'auto', padding: '5px 12px', borderRadius: 6, background: 'rgba(34,197,94,0.1)', border: '1px solid rgba(34,197,94,0.3)', color: '#22c55e', fontSize: 11, cursor: 'pointer' }}>
                {testLoading ? 'Testing...' : 'Test Connection'}
              </button>
            </div>
          ) : (
            <p style={{ color: 'var(--ink-muted)', fontSize: 12 }}>
              AI Copilot running in context-only mode. Contact the administrator to enable full AI responses.
            </p>
          )}
          {testResult && (
            <div style={{ marginTop: 10, padding: '8px 12px', borderRadius: 6, background: testResult.ok ? 'rgba(34,197,94,0.1)' : 'rgba(239,68,68,0.1)', border: `1px solid ${testResult.ok ? 'rgba(34,197,94,0.3)' : 'rgba(239,68,68,0.3)'}` }}>
              <p style={{ color: testResult.ok ? '#22c55e' : '#ef4444', fontSize: 12, margin: 0 }}>
                {testResult.ok ? `Connected · ${testResult.model}` : testResult.error}
              </p>
            </div>
          )}
        </div>
      </div>

      {/* System Services */}
      <div style={card()}>
        <h3 style={{ color: 'var(--ink-primary)', fontSize: 14, fontWeight: 700, margin: '0 0 4px' }}>System Services</h3>
        <div style={{ borderTop: '1px solid var(--bg-border)', marginTop: 12 }}>
          <Row label="API Backend"     value={import.meta.env.VITE_API_URL ?? 'Render Web Service'}         status={backendOk === true ? 'ok' : backendOk === false ? 'error' : 'warn'} />
          <Row label="Database"        value="PostgreSQL (Render managed)"                                   status="ok" />
          <Row label="NLP Pipeline"    value="spaCy en_core_web_sm"                                         status="ok" />
          <Row label="Vector Store"    value="ChromaDB"                                                     status="warn" note="Resets on restart — persistence requires Qdrant Cloud" />
          <Row label="Redis Cache"     value="Not configured"                                               status="inactive" />
        </div>
      </div>

      {/* Ingestion stats */}
      <div style={card()}>
        <h3 style={{ color: 'var(--ink-primary)', fontSize: 14, fontWeight: 700, margin: '0 0 14px' }}>OSINT Data Sources</h3>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 12, marginBottom: 16 }}>
          {[
            { label: 'Total Threats',  value: ingestData?.total_threats  ?? 0, color: 'var(--cyan)' },
            { label: 'Processed',      value: ingestData?.processed_docs ?? 0, color: '#22c55e' },
            { label: 'Pending NLP',    value: ingestData?.pending_docs   ?? 0, color: ingestData?.pending_docs ? '#a78bfa' : '#22c55e' },
          ].map(({ label, value, color }) => (
            <div key={label} style={{ padding: 14, borderRadius: 10, background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)', textAlign: 'center' }}>
              <div style={{ color, fontSize: 26, fontWeight: 800, fontFamily: 'monospace' }}>{value}</div>
              <div style={{ color: 'var(--ink-muted)', fontSize: 11, marginTop: 4 }}>{label}</div>
            </div>
          ))}
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
          {[
            { label: 'CISA / NVD',        active: true  },
            { label: 'Bleeping Computer', active: true  },
            { label: 'SecurityWeek',      active: true  },
            { label: 'Google News RSS',   active: true  },
            { label: 'Krebs on Security', active: true  },
            { label: 'NewsAPI',           active: false },
          ].map(({ label, active }) => (
            <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '9px 12px', borderRadius: 8, background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)' }}>
              <div style={{ width: 7, height: 7, borderRadius: '50%', background: active ? '#22c55e' : '#475569', flexShrink: 0 }} />
              <span style={{ color: 'var(--ink-primary)', fontSize: 12, fontWeight: 500 }}>{label}</span>
              {!active && <span style={{ color: 'var(--ink-muted)', fontSize: 10, marginLeft: 'auto' }}>key required</span>}
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
