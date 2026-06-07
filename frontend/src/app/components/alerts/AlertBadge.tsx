import React from 'react'

type Severity = 'critical' | 'high' | 'medium' | 'low'

const COLOURS: Record<Severity, { bg: string; text: string; border: string }> = {
  critical: { bg: 'rgba(239,68,68,0.15)',  text: '#ef4444', border: 'rgba(239,68,68,0.3)'  },
  high:     { bg: 'rgba(249,115,22,0.15)', text: '#f97316', border: 'rgba(249,115,22,0.3)' },
  medium:   { bg: 'rgba(234,179,8,0.15)',  text: '#eab308', border: 'rgba(234,179,8,0.3)'  },
  low:      { bg: 'rgba(34,197,94,0.15)',  text: '#22c55e', border: 'rgba(34,197,94,0.3)'  },
}

export default function AlertBadge({ severity }: { severity: string }) {
  const s = (severity?.toLowerCase() ?? 'low') as Severity
  const c = COLOURS[s] ?? COLOURS.low
  return (
    <span className="inline-flex items-center px-2 py-0.5 rounded text-[10px] font-bold font-mono uppercase"
      style={{ background: c.bg, color: c.text, border: `1px solid ${c.border}` }}>
      {s}
    </span>
  )
}
