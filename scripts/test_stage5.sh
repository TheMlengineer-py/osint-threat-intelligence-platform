#!/usr/bin/env bash
# =============================================================================
# STAGE 5 TEST SUITE
# Run from: backend/
# Usage:    bash ../scripts/test_stage5.sh
# =============================================================================
BASE="http://localhost:8000"
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
        echo "       got      : ${actual:0:200}"
        ((FAIL++))
    fi
}

echo ""
echo -e "${BOLD}=== STAGE 5 TEST SUITE ===${NC}"
echo ""

# ── T1: all routers mounted ────────────────────────────────────────────────────
echo "T1 — all routers registered in main.py"
R=$(curl -s "$BASE/openapi.json")
chk "threats routes present"   "/api/v1/threats"   "$R"
chk "copilot routes present"   "/api/v1/copilot"   "$R"
chk "reports routes present"   "/api/v1/reports"   "$R"
chk "analytics routes present" "/api/v1/analytics" "$R"

# ── T2: analytics dashboard ───────────────────────────────────────────────────
echo "T2 — analytics dashboard"
R=$(curl -s "$BASE/api/v1/analytics/dashboard")
chk "has total_threats"    "total_threats"   "$R"
chk "has avg_risk_score"   "avg_risk_score"  "$R"
chk "has by_category"      "by_category"     "$R"
chk "has by_source"        "by_source"       "$R"

TOTAL=$(echo "$R" | python3 -c \
    "import sys,json; print(json.load(sys.stdin)['total_threats'])" 2>/dev/null || echo 0)
echo "     total_threats in DB: $TOTAL"
[ "${TOTAL:-0}" -gt 0 ] && ((PASS++)) && echo -e "  ${GREEN}PASS${NC} DB has data" \
    || { ((FAIL++)); echo -e "  ${RED}FAIL${NC} DB empty — run ingest first"; }

# ── T3: analytics trends ──────────────────────────────────────────────────────
echo "T3 — analytics trends"
R=$(curl -s "$BASE/api/v1/analytics/trends?days=30")
chk "has days field"       "days"        "$R"
chk "has trend field"      "trend"       "$R"

# ── T4: analytics risk distribution ───────────────────────────────────────────
echo "T4 — risk distribution"
R=$(curl -s "$BASE/api/v1/analytics/risk-distribution")
chk "has buckets"          "buckets"     "$R"
chk "has avg"              "\"avg\""     "$R"

# ── T5: analytics top threats ─────────────────────────────────────────────────
echo "T5 — top threats"
R=$(curl -s "$BASE/api/v1/analytics/top-threats?limit=5")
chk "returns array"        "\["          "$R"
HAS_ITEMS=$(echo "$R" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo 0)
[ "${HAS_ITEMS:-0}" -gt 0 ] && ((PASS++)) && echo -e "  ${GREEN}PASS${NC} $HAS_ITEMS top threats returned" \
    || { ((FAIL++)); echo -e "  ${RED}FAIL${NC} No threats returned"; }

# ── T6: quick report ──────────────────────────────────────────────────────────
echo "T6 — quick report generation"
R=$(curl -s "$BASE/api/v1/reports/quick")
chk "has total_threats"    "total_threats"   "$R"
chk "has top_20_by_risk"   "top_20_by_risk"  "$R"
chk "has top_threats"      "top_threats"     "$R"

# ── T7: full report generation ────────────────────────────────────────────────
echo "T7 — full report POST"
R=$(curl -s -X POST "$BASE/api/v1/reports" \
    -H "Content-Type: application/json" \
    -d '{"title":"Test Intelligence Report","format":"json"}')
chk "report has id"             '"id"'              "$R"
chk "report has title"          '"title"'           "$R"
chk "report has content"        '"content"'         "$R"
chk "report has threat_count"   '"threat_count"'    "$R"

# ── T8: copilot status ────────────────────────────────────────────────────────
echo "T8 — copilot status"
R=$(curl -s "$BASE/api/v1/copilot/status")
chk "has ollama_available" "ollama_available" "$R"
chk "has status field"     '"status"'         "$R"
OLLAMA=$(echo "$R" | python3 -c \
    "import sys,json; print(json.load(sys.stdin)['ollama_available'])" 2>/dev/null || echo "False")
echo "     Ollama available: $OLLAMA"

# ── T9: copilot /ask ──────────────────────────────────────────────────────────
echo "T9 — copilot /ask endpoint"
R=$(curl -s -X POST "$BASE/api/v1/copilot/ask" \
    -H "Content-Type: application/json" \
    -d '{"query":"What are the top critical threats?","max_context_docs":3}')
chk "has answer field"          '"answer"'              "$R"
chk "has sources field"         '"sources"'             "$R"
chk "has follow_up_questions"   "follow_up_questions"   "$R"

ANSWER_LEN=$(echo "$R" | python3 -c \
    "import sys,json; print(len(json.load(sys.stdin).get('answer','')))" 2>/dev/null || echo 0)
[ "${ANSWER_LEN:-0}" -gt 10 ] \
    && echo -e "  ${GREEN}PASS${NC} Answer has content ($ANSWER_LEN chars)" && ((PASS++)) \
    || { echo -e "  ${RED}FAIL${NC} Answer is empty"; ((FAIL++)); }

# ── T10: root endpoint shows all routes ───────────────────────────────────────
echo "T10 — root endpoint lists all routes"
R=$(curl -s "$BASE/")
chk "lists threats route"   "threats"   "$R"
chk "lists copilot route"   "copilot"   "$R"
chk "lists reports route"   "reports"   "$R"
chk "lists analytics route" "analytics" "$R"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Results: ${GREEN}$PASS passed${NC} / ${RED}$FAIL failed${NC}"
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✓ Stage 5 complete — ready for Stage 6 (Frontend integration)${NC}"
    echo ""
    echo "  All backend APIs are live:"
    echo "    GET  $BASE/api/v1/analytics/dashboard"
    echo "    GET  $BASE/api/v1/analytics/top-threats"
    echo "    POST $BASE/api/v1/reports"
    echo "    POST $BASE/api/v1/copilot/ask"
    echo "    GET  $BASE/docs  ← full Swagger UI"
else
    echo -e "${RED}✗ $FAIL test(s) failed — fix before Stage 6${NC}"
fi
echo ""
