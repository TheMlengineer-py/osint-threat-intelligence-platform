import { describe, it, expect } from 'vitest'
import {
  timeAgo, formatCount, truncate, capitalise, getSeverity, getCategoryLabel
} from '@/utils/ui'

describe('timeAgo', () => {
  it('returns just now for < 1 minute', () => {
    expect(timeAgo(new Date().toISOString())).toBe('just now')
  })
  it('returns minutes', () => {
    expect(timeAgo(new Date(Date.now() - 25 * 60_000).toISOString())).toBe('25m ago')
  })
  it('returns hours', () => {
    expect(timeAgo(new Date(Date.now() - 4 * 3600_000).toISOString())).toBe('4h ago')
  })
  it('returns days', () => {
    expect(timeAgo(new Date(Date.now() - 3 * 86400_000).toISOString())).toBe('3d ago')
  })
})

describe('formatCount', () => {
  it('raw below 1000', () => { expect(formatCount(999)).toBe('999') })
  it('K suffix',       () => { expect(formatCount(2500)).toBe('2.5K') })
  it('M suffix',       () => { expect(formatCount(1_500_000)).toBe('1.5M') })
  it('handles zero',   () => { expect(formatCount(0)).toBe('0') })
})

describe('truncate', () => {
  it('truncates with ellipsis', () => {
    expect(truncate('Hello World', 5)).toBe('Hello…')
  })
  it('no truncation within limit', () => {
    expect(truncate('Hi', 10)).toBe('Hi')
  })
})

describe('capitalise', () => {
  it('first letter', () => { expect(capitalise('hello')).toBe('Hello') })
  it('handles uppercase', () => { expect(capitalise('WORLD')).toBe('WORLD') })
})

describe('getSeverity', () => {
  it('critical is red', () => {
    const c = getSeverity('critical')
    expect(c.colour).toBe('#ef4444')
    expect(c.label).toBe('CRITICAL')
  })
  it('low is green', () => { expect(getSeverity('low').colour).toBe('#22c55e') })
  it('unknown falls back', () => { expect(getSeverity('unknown' as any)).toBeDefined() })
})

describe('getCategoryLabel', () => {
  it('maps malware_ransomware', () => {
    expect(getCategoryLabel('malware_ransomware')).toBe('Malware / Ransomware')
  })
  it('maps apt', () => {
    expect(getCategoryLabel('apt')).toBe('APT / Nation-State')
  })
  it('returns raw for unknown', () => {
    expect(getCategoryLabel('xyz' as any)).toBe('xyz')
  })
})
