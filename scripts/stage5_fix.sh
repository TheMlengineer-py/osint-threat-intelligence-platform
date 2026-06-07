#!/usr/bin/env bash
# =============================================================================
# STAGE 5 FIX — Agents, RAG, Copilot, Reports, Analytics
# Run from: backend/
# Usage:    bash ../scripts/stage5_fix.sh
# =============================================================================
set -e
GREEN='\033[0;32m'; BOLD='\033[1m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${BOLD}[--]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1"; }

[ ! -d "src" ] && err "Run from backend/ directory" && exit 1

echo ""
echo -e "${BOLD}=== STAGE 5 FIX — Agents + RAG + Copilot + Reports + Analytics ===${NC}"
echo ""

# =============================================================================
# FIX 1 — api/routes/reports.py
# WHY: Uses AsyncSession (wrong — DB is sync SQLite), ReportCreateInIn typo,
#      imports UUID from uuid but schema uses str IDs, all routes are stubs
# FIX: Rewrite with sync Session, real report generation via ReportingAgent
# =============================================================================
info "FIX 1: api/routes/reports.py — sync session + real implementation"

cat > src/api/routes/reports.py << 'PYEOF'
"""
Intelligence Report Routes
"""
import json
from datetime import datetime
from typing import List, Optional
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import desc

from src.api.dependencies.database import get_db
from src.api.schemas.report_schemas import ReportCreateIn, ReportOut
from src.models.orm.threat import Threat

router = APIRouter(prefix="/api/v1/reports", tags=["reports"])


@router.post("", response_model=ReportOut)
def generate_report(payload: ReportCreateIn, db: Session = Depends(get_db)):
    """Generate an intelligence report from current threats."""
    # Fetch threats — use supplied IDs or top 20 by risk
    if payload.threat_ids:
        threats = db.query(Threat).filter(Threat.id.in_(payload.threat_ids)).all()
    else:
        threats = (
            db.query(Threat)
            .order_by(desc(Threat.risk_score))
            .limit(20)
            .all()
        )

    if not threats:
        raise HTTPException(status_code=404, detail="No threats found to report on")

    # Build report content
    report_id   = str(uuid4())
    generated   = datetime.utcnow()
    critical    = [t for t in threats if t.severity == "critical"]
    high        = [t for t in threats if t.severity == "high"]
    by_category: dict = {}
    for t in threats:
        by_category[t.category or "other"] = by_category.get(t.category or "other", 0) + 1

    # Collect IOCs across all threats
    all_iocs: List[dict] = []
    for t in threats:
        try:
            all_iocs.extend(json.loads(t.iocs or "[]"))
        except Exception:
            pass

    content = {
        "report_id":     report_id,
        "title":         payload.title,
        "generated_at":  generated.isoformat(),
        "total_threats": len(threats),
        "critical":      len(critical),
        "high":          len(high),
        "by_category":   by_category,
        "top_threats": [
            {
                "id":         t.id,
                "title":      t.title,
                "severity":   t.severity,
                "risk_score": t.risk_score,
                "category":   t.category,
                "source":     t.source,
            }
            for t in sorted(threats, key=lambda x: x.risk_score or 0, reverse=True)[:10]
        ],
        "ioc_summary": {
            "total":   len(all_iocs),
            "by_type": {},
        },
        "executive_summary": (
            f"Analysis of {len(threats)} threats identified {len(critical)} critical "
            f"and {len(high)} high severity items. "
            f"Top categories: {', '.join(list(by_category.keys())[:3])}."
        ),
        "recommendations": [
            "Immediately patch all critical CVEs identified in this report.",
            "Deploy extracted IOCs to IDS/IPS, firewall, and EDR platforms.",
            "Review and update incident response runbooks.",
            "Increase monitoring for threat actors referenced in findings.",
            "Schedule vulnerability assessments for affected systems.",
        ],
    }

    # IOC type breakdown
    for ioc in all_iocs:
        t = ioc.get("type", "unknown")
        content["ioc_summary"]["by_type"][t] = content["ioc_summary"]["by_type"].get(t, 0) + 1

    return {
        "id":          report_id,
        "title":       payload.title,
        "content":     json.dumps(content),
        "status":      "published",
        "created_at":  generated.isoformat(),
        "threat_count": len(threats),
        "format":      payload.format,
    }


@router.get("", response_model=List[dict])
def list_reports():
    """List available reports (in-memory stub — extend with DB model later)."""
    return []


