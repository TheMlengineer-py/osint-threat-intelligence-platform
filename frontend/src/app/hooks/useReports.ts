import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { reportsService, type ReportPayload } from '../services/reports'

export function useReports() {
  return useQuery({
    queryKey:  ['reports'],
    queryFn:   () => reportsService.list(),
    staleTime: 60_000,
  })
}

export function useQuickReport() {
  return useQuery({
    queryKey:  ['reports', 'quick'],
    queryFn:   () => reportsService.quick(),
    staleTime: 60_000,
  })
}

export function useGenerateReport() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (payload: ReportPayload) => reportsService.generate(payload),
    onSuccess:  () => qc.invalidateQueries({ queryKey: ['reports'] }),
  })
}
