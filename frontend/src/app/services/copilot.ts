/**
 * AI Copilot API service — maps to /api/v1/copilot/* endpoints.
 */
import { apiClient } from './api'
import type { CopilotRequest, CopilotResponse } from '../types'

export const copilotService = {
  ask(body: CopilotRequest): Promise<CopilotResponse> {
    return apiClient.post<CopilotResponse>('/copilot/ask', body).then(r => r.data)
  },

  // Alias for hooks that use .chat()
  chat(body: CopilotRequest): Promise<CopilotResponse> {
    return copilotService.ask(body)
  },

  status(): Promise<{ ollama_available: boolean; status: string }> {
    return apiClient.get('/copilot/status').then(r => r.data)
  },
}
