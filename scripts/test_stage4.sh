#!/usr/bin/env bash
# =============================================================================
# STAGE 4 TEST SUITE
# Run from: backend/
# Usage:    bash ../scripts/test_stage4.sh
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
        echo "       expected : $expected"
        echo "       got      : ${actual:0:200}"
        ((FAIL++))
    fi
}

echo ""
echo -e "${BOLD}=== STAGE 4 TEST SUITE ===${NC}"
echo ""

# ── T1: processed/stats before processing ─────────────────────────────────────
echo "T1 — processed/stats endpoint"
R=$(curl -s "$BASE/processed/stats")
chk "has total_documents"  "total_documents" "$R"
chk "has pending count"    "pending"         "$R"
chk "has pct_complete"     "pct_complete"    "$R"

PENDING_BEFORE=$(echo "$R" | python3 -c \
    "import sys,json; print(json.load(sys.stdin)['pending'])" 2>/dev/null || echo 0)
echo "     pending before processing: $PENDING_BEFORE"

# ── T2: trigger NLP processing ────────────────────────────────────────────────
echo "T2 — POST /process (run NLP pipeline)"
R=$(curl -s -X POST "$BASE/process")
chk "returns status ok"     '"status"'    "$R"
chk "returns results dict"  '"results"'   "$R"
chk "has processed count"   '"processed"' "$R"
echo "     response: $R"

# ── T3: processed/stats after processing ──────────────────────────────────────
echo "T3 — processed/stats after pipeline run"
R=$(curl -s "$BASE/processed/stats")
PROCESSED=$(echo "$R" | python3 -c \
    "import sys,json; print(json.load(sys.stdin)['processed'])" 2>/dev/null || echo 0)
PENDING_AFTER=$(echo "$R" | python3 -c \
    "import sys,json; print(json.load(sys.stdin)['pending'])" 2>/dev/null || echo 0)
PCT=$(echo "$R" | python3 -c \
    "import sys,json; print(json.load(sys.stdin)['pct_complete'])" 2>/dev/null || echo 0)

echo "     processed: $PROCESSED  pending: $PENDING_AFTER  pct: $PCT%"

if [ "${PROCESSED:-0}" -gt 0 ]; then
    echo -e "  ${GREEN}PASS${NC} $PROCESSED documents processed"
    ((PASS++))
else
    echo -e "  ${RED}FAIL${NC} No documents were processed"
    ((FAIL++))
fi

# ── T4: threats now have enriched data ────────────────────────────────────────
echo "T4 — threats have enriched fields after processing"
R=$(curl -s "$BASE/?limit=10")

