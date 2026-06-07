import React from 'react'
import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer, Legend } from 'recharts'

const COLOURS = ['#06b6d4','#3b82f6','#8b5cf6','#f97316','#ef4444','#22c55e','#eab308','#ec4899']

interface Props { data: { category: string; count: number }[] }

export default function CategoryDonut({ data }: Props) {
  if (!data?.length) return (
    <div className="flex items-center justify-center h-48 text-sm text-slate-500">No data</div>
  )
  return (
    <ResponsiveContainer width="100%" height={220}>
      <PieChart>
        <Pie data={data} dataKey="count" nameKey="category"
          cx="50%" cy="50%" innerRadius={55} outerRadius={85} paddingAngle={2}>
          {data.map((_, i) => <Cell key={i} fill={COLOURS[i % COLOURS.length]} />)}
        </Pie>
        <Tooltip contentStyle={{ background: '#0d1f35', border: '1px solid #1a3050', borderRadius: 6, fontSize: 12 }}
          formatter={(v: number, n: string) => [v, n]} />
        <Legend iconType="circle" iconSize={8}
          formatter={(v) => <span style={{ color: '#94a3b8', fontSize: 11 }}>{v}</span>} />
      </PieChart>
    </ResponsiveContainer>
  )
}
