import React, { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useTriggerIngestion } from '@/hooks'
import { useTheme } from '@/context/ThemeContext'

interface TopBarProps {
  title?: string
  subtitle?: string
  alertCount?: number
}

export default function TopBar({ title = 'Dashboard', subtitle = 'Overview', alertCount = 0 }: TopBarProps) {
  const navigate = useNavigate()
  const [search, setSearch] = useState('')
  const { mutate: trigger, isPending } = useTriggerIngestion()
  const { theme, toggle } = useTheme()
  const isDark = theme === 'dark'

  return (
    <header style={{
      display: 'flex', alignItems: 'center', gap: 12, padding: '0 24px',
      height: 60, minHeight: 60, flexShrink: 0,
      background: isDark ? 'rgba(10,22,40,.95)' : 'rgba(240,244,248,.97)',
      borderBottom: '1px solid var(--bg-border)',
      position: 'sticky', top: 0, zIndex: 20,
    }}>
      {/* Title */}
      <div style={{ minWidth: 0 }}>
        <div style={{ color: 'var(--ink-primary)', fontSize: 18, fontWeight: 700, lineHeight: 1 }}>{title}</div>
        <div style={{ color: 'var(--ink-muted)', fontSize: 11, marginTop: 2 }}>{subtitle}</div>
      </div>

      <div style={{ flex: 1 }} />

      {/* Search */}
      <div style={{ position: 'relative' }}>
        <span style={{ position: 'absolute', left: 10, top: '50%', transform: 'translateY(-50%)', color: 'var(--ink-muted)', fontSize: 12 }}>🔍</span>
        <input
          type="text"
          placeholder="Search threats…"
          value={search}
          onChange={e => setSearch(e.target.value)}
          style={{
            paddingLeft: 30, paddingRight: 12, paddingTop: 7, paddingBottom: 7,
            background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)',
            borderRadius: 8, color: 'var(--ink-primary)', fontSize: 12,
            outline: 'none', width: 200,
          }}
        />
      </div>

      {/* Dark / Light toggle */}
      <button onClick={toggle} title={isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode'} style={{
        width: 38, height: 38, borderRadius: 8, border: '1px solid var(--bg-border)',
        background: 'var(--bg-elevated)', cursor: 'pointer', fontSize: 18,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        {isDark ? '☀️' : '🌙'}
      </button>

      {/* Refresh / Ingest */}
      <button onClick={() => trigger()} disabled={isPending} style={{
        display: 'flex', alignItems: 'center', gap: 6, padding: '7px 14px',
        background: 'rgba(6,182,212,.15)', border: '1px solid rgba(6,182,212,.4)',
        borderRadius: 8, color: 'var(--cyan)', fontSize: 12, fontWeight: 600,
        cursor: isPending ? 'not-allowed' : 'pointer', opacity: isPending ? 0.6 : 1,
        whiteSpace: 'nowrap',
      }}>
        {isPending ? '⟳' : '↺'} {isPending ? 'Ingesting…' : 'Refresh'}
      </button>

      {/* New Report */}
      <button onClick={() => navigate('/reports')} style={{
        display: 'flex', alignItems: 'center', gap: 6, padding: '7px 14px',
        background: 'var(--cyan)', border: 'none', borderRadius: 8,
        color: '#050c18', fontSize: 12, fontWeight: 700, cursor: 'pointer',
        whiteSpace: 'nowrap',
      }}>
        + New Report
      </button>

      {/* Alerts bell */}
      <button onClick={() => navigate('/alerts')} style={{
        position: 'relative', width: 38, height: 38, background: 'var(--bg-elevated)',
        border: '1px solid var(--bg-border)', borderRadius: 8,
        cursor: 'pointer', fontSize: 16, display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        🔔
        {alertCount > 0 && (
          <span style={{
            position: 'absolute', top: 4, right: 4, minWidth: 14, height: 14,
            background: '#ef4444', color: 'white', fontSize: 9, fontWeight: 700,
            borderRadius: '50%', display: 'flex', alignItems: 'center',
            justifyContent: 'center', padding: '0 2px',
          }}>
            {alertCount > 99 ? '99+' : alertCount}
          </span>
        )}
      </button>
    </header>
  )
}