# Check that at least one threat has non-empty iocs
HAS_IOCS=$(echo "$R" | python3 -c "
import sys, json
threats = json.load(sys.stdin)
enriched = [t for t in threats if t.get('iocs') and t['iocs'] != '[]']
print(len(enriched))
" 2>/dev/null || echo 0)

if [ "${HAS_IOCS:-0}" -gt 0 ]; then
    echo -e "  ${GREEN}PASS${NC} $HAS_IOCS threats have extracted IOCs"
    ((PASS++))
else
    echo -e "  ${RED}FAIL${NC} No threats have IOC data (may be normal if docs had no indicators)"
    ((FAIL++))
fi

# Check risk scores are set
HAS_RISK=$(echo "$R" | python3 -c "
import sys, json
threats = json.load(sys.stdin)
with_risk = [t for t in threats if t.get('risk_score') and t['risk_score'] > 0]
print(len(with_risk))
" 2>/dev/null || echo 0)

if [ "${HAS_RISK:-0}" -gt 0 ]; then
    echo -e "  ${GREEN}PASS${NC} $HAS_RISK threats have risk_score > 0"
    ((PASS++))
else
    echo -e "  ${RED}FAIL${NC} No threats have risk scores"
    ((FAIL++))
fi

# ── T5: stats show severity distribution ──────────────────────────────────────
echo "T5 — severity distribution in stats"
R=$(curl -s "$BASE/stats/summary")
chk "stats has total"       '"total"'       "$R"
chk "stats has by_severity" '"by_severity"' "$R"
chk "stats has by_category" '"by_category"' "$R"

# ── T6: unit tests — classifier ───────────────────────────────────────────────
echo "T6 — classifier unit tests"
python3 - << 'PYEOF'
import sys
sys.path.insert(0, ".")

from src.intelligence.classification.classifier import classify, classify_category, classify_severity

tests = [
    ("CVE text -> vulnerability",  "vulnerability_exploit", classify_category("Critical CVE-2024-1234 RCE exploit")),
    ("Ransomware -> malware",       "malware_ransomware",    classify_category("New ransomware variant encrypting files")),
    ("Phishing -> phishing",        "phishing_fraud",        classify_category("Spear-phishing campaign targeting banks")),
    ("Critical severity",           "critical",              classify_severity("Critical 0-day actively exploited")),
    ("CVSS 9.8 -> critical",        "critical",              classify_severity("CVSS 9.8 vulnerability", cvss_score=9.8)),
    ("CVSS 5.0 -> medium",          "medium",                classify_severity("moderate issue", cvss_score=5.0)),
]

passed = failed = 0
for name, expected, got in tests:
    if got == expected:
        print(f"  PASS {name} -> {got}")
        passed += 1
    else:
        print(f"  FAIL {name} -> expected={expected} got={got}")
        failed += 1

print(f"\n  {passed} passed, {failed} failed")
sys.exit(0 if failed == 0 else 1)
PYEOF
[ $? -eq 0 ] && ((PASS++)) || ((FAIL++))

# ── T7: IOC extractor unit tests ──────────────────────────────────────────────
echo "T7 — IOC extractor unit tests"
python3 - << 'PYEOF'
import sys
sys.path.insert(0, ".")
from src.intelligence.indicators.ioc_extractor import extract_iocs

text = "Attacker C2 at 45.33.32.156 used CVE-2024-5678. Hash: d41d8cd98f00b204e9800998ecf8427e"
iocs = extract_iocs(text)
types = {i["type"] for i in iocs}

passed = failed = 0
for expected_type in ["ipv4", "cve", "md5"]:
    if expected_type in types:
        print(f"  PASS extracted {expected_type}")
        passed += 1
    else:
        print(f"  FAIL missing {expected_type}")
        failed += 1

# Private IPs should be excluded
private_text = "Internal IP 192.168.1.1 and public 8.8.8.8"
private_iocs = extract_iocs(private_text)
public_ips = [i for i in private_iocs if i["type"] == "ipv4"]
if all(i["value"] != "192.168.1.1" for i in public_ips):
    print(f"  PASS private IP filtered out correctly")
    passed += 1
else:
    print(f"  FAIL private IP not filtered")
    failed += 1

print(f"\n  {passed} passed, {failed} failed")
sys.exit(0 if failed == 0 else 1)
PYEOF
[ $? -eq 0 ] && ((PASS++)) || ((FAIL++))

# ── T8: SQLite — check processed flag ─────────────────────────────────────────
echo "T8 — SQLite processed flag check"
python3 - << 'PYEOF'
import sqlite3, sys
try:
    conn = sqlite3.connect("osint.db")
    cur  = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM threat_documents WHERE is_processed = 1")
    processed = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM threat_documents")
    total = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM threats WHERE risk_score > 0")
    with_risk = cur.fetchone()[0]
    conn.close()
    print(f"  threat_documents processed: {processed}/{total}")
    print(f"  threats with risk_score > 0: {with_risk}")
    if processed > 0 and with_risk > 0:
        print("  PASS DB shows NLP enrichment")
    else:
        print("  FAIL DB not enriched")
        sys.exit(1)
except Exception as e:
    print(f"  FAIL: {e}"); sys.exit(1)
PYEOF
[ $? -eq 0 ] && ((PASS++)) || ((FAIL++))

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Results: ${GREEN}$PASS passed${NC} / ${RED}$FAIL failed${NC}"
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✓ Stage 4 complete — ready for Stage 5 (AI Agents + RAG)${NC}"
    echo ""
    echo "  Stage 5 will wire up:"
    echo "  Supervisor agent → Classification agent → Risk agent → Reporting agent"
    echo "  RAG pipeline → ChromaDB vector store → Ollama LLM → Copilot API"
else
    echo -e "${RED}✗ $FAIL test(s) failed — fix before Stage 5${NC}"
fi
echo ""
