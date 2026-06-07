"""
Text pre-processing: HTML stripping, whitespace normalisation, SHA-256 fingerprinting.
Run before NER and embedding to improve model quality.
"""

import hashlib
import re

# HTML / XML tag pattern
_HTML_RE = re.compile(r"<[^>]+>", re.IGNORECASE)
# Runs of whitespace (including tabs, newlines)
_WS_RE = re.compile(r"\s+")
# Characters that are noise but not useful for NLP (keep IOC chars: . : / @ # _ -)
_NOISE_RE = re.compile(r"[^\w\s\-\.\:\/\@\#\(\)\[\]]")


def clean_text(raw: str) -> str:
    """
    Produce a normalised, plain-text version of raw OSINT content.

    Steps:
        1. Strip HTML/XML tags
        2. Remove noise characters
        3. Collapse whitespace
        4. Strip leading/trailing whitespace
    """
    text = _HTML_RE.sub(" ", raw)
    text = _NOISE_RE.sub(" ", text)
    text = _WS_RE.sub(" ", text).strip()
    return text


def fingerprint(text: str) -> str:
    """
    SHA-256 fingerprint for deduplication.
    Normalises to lowercase and collapses whitespace before hashing
    so near-duplicate articles from different feeds are caught.
    """
    normalised = _WS_RE.sub(" ", text.lower().strip())
    return hashlib.sha256(normalised.encode("utf-8")).hexdigest()


def is_security_relevant(text: str, threshold: int = 1) -> bool:
    """
    Quick keyword gate — discard content with zero security relevance
    before running the heavier NLP pipeline.
    """
    SECURITY_KEYWORDS = [
        "cyber",
        "hack",
        "breach",
        "malware",
        "ransomware",
        "phishing",
        "vulnerability",
        "exploit",
        "attack",
        "threat",
        "cve",
        "security",
        "intrusion",
        "incident",
        "zero-day",
        "trojan",
        "botnet",
        "apt",
    ]
    text_lower = text.lower()
    hits = sum(1 for kw in SECURITY_KEYWORDS if kw in text_lower)
    return hits >= threshold


clean = clean_text
