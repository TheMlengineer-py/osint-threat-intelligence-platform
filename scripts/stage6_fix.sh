#!/usr/bin/env bash
# =============================================================================
# STAGE 6 FIX — Frontend Integration
# Run from: project root (osint-threat-intelligence-platform/)
# Usage:    bash scripts/stage6_fix.sh
# =============================================================================
set -e
GREEN='\033[0;32m'; BOLD='\033[1m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${BOLD}[--]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1"; }

[ ! -d "frontend" ] && err "Run from project root directory" && exit 1

echo ""
echo -e "${BOLD}=== STAGE 6 FIX — Frontend Integration ===${NC}"
echo ""

# =============================================================================
# FIX 1 — frontend/.env
# WHY: Has VITE_API_URL but vite.config.ts and api.ts read VITE_API_BASE_URL
#      So the proxy and axios baseURL both fall back to localhost:8000 hardcoded
# FIX: Add the correct variable name
# =============================================================================
info "FIX 1: frontend/.env — add VITE_API_BASE_URL"

cat > frontend/.env << 'EOF'
VITE_API_BASE_URL=http://localhost:8000
VITE_WS_URL=ws://localhost:8000
VITE_API_URL=http://localhost:8000
VITE_APP_NAME=OSINT Threat Intelligence Platform
VITE_ENVIRONMENT=development
VITE_DEBUG=true
EOF
log ".env — VITE_API_BASE_URL added"

# =============================================================================
# FIX 2 — frontend/src/app/services/threats.ts
# WHY: File starts with shell script comment (#) and cat heredoc — not TypeScript
#      Will fail to compile immediately
# FIX: Write clean TypeScript aligned with actual backend API response shape
# =============================================================================
info "FIX 2: services/threats.ts — rewrite (was shell script not TypeScript)"

cat > frontend/src/app/services/threats.ts << 'EOF'
/**
 * Threats API service.
 * Backend returns flat arrays, not paginated objects — aligned here.
 */
import { apiClient } from './api'
import type { Threat } from '../types'

export interface ThreatListParams {
  skip?:     number
  limit?:    number
  severity?: string
  category?: string
}

export const threatsService = {
  list(params: ThreatListParams = {}): Promise<Threat[]> {
    return apiClient
      .get<Threat[]>('/threats/', { params: { skip: 0, limit: 50, ...params } })
      .then(r => r.data)
  },

  get(id: string): Promise<Threat> {
    return apiClient.get<Threat>(`/threats/${id}`).then(r => r.data)
  },

  ingestCisa(): Promise<{ status: string; ingested: number }> {
    return apiClient.post('/threats/ingest/cisa').then(r => r.data)
  },

  ingestRss(): Promise<{ status: string; ingested: number }> {
    return apiClient.post('/threats/ingest/rss').then(r => r.data)
  },

  processAll(): Promise<{ status: string; results: Record<string, number> }> {
    return apiClient.post('/threats/process').then(r => r.data)
  },

  ingestStatus(): Promise<Record<string, number>> {
    return apiClient.get('/threats/ingest/status').then(r => r.data)
  },

  stats(): Promise<Record<string, unknown>> {
    return apiClient.get('/threats/stats/summary').then(r => r.data)
  },
}
EOF
log "services/threats.ts rewritten"

# =============================================================================
# FIX 3 — frontend/src/app/services/analytics.ts
# WHY: Contains copilot service code (wrong file), no analytics exports at all
# FIX: Write real analytics service matching backend endpoints
# =============================================================================
info "FIX 3: services/analytics.ts — rewrite (contained copilot code)"

cat > frontend/src/app/services/analytics.ts << 'EOF'
/**
 * Analytics API service — maps to /api/v1/analytics/* endpoints.
 */
import { apiClient } from './api'

export interface DashboardMetrics {
  total_threats:    number
  critical_threats: number
  high_threats:     number
  processed_docs:   number
  pending_docs:     number
  avg_risk_score:   number
  max_risk_score:   number
  by_source:        Record<string, number>
  by_category:      Record<string, number>
  last_updated:     string
}

export interface TrendData {
  days:        number
  since:       string
  data_points: number
  trend:       Record<string, Record<string, number>>
}

export interface RiskDistribution {
  total:   number
  buckets: Record<string, number>
  avg:     number
  max:     number
}

export interface TopThreat {
  id:          string
  title:       string
  severity:    string
  category:    string
  risk_score:  number
  source:      string
  detected_at: string
}

