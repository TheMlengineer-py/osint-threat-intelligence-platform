import React, { useState } from 'react'
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip,
  BarChart, Bar, Cell, PieChart, Pie, ResponsiveContainer,
} from 'recharts'
import { useAnalyticsSummary, useRiskDistribution, useTopThreats, useAnalyticsTrends } from '@/hooks'
import { useTheme } from '@/context/ThemeContext'

const CATS = ['#06b6d4','#f97316','#ef4444','#8b5cf6','#22c55e','#eab308','#ec4899']

function card(extra: React.CSSProperties = {}): React.CSSProperties {
  return { background: 'var(--bg-card)', border: '1px solid var(--bg-border)', borderRadius: 12, padding: 20, ...extra }
}

function Tip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null
  return (
    <div style={{ background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)', borderRadius: 8, padding: '10px 14px', fontSize: 12 }}>
      <p style={{ color: 'var(--ink-muted)', marginBottom: 6 }}>{label}</p>
      {payload.map((p: any) => (
        <div key={p.name} style={{ color: p.color ?? 'var(--cyan)', marginBottom: 2 }}>{p.name}: <strong>{p.value}</strong></div>
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
    Low:      v.low      ?? 0,
  }))
}

export default function Analytics() {
  const { data: metrics }  = useAnalyticsSummary()
  const { data: riskDist } = useRiskDistribution()
  const { data: top = [] } = useTopThreats(15)
  const { data: trends }   = useAnalyticsTrends(30)
  const { theme }          = useTheme()
  const isDark             = theme === 'dark'
  const axisColor          = isDark ? '#475569' : '#94a3b8'
  const gridColor          = isDark ? '#1a3050' : '#e2e8f0'
  const [days, setDays]    = useState(30)

  const trendSeries = buildTrend(trends?.trend)
  const catData     = Object.entries(metrics?.by_category ?? {}).map(([name, value], i) => ({
    name: name.replace(/_/g,' '), value: value as number, color: CATS[i % CATS.length],
  }))
  const srcData = Object.entries(metrics?.by_source ?? {}).map(([name, value]) => ({
    name, value: value as number,
  }))
  const topData = (top as any[]).slice(0, 10).map(t => ({
    name: t.title?.substring(0, 22) + (t.title?.length > 22 ? '…' : ''),
    risk: parseFloat(t.risk_score?.toFixed(2) ?? '0'),
    severity: t.severity,
  }))

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 20, maxWidth: 1400 }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', flexWrap: 'wrap', gap: 12 }}>
        <div>
          <h1 style={{ color: 'var(--ink-primary)', fontSize: 24, fontWeight: 800, margin: 0 }}>Analytics</h1>
          <p style={{ color: 'var(--ink-muted)', fontSize: 13, marginTop: 4 }}>Deep-dive insights and trend analysis</p>
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          {[7, 14, 30].map(d => (
            <button key={d} onClick={() => setDays(d)} style={{
              padding: '6px 14px', borderRadius: 8, fontSize: 12, fontWeight: 600, cursor: 'pointer',
              background: days === d ? 'rgba(6,182,212,0.2)' : 'var(--bg-elevated)',
              border: `1px solid ${days === d ? 'rgba(6,182,212,0.5)' : 'var(--bg-border)'}`,
              color: days === d ? 'var(--cyan)' : 'var(--ink-secondary)',
            }}>{d}d</button>
          ))}
        </div>
      </div>

      {/* KPI summary row */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 14 }}>
        {[
          { label: 'Total Threats',   value: metrics?.total_threats    ?? 0,                   color: 'var(--cyan)' },
          { label: 'Critical',        value: metrics?.critical_threats  ?? 0,                   color: '#ef4444' },
          { label: 'Avg Risk',        value: (metrics?.avg_risk_score  ?? 0).toFixed(2),         color: '#f97316' },
          { label: 'Max Risk',        value: (metrics?.max_risk_score  ?? 0).toFixed(2),         color: '#ef4444' },
        ].map(({ label, value, color }) => (
          <div key={label} style={card({ textAlign: 'center', padding: '18px' })}>
            <div style={{ color: 'var(--ink-muted)', fontSize: 10, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 1 }}>{label}</div>
            <div style={{ color, fontSize: 34, fontWeight: 800, fontFamily: 'monospace', margin: '6px 0 0' }}>{value}</div>
          </div>
        ))}
      </div>

      {/* Trend chart */}
      <div style={card()}>
        <h2 style={{ color: 'var(--ink-primary)', fontSize: 14, fontWeight: 700, margin: '0 0 4px' }}>Threat Volume Over Time</h2>
        <p style={{ color: 'var(--ink-muted)', fontSize: 11, margin: '0 0 16px' }}>Daily count by severity — last {days} days</p>
        {trendSeries.length > 0 ? (
          <ResponsiveContainer width="100%" height={220}>
            <AreaChart data={trendSeries.slice(-days)} margin={{ top: 4, right: 8, bottom: 0, left: 0 }}>
              <defs>
                {[['Total','#06b6d4'],['Critical','#ef4444'],['High','#f97316'],['Medium','#eab308'],['Low','#22c55e']].map(([k,c]) => (
                  <linearGradient key={k} id={`ag${k}`} x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor={c} stopOpacity={0.3} />
                    <stop offset="95%" stopColor={c} stopOpacity={0.02} />
                  </linearGradient>
                ))}
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke={gridColor} />
              <XAxis dataKey="date" tick={{ fill: axisColor, fontSize: 10 }} tickLine={false} />
              <YAxis tick={{ fill: axisColor, fontSize: 10 }} tickLine={false} axisLine={false} />
              <Tooltip content={<Tip />} />
              {[['Total','#06b6d4'],['Critical','#ef4444'],['High','#f97316'],['Medium','#eab308']].map(([k,c]) => (
                <Area key={k} type="monotone" dataKey={k} stroke={c} strokeWidth={2} fill={`url(#ag${k})`} />
              ))}
            </AreaChart>
          </ResponsiveContainer>
        ) : (
          <div style={{ height: 220, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', color: 'var(--ink-muted)', gap: 8 }}>
            <span style={{ fontSize: 32 }}>📈</span>
            <p>Trend data appears after ingestion runs</p>
          </div>
        )}
      </div>

      {/* Risk dist + Category + Source row */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 16 }}>

        {/* Risk score distribution */}
        <div style={card()}>
          <h2 style={{ color: 'var(--ink-primary)', fontSize: 14, fontWeight: 700, margin: '0 0 4px' }}>Risk Score Distribution</h2>
          <p style={{ color: 'var(--ink-muted)', fontSize: 11, margin: '0 0 16px' }}>Bucketed 0–10</p>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12 }}>
            <thead>
              <tr style={{ borderBottom: '1px solid var(--bg-border)' }}>
                <th style={{ textAlign: 'left', padding: '5px 0', color: 'var(--ink-muted)', fontSize: 10, fontWeight: 700, textTransform: 'uppercase' }}>Range</th>
                <th style={{ textAlign: 'right', padding: '5px 0', color: 'var(--ink-muted)', fontSize: 10, fontWeight: 700, textTransform: 'uppercase' }}>Count</th>
                <th style={{ textAlign: 'right', padding: '5px 0', color: 'var(--ink-muted)', fontSize: 10, fontWeight: 700, textTransform: 'uppercase' }}>Bar</th>
              </tr>
            </thead>
            <tbody>
              {Object.entries(riskDist?.buckets ?? {}).map(([bucket, count]) => {
                const pct = riskDist?.total ? Math.round((count as number) / riskDist.total * 100) : 0
                const col = bucket.startsWith('8') || bucket.startsWith('6') ? '#ef4444' : bucket.startsWith('4') || bucket.startsWith('5') ? '#f97316' : '#22c55e'
                return (
                  <tr key={bucket} style={{ borderBottom: '1px solid rgba(255,255,255,0.04)' }}>
                    <td style={{ padding: '8px 0', color: 'var(--ink-secondary)', fontFamily: 'monospace' }}>{bucket}</td>
                    <td style={{ padding: '8px 0', textAlign: 'right', color: 'var(--cyan)', fontFamily: 'monospace', fontWeight: 700 }}>{count as number}</td>
                    <td style={{ padding: '8px 0', paddingLeft: 12 }}>
                      <div style={{ height: 6, width: 80, borderRadius: 3, background: 'var(--bg-border)' }}>
                        <div style={{ width: `${pct}%`, height: '100%', borderRadius: 3, background: col }} />
                      </div>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>

        {/* Category breakdown */}
        <div style={card()}>
          <h2 style={{ color: 'var(--ink-primary)', fontSize: 14, fontWeight: 700, margin: '0 0 12px' }}>Category Breakdown</h2>
          {catData.length > 0 ? (
            <>
              <ResponsiveContainer width="100%" height={130}>
                <PieChart>
                  <Pie data={catData} cx="50%" cy="50%" innerRadius={35} outerRadius={58} paddingAngle={3} dataKey="value" strokeWidth={0}>
                    {catData.map((_, i) => <Cell key={i} fill={CATS[i % CATS.length]} />)}
                  </Pie>
                  <Tooltip contentStyle={{ background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)', borderRadius: 8, fontSize: 11 }} />
                </PieChart>
              </ResponsiveContainer>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 4, marginTop: 8 }}>
                {catData.map((d, i) => (
                  <div key={i} style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                      <div style={{ width: 7, height: 7, borderRadius: '50%', background: d.color }} />
                      <span style={{ color: 'var(--ink-secondary)', fontSize: 11, textTransform: 'capitalize' }}>{d.name}</span>
                    </div>
                    <span style={{ color: d.color, fontSize: 11, fontWeight: 700, fontFamily: 'monospace' }}>{d.value}</span>
                  </div>
                ))}
              </div>
            </>
          ) : <div style={{ height: 200, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--ink-muted)', fontSize: 13 }}>No data</div>}
        </div>

        {/* Source breakdown */}
        <div style={card()}>
          <h2 style={{ color: 'var(--ink-primary)', fontSize: 14, fontWeight: 700, margin: '0 0 12px' }}>Source Breakdown</h2>
          {srcData.length > 0 ? (
            <ResponsiveContainer width="100%" height={200}>
              <BarChart data={srcData} layout="vertical" margin={{ top: 0, right: 20, bottom: 0, left: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke={gridColor} horizontal={false} />
                <XAxis type="number" tick={{ fill: axisColor, fontSize: 10 }} tickLine={false} axisLine={false} />
                <YAxis type="category" dataKey="name" tick={{ fill: axisColor, fontSize: 10 }} tickLine={false} axisLine={false} width={90} />
                <Tooltip contentStyle={{ background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)', borderRadius: 8, fontSize: 11 }} />
                <Bar dataKey="value" radius={[0, 4, 4, 0]}>
                  {srcData.map((_, i) => <Cell key={i} fill={CATS[i % CATS.length]} />)}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          ) : <div style={{ height: 200, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--ink-muted)', fontSize: 13 }}>No data</div>}
        </div>
      </div>

      {/* Top threats risk bar chart */}
      {topData.length > 0 && (
        <div style={card()}>
          <h2 style={{ color: 'var(--ink-primary)', fontSize: 14, fontWeight: 700, margin: '0 0 4px' }}>Top Threats — Risk Score Chart</h2>
          <p style={{ color: 'var(--ink-muted)', fontSize: 11, margin: '0 0 16px' }}>Top 10 by risk score</p>
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={topData} margin={{ top: 4, right: 12, bottom: 60, left: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke={gridColor} vertical={false} />
              <XAxis dataKey="name" tick={{ fill: axisColor, fontSize: 9 }} tickLine={false} angle={-35} textAnchor="end" interval={0} />
              <YAxis domain={[0, 10]} tick={{ fill: axisColor, fontSize: 10 }} tickLine={false} axisLine={false} />
              <Tooltip contentStyle={{ background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)', borderRadius: 8, fontSize: 11 }} />
              <Bar dataKey="risk" name="Risk Score" radius={[4, 4, 0, 0]}>
                {topData.map((d, i) => (
                  <Cell key={i} fill={d.severity === 'critical' ? '#ef4444' : d.severity === 'high' ? '#f97316' : '#eab308'} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}
    </div>
  )
}
