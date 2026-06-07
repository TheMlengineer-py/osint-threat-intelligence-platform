import React from 'react'
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip,
  PieChart, Pie, Cell, BarChart, Bar, ResponsiveContainer,
} from 'recharts'
import { useAnalyticsSummary, useTopThreats, useAnalyticsTrends, useTriggerIngestion } from '@/hooks'
import { WorldThreatMap } from '@/components/charts/WorldThreatMap'
import { useTheme } from '@/context/ThemeContext'

const SEV   = { critical: '#ef4444', high: '#f97316', medium: '#eab308', low: '#22c55e' }
const CATS  = ['#06b6d4','#f97316','#ef4444','#8b5cf6','#22c55e','#eab308','#ec4899']

// World threat hotspot data (lat/lng mapped to SVG x/y on 1000×500 viewBox)
const HOTSPOTS = [
  { name: 'North America',  x: 200, y: 160, count: 18, color: '#ef4444' },
  { name: 'Europe',         x: 480, y: 140, count: 22, color: '#f97316' },
  { name: 'East Asia',      x: 730, y: 180, count: 15, color: '#eab308' },
  { name: 'Russia',         x: 600, y: 110, count: 12, color: '#ef4444' },
  { name: 'Middle East',    x: 570, y: 210, count: 9,  color: '#f97316' },
  { name: 'South Asia',     x: 650, y: 230, count: 7,  color: '#eab308' },
  { name: 'South America',  x: 270, y: 310, count: 5,  color: '#22c55e' },
  { name: 'Africa',         x: 490, y: 280, count: 4,  color: '#22c55e' },
  { name: 'SE Asia',        x: 720, y: 260, count: 8,  color: '#eab308' },
]

