/**
 * Entities API service.
 * apiClient.baseURL is already ${BASE_URL}/api/v1
 * so all paths here must NOT include /api/v1 again.
 */
import { apiClient } from './api'
import type { EntityType } from '../types'

export const entitiesService = {
  list: (entityType?: EntityType, limit = 50) =>
    apiClient
      .get('/entities/', {
        params: { ...(entityType && { entity_type: entityType }), limit },
      })
      .then(r => r.data),

  graph: (limit = 60) =>
    apiClient
      .get('/entities/graph', { params: { limit } })
      .then(r => r.data),
}
