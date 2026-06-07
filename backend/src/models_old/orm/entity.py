"""
SQLAlchemy ORM models for entities and their links to threats.
Entities represent named objects extracted from threat documents:
actors, malware families, organisations, IPs, domains, hashes, CVEs.
"""

import uuid

from sqlalchemy import (
    Column,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from src.database.engine import Base
from src.models.orm.base import EntityType


class Entity(Base):
    """
    A named entity extracted from OSINT threat documents.
    Unique on (name, entity_type) to allow merging duplicates.
    """

    __tablename__ = "entities"
    __table_args__ = (
        UniqueConstraint("name", "entity_type", name="uq_entity_name_type"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(500), nullable=False)
    entity_type = Column(Enum(EntityType, name="entity_type"), nullable=False)
    aliases = Column(JSONB, default=[])  # alternative names / spellings
    description = Column(Text)
    first_seen = Column(DateTime(timezone=True), server_default=func.now())
    last_seen = Column(DateTime(timezone=True), server_default=func.now())
    threat_count = Column(Integer, default=0)  # denormalised counter
    entity_metadata = Column("metadata", JSONB, default={})

    threat_links = relationship("ThreatEntityLink", back_populates="entity")


class ThreatEntityLink(Base):
    """
    Many-to-many join between Threat and Entity.
    The `relationship` field stores the semantic link type
    (e.g. uses, targets, attributed_to, exploits).
    """

    __tablename__ = "threat_entity_links"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    threat_id = Column(UUID(as_uuid=True), ForeignKey("threats.id", ondelete="CASCADE"))
    entity_id = Column(
        UUID(as_uuid=True), ForeignKey("entities.id", ondelete="CASCADE")
    )
    relationship = Column(String(100), default="mentioned_in")
    confidence = Column(Float, default=0.8)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    threat = relationship("Threat", back_populates="entity_links")
    entity = relationship("Entity", back_populates="threat_links")