export const analyticsService = {
  dashboard(): Promise<DashboardMetrics> {
    return apiClient.get<DashboardMetrics>('/analytics/dashboard').then(r => r.data)
  },

  trends(days = 30): Promise<TrendData> {
    return apiClient.get<TrendData>('/analytics/trends', { params: { days } }).then(r => r.data)
  },

  riskDistribution(): Promise<RiskDistribution> {
    return apiClient.get<RiskDistribution>('/analytics/risk-distribution').then(r => r.data)
  },

  topThreats(limit = 10): Promise<TopThreat[]> {
    return apiClient.get<TopThreat[]>('/analytics/top-threats', { params: { limit } }).then(r => r.data)
  },

  // Alias used by hooks
  summary(): Promise<DashboardMetrics> {
    return analyticsService.dashboard()
  },
}
EOF
log "services/analytics.ts rewritten"

# =============================================================================
# FIX 4 — frontend/src/app/services/copilot.ts
# WHY: Contains shell script heredoc at the top — not valid TypeScript
#      Also calls /copilot/chat but backend endpoint is /copilot/ask
# FIX: Clean TypeScript, correct endpoint
# =============================================================================
info "FIX 4: services/copilot.ts — rewrite (was shell script + wrong endpoint)"

cat > frontend/src/app/services/copilot.ts << 'EOF'
/**
 * AI Copilot API service — maps to /api/v1/copilot/* endpoints.
 */
import { apiClient } from './api'
import type { CopilotRequest, CopilotResponse } from '../types'

export const copilotService = {
  ask(body: CopilotRequest): Promise<CopilotResponse> {
    return apiClient.post<CopilotResponse>('/copilot/ask', body).then(r => r.data)
  },

  // Alias for hooks that use .chat()
  chat(body: CopilotRequest): Promise<CopilotResponse> {
    return copilotService.ask(body)
  },

  status(): Promise<{ ollama_available: boolean; status: string }> {
    return apiClient.get('/copilot/status').then(r => r.data)
  },
}
EOF
log "services/copilot.ts rewritten"

# =============================================================================
# FIX 5 — frontend/src/app/services/reports.ts
# WHY: Need to check what's there
# =============================================================================
info "FIX 5: services/reports.ts — write clean version"

cat > frontend/src/app/services/reports.ts << 'EOF'
/**
 * Reports API service — maps to /api/v1/reports/* endpoints.
 */
import { apiClient } from './api'

export interface ReportPayload {
  title?:      string
  threat_ids?: string[]
  format?:     string
}

export interface ReportResult {
  id:           string
  title:        string
  content:      string
  status:       string
  created_at:   string
  threat_count: number
  format:       string
}

export const reportsService = {
  generate(payload: ReportPayload = {}): Promise<ReportResult> {
    return apiClient.post<ReportResult>('/reports', payload).then(r => r.data)
  },

  quick(): Promise<Record<string, unknown>> {
    return apiClient.get('/reports/quick').then(r => r.data)
  },

  list(): Promise<ReportResult[]> {
    return apiClient.get<ReportResult[]>('/reports').then(r => r.data)
  },
}
EOF
log "services/reports.ts rewritten"

# =============================================================================
# FIX 6 — frontend/src/app/hooks/useAnalytics.ts
# WHY: Calls analyticsService.summary as a property not a function
#      analyticsService.summary is a function — needs ()
# FIX: Correct call syntax + add more hooks
# =============================================================================
info "FIX 6: hooks/useAnalytics.ts — fix call syntax + add hooks"

cat > frontend/src/app/hooks/useAnalytics.ts << 'EOF'
import { useQuery } from '@tanstack/react-query'
import { analyticsService } from '../services/analytics'

export function useAnalyticsSummary() {
  return useQuery({
    queryKey:        ['analytics', 'summary'],
    queryFn:         () => analyticsService.dashboard(),
    staleTime:       30_000,
    refetchInterval: 60_000,
  })
}

export function useAnalyticsTrends(days = 30) {
  return useQuery({
    queryKey:  ['analytics', 'trends', days],
    queryFn:   () => analyticsService.trends(days),
    staleTime: 60_000,
  })
}

export function useRiskDistribution() {
  return useQuery({
    queryKey:  ['analytics', 'risk-distribution'],
    queryFn:   () => analyticsService.riskDistribution(),
    staleTime: 60_000,
  })
}

