import React from 'react'
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, Legend } from 'recharts'

interface Props { data: Record<string, Record<string, number>> }

export default function ThreatTrendChart({ data }: Props) {
  if (!data || !Object.keys(data).length) return (
    <div className="flex items-center justify-center h-48 text-sm text-slate-500">No trend data yet</div>
  )

  const chartData = Object.entries(data).map(([date, severities]) => ({
    date: date.slice(5),
    critical: severities.critical ?? 0,
    high:     severities.high     ?? 0,
    medium:   severities.medium   ?? 0,
    low:      severities.low      ?? 0,
  }))

  return (
    <ResponsiveContainer width="100%" height={220}>
      <LineChart data={chartData} margin={{ top: 4, right: 8, bottom: 0, left: -20 }}>
        <XAxis dataKey="date" tick={{ fill: '#475569', fontSize: 10 }} axisLine={false} tickLine={false} />
        <YAxis tick={{ fill: '#475569', fontSize: 10 }} axisLine={false} tickLine={false} />
        <Tooltip contentStyle={{ background: '#0d1f35', border: '1px solid #1a3050', borderRadius: 6, fontSize: 12 }} />
        <Legend iconType="circle" iconSize={7}
          formatter={(v) => <span style={{ color: '#94a3b8', fontSize: 10 }}>{v}</span>} />
        <Line type="monotone" dataKey="critical" stroke="#ef4444" strokeWidth={2} dot={false} />
        <Line type="monotone" dataKey="high"     stroke="#f97316" strokeWidth={2} dot={false} />
        <Line type="monotone" dataKey="medium"   stroke="#eab308" strokeWidth={1.5} dot={false} />
        <Line type="monotone" dataKey="low"      stroke="#22c55e" strokeWidth={1}   dot={false} />
      </LineChart>
    </ResponsiveContainer>
  )
}
