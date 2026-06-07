"""
NLP Processing Service — Stage 4 pipeline.

For every ThreatDocument where is_processed=False:
  1. clean raw_content          (cleaner.py)
  2. detect language            (language_detector.py)
  3. extract IOCs               (ioc_extractor.py)
  4. extract entities           (extractoe.py)
  5. classify category+severity (classifier.py)
  6. calculate risk score       (risk formula)
  7. persist updates to Threat + ThreatDocument
"""

import json
import logging

from sqlalchemy.orm import Session

from src.database.session import SessionLocal
from src.intelligence.classification.classifier import classify
from src.intelligence.indicators.ioc_extractor import extract_iocs
from src.models.orm.threat import Threat, ThreatDocument
from src.preprocessing.cleaner import clean_text
from src.preprocessing.language_detector import is_english

logger = logging.getLogger(__name__)

# Lazy import entity extractor — spaCy may not be installed
try:
    from src.intelligence.entities.extractoe import entity_extractor

    _SPACY_AVAILABLE = True
except Exception:
    entity_extractor = None
    _SPACY_AVAILABLE = False


class NLPService:

    def __init__(self, db: Session = None):
        self.db = db or SessionLocal()

    # ── public ────────────────────────────────────────────────────────────────

    def process_all_pending(self) -> dict[str, int]:
        """
        Process every unprocessed ThreatDocument.
        Returns counts: {processed, skipped, errors}
        """
        pending = (
            self.db.query(ThreatDocument)
            .filter(ThreatDocument.is_processed == False)
            .all()
        )
        logger.info(f"NLP pipeline: {len(pending)} documents pending")

        results = {"processed": 0, "skipped": 0, "errors": 0}
        for doc in pending:
            try:
                outcome = self._process_document(doc)
                results[outcome] += 1
            except Exception as e:
                self.db.rollback()
                logger.error(f"NLP error on doc {doc.id}: {e}")
                results["errors"] += 1

        logger.info(f"NLP pipeline complete: {results}")
        return results

    def process_one(self, doc_id: str) -> str:
        """Process a single document by ID. Returns outcome string."""
        doc = self.db.query(ThreatDocument).filter(ThreatDocument.id == doc_id).first()
        if not doc:
            return "not_found"
        return self._process_document(doc)

    # ── internals ─────────────────────────────────────────────────────────────

    def _process_document(self, doc: ThreatDocument) -> str:
        """Run full pipeline on one document. Returns 'processed' or 'skipped'."""

        # Step 1 — clean
        raw = doc.raw_content or doc.title or ""
        clean = clean_text(raw)
        doc.clean_content = clean

        # Step 2 — language filter (skip non-English)
        if not is_english(clean):
            doc.is_processed = True
            self.db.commit()
            return "skipped"

        # Step 3 — IOC extraction
        iocs = extract_iocs(clean)

        # Step 4 — entity extraction (spaCy, optional)
        entities: list[dict] = []
        mitre: list[dict] = []
        if _SPACY_AVAILABLE and entity_extractor:
            try:
                entities = entity_extractor.extract_entities(clean)
                mitre = entity_extractor.extract_mitre_techniques(clean)
            except Exception as e:
                logger.warning(f"Entity extraction failed: {e}")

        # Step 5 — classify
        result = classify(clean)
        category = result["category"]
        severity = result["severity"]

        # Step 6 — risk score  (likelihood × impact × confidence)
        likelihood = self._estimate_likelihood(iocs, severity)
        impact = self._estimate_impact(severity, iocs)
        confidence = 0.85 if _SPACY_AVAILABLE else 0.6
        risk_score = round(likelihood * impact * confidence * 10, 2)

        # Step 7 — persist to linked Threat
        threat = self.db.query(Threat).filter(Threat.document_id == doc.id).first()
        if threat:
            # Only upgrade severity, never downgrade
            if self._severity_rank(severity) > self._severity_rank(threat.severity):
                threat.severity = severity

            threat.category = category
            threat.risk_score = risk_score
            threat.likelihood = round(likelihood, 3)
            threat.impact = round(impact, 3)
            threat.confidence = round(confidence, 3)
            threat.iocs = json.dumps(iocs)
            threat.mitre_techniques = json.dumps(mitre)
            threat.affected_sectors = json.dumps(
                [e["name"] for e in entities if e.get("type") == "ORG"][:5]
            )

        doc.is_processed = True
        self.db.commit()
        return "processed"

    # ── helpers ───────────────────────────────────────────────────────────────

    @staticmethod
    def _estimate_likelihood(iocs: list[dict], severity: str) -> float:
        base = {"critical": 0.8, "high": 0.65, "medium": 0.45, "low": 0.25}.get(
            severity, 0.45
        )
        ioc_boost = min(len(iocs) * 0.02, 0.15)
        return min(base + ioc_boost, 1.0)

    @staticmethod
    def _estimate_impact(severity: str, iocs: list[dict]) -> float:
        base = {"critical": 0.9, "high": 0.7, "medium": 0.5, "low": 0.3}.get(
            severity, 0.5
        )
        hash_count = sum(1 for i in iocs if i["type"] in ("md5", "sha1", "sha256"))
        return min(base + hash_count * 0.02, 1.0)

    @staticmethod
    def _severity_rank(severity: str) -> int:
        return {"low": 1, "medium": 2, "high": 3, "critical": 4}.get(
            (severity or "").lower(), 0
        )

    def __del__(self):
        try:
            if self.db:
                self.db.close()
        except Exception:
            pass
