"""
Database Engine Configuration
"""

import os

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from sqlalchemy.pool import StaticPool

# Get database URL from environment
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./osint.db")
# Strip async drivers — this module uses sync SQLAlchemy only
DATABASE_URL = DATABASE_URL.replace("sqlite+aiosqlite://", "sqlite://")
DATABASE_URL = DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://")
DATABASE_URL = DATABASE_URL.replace("postgres+asyncpg://", "postgresql://")
DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://")

# Check if using SQLite or PostgreSQL
is_sqlite = DATABASE_URL.startswith("sqlite")

if is_sqlite:
    # SQLite Configuration (Synchronous)
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
        echo=os.getenv("SQLALCHEMY_ECHO", "False").lower() == "true",
    )
else:
    # PostgreSQL Configuration (Asynchronous)
    engine = create_engine(
        DATABASE_URL, echo=os.getenv("SQLALCHEMY_ECHO", "False").lower() == "true"
    )

# Create declarative base
Base = declarative_base()

# Create session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db():
    """Get database session"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
