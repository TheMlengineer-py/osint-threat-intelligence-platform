import React from 'react'
import { useLocation } from 'react-router-dom'
import Sidebar from './Sidebar'
import TopBar from './TopBar'
import { useAnalyticsSummary } from '@/hooks'

const PAGE_TITLES: Record<string, { title: string; subtitle: string }> = {
  '/dashboard': { title: 'Dashboard',   subtitle: 'Command Centre Overview' },
  '/threats':   { title: 'Threats',     subtitle: 'View & investigate threats' },
  '/alerts':    { title: 'Alerts',      subtitle: 'Real-time threat notifications' },
  '/entities':  { title: 'Entities',    subtitle: 'People, organisations & indicators' },
  '/reports':   { title: 'Reports',     subtitle: 'Intelligence reports' },
  '/copilot':   { title: 'AI Copilot',  subtitle: 'RAG-powered threat assistant' },
  '/analytics': { title: 'Analytics',   subtitle: 'Insights & trend analysis' },
  '/settings':  { title: 'Settings',    subtitle: 'System & user preferences' },
}

export default function MainLayout({ children }: { children: React.ReactNode }) {
  const location = useLocation()
  const page = PAGE_TITLES[location.pathname] ?? { title: 'OSINT', subtitle: 'Threat Intelligence Platform' }
  const { data: analytics } = useAnalyticsSummary()
  const alertCount = analytics?.critical_threats ?? 0

  return (
    <div style={{ display: 'flex', height: '100vh', overflow: 'hidden', background: 'var(--bg-primary)' }}>
      <Sidebar alertCount={alertCount} />
      <div style={{ display: 'flex', flexDirection: 'column', flex: 1, minWidth: 0, overflow: 'hidden' }}>
        <TopBar title={page.title} subtitle={page.subtitle} alertCount={alertCount} />
        <main style={{ flex: 1, overflowY: 'auto', background: 'var(--bg-primary)' }}>
          {children}
        </main>
      </div>
    </div>
  )
}
