import React from 'react'
import { useLocation, useNavigate } from 'react-router-dom'

const NAV = [
  { path: '/dashboard', label: 'Dashboard',  sub: 'Command centre',      icon: '⊞' },
  { path: '/threats',   label: 'Threats',    sub: 'Investigate threats', icon: '🛡' },
  { path: '/alerts',    label: 'Alerts',     sub: 'Real-time feed',      icon: '🔔' },
  { path: '/entities',  label: 'Entities',   sub: 'Orgs & indicators',   icon: '⬡'  },
  { path: '/reports',   label: 'Reports',    sub: 'Intel reports',       icon: '📄' },
  { path: '/copilot',   label: 'AI Copilot', sub: 'Ask anything',        icon: '🤖' },
  { path: '/analytics', label: 'Analytics',  sub: 'Insights & trends',   icon: '📊' },
  { path: '/settings',  label: 'Settings',   sub: 'Preferences',         icon: '⚙' },
]

export default function Sidebar({ alertCount = 0 }: { alertCount?: number }) {
  const location = useLocation()
  const navigate = useNavigate()

  return (
    <aside style={{
      width: 220, minHeight: '100vh', display: 'flex', flexDirection: 'column',
      background: 'var(--bg-secondary)', borderRight: '1px solid var(--bg-border)',
      flexShrink: 0,
    }}>
      {/* Logo */}
      <div style={{ padding: '20px 16px', borderBottom: '1px solid var(--bg-border)', display: 'flex', alignItems: 'center', gap: 12 }}>
        <div style={{ width: 32, height: 32, borderRadius: 6, background: 'rgba(6,182,212,.15)', border: '1px solid rgba(6,182,212,.4)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16 }}>🛡</div>
        <div>
          <div style={{ color: 'var(--cyan)', fontWeight: 700, fontSize: 13, letterSpacing: 2 }}>OSINT</div>
          <div style={{ color: 'var(--ink-muted)', fontSize: 10 }}>Threat Intelligence Platform</div>
        </div>
      </div>

      {/* Nav label */}
      <div style={{ padding: '16px 16px 8px', color: 'var(--ink-muted)', fontSize: 10, fontWeight: 600, letterSpacing: 2, textTransform: 'uppercase' }}>Navigation</div>

      {/* Nav items */}
      <nav style={{ flex: 1, padding: '0 8px', display: 'flex', flexDirection: 'column', gap: 2 }}>
        {NAV.map(({ path, label, sub, icon }) => {
          const active = location.pathname === path
          const isAlerts = path === '/alerts' && alertCount > 0
          return (
            <button key={path} onClick={() => navigate(path)} style={{
              display: 'flex', alignItems: 'center', gap: 12, width: '100%',
              padding: '10px 12px', borderRadius: 8, border: active ? '1px solid rgba(6,182,212,.25)' : '1px solid transparent',
              background: active ? 'rgba(6,182,212,.12)' : 'transparent',
              cursor: 'pointer', textAlign: 'left',
            }}>
              <span style={{ fontSize: 15, width: 20, textAlign: 'center' }}>{icon}</span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ color: active ? 'var(--cyan)' : '#cbd5e1', fontSize: 13, fontWeight: 500, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{label}</div>
                <div style={{ color: 'var(--ink-muted)', fontSize: 10, marginTop: 1 }}>{sub}</div>
              </div>
              {isAlerts && (
                <span style={{ background: 'rgba(239,68,68,.2)', color: '#ef4444', fontSize: 10, fontWeight: 700, padding: '1px 5px', borderRadius: 4, border: '1px solid rgba(239,68,68,.3)' }}>
                  {alertCount > 99 ? '99+' : alertCount}
                </span>
              )}
            </button>
          )
        })}
      </nav>

      {/* Footer */}
      <div style={{ padding: '12px 16px', borderTop: '1px solid var(--bg-border)', display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ width: 28, height: 28, borderRadius: '50%', background: 'rgba(6,182,212,.2)', color: 'var(--cyan)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12, fontWeight: 700, flexShrink: 0 }}>A</div>
        <div style={{ minWidth: 0 }}>
          <div style={{ color: 'var(--ink-primary)', fontSize: 12, fontWeight: 500 }}>Analyst</div>
          <div style={{ color: 'var(--ink-muted)', fontSize: 10 }}>Analyst</div>
        </div>
        <div style={{ width: 8, height: 8, borderRadius: '50%', background: '#22c55e', marginLeft: 'auto', flexShrink: 0 }} />
      </div>
    </aside>
  )
}
