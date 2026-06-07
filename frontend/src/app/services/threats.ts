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
