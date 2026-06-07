#!/usr/bin/env bash
# =============================================================================
# STAGE 4 FIX
# Wires up the NLP processing pipeline.
# Run from: backend/
# Usage:    bash ../scripts/stage4_fix.sh
# =============================================================================
set -e
GREEN='\033[0;32m'; BOLD='\033[1m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${BOLD}[--]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1"; }

[ ! -d "src" ] && err "Run from backend/ directory" && exit 1

echo ""
echo -e "${BOLD}=== STAGE 4 FIX — NLP Processing Pipeline ===${NC}"
echo ""

# =============================================================================
# FIX 1 — base_agent.py
# WHY: Imports from langchain which is not installed and not used anywhere else.
#      AgentState and BaseAgent only need stdlib + pydantic.
# FIX: Remove langchain import, keep full interface intact.
# =============================================================================
info "FIX 1: agents/base_agent.py — remove langchain dependency"

cat > src/agents/base_agent.py << 'PYEOF'
"""
Base agent class for all agentic AI workflows.
No external LLM framework dependency — works with any callable LLM.
"""
import json
import logging
from abc import ABC, abstractmethod
from typing import Any, Dict, List, Optional
from datetime import datetime

from pydantic import BaseModel

logger = logging.getLogger(__name__)


class AgentState(BaseModel):
    """State object passed between agent nodes."""
    data:      Dict[str, Any]       = {}
    messages:  List[Dict[str, str]] = []
    errors:    List[str]            = []
    metadata:  Dict[str, Any]       = {}
    timestamp: datetime             = datetime.now()

    class Config:
        arbitrary_types_allowed = True


class BaseAgent(ABC):
    """Base class for all agents."""

    def __init__(self, llm: Any = None, name: str = "BaseAgent"):
        self.llm    = llm
        self.name   = name
        self.logger = logging.getLogger(f"agents.{name}")

    @abstractmethod
    async def execute(self, state: AgentState) -> AgentState:
        """Execute agent logic."""
        pass

    def _log_execution(self, step: str, details: Dict[str, Any]) -> None:
        self.logger.info(f"{self.name} - {step}: {json.dumps(details, default=str)}")

    def _add_message(self, state: AgentState, role: str, content: str) -> None:
        state.messages.append({
            "role":      role,
            "content":   content,
            "timestamp": datetime.now().isoformat(),
        })

    def _add_error(self, state: AgentState, error: str) -> None:
        state.errors.append(error)
        self.logger.error(f"{self.name} - Error: {error}")
PYEOF
log "base_agent.py — langchain removed"

# =============================================================================
# FIX 2 — intelligence/__init__.py  (empty)
# =============================================================================
info "FIX 2: intelligence/__init__.py"
cat > src/intelligence/__init__.py << 'PYEOF'
"""OSINT intelligence processing modules."""
PYEOF
log "intelligence/__init__.py written"

# =============================================================================
# FIX 3 — intelligence/classification/__init__.py  (empty)
# =============================================================================
info "FIX 3: intelligence/classification/__init__.py"
cat > src/intelligence/classification/__init__.py << 'PYEOF'
"""Threat classification module."""
PYEOF
log "intelligence/classification/__init__.py written"

# =============================================================================
# FIX 4 — intelligence/entities/__init__.py  (empty)
# =============================================================================
info "FIX 4: intelligence/entities/__init__.py"
cat > src/intelligence/entities/__init__.py << 'PYEOF'
"""Entity extraction module."""
PYEOF
log "intelligence/entities/__init__.py written"

# =============================================================================
# FIX 5 — intelligence/indicators/__init__.py  (empty)
# =============================================================================
info "FIX 5: intelligence/indicators/__init__.py"
cat > src/intelligence/indicators/__init__.py << 'PYEOF'
"""IOC indicator extraction module."""
PYEOF
log "intelligence/indicators/__init__.py written"

# =============================================================================
# FIX 6 — intelligence/classification/classifier.py  (MISSING)
# WHY: Needed by the NLP pipeline to map raw text -> ThreatCategory enum.
#      Combines keyword matching (fast, no model needed) with the existing
#      ClassificationTools so no new dependencies are required.
# =============================================================================
info "FIX 6: intelligence/classification/classifier.py — write (was missing)"

