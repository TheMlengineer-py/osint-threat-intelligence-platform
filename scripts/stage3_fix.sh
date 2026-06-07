#!/usr/bin/env bash
# =============================================================================
# STAGE 3 FIX — definitive version
# Fixes 6 issues found from actual file inspection.
# Run from: backend/
# Usage:    bash ../scripts/stage3_fix.sh
# =============================================================================
set -e
GREEN='\033[0;32m'; BOLD='\033[1m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${BOLD}[--]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1"; }

[ ! -d "src" ] && err "Run from backend/ directory" && exit 1

echo ""
echo -e "${BOLD}=== STAGE 3 FIX ===${NC}"
echo "DB: SQLite  |  6 surgical fixes  |  no file touched unless broken"
echo ""

# =============================================================================
# FIX 1 — src/models/orm/threat.py
# WHY: Uses JSONB + UUID(as_uuid=True) — PostgreSQL-only, crashes on SQLite
# FIX: Replace with Text (JSON strings) and String(36)
# =============================================================================
info "FIX 1: models/orm/threat.py — SQLite-compatible types"

cat > src/models/orm/threat.py << 'PYEOF'
"""
SQLAlchemy ORM models for threat-related tables.
SQLite-compatible: JSONB -> Text, UUID -> String(36).
"""
import uuid
from datetime import datetime
from sqlalchemy import (
    Boolean, Column, DateTime, Enum, Float,
    ForeignKey, String, Text,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from src.database.engine import Base
from src.models.orm.base import (
    EntityType, FeedbackAction, ReportStatus,
    SeverityLevel, SourceType, ThreatCategory,
)

def _uuid():
    return str(uuid.uuid4())

class Source(Base):
    __tablename__ = "sources"
    id           = Column(String(36), primary_key=True, default=_uuid)
    name         = Column(String(200), nullable=False)
    url          = Column(Text)
    source_type  = Column(Enum(SourceType), nullable=False, default=SourceType.rss)
    credibility  = Column(Float, default=0.75)
    is_active    = Column(Boolean, default=True)
    last_fetched = Column(DateTime)
    created_at   = Column(DateTime, server_default=func.now())
    documents    = relationship("ThreatDocument", back_populates="source")

class ThreatDocument(Base):
    __tablename__ = "threat_documents"
    id            = Column(String(36), primary_key=True, default=_uuid)
    source_id     = Column(String(36), ForeignKey("sources.id", ondelete="SET NULL"), nullable=True)
    title         = Column(Text, nullable=False)
    raw_content   = Column(Text, nullable=False)
    clean_content = Column(Text)
    url           = Column(Text)
    language      = Column(String(10), default="en")
    source_type   = Column(Enum(SourceType), default=SourceType.rss)
    published_at  = Column(DateTime)
    fetched_at    = Column(DateTime, server_default=func.now())
    is_processed  = Column(Boolean, default=False)
    chroma_doc_id = Column(String(100))
    doc_metadata  = Column(Text, default="{}")
    source = relationship("Source", back_populates="documents")
    threat = relationship("Threat", back_populates="document", uselist=False)

class Threat(Base):
    __tablename__ = "threats"
    id               = Column(String(36), primary_key=True, default=_uuid)
    document_id      = Column(String(36), ForeignKey("threat_documents.id", ondelete="CASCADE"), nullable=True)
    title            = Column(Text, nullable=False)
    summary          = Column(Text)
    category         = Column(Enum(ThreatCategory), nullable=False, default=ThreatCategory.other)
    severity         = Column(Enum(SeverityLevel), nullable=False, default=SeverityLevel.medium)
    risk_score       = Column(Float, default=0.0)
    likelihood       = Column(Float, default=0.5)
    impact           = Column(Float, default=0.5)
    confidence       = Column(Float, default=0.5)
    iocs             = Column(Text, default="[]")
    mitre_techniques = Column(Text, default="[]")
    affected_sectors = Column(Text, default="[]")
    source           = Column(String(255))
    source_url       = Column(Text)
    source_type      = Column(Enum(SourceType), default=SourceType.rss)
    detected_at      = Column(DateTime, server_default=func.now())
    updated_at       = Column(DateTime, server_default=func.now(), onupdate=func.now())
    is_active        = Column(Boolean, default=True)
    analyst_verified = Column(Boolean, default=False)
    threat_metadata  = Column(Text, default="{}")
    document  = relationship("ThreatDocument", back_populates="threat")
    alerts    = relationship("Alert", back_populates="threat", cascade="all, delete-orphan")
    feedback  = relationship("AnalystFeedback", back_populates="threat", cascade="all, delete-orphan")

class Alert(Base):
    __tablename__ = "alerts"
    id          = Column(String(36), primary_key=True, default=_uuid)
    threat_id   = Column(String(36), ForeignKey("threats.id", ondelete="CASCADE"))
    title       = Column(Text, nullable=False)
    description = Column(Text)
    severity    = Column(Enum(SeverityLevel), nullable=False, default=SeverityLevel.medium)
    is_read     = Column(Boolean, default=False)
    created_at  = Column(DateTime, server_default=func.now())
    threat      = relationship("Threat", back_populates="alerts")

class AnalystFeedback(Base):
    __tablename__ = "analyst_feedback"
    id                 = Column(String(36), primary_key=True, default=_uuid)
    threat_id          = Column(String(36), ForeignKey("threats.id", ondelete="CASCADE"))
    action             = Column(Enum(FeedbackAction), nullable=False)
    notes              = Column(Text)
    corrected_severity = Column(Enum(SeverityLevel))
    corrected_category = Column(Enum(ThreatCategory))
    analyst_id         = Column(String(100), default="analyst")
    created_at         = Column(DateTime, server_default=func.now())
    threat             = relationship("Threat", back_populates="feedback")
PYEOF
log "threat.py patched"

# =============================================================================
# FIX 2 — src/api/schemas/threat_schemas.py
# WHY: Declares id:int, external_id, threat_type, confidence_score, created_at,
#      status — none exist in the ORM, FastAPI throws validation errors
# FIX: Align schema fields with actual Threat ORM columns
# =============================================================================
info "FIX 2: api/schemas/threat_schemas.py — align with ORM columns"

cat > src/api/schemas/threat_schemas.py << 'PYEOF'
"""
Threat API Schemas — aligned with models/orm/threat.py columns.
"""
from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List

class ThreatCreate(BaseModel):
    title: str
    summary: Optional[str] = None
    category: Optional[str] = "other"
    severity: Optional[str] = "medium"
    source: Optional[str] = None
    source_url: Optional[str] = None
    risk_score: Optional[float] = 0.0

class ThreatResponse(BaseModel):
    id: str
    title: str
    summary: Optional[str] = None
    category: Optional[str] = None
    severity: Optional[str] = None
    risk_score: Optional[float] = None
    likelihood: Optional[float] = None
    impact: Optional[float] = None
    confidence: Optional[float] = None
    source: Optional[str] = None
    source_url: Optional[str] = None
    source_type: Optional[str] = None
    iocs: Optional[str] = None
    detected_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    is_active: Optional[bool] = True
    analyst_verified: Optional[bool] = False
    class Config:
        from_attributes = True

class ThreatListResponse(BaseModel):
    total: int
    threats: List[ThreatResponse]
PYEOF
log "threat_schemas.py patched"

# =============================================================================
# FIX 3 — src/api/routes/threats.py
# WHY: Queries Threat.created_at (col is detected_at), Threat.threat_type
#      (removed), threat_id as int (it's UUID string)
# FIX: Correct column names, add granular ingest endpoints
# =============================================================================
info "FIX 3: api/routes/threats.py — fix column names + ingest endpoints"

cat > src/api/routes/threats.py << 'PYEOF'
"""
Threat Intelligence API Routes
"""
import asyncio
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from sqlalchemy import func
from src.api.dependencies.database import get_db
from src.api.schemas.threat_schemas import ThreatResponse, ThreatCreate
from src.models.orm.threat import Threat
from src.services.ingestion_service import IngestionService

router = APIRouter(prefix="/api/v1/threats", tags=["threats"])

@router.get("/", response_model=List[ThreatResponse])
async def get_threats(
    skip: int = 0,
    limit: int = 50,
    severity: Optional[str] = None,
    category: Optional[str] = None,
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
            db.query(Threat.severity, func.count(Threat.id))
            .group_by(Threat.severity).all()
        ),
        "by_category": dict(
            db.query(Threat.category, func.count(Threat.id))
            .group_by(Threat.category).all()
        ),
        "by_source": dict(
            db.query(Threat.source, func.count(Threat.id))
            .group_by(Threat.source).all()
        ),
        "last_updated": datetime.utcnow().isoformat(),
    }