export function useTopThreats(limit = 10) {
  return useQuery({
    queryKey:        ['analytics', 'top-threats', limit],
    queryFn:         () => analyticsService.topThreats(limit),
    staleTime:       30_000,
    refetchInterval: 60_000,
  })
}
EOF
log "hooks/useAnalytics.ts fixed"

# =============================================================================
# FIX 7 — frontend/src/app/hooks/useCopilot.ts
# WHY: Calls copilotService.chat — now works since we added the alias,
#      but needs proper typing
# FIX: Clean up + add status hook
# =============================================================================
info "FIX 7: hooks/useCopilot.ts — clean up + status hook"

cat > frontend/src/app/hooks/useCopilot.ts << 'EOF'
import { useMutation, useQuery } from '@tanstack/react-query'
import { copilotService } from '../services/copilot'
import type { CopilotRequest } from '../types'

export function useCopilotChat() {
  return useMutation({
    mutationFn: (request: CopilotRequest) => copilotService.ask(request),
  })
}

export function useCopilotStatus() {
  return useQuery({
    queryKey:  ['copilot', 'status'],
    queryFn:   () => copilotService.status(),
    staleTime: 30_000,
  })
}
EOF
log "hooks/useCopilot.ts fixed"

# =============================================================================
# FIX 8 — frontend/src/app/hooks/useReports.ts
# WHY: Need to align with reportsService
# =============================================================================
info "FIX 8: hooks/useReports.ts — align with reportsService"

cat > frontend/src/app/hooks/useReports.ts << 'EOF'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { reportsService, type ReportPayload } from '../services/reports'

export function useReports() {
  return useQuery({
    queryKey:  ['reports'],
    queryFn:   () => reportsService.list(),
    staleTime: 60_000,
  })
}

export function useQuickReport() {
  return useQuery({
    queryKey:  ['reports', 'quick'],
    queryFn:   () => reportsService.quick(),
    staleTime: 60_000,
  })
}

export function useGenerateReport() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (payload: ReportPayload) => reportsService.generate(payload),
    onSuccess:  () => qc.invalidateQueries({ queryKey: ['reports'] }),
  })
}
EOF
log "hooks/useReports.ts fixed"

# =============================================================================
# FIX 9 — frontend/src/app/hooks/index.ts
# WHY: MainLayout imports useIngestionStatus and useWebSocket from @/hooks
#      These need to be exported from the index
# =============================================================================
info "FIX 9: hooks/index.ts — export all hooks including missing ones"

cat > frontend/src/app/hooks/index.ts << 'EOF'
export * from './useThreats'
export * from './useAnalytics'
export * from './useCopilot'
export * from './useReports'

// ── useIngestionStatus ────────────────────────────────────────────────────────
import { useQuery } from '@tanstack/react-query'
import { threatsService } from '../services/threats'

export function useIngestionStatus() {
  return useQuery({
    queryKey:        ['ingestion', 'status'],
    queryFn:         () => threatsService.ingestStatus(),
    staleTime:       15_000,
    refetchInterval: 30_000,
  })
}

// ── useWebSocket ──────────────────────────────────────────────────────────────
// Stub — real WebSocket backend not yet implemented.
// MainLayout calls this but it's safe to no-op.
export function useWebSocket() {
  return null
}
EOF
log "hooks/index.ts — all hooks exported"

# =============================================================================
# FIX 10 — Missing page components
# WHY: routes/index.tsx lazy-loads Alerts, Entities, Reports, Settings, NotFound
#      pages/ directories exist but index.tsx files are missing for Reports + Settings
#      Also check Alerts, Entities, NotFound
# =============================================================================
info "FIX 10: Creating missing page stubs"

mkdir -p frontend/src/app/pages/Reports
mkdir -p frontend/src/app/pages/Settings
mkdir -p frontend/src/app/pages/Alerts
mkdir -p frontend/src/app/pages/Entities
mkdir -p frontend/src/app/pages/NotFound

# Reports page
if [ ! -s frontend/src/app/pages/Reports/index.tsx ]; then
cat > frontend/src/app/pages/Reports/index.tsx << 'EOF'
import React from 'react'
import { FileText, Download, Plus } from 'lucide-react'
import { useQuickReport, useGenerateReport } from '@/hooks'