cat > src/intelligence/classification/classifier.py << 'PYEOF'
"""
Threat classifier — maps raw document text to ThreatCategory + SeverityLevel.
Uses keyword matching (no external model required).
Falls back gracefully when spaCy is unavailable.
"""
import re
from typing import Dict, Tuple

from src.models.orm.base import ThreatCategory, SeverityLevel
from src.core.logging.logger import logger

# ── Keyword maps ──────────────────────────────────────────────────────────────
_CATEGORY_KEYWORDS: Dict[str, list] = {
    ThreatCategory.malware_ransomware:    [
        "malware", "ransomware", "trojan", "worm", "botnet",
        "spyware", "keylogger", "rootkit", "backdoor", "cryptominer",
    ],
    ThreatCategory.phishing_fraud:        [
        "phishing", "spear-phishing", "whaling", "credential harvesting",
        "fake login", "smishing", "vishing", "social engineering",
    ],
    ThreatCategory.data_breach:           [
        "data breach", "exfiltration", "leaked", "unauthorized access",
        "data theft", "sensitive data", "pii exposed", "database dump",
    ],
    ThreatCategory.vulnerability_exploit: [
        "cve", "vulnerability", "exploit", "zero-day", "0-day",
        "patch", "rce", "remote code execution", "buffer overflow",
        "sql injection", "xss", "arbitrary code",
    ],
    ThreatCategory.apt:                   [
        "apt", "advanced persistent threat", "nation-state", "state-sponsored",
        "threat actor", "campaign", "shadowpad", "cobalt strike",
    ],
    ThreatCategory.insider_threat:        [
        "insider threat", "disgruntled employee", "privilege abuse",
        "unauthorized access by employee",
    ],
    ThreatCategory.other:                 [],   # fallback
}

_SEVERITY_KEYWORDS: Dict[str, list] = {
    SeverityLevel.critical: [
        "critical", "0-day", "zero-day", "actively exploited",
        "widespread", "emergency", "cvss 9", "cvss 10",
    ],
    SeverityLevel.high: [
        "high", "exploitation", "public exploit", "major breach",
        "cvss 7", "cvss 8", "significant",
    ],
    SeverityLevel.medium: [
        "medium", "moderate", "vulnerability", "potential",
        "cvss 4", "cvss 5", "cvss 6",
    ],
    SeverityLevel.low: [
        "low", "minor", "informational", "cvss 1", "cvss 2", "cvss 3",
    ],
}

# CVSS score pattern to extract numeric severity
_CVSS_RE = re.compile(r"cvss[v\s]*(?:score)?[:\s]*([\d.]+)", re.IGNORECASE)


def _score_keywords(text_lower: str, keyword_map: Dict) -> Tuple[str, int]:
    """Return (best_key, hit_count) from a keyword map."""
    best_key  = None
    best_hits = 0
    for key, keywords in keyword_map.items():
        hits = sum(1 for kw in keywords if kw in text_lower)
        if hits > best_hits:
            best_hits = hits
            best_key  = key
    return best_key, best_hits


def classify_category(text: str) -> str:
    """
    Return a ThreatCategory value string for the given text.
    """
    text_lower = text.lower()
    best, hits = _score_keywords(text_lower, _CATEGORY_KEYWORDS)
    if best and hits > 0:
        return best.value if hasattr(best, "value") else str(best)
    return ThreatCategory.other.value


def classify_severity(text: str, cvss_score: float = None) -> str:
    """
    Return a SeverityLevel value string.
    If a numeric CVSS score is provided it takes priority.
    """
    # CVSS score override
    if cvss_score is not None:
        if cvss_score >= 9.0:  return SeverityLevel.critical.value
        if cvss_score >= 7.0:  return SeverityLevel.high.value
        if cvss_score >= 4.0:  return SeverityLevel.medium.value
        return SeverityLevel.low.value

    # Try to extract CVSS from text
    m = _CVSS_RE.search(text)
    if m:
        try:
            return classify_severity(text, cvss_score=float(m.group(1)))
        except ValueError:
            pass

    # Keyword fallback
    text_lower = text.lower()
    best, hits = _score_keywords(text_lower, _SEVERITY_KEYWORDS)
    if best and hits > 0:
        return best.value if hasattr(best, "value") else str(best)
    return SeverityLevel.medium.value


