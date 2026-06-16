#!/usr/bin/env bash
# =============================================================================
# OSINT Platform — Frontend Bug Fix Script
# Fixes: threat filter counts, alerts persistence, search, entities URL,
#        world map live data, entities IOC extraction, sidebar badge wiring,
#        dashboard duplicate hotspot stats
#
# Run from repo root:
#   bash apply_fixes.sh
# =============================================================================
set -euo pipefail

REPO="/mnt/c/Users/playground/OSINT/osint-threat-intelligence-platform"
FE="$REPO/frontend/src/app"

echo ""
echo "=========================================="
echo " OSINT Frontend Fix — $(date '+%Y-%m-%d %H:%M')"
echo "=========================================="
echo ""

# ── Guard: must be run from repo root or we set the path above ────────────────
if [[ ! -d "$REPO/frontend" ]]; then
  echo "ERROR: Cannot find repo at $REPO"
  echo "Edit the REPO variable at the top of this script."
  exit 1
fi

# =============================================================================
# FIX 1 — entities.ts  (double /api/v1 prefix bug)
# =============================================================================
echo "[1/7] Fixing entities service — removing duplicate /api/v1 prefix..."
cat > "$FE/services/entities.ts" << 'ENTITIES_EOF'
/**
 * Entities API service.
 * apiClient.baseURL is already ${BASE_URL}/api/v1
 * so all paths here must NOT include /api/v1 again.
 */
import { apiClient } from './api'
import type { EntityType } from '../types'

export const entitiesService = {
  list: (entityType?: EntityType, limit = 50) =>
    apiClient
      .get('/entities/', {
        params: { ...(entityType && { entity_type: entityType }), limit },
      })
      .then(r => r.data),

  graph: (limit = 60) =>
    apiClient
      .get('/entities/graph', { params: { limit } })
      .then(r => r.data),
}
ENTITIES_EOF
echo "    Done."

# =============================================================================
# FIX 2 — Threats/index.tsx
#   • Fetch ALL threats once (limit 200, no severity param)
#   • Filter client-side so counts per severity button are accurate
#   • Read ?search= from URL params so TopBar search works
# =============================================================================
echo "[2/7] Fixing Threats page — client-side filtering + search param support..."
cat > "$FE/pages/Threats/index.tsx" << 'THREATS_EOF'
import React, { useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useThreats } from '@/hooks'

const SEV_COLOR: Record<string, string> = {
  critical: '#ef4444', high: '#f97316', medium: '#eab308', low: '#22c55e',
}
const card = {
  background: 'rgba(255,255,255,0.03)',
  border: '1px solid rgba(255,255,255,0.08)',
  borderRadius: 12,
}

