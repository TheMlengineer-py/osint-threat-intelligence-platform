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
