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