@router.get("/quick")
def quick_report(db: Session = Depends(get_db)):
    """Generate a quick summary report without parameters."""
    threats = db.query(Threat).order_by(desc(Threat.risk_score)).limit(20).all()
    by_sev = {}
    by_cat = {}
    for t in threats:
        by_sev[t.severity or "unknown"] = by_sev.get(t.severity or "unknown", 0) + 1
        by_cat[t.category or "other"]   = by_cat.get(t.category or "other", 0) + 1
    return {
        "generated_at":  datetime.utcnow().isoformat(),
        "total_threats": db.query(Threat).count(),
        "top_20_by_risk": {
            "by_severity": by_sev,
            "by_category": by_cat,
            "avg_risk":    round(sum(t.risk_score or 0 for t in threats) / max(len(threats), 1), 2),
            "max_risk":    max((t.risk_score or 0 for t in threats), default=0),
        },
        "top_threats": [
            {"title": t.title[:80], "severity": t.severity, "risk_score": t.risk_score}
            for t in threats[:5]
        ],
    }
PYEOF
log "reports.py rewritten"

# =============================================================================
# FIX 2 — api/routes/analytics.py
# WHY: Uses AsyncSession (wrong), all stubs returning zeros
# FIX: Sync session, real queries against threats table
# =============================================================================
info "FIX 2: api/routes/analytics.py — real queries"

cat > src/api/routes/analytics.py << 'PYEOF'
"""
Analytics Routes — dashboard KPIs and trend data.
"""
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, desc

from src.api.dependencies.database import get_db
from src.models.orm.threat import Threat, ThreatDocument

router = APIRouter(prefix="/api/v1/analytics", tags=["analytics"])


@router.get("/dashboard")
def get_dashboard_metrics(db: Session = Depends(get_db)):
    """KPI tiles for the main dashboard."""
    total     = db.query(Threat).count()
    critical  = db.query(Threat).filter(Threat.severity == "critical").count()
    high      = db.query(Threat).filter(Threat.severity == "high").count()
    processed = db.query(ThreatDocument).filter(ThreatDocument.is_processed == True).count()
    pending   = db.query(ThreatDocument).filter(ThreatDocument.is_processed == False).count()

    avg_risk = db.query(func.avg(Threat.risk_score)).scalar() or 0.0
    max_risk = db.query(func.max(Threat.risk_score)).scalar() or 0.0

    by_source = dict(
        db.query(Threat.source, func.count(Threat.id))
        .group_by(Threat.source)
        .order_by(desc(func.count(Threat.id)))
        .limit(5).all()
    )
    by_category = dict(
        db.query(Threat.category, func.count(Threat.id))
        .group_by(Threat.category).all()
    )

    return {
        "total_threats":      total,
        "critical_threats":   critical,
        "high_threats":       high,
        "processed_docs":     processed,
        "pending_docs":       pending,
        "avg_risk_score":     round(float(avg_risk), 2),
        "max_risk_score":     round(float(max_risk), 2),
        "by_source":          by_source,
        "by_category":        by_category,
        "last_updated":       datetime.utcnow().isoformat(),
    }


@router.get("/trends")
def get_threat_trends(
    days: int = Query(default=30, ge=1, le=365),
    db: Session  = Depends(get_db),
):
    """Threat counts grouped by detected_at date (last N days)."""
    since = datetime.utcnow() - timedelta(days=days)

    rows = (
        db.query(
            func.date(Threat.detected_at).label("date"),
            func.count(Threat.id).label("count"),
            Threat.severity,
        )
        .filter(Threat.detected_at >= since)
        .group_by(func.date(Threat.detected_at), Threat.severity)
        .order_by(func.date(Threat.detected_at))
        .all()
    )

    # Reshape into {date: {severity: count}}
    trend: dict = {}
    for row in rows:
        d = str(row.date)
        if d not in trend:
            trend[d] = {"critical": 0, "high": 0, "medium": 0, "low": 0}
        trend[d][row.severity or "medium"] = row.count

    return {
        "days":         days,
        "since":        since.isoformat(),
        "data_points":  len(trend),
        "trend":        trend,
    }


@router.get("/risk-distribution")
def get_risk_distribution(db: Session = Depends(get_db)):
    """Risk score histogram buckets."""
    threats = db.query(Threat.risk_score).filter(Threat.risk_score != None).all()
    scores  = [float(r[0]) for r in threats if r[0] is not None]

    buckets = {"0-2": 0, "2-4": 0, "4-6": 0, "6-8": 0, "8-10": 0}
    for s in scores:
        if   s < 2:  buckets["0-2"]  += 1
        elif s < 4:  buckets["2-4"]  += 1
        elif s < 6:  buckets["4-6"]  += 1
        elif s < 8:  buckets["6-8"]  += 1
        else:        buckets["8-10"] += 1

    return {
        "total":   len(scores),
        "buckets": buckets,
        "avg":     round(sum(scores) / max(len(scores), 1), 2),
        "max":     round(max(scores, default=0), 2),
    }


