import '@testing-library/jest-dom'
import { vi } from 'vitest'
import { setupServer } from 'msw/node'
import { http, HttpResponse } from 'msw'

Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation(q => ({
    matches: false, media: q, onchange: null,
    addListener: vi.fn(), removeListener: vi.fn(),
    addEventListener: vi.fn(), removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
})

Object.defineProperty(window, 'ResizeObserver', {
  writable: true,
  value: vi.fn(() => ({ observe: vi.fn(), unobserve: vi.fn(), disconnect: vi.fn() })),
})

const MOCK_DASHBOARD = {
  total_threats: 75, critical_threats: 7, high_threats: 2,
  processed_docs: 75, pending_docs: 0,
  avg_risk_score: 1.88, max_risk_score: 6.27,
  by_source: { 'CISA/NVD': 50, 'BleepingComputer': 15, 'SecurityWeek': 10 },
  by_category: { vulnerability_exploit: 37, other: 34, malware_ransomware: 4 },
  last_updated: new Date().toISOString(),
}

export const server = setupServer(
  http.get('/api/v1/analytics/dashboard',      () => HttpResponse.json(MOCK_DASHBOARD)),
  http.get('/api/v1/analytics/top-threats',    () => HttpResponse.json([
    { id: '1', title: 'Critical CVE Exploit in WordPress', severity: 'critical',
      category: 'vulnerability_exploit', risk_score: 6.27, source: 'CISA',
      detected_at: new Date().toISOString() },
    { id: '2', title: 'LockBit Ransomware Campaign',       severity: 'high',
      category: 'malware_ransomware',    risk_score: 5.10, source: 'BleepingComputer',
      detected_at: new Date().toISOString() },
  ])),
  http.get('/api/v1/analytics/risk-distribution', () => HttpResponse.json({
    total: 75, avg: 1.88, max: 6.27,
    buckets: { '0-2': 66, '2-4': 2, '4-6': 0, '6-8': 7, '8-10': 0 },
  })),
  http.get('/api/v1/analytics/trends',         () => HttpResponse.json({ trend: {}, data_points: 0, days: 30 })),
  http.get('/api/v1/threats/',                 () => HttpResponse.json([
    { id: '1', title: 'Test Threat', severity: 'high', category: 'malware_ransomware',
      risk_score: 5.5, source: 'RSS', detected_at: new Date().toISOString(),
      indicators_of_compromise: [{ type: 'ipv4', value: '1.2.3.4' }] },
  ])),
  http.get('/api/v1/threats/ingest/status',    () => HttpResponse.json({ total_threats: 75, processed_docs: 75, pending_docs: 0 })),
  http.get('/api/v1/copilot/status',           () => HttpResponse.json({ groq_available: false, model: 'none', status: 'no_key' })),
  http.post('/api/v1/copilot/ask',             () => HttpResponse.json({
    answer: 'Top threats include CVE exploits and ransomware.',
    sources: [{ id: '1', title: 'CISA Advisory', similarity: 0.92, risk_score: 6.27 }],
    follow_up_questions: ['What IOCs?'],
    provider: 'context_only',
  })),
  http.get('/api/v1/reports/quick',            () => HttpResponse.json({
    total_threats: 75, generated_at: new Date().toISOString(),
    top_20_by_risk: { avg_risk: 3.49, max_risk: 6.27 },
  })),
  http.get('/health',                          () => HttpResponse.json({ status: 'healthy', version: '1.0.0' })),
)

beforeAll(() => server.listen({ onUnhandledRequest: 'warn' }))
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
