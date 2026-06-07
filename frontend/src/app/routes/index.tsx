import React, { Suspense, lazy } from 'react'
import { Routes, Route, Navigate } from 'react-router-dom'
import MainLayout from '@/layouts/MainLayout'

const Dashboard = lazy(() => import('@/pages/Dashboard'))
const Threats = lazy(() => import('@/pages/Threats'))
const Alerts = lazy(() => import('@/pages/Alerts'))
const Entities = lazy(() => import('@/pages/Entities'))
const Reports = lazy(() => import('@/pages/Reports'))
const Copilot = lazy(() => import('@/pages/Copilot'))
const Analytics = lazy(() => import('@/pages/Analytics'))
const Settings = lazy(() => import('@/pages/Settings'))
const NotFound = lazy(() => import('@/pages/NotFound'))

function PageLoader() {
  return (
    <MainLayout>
      <div className="flex h-full items-center justify-center">
        <div className="w-6 h-6 rounded-full border-2 border-cyan-500 border-t-transparent animate-spin" />
      </div>
    </MainLayout>
  )
}

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  return <MainLayout>{children}</MainLayout>
}

export function AppRoutes() {
  return (
    <Suspense fallback={<PageLoader />}>
      <Routes>
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
        <Route path="/dashboard" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
        <Route path="/threats" element={<ProtectedRoute><Threats /></ProtectedRoute>} />
        <Route path="/alerts" element={<ProtectedRoute><Alerts /></ProtectedRoute>} />
        <Route path="/entities" element={<ProtectedRoute><Entities /></ProtectedRoute>} />
        <Route path="/reports" element={<ProtectedRoute><Reports /></ProtectedRoute>} />
        <Route path="/copilot" element={<ProtectedRoute><Copilot /></ProtectedRoute>} />
        <Route path="/analytics" element={<ProtectedRoute><Analytics /></ProtectedRoute>} />
        <Route path="/settings" element={<ProtectedRoute><Settings /></ProtectedRoute>} />
        <Route path="*" element={<MainLayout><NotFound /></MainLayout>} />
      </Routes>
    </Suspense>
  )
}