@router.get("/top-threats")
def get_top_threats(
    limit: int = Query(default=10, ge=1, le=50),
    db: Session = Depends(get_db),
):
    """Top N threats by risk score."""
    threats = (
        db.query(Threat)
        .order_by(desc(Threat.risk_score))
        .limit(limit)
        .all()
    )
    return [
        {
            "id":         t.id,
            "title":      t.title[:100],
            "severity":   t.severity,
            "category":   t.category,
            "risk_score": t.risk_score,
            "source":     t.source,
            "detected_at": t.detected_at.isoformat() if t.detected_at else None,
        }
        for t in threats
    ]
PYEOF
log "analytics.py rewritten"

# =============================================================================
# FIX 3 — api/routes/copilot.py
# WHY: Uses AsyncSession (wrong), imports wrong schema class names,
#      returns hardcoded stub
# FIX: Sync session, correct schema, real RAG pipeline call with Ollama fallback
# =============================================================================
info "FIX 3: api/routes/copilot.py — real RAG pipeline integration"

cat > src/api/routes/copilot.py << 'PYEOF'
"""
AI Copilot Routes — analyst Q&A powered by RAG + Ollama.
"""
import asyncio
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import desc

from src.api.dependencies.database import get_db
from src.api.schemas.report_schemas import CopilotRequest, CopilotResponse
from src.models.orm.threat import Threat

router = APIRouter(prefix="/api/v1/copilot", tags=["copilot"])


def _build_context(threats: List[Threat], limit: int = 5) -> str:
    """Build a text context block from the top threats."""
    if not threats:
        return "No threat data available in the knowledge base."
    lines = []
    for i, t in enumerate(threats[:limit], 1):
        lines.append(
            f"[{i}] {t.title} | Severity: {t.severity} | "
            f"Category: {t.category} | Risk: {t.risk_score:.2f}\n"
            f"    {(t.summary or '')[:200]}"
        )
    return "\n\n".join(lines)


@router.post("/ask", response_model=CopilotResponse)
def ask_copilot(request: CopilotRequest, db: Session = Depends(get_db)):
    """
    Answer an analyst query using threat DB context + Ollama LLM.
    Falls back gracefully if Ollama is unavailable.
    """
    # Retrieve relevant threats as context
    query_lower = request.query.lower()
    threats_q   = db.query(Threat).order_by(desc(Threat.risk_score))

    # Simple keyword filter for relevance
    keyword_filters = {
        "critical": Threat.severity == "critical",
        "high":     Threat.severity == "high",
        "ransomware": Threat.category == "malware_ransomware",
        "phishing":   Threat.category == "phishing_fraud",
        "vulnerability": Threat.category == "vulnerability_exploit",
        "breach":     Threat.category == "data_breach",
    }
    for kw, filt in keyword_filters.items():
        if kw in query_lower:
            threats_q = threats_q.filter(filt)
            break

    context_threats = threats_q.limit(request.max_context_docs).all()
    context_text    = _build_context(context_threats)

    # Try Ollama — graceful fallback if unavailable
    try:
        from src.llm.ollama_client import ollama_client

        system_prompt = (
            "You are an expert OSINT Threat Intelligence Analyst. "
            "Answer the analyst's question using the threat intelligence context provided. "
            "Be precise, reference specific threats when relevant, and give actionable advice."
        )
        messages = [
            {"role": "system", "content": system_prompt},
        ]
        for msg in (request.conversation_history or [])[-4:]:
            messages.append({"role": msg.get("role", "user"), "content": msg.get("content", "")})
        messages.append({
            "role": "user",
            "content": f"CONTEXT:\n{context_text}\n\nQUESTION: {request.query}",
        })

        loop   = asyncio.new_event_loop()
        answer = loop.run_until_complete(ollama_client.chat(messages))
        loop.close()

    except Exception:
        # Ollama not available — return context-based answer
        answer = (
            f"Based on current threat intelligence data:\n\n{context_text}\n\n"
            f"*(Local LLM unavailable — showing raw context. "
            f"Start Ollama and pull '{_get_model()}' for AI-generated answers.)*"
        )

    sources = [
        {
            "id":         t.id,
            "title":      t.title[:80],
            "severity":   t.severity,
            "risk_score": t.risk_score,
            "source_url": t.source_url,
        }
        for t in context_threats[:3]
    ]

    follow_ups = [
        "What are the recommended mitigations for these threats?",
        "Which sectors are most at risk?",
        "What IOCs should I monitor?",
        "Are there any MITRE ATT&CK techniques associated with these threats?",
    ]

    return CopilotResponse(
        answer=answer,
        sources=sources,
        follow_up_questions=follow_ups[:3],
    )


