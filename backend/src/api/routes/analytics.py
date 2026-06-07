"""
Analytics Routes — dashboard KPIs and trend data.
"""

from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import desc, func
from sqlalchemy.orm import Session

from src.api.dependencies.database import get_db
from src.models.orm.threat import Threat, ThreatDocument

router = APIRouter(prefix="/api/v1/analytics", tags=["analytics"])


@router.get("/dashboard")
def get_dashboard_metrics(db: Session = Depends(get_db)):
    """KPI tiles for the main dashboard."""
    total = db.query(Threat).count()
    critical = db.query(Threat).filter(Threat.severity == "critical").count()
    high = db.query(Threat).filter(Threat.severity == "high").count()
    processed = db.query(ThreatDocument).filter(ThreatDocument.is_processed == True).count()
    pending = db.query(ThreatDocument).filter(ThreatDocument.is_processed == False).count()

    avg_risk = db.query(func.avg(Threat.risk_score)).scalar() or 0.0
    max_risk = db.query(func.max(Threat.risk_score)).scalar() or 0.0

    by_source = dict(
        db.query(Threat.source, func.count(Threat.id))
        .group_by(Threat.source)
        .order_by(desc(func.count(Threat.id)))
        .limit(5)
        .all()
    )
    by_category = dict(
        db.query(Threat.category, func.count(Threat.id)).group_by(Threat.category).all()
    )

    return {
        "total_threats": total,
        "critical_threats": critical,
        "high_threats": high,
        "processed_docs": processed,
        "pending_docs": pending,
        "avg_risk_score": round(float(avg_risk), 2),
        "max_risk_score": round(float(max_risk), 2),
        "by_source": by_source,
        "by_category": by_category,
        "last_updated": datetime.utcnow().isoformat(),
    }


@router.get("/trends")
def get_threat_trends(
    days: int = Query(default=30, ge=1, le=365),
    db: Session = Depends(get_db),
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
        d = str(row[0])
        if d not in trend:
            trend[d] = {"critical": 0, "high": 0, "medium": 0, "low": 0}
        trend[d][row[2] or "medium"] = row[1]

    return {
        "days": days,
        "since": since.isoformat(),
        "data_points": len(trend),
        "trend": trend,
    }


@router.get("/risk-distribution")
def get_risk_distribution(db: Session = Depends(get_db)):
    """Risk score histogram buckets."""
    threats = db.query(Threat.risk_score).filter(Threat.risk_score is not None).all()
    scores = [float(r[0]) for r in threats if r[0] is not None]

    buckets = {"0-2": 0, "2-4": 0, "4-6": 0, "6-8": 0, "8-10": 0}
    for s in scores:
        if s < 2:
            buckets["0-2"] += 1
        elif s < 4:
            buckets["2-4"] += 1
        elif s < 6:
            buckets["4-6"] += 1
        elif s < 8:
            buckets["6-8"] += 1
        else:
            buckets["8-10"] += 1

    return {
        "total": len(scores),
        "buckets": buckets,
        "avg": round(sum(scores) / max(len(scores), 1), 2),
        "max": round(max(scores, default=0), 2),
    }


@router.get("/top-threats")
def get_top_threats(
    limit: int = Query(default=10, ge=1, le=50),
    db: Session = Depends(get_db),
):
    """Top N threats by risk score."""
    threats = db.query(Threat).order_by(desc(Threat.risk_score)).limit(limit).all()
    return [
        {
            "id": t.id,
            "title": t.title[:100],
            "severity": t.severity,
            "category": t.category,
            "risk_score": t.risk_score,
            "source": t.source,
            "detected_at": t.detected_at.isoformat() if t.detected_at else None,
        }
        for t in threats
    ]
