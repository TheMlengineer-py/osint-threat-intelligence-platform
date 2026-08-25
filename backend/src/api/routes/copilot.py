"""
AI Copilot Routes — powered by Groq API.
"""

import json

from fastapi import APIRouter, Depends
from sqlalchemy import desc
from sqlalchemy.orm import Session

from src.api.dependencies.database import get_db
from src.api.schemas.report_schemas import CopilotRequest, CopilotResponse
from src.llm.groq_client import groq_client
from src.models.orm.threat import Threat

router = APIRouter(prefix="/api/v1/copilot", tags=["copilot"])

_SYSTEM_PROMPT = (
    "You are an expert OSINT Threat Intelligence Analyst in a Security Operations Centre. "
    "You have access to real-time threat data including CVEs, malware campaigns, and IOCs. "
    "Be precise, reference specific threat IDs when relevant, and give actionable recommendations. "
    "If information is not in the context provided, say so clearly."
)


def _build_context(threats: list[Threat]) -> str:
    if not threats:
        return "No relevant threats found in the knowledge base."
    lines = []
    for i, t in enumerate(threats[:5], 1):
        iocs_preview = ""
        try:
            iocs = json.loads(t.iocs or "[]")
            if iocs:
                parts = [ioc.get("type", "") + ":" + ioc.get("value", "") for ioc in iocs[:3]]
                iocs_preview = " | IOCs: " + ", ".join(parts)
        except Exception:
            pass
        lines.append(
            f"[{i}] {t.title}\n"
            f"    Severity: {t.severity} | Category: {t.category} | "
            f"Risk: {t.risk_score:.2f} | Source: {t.source}"
            f"{iocs_preview}\n"
            f"    {(t.summary or '')[:300]}"
        )
    return "\n\n".join(lines)


def _filter_threats(db: Session, query: str, limit: int) -> list[Threat]:
    q = db.query(Threat).filter(Threat.is_active is True)
    keyword_filters = {
        "critical": Threat.severity == "critical",
        "high": Threat.severity == "high",
        "ransomware": Threat.category == "malware_ransomware",
        "malware": Threat.category == "malware_ransomware",
        "phishing": Threat.category == "phishing_fraud",
        "vulnerability": Threat.category == "vulnerability_exploit",
        "cve": Threat.category == "vulnerability_exploit",
        "breach": Threat.category == "data_breach",
        "apt": Threat.category == "apt",
    }
    for kw, filt in keyword_filters.items():
        if kw in query.lower():
            q = q.filter(filt)
            break
    return q.order_by(desc(Threat.risk_score)).limit(limit).all()


@router.post("/ask", response_model=CopilotResponse)
async def ask_copilot(request: CopilotRequest, db: Session = Depends(get_db)):
    """Answer analyst query using threat DB context + Groq LLaMA 3."""
    context_threats = _filter_threats(db, request.query, request.max_context_docs)
    context_text = _build_context(context_threats)

    messages = [{"role": "system", "content": _SYSTEM_PROMPT}]
    for msg in (request.conversation_history or [])[-6:]:
        role = msg.get("role", "user")
        content = msg.get("content", "")
        if role in ("user", "assistant") and content:
            messages.append({"role": role, "content": content})
    messages.append(
        {
            "role": "user",
            "content": "THREAT CONTEXT:\n" + context_text + "\n\nQUESTION: " + request.query,
        }
    )

    answer = await groq_client.chat(messages)

    sources = [
        {
            "id": t.id,
            "title": t.title[:100],
            "severity": t.severity,
            "risk_score": round(t.risk_score or 0, 2),
            "source_url": t.source_url or "",
            "category": t.category,
        }
        for t in context_threats[:3]
    ]

    return CopilotResponse(
        answer=answer,
        sources=sources,
        follow_up_questions=[
            "What are the recommended mitigations?",
            "Which sectors are most at risk?",
            "What IOCs should I monitor?",
        ],
    )


@router.get("/status")
def copilot_status():
    """Check Groq API status."""
    available = groq_client.is_available
    return {
        "provider": "groq",
        "model": groq_client.model_name,
        "available": available,
        "key_configured": available,
        "status": "ready" if available else "no_key",
        "ollama_available": available,
    }


@router.get("/models")
def list_models():
    return {
        "current": groq_client.model_name,
        "available": [
            {"id": "openai/gpt-oss-20b", "description": "Recommended — fast MoE, tool use, 20B params"},
            {"id": "llama3-70b-8192",    "description": "Best quality, slower"},
            {"id": "mixtral-8x7b-32768", "description": "Long context 32k tokens"},
        ],
    }