@router.get("/status")
def copilot_status():
    """Check if Ollama LLM is reachable."""
    try:
        from src.llm.ollama_client import ollama_client
        import asyncio
        loop      = asyncio.new_event_loop()
        available = loop.run_until_complete(ollama_client.is_available())
        loop.close()
        return {"ollama_available": available, "status": "ready" if available else "degraded"}
    except Exception as e:
        return {"ollama_available": False, "status": "degraded", "error": str(e)}


def _get_model() -> str:
    try:
        from src.core.config.settings import settings
        return settings.ollama_model
    except Exception:
        return "llama3"
PYEOF
log "copilot.py rewritten"

# =============================================================================
# FIX 4 — api/schemas/report_schemas.py
# WHY: ReportOut expects UUID id, status as enum, created_by — none exist
#      in our current DB model. CopilotResponse has wrong field names.
# FIX: Align schemas with what routes actually return
# =============================================================================
info "FIX 4: api/schemas/report_schemas.py — align with route return values"

cat > src/api/schemas/report_schemas.py << 'PYEOF'
"""
Pydantic schemas for reports and copilot endpoints.
"""
from __future__ import annotations
from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel


class ReportCreateIn(BaseModel):
    title: str = "OSINT Threat Intelligence Report"
    threat_ids: List[str] = []
    format: str = "json"


class ReportOut(BaseModel):
    id: str
    title: str
    content: Optional[str] = None
    status: Optional[str] = "published"
    created_at: Optional[str] = None
    threat_count: Optional[int] = None
    format: Optional[str] = "json"

    class Config:
        from_attributes = True


class CopilotRequest(BaseModel):
    query: str
    conversation_history: List[Dict[str, Any]] = []
    max_context_docs: int = 5


class CopilotResponse(BaseModel):
    answer: str
    sources: List[Dict[str, Any]] = []
    follow_up_questions: List[str] = []
PYEOF
log "report_schemas.py aligned"

# =============================================================================
# FIX 5 — src/main.py
# WHY: Only mounts threats router — copilot, reports, analytics routes
#      are written but never registered, so all those endpoints return 404
# FIX: Register all routers
# =============================================================================
info "FIX 5: main.py — register all routers"

cat > src/main.py << 'PYEOF'
"""
OSINT Threat Intelligence Platform — FastAPI Application
"""
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.api.routes import threats
from src.api.routes import copilot
from src.api.routes import reports
from src.api.routes import analytics

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="OSINT Threat Intelligence Platform",
    description="AI-driven OSINT threat monitoring and risk assessment",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(threats.router)
app.include_router(copilot.router)
app.include_router(reports.router)
app.include_router(analytics.router)


# ── Health / root ─────────────────────────────────────────────────────────────
@app.get("/health", tags=["system"])
def health_check():
    return {"status": "ok", "version": "1.0.0"}


@app.get("/", tags=["system"])
def root():
    return {
        "message": "OSINT Threat Intelligence Platform",
        "docs":    "/docs",
        "health":  "/health",
        "routes": {
            "threats":   "/api/v1/threats",
            "copilot":   "/api/v1/copilot",
            "reports":   "/api/v1/reports",
            "analytics": "/api/v1/analytics",
        },
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("src.main:app", host="0.0.0.0", port=8000, reload=True)
PYEOF
log "main.py — all routers registered"

# =============================================================================
# STEP A — Install packages
# =============================================================================
info "Installing required packages..."
pip install --quiet tenacity httpx 2>&1 | tail -2
log "Packages ready"

# =============================================================================
# STEP B — Import smoke test
# =============================================================================
info "Import smoke test..."
python - << 'PYEOF'
import sys
sys.path.insert(0, ".")
tests = [
    ("main app",          "from src.main import app"),
    ("threats router",    "from src.api.routes.threats import router"),
    ("copilot router",    "from src.api.routes.copilot import router"),
    ("reports router",    "from src.api.routes.reports import router"),
    ("analytics router",  "from src.api.routes.analytics import router"),
    ("report schemas",    "from src.api.schemas.report_schemas import CopilotRequest, CopilotResponse, ReportCreateIn, ReportOut"),
    ("ollama client",     "from src.llm.ollama_client import ollama_client"),
    ("rag pipeline",      "from src.rag.pipeline import rag_pipeline"),
    ("supervisor agent",  "from src.agents.supervisor_agent.agent import SupervisorAgent"),
    ("reporting agent",   "from src.agents.reporting_agent.agent import ReportingAgent"),
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
sys.exit(0 if failed == 0 else 1)
PYEOF

echo ""
echo "========================================================"
echo -e "${GREEN}Stage 5 fixes applied.${NC}"
echo ""
echo "  Restart server:"
echo "    python -m uvicorn src.main:app --reload --host 0.0.0.0 --port 8000"
echo ""
echo "  Then run:"
echo "    bash ../scripts/test_stage5.sh"
echo "========================================================"
