import React, { useState } from 'react'
import { useQuickReport, useGenerateReport, useReports } from '@/hooks'
import { useAnalyticsSummary, useTopThreats } from '@/hooks'

function card(extra: React.CSSProperties = {}): React.CSSProperties {
  return { background: 'var(--bg-card)', border: '1px solid var(--bg-border)', borderRadius: 12, ...extra }
}

const SEV_COLOR: Record<string, string> = {
  critical: '#ef4444', high: '#f97316', medium: '#eab308', low: '#22c55e'
}

export default function Reports() {
  const { data: quick, isLoading: quickLoading } = useQuickReport()
  const { data: metrics }     = useAnalyticsSummary()
  const { data: top = [] }    = useTopThreats(20)
  const generate              = useGenerateReport()
  const [generated, setGenerated] = useState<any>(null)
  const [genLoading, setGenLoading] = useState(false)

  const handleGenerate = () => {
    setGenLoading(true)
    generate.mutate(
      { title: `Intelligence Report — ${new Date().toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' })}` },
      {
        onSuccess: d => { setGenerated(d); setGenLoading(false) },
        onError:   () => setGenLoading(false),
      }
    )
  }

  const q = quick as any

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 20, maxWidth: 1200 }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <div>
          <h1 style={{ color: 'var(--ink-primary)', fontSize: 24, fontWeight: 800, margin: 0 }}>Intelligence Reports</h1>
          <p style={{ color: 'var(--ink-muted)', fontSize: 13, marginTop: 4 }}>Generate and manage threat intelligence reports</p>
        </div>
        {/* BUTTON DISABLED */}
      </div>

      {/* Summary cards row */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 14 }}>
        {[
          { label: 'Total Threats',   value: q?.total_threats ?? metrics?.total_threats ?? 0,  color: 'var(--cyan)' },
          { label: 'Critical',        value: metrics?.critical_threats ?? 0,                   color: '#ef4444' },
          { label: 'Avg Risk Score',  value: (q?.top_20_by_risk?.avg_risk ?? metrics?.avg_risk_score ?? 0).toFixed ? (q?.top_20_by_risk?.avg_risk ?? metrics?.avg_risk_score ?? 0).toFixed(2) : '—', color: '#f97316' },
          { label: 'Max Risk Score',  value: (q?.top_20_by_risk?.max_risk ?? metrics?.max_risk_score ?? 0).toFixed ? (q?.top_20_by_risk?.max_risk ?? metrics?.max_risk_score ?? 0).toFixed(2) : '—', color: '#ef4444' },
        ].map(({ label, value, color }) => (
          <div key={label} style={{ ...card({ padding: '18px 20px' }) }}>
            <div style={{ color: 'var(--ink-muted)', fontSize: 10, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 1 }}>{label}</div>
            <div style={{ color, fontSize: 32, fontWeight: 800, fontFamily: 'monospace', margin: '6px 0 0' }}>{value}</div>
          </div>
        ))}
      </div>

      {/* Category & Source breakdown */}
      {metrics && (
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
          <div style={card({ padding: 20 })}>
            <h3 style={{ color: 'var(--ink-primary)', fontSize: 13, fontWeight: 700, margin: '0 0 14px' }}>By Category</h3>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12 }}>
              <thead>
                <tr style={{ borderBottom: '1px solid var(--bg-border)' }}>
                  <th style={{ textAlign: 'left', padding: '6px 0', color: 'var(--ink-muted)', fontWeight: 600, fontSize: 10, textTransform: 'uppercase', letterSpacing: 1 }}>Category</th>
                  <th style={{ textAlign: 'right', padding: '6px 0', color: 'var(--ink-muted)', fontWeight: 600, fontSize: 10, textTransform: 'uppercase', letterSpacing: 1 }}>Count</th>
                  <th style={{ textAlign: 'right', padding: '6px 0', color: 'var(--ink-muted)', fontWeight: 600, fontSize: 10, textTransform: 'uppercase', letterSpacing: 1 }}>%</th>
                </tr>
              </thead>
              <tbody>
                {Object.entries(metrics.by_category ?? {}).map(([cat, cnt]) => {
                  const pct = metrics.total_threats ? ((cnt as number) / metrics.total_threats * 100).toFixed(1) : '0'
                  return (
                    <tr key={cat} style={{ borderBottom: '1px solid rgba(255,255,255,0.04)' }}>
                      <td style={{ padding: '8px 0', color: 'var(--ink-secondary)', textTransform: 'capitalize' }}>{cat.replace(/_/g,' ')}</td>
                      <td style={{ padding: '8px 0', textAlign: 'right', color: 'var(--cyan)', fontFamily: 'monospace', fontWeight: 600 }}>{cnt as number}</td>
                      <td style={{ padding: '8px 0', textAlign: 'right', color: 'var(--ink-muted)', fontFamily: 'monospace' }}>{pct}%</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
          <div style={card({ padding: 20 })}>
            <h3 style={{ color: 'var(--ink-primary)', fontSize: 13, fontWeight: 700, margin: '0 0 14px' }}>By Source</h3>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12 }}>
              <thead>
                <tr style={{ borderBottom: '1px solid var(--bg-border)' }}>
                  <th style={{ textAlign: 'left', padding: '6px 0', color: 'var(--ink-muted)', fontWeight: 600, fontSize: 10, textTransform: 'uppercase', letterSpacing: 1 }}>Source</th>
                  <th style={{ textAlign: 'right', padding: '6px 0', color: 'var(--ink-muted)', fontWeight: 600, fontSize: 10, textTransform: 'uppercase', letterSpacing: 1 }}>Count</th>
                  <th style={{ textAlign: 'right', padding: '6px 0', color: 'var(--ink-muted)', fontWeight: 600, fontSize: 10, textTransform: 'uppercase', letterSpacing: 1 }}>%</th>
                </tr>
              </thead>
              <tbody>
                {Object.entries(metrics.by_source ?? {}).map(([src, cnt]) => {
                  const pct = metrics.total_threats ? ((cnt as number) / metrics.total_threats * 100).toFixed(1) : '0'
                  return (
                    <tr key={src} style={{ borderBottom: '1px solid rgba(255,255,255,0.04)' }}>
                      <td style={{ padding: '8px 0', color: 'var(--ink-secondary)' }}>{src}</td>
                      <td style={{ padding: '8px 0', textAlign: 'right', color: 'var(--cyan)', fontFamily: 'monospace', fontWeight: 600 }}>{cnt as number}</td>
                      <td style={{ padding: '8px 0', textAlign: 'right', color: 'var(--ink-muted)', fontFamily: 'monospace' }}>{pct}%</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Threat intelligence table */}
      <div style={card({ overflow: 'hidden' })}>
        <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--bg-border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: 'var(--bg-elevated)' }}>
          <h3 style={{ color: 'var(--ink-primary)', fontSize: 13, fontWeight: 700, margin: 0 }}>
            Top Threats by Risk Score — Intelligence Table
          </h3>
          <span style={{ color: 'var(--ink-muted)', fontSize: 11 }}>{(top as any[]).length} records</span>
        </div>
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12 }}>
            <thead>
              <tr style={{ background: 'var(--bg-elevated)' }}>
                {['#','Severity','Title','Category','Source','Risk Score','Detected'].map(h => (
                  <th key={h} style={{ padding: '10px 14px', textAlign: 'left', color: 'var(--ink-muted)', fontWeight: 700, fontSize: 10, textTransform: 'uppercase', letterSpacing: 1, whiteSpace: 'nowrap', borderBottom: '1px solid var(--bg-border)' }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {(top as any[]).map((t: any, i: number) => {
                const col = SEV_COLOR[t.severity] ?? '#64748b'
                return (
                  <tr key={t.id ?? i} style={{ borderBottom: '1px solid rgba(255,255,255,0.04)', transition: 'background 0.15s' }}
                    onMouseEnter={e => (e.currentTarget.style.background = 'rgba(255,255,255,0.02)')}
                    onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}>
                    <td style={{ padding: '10px 14px', color: 'var(--ink-muted)', fontFamily: 'monospace' }}>{i + 1}</td>
                    <td style={{ padding: '10px 14px' }}>
                      <span style={{ fontSize: 10, fontWeight: 700, padding: '3px 7px', borderRadius: 4, background: `${col}20`, color: col, textTransform: 'uppercase' }}>{t.severity}</span>
                    </td>
                    <td style={{ padding: '10px 14px', color: 'var(--ink-primary)', maxWidth: 280, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{t.title}</td>
                    <td style={{ padding: '10px 14px', color: 'var(--ink-secondary)', whiteSpace: 'nowrap', textTransform: 'capitalize' }}>{(t.category ?? '').replace(/_/g,' ')}</td>
                    <td style={{ padding: '10px 14px', color: 'var(--ink-muted)', whiteSpace: 'nowrap' }}>{t.source ?? '—'}</td>
                    <td style={{ padding: '10px 14px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <div style={{ width: 50, height: 4, borderRadius: 2, background: 'var(--bg-border)' }}>
                          <div style={{ width: `${Math.min((t.risk_score / 10) * 100, 100)}%`, height: '100%', borderRadius: 2, background: col }} />
                        </div>
                        <span style={{ color: col, fontFamily: 'monospace', fontWeight: 700 }}>{t.risk_score?.toFixed(2) ?? '—'}</span>
                      </div>
                    </td>
                    <td style={{ padding: '10px 14px', color: 'var(--ink-muted)', whiteSpace: 'nowrap' }}>
                      {t.detected_at ? new Date(t.detected_at).toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' }) : '—'}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* Generated report output */}
      {generated && (
        <div style={card({ padding: 24, border: '1px solid rgba(34,197,94,0.3)', background: 'rgba(34,197,94,0.05)' })}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
            <h3 style={{ color: 'var(--ink-primary)', fontSize: 14, fontWeight: 700, margin: 0 }}>{generated.title}</h3>
            <span style={{ padding: '3px 10px', borderRadius: 10, background: 'rgba(34,197,94,0.15)', color: '#22c55e', fontSize: 11, fontWeight: 600 }}>✓ Generated</span>
          </div>
          <p style={{ color: 'var(--ink-secondary)', fontSize: 12, marginBottom: 8 }}>{generated.threat_count} threats analysed · {new Date().toLocaleString()}</p>
          {generated.content && (
            <pre style={{ color: 'var(--ink-secondary)', fontSize: 12, whiteSpace: 'pre-wrap', lineHeight: 1.7, background: 'var(--bg-elevated)', padding: 16, borderRadius: 8, maxHeight: 300, overflowY: 'auto' }}>
              {generated.content.substring(0, 1200)}{generated.content.length > 1200 ? '\n\n… (truncated)' : ''}
            </pre>
          )}
        </div>
      )}
    </div>
  )
}
