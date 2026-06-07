import React from 'react'
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Cell } from 'recharts'

const COLOURS = ['#06b6d4','#3b82f6','#8b5cf6','#f97316','#ef4444','#22c55e']

interface Props { data: { source: string; count: number }[] }

export default function SourceDistribution({ data }: Props) {
  if (!data?.length) return (
    <div className="flex items-center justify-center h-48 text-sm text-slate-500">No data</div>
  )
  return (
    <ResponsiveContainer width="100%" height={200}>
      <BarChart data={data} layout="vertical" margin={{ left: 8, right: 16 }}>
        <XAxis type="number" tick={{ fill: '#475569', fontSize: 10 }} axisLine={false} tickLine={false} />
        <YAxis type="category" dataKey="source" tick={{ fill: '#94a3b8', fontSize: 10 }} width={110} axisLine={false} tickLine={false} />
        <Tooltip contentStyle={{ background: '#0d1f35', border: '1px solid #1a3050', borderRadius: 6, fontSize: 12 }} />
        <Bar dataKey="count" radius={[0, 3, 3, 0]}>
          {data.map((_, i) => <Cell key={i} fill={COLOURS[i % COLOURS.length]} />)}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  )
}
