"""
Threat API Schemas — aligned with models/orm/threat.py columns.
"""

from datetime import datetime

from pydantic import BaseModel


class ThreatCreate(BaseModel):
    title: str
    summary: str | None = None
    category: str | None = "other"
    severity: str | None = "medium"
    source: str | None = None
    source_url: str | None = None
    risk_score: float | None = 0.0


class ThreatResponse(BaseModel):
    id: str
    title: str
    summary: str | None = None
    category: str | None = None
    severity: str | None = None
    risk_score: float | None = None
    likelihood: float | None = None
    impact: float | None = None
    confidence: float | None = None
    source: str | None = None
    source_url: str | None = None
    source_type: str | None = None
    iocs: str | None = None
    detected_at: datetime | None = None
    updated_at: datetime | None = None
    is_active: bool | None = True
    analyst_verified: bool | None = False

    class Config:
        from_attributes = True


class ThreatListResponse(BaseModel):
    total: int
    threats: list[ThreatResponse]
