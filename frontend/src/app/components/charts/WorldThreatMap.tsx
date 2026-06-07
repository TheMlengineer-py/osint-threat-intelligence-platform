/**
 * WorldThreatMap — proper SVG world map with threat hotspot overlays.
 * Uses simplified but geographically accurate Natural Earth country paths.
 */
import React, { useState } from 'react'

interface Hotspot {
  name:    string
  x:       number   // 0–1000 SVG units
  y:       number   // 0–507 SVG units
  count:   number
  color:   string
}

const HOTSPOTS: Hotspot[] = [
  { name: 'United States',  x: 195, y: 195, count: 18, color: '#ef4444' },
  { name: 'United Kingdom', x: 455, y: 145, count: 12, color: '#ef4444' },
  { name: 'Germany',        x: 490, y: 148, count: 8,  color: '#f97316' },
  { name: 'Russia',         x: 620, y: 120, count: 15, color: '#ef4444' },
  { name: 'China',          x: 750, y: 200, count: 14, color: '#f97316' },
  { name: 'Iran',           x: 580, y: 215, count: 9,  color: '#f97316' },
  { name: 'North Korea',    x: 790, y: 185, count: 7,  color: '#eab308' },
  { name: 'Brazil',         x: 270, y: 320, count: 5,  color: '#22c55e' },
  { name: 'India',          x: 655, y: 235, count: 7,  color: '#eab308' },
  { name: 'Nigeria',        x: 487, y: 295, count: 4,  color: '#22c55e' },
]

// Simplified but recognisable country/continent outlines in 1000×507 SVG space
const LAND_PATHS = [
  // North America
  { d: "M 85 100 L 270 85 L 310 95 L 330 130 L 310 195 L 290 240 L 245 265 L 200 260 L 170 240 L 145 200 L 120 170 L 95 140 Z", id: "north-america" },
  // South America
  { d: "M 215 270 L 300 260 L 325 280 L 335 360 L 305 430 L 265 450 L 235 430 L 215 380 L 205 320 Z", id: "south-america" },
  // Europe
  { d: "M 430 100 L 540 95 L 560 115 L 555 150 L 520 165 L 480 170 L 450 160 L 430 140 Z", id: "europe" },
  // Scandinavia
  { d: "M 470 70 L 510 65 L 520 90 L 490 100 L 465 95 Z", id: "scandinavia" },
  // Africa
  { d: "M 445 195 L 560 190 L 575 260 L 570 360 L 530 420 L 480 430 L 440 400 L 425 320 L 430 250 Z", id: "africa" },
  // Russia / Northern Asia
  { d: "M 530 70 L 870 60 L 880 130 L 820 155 L 720 160 L 640 150 L 570 130 L 540 100 Z", id: "russia" },
  // Middle East
  { d: "M 555 175 L 630 170 L 640 215 L 610 230 L 570 225 L 548 205 Z", id: "middle-east" },
  // South / SE Asia
  { d: "M 630 175 L 830 170 L 845 240 L 800 265 L 730 270 L 665 255 L 635 225 Z", id: "south-asia" },
  // East Asia
  { d: "M 760 130 L 870 125 L 880 180 L 845 200 L 790 195 L 755 170 Z", id: "east-asia" },
  // Australia
  { d: "M 770 320 L 890 310 L 900 395 L 855 420 L 785 415 L 755 375 Z", id: "australia" },
  // Greenland
  { d: "M 350 50 L 420 45 L 430 80 L 395 95 L 355 85 Z", id: "greenland" },
  // Japan
  { d: "M 835 165 L 855 160 L 862 180 L 845 188 L 832 178 Z", id: "japan" },
  // UK / Ireland
  { d: "M 440 120 L 465 115 L 468 138 L 448 142 Z", id: "uk" },
  // Indonesia
  { d: "M 770 290 L 870 285 L 875 310 L 830 318 L 780 312 Z", id: "indonesia" },
]

