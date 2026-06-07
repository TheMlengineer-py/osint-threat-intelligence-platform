"""Pydantic schemas for analytics/dashboard endpoints."""

from typing import Any

from pydantic import BaseModel


class ThreatTrendPoint(BaseModel):
    date: str
    total: int
    high: int
    medium: int
    low: int


class CategoryCount(BaseModel):
    category: str
    count: int
    percentage: float


class AnalyticsSummary(BaseModel):
    total_threats: int
    high_severity: int
    new_alerts: int
    monitored_sources: int
    reports_generated: int
    trend_data: list[ThreatTrendPoint]
    category_distribution: list[CategoryCount]
    top_threat_actors: list[dict[str, Any]]
    source_distribution: list[dict[str, Any]]
