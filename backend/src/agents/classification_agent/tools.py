"""Tools for classification agent."""

import logging
import re
from typing import Any

try:
    import spacy

    _SPACY_AVAILABLE = True
except ImportError:
    spacy = None  # type: ignore[assignment]
    _SPACY_AVAILABLE = False

logger = logging.getLogger(__name__)

# Load spaCy model
try:
    nlp = spacy.load("en_core_web_sm")
except OSError:
    logger.warning("spaCy model not loaded - install with: python -m spacy download en_core_web_sm")
    nlp = None


class ClassificationTools:
    """Tools for threat classification and entity extraction."""

    # IOC patterns
    IPV4_PATTERN = re.compile(
        r"\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"
    )
    DOMAIN_PATTERN = re.compile(
        r"\b(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}\b", re.IGNORECASE
    )
    EMAIL_PATTERN = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b")
    URL_PATTERN = re.compile(r"https?://[^\s]+")
    HASH_PATTERN_MD5 = re.compile(r"\b[a-fA-F0-9]{32}\b")
    HASH_PATTERN_SHA1 = re.compile(r"\b[a-fA-F0-9]{40}\b")
    HASH_PATTERN_SHA256 = re.compile(r"\b[a-fA-F0-9]{64}\b")

    @staticmethod
    def extract_entities(text: str) -> list[dict[str, Any]]:
        """Extract entities using spaCy."""
        if not nlp:
            logger.warning("spaCy model not available")
            return []

        entities = []
        doc = nlp(text)

        for ent in doc.ents:
            entity_type_map = {
                "PERSON": "PERSON",
                "ORG": "ORG",
                "GPE": "GPE",
                "PRODUCT": "PRODUCT",
                "EVENT": "EVENT",
            }

            entity = {
                "value": ent.text,
                "type": entity_type_map.get(ent.label_, ent.label_),
                "confidence": 0.85,  # spaCy doesn't provide confidence
                "start": ent.start_char,
                "end": ent.end_char,
            }
            entities.append(entity)

        return entities

    @staticmethod
    def extract_iocs(text: str) -> dict[str, list[str]]:
        """Extract indicators of compromise."""
        iocs = {
            "ipv4": list(set(ClassificationTools.IPV4_PATTERN.findall(text))),
            "domains": list(set(ClassificationTools.DOMAIN_PATTERN.findall(text))),
            "emails": list(set(ClassificationTools.EMAIL_PATTERN.findall(text))),
            "urls": list(set(ClassificationTools.URL_PATTERN.findall(text))),
            "md5": list(set(ClassificationTools.HASH_PATTERN_MD5.findall(text))),
            "sha1": list(set(ClassificationTools.HASH_PATTERN_SHA1.findall(text))),
            "sha256": list(set(ClassificationTools.HASH_PATTERN_SHA256.findall(text))),
        }

        return {k: v for k, v in iocs.items() if v}

    @staticmethod
    def classify_threat_type(text: str) -> dict[str, Any]:
        """Classify threat type from text."""
        text_lower = text.lower()

        threat_keywords = {
            "malware": ["malware", "trojan", "worm", "ransomware", "botnet", "spyware"],
            "phishing": ["phishing", "spear-phishing", "whaling", "credential", "fake"],
            "vulnerability": ["vulnerability", "cve", "exploit", "flaw", "patch"],
            "data_breach": ["breach", "data exfiltration", "unauthorized access"],
            "ddos": ["ddos", "denial of service", "botnet attack"],
            "campaign": [
                "campaign",
                "apt",
                "advanced persistent threat",
                "coordinated",
            ],
        }

        threat_type = "unknown"
        confidence = 0.0

        for ttype, keywords in threat_keywords.items():
            for keyword in keywords:
                if keyword in text_lower:
                    threat_type = ttype
                    confidence = 0.8
                    break

        return {
            "threat_type": threat_type,
            "confidence": confidence,
        }

    @staticmethod
    def map_mitre_techniques(text: str) -> list[dict[str, Any]]:
        """Map to MITRE ATT&CK techniques."""
        technique_keywords = {
            "T1001": ["obfuscation", "command and control"],
            "T1021": ["lateral movement", "remote services"],
            "T1566": ["phishing", "initial access"],
            "T1087": ["account discovery", "reconnaissance"],
            "T1010": ["application window discovery"],
            "T1217": ["browser bookmark discovery"],
        }

        mapped_techniques = []
        text_lower = text.lower()

        for technique_id, keywords in technique_keywords.items():
            for keyword in keywords:
                if keyword in text_lower:
                    mapped_techniques.append(
                        {
                            "technique_id": technique_id,
                            "name": keyword.title(),
                            "confidence": 0.7,
                        }
                    )
                    break

        return mapped_techniques

    @staticmethod
    def assess_severity(content: str, threat_type: str) -> str:
        """Assess threat severity."""
        text_lower = content.lower()

        critical_keywords = ["critical", "0-day", "actively exploited", "widespread"]
        high_keywords = ["high", "exploitation", "public exploit", "major"]
        medium_keywords = ["medium", "vulnerability", "moderate"]

        if any(kw in text_lower for kw in critical_keywords):
            return "critical"
        elif any(kw in text_lower for kw in high_keywords):
            return "high"
        elif any(kw in text_lower for kw in medium_keywords):
            return "medium"
        else:
            return "low"
