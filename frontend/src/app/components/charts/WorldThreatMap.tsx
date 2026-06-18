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
  totalThreats?: number                // analytics.total_threats -- map is normalised to sum to this
}

function buildHotspots(bySource: Record<string, number> | undefined, totalThreats: number | undefined) {
  if (!bySource || Object.keys(bySource).length === 0 || !totalThreats) {
    return HOTSPOT_DEFS.map(h => ({ ...h, count: h.baseCount }))
  }

  const srcLower: Record<string, number> = {}
  Object.entries(bySource).forEach(([k, v]) => { srcLower[k.toLowerCase()] = v })

  const rawWeights = HOTSPOT_DEFS.map(h => {
    let w = h.baseCount
    h.sourceKeys.forEach(key => {
      Object.entries(srcLower).forEach(([src, cnt]) => {
        if (src.includes(key) || key.includes(src)) w += cnt
      })
    })
    return w
  })

  const sumWeights = rawWeights.reduce((a, b) => a + b, 0)

  const counts = rawWeights.map(w => Math.round((w / sumWeights) * totalThreats))

  const diff = totalThreats - counts.reduce((a, b) => a + b, 0)
  const maxIdx = counts.indexOf(Math.max(...counts))
  counts[maxIdx] += diff

  return HOTSPOT_DEFS.map((h, i) => ({ ...h, count: counts[i] }))
}

export function WorldThreatMap({ bySource, totalThreats }: Props) {
  const [hovered, setHovered] = useState<string | null>(null)
  const hotspots = buildHotspots(bySource, totalThreats)
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
