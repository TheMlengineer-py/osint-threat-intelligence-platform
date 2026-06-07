"""
Ingestion Service — orchestrates collectors and persists to SQLite.
"""

import json
import logging
from datetime import datetime

from sqlalchemy.orm import Session

from src.database.session import SessionLocal
from src.ingestion.cisa_collector import CISACollector
from src.ingestion.rss_collector import RSSCollector
from src.models.orm.threat import Threat, ThreatDocument

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

    async def ingest_all_sources(self) -> dict[str, int]:
        r = {"cisa": 0, "news": 0, "rss": 0, "total": 0, "errors": 0}
        try:
            r["cisa"] = await self.ingest_cisa()
            r["rss"] = await self.ingest_rss()
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
                self.db.add(
                    Threat(
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
                    )
                )
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
                url = getattr(item, "source_url", "") or ""
                title = getattr(item, "title", "") or "Untitled"
                if url and self._url_exists(url):
                    continue
                doc = ThreatDocument(
                    title=title[:500],
                    raw_content=getattr(item, "description", "") or "",
                    url=url,
                    source_type=source_type,
                    published_at=self._parse_date(
                        getattr(item, "published_date", None)
                    ),
                    is_processed=False,
                )
                self.db.add(doc)
                self.db.flush()
                self.db.add(
                    Threat(
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
                    )
                )
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
        return (
            self.db.query(Threat).filter(Threat.source_url == url).first() is not None
        )

    @staticmethod
    def _map_severity(raw: str) -> str:
        return {
            "CRITICAL": "critical",
            "HIGH": "high",
            "MEDIUM": "medium",
            "LOW": "low",
            "NONE": "low",
        }.get((raw or "").upper(), "medium")

    @staticmethod
    def _parse_date(value) -> datetime | None:
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
