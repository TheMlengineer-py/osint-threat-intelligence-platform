"""
Pydantic schemas for reports and copilot endpoints.
"""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel


class ReportCreateIn(BaseModel):
    title: str = "OSINT Threat Intelligence Report"
    threat_ids: list[str] = []
    format: str = "json"


class ReportOut(BaseModel):
    id: str
    title: str
    content: str | None = None
    status: str | None = "published"
    created_at: str | None = None
    threat_count: int | None = None
    format: str | None = "json"

    class Config:
        from_attributes = True


class CopilotRequest(BaseModel):
    query: str
    conversation_history: list[dict[str, Any]] = []
    max_context_docs: int = 5


class CopilotResponse(BaseModel):
    answer: str
    sources: list[dict[str, Any]] = []
    follow_up_questions: list[str] = []
