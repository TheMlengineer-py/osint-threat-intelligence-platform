"""Threat repository."""

from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from src.models.orm.threat import Threat
from src.repositories.base import BaseRepository


class ThreatRepository(BaseRepository[Threat]):
    """Threat repository."""

    def __init__(self, session: AsyncSession):
        """Initialize threat repository."""
        super().__init__(session, Threat)

    async def get_by_source(self, source: str, limit: int = 100) -> list[Threat]:
        """Get threats by source."""
        query = select(self.model).where(self.model.source == source).limit(limit)
        result = await self.session.execute(query)
        return result.scalars().all()

    async def get_by_severity(
        self, min_severity: float = 0.0, limit: int = 100
    ) -> list[Threat]:
        """Get threats by severity threshold."""
        query = (
            select(self.model)
            .where(self.model.severity_score >= min_severity)
            .order_by(desc(self.model.severity_score))
            .limit(limit)
        )
        result = await self.session.execute(query)
        return result.scalars().all()

    async def get_by_status(self, status: str, limit: int = 100) -> list[Threat]:
        """Get threats by status."""
        query = select(self.model).where(self.model.status == status).limit(limit)
        result = await self.session.execute(query)
        return result.scalars().all()

    async def search(
        self,
        query_str: str,
        threat_type: str | None = None,
        skip: int = 0,
        limit: int = 100,
    ) -> tuple[list[Threat], int]:
        """Search threats."""
        query = select(self.model)

        # Text search
        query = query.where(
            self.model.title.ilike(f"%{query_str}%")
            | self.model.description.ilike(f"%{query_str}%")
        )

        if threat_type:
            query = query.where(self.model.threat_type == threat_type)

        # Count
        count_result = await self.session.execute(query)
        total = len(count_result.all())

        # Paginate
        query = query.offset(skip).limit(limit)
        result = await self.session.execute(query)
        return result.scalars().all(), total