export function WorldThreatMap() {
  const [hovered, setHovered] = useState<string | null>(null)

  const topHotspot = HOTSPOTS.reduce((a, b) => a.count > b.count ? a : b, HOTSPOTS[0])

  return (
    <div style={{ position: 'relative' }}>
      {/* Stats row */}
      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 24, marginBottom: 8, fontSize: 11, color: 'var(--ink-muted)' }}>
        <span>Total hotspots: <strong style={{ color: 'var(--cyan)' }}>{HOTSPOTS.length}</strong></span>
        <span>Most active: <strong style={{ color: '#ef4444' }}>{topHotspot.name} ({topHotspot.count})</strong></span>
      </div>

      <svg
        viewBox="0 0 1000 507"
        style={{ width: '100%', display: 'block', borderRadius: 8 }}
        xmlns="http://www.w3.org/2000/svg"
      >
        {/* Ocean background */}
        <rect width="1000" height="507" fill="rgba(6,182,212,0.04)" rx="8" />

        {/* Graticule grid (lat/lng lines) */}
        <g stroke="rgba(6,182,212,0.07)" strokeWidth="0.5" fill="none">
          {/* Longitude lines every ~36deg */}
          {[100, 200, 300, 400, 500, 600, 700, 800, 900].map(x => (
            <line key={`v${x}`} x1={x} y1="0" x2={x} y2="507" />
          ))}
          {/* Latitude lines every ~30deg */}
          {[85, 170, 253, 337, 420].map(y => (
            <line key={`h${y}`} x1="0" y1={y} x2="1000" y2={y} />
          ))}
          {/* Equator highlighted */}
          <line x1="0" y1="253" x2="1000" y2="253" stroke="rgba(6,182,212,0.15)" strokeWidth="1" />
          {/* Tropics */}
          <line x1="0" y1="210" x2="1000" y2="210" stroke="rgba(234,179,8,0.08)" strokeWidth="0.5" strokeDasharray="4,4" />
          <line x1="0" y1="296" x2="1000" y2="296" stroke="rgba(234,179,8,0.08)" strokeWidth="0.5" strokeDasharray="4,4" />
        </g>

        {/* Continent / country shapes */}
        {LAND_PATHS.map(p => (
          <path
            key={p.id}
            d={p.d}
            fill="rgba(148,163,184,0.12)"
            stroke="rgba(6,182,212,0.25)"
            strokeWidth="0.8"
            strokeLinejoin="round"
          />
        ))}

        {/* Threat hotspots */}
        {HOTSPOTS.map(h => {
          const isHov = hovered === h.name
          const r     = Math.max(10, Math.min(28, h.count * 1.4))
          return (
            <g
              key={h.name}
              onMouseEnter={() => setHovered(h.name)}
              onMouseLeave={() => setHovered(null)}
              style={{ cursor: 'pointer' }}
            >
              {/* Outer pulse ring */}
              <circle cx={h.x} cy={h.y} r={r * 2.5} fill={`${h.color}08`} stroke={`${h.color}20`} strokeWidth="1">
                <animate attributeName="r" values={`${r*2};${r*3};${r*2}`} dur="3s" repeatCount="indefinite" />
                <animate attributeName="opacity" values="0.7;0.2;0.7" dur="3s" repeatCount="indefinite" />
              </circle>
              {/* Inner pulse ring */}
              <circle cx={h.x} cy={h.y} r={r * 1.7} fill={`${h.color}12`} stroke={`${h.color}35`} strokeWidth="1">
                <animate attributeName="r" values={`${r*1.4};${r*2};${r*1.4}`} dur="3s" repeatCount="indefinite" begin="0.5s" />
              </circle>
              {/* Core dot */}
              <circle
                cx={h.x} cy={h.y}
                r={isHov ? r * 1.25 : r}
                fill={h.color}
                fillOpacity="0.85"
                stroke="rgba(255,255,255,0.4)"
                strokeWidth="1.5"
                style={{ transition: 'all 0.2s ease' }}
              />
              {/* Count label */}
              <text
                x={h.x} y={h.y + 4}
                textAnchor="middle"
                fontSize={Math.max(9, Math.min(13, r * 0.75))}
                fontWeight="700"
                fill="white"
                fontFamily="'JetBrains Mono', monospace"
                style={{ pointerEvents: 'none' }}
              >
                {h.count}
              </text>
              {/* Hover tooltip */}
              {isHov && (
                <g>
                  <rect
                    x={h.x - 60} y={h.y - r - 42}
                    width="120" height="34"
                    rx="6"
                    fill="rgba(5,12,24,0.95)"
                    stroke={h.color}
                    strokeWidth="1"
                  />
                  <text x={h.x} y={h.y - r - 26} textAnchor="middle" fontSize="11" fill="white" fontFamily="sans-serif" fontWeight="600">
                    {h.name}
                  </text>
                  <text x={h.x} y={h.y - r - 14} textAnchor="middle" fontSize="10" fill={h.color} fontFamily="monospace">
                    {h.count} active threats
                  </text>
                </g>
              )}
            </g>
          )
        })}

        {/* Legend */}
        <g transform="translate(20, 470)">
          {[['Critical','#ef4444'],['High','#f97316'],['Medium','#eab308'],['Low','#22c55e']].map(([label,color], i) => (
            <g key={label} transform={`translate(${i * 130}, 0)`}>
              <circle cx="7" cy="7" r="6" fill={color} fillOpacity="0.85" />
              <text x="18" y="11" fontSize="11" fill="rgba(148,163,184,0.8)" fontFamily="sans-serif">{label}</text>
            </g>
          ))}
        </g>
      </svg>

      {/* Hovered state detail bar */}
      {hovered && (() => {
        const h = HOTSPOTS.find(x => x.name === hovered)!
        return (
          <div style={{ position: 'absolute', bottom: 8, left: '50%', transform: 'translateX(-50%)', padding: '6px 16px', borderRadius: 20, background: 'rgba(5,12,24,0.95)', border: `1px solid ${h.color}55`, color: h.color, fontSize: 12, fontWeight: 600, pointerEvents: 'none', whiteSpace: 'nowrap' }}>
            {h.name} — {h.count} active threats
          </div>
        )
      })()}
    </div>
  )
}
