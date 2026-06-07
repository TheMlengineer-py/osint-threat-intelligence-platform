# ── hooks/useWebSocket.ts ─────────────────────────────────────────────────────
cat > /home/claude/osint-threat-intelligence/frontend/src/app/hooks/useWebSocket.ts << 'EOF'
import { useEffect, useRef, useCallback } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { createWebSocket } from '../services/api'

/**
 * Opens a WebSocket to /ws and invalidates React Query caches
 * when the backend broadcasts an ingestion_complete event.
 * Reconnects automatically after 5 s on unexpected close.
 */
export function useWebSocket() {
  const wsRef = useRef<WebSocket | null>(null)
  const qc = useQueryClient()

  const onMessage = useCallback((data: unknown) => {
    const msg = data as { type?: string }
    if (msg?.type === 'ingestion_complete') {
      qc.invalidateQueries({ queryKey: ['threats'] })
      qc.invalidateQueries({ queryKey: ['analytics'] })
      qc.invalidateQueries({ queryKey: ['ingestion'] })
    }
  }, [qc])

  useEffect(() => {
    function connect() {
      wsRef.current = createWebSocket(onMessage, () => {
        setTimeout(connect, 5_000)
      })
    }
    connect()
    return () => { wsRef.current?.close() }
  }, [onMessage])
}
