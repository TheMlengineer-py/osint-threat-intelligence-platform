"""
Ingestion scheduler — runs on startup and every 30 minutes.
Also exposes a manual trigger endpoint.
"""

import logging
from datetime import datetime

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger

from src.core.config.settings import settings

logger = logging.getLogger(__name__)
_scheduler = AsyncIOScheduler()
_last_run: datetime | None = None
_last_result: dict = {}


async def run_full_pipeline() -> dict:
    """Full ingest + NLP cycle."""
    global _last_run, _last_result
    _last_run = datetime.utcnow()
    logger.info("Ingestion pipeline started at %s", _last_run)

    results: dict = {}
    try:
        from src.ingestion.cisa_collector import cisa_collector

        results["cisa"] = await cisa_collector.collect()
    except Exception as exc:
        results["cisa"] = {"error": str(exc)}

    try:
        from src.ingestion.rss_collector import rss_collector

        results["rss"] = await rss_collector.collect_all()
    except Exception as exc:
        results["rss"] = {"error": str(exc)}

    try:
        from src.services.nlp_service import NLPService

        nlp = NLPService()
        results["nlp"] = await nlp.process_pending()
    except Exception as exc:
        results["nlp"] = {"error": str(exc)}

    _last_result = results
    logger.info("Ingestion pipeline complete: %s", results)
    return results


def start_scheduler():
    """Start APScheduler — runs on startup + every 30 min."""
    import asyncio

    _scheduler.add_job(
        run_full_pipeline,
        trigger=IntervalTrigger(minutes=settings.ingestion_interval_minutes),
        id="periodic_ingestion",
        replace_existing=True,
        misfire_grace_time=300,
    )

    _scheduler.start()
    logger.info(
        "Scheduler started — interval: %d min", settings.ingestion_interval_minutes
    )

    # Run immediately on startup in background
    asyncio.create_task(run_full_pipeline())


def stop_scheduler():
    _scheduler.shutdown(wait=False)


def get_status() -> dict:
    return {
        "last_run": _last_run.isoformat() if _last_run else None,
        "last_result": _last_result,
        "next_run": (
            str(_scheduler.get_job("periodic_ingestion").next_run_time)
            if _scheduler.get_job("periodic_ingestion")
            else None
        ),
    }
