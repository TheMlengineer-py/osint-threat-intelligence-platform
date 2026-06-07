"""
SQLAlchemy ORM models for threat-related tables.
"""

import uuid

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from src.database.engine import Base
from src.models.orm.base import (
    FeedbackAction,
    SeverityLevel,
    SourceType,
    ThreatCategory,
)


class Source(Base):
    """Registered OSINT data source."""

    __tablename__ = "sources"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(200), nullable=False)
    url = Column(Text)
    source_type = Column(Enum(SourceType, name="source_type"), nullable=False)
    credibility = Column(Float, default=0.75)  # 0-1 trustworthiness score
    is_active = Column(Boolean, default=True)
    last_fetched = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    documents = relationship("ThreatDocument", back_populates="source")


class ThreatDocument(Base):
    """Raw ingested document before NLP processing."""

    __tablename__ = "threat_documents"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    source_id = Column(
        UUID(as_uuid=True), ForeignKey("sources.id", ondelete="SET NULL")
    )
    title = Column(Text, nullable=False)
    raw_content = Column(Text, nullable=False)
    clean_content = Column(Text)
    url = Column(Text)
    language = Column(String(10), default="en")
    source_type = Column(Enum(SourceType, name="source_type"))
    published_at = Column(DateTime(timezone=True))
    fetched_at = Column(DateTime(timezone=True), server_default=func.now())
    is_processed = Column(Boolean, default=False)
    chroma_doc_id = Column(String(100))  # ChromaDB document ID
    doc_metadata = Column("metadata", JSONB, default={})

    source = relationship("Source", back_populates="documents")
    threat = relationship("Threat", back_populates="document", uselist=False)


class Threat(Base):
    """
    Processed, classified, and risk-scored threat record.
    One Threat is derived from one ThreatDocument after the NLP+AI pipeline.
    """

    __tablename__ = "threats"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    document_id = Column(
        UUID(as_uuid=True), ForeignKey("threat_documents.id", ondelete="CASCADE")
    )
    title = Column(Text, nullable=False)
    summary = Column(Text)
    category = Column(
        Enum(ThreatCategory, name="threat_category"),
        nullable=False,
        default=ThreatCategory.other,
    )
    severity = Column(
        Enum(SeverityLevel, name="severity_level"),
        nullable=False,
        default=SeverityLevel.medium,
    )

    # Risk formula: risk_score = likelihood × impact × confidence
    risk_score = Column(Float)
    likelihood = Column(Float)
    impact = Column(Float)
    confidence = Column(Float)

    iocs = Column(JSONB, default=[])  # [{type, value}]
    mitre_techniques = Column(JSONB, default=[])  # [{technique_id, source}]
    affected_sectors = Column(JSONB, default=[])

    source_url = Column(Text)
    source_type = Column(Enum(SourceType, name="source_type"))
    detected_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    is_active = Column(Boolean, default=True)
    analyst_verified = Column(Boolean, default=False)
    threat_metadata = Column("metadata", JSONB, default={})

    document = relationship("ThreatDocument", back_populates="threat")
    entity_links = relationship(
        "ThreatEntityLink", back_populates="threat", cascade="all, delete-orphan"
    )
    alerts = relationship(
        "Alert", back_populates="threat", cascade="all, delete-orphan"
    )
    feedback = relationship(
        "AnalystFeedback", back_populates="threat", cascade="all, delete-orphan"
    )


class Alert(Base):
    """Real-time alert surfaced from a High/Critical threat."""

    __tablename__ = "alerts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    threat_id = Column(UUID(as_uuid=True), ForeignKey("threats.id", ondelete="CASCADE"))
    title = Column(Text, nullable=False)
    description = Column(Text)
    severity = Column(Enum(SeverityLevel, name="severity_level"), nullable=False)
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    threat = relationship("Threat", back_populates="alerts")


class AnalystFeedback(Base):
    """Human-in-the-loop feedback from the analyst dashboard."""

    __tablename__ = "analyst_feedback"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    threat_id = Column(UUID(as_uuid=True), ForeignKey("threats.id", ondelete="CASCADE"))
    action = Column(Enum(FeedbackAction, name="feedback_action"), nullable=False)
    notes = Column(Text)
    corrected_severity = Column(Enum(SeverityLevel, name="severity_level"))
    corrected_category = Column(Enum(ThreatCategory, name="threat_category"))
    analyst_id = Column(String(100), default="analyst")
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    threat = relationship("Threat", back_populates="feedback")
