import uuid

from sqlalchemy import Boolean, Column, DateTime, Enum, Float, ForeignKey, String, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from src.database.engine import Base
from src.models.orm.base import (
    FeedbackAction,
    SeverityLevel,
    SourceType,
    ThreatCategory,
)


def _uuid():
    return str(uuid.uuid4())


class Source(Base):
    __tablename__ = "sources"
    id = Column(String(36), primary_key=True, default=_uuid)
    name = Column(String(200), nullable=False)
    url = Column(Text)
    source_type = Column(Enum(SourceType), nullable=False, default=SourceType.rss)
    credibility = Column(Float, default=0.75)
    is_active = Column(Boolean, default=True)
    last_fetched = Column(DateTime)
    created_at = Column(DateTime, server_default=func.now())
    documents = relationship("ThreatDocument", back_populates="source")


class ThreatDocument(Base):
    __tablename__ = "threat_documents"
    id = Column(String(36), primary_key=True, default=_uuid)
    source_id = Column(
        String(36), ForeignKey("sources.id", ondelete="SET NULL"), nullable=True
    )
    title = Column(Text, nullable=False)
    raw_content = Column(Text, nullable=False)
    clean_content = Column(Text)
    url = Column(Text)
    language = Column(String(10), default="en")
    source_type = Column(Enum(SourceType), default=SourceType.rss)
    published_at = Column(DateTime)
    fetched_at = Column(DateTime, server_default=func.now())
    is_processed = Column(Boolean, default=False)
    chroma_doc_id = Column(String(100))
    doc_metadata = Column(Text, default="{}")
    source = relationship("Source", back_populates="documents")
    threat = relationship("Threat", back_populates="document", uselist=False)


class Threat(Base):
    __tablename__ = "threats"
    id = Column(String(36), primary_key=True, default=_uuid)
    document_id = Column(
        String(36), ForeignKey("threat_documents.id", ondelete="CASCADE"), nullable=True
    )
    title = Column(Text, nullable=False)
    summary = Column(Text)
    category = Column(
        Enum(ThreatCategory), nullable=False, default=ThreatCategory.other
    )
    severity = Column(Enum(SeverityLevel), nullable=False, default=SeverityLevel.medium)
    risk_score = Column(Float, default=0.0)
    likelihood = Column(Float, default=0.5)
    impact = Column(Float, default=0.5)
    confidence = Column(Float, default=0.5)
    iocs = Column(Text, default="[]")
    mitre_techniques = Column(Text, default="[]")
    affected_sectors = Column(Text, default="[]")
    source = Column(String(255))
    source_url = Column(Text)
    source_type = Column(Enum(SourceType), default=SourceType.rss)
    detected_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
    is_active = Column(Boolean, default=True)
    analyst_verified = Column(Boolean, default=False)
    threat_metadata = Column(Text, default="{}")
    document = relationship("ThreatDocument", back_populates="threat")
    alerts = relationship(
        "Alert", back_populates="threat", cascade="all, delete-orphan"
    )
    feedback = relationship(
        "AnalystFeedback", back_populates="threat", cascade="all, delete-orphan"
    )


class Alert(Base):
    __tablename__ = "alerts"
    id = Column(String(36), primary_key=True, default=_uuid)
    threat_id = Column(String(36), ForeignKey("threats.id", ondelete="CASCADE"))
    title = Column(Text, nullable=False)
    description = Column(Text)
    severity = Column(Enum(SeverityLevel), nullable=False, default=SeverityLevel.medium)
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, server_default=func.now())
    threat = relationship("Threat", back_populates="alerts")


class AnalystFeedback(Base):
    __tablename__ = "analyst_feedback"
    id = Column(String(36), primary_key=True, default=_uuid)
    threat_id = Column(String(36), ForeignKey("threats.id", ondelete="CASCADE"))
    action = Column(Enum(FeedbackAction), nullable=False)
    notes = Column(Text)
    corrected_severity = Column(Enum(SeverityLevel))
    corrected_category = Column(Enum(ThreatCategory))
    analyst_id = Column(String(100), default="analyst")
    created_at = Column(DateTime, server_default=func.now())
    threat = relationship("Threat", back_populates="feedback")