// WorldMap moved to components/charts/WorldThreatMap.tsx
function _DEPRECATED_WorldMap() {
  const [hovered, setHovered] = React.useState<string | null>(null)
  return (
    <div style={{ position: 'relative', width: '100%' }}>
      <svg viewBox="0 0 1000 480" style={{ width: '100%', display: 'block' }}>
        {/* Ocean background */}
        <rect width="1000" height="480" fill="rgba(6,182,212,0.04)" rx="8" />
        {/* Simplified continent outlines */}
        {/* North America */}
        <path d="M120,80 L230,70 L280,120 L260,200 L220,240 L180,220 L150,180 L110,160 Z"
          fill="rgba(255,255,255,0.06)" stroke="rgba(6,182,212,0.2)" strokeWidth="1" />
        {/* South America */}
        <path d="M220,270 L290,260 L310,340 L280,410 L240,420 L210,370 L200,300 Z"
          fill="rgba(255,255,255,0.06)" stroke="rgba(6,182,212,0.2)" strokeWidth="1" />
        {/* Europe */}
        <path d="M430,80 L530,75 L550,130 L510,160 L460,155 L430,130 Z"
          fill="rgba(255,255,255,0.06)" stroke="rgba(6,182,212,0.2)" strokeWidth="1" />
        {/* Africa */}
        <path d="M450,200 L540,195 L560,300 L520,390 L470,385 L440,300 L430,230 Z"
          fill="rgba(255,255,255,0.06)" stroke="rgba(6,182,212,0.2)" strokeWidth="1" />
        {/* Russia/Asia */}
        <path d="M540,60 L820,55 L840,140 L780,180 L700,170 L600,150 L550,120 Z"
          fill="rgba(255,255,255,0.06)" stroke="rgba(6,182,212,0.2)" strokeWidth="1" />
        {/* South/SE Asia */}
        <path d="M600,190 L780,195 L800,260 L750,290 L680,280 L620,250 Z"
          fill="rgba(255,255,255,0.06)" stroke="rgba(6,182,212,0.2)" strokeWidth="1" />
        {/* Australia */}
        <path d="M740,320 L850,315 L870,390 L820,410 L760,400 L730,370 Z"
          fill="rgba(255,255,255,0.06)" stroke="rgba(6,182,212,0.2)" strokeWidth="1" />
        {/* Grid lines */}
        {[200,400,600,800].map(x => (
          <line key={x} x1={x} y1="0" x2={x} y2="480" stroke="rgba(6,182,212,0.08)" strokeWidth="0.5" />
        ))}
        {[120,240,360].map(y => (
          <line key={y} x1="0" y1={y} x2="1000" y2={y} stroke="rgba(6,182,212,0.08)" strokeWidth="0.5" />
        ))}
        {/* Threat hotspots */}
        {HOTSPOTS.map(h => {
          const isHov = hovered === h.name
          const r = Math.max(8, Math.min(24, h.count * 1.2))
          return (
            <g key={h.name}
              onMouseEnter={() => setHovered(h.name)}
              onMouseLeave={() => setHovered(null)}
              style={{ cursor: 'pointer' }}>
              {/* Pulse ring */}
              <circle cx={h.x} cy={h.y} r={r * 2.2}
                fill={`${h.color}12`} stroke={`${h.color}30`} strokeWidth="1">
                <animate attributeName="r" values={`${r * 1.8};${r * 2.6};${r * 1.8}`}
                  dur="3s" repeatCount="indefinite" />
                <animate attributeName="opacity" values="0.6;0.2;0.6"
                  dur="3s" repeatCount="indefinite" />
              </circle>
              {/* Core dot */}
              <circle cx={h.x} cy={h.y} r={isHov ? r * 1.3 : r}
                fill={h.color} fillOpacity="0.85"
                stroke="rgba(255,255,255,0.3)" strokeWidth="1.5"
                style={{ transition: 'r 0.2s' }} />
              {/* Count label */}
              <text x={h.x} y={h.y + 4} textAnchor="middle"
                fontSize={r > 14 ? 10 : 8} fontWeight="700"
                fill="white" fontFamily="monospace">
                {h.count}
              </text>
              {/* Tooltip on hover */}
              {isHov && (
                <g>
                  <rect x={h.x - 55} y={h.y - r - 36} width="110" height="28" rx="6"
                    fill="rgba(10,22,40,0.95)" stroke={h.color} strokeWidth="1" />
                  <text x={h.x} y={h.y - r - 16} textAnchor="middle"
                    fontSize="11" fill="white" fontFamily="sans-serif">
                    {h.name}
                  </text>
                  <text x={h.x} y={h.y - r - 26} textAnchor="middle"
                    fontSize="9" fill={h.color} fontFamily="monospace">
                    {h.count} threats
                  </text>
                </g>
              )}
            </g>
          )
        })}
        {/* Legend */}
        <g transform="translate(20, 430)">
          {[['Critical','#ef4444'],['High','#f97316'],['Medium','#eab308'],['Low','#22c55e']].map(([l,c], i) => (
            <g key={l} transform={`translate(${i * 120}, 0)`}>
              <circle cx="6" cy="6" r="5" fill={c} fillOpacity="0.8" />
              <text x="16" y="10" fontSize="10" fill="rgba(255,255,255,0.5)" fontFamily="sans-serif">{l}</text>
            </g>
          ))}
        </g>
      </svg>
    </div>
  )
}

function card(extra: React.CSSProperties = {}): React.CSSProperties {
  return { background: 'var(--bg-card)', border: '1px solid var(--bg-border)', borderRadius: 12, padding: 20, ...extra }
}

function KpiCard({ label, value, sub, color, change }: {
  label: string; value: string | number; sub?: string; color: string; change?: string
}) {
  return (
    <div style={{ ...card(), flex: 1, minWidth: 130 }}>
      <div style={{ color: 'var(--ink-muted)', fontSize: 10, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 1 }}>{label}</div>
      <div style={{ color, fontSize: 36, fontWeight: 800, fontFamily: 'monospace', margin: '6px 0 4px', lineHeight: 1 }}>{value}</div>
      {sub && <div style={{ color: 'var(--ink-muted)', fontSize: 11 }}>{sub}</div>}
      {change && <div style={{ color: '#22c55e', fontSize: 11, marginTop: 4 }}>↑ {change}</div>}
    </div>
  )
}

function ChartTip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null
  return (
    <div style={{ background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)', borderRadius: 8, padding: '10px 14px', fontSize: 12 }}>
      <p style={{ color: 'var(--ink-muted)', marginBottom: 6 }}>{label}</p>
      {payload.map((p: any) => (
        <div key={p.name} style={{ color: p.color, marginBottom: 2 }}>{p.name}: <strong>{p.value}</strong></div>
      ))}
    </div>
  )
}

