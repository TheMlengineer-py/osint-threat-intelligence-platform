#!/usr/bin/env bash
# =============================================================================
# GROQ COPILOT FIX — replaces Ollama entirely with Groq API
# Run from: project root (osint-threat-intelligence-platform/)
# Usage:    bash scripts/groq_fix.sh
# =============================================================================
set -e
GREEN='\033[0;32m'; BOLD='\033[1m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${BOLD}[--]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1"; }

[ ! -d "backend" ] && err "Run from project root" && exit 1

echo ""
echo -e "${BOLD}=== GROQ COPILOT — Remove Ollama, wire Groq end-to-end ===${NC}"
echo ""

# =============================================================================
# STEP 1 — Add Groq settings to .env and settings.py
# =============================================================================
info "STEP 1: Adding Groq config to .env and settings.py"

# Add to .env (only if not already there)
if ! grep -q "GROQ_API_KEY" backend/.env; then
cat >> backend/.env << 'EOF'

# ── Groq LLM (cloud — replaces Ollama) ───────────────────────────────────────
GROQ_API_KEY=
GROQ_MODEL=llama3-8b-8192
LLM_PROVIDER=groq
EOF
fi
log ".env — Groq vars added (fill in GROQ_API_KEY)"

# Patch settings.py — add Groq fields after Ollama block
if ! grep -q "groq_api_key" backend/src/core/config/settings.py; then
python3 - << 'PYEOF'
path = "backend/src/core/config/settings.py"
with open(path) as f:
    content = f.read()

groq_block = """
    # ── Groq LLM (cloud — replaces Ollama) ───────────────────────────────────
    groq_api_key: str = ""
    groq_model:   str = "llama3-8b-8192"
    llm_provider: str = "groq"   # "groq" | "ollama"
"""

# Insert after the Ollama block
content = content.replace(
    '    # ── Embedding ─────────────────────────────────────────────────────────────',
    groq_block + '    # ── Embedding ─────────────────────────────────────────────────────────────'
)
with open(path, "w") as f:
    f.write(content)
print("  settings.py patched")
PYEOF
fi
log "settings.py — Groq fields added"

# =============================================================================
# STEP 2 — Write src/llm/groq_client.py (replaces ollama_client.py)
# =============================================================================
info "STEP 2: Writing backend/src/llm/groq_client.py"

cat > backend/src/llm/groq_client.py << 'PYEOF'
"""
Groq LLM client — OpenAI-compatible API.
Uses llama3-8b-8192 by default (fast, free tier: 14,400 req/day).
Drop-in replacement for ollama_client — same .chat() and .is_available() interface.
"""
import logging
from typing import Dict, List, Optional

import httpx

from src.core.config.settings import settings

logger = logging.getLogger(__name__)

_GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
_MODELS_URL = "https://api.groq.com/openai/v1/models"

# Available Groq models (free tier)
GROQ_MODELS = {
    "llama3-8b-8192":      "LLaMA 3 8B  — fast, great for Q&A",
    "llama3-70b-8192":     "LLaMA 3 70B — best quality, slower",
    "mixtral-8x7b-32768":  "Mixtral 8x7B — long context (32k)",
    "gemma2-9b-it":        "Gemma 2 9B  — Google, instruction-tuned",
}


