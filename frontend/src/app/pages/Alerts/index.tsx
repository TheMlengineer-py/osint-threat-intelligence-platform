import React, { useState } from 'react'
import { useThreats } from '@/hooks'

const SEV_COLOR: Record<string, string> = {
  critical: '#ef4444', high: '#f97316', medium: '#eab308', low: '#22c55e'
}

function timeAgo(iso: string) {
  const m = Math.floor((Date.now() - new Date(iso).getTime()) / 60000)
  if (m < 1) return 'just now'
  if (m < 60) return `${m}m ago`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h}h ago`
  return `${Math.floor(h / 24)}d ago`
}

export default function Alerts() {
  const { data = [], isLoading } = useThreats({ limit: 50 } as any)
  const [readIds, setReadIds] = useState<Set<string>>(new Set())
  const [filter, setFilter] = useState<'all' | 'unread'>('unread')

  const threats = (data as any[]).filter(t =>
    t.severity === 'critical' || t.severity === 'high'
  )

  const displayed = filter === 'unread'
    ? threats.filter(t => !readIds.has(t.id))
    : threats

  const unreadCount = threats.filter(t => !readIds.has(t.id)).length

  const markRead = (id: string) => setReadIds(prev => new Set([...prev, id]))
  const markAllRead = () => setReadIds(new Set(threats.map(t => t.id)))

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 20, maxWidth: 900 }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 12 }}>
        <div>
          <h1 style={{ color: 'var(--ink-primary)', fontSize: 24, fontWeight: 800, margin: 0 }}>Alerts</h1>
          <p style={{ color: 'var(--ink-muted)', fontSize: 13, marginTop: 4 }}>
            Real-time notifications for high and critical severity threats
          </p>
        </div>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          {unreadCount > 0 && (
            <span style={{ padding: '4px 12px', borderRadius: 20, background: 'rgba(239,68,68,0.15)', color: '#ef4444', fontSize: 12, fontWeight: 700, border: '1px solid rgba(239,68,68,0.3)' }}>
              {unreadCount} unread
            </span>
          )}
          {unreadCount > 0 && (
            <button onClick={markAllRead} style={{ padding: '6px 14px', borderRadius: 8, background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)', color: 'var(--ink-secondary)', fontSize: 12, cursor: 'pointer' }}>
              Mark all read
            </button>
          )}
          <div style={{ display: 'flex', borderRadius: 8, overflow: 'hidden', border: '1px solid var(--bg-border)' }}>
            {(['unread', 'all'] as const).map(f => (
              <button key={f} onClick={() => setFilter(f)} style={{
                padding: '6px 14px', fontSize: 12, fontWeight: 500, cursor: 'pointer', textTransform: 'capitalize',
                background: filter === f ? 'rgba(6,182,212,0.15)' : 'var(--bg-elevated)',
                color: filter === f ? 'var(--cyan)' : 'var(--ink-secondary)',
                border: 'none',
              }}>{f === 'unread' ? `Unread (${unreadCount})` : `All (${threats.length})`}</button>
            ))}
          </div>
        </div>
      </div>

      {isLoading ? (
        <div style={{ color: 'var(--ink-muted)', padding: 24 }}>Loading alerts…</div>
      ) : displayed.length === 0 ? (
        <div style={{ padding: 48, textAlign: 'center', background: 'var(--bg-card)', borderRadius: 12, border: '1px solid var(--bg-border)' }}>
          <div style={{ fontSize: 40, marginBottom: 12 }}>✓</div>
          <p style={{ color: 'var(--ink-primary)', fontWeight: 600 }}>All caught up</p>
          <p style={{ color: 'var(--ink-muted)', fontSize: 13, marginTop: 6 }}>
            {filter === 'unread' ? 'No unread alerts — switch to "All" to see history' : 'No critical or high severity threats detected'}
          </p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {displayed.map((t: any) => {
            const isRead = readIds.has(t.id)
            const col = SEV_COLOR[t.severity] ?? '#64748b'
            return (
              <div
                key={t.id}
                onClick={() => markRead(t.id)}
                style={{
                  display: 'flex', alignItems: 'flex-start', gap: 14, padding: '14px 18px',
                  borderRadius: 10, cursor: 'pointer', transition: 'all 0.2s',
                  background: isRead ? 'var(--bg-card)' : `${col}08`,
                  border: `1px solid ${isRead ? 'var(--bg-border)' : col + '44'}`,
                  opacity: isRead ? 0.6 : 1,
                }}
              >
                {/* Unread dot */}
                <div style={{ marginTop: 5, width: 8, height: 8, borderRadius: '50%', background: isRead ? 'transparent' : col, border: isRead ? '1px solid var(--bg-border)' : 'none', flexShrink: 0 }} />

                {/* Severity badge */}
                <span style={{ fontSize: 10, fontWeight: 700, padding: '3px 8px', borderRadius: 4, background: `${col}22`, color: col, textTransform: 'uppercase', flexShrink: 0, marginTop: 2 }}>
                  {t.severity}
                </span>

                {/* Content */}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <p style={{ color: isRead ? 'var(--ink-secondary)' : 'var(--ink-primary)', fontSize: 13, fontWeight: isRead ? 400 : 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {t.title}
                  </p>
                  <div style={{ display: 'flex', gap: 12, marginTop: 5 }}>
                    <span style={{ color: 'var(--ink-muted)', fontSize: 11 }}>{(t.category ?? '').replace(/_/g, ' ')}</span>
                    <span style={{ color: 'var(--ink-muted)', fontSize: 11 }}>{t.source ?? 'OSINT'}</span>
                    <span style={{ color: 'var(--cyan)', fontSize: 11, fontFamily: 'monospace' }}>Risk: {t.risk_score?.toFixed(2) ?? '—'}</span>
                  </div>
                </div>

                <div style={{ textAlign: 'right', flexShrink: 0 }}>
                  <div style={{ color: 'var(--ink-muted)', fontSize: 11 }}>
                    {t.detected_at ? timeAgo(t.detected_at) : '—'}
                  </div>
                  {isRead && <div style={{ color: '#22c55e', fontSize: 10, marginTop: 2 }}>✓ Read</div>}
                  {!isRead && <div style={{ color: 'var(--ink-muted)', fontSize: 10, marginTop: 2 }}>click to dismiss</div>}
                </div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