def classify(text: str, cvss_score: float = None) -> Dict[str, str]:
    """
    Full classification — returns category + severity.

    Returns:
        {"category": "...", "severity": "..."}
    """
    return {
        "category": classify_category(text),
        "severity": classify_severity(text, cvss_score=cvss_score),
    }
PYEOF
log "classifier.py written"

# =============================================================================
# FIX 7 — NLP processing service (new file)
# Reads ThreatDocument(is_processed=False), runs the full pipeline,
# updates Threat fields, marks document as processed.
# =============================================================================
info "FIX 7: services/nlp_service.py — write processing pipeline"

cat > src/services/nlp_service.py << 'PYEOF'
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
from typing import Dict, List, Optional

from sqlalchemy.orm import Session

from src.database.session import SessionLocal
from src.models.orm.threat import Threat, ThreatDocument
from src.preprocessing.cleaner import clean_text
from src.preprocessing.language_detector import is_english
from src.intelligence.indicators.ioc_extractor import extract_iocs
from src.intelligence.classification.classifier import classify

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

    def process_all_pending(self) -> Dict[str, int]:
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
        raw   = doc.raw_content or doc.title or ""
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
        entities: List[Dict] = []
        mitre: List[Dict] = []
        if _SPACY_AVAILABLE and entity_extractor:
            try:
                entities = entity_extractor.extract_entities(clean)
                mitre    = entity_extractor.extract_mitre_techniques(clean)
            except Exception as e:
                logger.warning(f"Entity extraction failed: {e}")

        # Step 5 — classify
        result = classify(clean)
        category = result["category"]
        severity = result["severity"]

        # Step 6 — risk score  (likelihood × impact × confidence)
        likelihood  = self._estimate_likelihood(iocs, severity)
        impact      = self._estimate_impact(severity, iocs)
        confidence  = 0.85 if _SPACY_AVAILABLE else 0.6
        risk_score  = round(likelihood * impact * confidence * 10, 2)

        # Step 7 — persist to linked Threat
        threat = self.db.query(Threat).filter(Threat.document_id == doc.id).first()
        if threat:
            # Only upgrade severity, never downgrade
            if self._severity_rank(severity) > self._severity_rank(threat.severity):
                threat.severity = severity

            threat.category         = category
            threat.risk_score       = risk_score
            threat.likelihood       = round(likelihood, 3)
            threat.impact           = round(impact, 3)
            threat.confidence       = round(confidence, 3)
            threat.iocs             = json.dumps(iocs)
            threat.mitre_techniques = json.dumps(mitre)
            threat.affected_sectors = json.dumps(
                [e["name"] for e in entities if e.get("type") == "ORG"][:5]
            )

        doc.is_processed = True
        self.db.commit()
        return "processed"

    # ── helpers ───────────────────────────────────────────────────────────────

    @staticmethod
    def _estimate_likelihood(iocs: List[Dict], severity: str) -> float:
        base = {"critical": 0.8, "high": 0.65, "medium": 0.45, "low": 0.25}.get(severity, 0.45)
        ioc_boost = min(len(iocs) * 0.02, 0.15)
        return min(base + ioc_boost, 1.0)

    @staticmethod
    def _estimate_impact(severity: str, iocs: List[Dict]) -> float:
        base = {"critical": 0.9, "high": 0.7, "medium": 0.5, "low": 0.3}.get(severity, 0.5)
        hash_count = sum(1 for i in iocs if i["type"] in ("md5", "sha1", "sha256"))
        return min(base + hash_count * 0.02, 1.0)

    @staticmethod
    def _severity_rank(severity: str) -> int:
        return {"low": 1, "medium": 2, "high": 3, "critical": 4}.get(
            (severity or "").lower(), 0
        )

    def __del__(self):
        try:
            if self.db: self.db.close()
        except Exception: pass
