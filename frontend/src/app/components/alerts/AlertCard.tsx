import React from 'react'
import { formatDistanceToNow } from 'date-fns'
import AlertBadge from './AlertBadge'

interface AlertCardProps {
  title:     string
  severity:  string
  source?:   string
  createdAt?: string
  onClick?:  () => void
}

export default function AlertCard({ title, severity, source, createdAt, onClick }: AlertCardProps) {
  const ago = createdAt
    ? formatDistanceToNow(new Date(createdAt), { addSuffix: true })
    : null

  return (
    <div onClick={onClick}
      className="flex items-start gap-3 px-4 py-3 transition-colors cursor-pointer hover:bg-white/[0.03]"
      style={{ borderBottom: '1px solid var(--bg-border)' }}>
      <AlertBadge severity={severity} />
      <div className="flex-1 min-w-0">
        <p className="text-sm text-slate-200 truncate">{title}</p>
        {source && <p className="text-[10px] text-slate-500 mt-0.5">{source}</p>}
      </div>
      {ago && <span className="text-[10px] text-slate-500 shrink-0">{ago}</span>}
    </div>
  )
}
