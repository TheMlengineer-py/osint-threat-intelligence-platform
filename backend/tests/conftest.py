# """
# Shared pytest fixtures for all backend tests.
# Uses an in-memory SQLite database — never touches osint.db.
# """
# import pytest
# import pytest_asyncio
# from httpx import AsyncClient, ASGITransport
#
# # ── Database fixtures ──────────────────────────────────────────────────────────
#
# @pytest.fixture(scope="session")
# def anyio_backend():
#     return "asyncio"
#
#
# @pytest_asyncio.fixture(scope="function")
# async def test_db():
#     """
#     Provide a clean in-memory async SQLite database for each test function.
#     Creates all tables from ORM models, yields engine, then drops everything.
#     """
#     from sqlalchemy.ext.asyncio import (
#         create_async_engine, AsyncSession, async_sessionmaker
#     )
#     from src.models.orm.base import Base
#     # Import all ORM models so metadata is populated
#     import src.models.orm.threat   # noqa: F401
#     import src.models.orm.entity   # noqa: F401
#     import src.models.orm.report   # noqa: F401
#
#     engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
#     async with engine.begin() as conn:
#         await conn.run_sync(Base.metadata.create_all)
#
#     TestSession = async_sessionmaker(
#         engine, class_=AsyncSession, expire_on_commit=False
#     )
#
#     # Override FastAPI dependency
#     from src.main import app
#     from src.api.dependencies.database import get_db
#
#     async def override_get_db():
#         async with TestSession() as session:
#             yield session
#
#     app.dependency_overrides[get_db] = override_get_db
#
#     yield engine
#
#     async with engine.begin() as conn:
#         await conn.run_sync(Base.metadata.drop_all)
#     await engine.dispose()
#     app.dependency_overrides.clear()
#
#
# @pytest_asyncio.fixture(scope="function")
# async def client(test_db):
#     """
#     Async HTTP test client wired to test DB.
#     All routes are accessible without authentication (DEBUG mode).
#     """
#     from src.main import app
#     async with AsyncClient(
#         transport=ASGITransport(app=app),
#         base_url="http://test",
#     ) as ac:
#         yield ac
#
#
# # ── Sample data fixtures ───────────────────────────────────────────────────────
#
# @pytest.fixture
# def sample_cve_text():
#     return (
#         "CISA warns of critical CVE-2024-9999 vulnerability in Apache HTTP Server. "
#         "Remote code execution possible without authentication. "
#         "CVSS score 9.8. Patch available — update immediately. "
#         "C2 traffic observed at 185.220.101.45. "
#         "Malware hash: " + "a" * 64
#     )
#
#
# @pytest.fixture
# def sample_ransomware_text():
#     return (
#         "LockBit 3.0 ransomware group launches new campaign targeting healthcare. "
#         "Malware delivered via phishing email with trojan dropper. "
#         "Encrypted C2 at malicious-domain.com. "
#         "IoC hash: " + "b" * 64
#     )
#
#
# @pytest.fixture
# def sample_apt_text():
#     return (
#         "Nation-state APT group Fancy Bear (APT28) conducts advanced persistent "
#         "threat campaign against government entities using zero-day exploit. "
#         "Attributed to Russian intelligence. MITRE ATT&CK T1566.001."
#     )

"""
Test configuration and fixtures.
Uses an in-memory SQLite DB — isolated from production osint.db.
"""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from src.api.dependencies.database import get_db
from src.database.engine import Base
from src.main import app

# ── In-memory test database ───────────────────────────────────────────────────
TEST_DB_URL = "sqlite:///:memory:"

test_engine = create_engine(
    TEST_DB_URL,
    connect_args={"check_same_thread": False},
)
TestingSessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=test_engine,
)


@pytest.fixture(scope="session", autouse=True)
def create_tables():
    """Create all tables once per test session."""
    # Import only the models we actually use — entity.py is broken (Column/relationship bug)
    import src.models.orm.base  # noqa: F401  registers enums
    import src.models.orm.threat  # noqa: F401  registers Threat, ThreatDocument, etc.

    Base.metadata.create_all(bind=test_engine)
    yield
    Base.metadata.drop_all(bind=test_engine)


@pytest.fixture
def test_db(create_tables):
    """Yield a clean DB session, rolled back after each test."""
    connection = test_engine.connect()
    transaction = connection.begin()
    session = TestingSessionLocal(bind=connection)
    yield session
    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture
def client(test_db):
    """FastAPI test client wired to the test DB."""

    def override_get_db():
        try:
            yield test_db
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()
