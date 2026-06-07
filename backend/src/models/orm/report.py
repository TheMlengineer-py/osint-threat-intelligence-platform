"""
SQLAlchemy ORM model for AI-generated intelligence reports.
"""

import uuid

from sqlalchemy import Column, DateTime, Enum, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.sql import func

from src.database.engine import Base
from src.models.orm.base import ReportStatus


class Report(Base):
    """
    Structured intelligence report produced by the Reporting Agent.
    Can be draft (queued), generated (LLM complete), or published.
    """

    __tablename__ = "reports"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title = Column(String(500), nullable=False)
    content = Column(Text)  # full LLM-generated report text
    summary = Column(Text)  # executive summary (first 500 chars)
    status = Column(
        Enum(ReportStatus, name="report_status"), default=ReportStatus.draft
    )
    threat_ids = Column(JSONB, default=[])  # UUIDs of source threats
    entity_ids = Column(JSONB, default=[])
    created_by = Column(String(100), default="system")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    published_at = Column(DateTime(timezone=True))
    file_path = Column(Text)  # optional exported PDF path
    report_metadata = Column("metadata", JSONB, default={})