function buildTrend(data?: Record<string, Record<string, number>>) {
  if (!data) return []
  return Object.entries(data).slice(-30).map(([date, v]) => ({
    date: date.slice(5),
    Total:    (v.critical ?? 0) + (v.high ?? 0) + (v.medium ?? 0) + (v.low ?? 0),
    Critical: v.critical ?? 0,
    High:     v.high     ?? 0,
    Medium:   v.medium   ?? 0,
  }))
}

export default function Dashboard() {
  const { data: m, isLoading }     = useAnalyticsSummary()
  const { data: top = [] }         = useTopThreats(8)
  const { data: trends }           = useAnalyticsTrends(30)
  const { mutate: refresh, isPending: refreshing } = useTriggerIngestion()
  const { theme }                  = useTheme()
  const isDark                     = theme === 'dark'
  const axisColor                  = isDark ? '#475569' : '#94a3b8'
  const gridColor                  = isDark ? '#1a3050' : '#e2e8f0'
  const trendSeries                = buildTrend(trends?.trend)

  const catData = Object.entries(m?.by_category ?? {}).map(([name, value], i) => ({
    name: name.replace(/_/g, ' '), value: value as number, color: CATS[i % CATS.length],
  }))
  const srcData = Object.entries(m?.by_source ?? {}).map(([name, value]) => ({
    name, value: value as number,
  }))

  if (isLoading) return (
    <div style={{ padding: 32, display: 'flex', alignItems: 'center', gap: 12, color: 'var(--ink-secondary)' }}>
      <div style={{ width: 20, height: 20, border: '2px solid var(--cyan)', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
      Loading dashboard…
    </div>
  )

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 20, maxWidth: 1600 }}>

      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', flexWrap: 'wrap', gap: 12 }}>
        <div>
          <h1 style={{ color: 'var(--ink-primary)', fontSize: 26, fontWeight: 800, margin: 0 }}>Dashboard</h1>
          <p style={{ color: 'var(--ink-muted)', fontSize: 13, marginTop: 4 }}>
            Open Source Intelligence (OSINT) — Command Centre
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <button onClick={() => refresh()} disabled={refreshing} style={{
            display: 'flex', alignItems: 'center', gap: 8, padding: '8px 18px', borderRadius: 8,
            background: refreshing ? 'rgba(6,182,212,0.08)' : 'rgba(6,182,212,0.15)',
            border: '1px solid rgba(6,182,212,0.4)', color: 'var(--cyan)',
            cursor: refreshing ? 'not-allowed' : 'pointer', fontSize: 13, fontWeight: 600,
            opacity: refreshing ? 0.7 : 1,
          }}>
            <span style={{ display: 'inline-block', animation: refreshing ? 'spin 1s linear infinite' : 'none' }}>↺</span>
            {refreshing ? 'Running ingestion…' : 'Run OSINT Ingestion'}
          </button>
          <div style={{ textAlign: 'right' }}>
            <div style={{ color: '#22c55e', fontSize: 12, fontWeight: 600 }}>● Live</div>
            <div style={{ color: 'var(--ink-muted)', fontSize: 11 }}>{new Date().toLocaleTimeString()}</div>
          </div>
        </div>
      </div>

      {/* KPI row */}
      <div style={{ display: 'flex', gap: 14, flexWrap: 'wrap' }}>
        <KpiCard label="Total Threats"  value={m?.total_threats    ?? 0}                   color="var(--cyan)" sub="all ingested sources" change="+12.3% vs last 7d" />
        <KpiCard label="Critical"       value={m?.critical_threats  ?? 0}                   color="#ef4444"     sub="immediate action req'd" />
        <KpiCard label="High Severity"  value={m?.high_threats      ?? 0}                   color="#f97316"     sub="investigate soon" />
        <KpiCard label="Avg Risk Score" value={(m?.avg_risk_score   ?? 0).toFixed(2)}        color="#eab308"     sub="0–10 normalised" />
        <KpiCard label="Max Risk Score" value={(m?.max_risk_score   ?? 0).toFixed(2)}        color="#ef4444"     sub="highest single threat" />
        <KpiCard label="Pending NLP"    value={m?.pending_docs      ?? 0}                   color={m?.pending_docs ? '#a78bfa' : '#22c55e'}
          sub={m?.pending_docs ? 'awaiting processing' : 'all processed'} />
      </div>

      {/* World Threat Map */}
      <div style={card({ padding: '20px 20px 12px' })}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
          <div>
            <h2 style={{ color: 'var(--ink-primary)', fontSize: 14, fontWeight: 700, margin: 0 }}>
              Global Threat Distribution
            </h2>
            <p style={{ color: 'var(--ink-muted)', fontSize: 11, marginTop: 3 }}>
              OSINT threat source geolocation — hover for details
            </p>
          </div>
          <div style={{ display: 'flex', gap: 16, fontSize: 11, color: 'var(--ink-muted)' }}>
            <span>Total hotspots: <strong style={{ color: 'var(--cyan)' }}>{HOTSPOTS.length}</strong></span>
            <span>Most active: <strong style={{ color: '#ef4444' }}>Europe ({HOTSPOTS.find(h=>h.name==='Europe')?.count})</strong></span>
          </div>
        </div>
        <WorldThreatMap />
      </div>

      {/* Trend + Category */}
      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 16 }}>
        <div style={card()}>
          <h2 style={{ color: 'var(--ink-primary)', fontSize: 14, fontWeight: 700, margin: '0 0 4px' }}>Threat Trend — Last 30 Days</h2>
          <p style={{ color: 'var(--ink-muted)', fontSize: 11, margin: '0 0 16px' }}>Daily volume by severity level</p>
          {trendSeries.length > 0 ? (
            <ResponsiveContainer width="100%" height={200}>
              <AreaChart data={trendSeries} margin={{ top: 4, right: 8, bottom: 0, left: 0 }}>
                <defs>
                  {[['Total','#06b6d4'],['Critical','#ef4444'],['High','#f97316'],['Medium','#eab308']].map(([k,c]) => (
                    <linearGradient key={k} id={`g${k}`} x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%"  stopColor={c} stopOpacity={0.3} />
                      <stop offset="95%" stopColor={c} stopOpacity={0.02} />
                    </linearGradient>
                  ))}
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke={gridColor} />
                <XAxis dataKey="date" tick={{ fill: axisColor, fontSize: 10 }} tickLine={false} />
                <YAxis tick={{ fill: axisColor, fontSize: 10 }} tickLine={false} axisLine={false} />
                <Tooltip content={<ChartTip />} />
                {[['Total','#06b6d4'],['Critical','#ef4444'],['High','#f97316'],['Medium','#eab308']].map(([k,c]) => (
                  <Area key={k} type="monotone" dataKey={k} stroke={c} strokeWidth={2} fill={`url(#g${k})`} />
                ))}
              </AreaChart>
            </ResponsiveContainer>
          ) : (
            <div style={{ height: 200, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 8, color: 'var(--ink-muted)' }}>
              <span style={{ fontSize: 32 }}>📈</span>
              <p style={{ fontSize: 13 }}>Click "Run OSINT Ingestion" above to populate trend data</p>
            </div>
          )}
        </div>

        <div style={card()}>
          <h2 style={{ color: 'var(--ink-primary)', fontSize: 14, fontWeight: 700, margin: '0 0 4px' }}>Threat Categories</h2>
          <p style={{ color: 'var(--ink-muted)', fontSize: 11, margin: '0 0 12px' }}>Distribution by type</p>
          {catData.length > 0 ? (
            <>
              <ResponsiveContainer width="100%" height={150}>
                <PieChart>
                  <Pie data={catData} cx="50%" cy="50%" innerRadius={40} outerRadius={65} paddingAngle={3} dataKey="value" strokeWidth={0}>
                    {catData.map((_, i) => <Cell key={i} fill={CATS[i % CATS.length]} />)}
                  </Pie>
                  <Tooltip contentStyle={{ background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)', borderRadius: 8, fontSize: 12 }} />
                </PieChart>
              </ResponsiveContainer>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                {catData.slice(0, 5).map((d, i) => (
                  <div key={i} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                      <div style={{ width: 7, height: 7, borderRadius: '50%', background: d.color }} />
                      <span style={{ color: 'var(--ink-secondary)', fontSize: 11, textTransform: 'capitalize' }}>{d.name}</span>
                    </div>
                    <span style={{ color: d.color, fontSize: 12, fontWeight: 700, fontFamily: 'monospace' }}>{d.value}</span>
                  </div>
                ))}
              </div>
            </>
          ) : <div style={{ height: 200, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--ink-muted)', fontSize: 13 }}>No data yet</div>}
        </div>
      </div>

      {/* Top Threats + Source bar */}
      <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: 16 }}>
        <div style={card()}>
          <h2 style={{ color: 'var(--ink-primary)', fontSize: 14, fontWeight: 700, margin: '0 0 16px' }}>
            Top Threats by Risk Score
          </h2>
          {(top as any[]).length === 0
            ? <p style={{ color: 'var(--ink-muted)', fontSize: 13 }}>No threats yet — run ingestion above.</p>
            : (top as any[]).map((t: any, i: number) => {
                const col = SEV[t.severity as keyof typeof SEV] ?? '#64748b'
                return (
                  <div key={i} style={{ display: 'flex', gap: 12, alignItems: 'center', padding: '10px 0', borderBottom: '1px solid var(--bg-border)' }}>
                    <span style={{ width: 22, height: 22, borderRadius: '50%', background: 'var(--bg-elevated)', color: 'var(--ink-muted)', fontSize: 11, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, flexShrink: 0 }}>{i + 1}</span>
                    <span style={{ fontSize: 10, fontWeight: 700, padding: '2px 7px', borderRadius: 4, background: `${col}22`, color: col, textTransform: 'uppercase', flexShrink: 0 }}>{t.severity}</span>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ color: 'var(--ink-primary)', fontSize: 12, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{t.title}</div>
                      <div style={{ marginTop: 4, height: 3, borderRadius: 2, background: 'var(--bg-border)' }}>
                        <div style={{ width: `${Math.min((t.risk_score / 10) * 100, 100)}%`, height: '100%', borderRadius: 2, background: col }} />
                      </div>
                    </div>
                    <span style={{ color: col, fontFamily: 'monospace', fontWeight: 700, fontSize: 13, flexShrink: 0 }}>{t.risk_score?.toFixed(2)}</span>
                  </div>
                )
              })
          }
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={card({ flex: 1 })}>
            <h2 style={{ color: 'var(--ink-primary)', fontSize: 14, fontWeight: 700, margin: '0 0 12px' }}>Threats by Source</h2>
            {srcData.length > 0 ? (
              <ResponsiveContainer width="100%" height={160}>
                <BarChart data={srcData} layout="vertical" margin={{ top: 0, right: 20, bottom: 0, left: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke={gridColor} horizontal={false} />
                  <XAxis type="number" tick={{ fill: axisColor, fontSize: 10 }} tickLine={false} axisLine={false} />
                  <YAxis type="category" dataKey="name" tick={{ fill: axisColor, fontSize: 10 }} tickLine={false} axisLine={false} width={95} />
                  <Tooltip contentStyle={{ background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)', borderRadius: 8, fontSize: 12 }} />
                  <Bar dataKey="value" radius={[0, 4, 4, 0]}>
                    {srcData.map((_, i) => <Cell key={i} fill={CATS[i % CATS.length]} />)}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            ) : <div style={{ height: 160, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--ink-muted)', fontSize: 13 }}>No source data yet</div>}
          </div>

          <div style={card()}>
            <h2 style={{ color: 'var(--ink-primary)', fontSize: 14, fontWeight: 700, margin: '0 0 12px' }}>Risk Distribution</h2>
            {[
              { label: 'Critical (≥7)', count: m?.critical_threats ?? 0, color: '#ef4444' },
              { label: 'High (≥5)',     count: m?.high_threats     ?? 0, color: '#f97316' },
              { label: 'Medium (≥3)',   count: Math.max(0, (m?.total_threats ?? 0) - (m?.critical_threats ?? 0) - (m?.high_threats ?? 0)), color: '#eab308' },
            ].map(({ label, count, color }) => {
              const pct = m?.total_threats ? Math.round((count / m.total_threats) * 100) : 0
              return (
                <div key={label} style={{ marginBottom: 10 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                    <span style={{ color, fontSize: 12, fontWeight: 600 }}>{label}</span>
                    <span style={{ color: 'var(--ink-muted)', fontSize: 11 }}>{count} ({pct}%)</span>
                  </div>
                  <div style={{ height: 5, borderRadius: 3, background: 'var(--bg-border)' }}>
                    <div style={{ width: `${pct}%`, height: '100%', borderRadius: 3, background: color }} />
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      </div>
    </div>
  )
}
