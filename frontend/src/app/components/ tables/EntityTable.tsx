import React from 'react'

interface Entity { id: number; name: string; entity_type: string; threat_count: number }
interface Props   { entities: Entity[]; onSelect?: (e: Entity) => void }

export default function EntityTable({ entities, onSelect }: Props) {
  if (!entities?.length) return (
    <div className="flex items-center justify-center h-32 text-sm text-slate-500">No entities found.</div>
  )
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr style={{ borderBottom: '1px solid var(--bg-border)' }}>
            {['Name','Type','Threat Count'].map(h => (
              <th key={h} className="px-4 py-2 text-left text-[11px] font-semibold uppercase tracking-wider"
                style={{ color: 'var(--ink-muted)' }}>{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {entities.map(e => (
            <tr key={e.id} onClick={() => onSelect?.(e)}
              className="cursor-pointer hover:bg-white/[0.03] transition-colors"
              style={{ borderBottom: '1px solid rgba(255,255,255,0.04)' }}>
              <td className="px-4 py-3 text-slate-200">{e.name}</td>
              <td className="px-4 py-3">
                <span className="text-[10px] px-2 py-0.5 rounded font-mono uppercase"
                  style={{ background: 'rgba(6,182,212,0.1)', color: 'var(--cyan)', border: '1px solid rgba(6,182,212,0.2)' }}>
                  {e.entity_type}
                </span>
              </td>
              <td className="px-4 py-3 font-mono text-xs" style={{ color: 'var(--cyan)' }}>{e.threat_count}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
