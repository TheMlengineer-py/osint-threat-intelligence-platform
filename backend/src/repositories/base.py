"""Base repository for database operations."""

from typing import Any, Generic, TypeVar
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.database.engine import Base

T = TypeVar("T", bound=Base)


class BaseRepository(Generic[T]):
    """Base repository with CRUD operations."""

    def __init__(self, session: AsyncSession, model: type[T]):
        """Initialize repository."""
        self.session = session
        self.model = model

    async def create(self, obj_in: dict[str, Any]) -> T:
        """Create new record."""
        db_obj = self.model(**obj_in)
        self.session.add(db_obj)
        await self.session.commit()
        await self.session.refresh(db_obj)
        return db_obj

    async def get(self, id: UUID) -> T | None:
        """Get record by ID."""
        return await self.session.get(self.model, id)

    async def get_multi(
        self, skip: int = 0, limit: int = 100, **filters: Any
    ) -> tuple[list[T], int]:
        """Get multiple records with pagination."""
        query = select(self.model)

        # Apply filters
        for key, value in filters.items():
            if hasattr(self.model, key):
                query = query.where(getattr(self.model, key) == value)

        # Count total
        count_query = select(self.model)
        for key, value in filters.items():
            if hasattr(self.model, key):
                count_query = count_query.where(getattr(self.model, key) == value)

        result = await self.session.execute(count_query)
        total = len(result.all())

        # Paginate
        query = query.offset(skip).limit(limit)
        result = await self.session.execute(query)
        return result.scalars().all(), total

    async def update(self, id: UUID, obj_in: dict[str, Any]) -> T | None:
        """Update record."""
        db_obj = await self.get(id)
        if not db_obj:
            return None

        for field, value in obj_in.items():
            if hasattr(db_obj, field):
                setattr(db_obj, field, value)

        await self.session.commit()
        await self.session.refresh(db_obj)
        return db_obj

    async def delete(self, id: UUID) -> bool:
        """Delete record."""
        db_obj = await self.get(id)
        if not db_obj:
            return False

        await self.session.delete(db_obj)
        await self.session.commit()
        return True
