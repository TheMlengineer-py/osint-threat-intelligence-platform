import React from 'react'

interface Props { score: number; max?: number }

export default function RiskScoreBar({ score, max = 1 }: Props) {
  const pct  = Math.min(100, (score / max) * 100)
  const color = pct >= 70 ? '#ef4444' : pct >= 45 ? '#f97316' : pct >= 20 ? '#eab308' : '#22c55e'
  return (
    <div className="flex items-center gap-2">
      <div className="flex-1 h-1.5 rounded-full overflow-hidden" style={{ background: 'var(--bg-border)' }}>
        <div className="h-full rounded-full transition-all duration-500" style={{ width: `${pct}%`, background: color }} />
      </div>
      <span className="text-[11px] font-mono w-8 text-right shrink-0" style={{ color }}>{score.toFixed(2)}</span>
    </div>
  )
}
