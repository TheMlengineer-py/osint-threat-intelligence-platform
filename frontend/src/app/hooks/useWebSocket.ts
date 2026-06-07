import { useEffect, useRef, useState, useCallback } from 'react'

export type WSStatus = 'connecting' | 'open' | 'closed' | 'error'

interface UseWebSocketOptions {
  onMessage?: (data: unknown) => void
  onOpen?: () => void
  onClose?: () => void
  onError?: (e: Event) => void
  reconnectDelay?: number
  maxRetries?: number
}

export function useWebSocket(url: string | null, options: UseWebSocketOptions = {}) {
  const { onMessage, onOpen, onClose, onError, reconnectDelay = 3000, maxRetries = 5 } = options
  const wsRef = useRef<WebSocket | null>(null)
  const retriesRef = useRef(0)
  const [status, setStatus] = useState<WSStatus>('closed')

  const connect = useCallback(() => {
    if (!url) return
    setStatus('connecting')
    const ws = new WebSocket(url)
    wsRef.current = ws

    ws.onopen = () => {
      retriesRef.current = 0
      setStatus('open')
      onOpen?.()
    }
    ws.onmessage = (e) => {
      try { onMessage?.(JSON.parse(e.data as string)) }
      catch { onMessage?.(e.data) }
    }
    ws.onerror = (e) => {
      setStatus('error')
      onError?.(e)
    }
    ws.onclose = () => {
      setStatus('closed')
      onClose?.()
      if (retriesRef.current < maxRetries) {
        retriesRef.current++
        setTimeout(connect, reconnectDelay)
      }
    }
  }, [url, onMessage, onOpen, onClose, onError, reconnectDelay, maxRetries])

  useEffect(() => {
    connect()
    return () => { wsRef.current?.close() }
  }, [connect])

  const send = useCallback((data: unknown) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify(data))
    }
  }, [])

  return { status, send }
}
