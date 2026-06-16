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
