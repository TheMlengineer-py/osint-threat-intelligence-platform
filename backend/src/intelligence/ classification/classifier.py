"""
Threat classifier — keyword-density heuristic plus optional scikit-learn fallback.
Returns a (ThreatCategory, confidence) tuple for any text input.
"""

from src.models.orm.base import ThreatCategory

# ── Keyword taxonomy ──────────────────────────────────────────────────────────
_KEYWORDS: dict[ThreatCategory, list[str]] = {
    ThreatCategory.apt: [
        "apt",
        "advanced persistent threat",
        "nation state",
        "state-sponsored",
        "shadowpulse",
        "lazarus",
        "fancy bear",
        "cozy bear",
        "volt typhoon",
        "scattered spider",
        "lapsus",
        "carbanak",
        "fin7",
        "turla",
    ],
    ThreatCategory.malware_ransomware: [
        "malware",
        "ransomware",
        "trojan",
        "backdoor",
        "rootkit",
        "spyware",
        "botnet",
        "worm",
        "virus",
        "cryptolocker",
        "lockbit",
        "blackcat",
        "conti",
        "ryuk",
        "revil",
        "darkside",
        "dropper",
        "loader",
    ],
    ThreatCategory.data_breach: [
        "data breach",
        "data leak",
        "leaked",
        "exposed database",
        "credentials",
        "stolen data",
        "personal data",
        "exfiltration",
        "dump",
        "paste",
        "credential stuffing",
        "account takeover",
    ],
    ThreatCategory.phishing_fraud: [
        "phishing",
        "spear phishing",
        "whaling",
        "smishing",
        "vishing",
        "credential harvesting",
        "fake invoice",
        "business email compromise",
        "bec",
        "social engineering",
        "lure",
        "impersonation",
    ],
    ThreatCategory.vulnerability_exploit: [
        "vulnerability",
        "exploit",
        "zero-day",
        "0-day",
        "patch",
        "cve",
        "remote code execution",
        "rce",
        "sql injection",
        "xss",
        "buffer overflow",
        "privilege escalation",
        "authentication bypass",
        "memory corruption",
    ],
    ThreatCategory.insider_threat: [
        "insider threat",
        "rogue employee",
        "disgruntled",
        "unauthorized access",
        "data theft",
        "sabotage",
        "lateral movement",
        "privilege abuse",
    ],
}


def classify(text: str) -> tuple[ThreatCategory, float]:
    """
    Classify text into a ThreatCategory using keyword density scoring.

    Algorithm:
        For each category, count keyword hits in text_lower.
        The category with the most hits wins.
        Confidence = min(hits / (max_possible * 0.3), 1.0)

    Returns:
        (category, confidence) — defaults to (other, 0.5) when no keywords match.
    """
    text_lower = text.lower()
    scores: dict[ThreatCategory, int] = {}

    for category, keywords in _KEYWORDS.items():
        hits = sum(1 for kw in keywords if kw in text_lower)
        if hits:
            scores[category] = hits

    if not scores:
        return ThreatCategory.other, 0.5

    best = max(scores, key=lambda c: scores[c])
    max_possible = len(_KEYWORDS[best])
    # Scale confidence: hitting 30 % of keywords → confidence = 1.0
    confidence = min(scores[best] / max(max_possible * 0.3, 1), 1.0)
    return best, round(confidence, 4)
