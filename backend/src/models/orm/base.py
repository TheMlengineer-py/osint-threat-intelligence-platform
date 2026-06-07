"""
ORM base — exports SQLAlchemy Base + all domain enums.
All ORM models import from here to avoid circular imports.
"""

import enum

from sqlalchemy.orm import DeclarativeBase


# ── SQLAlchemy declarative base ───────────────────────────────────────────────
class Base(DeclarativeBase):
    """All ORM models inherit from this."""

    pass


# ── Domain enums (mirrored in frontend types/index.ts) ────────────────────────
class SeverityLevel(str, enum.Enum):
    low = "low"
    medium = "medium"
    high = "high"
    critical = "critical"


class ThreatCategory(str, enum.Enum):
    malware_ransomware = "malware_ransomware"
    data_breach = "data_breach"
    phishing_fraud = "phishing_fraud"
    vulnerability_exploit = "vulnerability_exploit"
    insider_threat = "insider_threat"
    apt = "apt"
    other = "other"


class SourceType(str, enum.Enum):
    news = "news"
    cve = "cve"
    mitre = "mitre"
    cisa = "cisa"
    social_media = "social_media"
    dark_web = "dark_web"
    rss = "rss"
    manual = "manual"


class EntityType(str, enum.Enum):
    PERSON = "PERSON"
    ORG = "ORG"
    LOC = "LOC"
    MALWARE = "MALWARE"
    CVE = "CVE"
    IP = "IP"
    DOMAIN = "DOMAIN"
    HASH = "HASH"
    URL = "URL"
    CAMPAIGN = "CAMPAIGN"
    THREAT_ACTOR = "THREAT_ACTOR"


class ReportStatus(str, enum.Enum):
    draft = "draft"
    generated = "generated"
    published = "published"


class FeedbackAction(str, enum.Enum):
    approved = "approved"
    rejected = "rejected"
    edited = "edited"