PYEOF
log "nlp_service.py written"

# =============================================================================
# FIX 8 — Add /process route to threats.py API
# =============================================================================
info "FIX 8: Adding /process endpoints to threats.py routes"

# Only append if not already there
if ! grep -q "nlp_service" src/api/routes/threats.py; then
cat >> src/api/routes/threats.py << 'PYEOF'


# ── NLP Processing endpoints (Stage 4) ────────────────────────────────────────
from src.services.nlp_service import NLPService


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
    total     = db.query(ThreatDocument).count()
    processed = db.query(ThreatDocument).filter(ThreatDocument.is_processed == True).count()
    pending   = total - processed
    return {
        "total_documents": total,
        "processed":       processed,
        "pending":         pending,
        "pct_complete":    round(processed / total * 100, 1) if total else 0,
    }
PYEOF
log "Process endpoints appended to threats.py"
else
  log "SKIPPED — process endpoints already present"
fi

# =============================================================================
# STEP A — Install packages
# =============================================================================
info "Installing required packages..."
pip install --quiet spacy tenacity httpx 2>&1 | tail -2

# Download spaCy model if not present
python - << 'PYEOF'
import sys
try:
    import spacy
    spacy.load("en_core_web_sm")
    print("  spaCy en_core_web_sm already installed")
except OSError:
    print("  Downloading spaCy en_core_web_sm...")
    import subprocess
    subprocess.run([sys.executable, "-m", "spacy", "download", "en_core_web_sm"], check=True)
    print("  spaCy model downloaded")
except ImportError:
    print("  spaCy not installed — entity extraction will be skipped")
PYEOF
log "Packages ready"

# =============================================================================
# STEP B — Import smoke test
# =============================================================================
info "Import smoke test..."
python - << 'PYEOF'
import sys
sys.path.insert(0, ".")
tests = [
    ("base_agent",      "from src.agents.base_agent import BaseAgent, AgentState"),
    ("classification",  "from src.agents.classification_agent.agent import ClassificationAgent"),
    ("risk agent",      "from src.agents.risk_agent.agent import RiskAgent"),
    ("ioc_extractor",   "from src.intelligence.indicators.ioc_extractor import extract_iocs"),
    ("entity extractor","from src.intelligence.entities.extractoe import entity_extractor"),
    ("classifier",      "from src.intelligence.classification.classifier import classify"),
    ("nlp_service",     "from src.services.nlp_service import NLPService"),
    ("ollama_client",   "from src.llm.ollama_client import ollama_client"),
    ("threat route",    "from src.api.routes.threats import router"),
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

# =============================================================================
# STEP C — Quick functional test of the NLP pipeline (no server needed)
# =============================================================================
info "NLP pipeline functional test..."
python - << 'PYEOF'
import sys
sys.path.insert(0, ".")

# Test classifier
from src.intelligence.classification.classifier import classify
r = classify("Critical RCE vulnerability CVE-2024-1234 actively exploited in the wild")
print(f"  classify() -> category={r['category']} severity={r['severity']}")
assert r["severity"] == "critical", f"Expected critical, got {r['severity']}"

# Test IOC extractor
from src.intelligence.indicators.ioc_extractor import extract_iocs
iocs = extract_iocs("Attacker used 192.168.1.1 and 45.33.32.156, CVE-2024-5678")
public_iocs = [i for i in iocs if i["type"] == "ipv4"]
cve_iocs    = [i for i in iocs if i["type"] == "cve"]
print(f"  extract_iocs() -> {len(iocs)} iocs, {len(public_iocs)} public IPs, {len(cve_iocs)} CVEs")

print("\n  All functional tests passed")
PYEOF

echo ""
echo "========================================================"
echo -e "${GREEN}Stage 4 fixes applied.${NC}"
echo ""
echo "  Restart server:"
echo "    python -m uvicorn src.main:app --reload --host 0.0.0.0 --port 8000"
echo ""
echo "  Then run:"
echo "    bash ../scripts/test_stage4.sh"
echo "========================================================"
