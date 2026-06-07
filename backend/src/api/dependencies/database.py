"""
FastAPI dependency that provides a scoped async DB session per request.
Import `get_db` into any route that needs database access.
"""

from src.database.session import get_db  # re-export for cleaner import paths

__all__ = ["get_db"]