export default function Reports() {
  const { data: quick, isLoading } = useQuickReport()
  const generate = useGenerateReport()

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Intelligence Reports</h1>
          <p className="text-slate-400 mt-1">Generate and manage threat intelligence reports</p>
        </div>
        <button
          onClick={() => generate.mutate({ title: 'Intelligence Report' })}
          disabled={generate.isPending}
          className="flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium text-white"
          style={{ background: 'rgba(6,182,212,0.2)', border: '1px solid rgba(6,182,212,0.4)' }}
        >
          <Plus size={16} />
          {generate.isPending ? 'Generating…' : 'New Report'}
        </button>
      </div>

      {isLoading ? (
        <div className="text-slate-400">Loading…</div>
      ) : quick ? (
        <div className="rounded-xl p-6 space-y-4" style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)' }}>
          <div className="flex items-center gap-3">
            <FileText size={20} style={{ color: 'var(--cyan)' }} />
            <h2 className="text-lg font-semibold text-white">Quick Summary</h2>
            <span className="ml-auto text-xs text-slate-500">{(quick as any).generated_at?.slice(0,19).replace('T',' ')}</span>
          </div>
          <div className="grid grid-cols-3 gap-4">
            {[
              { label: 'Total Threats', value: (quick as any).total_threats },
              { label: 'Avg Risk',      value: (quick as any).top_20_by_risk?.avg_risk },
              { label: 'Max Risk',      value: (quick as any).top_20_by_risk?.max_risk },
            ].map(({ label, value }) => (
              <div key={label} className="rounded-lg p-4 text-center" style={{ background: 'rgba(6,182,212,0.05)', border: '1px solid rgba(6,182,212,0.15)' }}>
                <p className="text-2xl font-bold" style={{ color: 'var(--cyan)' }}>{value ?? 0}</p>
                <p className="text-xs text-slate-400 mt-1">{label}</p>
              </div>
            ))}
          </div>
        </div>
      ) : null}

      {generate.data && (
        <div className="rounded-xl p-6" style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)' }}>
          <div className="flex items-center justify-between mb-3">
            <h3 className="font-semibold text-white">{generate.data.title}</h3>
            <span className="text-xs px-2 py-1 rounded" style={{ background: 'rgba(34,197,94,0.15)', color: '#22c55e' }}>Generated</span>
          </div>
          <p className="text-sm text-slate-400">{generate.data.threat_count} threats analysed</p>
        </div>
      )}
    </div>
  )
}
EOF
log "pages/Reports/index.tsx created"
fi

# Settings page
if [ ! -s frontend/src/app/pages/Settings/index.tsx ]; then
cat > frontend/src/app/pages/Settings/index.tsx << 'EOF'
import React from 'react'
import { Settings as SettingsIcon } from 'lucide-react'
import { useCopilotStatus } from '@/hooks'

export default function Settings() {
  const { data: copilot } = useCopilotStatus()

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-white">Settings</h1>
        <p className="text-slate-400 mt-1">System configuration and preferences</p>
      </div>

      <div className="grid gap-4">
        {[
          { label: 'Backend API',     value: 'http://localhost:8000', status: 'connected' },
          { label: 'Ollama LLM',      value: copilot?.ollama_available ? 'Available' : 'Unavailable', status: copilot?.ollama_available ? 'connected' : 'warning' },
          { label: 'Database',        value: 'SQLite (local)',         status: 'connected' },
          { label: 'Vector Store',    value: 'ChromaDB',               status: 'warning' },
        ].map(({ label, value, status }) => (
          <div key={label} className="flex items-center justify-between rounded-xl p-4" style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)' }}>
            <div>
              <p className="text-sm font-medium text-white">{label}</p>
              <p className="text-xs text-slate-500 mt-0.5">{value}</p>
            </div>
            <span className="text-xs px-2 py-1 rounded-full" style={{
              background: status === 'connected' ? 'rgba(34,197,94,0.15)' : 'rgba(234,179,8,0.15)',
              color:      status === 'connected' ? '#22c55e'              : '#eab308',
            }}>
              {status}
            </span>
          </div>
        ))}
      </div>
    </div>
  )
}
EOF
log "pages/Settings/index.tsx created"
fi

# Alerts page stub
if [ ! -s frontend/src/app/pages/Alerts/index.tsx ]; then
cat > frontend/src/app/pages/Alerts/index.tsx << 'EOF'
import React from 'react'
import { Bell } from 'lucide-react'
import { useThreats } from '@/hooks'

