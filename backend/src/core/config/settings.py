"""
Application settings loaded from environment variables / .env file.
All modules import `settings` from this module — never access os.environ directly.
"""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", case_sensitive=False, extra="ignore"
    )

    # ── App ───────────────────────────────────────────────────────────────────
    app_name: str = "OSINT Threat Intelligence Platform"
    app_version: str = "1.0.0"
    app_env: str = "development"
    debug: bool = True
    secret_key: str = "change-me-in-production"

    # ── Database ──────────────────────────────────────────────────────────────
    database_url: str = (
        "postgresql+asyncpg://osint_user:osint_pass@postgres:5432/osint_db"
    )
    postgres_host: str = "postgres"
    postgres_port: int = 5432
    postgres_db: str = "osint_db"
    postgres_user: str = "osint_user"
    postgres_password: str = "osint_pass"

    # ── Redis ─────────────────────────────────────────────────────────────────
    redis_url: str = "redis://redis:6379/0"

    # ── ChromaDB ─────────────────────────────────────────────────────────────
    chroma_host: str = "chromadb"
    chroma_port: int = 8000
    chroma_collection: str = "osint_threats"

    # ── Ollama ────────────────────────────────────────────────────────────────
    ollama_host: str = "http://ollama:11434"
    ollama_model: str = "llama3"

    # ── Groq LLM (cloud — replaces Ollama) ───────────────────────────────────
    groq_api_key: str = ""
    groq_model: str = "llama3-8b-8192"
    llm_provider: str = "groq"  # "groq" | "ollama"
    # ── Embedding ─────────────────────────────────────────────────────────────
    embedding_model: str = "sentence-transformers/all-MiniLM-L6-v2"

    # ── OSINT sources ─────────────────────────────────────────────────────────
    news_api_key: str = ""
    guardian_api_key: str = ""
    cisa_feed_url: str = (
        "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json"
    )
    nvd_cve_url: str = "https://services.nvd.nist.gov/rest/json/cves/2.0"

    # ── Ingestion scheduler ───────────────────────────────────────────────────
    ingestion_interval_minutes: int = 30
    max_articles_per_run: int = 100

    @property
    def is_production(self) -> bool:
        return self.app_env == "production"


@lru_cache
def get_settings() -> Settings:
    """Cached singleton — safe to import at module level."""
    return Settings()


# Module-level singleton for direct imports
settings = get_settings()
