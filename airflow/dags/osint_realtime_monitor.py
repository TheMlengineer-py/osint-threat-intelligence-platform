"""
OSINT Real-Time Monitor — runs every hour.
Lightweight: only ingests + processes, no report generation.
"""

from __future__ import annotations
from datetime import datetime, timedelta
import logging
import requests

from airflow import DAG
from airflow.operators.python import PythonOperator

log = logging.getLogger(__name__)
BACKEND_URL = "https://osint-threat-intelligence-platform-82p9.onrender.com/api/v1"

DEFAULT_ARGS = {
    "owner": "osint-platform",
    "start_date": datetime(2025, 1, 1),
    "retries": 1,
    "retry_delay": timedelta(minutes=2),
}


def quick_ingest(**ctx):
    """Fast ingest: CISA only (most critical source)."""
    try:
        r = requests.post(f"{BACKEND_URL}/threats/ingest/cisa", timeout=30)
        result = r.json()
        log.info("Quick ingest: %s", result)
        return result
    except Exception as exc:
        log.warning("Quick ingest failed: %s", exc)
        return {}


def quick_process(**ctx):
    """Process any pending NLP documents."""
    try:
        r = requests.post(f"{BACKEND_URL}/threats/process", timeout=120)
        return r.json()
    except Exception as exc:
        log.warning("Quick process failed: %s", exc)
        return {}


with DAG(
    dag_id="osint_hourly_monitor",
    description="Hourly OSINT feed check for critical threats",
    default_args=DEFAULT_ARGS,
    schedule="0 * * * *",  # every hour
    catchup=False,
    max_active_runs=1,
    tags=["osint", "monitor", "hourly"],
) as dag:

    PythonOperator(
        task_id="quick_ingest", python_callable=quick_ingest
    ) >> PythonOperator(task_id="quick_process", python_callable=quick_process)