class GroqClient:
    """Async Groq API client with graceful fallback."""

    def __init__(self):
        self._headers: Optional[Dict] = None

    def _get_headers(self) -> Dict:
        if not self._headers:
            self._headers = {
                "Authorization": f"Bearer {settings.groq_api_key}",
                "Content-Type":  "application/json",
            }
        return self._headers

    async def chat(
        self,
        messages: List[Dict],
        temperature: float = 0.3,
        max_tokens: int = 1024,
    ) -> str:
        """
        Send a chat completion request to Groq.
        Same interface as ollama_client.chat().
        """
        if not settings.groq_api_key:
            return self._no_key_fallback()

        payload = {
            "model":       settings.groq_model,
            "messages":    messages,
            "temperature": temperature,
            "max_tokens":  max_tokens,
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                resp = await client.post(
                    _GROQ_URL,
                    headers=self._get_headers(),
                    json=payload,
                )
                resp.raise_for_status()
                data = resp.json()
                content = data["choices"][0]["message"]["content"]
                logger.info(
                    "Groq response",
                    model=settings.groq_model,
                    tokens=data.get("usage", {}).get("total_tokens"),
                )
                return content

        except httpx.HTTPStatusError as e:
            if e.response.status_code == 401:
                logger.error("Groq: invalid API key")
                return "**Groq API key invalid** — update GROQ_API_KEY in backend/.env"
            if e.response.status_code == 429:
                logger.warning("Groq: rate limit hit")
                return "**Groq rate limit reached** — free tier: 30 req/min, 14,400/day. Try again shortly."
            logger.error(f"Groq HTTP error: {e.response.status_code}")
            return f"**Groq API error {e.response.status_code}** — {e.response.text[:200]}"

        except httpx.TimeoutException:
            logger.warning("Groq: request timed out")
            return "**Groq request timed out** — please try again."

        except Exception as exc:
            logger.error(f"Groq unexpected error: {exc}")
            return f"**LLM error** — {str(exc)[:200]}"

    async def is_available(self) -> bool:
        """Check if Groq API key is valid and service is reachable."""
        if not settings.groq_api_key:
            return False
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                r = await client.get(
                    _MODELS_URL,
                    headers=self._get_headers(),
                )
                return r.status_code == 200
        except Exception:
            return False

    async def get_model_info(self) -> Dict:
        """Return current model info for the status endpoint."""
        available = await self.is_available()
        return {
            "provider":   "groq",
            "model":      settings.groq_model,
            "available":  available,
            "model_desc": GROQ_MODELS.get(settings.groq_model, settings.groq_model),
            "key_set":    bool(settings.groq_api_key),
        }

    @staticmethod
    def _no_key_fallback() -> str:
        return (
            "**Groq API key not configured.**\n\n"
            "To activate the AI Copilot:\n"
            "1. Get a free key at https://console.groq.com\n"
            "2. Add `GROQ_API_KEY=your_key` to `backend/.env`\n"
            "3. Restart the backend server\n\n"
            "Free tier: 14,400 requests/day — more than enough for this platform."
        )


groq_client = GroqClient()

# Backward-compatible alias so any code importing ollama_client still works
ollama_client = groq_client
PYEOF
log "groq_client.py written"

# =============================================================================
# STEP 3 — Rewrite copilot.py — Groq only, no Ollama references
# =============================================================================
info "STEP 3: Rewriting copilot.py — Groq only"

cat > backend/src/api/routes/copilot.py << 'PYEOF'
"""
AI Copilot Routes — powered entirely by Groq API.
Retrieves relevant threats from DB as context, sends to Groq LLaMA 3.
"""
import asyncio
from typing import List

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import desc

from src.api.dependencies.database import get_db
from src.api.schemas.report_schemas import CopilotRequest, CopilotResponse
from src.models.orm.threat import Threat
from src.llm.groq_client import groq_client
from src.core.config.settings import settings

router = APIRouter(prefix="/api/v1/copilot", tags=["copilot"])

_SYSTEM_PROMPT = (
    "You are an expert OSINT Threat Intelligence Analyst working in a Security Operations Centre (SOC). "
    "You have access to a curated database of real-time threats, CVEs, malware campaigns, and IOCs. "
    "When answering:\n"
    "- Be precise and factual. Reference specific CVE IDs, threat actors, or malware families when relevant.\n"
    "- Give actionable recommendations where appropriate.\n"
    "- Distinguish confirmed intelligence from analytical assessment.\n"
    "- If information is not in the context, say so clearly rather than guessing.\n"
    "- Keep responses concise and structured for a security analyst audience."
)

_FOLLOW_UPS = [
    "What are the recommended mitigations for these threats?",
    "Which sectors or industries are most at risk?",
    "What IOCs should I add to my detection rules?",
    "Are there MITRE ATT&CK techniques associated with these threats?",
    "What is the likelihood of exploitation in the next 30 days?",
]


def _build_context(threats: List[Threat], limit: int = 5) -> str:
    if not threats:
        return "No relevant threats found in the knowledge base for this query."
    lines = []
    for i, t in enumerate(threats[:limit], 1):
        iocs_preview = ""
        try:
            import json
            iocs = json.loads(t.iocs or "[]")
            if iocs:
                iocs_preview = f"\n    IOCs: {', '.join(f'{x[\"type\"]}:{x[\"value\"]}' for x in iocs[:3])}"
        except Exception:
            pass
        lines.append(
            f"[{i}] {t.title}\n"
            f"    Severity: {t.severity} | Category: {t.category} | "
            f"Risk Score: {t.risk_score:.2f} | Source: {t.source}"
            f"{iocs_preview}\n"
            f"    {(t.summary or '')[:300]}"
        )
    return "\n\n".join(lines)


def _filter_threats(db: Session, query: str, limit: int) -> List[Threat]:
    """Return relevant threats based on query keywords."""
    q = db.query(Threat).filter(Threat.is_active == True)

    keyword_filters = {
        "critical":      Threat.severity == "critical",
        "high":          Threat.severity == "high",
        "ransomware":    Threat.category == "malware_ransomware",
        "malware":       Threat.category == "malware_ransomware",
        "phishing":      Threat.category == "phishing_fraud",
        "vulnerability": Threat.category == "vulnerability_exploit",
        "cve":           Threat.category == "vulnerability_exploit",
        "breach":        Threat.category == "data_breach",
        "apt":           Threat.category == "apt",
    }

    query_lower = query.lower()
    for kw, filt in keyword_filters.items():
        if kw in query_lower:
            q = q.filter(filt)
            break

    return q.order_by(desc(Threat.risk_score)).limit(limit).all()


@router.post("/ask", response_model=CopilotResponse)
def ask_copilot(request: CopilotRequest, db: Session = Depends(get_db)):
    """
    Answer analyst query using threat DB context + Groq LLaMA 3.
    """
    # Retrieve relevant threats as RAG context
    context_threats = _filter_threats(db, request.query, request.max_context_docs)
    context_text    = _build_context(context_threats)

    # Build message chain
    messages = [{"role": "system", "content": _SYSTEM_PROMPT}]

    # Include recent conversation history (last 6 messages)
    for msg in (request.conversation_history or [])[-6:]:
        role    = msg.get("role", "user")
        content = msg.get("content", "")
        if role in ("user", "assistant") and content:
            messages.append({"role": role, "content": content})

    # Augmented query with context
    messages.append({
        "role": "user",
        "content": (
            f"THREAT INTELLIGENCE CONTEXT:\n{context_text}\n\n"
            f"ANALYST QUESTION: {request.query}"
        ),
    })

    # Call Groq
    loop   = asyncio.new_event_loop()
    answer = loop.run_until_complete(groq_client.chat(messages))
    loop.close()

    sources = [
        {
            "id":         t.id,
            "title":      t.title[:100],
            "severity":   t.severity,
            "risk_score": round(t.risk_score or 0, 2),
            "source_url": t.source_url or "",
            "category":   t.category,
        }
        for t in context_threats[:3]
    ]

    return CopilotResponse(
        answer=answer,
        sources=sources,
        follow_up_questions=_FOLLOW_UPS[:3],
    )


@router.get("/status")
def copilot_status():
    """Check Groq API availability and configuration."""
    loop = asyncio.new_event_loop()
    info = loop.run_until_complete(groq_client.get_model_info())
    loop.close()

    return {
        "provider":         "groq",
        "model":            info["model"],
        "model_desc":       info["model_desc"],
        "available":        info["available"],
        "key_configured":   info["key_set"],
        "status":           "ready" if info["available"] else (
                            "no_key" if not info["key_set"] else "unreachable"
        ),
        # Keep backward compat with frontend checking ollama_available
        "ollama_available": info["available"],
    }


@router.get("/models")
def list_models():
    """List available Groq models."""
    from src.llm.groq_client import GROQ_MODELS
    return {
        "current": settings.groq_model,
        "available": [
            {"id": k, "description": v}
            for k, v in GROQ_MODELS.items()
        ],
    }
PYEOF
log "copilot.py rewritten — Groq only"

# =============================================================================
# STEP 4 — Update frontend Copilot page — remove Ollama references
# =============================================================================
info "STEP 4: Updating frontend Copilot page — Groq branding"

cat > frontend/src/app/pages/Copilot/index.tsx << 'PYEOF'
import React, { useState, useRef, useEffect } from 'react'
import { Bot, Send, Zap, ExternalLink } from 'lucide-react'
import { useCopilotChat, useCopilotStatus } from '@/hooks'
import type { ChatMessage } from '@/types'

function StatusBanner({ status }: { status: any }) {
  if (!status) return null

  if (status.status === 'ready') {
    return (
      <div className="flex items-center gap-3 px-4 py-2 rounded-lg text-sm"
        style={{ background: 'rgba(34,197,94,0.08)', border: '1px solid rgba(34,197,94,0.2)', color: '#22c55e' }}>
        <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse shrink-0" />
        <span>Groq API connected — <strong>{status.model}</strong> · {status.model_desc}</span>
      </div>
    )
  }

  if (status.status === 'no_key') {
    return (
      <div className="rounded-xl p-4 space-y-3"
        style={{ background: 'rgba(234,179,8,0.08)', border: '1px solid rgba(234,179,8,0.25)' }}>
        <div className="flex items-center gap-2">
          <Zap size={16} style={{ color: '#eab308' }} />
          <span className="font-semibold text-sm" style={{ color: '#eab308' }}>
            Groq API key not configured
          </span>
        </div>
        <p className="text-xs text-slate-400">
          Add your free Groq API key to activate full AI responses.
          Free tier: 14,400 requests/day — no credit card required.
        </p>
        <div className="rounded-lg px-3 py-2 font-mono text-xs"
          style={{ background: 'rgba(0,0,0,0.3)', color: 'var(--cyan)' }}>
          {'# backend/.env'}<br />
          {'GROQ_API_KEY=your_key_here'}
        </div>
        <a href="https://console.groq.com" target="_blank" rel="noopener noreferrer"
          className="inline-flex items-center gap-1.5 text-xs font-medium"
          style={{ color: '#eab308' }}>
          Get free API key at console.groq.com
          <ExternalLink size={11} />
        </a>
      </div>
    )
  }

  return null
}

function SourceCard({ source }: { source: any }) {
  const sevColor: Record<string, string> = {
    critical: '#ef4444', high: '#f97316', medium: '#eab308', low: '#22c55e'
  }
  return (
    <div className="rounded-lg px-3 py-2 text-xs"
      style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)' }}>
      <div className="flex items-center gap-2 mb-1">
        <span className="font-mono uppercase text-[10px] font-bold px-1.5 py-0.5 rounded"
          style={{ background: `${sevColor[source.severity] ?? '#64748b'}22`, color: sevColor[source.severity] ?? '#64748b' }}>
          {source.severity}
        </span>
        <span className="font-mono text-[10px]" style={{ color: 'var(--cyan)' }}>
          {source.risk_score?.toFixed(2)}
        </span>
      </div>
      <p className="text-slate-300 leading-tight truncate">{source.title}</p>
    </div>
  )
}

