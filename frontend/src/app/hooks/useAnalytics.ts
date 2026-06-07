import { useQuery } from '@tanstack/react-query'
import { analyticsService } from '../services/analytics'

export function useAnalyticsSummary() {
  return useQuery({
    queryKey:        ['analytics', 'summary'],
    queryFn:         () => analyticsService.dashboard(),
    staleTime:       30_000,
    refetchInterval: 60_000,
  })
}

export function useAnalyticsTrends(days = 30) {
  return useQuery({
    queryKey:  ['analytics', 'trends', days],
    queryFn:   () => analyticsService.trends(days),
    staleTime: 60_000,
  })
}

export function useRiskDistribution() {
  return useQuery({
    queryKey:  ['analytics', 'risk-distribution'],
    queryFn:   () => analyticsService.riskDistribution(),
    staleTime: 60_000,
  })
}

export function useTopThreats(limit = 10) {
  return useQuery({
    queryKey:        ['analytics', 'top-threats', limit],
    queryFn:         () => analyticsService.topThreats(limit),
    staleTime:       30_000,
    refetchInterval: 60_000,
  })
}
