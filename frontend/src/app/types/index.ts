



// ─────────────────────────────────────────────────────────────────────────────
// Domain Enums  (mirror backend src/models/orm/base.py)
// ─────────────────────────────────────────────────────────────────────────────
export type SeverityLevel   = 'low' | 'medium' | 'high' | 'critical'
export type ThreatCategory  =
  | 'malware_ransomware' | 'data_breach' | 'phishing_fraud'
  | 'vulnerability_exploit' | 'insider_threat' | 'apt' | 'other'
export type SourceType =
  | 'news' | 'cve' | 'mitre' | 'cisa' | 'social_media' | 'dark_web' | 'rss' | 'manual'
export type EntityType =
  | 'PERSON' | 'ORG' | 'LOC' | 'MALWARE' | 'CVE' | 'IP'
  | 'DOMAIN' | 'HASH' | 'URL' | 'CAMPAIGN' | 'THREAT_ACTOR'
export type ReportStatus    = 'draft' | 'generated' | 'published'
export type FeedbackAction  = 'approved' | 'rejected' | 'edited'
export type NavPage =
  | 'dashboard' | 'threats' | 'alerts' | 'entities'
  | 'reports'   | 'copilot' | 'analytics' | 'settings'

// ─────────────────────────────────────────────────────────────────────────────
// Threat
// ─────────────────────────────────────────────────────────────────────────────
export interface IOC            { type: string; value: string }
export interface MitreTechnique { technique_id: string; source: string }

export interface Threat {
  id: string
  title: string
  summary?: string
  category: ThreatCategory
  severity: SeverityLevel
  risk_score?:  number
  likelihood?:  number
  impact?:      number
  confidence?:  number
  iocs:             IOC[]
  mitre_techniques: MitreTechnique[]
  affected_sectors: string[]
  source_url?:  string
  source_type?: SourceType
  detected_at:  string
  analyst_verified: boolean
}

export interface ThreatListResponse {
  total:     number
  page:      number
  page_size: number
  items:     Threat[]
}

export interface ThreatFeedback {
  action:              FeedbackAction
  notes?:              string
  corrected_severity?: SeverityLevel
  corrected_category?: ThreatCategory
}

// ─────────────────────────────────────────────────────────────────────────────
// Entity / Knowledge Graph
// ─────────────────────────────────────────────────────────────────────────────
export interface Entity {
  id:          string
  name:        string
  entity_type: EntityType
  aliases:     string[]
  description?: string
  first_seen:  string
  last_seen:   string
  threat_count: number
}

export interface GraphNode { id: string; name: string; entity_type: string; threat_count: number }
export interface GraphEdge { source: string; target: string; relationship: string; confidence: number }
export interface EntityGraph { nodes: GraphNode[]; edges: GraphEdge[] }

// ─────────────────────────────────────────────────────────────────────────────
// Alert
// ─────────────────────────────────────────────────────────────────────────────
export interface Alert {
  id:          string
  threat_id:   string
  title:       string
  description?: string
  severity:    SeverityLevel
  is_read:     boolean
  created_at:  string
}

// ─────────────────────────────────────────────────────────────────────────────
// Report
// ─────────────────────────────────────────────────────────────────────────────
export interface Report {
  id:           string
  title:        string
  summary?:     string
  status:       ReportStatus
  created_by:   string
  created_at:   string
  published_at?: string
  file_path?:   string
}

export interface ReportCreatePayload {
  title:      string
  threat_ids?: string[]
  format?:    'pdf' | 'docx' | 'json'
}

// ─────────────────────────────────────────────────────────────────────────────
// Analytics
// ─────────────────────────────────────────────────────────────────────────────
export interface ThreatTrendPoint { date: string; total: number; high: number; medium: number; low: number }
export interface CategoryCount    { category: string; count: number; percentage: number }
export interface AnalyticsSummary {
  total_threats:     number
  high_severity:     number
  new_alerts:        number
  monitored_sources: number
  reports_generated: number
  trend_data:            ThreatTrendPoint[]
  category_distribution: CategoryCount[]
  top_threat_actors:     { name: string; count: number }[]
  source_distribution:   { source: string; count: number; percentage: number }[]
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Copilot / Chat
// ─────────────────────────────────────────────────────────────────────────────
export interface ChatMessage    { role: 'user' | 'assistant'; content: string; timestamp?: string }
export interface CopilotSource  { id: string; title: string; source_url: string; similarity: number; detected_at?: string }
export interface CopilotRequest { query: string; conversation_history: ChatMessage[]; max_context_docs?: number }
export interface CopilotResponse { answer: string; sources: CopilotSource[]; follow_up_questions: string[] }

// ─────────────────────────────────────────────────────────────────────────────
// Shared UI
// ─────────────────────────────────────────────────────────────────────────────
export interface FilterState { severity?: SeverityLevel; category?: ThreatCategory; search?: string; page: number; pageSize: number }
export interface IngestionStatus { status: string; last_run?: string; documents_ingested: number; threats_detected: number }
