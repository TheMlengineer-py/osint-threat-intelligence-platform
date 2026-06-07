import contextlib

"""
Intelligence Report Routes
"""

import json
from datetime import datetime
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import desc
from sqlalchemy.orm import Session

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
        threats = db.query(Threat).order_by(desc(Threat.risk_score)).limit(20).all()

    if not threats:
        raise HTTPException(status_code=404, detail="No threats found to report on")

    # Build report content
    report_id = str(uuid4())
    generated = datetime.utcnow()
    critical = [t for t in threats if t.severity == "critical"]
    high = [t for t in threats if t.severity == "high"]
    by_category: dict = {}
    for t in threats:
        by_category[t.category or "other"] = by_category.get(t.category or "other", 0) + 1

    # Collect IOCs across all threats
    all_iocs: list[dict] = []
    for t in threats:
        with contextlib.suppress(Exception):
            all_iocs.extend(json.loads(t.iocs or "[]"))

    content = {
        "report_id": report_id,
        "title": payload.title,
        "generated_at": generated.isoformat(),
        "total_threats": len(threats),
        "critical": len(critical),
        "high": len(high),
        "by_category": by_category,
        "top_threats": [
            {
                "id": t.id,
                "title": t.title,
                "severity": t.severity,
                "risk_score": t.risk_score,
                "category": t.category,
                "source": t.source,
            }
            for t in sorted(threats, key=lambda x: x.risk_score or 0, reverse=True)[:10]
        ],
        "ioc_summary": {
            "total": len(all_iocs),
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
        "id": report_id,
        "title": payload.title,
        "content": json.dumps(content),
        "status": "published",
        "created_at": generated.isoformat(),
        "threat_count": len(threats),
        "format": payload.format,
    }


@router.get("", response_model=list[dict])
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
        by_cat[t.category or "other"] = by_cat.get(t.category or "other", 0) + 1
    return {
        "generated_at": datetime.utcnow().isoformat(),
        "total_threats": db.query(Threat).count(),
        "top_20_by_risk": {
            "by_severity": by_sev,
            "by_category": by_cat,
            "avg_risk": round(sum(t.risk_score or 0 for t in threats) / max(len(threats), 1), 2),
            "max_risk": max((t.risk_score or 0 for t in threats), default=0),
        },
        "top_threats": [
            {"title": t.title[:80], "severity": t.severity, "risk_score": t.risk_score}
            for t in threats[:5]
        ],
    }
