import { useQuery } from '@tanstack/react-query'
import { threatsService } from '../services/threats'
import type { ThreatListParams } from '../services/threats'

export function useThreats(params: ThreatListParams = {}) {
  return useQuery({
    queryKey:        ['threats', params],
    queryFn:         () => threatsService.list(params),
    staleTime:       30_000,
    refetchInterval: 60_000,
  })
}

export function useThreat(id: string) {
  return useQuery({
    queryKey: ['threat', id],
    queryFn:  () => threatsService.get(id),
    enabled:  !!id,
  })
}
