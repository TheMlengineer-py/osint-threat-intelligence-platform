import React, { createContext, useContext, useState, useEffect } from 'react'

type Theme = 'dark' | 'light'
interface ThemeCtx { theme: Theme; toggle: () => void }
const ThemeContext = createContext<ThemeCtx>({ theme: 'dark', toggle: () => {} })

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setTheme] = useState<Theme>(
    () => (localStorage.getItem('osint-theme') as Theme) ?? 'dark'
  )

  useEffect(() => {
    localStorage.setItem('osint-theme', theme)
    const r = document.documentElement
    if (theme === 'dark') {
      r.style.setProperty('--bg-primary',   '#050c18')
      r.style.setProperty('--bg-secondary', '#0a1628')
      r.style.setProperty('--bg-card',      '#0d1f35')
      r.style.setProperty('--bg-elevated',  '#112540')
      r.style.setProperty('--bg-border',    '#1a3050')
      r.style.setProperty('--cyan',         '#06b6d4')
      r.style.setProperty('--ink-primary',  '#e2e8f0')
      r.style.setProperty('--ink-secondary','#94a3b8')
      r.style.setProperty('--ink-muted',    '#475569')
    } else {
      r.style.setProperty('--bg-primary',   '#f0f4f8')
      r.style.setProperty('--bg-secondary', '#e2e8f0')
      r.style.setProperty('--bg-card',      '#ffffff')
      r.style.setProperty('--bg-elevated',  '#f8fafc')
      r.style.setProperty('--bg-border',    '#cbd5e1')
      r.style.setProperty('--cyan',         '#0284c7')
      r.style.setProperty('--ink-primary',  '#0f172a')
      r.style.setProperty('--ink-secondary','#334155')
      r.style.setProperty('--ink-muted',    '#64748b')
    }
  }, [theme])

  const toggle = () => setTheme(t => t === 'dark' ? 'light' : 'dark')
  return <ThemeContext.Provider value={{ theme, toggle }}>{children}</ThemeContext.Provider>
}

export const useTheme = () => useContext(ThemeContext)
