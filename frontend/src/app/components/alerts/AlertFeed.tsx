import React from 'react'
import AlertCard from './AlertCard'
import { useTopThreats } from '@/hooks'

export default function AlertFeed({ limit = 10 }: { limit?: number }) {
  const { data: threats = [], isLoading } = useTopThreats(limit)

  if (isLoading) return (
    <div className="flex items-center justify-center h-32">
      <div className="w-5 h-5 rounded-full border-2 border-cyan-500 border-t-transparent animate-spin" />
    </div>
  )

  if (!threats.length) return (
    <div className="flex items-center justify-center h-32 text-sm text-slate-500">
      No alerts yet — trigger ingestion to populate.
    </div>
  )

  return (
    <div className="flex flex-col">
      {(threats as any[]).map((t: any) => (
        <AlertCard key={t.id} title={t.title} severity={t.severity}
          source={t.source} createdAt={t.created_at} />
      ))}
    </div>
  )
}
