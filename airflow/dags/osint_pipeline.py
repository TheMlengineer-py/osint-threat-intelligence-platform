"""
OSINT Daily Intelligence Pipeline — Airflow DAG
================================================
Schedule:  Every day at 06:00 UTC
Pipeline:
    1. Health check (verify backend is alive)
    2. Ingest CISA/NVD      (highest credibility — run first)
    3. Ingest RSS feeds      (news sources)
    4. Run NLP processing    (classify + score + embed)
    5. Generate daily report (AI summary of new threats)
    6. Notify on failures    (email/Slack alert)

Run manually:
    airflow dags trigger osint_daily_pipeline
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timedelta

import requests
from airflow import DAG
from airflow.operators.python import PythonOperator, BranchPythonOperator
from airflow.operators.empty import EmptyOperator
from airflow.utils.trigger_rule import TriggerRule

log = logging.getLogger(__name__)

# ── Config ────────────────────────────────────────────────────────────────────
BACKEND_URL = "https://osint-threat-intelligence-platform-82p9.onrender.com/api/v1"
TIMEOUT = 60  # seconds per request

DEFAULT_ARGS = {
    "owner": "osint-platform",
    "depends_on_past": False,
    "start_date": datetime(2025, 1, 1),
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}

# ── Task functions ─────────────────────────────────────────────────────────────


def health_check(**ctx):
    """Verify backend API is reachable before starting pipeline."""
    try:
        r = requests.get(f"{BACKEND_URL.replace('/api/v1', '')}/health", timeout=10)
        r.raise_for_status()
        data = r.json()
        log.info("Backend healthy: %s", data)
        ctx["ti"].xcom_push(key="backend_version", value=data.get("version", "unknown"))
        return "healthy"
    except Exception as exc:
        log.error("Backend health check failed: %s", exc)
        raise RuntimeError(f"Backend not reachable: {exc}") from exc


def ingest_cisa(**ctx):
    """Ingest CISA Known Exploited Vulnerabilities feed."""
    r = requests.post(f"{BACKEND_URL}/threats/ingest/cisa", timeout=TIMEOUT)
    r.raise_for_status()
    result = r.json()
    log.info("CISA ingestion: %s", result)
    ctx["ti"].xcom_push(key="cisa_count", value=result.get("ingested", 0))
    return result


def ingest_rss(**ctx):
    """Ingest all configured RSS/news feeds."""
    r = requests.post(f"{BACKEND_URL}/threats/ingest/rss", timeout=TIMEOUT * 2)
    r.raise_for_status()
    result = r.json()
    log.info("RSS ingestion: %s", result)
    ctx["ti"].xcom_push(key="rss_count", value=result.get("ingested", 0))
    return result


def run_nlp_pipeline(**ctx):
    """Run NLP classification, risk scoring, and embedding on new documents."""
    r = requests.post(f"{BACKEND_URL}/threats/process", timeout=TIMEOUT * 5)
    r.raise_for_status()
    result = r.json()
    log.info("NLP pipeline result: %s", result)

    # Pull counts from XCom
    ti = ctx["ti"]
    cisa_count = ti.xcom_pull(key="cisa_count", task_ids="ingest_cisa") or 0
    rss_count = ti.xcom_pull(key="rss_count", task_ids="ingest_rss") or 0
    total_new = cisa_count + rss_count

    ti.xcom_push(key="total_ingested", value=total_new)
    ti.xcom_push(key="nlp_result", value=result)
    return result


def check_new_threats(**ctx):
    """Branch: only generate report if new threats were ingested."""
    ti = ctx["ti"]
    total_new = ti.xcom_pull(key="total_ingested", task_ids="run_nlp") or 0
    log.info("Total new threats ingested today: %d", total_new)

    if total_new > 0:
        return "generate_report"
    log.info("No new threats — skipping report generation")
    return "skip_report"


def generate_daily_report(**ctx):
    """Generate AI-powered daily intelligence report."""
    ti = ctx["ti"]
    run_date = ctx["ds"]  # YYYY-MM-DD

    payload = {
        "title": f"Daily Intelligence Report — {run_date}",
        "format": "json",
    }
    r = requests.post(f"{BACKEND_URL}/reports", json=payload, timeout=TIMEOUT * 3)
    r.raise_for_status()
    result = r.json()
    log.info("Daily report generated: %s", result.get("id"))
    ti.xcom_push(key="report_id", value=result.get("id"))
    return result


def verify_pipeline(**ctx):
    """Final verification — check stats and log summary."""
    ti = ctx["ti"]
    run_date = ctx["ds"]

    # Fetch current stats
    r = requests.get(f"{BACKEND_URL}/analytics/dashboard", timeout=TIMEOUT)
    r.raise_for_status()
    stats = r.json()

    ingested = ti.xcom_pull(key="total_ingested", task_ids="run_nlp") or 0
    report_id = ti.xcom_pull(key="report_id", task_ids="generate_report")
    nlp_result = ti.xcom_pull(key="nlp_result", task_ids="run_nlp") or {}

    summary = {
        "run_date": run_date,
        "new_threats": ingested,
        "total_threats": stats.get("total_threats", 0),
        "critical": stats.get("critical_threats", 0),
        "avg_risk": stats.get("avg_risk_score", 0),
        "report_id": report_id,
        "nlp_processed": nlp_result.get("results", {}).get("processed", 0),
    }

    log.info("Pipeline complete: %s", json.dumps(summary, indent=2))
    return summary


# ── DAG definition ─────────────────────────────────────────────────────────────
with DAG(
    dag_id="osint_daily_pipeline",
    description="Daily OSINT threat intelligence ingestion and analysis",
    default_args=DEFAULT_ARGS,
    schedule="0 6 * * *",  # 06:00 UTC every day
    catchup=False,
    max_active_runs=1,  # prevent overlapping runs
    tags=["osint", "intelligence", "daily"],
) as dag:

    # ── Task definitions ──────────────────────────────────────────────────────
    t_health = PythonOperator(
        task_id="health_check",
        python_callable=health_check,
    )

    t_cisa = PythonOperator(
        task_id="ingest_cisa",
        python_callable=ingest_cisa,
    )

    t_rss = PythonOperator(
        task_id="ingest_rss",
        python_callable=ingest_rss,
    )

    t_nlp = PythonOperator(
        task_id="run_nlp",
        python_callable=run_nlp_pipeline,
    )

    t_branch = BranchPythonOperator(
        task_id="check_new_threats",
        python_callable=check_new_threats,
    )

    t_report = PythonOperator(
        task_id="generate_report",
        python_callable=generate_daily_report,
    )

    t_skip = EmptyOperator(task_id="skip_report")

    t_verify = PythonOperator(
        task_id="verify_pipeline",
        python_callable=verify_pipeline,
        trigger_rule=TriggerRule.NONE_FAILED_MIN_ONE_SUCCESS,
    )

    # ── Pipeline graph ────────────────────────────────────────────────────────
    #
    #  health_check
    #       ├── ingest_cisa ──┐
    #       └── ingest_rss  ──┴── run_nlp ── check_new_threats ──┬── generate_report ──┐
    #                                                             └── skip_report      ──┴── verify_pipeline
    #
    t_health >> [t_cisa, t_rss] >> t_nlp >> t_branch
    t_branch >> [t_report, t_skip] >> t_verify
