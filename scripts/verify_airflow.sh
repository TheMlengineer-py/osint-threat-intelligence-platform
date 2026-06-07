#!/usr/bin/env bash
# How to verify Airflow DAG locally and in production

echo ""
echo "=== AIRFLOW DAG VERIFICATION GUIDE ==="
echo ""

echo "--- LOCAL SETUP ---"
echo ""
echo "1. Install Airflow:"
echo "   pip install apache-airflow==2.9.0 --quiet"
echo ""
echo "2. Configure:"
echo "   export AIRFLOW_HOME=\$(pwd)/airflow"
echo "   airflow db migrate"
echo "   airflow users create \\"
echo "     --username admin --password osint123 \\"
echo "     --firstname Admin --lastname User \\"
echo "     --role Admin --email admin@local"
echo ""
echo "3. Start services (2 terminals):"
echo "   airflow webserver --port 8080    # Terminal A"
echo "   airflow scheduler                # Terminal B"
echo ""
echo "4. Open UI: http://localhost:8080  (admin / osint123)"
echo ""
echo "5. Verify DAG is listed:"
echo "   airflow dags list | grep osint"
echo ""
echo "6. Trigger manually:"
echo "   airflow dags trigger osint_daily_pipeline"
echo ""
echo "7. Check run status:"
echo "   airflow dags state osint_daily_pipeline \$(date +%Y-%m-%dT%H:%M:%S)"
echo ""
echo "8. View task logs:"
echo "   airflow tasks logs osint_daily_pipeline health_check latest"
echo ""
echo "--- VALIDATE DAG STRUCTURE (no UI needed) ---"
echo ""
python3 - << 'PYEOF'
import sys
sys.path.insert(0, 'airflow/dags')
try:
    from osint_pipeline import dag
    print(f"  DAG ID:        {dag.dag_id}")
    print(f"  Schedule:      {dag.schedule_interval}")
    print(f"  Tasks ({len(dag.tasks)}):  {[t.task_id for t in dag.tasks]}")
    print(f"  Dependencies:")
    for task in dag.tasks:
        ups = [u.task_id for u in task.upstream_list]
        if ups:
            print(f"    {' + '.join(ups)} -> {task.task_id}")
    print("  DAG structure VALID")
except Exception as e:
    print(f"  DAG validation error: {e}")
PYEOF

echo ""
echo "--- VISUALIZE DAG (CLI) ---"
echo ""
echo "  airflow dags show osint_daily_pipeline"
echo "  airflow dags show osint_daily_pipeline --imgcat  # requires imgcat"
echo ""
echo "--- PRODUCTION (Render / cloud) ---"
echo ""
echo "  Option A: Astro Cloud (free tier) — connect GitHub repo"
echo "    https://www.astronomer.io/try-astro/"
echo ""
echo "  Option B: MWAA (AWS) — managed Airflow"
echo "  Option C: Cloud Composer (GCP) — managed Airflow"
echo ""
echo "  DAG auto-deploys when airflow/dags/*.py is pushed to main branch"
echo ""
