"""
Structured logging setup.
Uses structlog for app logs.
Configures stdlib logging to NOT intercept groq/httpx internal calls.
"""

import logging
import logging.config

import structlog

# ── Suppress noisy third-party loggers ────────────────────────────────────────
SUPPRESS = [
    "groq",
    "groq._base_client",
    "httpx",
    "httpcore",
    "urllib3",
    "asyncio",
    "watchfiles",
]
for name in SUPPRESS:
    logging.getLogger(name).setLevel(logging.WARNING)
    logging.getLogger(name).propagate = False


def setup_logging(level: str = "INFO") -> None:
    """Configure structlog. Call once at startup."""
    shared_processors = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="%H:%M:%S"),
        structlog.processors.StackInfoRenderer(),
    ]

    structlog.configure(
        processors=shared_processors + [structlog.dev.ConsoleRenderer()],
        wrapper_class=structlog.make_filtering_bound_logger(logging.INFO),
        logger_factory=structlog.PrintLoggerFactory(),
        cache_logger_on_first_use=True,
    )


# Module-level logger for imports
logger = structlog.get_logger("osint")
