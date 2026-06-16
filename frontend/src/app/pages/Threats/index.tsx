import React, { useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useThreats } from '@/hooks'

const SEV_COLOR: Record<string, string> = {
  critical: '#ef4444', high: '#f97316', medium: '#eab308', low: '#22c55e',
}
const card = {
  background: 'rgba(255,255,255,0.03)',
  border: '1px solid rgba(255,255,255,0.08)',
  borderRadius: 12,
}

export default function Threats() {
  // Severity UI filter (local)
  const [severity, setSeverity] = useState<string>('')

  // Search comes from URL ?search= (set by TopBar) OR local state fallback
  const [searchParams] = useSearchParams()
  const urlSearch = searchParams.get('search') ?? ''

  // Always fetch ALL threats client-side (limit 200, no server-side severity filter)
  const { data = [], isLoading, refetch } = useThreats({ limit: 200 } as any)
  const all = data as any[]

  // Derive per-severity counts from the full set
  const counts: Record<string, number> = {
    critical: all.filter(t => t.severity === 'critical').length,
    high:     all.filter(t => t.severity === 'high').length,
    medium:   all.filter(t => t.severity === 'medium').length,
    low:      all.filter(t => t.severity === 'low').length,
  }

  // Apply client-side filters
  const threats = all.filter(t => {
    const matchSev    = !severity || t.severity === severity
    const matchSearch = !urlSearch || (
      (t.title ?? '').toLowerCase().includes(urlSearch.toLowerCase()) ||
      (t.summary ?? '').toLowerCase().includes(urlSearch.toLowerCase()) ||
      (t.category ?? '').toLowerCase().includes(urlSearch.toLowerCase())
    )
    return matchSev && matchSearch
  })

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 20 }}>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 12 }}>
        <div>
          <h1 style={{ color: 'white', fontSize: 24, fontWeight: 700 }}>Threats</h1>
          <p style={{ color: 'var(--ink-muted)', fontSize: 13, marginTop: 4 }}>
            {threats.length} of {all.length} threats
            {severity ? ` · filtered: ${severity}` : ''}
            {urlSearch ? ` · search: "${urlSearch}"` : ''}
          </p>
        </div>
        <button
          onClick={() => refetch()}
          style={{ padding: '8px 16px', background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 8, color: '#cbd5e1', cursor: 'pointer', fontSize: 13 }}
        >
          ↺ Refresh
        </button>
      </div>

      {/* Severity filter buttons with accurate counts */}
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        {(['', 'critical', 'high', 'medium', 'low'] as const).map(s => {
          const active = severity === s
          const label  = s ? `${s.charAt(0).toUpperCase()}${s.slice(1)} (${counts[s] ?? 0})` : `All (${all.length})`
          return (
            <button
              key={s}
              onClick={() => setSeverity(s)}
              style={{
                padding: '6px 14px', borderRadius: 20, fontSize: 12, fontWeight: 500,
                cursor: 'pointer', textTransform: 'capitalize',
                background: active ? 'rgba(6,182,212,.2)' : 'rgba(255,255,255,0.05)',
                border: active ? '1px solid rgba(6,182,212,.4)' : '1px solid rgba(255,255,255,0.08)',
                color: s ? SEV_COLOR[s] : 'var(--cyan)',
              }}
            >
              {label}
            </button>
          )
        })}
      </div>

      {/* Threat table */}
      {isLoading ? (
        <p style={{ color: 'var(--ink-muted)' }}>Loading…</p>
      ) : threats.length === 0 ? (
        <div style={{ ...card, padding: 40, textAlign: 'center', color: 'var(--ink-muted)' }}>
          {urlSearch
            ? `No threats matching "${urlSearch}". Try a different search term.`
            : 'No threats found. Click Refresh to trigger ingestion.'}
        </div>
      ) : (
        <div style={{ ...card, overflow: 'hidden' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead>
              <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.08)' }}>
                {['Severity', 'Title', 'Category', 'Source', 'Risk Score', 'Detected'].map(h => (
                  <th key={h} style={{ padding: '12px 16px', textAlign: 'left', color: 'var(--ink-muted)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: 1 }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {threats.map((t: any, i: number) => (
                <tr key={t.id ?? i} style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                  <td style={{ padding: '12px 16px' }}>
                    <span style={{ background: `${SEV_COLOR[t.severity] ?? '#64748b'}22`, color: SEV_COLOR[t.severity] ?? '#64748b', fontSize: 10, fontWeight: 700, padding: '3px 8px', borderRadius: 4, textTransform: 'uppercase' }}>
                      {t.severity}
                    </span>
                  </td>
                  <td style={{ padding: '12px 16px', color: '#e2e8f0', maxWidth: 300, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{t.title}</td>
                  <td style={{ padding: '12px 16px', color: 'var(--ink-secondary)', whiteSpace: 'nowrap' }}>{(t.category ?? '').replace(/_/g, ' ')}</td>
                  <td style={{ padding: '12px 16px', color: 'var(--ink-muted)', whiteSpace: 'nowrap' }}>{t.source ?? '—'}</td>
                  <td style={{ padding: '12px 16px' }}>
                    <span style={{ color: 'var(--cyan)', fontFamily: 'monospace', fontWeight: 600 }}>{t.risk_score?.toFixed(2) ?? '—'}</span>
                  </td>
                  <td style={{ padding: '12px 16px', color: 'var(--ink-muted)', whiteSpace: 'nowrap', fontSize: 12 }}>
                    {t.detected_at ? new Date(t.detected_at).toLocaleDateString('en-GB') : '—'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
