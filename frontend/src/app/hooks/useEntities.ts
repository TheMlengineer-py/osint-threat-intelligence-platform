import { useQuery } from '@tanstack/react-query'
import { entitiesService } from '../services/entities'
import type { EntityType } from '../types'

export function useEntities(entityType?: EntityType, limit = 50) {
  return useQuery({
    queryKey: ['entities', entityType, limit],
    queryFn:  () => entitiesService.list(entityType, limit),
    staleTime: 60_000,
  })
}

export function useEntityGraph(limit = 60) {
  return useQuery({
    queryKey: ['entity-graph', limit],
    queryFn:  () => entitiesService.graph(limit),
    staleTime: 120_000,
  })
}
