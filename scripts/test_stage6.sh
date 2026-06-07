bash

#!/usr/bin/env bash
# =============================================================================
# STAGE 6 TEST SUITE
# Run from: project root (osint-threat-intelligence-platform/)
# Usage:    bash scripts/test_stage6.sh
# =============================================================================
FRONTEND="http://localhost:5174"
BACKEND="http://localhost:8000"
GREEN='\033[0;32m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
PASS=0; FAIL=0

chk() {
    local name="$1" expected="$2" actual="$3"
    if echo "$actual" | grep -q "$expected"; then
        echo -e "  ${GREEN}PASS${NC} $name"
        ((PASS++))
    else
        echo -e "  ${RED}FAIL${NC} $name"
        echo "       expected : $expected"
        echo "       got      : ${actual:0:150}"
        ((FAIL++))
    fi
}

echo ""
echo -e "${BOLD}=== STAGE 6 TEST SUITE ===${NC}"
echo ""

# ── T1: Backend still healthy ──────────────────────────────────────────────────
echo "T1 — backend health"
R=$(curl -s "$BACKEND/health")
chk "backend healthy"  '"ok"' "$R"

# ── T2: Frontend dev server running ───────────────────────────────────────────
echo "T2 — frontend dev server"
R=$(curl -s --max-time 5 "$FRONTEND" 2>/dev/null || echo "")
if echo "$R" | grep -q "html\|OSINT\|vite\|react"; then
    echo -e "  ${GREEN}PASS${NC} frontend responding at $FRONTEND"
    ((PASS++))
else
    echo -e "  ${RED}FAIL${NC} frontend not responding — run: cd frontend && npm run dev"
    ((FAIL++))
fi

# ── T3: TypeScript compiles ────────────────────────────────────────────────────
echo "T3 — TypeScript compilation"
cd frontend 2>/dev/null || { echo -e "  ${RED}FAIL${NC} frontend/ dir not found"; ((FAIL++)); }
TS_OUT=$(npx tsc --noEmit 2>&1 | grep -v "^$" | head -20)
TS_ERRORS=$(echo "$TS_OUT" | grep -c "error TS" || true)
if [ "${TS_ERRORS:-0}" -eq 0 ]; then
    echo -e "  ${GREEN}PASS${NC} TypeScript: 0 errors"
    ((PASS++))
else
    echo -e "  ${RED}FAIL${NC} TypeScript: $TS_ERRORS error(s)"
    echo "$TS_OUT" | head -10
    ((FAIL++))
fi
cd ..

# ── T4: All services are valid TypeScript ──────────────────────────────────────
echo "T4 — service files are valid TypeScript (no shell script content)"
for f in \
  frontend/src/app/services/threats.ts \
  frontend/src/app/services/analytics.ts \
  frontend/src/app/services/copilot.ts \
  frontend/src/app/services/reports.ts; do
  if grep -q "^#\|cat >\|<< 'EOF'" "$f" 2>/dev/null; then
    echo -e "  ${RED}FAIL${NC} $f contains shell script content"
    ((FAIL++))
  else
    echo -e "  ${GREEN}PASS${NC} $f is clean TypeScript"
    ((PASS++))
  fi
done

# ── T5: All page components exist and are non-empty ───────────────────────────
echo "T5 — all page components exist"
for page in Dashboard Threats Analytics Copilot Reports Settings Alerts Entities NotFound; do
  f="frontend/src/app/pages/$page/index.tsx"
  if [ -s "$f" ]; then
    echo -e "  ${GREEN}PASS${NC} pages/$page/index.tsx ($(wc -l < $f) lines)"
    ((PASS++))
  else
    echo -e "  ${RED}FAIL${NC} pages/$page/index.tsx missing or empty"
    ((FAIL++))
  fi
done

# ── T6: hooks/index.ts exports all required hooks ─────────────────────────────
echo "T6 — hooks/index.ts exports"
HOOKS_FILE="frontend/src/app/hooks/index.ts"
for hook in useThreats useAnalyticsSummary useCopilotChat useIngestionStatus useWebSocket useReports; do
  if grep -q "$hook" "$HOOKS_FILE" 2>/dev/null; then
    echo -e "  ${GREEN}PASS${NC} $hook exported"
    ((PASS++))
  else
    echo -e "  ${RED}FAIL${NC} $hook not found in hooks/index.ts"
    ((FAIL++))
  fi
done

# ── T7: .env has correct variable ─────────────────────────────────────────────
echo "T7 — frontend .env"
if grep -q "VITE_API_BASE_URL" frontend/.env 2>/dev/null; then
    echo -e "  ${GREEN}PASS${NC} VITE_API_BASE_URL present in .env"
    ((PASS++))
else
    echo -e "  ${RED}FAIL${NC} VITE_API_BASE_URL missing from .env"
    ((FAIL++))
fi

# ── T8: API proxy — frontend can reach backend ────────────────────────────────
echo "T8 — API proxy (frontend -> backend)"
R=$(curl -s --max-time 5 "$FRONTEND/api/v1/threats/ingest/status" 2>/dev/null || echo "")
if echo "$R" | grep -q "total_threats"; then
    echo -e "  ${GREEN}PASS${NC} frontend proxy routes /api to backend"
    ((PASS++))
else
    echo -e "  ${RED}FAIL${NC} proxy not working (start both servers first)"
    ((FAIL++))
fi

# ── T9: Backend API endpoints used by frontend all respond ────────────────────
echo "T9 — backend endpoints used by frontend"
declare -A ENDPOINTS=(
  ["analytics/dashboard"]="total_threats"
  ["analytics/top-threats"]="risk_score"
  ["threats/ingest/status"]="total_threats"
  ["copilot/status"]="ollama_available"
  ["reports/quick"]="total_threats"
)
for path in "${!ENDPOINTS[@]}"; do
  R=$(curl -s "$BACKEND/api/v1/$path")
  chk "$path" "${ENDPOINTS[$path]}" "$R"
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Results: ${GREEN}$PASS passed${NC} / ${RED}$FAIL failed${NC}"
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✓ Stage 6 complete — Full stack working end-to-end${NC}"
    echo ""
    echo "  Frontend:  http://localhost:5174"
    echo "  Backend:   http://localhost:8000"
    echo "  API Docs:  http://localhost:8000/docs"
else
    echo -e "${RED}✗ $FAIL test(s) failed${NC}"
    echo ""
    echo "  Make sure both servers are running:"
    echo "    Terminal 1: cd backend  && python -m uvicorn src.main:app --reload --host 0.0.0.0 --port 8000"
    echo "    Terminal 2: cd frontend && npm run dev"
fi
echo ""
