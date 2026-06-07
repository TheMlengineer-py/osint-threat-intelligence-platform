import React from 'react'
import { useNavigate } from 'react-router-dom'

export default function NotFound() {
  const navigate = useNavigate()
  return (
    <div className="flex flex-col items-center justify-center h-full gap-4">
      <p className="text-6xl font-bold text-slate-700">404</p>
      <p className="text-slate-400">Page not found</p>
      <button onClick={() => navigate('/dashboard')} className="px-4 py-2 rounded text-sm" style={{ background: 'rgba(6,182,212,0.2)', color: 'var(--cyan)' }}>
        Back to Dashboard
      </button>
    </div>
  )
}