@router.get("/ingest/status")
async def ingest_status(db: Session = Depends(get_db)):
    return {
        "total_threats": db.query(Threat).count(),
        "critical": db.query(Threat).filter(Threat.severity == "critical").count(),
        "high":     db.query(Threat).filter(Threat.severity == "high").count(),
        "medium":   db.query(Threat).filter(Threat.severity == "medium").count(),
        "low":      db.query(Threat).filter(Threat.severity == "low").count(),
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
    try:    return loop.run_until_complete(coro)
    finally: loop.close()

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
PYEOF
log "threats.py routes patched"

# =============================================================================
# FIX 4 — src/services/ingestion_service.py
# WHY: _store_* methods reference Threat.external_id, Threat.threat_type,
#      Threat.confidence_score, Threat.status, Threat.published_date —
#      none exist in the new ORM
# FIX: Rewrite store methods using actual column names
# =============================================================================
info "FIX 4: services/ingestion_service.py — align store methods with ORM"

cat > src/services/ingestion_service.py << 'PYEOF'
"""
Ingestion Service — orchestrates collectors and persists to SQLite.
"""
import json
import logging
from datetime import datetime
from typing import Dict, Optional
from sqlalchemy.orm import Session
from src.ingestion.cisa_collector import CISACollector
from src.ingestion.rss_collector import RSSCollector
from src.models.orm.threat import Threat, ThreatDocument
from src.database.session import SessionLocal

try:
    from src.ingestion.newsapi_collector import NewsAPICollector
    _NEWSAPI_AVAILABLE = True
except Exception:
    NewsAPICollector = None
    _NEWSAPI_AVAILABLE = False

logger = logging.getLogger(__name__)


class IngestionService:

    def __init__(self, db: Session = None):
        self.db = db or SessionLocal()

    async def ingest_all_sources(self) -> Dict[str, int]:
        r = {"cisa": 0, "news": 0, "rss": 0, "total": 0, "errors": 0}
        try:
            r["cisa"] = await self.ingest_cisa()
            r["rss"]  = await self.ingest_rss()
            if _NEWSAPI_AVAILABLE:
                r["news"] = await self.ingest_newsapi()
            r["total"] = r["cisa"] + r["news"] + r["rss"]
            logger.info(f"Ingestion complete: {r}")
        except Exception as e:
            logger.error(f"Ingestion error: {e}")
            r["errors"] += 1
        return r

    async def ingest_cisa(self) -> int:
        threats = await CISACollector().collect_latest_threats(limit=50)
        return await self._store_cisa(threats)

    async def ingest_rss(self) -> int:
        items = await RSSCollector().collect_from_all_feeds(limit=50)
        return await self._store_generic(items, "RSS", "rss")

    async def ingest_newsapi(self) -> int:
        if not _NEWSAPI_AVAILABLE:
            return 0
        items = await NewsAPICollector().collect_threat_news(days=7, limit=50)
        return await self._store_generic(items, "NewsAPI", "news")

    async def _store_cisa(self, threats) -> int:
        count = 0
        for t in threats:
            try:
                if self._url_exists(t.source_url):
                    continue
                doc = ThreatDocument(
                    title=t.title,
                    raw_content=t.description or "",
                    url=t.source_url,
                    source_type="cisa",
                    published_at=self._parse_date(t.published_date),
                    is_processed=False,
                )
                self.db.add(doc)
                self.db.flush()
                self.db.add(Threat(
                    document_id=doc.id,
                    title=t.title,
                    summary=(t.description or "")[:500],
                    severity=self._map_severity(t.severity),
                    category="vulnerability_exploit",
                    risk_score=float(t.cvss_score or 0.0),
                    likelihood=min(float(t.cvss_score or 5.0) / 10.0, 1.0),
                    impact=min(float(t.cvss_score or 5.0) / 10.0, 1.0),
                    confidence=0.9,
                    source="CISA/NVD",
                    source_url=t.source_url,
                    source_type="cisa",
                    iocs=json.dumps([{"type": "cve", "value": t.cve_id}]),
                    threat_metadata=json.dumps({"cve_id": t.cve_id}),
                ))
                self.db.commit()
                count += 1
            except Exception as e:
                self.db.rollback()
                logger.error(f"CISA store error ({getattr(t, 'cve_id', '?')}): {e}")
        logger.info(f"CISA: stored {count} new threats")
        return count

    async def _store_generic(self, items, source_label: str, source_type: str) -> int:
        count = 0
        for item in items:
            try:
                url   = getattr(item, "source_url", "") or ""
                title = getattr(item, "title", "") or "Untitled"
                if url and self._url_exists(url):
                    continue
                doc = ThreatDocument(
                    title=title[:500],
                    raw_content=getattr(item, "description", "") or "",
                    url=url,
                    source_type=source_type,
                    published_at=self._parse_date(getattr(item, "published_date", None)),
                    is_processed=False,
                )
                self.db.add(doc)
                self.db.flush()
                self.db.add(Threat(
                    document_id=doc.id,
                    title=title[:500],
                    summary=(getattr(item, "description", "") or "")[:500],
                    severity="medium",
                    category="other",
                    risk_score=0.5,
                    likelihood=0.5,
                    impact=0.5,
                    confidence=0.6,
                    source=getattr(item, "source", source_label),
                    source_url=url,
                    source_type=source_type,
                ))
                self.db.commit()
                count += 1
            except Exception as e:
                self.db.rollback()
                logger.error(f"{source_label} store error: {e}")
        logger.info(f"{source_label}: stored {count} new items")
        return count

    def _url_exists(self, url: str) -> bool:
        if not url:
            return False
        return self.db.query(Threat).filter(Threat.source_url == url).first() is not None

    @staticmethod
    def _map_severity(raw: str) -> str:
        return {
            "CRITICAL": "critical", "HIGH": "high",
            "MEDIUM": "medium", "LOW": "low", "NONE": "low",
        }.get((raw or "").upper(), "medium")

    @staticmethod
    def _parse_date(value) -> Optional[datetime]:
        if not value:
            return None
        if isinstance(value, datetime):
            return value
        for fmt in ("%Y-%m-%dT%H:%M:%S.%f", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d"):
            try:
                return datetime.strptime(str(value)[:19], fmt)
            except ValueError:
                continue
        return None

    def __del__(self):
        try:
            if self.db:
                self.db.close()
        except Exception:
            pass
PYEOF
log "ingestion_service.py patched"

# =============================================================================
# FIX 5 — src/ingestion/newsapi_collector.py
# WHY: File exists but is completely empty — import fails silently
# FIX: Write async collector using settings.news_api_key (matches settings.py)
# =============================================================================
info "FIX 5: ingestion/newsapi_collector.py — write (was empty)"

cat > src/ingestion/newsapi_collector.py << 'PYEOF'
"""
NewsAPI collector — async, mirrors style of cisa_collector.py.
Requires NEWS_API_KEY in .env (free tier: 100 req/day).
"""
import aiohttp
import logging
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import List, Optional
from src.core.config.settings import settings

logger = logging.getLogger(__name__)
_QUERIES = [
    "cybersecurity threat",
    "ransomware attack",
    "data breach",
    "malware campaign",
]

@dataclass
class NewsItem:
    title: str
    description: str
    source: str
    source_url: str
    published_date: Optional[datetime]

class NewsAPICollector:
    BASE_URL = "https://newsapi.org/v2/everything"

    def __init__(self):
        self.api_key = settings.news_api_key
        self.timeout = aiohttp.ClientTimeout(total=20)

    async def collect_threat_news(
        self,
        days: int = 7,
        limit: int = 50,
        queries: Optional[List[str]] = None,
    ) -> List[NewsItem]:
        if not self.api_key:
            logger.warning("NEWS_API_KEY not set — skipping NewsAPI")
            return []
        items = []
        from_date = (datetime.utcnow() - timedelta(days=days)).strftime("%Y-%m-%d")
        terms = queries or _QUERIES
        per_q = max(1, limit // len(terms))

        async with aiohttp.ClientSession(timeout=self.timeout) as session:
            for query in terms:
                try:
                    params = {
                        "q": query, "from": from_date,
                        "sortBy": "publishedAt", "language": "en",
                        "pageSize": min(per_q, 20),
                        "apiKey": self.api_key,
                    }
                    async with session.get(self.BASE_URL, params=params) as resp:
                        if resp.status != 200:
                            logger.error(f"NewsAPI {resp.status} for '{query}'")
                            continue
                        for art in (await resp.json()).get("articles", []):
                            title = art.get("title") or ""
                            if not title or title == "[Removed]":
                                continue
                            try:
                                pub = datetime.fromisoformat(
                                    art.get("publishedAt", "").replace("Z", "+00:00")
                                )
                            except Exception:
                                pub = datetime.utcnow()
                            items.append(NewsItem(
                                title=title[:500],
                                description=(art.get("description") or "")[:1000],
                                source=art.get("source", {}).get("name", "NewsAPI"),
                                source_url=art.get("url", ""),
                                published_date=pub,
                            ))
                except Exception as e:
                    logger.error(f"NewsAPI error for '{query}': {e}")

        logger.info(f"NewsAPI: collected {len(items)} articles")
        return items[:limit]
PYEOF
log "newsapi_collector.py written"

# =============================================================================
# FIX 6 — src/ingestion/__init__.py
# WHY: Empty file — not a proper Python package
# FIX: Add package docstring
# =============================================================================
info "FIX 6: ingestion/__init__.py — add package docstring"
echo '"""OSINT data ingestion collectors."""' > src/ingestion/__init__.py
log "ingestion/__init__.py written"

# =============================================================================
# STEP A — Install packages
# =============================================================================
info "Installing required packages..."
pip install --quiet aiohttp feedparser pydantic-settings 2>&1 | tail -2
log "Packages ready"

# =============================================================================
# STEP B — Drop old tables, recreate with correct schema
# =============================================================================
info "Recreating DB tables with correct schema..."
python - << 'PYEOF'
import sys
sys.path.insert(0, ".")
try:
    from src.database.engine import Base, engine
    from src.models.orm import threat as _models
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    from sqlalchemy import inspect
    tables = inspect(engine).get_table_names()
    print(f"  Tables created: {tables}")
except Exception as e:
    print(f"  ERROR: {e}")
    import traceback; traceback.print_exc()
PYEOF

# =============================================================================
# STEP C — Import smoke test
# =============================================================================
info "Import smoke test..."
python - << 'PYEOF'
import sys
sys.path.insert(0, ".")
tests = [
    ("settings",         "from src.core.config.settings import settings"),
    ("orm base",         "from src.models.orm.base import SeverityLevel, ThreatCategory"),
    ("orm threat",       "from src.models.orm.threat import Threat, ThreatDocument"),
    ("cleaner",          "from src.preprocessing.cleaner import clean"),
    ("cisa collector",   "from src.ingestion.cisa_collector import CISACollector"),
    ("rss collector",    "from src.ingestion.rss_collector import RSSCollector"),
    ("newsapi",          "from src.ingestion.newsapi_collector import NewsAPICollector"),
    ("ingestion svc",    "from src.services.ingestion_service import IngestionService"),
    ("threat schema",    "from src.api.schemas.threat_schemas import ThreatResponse"),
    ("threat route",     "from src.api.routes.threats import router"),
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
if failed == 0:
    print("  ALL CLEAR — safe to restart server")
else:
    print("  Fix failures above before restarting")
sys.exit(0 if failed == 0 else 1)
PYEOF

# =============================================================================
# STEP D — Live CISA fetch (network test, no DB write)
# =============================================================================
info "Live CISA fetch test..."
python - << 'PYEOF'
import sys, asyncio
sys.path.insert(0, ".")
async def test():
    from src.ingestion.cisa_collector import CISACollector
    items = await CISACollector().collect_latest_threats(limit=5)
    print(f"  Fetched {len(items)} CISA items")
    for item in items[:3]:
        print(f"  [{item.severity:8}] {item.cve_id} — {item.title[:55]}")
asyncio.run(test())
PYEOF

echo ""
echo "========================================================"
echo -e "${GREEN}Stage 3 fixes applied.${NC}"
echo ""
echo "  1. Restart server (Ctrl+C in terminal 1, then):"
echo "     python -m uvicorn src.main:app --reload --host 0.0.0.0 --port 8000"
echo ""
echo "  2. Run test suite (terminal 2):"
echo "     bash ../scripts/test_stage3.sh"
echo "========================================================"