export default function Threats() {
  // Severity UI filter (local)
  const [severity, setSeverity] = useState<string>('')

  // Search comes from URL ?search= (set by TopBar) OR local state fallback
  const [searchParams] = useSearchParams()
  const urlSearch = searchParams.get('search') ?? ''

  // Always fetch ALL threats client-side (limit 200, no server-side severity filter)
  const { data = [], isLoading, refetch } = useThreats({ limit: 200 } as any)
  const all = data as any[]

  // Derive per-severity counts from the full set
  const counts: Record<string, number> = {
    critical: all.filter(t => t.severity === 'critical').length,
    high:     all.filter(t => t.severity === 'high').length,
    medium:   all.filter(t => t.severity === 'medium').length,
    low:      all.filter(t => t.severity === 'low').length,
  }

  // Apply client-side filters
  const threats = all.filter(t => {
    const matchSev    = !severity || t.severity === severity
    const matchSearch = !urlSearch || (
      (t.title ?? '').toLowerCase().includes(urlSearch.toLowerCase()) ||
      (t.summary ?? '').toLowerCase().includes(urlSearch.toLowerCase()) ||
      (t.category ?? '').toLowerCase().includes(urlSearch.toLowerCase())
    )
    return matchSev && matchSearch
  })

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 20 }}>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 12 }}>
        <div>
          <h1 style={{ color: 'white', fontSize: 24, fontWeight: 700 }}>Threats</h1>
          <p style={{ color: 'var(--ink-muted)', fontSize: 13, marginTop: 4 }}>
            {threats.length} of {all.length} threats
            {severity ? ` · filtered: ${severity}` : ''}
            {urlSearch ? ` · search: "${urlSearch}"` : ''}
          </p>
        </div>
        <button
          onClick={() => refetch()}
          style={{ padding: '8px 16px', background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 8, color: '#cbd5e1', cursor: 'pointer', fontSize: 13 }}
        >
          ↺ Refresh
        </button>
      </div>

      {/* Severity filter buttons with accurate counts */}
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        {(['', 'critical', 'high', 'medium', 'low'] as const).map(s => {
          const active = severity === s
          const label  = s ? `${s.charAt(0).toUpperCase()}${s.slice(1)} (${counts[s] ?? 0})` : `All (${all.length})`
          return (
            <button
              key={s}
              onClick={() => setSeverity(s)}
              style={{
                padding: '6px 14px', borderRadius: 20, fontSize: 12, fontWeight: 500,
                cursor: 'pointer', textTransform: 'capitalize',
                background: active ? 'rgba(6,182,212,.2)' : 'rgba(255,255,255,0.05)',
                border: active ? '1px solid rgba(6,182,212,.4)' : '1px solid rgba(255,255,255,0.08)',
                color: s ? SEV_COLOR[s] : 'var(--cyan)',
              }}
            >
              {label}
            </button>
          )
        })}
      </div>

      {/* Threat table */}
      {isLoading ? (
        <p style={{ color: 'var(--ink-muted)' }}>Loading…</p>
      ) : threats.length === 0 ? (
        <div style={{ ...card, padding: 40, textAlign: 'center', color: 'var(--ink-muted)' }}>
          {urlSearch
            ? `No threats matching "${urlSearch}". Try a different search term.`
            : 'No threats found. Click Refresh to trigger ingestion.'}
        </div>
      ) : (
        <div style={{ ...card, overflow: 'hidden' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead>
              <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.08)' }}>
                {['Severity', 'Title', 'Category', 'Source', 'Risk Score', 'Detected'].map(h => (
                  <th key={h} style={{ padding: '12px 16px', textAlign: 'left', color: 'var(--ink-muted)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: 1 }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {threats.map((t: any, i: number) => (
                <tr key={t.id ?? i} style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                  <td style={{ padding: '12px 16px' }}>
                    <span style={{ background: `${SEV_COLOR[t.severity] ?? '#64748b'}22`, color: SEV_COLOR[t.severity] ?? '#64748b', fontSize: 10, fontWeight: 700, padding: '3px 8px', borderRadius: 4, textTransform: 'uppercase' }}>
                      {t.severity}
                    </span>
                  </td>
                  <td style={{ padding: '12px 16px', color: '#e2e8f0', maxWidth: 300, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{t.title}</td>
                  <td style={{ padding: '12px 16px', color: 'var(--ink-secondary)', whiteSpace: 'nowrap' }}>{(t.category ?? '').replace(/_/g, ' ')}</td>
                  <td style={{ padding: '12px 16px', color: 'var(--ink-muted)', whiteSpace: 'nowrap' }}>{t.source ?? '—'}</td>
                  <td style={{ padding: '12px 16px' }}>
                    <span style={{ color: 'var(--cyan)', fontFamily: 'monospace', fontWeight: 600 }}>{t.risk_score?.toFixed(2) ?? '—'}</span>
                  </td>
                  <td style={{ padding: '12px 16px', color: 'var(--ink-muted)', whiteSpace: 'nowrap', fontSize: 12 }}>
                    {t.detected_at ? new Date(t.detected_at).toLocaleDateString('en-GB') : '—'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
THREATS_EOF
echo "    Done."

# =============================================================================
# FIX 3 — Alerts/index.tsx
#   • Persist readIds to localStorage so state survives navigation
#   • Sidebar badge reflects unread count (not total critical count)
#   • Removed ORG tab from entities (not significantly populating)
# =============================================================================
echo "[3/7] Fixing Alerts page — localStorage persistence..."
cat > "$FE/pages/Alerts/index.tsx" << 'ALERTS_EOF'
import React, { useState, useCallback } from 'react'
import { useThreats } from '@/hooks'

const SEV_COLOR: Record<string, string> = {
  critical: '#ef4444', high: '#f97316', medium: '#eab308', low: '#22c55e',
}

const LS_KEY = 'osint_read_alert_ids'

function loadReadIds(): Set<string> {
  try {
    const raw = localStorage.getItem(LS_KEY)
    return raw ? new Set(JSON.parse(raw) as string[]) : new Set()
  } catch { return new Set() }
}

function saveReadIds(ids: Set<string>) {
  try { localStorage.setItem(LS_KEY, JSON.stringify([...ids])) } catch { /* ignore */ }
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
  const { data = [], isLoading } = useThreats({ limit: 100 } as any)

  // Persist read state across navigation via localStorage
  const [readIds, setReadIds] = useState<Set<string>>(loadReadIds)
  const [filter, setFilter]   = useState<'all' | 'unread'>('unread')

  const threats = (data as any[]).filter(
    t => t.severity === 'critical' || t.severity === 'high'
  )

  const unreadCount = threats.filter(t => !readIds.has(String(t.id))).length
  const displayed   = filter === 'unread'
    ? threats.filter(t => !readIds.has(String(t.id)))
    : threats

  const markRead = useCallback((id: string) => {
    setReadIds(prev => {
      const next = new Set([...prev, id])
      saveReadIds(next)
      return next
    })
  }, [])

  const markAllRead = useCallback(() => {
    const next = new Set(threats.map(t => String(t.id)))
    setReadIds(next)
    saveReadIds(next)
  }, [threats])

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
        <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
          {unreadCount > 0 && (
            <span style={{ padding: '4px 12px', borderRadius: 20, background: 'rgba(239,68,68,0.15)', color: '#ef4444', fontSize: 12, fontWeight: 700, border: '1px solid rgba(239,68,68,0.3)' }}>
              {unreadCount} unread
            </span>
          )}
          {unreadCount > 0 && (
            <button
              onClick={markAllRead}
              style={{ padding: '6px 14px', borderRadius: 8, background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)', color: 'var(--ink-secondary)', fontSize: 12, cursor: 'pointer' }}
            >
              Mark all read
            </button>
          )}
          <div style={{ display: 'flex', borderRadius: 8, overflow: 'hidden', border: '1px solid var(--bg-border)' }}>
            {(['unread', 'all'] as const).map(f => (
              <button
                key={f}
                onClick={() => setFilter(f)}
                style={{
                  padding: '6px 14px', fontSize: 12, fontWeight: 500, cursor: 'pointer',
                  background: filter === f ? 'rgba(6,182,212,0.15)' : 'var(--bg-elevated)',
                  color: filter === f ? 'var(--cyan)' : 'var(--ink-secondary)',
                  border: 'none',
                }}
              >
                {f === 'unread' ? `Unread (${unreadCount})` : `All (${threats.length})`}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Body */}
      {isLoading ? (
        <div style={{ color: 'var(--ink-muted)', padding: 24 }}>Loading alerts…</div>
      ) : displayed.length === 0 ? (
        <div style={{ padding: 48, textAlign: 'center', background: 'var(--bg-card)', borderRadius: 12, border: '1px solid var(--bg-border)' }}>
          <div style={{ fontSize: 40, marginBottom: 12 }}>✓</div>
          <p style={{ color: 'var(--ink-primary)', fontWeight: 600 }}>All caught up</p>
          <p style={{ color: 'var(--ink-muted)', fontSize: 13, marginTop: 6 }}>
            {filter === 'unread'
              ? 'No unread alerts — switch to "All" to see history'
              : 'No critical or high severity threats detected'}
          </p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {displayed.map((t: any) => {
            const id    = String(t.id)
            const isRead = readIds.has(id)
            const col   = SEV_COLOR[t.severity] ?? '#64748b'
            return (
              <div
                key={id}
                onClick={() => markRead(id)}
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
                  {isRead
                    ? <div style={{ color: '#22c55e', fontSize: 10, marginTop: 2 }}>✓ Read</div>
                    : <div style={{ color: 'var(--ink-muted)', fontSize: 10, marginTop: 2 }}>click to dismiss</div>}
                </div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
ALERTS_EOF
echo "    Done."

# =============================================================================
# FIX 4 — MainLayout.tsx
#   • alertCount = UNREAD count (from localStorage) not total critical threats
#   • This makes the sidebar badge reflect actual unread alerts
# =============================================================================
echo "[4/7] Fixing MainLayout — unread alert badge count..."
cat > "$FE/layouts/MainLayout.tsx" << 'MAIN_EOF'
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
MAIN_EOF
echo "    Done."

# =============================================================================
# FIX 5 — TopBar.tsx
#   • Search navigates to /threats?search=<query> on Enter key press
# =============================================================================
echo "[5/7] Fixing TopBar — wiring search to navigate..."
cat > "$FE/layouts/TopBar.tsx" << 'TOPBAR_EOF'
import React, { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useTriggerIngestion } from '@/hooks'
import { useTheme } from '@/context/ThemeContext'

interface TopBarProps {
  title?:      string
  subtitle?:   string
  alertCount?: number
}

export default function TopBar({ title = 'Dashboard', subtitle = 'Overview', alertCount = 0 }: TopBarProps) {
  const navigate              = useNavigate()
  const [search, setSearch]   = useState('')
  const { mutate: trigger, isPending } = useTriggerIngestion()
  const { theme, toggle }     = useTheme()
  const isDark                = theme === 'dark'

  const handleSearch = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key !== 'Enter') return
    const q = search.trim()
    if (q) {
      navigate(`/threats?search=${encodeURIComponent(q)}`)
    } else {
      navigate('/threats')
    }
  }

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

      {/* Search — press Enter to navigate to /threats?search=... */}
      <div style={{ position: 'relative' }}>
        <span style={{ position: 'absolute', left: 10, top: '50%', transform: 'translateY(-50%)', color: 'var(--ink-muted)', fontSize: 12, pointerEvents: 'none' }}>🔍</span>
        <input
          type="text"
          placeholder="Search threats…"
          value={search}
          onChange={e => setSearch(e.target.value)}
          onKeyDown={handleSearch}
          style={{
            paddingLeft: 30, paddingRight: 12, paddingTop: 7, paddingBottom: 7,
            background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)',
            borderRadius: 8, color: 'var(--ink-primary)', fontSize: 12,
            outline: 'none', width: 200,
          }}
        />
      </div>

      {/* Dark / Light toggle */}
      <button
        onClick={toggle}
        title={isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode'}
        style={{ width: 38, height: 38, borderRadius: 8, border: '1px solid var(--bg-border)', background: 'var(--bg-elevated)', cursor: 'pointer', fontSize: 18, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
      >
        {isDark ? '☀️' : '🌙'}
      </button>

      {/* Refresh / Ingest */}
      <button
        onClick={() => trigger()}
        disabled={isPending}
        style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '7px 14px', background: 'rgba(6,182,212,.15)', border: '1px solid rgba(6,182,212,.4)', borderRadius: 8, color: 'var(--cyan)', fontSize: 12, fontWeight: 600, cursor: isPending ? 'not-allowed' : 'pointer', opacity: isPending ? 0.6 : 1, whiteSpace: 'nowrap' }}
      >
        {isPending ? '⟳' : '↺'} {isPending ? 'Ingesting…' : 'Refresh'}
      </button>

      {/* New Report */}
      <button
        onClick={() => navigate('/reports')}
        style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '7px 14px', background: 'var(--cyan)', border: 'none', borderRadius: 8, color: '#050c18', fontSize: 12, fontWeight: 700, cursor: 'pointer', whiteSpace: 'nowrap' }}
      >
        + New Report
      </button>

      {/* Alerts bell with UNREAD badge */}
      <button
        onClick={() => navigate('/alerts')}
        style={{ position: 'relative', width: 38, height: 38, background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)', borderRadius: 8, cursor: 'pointer', fontSize: 16, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
      >
        🔔
        {alertCount > 0 && (
          <span style={{ position: 'absolute', top: 4, right: 4, minWidth: 14, height: 14, background: '#ef4444', color: 'white', fontSize: 9, fontWeight: 700, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '0 2px' }}>
            {alertCount > 99 ? '99+' : alertCount}
          </span>
        )}
      </button>
    </header>
  )
}
TOPBAR_EOF
echo "    Done."

# =============================================================================
# FIX 6 — Entities/index.tsx
#   • Extended IOC extraction: IPs and domains parsed from text + source_url
#   • MD5/SHA256 hash regex added
#   • Removed ORG tab (never populates — no NLP entity extraction at source)
#   • Kept CVE, IP, DOMAIN, HASH
# =============================================================================
echo "[6/7] Fixing Entities page — richer IOC extraction, removed ORG tab..."
cat > "$FE/pages/Entities/index.tsx" << 'ENTITIES_PAGE_EOF'
import React, { useState } from 'react'
import { useThreats } from '@/hooks'

type EntityType = 'ALL' | 'CVE' | 'IP' | 'DOMAIN' | 'HASH'

const TYPE_CFG: Record<EntityType, { color: string; label: string }> = {
  ALL:    { color: 'var(--cyan)', label: 'All' },
  CVE:    { color: '#ef4444',     label: 'CVEs' },
  IP:     { color: '#f97316',     label: 'IPs' },
  DOMAIN: { color: '#eab308',     label: 'Domains' },
  HASH:   { color: '#94a3b8',     label: 'Hashes' },
}

// Private IP ranges to exclude
const PRIVATE_IP = /^(10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.|127\.|0\.0\.0\.0|255\.)/

function extractIOCs(threats: any[]) {
  const map = new Map<string, { value: string; type: string; count: number; threat: string }>()

  const add = (type: string, value: string, title: string) => {
    const k = `${type}:${value}`
    const e = map.get(k)
    if (e) e.count++
    else map.set(k, { value, type, count: 1, threat: title })
  }

  threats.forEach(t => {
    const title  = t.title   ?? ''
    const summary = t.summary ?? ''
    const text   = `${title} ${summary}`
    const src    = t.source_url ?? ''

    // ── CVEs ──────────────────────────────────────────────────────────────
    const cves = text.match(/CVE-\d{4}-\d{4,7}/gi) ?? []
    cves.forEach(c => add('CVE', c.toUpperCase(), title))

    // ── IPs (public only) ─────────────────────────────────────────────────
    const ips = text.match(/\b(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\b/g) ?? []
    ips.forEach(ip => { if (!PRIVATE_IP.test(ip)) add('IP', ip, title) })

    // ── Domains from source_url ───────────────────────────────────────────
    if (src) {
      try {
        const host = new URL(src).hostname.replace(/^www\./, '')
        if (host && host.includes('.') && !host.match(/^\d+\.\d+/)) {
          add('DOMAIN', host, title)
        }
      } catch { /* invalid URL */ }
    }
    // Also catch domain-like patterns from text (foo.com / foo.net / foo.org)
    const domainRe = /\b(?!CVE)[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.(?:com|net|org|io|gov|edu|co\.uk|ru|cn|de|ir)\b/gi
    const textDomains = text.match(domainRe) ?? []
    textDomains.forEach(d => add('DOMAIN', d.toLowerCase(), title))

    // ── MD5 / SHA-1 / SHA-256 hashes ─────────────────────────────────────
    const hashes = text.match(/\b[a-f0-9]{32}\b|\b[a-f0-9]{40}\b|\b[a-f0-9]{64}\b/gi) ?? []
    hashes.forEach(h => add('HASH', h.toLowerCase(), title))

    // ── IOCs from structured iocs array (if backend populates it) ────────
    const iocs: any[] = Array.isArray(t.indicators_of_compromise) ? t.indicators_of_compromise
                      : Array.isArray(t.iocs) ? t.iocs : []
    iocs.forEach((ioc: any) => {
      if (!ioc?.value || !ioc?.type) return
      const type = String(ioc.type).toUpperCase()
      if (['CVE','IP','DOMAIN','HASH'].includes(type)) {
        add(type, String(ioc.value), title)
      }
    })
  })

  return Array.from(map.values()).sort((a, b) => b.count - a.count)
}

export default function Entities() {
  const { data = [], isLoading, isError } = useThreats({ limit: 200 } as any)
  const [active, setActive]   = useState<EntityType>('ALL')
  const [search, setSearch]   = useState('')

  const threats  = Array.isArray(data) ? (data as any[]) : []
  const entities = extractIOCs(threats)

  const counts = Object.fromEntries(
    (Object.keys(TYPE_CFG) as EntityType[]).map(t => [
      t, t === 'ALL' ? entities.length : entities.filter(e => e.type === t).length,
    ])
  ) as Record<EntityType, number>

  const filtered = entities.filter(e => {
    const matchType   = active === 'ALL' || e.type === active
    const matchSearch = !search || e.value.toLowerCase().includes(search.toLowerCase())
    return matchType && matchSearch
  })

  if (isLoading) return (
    <div style={{ padding: 32, display: 'flex', alignItems: 'center', gap: 12, color: 'var(--ink-secondary)' }}>
      <div style={{ width: 20, height: 20, border: '2px solid var(--cyan)', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
      Extracting entities from threat data…
    </div>
  )

  if (isError) return (
    <div style={{ padding: 32, color: '#ef4444' }}>Unable to load threat data for entity extraction.</div>
  )

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 20, maxWidth: 1200 }}>
      {/* Header */}
      <div>
        <h1 style={{ color: 'var(--ink-primary)', fontSize: 24, fontWeight: 800, margin: 0 }}>Entities</h1>
        <p style={{ color: 'var(--ink-muted)', fontSize: 13, marginTop: 4 }}>
          Indicators of Compromise (IOCs) extracted from {threats.length} threat records
        </p>
      </div>

      {threats.length === 0 ? (
        <div style={{ padding: 48, textAlign: 'center', background: 'var(--bg-card)', borderRadius: 12, border: '1px solid var(--bg-border)' }}>
          <div style={{ fontSize: 40, marginBottom: 12 }}>🔍</div>
          <p style={{ color: 'var(--ink-primary)', fontWeight: 600 }}>No entity data yet</p>
          <p style={{ color: 'var(--ink-muted)', fontSize: 13, marginTop: 6 }}>
            Trigger ingestion on the Dashboard to populate threat intelligence data.
          </p>
        </div>
      ) : (
        <>
          {/* Stat tiles — CVE / IP / DOMAIN / HASH only */}
          <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
            {(['CVE','IP','DOMAIN','HASH'] as EntityType[]).map(type => {
              const { color, label } = TYPE_CFG[type]
              return (
                <div
                  key={type}
                  onClick={() => setActive(type)}
                  style={{ flex: '1 1 80px', padding: '14px 16px', borderRadius: 10, cursor: 'pointer', transition: 'all 0.15s', background: active === type ? `${color}15` : 'var(--bg-card)', border: `1px solid ${active === type ? color + '55' : 'var(--bg-border)'}` }}
                >
                  <div style={{ color, fontSize: 22, fontWeight: 800, fontFamily: 'monospace' }}>{counts[type]}</div>
                  <div style={{ color: 'var(--ink-muted)', fontSize: 11, marginTop: 3 }}>{label}</div>
                </div>
              )
            })}
          </div>

          {/* Filter bar */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
            <div style={{ display: 'flex', gap: 6 }}>
              {(Object.keys(TYPE_CFG) as EntityType[]).map(t => (
                <button
                  key={t}
                  onClick={() => setActive(t)}
                  style={{ padding: '5px 12px', borderRadius: 20, fontSize: 11, fontWeight: 600, cursor: 'pointer', background: active === t ? `${TYPE_CFG[t].color}20` : 'var(--bg-elevated)', border: `1px solid ${active === t ? TYPE_CFG[t].color + '50' : 'var(--bg-border)'}`, color: active === t ? TYPE_CFG[t].color : 'var(--ink-secondary)' }}
                >
                  {t} {counts[t] > 0 ? `(${counts[t]})` : ''}
                </button>
              ))}
            </div>
            <input
              placeholder="Search by value…"
              value={search}
              onChange={e => setSearch(e.target.value)}
              style={{ marginLeft: 'auto', padding: '6px 14px', borderRadius: 8, fontSize: 12, background: 'var(--bg-elevated)', border: '1px solid var(--bg-border)', color: 'var(--ink-primary)', outline: 'none', width: 200 }}
            />
          </div>

          {/* Table */}
          {filtered.length === 0 ? (
            <div style={{ padding: 32, textAlign: 'center', background: 'var(--bg-card)', borderRadius: 12, border: '1px solid var(--bg-border)', color: 'var(--ink-muted)' }}>
              No {active !== 'ALL' ? active : ''} entities found{search ? ` matching "${search}"` : ''}
            </div>
          ) : (
            <div style={{ background: 'var(--bg-card)', border: '1px solid var(--bg-border)', borderRadius: 12, overflow: 'hidden' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '100px 1fr 80px 1fr', padding: '10px 20px', background: 'var(--bg-elevated)', borderBottom: '1px solid var(--bg-border)' }}>
                {['Type','Value','Count','Seen In'].map(h => (
                  <div key={h} style={{ color: 'var(--ink-muted)', fontSize: 10, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 1 }}>{h}</div>
                ))}
              </div>
              <div style={{ maxHeight: 480, overflowY: 'auto' }}>
                {filtered.slice(0, 300).map((e, i) => {
                  const cfg = TYPE_CFG[e.type as EntityType] ?? TYPE_CFG.ALL
                  return (
                    <div key={i} style={{ display: 'grid', gridTemplateColumns: '100px 1fr 80px 1fr', padding: '10px 20px', borderBottom: '1px solid rgba(255,255,255,0.04)', alignItems: 'center' }}>
                      <span style={{ fontSize: 10, fontWeight: 700, padding: '2px 8px', borderRadius: 4, background: `${cfg.color}18`, color: cfg.color, textTransform: 'uppercase', display: 'inline-block', width: 'fit-content' }}>{e.type}</span>
                      <span style={{ color: 'var(--ink-primary)', fontSize: 12, fontFamily: 'monospace', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', paddingRight: 12 }}>{e.value}</span>
                      <span style={{ textAlign: 'center' }}>
                        <span style={{ background: 'rgba(6,182,212,0.12)', color: 'var(--cyan)', fontSize: 11, fontWeight: 700, padding: '2px 8px', borderRadius: 10 }}>{e.count}</span>
                      </span>
                      <span style={{ color: 'var(--ink-muted)', fontSize: 11, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{e.threat.substring(0, 45)}</span>
                    </div>
                  )
                })}
              </div>
              <div style={{ padding: '10px 20px', borderTop: '1px solid var(--bg-border)', background: 'var(--bg-elevated)' }}>
                <span style={{ color: 'var(--ink-muted)', fontSize: 11 }}>
                  {Math.min(filtered.length, 300)} of {filtered.length} entities · from {threats.length} threats
                </span>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  )
}
ENTITIES_PAGE_EOF
echo "    Done."

# =============================================================================
# FIX 7 — WorldThreatMap.tsx + Dashboard/index.tsx
#   • WorldThreatMap accepts analyticsData prop → maps by_source to regions
#   • Falls back to static counts if no real data yet
#   • Dashboard passes analytics data to WorldThreatMap
#   • Dashboard removes its own duplicate HOTSPOTS stat row
# =============================================================================
echo "[7/7] Fixing WorldThreatMap (live data) and Dashboard (remove duplicate stats)..."

cat > "$FE/components/charts/WorldThreatMap.tsx" << 'WORLDMAP_EOF'
/**
 * WorldThreatMap — SVG world map with threat hotspot overlays.
 * When analyticsData (by_source) is provided, hotspot counts reflect real data.
 * Falls back to default weights when no data is available yet.
 */
import React, { useState } from 'react'

interface Hotspot {
  name:        string
  x:           number
  y:           number
  baseCount:   number  // fallback / minimum
  color:       string
  sourceKeys:  string[]  // keys to look for in by_source
}

// Source key mappings to geographic regions
const HOTSPOT_DEFS: Hotspot[] = [
  { name: 'United States',  x: 195, y: 195, baseCount: 5,  color: '#ef4444', sourceKeys: ['bleeping_computer','securityweek','uscert','cisa','us-cert'] },
  { name: 'United Kingdom', x: 455, y: 145, baseCount: 3,  color: '#ef4444', sourceKeys: ['uk','ncsc','bbc'] },
  { name: 'Germany',        x: 490, y: 148, baseCount: 2,  color: '#f97316', sourceKeys: ['de','bsi','heise'] },
  { name: 'Russia',         x: 620, y: 120, baseCount: 4,  color: '#ef4444', sourceKeys: ['ru','russia','apt'] },
  { name: 'China',          x: 750, y: 200, baseCount: 4,  color: '#f97316', sourceKeys: ['cn','china','chinese'] },
  { name: 'Iran',           x: 580, y: 215, baseCount: 3,  color: '#f97316', sourceKeys: ['ir','iran','iranian'] },
  { name: 'North Korea',    x: 790, y: 185, baseCount: 2,  color: '#eab308', sourceKeys: ['dprk','lazarus','north korea'] },
  { name: 'Brazil',         x: 270, y: 320, baseCount: 1,  color: '#22c55e', sourceKeys: ['br','brazil'] },
  { name: 'India',          x: 655, y: 235, baseCount: 2,  color: '#eab308', sourceKeys: ['in','india','cert-in'] },
  { name: 'Nigeria',        x: 487, y: 295, baseCount: 1,  color: '#22c55e', sourceKeys: ['ng','nigeria'] },
]

const LAND_PATHS = [
  { d: "M 85 100 L 270 85 L 310 95 L 330 130 L 310 195 L 290 240 L 245 265 L 200 260 L 170 240 L 145 200 L 120 170 L 95 140 Z", id: "north-america" },
  { d: "M 215 270 L 300 260 L 325 280 L 335 360 L 305 430 L 265 450 L 235 430 L 215 380 L 205 320 Z", id: "south-america" },
  { d: "M 430 100 L 540 95 L 560 115 L 555 150 L 520 165 L 480 170 L 450 160 L 430 140 Z", id: "europe" },
  { d: "M 470 70 L 510 65 L 520 90 L 490 100 L 465 95 Z", id: "scandinavia" },
  { d: "M 445 195 L 560 190 L 575 260 L 570 360 L 530 420 L 480 430 L 440 400 L 425 320 L 430 250 Z", id: "africa" },
  { d: "M 530 70 L 870 60 L 880 130 L 820 155 L 720 160 L 640 150 L 570 130 L 540 100 Z", id: "russia" },
  { d: "M 555 175 L 630 170 L 640 215 L 610 230 L 570 225 L 548 205 Z", id: "middle-east" },
  { d: "M 630 175 L 830 170 L 845 240 L 800 265 L 730 270 L 665 255 L 635 225 Z", id: "south-asia" },
  { d: "M 760 130 L 870 125 L 880 180 L 845 200 L 790 195 L 755 170 Z", id: "east-asia" },
  { d: "M 770 320 L 890 310 L 900 395 L 855 420 L 785 415 L 755 375 Z", id: "australia" },
  { d: "M 350 50 L 420 45 L 430 80 L 395 95 L 355 85 Z", id: "greenland" },
  { d: "M 835 165 L 855 160 L 862 180 L 845 188 L 832 178 Z", id: "japan" },
  { d: "M 440 120 L 465 115 L 468 138 L 448 142 Z", id: "uk" },
  { d: "M 770 290 L 870 285 L 875 310 L 830 318 L 780 312 Z", id: "indonesia" },
]

interface Props {
  bySource?: Record<string, number>   // analytics.by_source from API
}

function buildHotspots(bySource?: Record<string, number>) {
  if (!bySource || Object.keys(bySource).length === 0) {
    // No real data yet — use base counts
    return HOTSPOT_DEFS.map(h => ({ ...h, count: h.baseCount }))
  }

  const srcLower: Record<string, number> = {}
  Object.entries(bySource).forEach(([k, v]) => { srcLower[k.toLowerCase()] = v })

  return HOTSPOT_DEFS.map(h => {
    let total = h.baseCount
    h.sourceKeys.forEach(key => {
      Object.entries(srcLower).forEach(([src, cnt]) => {
        if (src.includes(key) || key.includes(src)) total += cnt
      })
    })
    return { ...h, count: total }
  })
}

export function WorldThreatMap({ bySource }: Props) {
  const [hovered, setHovered] = useState<string | null>(null)
  const hotspots = buildHotspots(bySource)
  const top = hotspots.reduce((a, b) => a.count > b.count ? a : b, hotspots[0])
  const isLive = bySource && Object.keys(bySource).length > 0

  return (
    <div style={{ position: 'relative' }}>
      {/* Stats row */}
      <div style={{ display: 'flex', justifyContent: 'flex-end', alignItems: 'center', gap: 24, marginBottom: 8, fontSize: 11, color: 'var(--ink-muted)' }}>
        {isLive && (
          <span style={{ color: '#22c55e', fontWeight: 600, fontSize: 10 }}>● Live data</span>
        )}
        <span>Total hotspots: <strong style={{ color: 'var(--cyan)' }}>{hotspots.length}</strong></span>
        <span>Most active: <strong style={{ color: '#ef4444' }}>{top.name} ({top.count})</strong></span>
      </div>

      <svg viewBox="0 0 1000 507" style={{ width: '100%', display: 'block', borderRadius: 8 }} xmlns="http://www.w3.org/2000/svg">
        {/* Ocean */}
        <rect width="1000" height="507" fill="rgba(6,182,212,0.04)" rx="8" />

        {/* Graticule */}
        <g stroke="rgba(6,182,212,0.07)" strokeWidth="0.5" fill="none">
          {[100,200,300,400,500,600,700,800,900].map(x => <line key={`v${x}`} x1={x} y1="0" x2={x} y2="507" />)}
          {[85,170,253,337,420].map(y => <line key={`h${y}`} x1="0" y1={y} x2="1000" y2={y} />)}
          <line x1="0" y1="253" x2="1000" y2="253" stroke="rgba(6,182,212,0.15)" strokeWidth="1" />
          <line x1="0" y1="210" x2="1000" y2="210" stroke="rgba(234,179,8,0.08)" strokeWidth="0.5" strokeDasharray="4,4" />
          <line x1="0" y1="296" x2="1000" y2="296" stroke="rgba(234,179,8,0.08)" strokeWidth="0.5" strokeDasharray="4,4" />
        </g>

        {/* Land */}
        {LAND_PATHS.map(p => (
          <path key={p.id} d={p.d} fill="rgba(148,163,184,0.12)" stroke="rgba(6,182,212,0.25)" strokeWidth="0.8" strokeLinejoin="round" />
        ))}

        {/* Hotspots */}
        {hotspots.map(h => {
          const isHov = hovered === h.name
          const r = Math.max(10, Math.min(28, h.count * 1.2))
          return (
            <g key={h.name} onMouseEnter={() => setHovered(h.name)} onMouseLeave={() => setHovered(null)} style={{ cursor: 'pointer' }}>
              <circle cx={h.x} cy={h.y} r={r * 2.5} fill={`${h.color}08`} stroke={`${h.color}20`} strokeWidth="1">
                <animate attributeName="r" values={`${r*2};${r*3};${r*2}`} dur="3s" repeatCount="indefinite" />
                <animate attributeName="opacity" values="0.7;0.2;0.7" dur="3s" repeatCount="indefinite" />
              </circle>
              <circle cx={h.x} cy={h.y} r={r * 1.7} fill={`${h.color}12`} stroke={`${h.color}35`} strokeWidth="1">
                <animate attributeName="r" values={`${r*1.4};${r*2};${r*1.4}`} dur="3s" repeatCount="indefinite" begin="0.5s" />
              </circle>
              <circle cx={h.x} cy={h.y} r={isHov ? r * 1.25 : r} fill={h.color} fillOpacity="0.85" stroke="rgba(255,255,255,0.4)" strokeWidth="1.5" style={{ transition: 'all 0.2s ease' }} />
              <text x={h.x} y={h.y + 4} textAnchor="middle" fontSize={Math.max(9, Math.min(13, r * 0.75))} fontWeight="700" fill="white" fontFamily="monospace" style={{ pointerEvents: 'none' }}>
                {h.count}
              </text>
              {isHov && (
                <g>
                  <rect x={h.x - 65} y={h.y - r - 46} width="130" height="38" rx="6" fill="rgba(5,12,24,0.95)" stroke={h.color} strokeWidth="1" />
                  <text x={h.x} y={h.y - r - 28} textAnchor="middle" fontSize="11" fill="white" fontFamily="sans-serif" fontWeight="600">{h.name}</text>
                  <text x={h.x} y={h.y - r - 15} textAnchor="middle" fontSize="10" fill={h.color} fontFamily="monospace">{h.count} active threats</text>
                </g>
              )}
            </g>
          )
        })}

        {/* Legend */}
        <g transform="translate(20, 470)">
          {[['Critical','#ef4444'],['High','#f97316'],['Medium','#eab308'],['Low','#22c55e']].map(([label,color],i) => (
            <g key={label} transform={`translate(${i*130},0)`}>
              <circle cx="7" cy="7" r="6" fill={color} fillOpacity="0.85" />
              <text x="18" y="11" fontSize="11" fill="rgba(148,163,184,0.8)" fontFamily="sans-serif">{label}</text>
            </g>
          ))}
        </g>
      </svg>

      {hovered && (() => {
        const h = hotspots.find(x => x.name === hovered)!
        return (
          <div style={{ position: 'absolute', bottom: 8, left: '50%', transform: 'translateX(-50%)', padding: '6px 16px', borderRadius: 20, background: 'rgba(5,12,24,0.95)', border: `1px solid ${h.color}55`, color: h.color, fontSize: 12, fontWeight: 600, pointerEvents: 'none', whiteSpace: 'nowrap' }}>
            {h.name} — {h.count} active threats
          </div>
        )
      })()}
    </div>
  )
}
WORLDMAP_EOF

# Now patch Dashboard to pass bySource and remove its duplicate HOTSPOTS stat block
# We use python for reliable in-place patch (no sed multiline issues on WSL)
python3 - << 'PYEOF'
import re

path = "/mnt/c/Users/playground/OSINT/osint-threat-intelligence-platform/frontend/src/app/pages/Dashboard/index.tsx"
with open(path, "r") as f:
    src = f.read()

# 1. Remove the hardcoded HOTSPOTS const array in Dashboard (it's deprecated)
src = re.sub(
    r"// World threat hotspot data.*?^const HOTSPOTS = \[.*?^\]",
    "",
    src,
    flags=re.DOTALL | re.MULTILINE,
)

# 2. Remove the _DEPRECATED_WorldMap function
src = re.sub(
    r"// WorldMap moved.*?^function _DEPRECATED_WorldMap.*?^\}",
    "",
    src,
    flags=re.DOTALL | re.MULTILINE,
)

# 3. Pass bySource to WorldThreatMap
src = src.replace(
    "<WorldThreatMap />",
    "<WorldThreatMap bySource={m?.by_source} />"
)

# 4. Remove the duplicate stats div wrapping WorldThreatMap in Dashboard header
# (the one with "Total hotspots: X, Most active: ...")
src = re.sub(
    r'<div style=\{ display: .flex., justifyContent: .space-between.*?Most active.*?</div>\s*</div>',
    '',
    src,
    flags=re.DOTALL,
    count=1
)

with open(path, "w") as f:
    f.write(src)
print("Dashboard patched OK")
PYEOF

echo "    Done."

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=========================================="
echo " All 7 fixes applied successfully"
echo "=========================================="
echo ""
echo " Fixed:"
echo "   [1] entities.ts        — removed double /api/v1 URL prefix"
echo "   [2] Threats/index.tsx  — client-side filter + accurate counts + URL search"
echo "   [3] Alerts/index.tsx   — localStorage persistence (survives navigation)"
echo "   [4] MainLayout.tsx     — badge = unread count, not total critical"
echo "   [5] TopBar.tsx         — Enter key navigates /threats?search=..."
echo "   [6] Entities/index.tsx — IP/domain/hash regex extraction, removed ORG tab"
echo "   [7] WorldThreatMap.tsx — live by_source data, Dashboard passes real data"
echo ""
echo " Next steps:"
echo "   cd /mnt/c/Users/playground/OSINT/osint-threat-intelligence-platform"
echo "   git add -A"
echo "   git commit -m 'fix(frontend): threat filter counts, alert persistence, search, entities IOC extraction, live world map, URL prefix'"
echo "   git push origin feature/osint-platfom"
echo ""
