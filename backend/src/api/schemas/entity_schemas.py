"""Pydantic schemas for entity and knowledge graph endpoints."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from src.models.orm.base import EntityType


class EntityOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    entity_type: EntityType
    aliases: list[str] = []
    description: str | None = None
    first_seen: datetime
    last_seen: datetime
    threat_count: int


class GraphNode(BaseModel):
    id: str
    name: str
    entity_type: str
    threat_count: int


class GraphEdge(BaseModel):
    source: str
    target: str
    relationship: str
    confidence: float


class EntityGraphOut(BaseModel):
    nodes: list[GraphNode]
    edges: list[GraphEdge]
