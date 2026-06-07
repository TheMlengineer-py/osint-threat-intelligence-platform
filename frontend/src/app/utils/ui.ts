import type { SeverityLevel, ThreatCategory } from '../types'

export const SEVERITY_CFG: Record<SeverityLevel, { label: string; colour: string }> = {
  critical: { label: 'CRITICAL', colour: '#ef4444' },
  high:     { label: 'HIGH',     colour: '#f97316' },
  medium:   { label: 'MEDIUM',   colour: '#eab308' },
  low:      { label: 'LOW',      colour: '#22c55e' },
}
export const getSeverity = (s: SeverityLevel) => SEVERITY_CFG[s] ?? SEVERITY_CFG.low

export const CATEGORY_LABELS: Record<ThreatCategory, string> = {
  malware_ransomware:    'Malware / Ransomware',
  data_breach:           'Data Breach',
  phishing_fraud:        'Phishing / Fraud',
  vulnerability_exploit: 'Vulnerability / Exploit',
  insider_threat:        'Insider Threat',
  apt:                   'APT / Nation-State',
  other:                 'Other',
}
export const getCategoryLabel = (c: ThreatCategory) => CATEGORY_LABELS[c] ?? c

export function timeAgo(iso: string): string {
  const m = Math.floor((Date.now() - new Date(iso).getTime()) / 60_000)
  if (m < 1)  return 'just now'
  if (m < 60) return `${m}m ago`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h}h ago`
  return `${Math.floor(h / 24)}d ago`
}

export const formatDate = (iso: string) =>
  new Date(iso).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })

export const formatDateTime = (iso: string) =>
  new Date(iso).toLocaleString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })

export const formatCount = (n: number) =>
  n >= 1_000_000 ? `${(n / 1e6).toFixed(1)}M`
  : n >= 1_000   ? `${(n / 1e3).toFixed(1)}K`
  : String(n)

export const truncate = (s: string, max: number) =>
  s.length > max ? s.slice(0, max) + '…' : s

export const capitalise = (s: string) =>
  s.charAt(0).toUpperCase() + s.slice(1)

export const cn = (...cls: (string | undefined | false | null)[]) =>
  cls.filter(Boolean).join(' ')
