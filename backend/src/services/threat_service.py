"""Threat service for business logic."""

import logging
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from src.models.orm.threat import Threat
from src.repositories.threat import ThreatRepository

logger = logging.getLogger(__name__)


class ThreatService:
    """Threat service."""

    def __init__(self, session: AsyncSession):
        """Initialize threat service."""
        self.session = session
        self.repository = ThreatRepository(session)

    async def create_threat(self, threat_data: dict) -> Threat:
        """Create a new threat."""
        logger.info(f"Creating threat: {threat_data.get('title')}")
        return await self.repository.create(threat_data)

    async def get_threat(self, threat_id: UUID) -> Threat | None:
        """Get threat by ID."""
        return await self.repository.get(threat_id)

    async def list_threats(
        self,
        skip: int = 0,
        limit: int = 100,
        status: str | None = None,
        threat_type: str | None = None,
    ) -> tuple[list[Threat], int]:
        """List threats with filtering."""
        filters = {}
        if status:
            filters["status"] = status
        if threat_type:
            filters["threat_type"] = threat_type

        return await self.repository.get_multi(skip=skip, limit=limit, **filters)

    async def update_threat(self, threat_id: UUID, threat_data: dict) -> Threat | None:
        """Update threat."""
        logger.info(f"Updating threat: {threat_id}")
        return await self.repository.update(threat_id, threat_data)

    async def delete_threat(self, threat_id: UUID) -> bool:
        """Delete threat."""
        logger.info(f"Deleting threat: {threat_id}")
        return await self.repository.delete(threat_id)

    async def get_high_severity_threats(self, limit: int = 50) -> list[Threat]:
        """Get high severity threats."""
        return await self.repository.get_by_severity(min_severity=7.0, limit=limit)

    async def search_threats(
        self,
        query: str,
        threat_type: str | None = None,
        skip: int = 0,
        limit: int = 100,
    ) -> tuple[list[Threat], int]:
        """Search threats."""
        return await self.repository.search(query, threat_type, skip, limit)
