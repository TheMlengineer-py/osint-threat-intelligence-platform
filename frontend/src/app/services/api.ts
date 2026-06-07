/**
 * Base Axios client.
 * In development:   reads VITE_API_BASE_URL from .env  (default: localhost:8000)
 * In production:    Netlify/Render injects the env var at build time
 * NEVER hardcode IPs here.
 */
import axios from 'axios'

const BASE_URL = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000'

export const apiClient = axios.create({
  baseURL: `${BASE_URL}/api/v1`,
  headers: { 'Content-Type': 'application/json' },
  timeout: 30_000,
})

apiClient.interceptors.response.use(
  r => r,
  err => {
    console.error('[API]', err.response?.status, err.config?.url, err.message)
    return Promise.reject(err)
  }
)

export const WS_BASE = import.meta.env.VITE_WS_URL ?? 'ws://localhost:8000'
