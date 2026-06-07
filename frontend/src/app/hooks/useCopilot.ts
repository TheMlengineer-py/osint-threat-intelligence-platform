import { useMutation, useQuery } from '@tanstack/react-query'
import { apiClient } from '../services/api'
import type { CopilotRequest } from '../types'

export function useCopilotStatus() {
  return useQuery({
    queryKey:  ['copilot', 'status'],
    queryFn:   () => apiClient.get('/copilot/status').then(r => r.data),
    staleTime: 30_000,
    refetchInterval: 60_000,
  })
}

export function useCopilotChat() {
  return useMutation({
    mutationFn: (req: CopilotRequest) =>
      apiClient.post('/copilot/ask', req).then(r => r.data),
  })
}
