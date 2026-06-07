"""
Database Session Management
"""

from sqlalchemy.orm import Session, sessionmaker

from src.database.engine import engine

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db() -> Session:
    """Get database session"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
