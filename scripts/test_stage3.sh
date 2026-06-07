#!/usr/bin/env bash
# =============================================================================
# STAGE 3 TEST SUITE
# Run from: backend/
# Usage:    bash ../scripts/test_stage3.sh
# =============================================================================
BASE="http://localhost:8000/api/v1/threats"
GREEN='\033[0;32m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
PASS=0; FAIL=0

chk() {
    local name="$1" expected="$2" actual="$3"
    if echo "$actual" | grep -q "$expected"; then
        echo -e "  ${GREEN}PASS${NC} $name"
        ((PASS++))
    else
        echo -e "  ${RED}FAIL${NC} $name"
        echo "       expected to contain : $expected"
        echo "       got                 : ${actual:0:150}"
        ((FAIL++))
    fi
}

echo ""
echo -e "${BOLD}=== STAGE 3 TEST SUITE ===${NC}"
echo ""

# ── T1: ingest/status responds ────────────────────────────────────────────────
echo "T1 — ingest/status endpoint"
R=$(curl -s "$BASE/ingest/status")
chk "responds with total_threats"  "total_threats" "$R"
chk "has severity breakdown"       "critical"      "$R"

# ── T2: CISA ingest ───────────────────────────────────────────────────────────
echo "T2 — CISA ingestion"
R=$(curl -s -X POST "$BASE/ingest/cisa")
chk "returns status field"         '"status"'   "$R"
chk "returns ingested count"       '"ingested"' "$R"

# ── T3: DB has rows after CISA ────────────────────────────────────────────────
echo "T3 — DB has data after CISA"
TOTAL=$(curl -s "$BASE/ingest/status" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['total_threats'])" 2>/dev/null \
    || echo 0)
if [ "${TOTAL:-0}" -gt 0 ]; then
    echo -e "  ${GREEN}PASS${NC} DB has $TOTAL threats after CISA ingest"
    ((PASS++))
else
    echo -e "  ${RED}FAIL${NC} DB still empty after CISA ingest (total=$TOTAL)"
    ((FAIL++))
fi

# ── T4: RSS ingest ────────────────────────────────────────────────────────────
echo "T4 — RSS ingestion"
R=$(curl -s -X POST "$BASE/ingest/rss")
chk "returns status field"         '"status"'   "$R"
chk "returns ingested count"       '"ingested"' "$R"

# ── T5: threats list ─────────────────────────────────────────────────────────
echo "T5 — GET /threats returns records"
R=$(curl -s "$BASE/?limit=5")
chk "response is a JSON array"     '\['         "$R"

# ── T6: stats summary ────────────────────────────────────────────────────────
echo "T6 — stats/summary"
R=$(curl -s "$BASE/stats/summary")
chk "has total count"              '"total"'       "$R"
chk "has by_severity breakdown"    '"by_severity"' "$R"
chk "has by_source breakdown"      '"by_source"'   "$R"

# ── T7: get single threat by ID ───────────────────────────────────────────────
echo "T7 — GET /threats/{id} returns single record"
FIRST_ID=$(curl -s "$BASE/?limit=1" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'] if d else '')" \
    2>/dev/null || echo "")
if [ -n "$FIRST_ID" ]; then
    R=$(curl -s "$BASE/$FIRST_ID")
    chk "single threat has id"     '"id"'    "$R"
    chk "single threat has title"  '"title"' "$R"
else
    echo -e "  ${RED}FAIL${NC} T7 — no threats in DB to fetch by ID"
    ((FAIL++))
fi

# ── T8: SQLite row counts ─────────────────────────────────────────────────────
echo "T8 — SQLite DB row counts"
python3 - << 'PYEOF'
import sqlite3, sys
try:
    conn = sqlite3.connect("osint.db")
    cur  = conn.cursor()
    all_ok = True
    for table in ["threats", "threat_documents"]:
        cur.execute(f"SELECT COUNT(*) FROM {table}")
        n = cur.fetchone()[0]
        status = "\033[0;32mPASS\033[0m" if n > 0 else "\033[0;31mFAIL\033[0m"
        print(f"  {status} {table}: {n} rows")
        if n == 0:
            all_ok = False
    conn.close()
    sys.exit(0 if all_ok else 1)
except Exception as e:
    print(f"  \033[0;31mFAIL\033[0m DB check error: {e}")
    sys.exit(1)
PYEOF
[ $? -eq 0 ] && ((PASS++)) || ((FAIL++))

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Results: ${GREEN}$PASS passed${NC} / ${RED}$FAIL failed${NC}"
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✓ Stage 3 complete — ready to move to Stage 4${NC}"
    echo ""
    echo "  Stage 4 will process these ingested documents through:"
    echo "  NLP cleaning → NER entity extraction → IOC detection → risk scoring"
else
    echo -e "${RED}✗ $FAIL test(s) failed — fix before moving to Stage 4${NC}"
fi
echo ""
