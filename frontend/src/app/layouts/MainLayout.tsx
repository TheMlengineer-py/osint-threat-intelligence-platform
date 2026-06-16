import React, { useState, useEffect } from 'react'
import { useLocation } from 'react-router-dom'
import Sidebar from './Sidebar'
import TopBar from './TopBar'
import { useAnalyticsSummary, useThreats } from '@/hooks'

const LS_KEY = 'osint_read_alert_ids'

function getUnreadCount(threats: any[]): number {
  try {
    const raw  = localStorage.getItem(LS_KEY)
    const read: Set<string> = raw ? new Set(JSON.parse(raw)) : new Set()
    return threats.filter(
      t => (t.severity === 'critical' || t.severity === 'high') && !read.has(String(t.id))
    ).length
  } catch { return 0 }
}

const PAGE_TITLES: Record<string, { title: string; subtitle: string }> = {
  '/dashboard': { title: 'Dashboard',  subtitle: 'Command Centre Overview' },
  '/threats':   { title: 'Threats',    subtitle: 'View & investigate threats' },
  '/alerts':    { title: 'Alerts',     subtitle: 'Real-time threat notifications' },
  '/entities':  { title: 'Entities',   subtitle: 'People, organisations & indicators' },
  '/reports':   { title: 'Reports',    subtitle: 'Intelligence reports' },
  '/copilot':   { title: 'AI Copilot', subtitle: 'RAG-powered threat assistant' },
  '/analytics': { title: 'Analytics',  subtitle: 'Insights & trend analysis' },
  '/settings':  { title: 'Settings',   subtitle: 'System & user preferences' },
}

export default function MainLayout({ children }: { children: React.ReactNode }) {
  const location = useLocation()
  const page = PAGE_TITLES[location.pathname] ?? { title: 'OSINT', subtitle: 'Threat Intelligence Platform' }

  // Pull threat list to derive unread badge count
  const { data: threats = [] } = useThreats({ limit: 100 } as any)
  const [unreadCount, setUnreadCount] = useState(0)

  // Recompute badge whenever threats load OR localStorage changes (e.g. after Alerts page marks read)
  useEffect(() => {
    setUnreadCount(getUnreadCount(threats as any[]))
  }, [threats, location.pathname])   // re-check on route change so badge updates after visiting Alerts

  return (
    <div style={{ display: 'flex', height: '100vh', overflow: 'hidden', background: 'var(--bg-primary)' }}>
      <Sidebar alertCount={unreadCount} />
      <div style={{ display: 'flex', flexDirection: 'column', flex: 1, minWidth: 0, overflow: 'hidden' }}>
        <TopBar title={page.title} subtitle={page.subtitle} alertCount={unreadCount} />
        <main style={{ flex: 1, overflowY: 'auto', background: 'var(--bg-primary)' }}>
          {children}
        </main>
      </div>
    </div>
  )
}