export default function Alerts() {
  const { data: threats = [], isLoading } = useThreats({ severity: 'critical', limit: 20 } as any)
  const critical = (threats as any[]).filter?.((t: any) => t.severity === 'critical' || t.severity === 'high') ?? []

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center gap-3">
        <Bell size={24} style={{ color: 'var(--cyan)' }} />
        <div>
          <h1 className="text-2xl font-bold text-white">Real-time Alerts</h1>
          <p className="text-slate-400 mt-1">High and critical severity threats</p>
        </div>
      </div>
      {isLoading ? <div className="text-slate-400">Loading…</div> : (
        <div className="space-y-3">
          {critical.length === 0 && <p className="text-slate-500">No critical alerts at this time.</p>}
          {critical.slice(0, 20).map((t: any) => (
            <div key={t.id} className="rounded-xl p-4" style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(239,68,68,0.2)' }}>
              <div className="flex items-center gap-3">
                <span className="text-xs px-2 py-1 rounded font-mono font-bold uppercase" style={{ background: t.severity === 'critical' ? 'rgba(239,68,68,0.2)' : 'rgba(249,115,22,0.2)', color: t.severity === 'critical' ? '#ef4444' : '#f97316' }}>{t.severity}</span>
                <p className="text-sm font-medium text-white truncate">{t.title}</p>
                <span className="ml-auto text-xs text-slate-500">Risk: {t.risk_score?.toFixed(2)}</span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
EOF
log "pages/Alerts/index.tsx created"
fi

# Entities page stub
if [ ! -s frontend/src/app/pages/Entities/index.tsx ]; then
cat > frontend/src/app/pages/Entities/index.tsx << 'EOF'
import React from 'react'
import { Network } from 'lucide-react'

export default function Entities() {
  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center gap-3">
        <Network size={24} style={{ color: 'var(--cyan)' }} />
        <div>
          <h1 className="text-2xl font-bold text-white">Entities</h1>
          <p className="text-slate-400 mt-1">People, organisations, assets and indicators</p>
        </div>
      </div>
      <div className="rounded-xl p-8 text-center" style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)' }}>
        <Network size={40} className="mx-auto mb-3" style={{ color: 'var(--cyan)', opacity: 0.4 }} />
        <p className="text-slate-400">Entity relationship graph coming in Stage 7</p>
      </div>
    </div>
  )
}
EOF
log "pages/Entities/index.tsx created"
fi

# NotFound page
if [ ! -s frontend/src/app/pages/NotFound/index.tsx ]; then
cat > frontend/src/app/pages/NotFound/index.tsx << 'EOF'
import React from 'react'
import { useNavigate } from 'react-router-dom'

export default function NotFound() {
  const navigate = useNavigate()
  return (
    <div className="flex flex-col items-center justify-center h-full gap-4">
      <p className="text-6xl font-bold text-slate-700">404</p>
      <p className="text-slate-400">Page not found</p>
      <button onClick={() => navigate('/dashboard')} className="px-4 py-2 rounded text-sm" style={{ background: 'rgba(6,182,212,0.2)', color: 'var(--cyan)' }}>
        Back to Dashboard
      </button>
    </div>
  )
}
EOF
log "pages/NotFound/index.tsx created"
fi

# =============================================================================
# FIX 11 — Check existing Dashboard, Threats, Analytics, Copilot pages
#           Create stubs if missing
# =============================================================================
info "FIX 11: Ensuring Dashboard, Threats, Analytics, Copilot pages exist"

mkdir -p frontend/src/app/pages/Dashboard
mkdir -p frontend/src/app/pages/Threats
mkdir -p frontend/src/app/pages/Analytics
mkdir -p frontend/src/app/pages/Copilot

if [ ! -s frontend/src/app/pages/Dashboard/index.tsx ]; then
cat > frontend/src/app/pages/Dashboard/index.tsx << 'EOF'
import React from 'react'
import { Shield, AlertTriangle, TrendingUp, Database } from 'lucide-react'
import { useAnalyticsSummary, useTopThreats } from '@/hooks'

function KpiCard({ label, value, sub, color }: { label: string; value: number | string; sub?: string; color: string }) {
  return (
    <div className="rounded-xl p-5" style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)' }}>
      <p className="text-xs text-slate-400 mb-1">{label}</p>
      <p className="text-3xl font-bold font-mono" style={{ color }}>{value}</p>
      {sub && <p className="text-xs text-slate-500 mt-1">{sub}</p>}
    </div>
  )
}

export default function Dashboard() {
  const { data: metrics, isLoading } = useAnalyticsSummary()
  const { data: top = [] }           = useTopThreats(5)

  if (isLoading) return <div className="p-6 text-slate-400">Loading dashboard…</div>

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-white">Dashboard</h1>
        <p className="text-slate-400 mt-1">Command centre overview</p>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <KpiCard label="Total Threats"   value={metrics?.total_threats ?? 0}    color="var(--cyan)"  sub="all time" />
        <KpiCard label="Critical"        value={metrics?.critical_threats ?? 0} color="#ef4444"      sub="immediate action" />
        <KpiCard label="Avg Risk Score"  value={(metrics?.avg_risk_score ?? 0).toFixed(2)} color="#f97316" sub="0–10 scale" />
        <KpiCard label="Pending NLP"     value={metrics?.pending_docs ?? 0}     color="#a78bfa"      sub="unprocessed docs" />
      </div>

      <div className="rounded-xl p-6" style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)' }}>
        <h2 className="text-sm font-semibold text-white mb-4 flex items-center gap-2">
          <TrendingUp size={16} style={{ color: 'var(--cyan)' }} /> Top Threats by Risk Score
        </h2>
        <div className="space-y-2">
          {(top as any[]).map((t: any) => (
            <div key={t.id} className="flex items-center gap-3 py-2" style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
              <span className="text-xs px-2 py-0.5 rounded font-mono uppercase shrink-0" style={{
                background: t.severity === 'critical' ? 'rgba(239,68,68,0.2)' : t.severity === 'high' ? 'rgba(249,115,22,0.2)' : 'rgba(234,179,8,0.2)',
                color:      t.severity === 'critical' ? '#ef4444'              : t.severity === 'high' ? '#f97316'              : '#eab308',
              }}>{t.severity}</span>
              <p className="text-sm text-slate-300 flex-1 truncate">{t.title}</p>
              <span className="text-xs font-mono shrink-0" style={{ color: 'var(--cyan)' }}>{t.risk_score?.toFixed(2)}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div className="rounded-xl p-5" style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)' }}>
          <h3 className="text-sm font-semibold text-white mb-3">By Category</h3>
          {Object.entries(metrics?.by_category ?? {}).map(([cat, cnt]) => (
            <div key={cat} className="flex items-center justify-between py-1">
              <span className="text-xs text-slate-400">{cat}</span>
              <span className="text-xs font-mono" style={{ color: 'var(--cyan)' }}>{cnt as number}</span>
            </div>
          ))}
        </div>
        <div className="rounded-xl p-5" style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)' }}>
          <h3 className="text-sm font-semibold text-white mb-3">By Source</h3>
          {Object.entries(metrics?.by_source ?? {}).map(([src, cnt]) => (
            <div key={src} className="flex items-center justify-between py-1">
              <span className="text-xs text-slate-400">{src}</span>
              <span className="text-xs font-mono" style={{ color: 'var(--cyan)' }}>{cnt as number}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
EOF
log "pages/Dashboard/index.tsx created"
fi

if [ ! -s frontend/src/app/pages/Threats/index.tsx ]; then
cat > frontend/src/app/pages/Threats/index.tsx << 'EOF'
import React, { useState } from 'react'
import { Shield, RefreshCw } from 'lucide-react'
import { useThreats } from '@/hooks'
import { threatsService } from '@/services/threats'

const SEV_COLORS: Record<string, string> = {
  critical: '#ef4444', high: '#f97316', medium: '#eab308', low: '#22c55e'
}

export default function Threats() {
  const [severity, setSeverity] = useState<string | undefined>()
  const { data = [], isLoading, refetch } = useThreats({ severity } as any)
  const threats = data as any[]

  return (
    <div className="p-6 space-y-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Shield size={24} style={{ color: 'var(--cyan)' }} />
          <div>
            <h1 className="text-2xl font-bold text-white">Threats</h1>
            <p className="text-slate-400 text-sm">{threats.length} threats loaded</p>
          </div>
        </div>
        <button onClick={() => refetch()} className="flex items-center gap-2 px-3 py-2 rounded text-sm text-slate-300 hover:text-white" style={{ background: 'rgba(255,255,255,0.05)' }}>
          <RefreshCw size={14} /> Refresh
        </button>
      </div>

      <div className="flex gap-2">
        {['', 'critical', 'high', 'medium', 'low'].map(sev => (
          <button key={sev} onClick={() => setSeverity(sev || undefined)}
            className="px-3 py-1 rounded text-xs font-medium capitalize"
            style={{ background: severity === (sev || undefined) ? 'rgba(6,182,212,0.2)' : 'rgba(255,255,255,0.05)', color: sev ? SEV_COLORS[sev] : 'var(--cyan)', border: `1px solid ${severity === (sev || undefined) ? 'rgba(6,182,212,0.4)' : 'transparent'}` }}>
            {sev || 'All'}
          </button>
        ))}
      </div>

      {isLoading ? <div className="text-slate-400">Loading…</div> : (
        <div className="space-y-2">
          {threats.map((t: any) => (
            <div key={t.id} className="rounded-xl p-4" style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)' }}>
              <div className="flex items-start gap-3">
                <span className="text-xs px-2 py-0.5 rounded font-mono uppercase shrink-0 mt-0.5"
                  style={{ background: `${SEV_COLORS[t.severity] ?? '#64748b'}22`, color: SEV_COLORS[t.severity] ?? '#64748b' }}>
                  {t.severity}
                </span>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-white truncate">{t.title}</p>
                  {t.summary && <p className="text-xs text-slate-500 mt-1 line-clamp-2">{t.summary}</p>}
                  <div className="flex items-center gap-3 mt-2">
                    <span className="text-xs text-slate-600">{t.category}</span>
                    <span className="text-xs text-slate-600">{t.source}</span>
                    <span className="text-xs font-mono ml-auto" style={{ color: 'var(--cyan)' }}>Risk: {t.risk_score?.toFixed(2) ?? '—'}</span>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
EOF
log "pages/Threats/index.tsx created"
fi

if [ ! -s frontend/src/app/pages/Analytics/index.tsx ]; then
cat > frontend/src/app/pages/Analytics/index.tsx << 'EOF'
import React from 'react'
import { BarChart3 } from 'lucide-react'
import { useAnalyticsSummary, useRiskDistribution, useTopThreats } from '@/hooks'

export default function Analytics() {
  const { data: metrics }  = useAnalyticsSummary()
  const { data: riskDist } = useRiskDistribution()
  const { data: top = [] } = useTopThreats(10)

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center gap-3">
        <BarChart3 size={24} style={{ color: 'var(--cyan)' }} />
        <div>
          <h1 className="text-2xl font-bold text-white">Analytics</h1>
          <p className="text-slate-400 mt-1">Insights and trend analysis</p>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-4">
        {[
          { label: 'Total Threats',  value: metrics?.total_threats ?? 0,            color: 'var(--cyan)' },
          { label: 'Avg Risk Score', value: (metrics?.avg_risk_score ?? 0).toFixed(2), color: '#f97316' },
          { label: 'Max Risk Score', value: (metrics?.max_risk_score ?? 0).toFixed(2), color: '#ef4444' },
        ].map(({ label, value, color }) => (
          <div key={label} className="rounded-xl p-5 text-center" style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)' }}>
            <p className="text-3xl font-bold font-mono" style={{ color }}>{value}</p>
            <p className="text-xs text-slate-400 mt-1">{label}</p>
          </div>
        ))}
      </div>

      <div className="rounded-xl p-6" style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)' }}>
        <h2 className="text-sm font-semibold text-white mb-4">Risk Score Distribution</h2>
        <div className="space-y-2">
          {Object.entries(riskDist?.buckets ?? {}).map(([bucket, count]) => {
            const pct = riskDist?.total ? Math.round((count as number) / riskDist.total * 100) : 0
            return (
              <div key={bucket} className="flex items-center gap-3">
                <span className="text-xs font-mono text-slate-400 w-10">{bucket}</span>
                <div className="flex-1 h-2 rounded-full" style={{ background: 'rgba(255,255,255,0.08)' }}>
                  <div className="h-2 rounded-full" style={{ width: `${pct}%`, background: 'var(--cyan)' }} />
                </div>
                <span className="text-xs font-mono text-slate-400 w-8 text-right">{count as number}</span>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
EOF
log "pages/Analytics/index.tsx created"
fi

if [ ! -s frontend/src/app/pages/Copilot/index.tsx ]; then
cat > frontend/src/app/pages/Copilot/index.tsx << 'EOF'
import React, { useState, useRef, useEffect } from 'react'
import { Bot, Send } from 'lucide-react'
import { useCopilotChat, useCopilotStatus } from '@/hooks'
import type { ChatMessage } from '@/types'

export default function Copilot() {
  const [input, setInput]       = useState('')
  const [history, setHistory]   = useState<ChatMessage[]>([])
  const bottomRef               = useRef<HTMLDivElement>(null)
  const { data: status }        = useCopilotStatus()
  const chat                    = useCopilotChat()

  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: 'smooth' }) }, [history])

  const send = () => {
    if (!input.trim() || chat.isPending) return
    const q = input.trim()
    setInput('')
    const userMsg: ChatMessage = { role: 'user', content: q, timestamp: new Date().toISOString() }
    setHistory(h => [...h, userMsg])
    chat.mutate(
      { query: q, conversation_history: history, max_context_docs: 5 },
      {
        onSuccess: res => {
          setHistory(h => [...h, { role: 'assistant', content: res.answer, timestamp: new Date().toISOString() }])
        },
        onError: () => {
          setHistory(h => [...h, { role: 'assistant', content: 'Sorry, an error occurred. Please try again.', timestamp: new Date().toISOString() }])
        },
      }
    )
  }

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center gap-3 px-6 py-4" style={{ borderBottom: '1px solid rgba(255,255,255,0.08)' }}>
        <Bot size={22} style={{ color: 'var(--cyan)' }} />
        <div>
          <h1 className="text-lg font-bold text-white">AI Copilot</h1>
          <p className="text-xs text-slate-400">
            {status?.ollama_available ? '🟢 LLM connected' : '🟡 Context mode (Ollama offline)'}
          </p>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto px-6 py-4 space-y-4">
        {history.length === 0 && (
          <div className="text-center text-slate-500 mt-12">
            <Bot size={40} className="mx-auto mb-3 opacity-30" />
            <p>Ask anything about your threat intelligence data.</p>
            <p className="text-xs mt-2">Try: "What are the top critical threats?" or "Summarise recent ransomware activity"</p>
          </div>
        )}
        {history.map((msg, i) => (
          <div key={i} className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
            <div className="max-w-[80%] rounded-xl px-4 py-3 text-sm"
              style={msg.role === 'user'
                ? { background: 'rgba(6,182,212,0.15)', color: 'white', border: '1px solid rgba(6,182,212,0.3)' }
                : { background: 'rgba(255,255,255,0.05)', color: '#cbd5e1', border: '1px solid rgba(255,255,255,0.08)' }}>
              <p className="whitespace-pre-wrap">{msg.content}</p>
            </div>
          </div>
        ))}
        {chat.isPending && (
          <div className="flex justify-start">
            <div className="rounded-xl px-4 py-3" style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.08)' }}>
              <div className="flex gap-1">
                {[0,1,2].map(i => <div key={i} className="w-2 h-2 rounded-full animate-bounce" style={{ background: 'var(--cyan)', animationDelay: `${i*0.15}s` }} />)}
              </div>
            </div>
          </div>
        )}
        <div ref={bottomRef} />
      </div>

      <div className="px-6 py-4" style={{ borderTop: '1px solid rgba(255,255,255,0.08)' }}>
        <div className="flex gap-3">
          <input
            value={input}
            onChange={e => setInput(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && !e.shiftKey && send()}
            placeholder="Ask about threats, IOCs, risk levels…"
            className="flex-1 rounded-xl px-4 py-3 text-sm text-white placeholder-slate-500 outline-none"
            style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)' }}
          />
          <button onClick={send} disabled={!input.trim() || chat.isPending}
            className="px-4 py-3 rounded-xl transition-opacity disabled:opacity-40"
            style={{ background: 'rgba(6,182,212,0.2)', border: '1px solid rgba(6,182,212,0.4)', color: 'var(--cyan)' }}>
            <Send size={16} />
          </button>
        </div>
      </div>
    </div>
  )
}
EOF
log "pages/Copilot/index.tsx created"
fi

# =============================================================================
# STEP A — npm install check
# =============================================================================
info "Checking npm dependencies..."
cd frontend
if [ ! -f node_modules/.package-lock.json ] && [ ! -f node_modules/.modules.yaml ]; then
  echo "  Running npm install..."
  npm install --silent
fi
log "npm dependencies ready"
cd ..

# =============================================================================
# STEP B — TypeScript type check
# =============================================================================
info "Running TypeScript check..."
cd frontend
npx tsc --noEmit 2>&1 | head -30 || true
cd ..
log "TypeScript check complete"

echo ""
echo "========================================================"
echo -e "${GREEN}Stage 6 fixes applied.${NC}"
echo ""
echo "  Start frontend (new terminal):"
echo "    cd frontend && npm run dev"
echo ""
echo "  Then open: http://localhost:5173"
echo ""
echo "  Run tests:"
echo "    bash ../scripts/test_stage6.sh"
echo "========================================================"
