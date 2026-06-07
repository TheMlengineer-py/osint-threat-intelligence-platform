import { apiClient } from './api'
import type { EntityType } from '../types'

export const entitiesService = {
  list: (entityType?: EntityType, limit = 50) =>
    apiClient.get('/api/v1/entities', {
      params: { ...(entityType && { entity_type: entityType }), limit }
    }).then(r => r.data),

  graph: (limit = 60) =>
    apiClient.get('/api/v1/entities/graph', { params: { limit } }).then(r => r.data),
}
