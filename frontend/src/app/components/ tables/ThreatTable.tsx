import React from 'react'
import { formatDistanceToNow } from 'date-fns'
import AlertBadge from '../alerts/AlertBadge'
import RiskScoreBar from '../charts/RiskScoreBar'

interface Threat {
  id: number; title: string; severity: string
  risk_score: number; source: string; created_at: string; category: string
}

interface Props { threats: Threat[]; onSelect?: (t: Threat) => void }

export default function ThreatTable({ threats, onSelect }: Props) {
  if (!threats?.length) return (
    <div className="flex items-center justify-center h-32 text-sm text-slate-500">
      No threats yet — trigger ingestion to populate.
    </div>
  )
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr style={{ borderBottom: '1px solid var(--bg-border)' }}>
            {['Severity','Title','Category','Source','Risk','Detected'].map(h => (
              <th key={h} className="px-4 py-2 text-left text-[11px] font-semibold uppercase tracking-wider"
                style={{ color: 'var(--ink-muted)' }}>{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {threats.map(t => (
            <tr key={t.id} onClick={() => onSelect?.(t)}
              className="transition-colors cursor-pointer hover:bg-white/[0.03]"
              style={{ borderBottom: '1px solid rgba(255,255,255,0.04)' }}>
              <td className="px-4 py-3"><AlertBadge severity={t.severity} /></td>
              <td className="px-4 py-3 max-w-xs">
                <p className="truncate text-slate-200">{t.title}</p>
              </td>
              <td className="px-4 py-3 text-xs text-slate-400">{t.category}</td>
              <td className="px-4 py-3 text-xs text-slate-400">{t.source}</td>
              <td className="px-4 py-3 w-32"><RiskScoreBar score={t.risk_score} /></td>
              <td className="px-4 py-3 text-xs text-slate-500 whitespace-nowrap">
                {t.created_at ? formatDistanceToNow(new Date(t.created_at), { addSuffix: true }) : '—'}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
