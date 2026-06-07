"""
Indicator of Compromise (IOC) extractor.
Uses compiled regex patterns to extract IPs, domains, URLs, hashes, CVEs, emails.
Results feed both the Threat model and the entity extraction pipeline.
"""

import re

# ── Compiled patterns ────────────────────────────────────────────────────────
PATTERNS: dict[str, re.Pattern] = {
    "ipv4": re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b"),
    "ipv6": re.compile(r"\b(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}\b"),
    "domain": re.compile(
        r"\b(?:[a-z0-9](?:[a-z0-9\-]{0,61}[a-z0-9])?\.)"
        r"+(?:com|net|org|io|gov|edu|ru|cn|de|uk|fr|onion)\b",
        re.IGNORECASE,
    ),
    "url": re.compile(r"https?://[^\s<>\"']+"),
    "md5": re.compile(r"\b[a-fA-F0-9]{32}\b"),
    "sha1": re.compile(r"\b[a-fA-F0-9]{40}\b"),
    "sha256": re.compile(r"\b[a-fA-F0-9]{64}\b"),
    "cve": re.compile(r"CVE-\d{4}-\d{4,7}", re.IGNORECASE),
    "email": re.compile(r"\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Z]{2,}\b"),
}

# Private / loopback IPs are rarely useful IOCs
_PRIVATE_PREFIXES = ("10.", "172.16.", "172.17.", "192.168.", "127.", "0.")


def _is_private_ip(ip: str) -> bool:
    return any(ip.startswith(p) for p in _PRIVATE_PREFIXES)


def extract_iocs(text: str, max_per_type: int = 20) -> list[dict[str, str]]:
    """
    Extract all IOCs from text.

    Returns:
        List of {"type": "<ioc_type>", "value": "<ioc_value>"} dicts.
        Deduped within each type; private IPs excluded.
    """
    results: list[dict[str, str]] = []
    seen: set = set()

    for ioc_type, pattern in PATTERNS.items():
        hits = pattern.findall(text)
        count = 0
        for value in hits:
            value = value.strip()
            if ioc_type == "ipv4" and _is_private_ip(value):
                continue
            key = f"{ioc_type}:{value}"
            if key not in seen and count < max_per_type:
                seen.add(key)
                results.append({"type": ioc_type, "value": value})
                count += 1

    return results
