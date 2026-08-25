import React, { useState, useRef } from 'react'
import { useQuickReport, useGenerateReport } from '@/hooks'
import { useAnalyticsSummary, useTopThreats } from '@/hooks'

function card(extra: React.CSSProperties = {}): React.CSSProperties {
  return { background: 'var(--bg-card)', border: '1px solid var(--bg-border)', borderRadius: 12, ...extra }
}

const SEV_COLOR: Record<string, string> = {
  critical: '#ef4444', high: '#f97316', medium: '#eab308', low: '#22c55e',
}

// ── Parse the JSON content string the backend returns ────────────────────────
function parseReportContent(raw: string): Record<string, any> | null {
  if (!raw) return null
  try {
    const cleaned = raw.replace(/```json\n?|\n?```/g, '').trim()
    return JSON.parse(cleaned)
  } catch {
    return null
  }
}

// ── Print-friendly PDF export via browser print dialog ───────────────────────
function downloadAsPDF(title: string) {
  const printArea = document.getElementById('report-print-area')
  if (!printArea) return

  const win = window.open('', '_blank', 'width=900,height=700')
  if (!win) return

  win.document.write(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>${title}</title>
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          font-family: 'Segoe UI', Arial, sans-serif;
          color: #0f172a;
          background: #fff;
          padding: 40px 48px;
          font-size: 13px;
          line-height: 1.6;
        }
        .report-header {
          border-bottom: 3px solid #0f172a;
          padding-bottom: 18px;
          margin-bottom: 28px;
        }
        .report-header h1 {
          font-size: 22px;
          font-weight: 800;
          color: #0f172a;
          margin-bottom: 4px;
        }
        .report-header .meta {
          font-size: 11px;
          color: #64748b;
        }
        .section { margin-bottom: 24px; }
        .section h2 {
          font-size: 13px;
          font-weight: 700;
          text-transform: uppercase;
          letter-spacing: 1px;
          color: #475569;
          border-bottom: 1px solid #e2e8f0;
          padding-bottom: 6px;
          margin-bottom: 12px;
        }
        .kpi-row {
          display: flex;
          gap: 16px;
          margin-bottom: 20px;
        }
        .kpi {
          flex: 1;
          background: #f8fafc;
          border: 1px solid #e2e8f0;
          border-radius: 8px;
          padding: 12px 16px;
        }
        .kpi .label { font-size: 10px; color: #94a3b8; text-transform: uppercase; letter-spacing: 1px; }
        .kpi .value { font-size: 24px; font-weight: 800; color: #0f172a; font-family: monospace; }
        .threat-row {
          display: grid;
          grid-template-columns: 24px 80px 1fr 130px 90px 60px;
          gap: 8px;
          padding: 8px 0;
          border-bottom: 1px solid #f1f5f9;
          align-items: center;
          font-size: 11px;
        }
        .threat-row.header {
          font-weight: 700;
          color: #64748b;
          font-size: 10px;
          text-transform: uppercase;
          letter-spacing: 0.5px;
        }
        .badge {
          display: inline-block;
          padding: 2px 7px;
          border-radius: 4px;
          font-size: 10px;
          font-weight: 700;
          text-transform: uppercase;
        }
        .footer {
          margin-top: 40px;
          padding-top: 16px;
          border-top: 1px solid #e2e8f0;
          font-size: 10px;
          color: #94a3b8;
          display: flex;
          justify-content: space-between;
        }
        @media print {
          body { padding: 20px 24px; }
          .no-print { display: none; }
        }
      </style>
    </head>
    <body>
      ${printArea.innerHTML}
    </body>
    </html>
  `)
  win.document.close()
  win.focus()
  setTimeout(() => { win.print(); win.close() }, 400)
}

export default function Reports() {
  const { data: quick }        = useQuickReport()
  const { data: metrics }      = useAnalyticsSummary()
  const { data: top = [] }     = useTopThreats(20)
  const generate               = useGenerateReport()
  const [generated, setGenerated] = useState<any>(null)
  const [genLoading, setGenLoading] = useState(false)
  const reportRef              = useRef<HTMLDivElement>(null)

  const handleGenerate = () => {
    setGenLoading(true)
    generate.mutate(
      {
        title: `Intelligence Report — ${new Date().toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })}`,
        format: 'json',
      },
      {
        onSuccess: d => { setGenerated(d); setGenLoading(false) },
        onError:   () => setGenLoading(false),
      }
    )
  }

  const q = quick as any
  const parsed = generated ? parseReportContent(generated.content) : null
  const reportTitle = generated?.title ?? `Intelligence Report — ${new Date().toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })}`

  // Build the print area HTML from parsed data + live metrics
  const topThreats = parsed?.top_threats ?? (top as any[]).slice(0, 10)
  const totalThreats = parsed?.total_threats ?? metrics?.total_threats ?? 0
  const critical     = parsed?.critical     ?? metrics?.critical_threats ?? 0
  const avgRisk      = parsed?.avg_risk     ?? metrics?.avg_risk_score ?? 0
  const maxRisk      = parsed?.max_risk     ?? metrics?.max_risk_score ?? 0

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 20, maxWidth: 1200 }}>

      {/* ── Header ────────────────────────────────────────────────────────── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 12 }}>
        <div>
          <h1 style={{ color: 'var(--ink-primary)', fontSize: 24, fontWeight: 800, margin: 0 }}>Intelligence Reports</h1>
          <p style={{ color: 'var(--ink-muted)', fontSize: 13, marginTop: 4 }}>Generate and manage threat intelligence reports</p>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          {generated && (
            <button
              onClick={() => downloadAsPDF(reportTitle)}
              style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '8px 16px', borderRadius: 8, background: 'rgba(34,197,94,0.12)', border: '1px solid rgba(34,197,94,0.4)', color: '#22c55e', fontSize: 13, fontWeight: 600, cursor: 'pointer' }}
            >
              ⬇ Download PDF
            </button>
          )}
          <button
            onClick={handleGenerate}
            disabled={genLoading}
            style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '8px 18px', borderRadius: 8, background: genLoading ? 'rgba(6,182,212,0.08)' : 'var(--cyan)', border: 'none', color: genLoading ? 'var(--cyan)' : '#050c18', fontSize: 13, fontWeight: 700, cursor: genLoading ? 'not-allowed' : 'pointer', opacity: genLoading ? 0.7 : 1 }}
          >
            {genLoading ? '⟳ Generating…' : '+ Generate Report'}
          </button>
        </div>
      </div>

      {/* ── KPI tiles ─────────────────────────────────────────────────────── */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 14 }}>
        {[
          { label: 'Total Threats',  value: q?.total_threats ?? metrics?.total_threats ?? 0,   color: 'var(--cyan)' },
          { label: 'Critical',       value: metrics?.critical_threats ?? 0,                    color: '#ef4444' },
          { label: 'Avg Risk Score', value: (metrics?.avg_risk_score ?? 0).toFixed(2),          color: '#f97316' },
          { label: 'Max Risk Score', value: (metrics?.max_risk_score ?? 0).toFixed(2),          color: '#ef4444' },
        ].map(({ label, value, color }) => (
          <div key={label} style={card({ padding: '18px 20px' })}>
            <div style={{ color: 'var(--ink-muted)', fontSize: 10, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 1 }}>{label}</div>
            <div style={{ color, fontSize: 32, fontWeight: 800, fontFamily: 'monospace', margin: '6px 0 0' }}>{value}</div>
          </div>
        ))}
      </div>

      {/* ── Category & Source breakdown ───────────────────────────────────── */}
      {metrics && (
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
          {[
            { title: 'By Category', entries: Object.entries(metrics.by_category ?? {}) },
            { title: 'By Source',   entries: Object.entries(metrics.by_source   ?? {}) },
          ].map(({ title, entries }) => (
            <div key={title} style={card({ padding: 20 })}>
              <h3 style={{ color: 'var(--ink-primary)', fontSize: 13, fontWeight: 700, margin: '0 0 14px' }}>{title}</h3>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12 }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid var(--bg-border)' }}>
                    {['Name', 'Count', '%'].map(h => (
                      <th key={h} style={{ textAlign: h === 'Name' ? 'left' : 'right', padding: '6px 0', color: 'var(--ink-muted)', fontWeight: 600, fontSize: 10, textTransform: 'uppercase', letterSpacing: 1 }}>{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {entries.map(([name, cnt]) => {
                    const pct = metrics.total_threats ? ((cnt as number) / metrics.total_threats * 100).toFixed(1) : '0'
                    return (
                      <tr key={name} style={{ borderBottom: '1px solid rgba(255,255,255,0.04)' }}>
                        <td style={{ padding: '8px 0', color: 'var(--ink-secondary)', textTransform: 'capitalize' }}>{name.replace(/_/g, ' ')}</td>
                        <td style={{ padding: '8px 0', textAlign: 'right', color: 'var(--cyan)', fontFamily: 'monospace', fontWeight: 600 }}>{cnt as number}</td>
                        <td style={{ padding: '8px 0', textAlign: 'right', color: 'var(--ink-muted)', fontFamily: 'monospace' }}>{pct}%</td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          ))}
        </div>
      )}

      {/* ── Top threats table ─────────────────────────────────────────────── */}
      <div style={card({ overflow: 'hidden' })}>
        <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--bg-border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: 'var(--bg-elevated)' }}>
          <h3 style={{ color: 'var(--ink-primary)', fontSize: 13, fontWeight: 700, margin: 0 }}>Top Threats by Risk Score</h3>
          <span style={{ color: 'var(--ink-muted)', fontSize: 11 }}>{(top as any[]).length} records</span>
        </div>
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12 }}>
            <thead>
              <tr style={{ background: 'var(--bg-elevated)' }}>
                {['#', 'Severity', 'Title', 'Category', 'Source', 'Risk Score', 'Detected'].map(h => (
                  <th key={h} style={{ padding: '10px 14px', textAlign: 'left', color: 'var(--ink-muted)', fontWeight: 700, fontSize: 10, textTransform: 'uppercase', letterSpacing: 1, whiteSpace: 'nowrap', borderBottom: '1px solid var(--bg-border)' }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {(top as any[]).map((t: any, i: number) => {
                const col = SEV_COLOR[t.severity] ?? '#64748b'
                return (
                  <tr key={t.id ?? i} style={{ borderBottom: '1px solid rgba(255,255,255,0.04)' }}
                    onMouseEnter={e => (e.currentTarget.style.background = 'rgba(255,255,255,0.02)')}
                    onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}>
                    <td style={{ padding: '10px 14px', color: 'var(--ink-muted)', fontFamily: 'monospace' }}>{i + 1}</td>
                    <td style={{ padding: '10px 14px' }}>
                      <span style={{ fontSize: 10, fontWeight: 700, padding: '3px 7px', borderRadius: 4, background: `${col}20`, color: col, textTransform: 'uppercase' }}>{t.severity}</span>
                    </td>
                    <td style={{ padding: '10px 14px', color: 'var(--ink-primary)', maxWidth: 280, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{t.title}</td>
                    <td style={{ padding: '10px 14px', color: 'var(--ink-secondary)', whiteSpace: 'nowrap', textTransform: 'capitalize' }}>{(t.category ?? '').replace(/_/g, ' ')}</td>
                    <td style={{ padding: '10px 14px', color: 'var(--ink-muted)', whiteSpace: 'nowrap' }}>{t.source ?? '—'}</td>
                    <td style={{ padding: '10px 14px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <div style={{ width: 50, height: 4, borderRadius: 2, background: 'var(--bg-border)' }}>
                          <div style={{ width: `${Math.min(((t.risk_score ?? 0) / 10) * 100, 100)}%`, height: '100%', borderRadius: 2, background: col }} />
                        </div>
                        <span style={{ color: col, fontFamily: 'monospace', fontWeight: 700 }}>{t.risk_score?.toFixed(2) ?? '—'}</span>
                      </div>
                    </td>
                    <td style={{ padding: '10px 14px', color: 'var(--ink-muted)', whiteSpace: 'nowrap' }}>
                      {t.detected_at ? new Date(t.detected_at).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }) : '—'}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── Generated report — structured card ───────────────────────────── */}
      {generated && (
        <div id="report-print-area" ref={reportRef}
          style={card({ border: '1px solid rgba(34,197,94,0.3)', background: 'rgba(34,197,94,0.03)', overflow: 'hidden' })}>

          {/* Report header */}
          <div style={{ padding: '20px 24px', borderBottom: '1px solid rgba(34,197,94,0.2)', background: 'rgba(34,197,94,0.05)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 10 }}>
            <div>
              <h2 style={{ color: 'var(--ink-primary)', fontSize: 16, fontWeight: 800, margin: 0 }}>{reportTitle}</h2>
              <p style={{ color: 'var(--ink-muted)', fontSize: 11, marginTop: 4 }}>
                {generated.threat_count ?? topThreats.length} threats analysed · Generated {new Date().toLocaleString('en-GB')}
              </p>
            </div>
            <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
              <span style={{ padding: '3px 10px', borderRadius: 10, background: 'rgba(34,197,94,0.15)', color: '#22c55e', fontSize: 11, fontWeight: 600 }}>✓ Generated</span>
              <button
                onClick={() => downloadAsPDF(reportTitle)}
                style={{ padding: '4px 12px', borderRadius: 6, background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)', color: 'var(--ink-secondary)', fontSize: 11, cursor: 'pointer' }}
              >
                ⬇ PDF
              </button>
            </div>
          </div>

          {/* Executive summary KPIs */}
          <div style={{ padding: '16px 24px', borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
            <p style={{ color: 'var(--ink-muted)', fontSize: 10, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 12 }}>Executive Summary</p>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
              {[
                { label: 'Total Threats', value: totalThreats, color: 'var(--cyan)' },
                { label: 'Critical',      value: critical,     color: '#ef4444' },
                { label: 'Avg Risk',      value: typeof avgRisk === 'number' ? avgRisk.toFixed(2) : avgRisk, color: '#f97316' },
                { label: 'Max Risk',      value: typeof maxRisk === 'number' ? maxRisk.toFixed(2) : maxRisk, color: '#ef4444' },
              ].map(({ label, value, color }) => (
                <div key={label} style={{ padding: '12px 14px', borderRadius: 8, background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)' }}>
                  <div style={{ color: 'var(--ink-muted)', fontSize: 10, fontWeight: 600, textTransform: 'uppercase', letterSpacing: 1 }}>{label}</div>
                  <div style={{ color, fontSize: 24, fontWeight: 800, fontFamily: 'monospace', marginTop: 4 }}>{value}</div>
                </div>
              ))}
            </div>
          </div>

          {/* Category breakdown from parsed JSON */}
          {(parsed?.by_category || metrics?.by_category) && (
            <div style={{ padding: '16px 24px', borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
              <p style={{ color: 'var(--ink-muted)', fontSize: 10, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 10 }}>Threat Categories</p>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                {Object.entries(parsed?.by_category ?? metrics?.by_category ?? {}).map(([cat, cnt]) => (
                  <div key={cat} style={{ padding: '6px 12px', borderRadius: 6, background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)', fontSize: 11 }}>
                    <span style={{ color: 'var(--ink-secondary)', textTransform: 'capitalize' }}>{cat.replace(/_/g, ' ')}</span>
                    <span style={{ color: 'var(--cyan)', fontFamily: 'monospace', fontWeight: 700, marginLeft: 8 }}>{cnt as number}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Top threats from report */}
          <div style={{ padding: '16px 24px' }}>
            <p style={{ color: 'var(--ink-muted)', fontSize: 10, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 10 }}>
              Top Threats — {topThreats.length} highest risk
            </p>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              {topThreats.slice(0, 10).map((t: any, i: number) => {
                const col = SEV_COLOR[t.severity] ?? '#64748b'
                return (
                  <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 14px', borderRadius: 8, background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)' }}>
                    <span style={{ color: 'var(--ink-muted)', fontFamily: 'monospace', fontSize: 11, width: 20, flexShrink: 0 }}>{i + 1}</span>
                    <span style={{ fontSize: 10, fontWeight: 700, padding: '2px 7px', borderRadius: 4, background: `${col}20`, color: col, textTransform: 'uppercase', flexShrink: 0 }}>{t.severity}</span>
                    <span style={{ color: 'var(--ink-primary)', fontSize: 12, flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{t.title}</span>
                    <span style={{ color: 'var(--ink-muted)', fontSize: 11, flexShrink: 0 }}>{(t.category ?? '').replace(/_/g, ' ')}</span>
                    <span style={{ color: col, fontFamily: 'monospace', fontWeight: 700, fontSize: 12, flexShrink: 0 }}>
                      {typeof t.risk_score === 'number' ? t.risk_score.toFixed(2) : t.risk_score ?? '—'}
                    </span>
                  </div>
                )
              })}
            </div>
          </div>

          {/* Report footer */}
          <div style={{ padding: '12px 24px', borderTop: '1px solid rgba(255,255,255,0.06)', background: 'var(--bg-elevated)', display: 'flex', justifyContent: 'space-between', fontSize: 10, color: 'var(--ink-muted)' }}>
            <span>OSINT Threat Intelligence Platform</span>
            <span>Classification: INTERNAL USE ONLY</span>
            <span>Generated: {new Date().toUTCString()}</span>
          </div>
        </div>
      )}
    </div>
  )
}
