"""
Threat Intelligence API Routes
"""

import asyncio
from datetime import datetime

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from src.api.dependencies.database import get_db
from src.api.schemas.threat_schemas import ThreatResponse
from src.models.orm.threat import Threat
from src.services.ingestion_service import IngestionService

router = APIRouter(prefix="/api/v1/threats", tags=["threats"])


@router.get("/", response_model=list[ThreatResponse])
async def get_threats(
    skip: int = 0,
    limit: int = 50,
    severity: str | None = None,
    category: str | None = None,
    db: Session = Depends(get_db),
):
    q = db.query(Threat).order_by(Threat.detected_at.desc())
    if severity:
        q = q.filter(Threat.severity == severity.lower())
    if category:
        q = q.filter(Threat.category == category.lower())
    return q.offset(skip).limit(limit).all()


@router.get("/stats/summary")
async def get_threat_stats(db: Session = Depends(get_db)):
    return {
        "total": db.query(Threat).count(),
        "by_severity": dict(
            db.query(Threat.severity, func.count(Threat.id)).group_by(Threat.severity).all()
        ),
        "by_category": dict(
            db.query(Threat.category, func.count(Threat.id)).group_by(Threat.category).all()
        ),
        "by_source": dict(
            db.query(Threat.source, func.count(Threat.id)).group_by(Threat.source).all()
        ),
        "last_updated": datetime.utcnow().isoformat(),
    }


@router.get("/ingest/status")
async def ingest_status(db: Session = Depends(get_db)):
    return {
        "total_threats": db.query(Threat).count(),
        "critical": db.query(Threat).filter(Threat.severity == "critical").count(),
        "high": db.query(Threat).filter(Threat.severity == "high").count(),
        "medium": db.query(Threat).filter(Threat.severity == "medium").count(),
        "low": db.query(Threat).filter(Threat.severity == "low").count(),
        "last_updated": datetime.utcnow().isoformat(),
    }


@router.get("/{threat_id}", response_model=ThreatResponse)
async def get_threat(threat_id: str, db: Session = Depends(get_db)):
    threat = db.query(Threat).filter(Threat.id == threat_id).first()
    if not threat:
        raise HTTPException(status_code=404, detail="Threat not found")
    return threat


def _run_async(coro):
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()


@router.post("/ingest")
async def ingest_all(background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    """Trigger all sources in background — returns immediately."""
    service = IngestionService(db)
    background_tasks.add_task(_run_async, service.ingest_all_sources())
    return {"status": "started", "message": "Ingestion running in background"}


@router.post("/ingest/cisa")
async def ingest_cisa(db: Session = Depends(get_db)):
    count = await IngestionService(db).ingest_cisa()
    return {"status": "ok", "ingested": count, "source": "cisa"}


@router.post("/ingest/rss")
async def ingest_rss(db: Session = Depends(get_db)):
    count = await IngestionService(db).ingest_rss()
    return {"status": "ok", "ingested": count, "source": "rss"}


@router.post("/ingest/newsapi")
async def ingest_newsapi(db: Session = Depends(get_db)):
    count = await IngestionService(db).ingest_newsapi()
    return {"status": "ok", "ingested": count, "source": "newsapi"}


# ── NLP Processing endpoints (Stage 4) ────────────────────────────────────────
from src.services.nlp_service import NLPService  # noqa: E402


@router.post("/process")
def process_all(db: Session = Depends(get_db)):
    """Run NLP pipeline on all unprocessed documents."""
    svc = NLPService(db)
    results = svc.process_all_pending()
    return {"status": "ok", "results": results}


@router.post("/process/{doc_id}")
def process_one(doc_id: str, db: Session = Depends(get_db)):
    """Run NLP pipeline on a single document by ID."""
    svc = NLPService(db)
    outcome = svc.process_one(doc_id)
    return {"status": "ok", "doc_id": doc_id, "outcome": outcome}


@router.get("/processed/stats")
def processed_stats(db: Session = Depends(get_db)):
    """Show how many documents have been NLP-processed."""
    from src.models.orm.threat import ThreatDocument

    total = db.query(ThreatDocument).count()
    processed = db.query(ThreatDocument).filter(ThreatDocument.is_processed is True).count()
    pending = total - processed
    return {
        "total_documents": total,
        "processed": processed,
        "pending": pending,
        "pct_complete": round(processed / total * 100, 1) if total else 0,
    }
