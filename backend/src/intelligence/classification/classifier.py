"""
Threat classifier — maps raw document text to ThreatCategory + SeverityLevel.
Uses keyword matching (no external model required).
Falls back gracefully when spaCy is unavailable.
"""

import re

from src.models.orm.base import SeverityLevel, ThreatCategory

# ── Keyword maps ──────────────────────────────────────────────────────────────
_CATEGORY_KEYWORDS: dict[str, list] = {
    ThreatCategory.malware_ransomware: [
        "malware",
        "ransomware",
        "trojan",
        "worm",
        "botnet",
        "spyware",
        "keylogger",
        "rootkit",
        "backdoor",
        "cryptominer",
    ],
    ThreatCategory.phishing_fraud: [
        "phishing",
        "spear-phishing",
        "whaling",
        "credential harvesting",
        "fake login",
        "smishing",
        "vishing",
        "social engineering",
    ],
    ThreatCategory.data_breach: [
        "data breach",
        "exfiltration",
        "leaked",
        "unauthorized access",
        "data theft",
        "sensitive data",
        "pii exposed",
        "database dump",
    ],
    ThreatCategory.vulnerability_exploit: [
        "cve",
        "vulnerability",
        "exploit",
        "zero-day",
        "0-day",
        "patch",
        "rce",
        "remote code execution",
        "buffer overflow",
        "sql injection",
        "xss",
        "arbitrary code",
    ],
    ThreatCategory.apt: [
        "apt",
        "advanced persistent threat",
        "nation-state",
        "state-sponsored",
        "threat actor",
        "campaign",
        "shadowpad",
        "cobalt strike",
    ],
    ThreatCategory.insider_threat: [
        "insider threat",
        "disgruntled employee",
        "privilege abuse",
        "unauthorized access by employee",
    ],
    ThreatCategory.other: [],  # fallback
}

_SEVERITY_KEYWORDS: dict[str, list] = {
    SeverityLevel.critical: [
        "critical",
        "0-day",
        "zero-day",
        "actively exploited",
        "widespread",
        "emergency",
        "cvss 9",
        "cvss 10",
    ],
    SeverityLevel.high: [
        "high",
        "exploitation",
        "public exploit",
        "major breach",
        "cvss 7",
        "cvss 8",
        "significant",
    ],
    SeverityLevel.medium: [
        "medium",
        "moderate",
        "vulnerability",
        "potential",
        "cvss 4",
        "cvss 5",
        "cvss 6",
    ],
    SeverityLevel.low: [
        "low",
        "minor",
        "informational",
        "cvss 1",
        "cvss 2",
        "cvss 3",
    ],
}

# CVSS score pattern to extract numeric severity
_CVSS_RE = re.compile(r"cvss[v\s]*(?:score)?[:\s]*([\d.]+)", re.IGNORECASE)


def _score_keywords(text_lower: str, keyword_map: dict) -> tuple[str, int]:
    """Return (best_key, hit_count) from a keyword map."""
    best_key = None
    best_hits = 0
    for key, keywords in keyword_map.items():
        hits = sum(1 for kw in keywords if kw in text_lower)
        if hits > best_hits:
            best_hits = hits
            best_key = key
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
        if cvss_score >= 9.0:
            return SeverityLevel.critical.value
        if cvss_score >= 7.0:
            return SeverityLevel.high.value
        if cvss_score >= 4.0:
            return SeverityLevel.medium.value
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


def classify(text: str, cvss_score: float = None) -> dict[str, str]:
    """
    Full classification — returns category + severity.

    Returns:
        {"category": "...", "severity": "..."}
    """
    return {
        "category": classify_category(text),
        "severity": classify_severity(text, cvss_score=cvss_score),
    }
