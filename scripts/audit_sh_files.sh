#!/usr/bin/env bash
# Audits .sh files in repo root — identifies unused/redundant ones
echo ""
echo "=== .sh File Audit ==="
echo ""

ROOT="/mnt/c/Users/playground/OSINT/osint-threat-intelligence-platform"

declare -A STATUS=(
  [add-missing-files.sh]="UNUSED  — superseded by stage6_fix.sh"
  [render-deploy.sh]="KEEP    — used for Render deployment"
  [repo_inspect.sh]="UNUSED  — replaced by scripts/tree.py"
  [run_all.sh]="KEEP    — starts backend + frontend"
  [setup_ingestion.sh]="UNUSED  — ingestion now runs via scheduler"
  [start.sh]="KEEP    — docker-compose start"
  [test.sh]="KEEP    — runs all tests"
  [wsl-setup.sh]="KEEP    — WSL environment setup"
)

for f in "$ROOT"/*.sh; do
  name=$(basename "$f")
  label=${STATUS[$name]:-"REVIEW  — check if still needed"}
  echo "  $label  →  $name"
done

echo ""
echo "=== To remove unused files ==="
echo "  rm add-missing-files.sh repo_inspect.sh setup_ingestion.sh"
echo ""
