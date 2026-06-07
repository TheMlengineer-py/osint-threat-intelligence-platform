import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { apiClient } from '../services/api'

export function useIngestionStatus() {
  return useQuery({
    queryKey:        ['ingestion', 'status'],
    queryFn:         () => apiClient.get('/threats/ingest/status').then(r => r.data),
    staleTime:       15_000,
    refetchInterval: 30_000,
  })
}

export function useTriggerIngestion() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async () => {
      await apiClient.post('/threats/ingest')
      await apiClient.post('/threats/process')
      return true
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['threats'] })
      qc.invalidateQueries({ queryKey: ['analytics'] })
      qc.invalidateQueries({ queryKey: ['ingestion'] })
      qc.invalidateQueries({ queryKey: ['reports'] })
      qc.invalidateQueries({ queryKey: ['copilot'] })
    },
    onError: (err) => console.error('[Ingestion]', err),
  })
}