export default function Copilot() {
  const [input, setInput]     = useState('')
  const [history, setHistory] = useState<ChatMessage[]>([])
  const bottomRef             = useRef<HTMLDivElement>(null)
  const { data: status }      = useCopilotStatus()
  const chat                  = useCopilotChat()

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [history])

  const send = () => {
    if (!input.trim() || chat.isPending) return
    const q = input.trim()
    setInput('')
    const userMsg: ChatMessage = {
      role: 'user', content: q, timestamp: new Date().toISOString()
    }
    setHistory(h => [...h, userMsg])

    chat.mutate(
      { query: q, conversation_history: history, max_context_docs: 5 },
      {
        onSuccess: res => {
          setHistory(h => [...h, {
            role: 'assistant',
            content: res.answer,
            timestamp: new Date().toISOString(),
            sources: res.sources,
          } as any])
        },
        onError: () => {
          setHistory(h => [...h, {
            role: 'assistant',
            content: 'An error occurred. Please check your Groq API key and try again.',
            timestamp: new Date().toISOString(),
          }])
        },
      }
    )
  }

  const suggestions = [
    'What are the top critical threats right now?',
    'Summarise recent ransomware activity',
    'Which CVEs have the highest risk scores?',
    'What IOCs should I add to my detection rules?',
  ]

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center justify-between px-6 py-4 shrink-0"
        style={{ borderBottom: '1px solid rgba(255,255,255,0.08)' }}>
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl flex items-center justify-center"
            style={{ background: 'rgba(6,182,212,0.15)', border: '1px solid rgba(6,182,212,0.3)' }}>
            <Bot size={18} style={{ color: 'var(--cyan)' }} />
          </div>
          <div>
            <h1 className="text-base font-bold text-white">AI Threat Analyst Copilot</h1>
            <p className="text-xs text-slate-500">
              Powered by Groq · {status?.model ?? 'llama3-8b-8192'} · searches your OSINT database
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-full text-xs font-medium"
          style={{
            background: status?.status === 'ready'
              ? 'rgba(34,197,94,0.12)' : 'rgba(234,179,8,0.12)',
            border: `1px solid ${status?.status === 'ready'
              ? 'rgba(34,197,94,0.3)' : 'rgba(234,179,8,0.3)'}`,
            color: status?.status === 'ready' ? '#22c55e' : '#eab308',
          }}>
          <div className={`w-1.5 h-1.5 rounded-full ${status?.status === 'ready' ? 'bg-green-500 animate-pulse' : 'bg-yellow-500'}`} />
          {status?.status === 'ready' ? 'Groq connected' : 'Setup required'}
        </div>
      </div>

      {/* Status banner */}
      {status && status.status !== 'ready' && (
        <div className="px-6 pt-4 shrink-0">
          <StatusBanner status={status} />
        </div>
      )}

      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-6 py-4 space-y-5">
        {history.length === 0 && (
          <div className="flex flex-col items-center justify-center h-full gap-6 text-center">
            <div className="w-16 h-16 rounded-2xl flex items-center justify-center"
              style={{ background: 'rgba(6,182,212,0.08)', border: '1px solid rgba(6,182,212,0.2)' }}>
              <Bot size={28} style={{ color: 'var(--cyan)', opacity: 0.6 }} />
            </div>
            <div>
              <p className="text-white font-medium mb-1">Ask about your threat intelligence</p>
              <p className="text-xs text-slate-500">
                Searches http://localhost:8000 ·{' '}
                {status?.status === 'ready' ? 'Groq AI active' : 'Context-only mode'}
              </p>
            </div>
            <div className="grid grid-cols-2 gap-2 w-full max-w-lg">
              {suggestions.map(s => (
                <button key={s} onClick={() => setInput(s)}
                  className="text-left px-3 py-2.5 rounded-lg text-xs text-slate-400 hover:text-white transition-colors"
                  style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)' }}>
                  {s}
                </button>
              ))}
            </div>
          </div>
        )}

        {history.map((msg, i) => (
          <div key={i} className={`flex gap-3 ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
            {msg.role === 'assistant' && (
              <div className="w-7 h-7 rounded-lg flex items-center justify-center shrink-0 mt-0.5"
                style={{ background: 'rgba(6,182,212,0.15)', border: '1px solid rgba(6,182,212,0.3)' }}>
                <Bot size={13} style={{ color: 'var(--cyan)' }} />
              </div>
            )}
            <div className="flex flex-col gap-2 max-w-[78%]">
              <div className="rounded-2xl px-4 py-3 text-sm leading-relaxed"
                style={msg.role === 'user'
                  ? { background: 'rgba(6,182,212,0.15)', color: 'white', border: '1px solid rgba(6,182,212,0.25)', borderBottomRightRadius: 4 }
                  : { background: 'rgba(255,255,255,0.05)', color: '#cbd5e1', border: '1px solid rgba(255,255,255,0.08)', borderBottomLeftRadius: 4 }}>
                <p className="whitespace-pre-wrap">{msg.content}</p>
              </div>
              {/* Sources */}
              {(msg as any).sources?.length > 0 && (
                <div className="space-y-1.5">
                  <p className="text-[10px] text-slate-600 font-medium uppercase tracking-wider px-1">
                    Sources
                  </p>
                  {(msg as any).sources.map((s: any) => (
                    <SourceCard key={s.id} source={s} />
                  ))}
                </div>
              )}
              <p className="text-[10px] text-slate-600 px-1">
                {new Date(msg.timestamp || '').toLocaleTimeString()}
              </p>
            </div>
          </div>
        ))}

        {chat.isPending && (
          <div className="flex gap-3 justify-start">
            <div className="w-7 h-7 rounded-lg flex items-center justify-center shrink-0"
              style={{ background: 'rgba(6,182,212,0.15)', border: '1px solid rgba(6,182,212,0.3)' }}>
              <Bot size={13} style={{ color: 'var(--cyan)' }} />
            </div>
            <div className="rounded-2xl px-4 py-3" style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.08)' }}>
              <div className="flex gap-1.5 items-center">
                {[0, 1, 2].map(i => (
                  <div key={i} className="w-1.5 h-1.5 rounded-full animate-bounce"
                    style={{ background: 'var(--cyan)', animationDelay: `${i * 0.15}s` }} />
                ))}
                <span className="text-xs text-slate-500 ml-1">Analysing threats…</span>
              </div>
            </div>
          </div>
        )}
        <div ref={bottomRef} />
      </div>

      {/* Input */}
      <div className="px-6 py-4 shrink-0" style={{ borderTop: '1px solid rgba(255,255,255,0.08)' }}>
        <div className="flex gap-3 items-end">
          <div className="flex-1 rounded-2xl px-4 py-3"
            style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)' }}>
            <textarea
              value={input}
              onChange={e => setInput(e.target.value)}
              onKeyDown={e => {
                if (e.key === 'Enter' && !e.shiftKey) {
                  e.preventDefault()
                  send()
                }
              }}
              placeholder="Ask about threats, CVEs, IOCs, risk levels…  (Enter to send)"
              rows={1}
              className="w-full bg-transparent text-sm text-white placeholder-slate-500 outline-none resize-none"
              style={{ lineHeight: '1.5' }}
            />
          </div>
          <button onClick={send}
            disabled={!input.trim() || chat.isPending}
            className="w-10 h-10 rounded-xl flex items-center justify-center transition-all disabled:opacity-40"
            style={{ background: 'rgba(6,182,212,0.2)', border: '1px solid rgba(6,182,212,0.4)', color: 'var(--cyan)' }}>
            <Send size={15} />
          </button>
        </div>
        <p className="text-[10px] text-slate-600 mt-2 text-center">
          Searches http://localhost:8000 ·{' '}
          {status?.status === 'ready'
            ? `Groq ${status.model} active`
            : 'Context-only mode — add GROQ_API_KEY to backend/.env for full AI'}
        </p>
      </div>
    </div>
  )
}
PYEOF
log "Copilot page rewritten — Groq branding, source cards, suggestions"

# =============================================================================
# STEP 5 — Update Settings page to show Groq status
# =============================================================================
info "STEP 5: Updating Settings page — Groq LLM config card"

cat > frontend/src/app/pages/Settings/index.tsx << 'PYEOF'
import React from 'react'
import { ExternalLink, CheckCircle, XCircle, AlertCircle } from 'lucide-react'
import { useCopilotStatus } from '@/hooks'

function StatusDot({ status }: { status: 'connected' | 'warning' | 'inactive' }) {
  const colors = {
    connected: 'bg-green-500',
    warning:   'bg-yellow-500',
    inactive:  'bg-slate-600',
  }
  return <div className={`w-2 h-2 rounded-full shrink-0 ${colors[status]}`} />
}

export default function Settings() {
  const { data: copilot } = useCopilotStatus()

  const groqReady = copilot?.status === 'ready'
  const groqKeySet = copilot?.key_configured

  return (
    <div className="p-6 space-y-6 max-w-3xl">
      <div>
        <h1 className="text-2xl font-bold text-white">Settings</h1>
        <p className="text-slate-400 mt-1">System configuration and service status</p>
      </div>

      {/* LLM Configuration */}
      <div className="rounded-xl p-5 space-y-4"
        style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)' }}>
        <h2 className="text-sm font-semibold text-white flex items-center gap-2">
          🤖 LLM Configuration
        </h2>

        <div className="grid grid-cols-2 gap-3">
          {/* Groq */}
          <div className="rounded-xl p-4 space-y-3"
            style={{
              background: groqReady ? 'rgba(34,197,94,0.05)' : 'rgba(255,255,255,0.02)',
              border: `1px solid ${groqReady ? 'rgba(34,197,94,0.25)' : 'rgba(255,255,255,0.08)'}`,
            }}>
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium text-white">Groq API</span>
              <span className="text-[10px] px-2 py-0.5 rounded font-medium"
                style={{ background: 'rgba(6,182,212,0.15)', color: 'var(--cyan)' }}>
                Production
              </span>
            </div>
            <p className="text-xs text-slate-500">
              {copilot?.model_desc ?? 'Cloud LLM inference — fast, free tier available'}
            </p>
            <div className="flex items-center gap-2">
              <StatusDot status={groqReady ? 'connected' : groqKeySet ? 'warning' : 'inactive'} />
              <span className="text-xs" style={{ color: groqReady ? '#22c55e' : '#eab308' }}>
                {groqReady ? `Active — ${copilot?.model}` : groqKeySet ? 'Key set, unreachable' : 'No API key'}
              </span>
            </div>
            {!groqKeySet && (
              <a href="https://console.groq.com" target="_blank" rel="noopener noreferrer"
                className="inline-flex items-center gap-1 text-xs"
                style={{ color: 'var(--cyan)' }}>
                Get free key <ExternalLink size={10} />
              </a>
            )}
          </div>

          {/* Ollama — shown as deprecated */}
          <div className="rounded-xl p-4 space-y-3 opacity-50"
            style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid rgba(255,255,255,0.06)' }}>
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium text-slate-400">Ollama (Local)</span>
              <span className="text-[10px] px-2 py-0.5 rounded font-medium text-slate-500"
                style={{ background: 'rgba(255,255,255,0.06)' }}>
                Dev only
              </span>
            </div>
            <p className="text-xs text-slate-600">
              phi3 / mistral / llama3 — offline, no cost
            </p>
            <div className="flex items-center gap-2">
              <StatusDot status="inactive" />
              <span className="text-xs text-slate-600">Not used — Groq preferred</span>
            </div>
          </div>
        </div>

        {/* Setup instructions if no key */}
        {!groqKeySet && (
          <div className="rounded-lg p-4 space-y-2"
            style={{ background: 'rgba(234,179,8,0.06)', border: '1px solid rgba(234,179,8,0.2)' }}>
            <p className="text-xs font-medium" style={{ color: '#eab308' }}>
              To activate the AI Copilot
            </p>
            <div className="rounded-lg px-3 py-2 font-mono text-xs space-y-1"
              style={{ background: 'rgba(0,0,0,0.3)', color: 'var(--cyan)' }}>
              <div className="text-slate-500"># 1. Get free key at console.groq.com</div>
              <div># 2. Add to backend/.env:</div>
              <div>GROQ_API_KEY=your_key_here</div>
              <div>GROQ_MODEL=llama3-8b-8192</div>
              <div className="text-slate-500"># 3. Restart backend server</div>
            </div>
          </div>
        )}
      </div>

      {/* System Services */}
      <div className="rounded-xl p-5 space-y-3"
        style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)' }}>
        <h2 className="text-sm font-semibold text-white">System Services</h2>
        {[
          { label: 'Backend API',   value: 'http://localhost:8000', status: 'connected' as const },
          { label: 'Database',      value: 'SQLite — osint.db',     status: 'connected' as const },
          { label: 'NLP Pipeline',  value: 'spaCy en_core_web_sm',  status: 'connected' as const },
          { label: 'Vector Store',  value: 'ChromaDB',              status: 'warning'   as const },
          { label: 'Redis Cache',   value: 'Not configured',        status: 'inactive'  as const },
        ].map(({ label, value, status }) => (
          <div key={label} className="flex items-center justify-between py-2"
            style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
            <div>
              <p className="text-sm text-white">{label}</p>
              <p className="text-xs text-slate-500 mt-0.5">{value}</p>
            </div>
            <div className="flex items-center gap-2">
              <StatusDot status={status} />
              <span className="text-xs capitalize"
                style={{ color: status === 'connected' ? '#22c55e' : status === 'warning' ? '#eab308' : '#64748b' }}>
                {status}
              </span>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
PYEOF
log "Settings page updated — Groq LLM config card"

# =============================================================================
# STEP 6 — Install httpx in backend (already there but verify)
# =============================================================================
info "STEP 6: Verifying packages"
cd backend
pip install --quiet httpx 2>&1 | tail -1
cd ..
log "Packages verified"

# =============================================================================
# STEP 7 — Import smoke test
# =============================================================================
info "STEP 7: Import smoke test"
cd backend
python3 - << 'PYEOF'
import sys
sys.path.insert(0, ".")
tests = [
    ("groq_client",   "from src.llm.groq_client import groq_client, GROQ_MODELS"),
    ("settings",      "from src.core.config.settings import settings; assert hasattr(settings, 'groq_api_key')"),
    ("copilot route", "from src.api.routes.copilot import router"),
]
passed = failed = 0
for name, stmt in tests:
    try:
        exec(stmt)
        print(f"  OK   {name}")
        passed += 1
    except Exception as e:
        print(f"  FAIL {name} -> {e}")
        failed += 1
print(f"\n  {passed} passed, {failed} failed")
PYEOF
cd ..

echo ""
echo "========================================================"
echo -e "${GREEN}Groq copilot wired up.${NC}"
echo ""
echo -e "  ${BOLD}Add your API key:${NC}"
echo "    1. Get free key: https://console.groq.com"
echo "    2. Edit backend/.env:"
echo "       GROQ_API_KEY=gsk_xxxxxxxxxxxxxxxxxxxxxxxx"
echo "    3. Restart backend"
echo ""
echo -e "  ${BOLD}Test:${NC}"
echo '    curl -s -X POST http://localhost:8000/api/v1/copilot/ask \'
echo '      -H "Content-Type: application/json" \'
echo '      -d '"'"'{"query":"What are the top critical threats?","max_context_docs":3}'"'"' \'
echo '      | python3 -m json.tool'
echo "========================================================"
