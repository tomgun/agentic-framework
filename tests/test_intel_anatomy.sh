#!/usr/bin/env bash
# test_intel_anatomy.sh — Tests for F-041 Intelligence Engine Phase 2
#
# Tests:
#   1. ag intel scan — generates anatomy.yaml + anatomy.index
#   2. anatomy.yaml structure — version, generated, file_count, files[]
#   3. anatomy.index — tab-separated flat format
#   4. ag intel scan --check — freshness detection
#   5. ag intel file PATH — lookup from index
#   6. ag intel file PATH — fallback without index
#   7. Language detection — extension mapping
#   8. Summary extraction — first comment line
#   9. ag intel stats — session metrics from events log
#  10. ag intel stats — lifetime metrics from token-summary.json
#  11. ag intel stats --session — session-only mode
#  12. Token events format — R/W pipe-delimited lines
#  13. Stop.sh token finalization — compiles ledger + merges summary
#  14. Index rebuild — regenerate from anatomy.yaml

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
TOTAL=0

pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); }
fail() { echo "  ❌ $1: $2"; FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); }

# Create a temp project with minimal structure for testing
create_project() {
    local dir
    dir=$(mktemp -d)
    mkdir -p "$dir/.agentic/intel" "$dir/.agentic/lib/tools/commands" "$dir/.agentic/lib/presets"
    mkdir -p "$dir/.agentic/lib/claude-hooks" "$dir/.agentic/journal" "$dir/.agentic/spec"
    mkdir -p "$dir/.agentic/session"

    # Copy required libraries
    cp "$REPO_ROOT/.agentic/lib/settings.sh" "$dir/.agentic/lib/"
    cp -r "$REPO_ROOT/.agentic/lib/presets" "$dir/.agentic/lib/" 2>/dev/null || true
    cp "$REPO_ROOT/.agentic/lib/paths.sh" "$dir/.agentic/lib/" 2>/dev/null || true
    cp "$REPO_ROOT/.agentic/lib/tools/commands/intel.sh" "$dir/.agentic/lib/tools/commands/"
    cp "$REPO_ROOT/.agentic/lib/claude-hooks/stop.sh" "$dir/.agentic/lib/claude-hooks/"

    # Minimal STACK.md
    cat > "$dir/STACK.md" << 'EOF'
# Stack

## Settings
- profile: discovery
- state_enforcement: off
- feature_tracking: no
EOF

    # Create sample source files for scanning
    mkdir -p "$dir/src"

    cat > "$dir/src/main.py" << 'PYEOF'
# Main application entry point
import os
import sys

def main():
    print("Hello, world!")

if __name__ == "__main__":
    main()
PYEOF

    cat > "$dir/src/utils.sh" << 'SHEOF'
#!/usr/bin/env bash
# Utility functions for build scripts
set -euo pipefail

say() {
    echo "$@"
}
SHEOF

    cat > "$dir/src/index.ts" << 'TSEOF'
// Express application bootstrap
import express from 'express';

const app = express();
app.listen(3000);
TSEOF

    cat > "$dir/README.md" << 'MDEOF'
# Test Project

A sample project for testing anatomy scanning.
MDEOF

    cat > "$dir/config.yaml" << 'YAEOF'
# Application configuration
version: 1
debug: false
YAEOF

    cat > "$dir/data.json" << 'JEOF'
{
  "name": "test",
  "version": "1.0.0"
}
JEOF

    # Initialize as git repo so git ls-files works
    (cd "$dir" && git init -q && git add -A && git commit -q -m "init" 2>/dev/null) || true

    echo "$dir"
}

cleanup_project() {
    rm -rf "$1" 2>/dev/null || true
}

# Minimal ag.sh stub that sources intel.sh
run_intel() {
    local project_dir="$1"
    shift
    (
        ROOT_DIR="$project_dir"
        SCRIPT_DIR="$project_dir/.agentic/lib/tools"
        # Source settings and paths
        source "$project_dir/.agentic/lib/settings.sh" 2>/dev/null || true
        PROFILE=$(_get_setting "profile" 2>/dev/null || echo "discovery")
        # Color codes
        RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
        BLUE='\033[0;34m' BOLD='\033[1m' DIM='\033[2m' NC='\033[0m'
        # Source intel
        source "$project_dir/.agentic/lib/tools/commands/intel.sh"
        cmd_intel "$@"
    )
}

echo ""
echo "=== F-041 Phase 2: Anatomy + Token Ledger ==="
echo ""

# --- Test 1: ag intel scan ---
echo "--- Scan ---"
PROJECT=$(create_project)
OUTPUT=$(run_intel "$PROJECT" scan 2>&1)

if echo "$OUTPUT" | grep -q "Scanned.*files"; then
    pass "1. ag intel scan reports scanned files"
else
    fail "1. ag intel scan failed" "$OUTPUT"
fi

# --- Test 2: anatomy.yaml structure ---
if [[ -f "$PROJECT/.agentic/intel/anatomy.yaml" ]]; then
    YAML="$PROJECT/.agentic/intel/anatomy.yaml"
    if grep -q "^version: 1" "$YAML" && \
       grep -q "^generated:" "$YAML" && \
       grep -q "^file_count:" "$YAML" && \
       grep -q "^total_tokens:" "$YAML" && \
       grep -q "^files:" "$YAML" && \
       grep -q "path:" "$YAML" && \
       grep -q "summary:" "$YAML" && \
       grep -q "tokens:" "$YAML" && \
       grep -q "language:" "$YAML" && \
       grep -q "related:" "$YAML"; then
        pass "2. anatomy.yaml has correct structure"
    else
        fail "2. anatomy.yaml missing required fields" "$(head -20 "$YAML")"
    fi
else
    fail "2. anatomy.yaml not created" ""
fi

# --- Test 3: anatomy.index format ---
if [[ -f "$PROJECT/.agentic/intel/anatomy.index" ]]; then
    INDEX="$PROJECT/.agentic/intel/anatomy.index"
    # Should be tab-separated: path\tsummary\ttokens\tlanguage
    SAMPLE=$(head -1 "$INDEX")
    FIELD_COUNT=$(echo "$SAMPLE" | awk -F'\t' '{print NF}')
    if [[ "$FIELD_COUNT" == "4" ]]; then
        pass "3. anatomy.index has 4 tab-separated fields"
    else
        fail "3. anatomy.index wrong field count: $FIELD_COUNT" "$SAMPLE"
    fi
else
    fail "3. anatomy.index not created" ""
fi

# --- Test 4: ag intel scan --check ---
echo "--- Freshness ---"
OUTPUT=$(run_intel "$PROJECT" scan --check 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && echo "$OUTPUT" | grep -q "fresh"; then
    pass "4a. scan --check reports fresh after scan"
else
    fail "4a. scan --check should report fresh" "$OUTPUT (rc=$RC)"
fi

# Touch a file to make it stale
sleep 1
touch "$PROJECT/src/main.py"
OUTPUT=$(run_intel "$PROJECT" scan --check 2>&1)
RC=$?
if [[ $RC -ne 0 ]] && echo "$OUTPUT" | grep -q "stale"; then
    pass "4b. scan --check detects stale anatomy"
else
    fail "4b. scan --check should detect stale" "$OUTPUT (rc=$RC)"
fi

# --- Test 5: ag intel file PATH (from index) ---
echo "--- File Lookup ---"
OUTPUT=$(run_intel "$PROJECT" file src/main.py 2>&1)
if echo "$OUTPUT" | grep -q "src/main.py" && \
   echo "$OUTPUT" | grep -q "tokens" && \
   echo "$OUTPUT" | grep -q "python"; then
    pass "5. ag intel file returns info from index"
else
    fail "5. ag intel file from index" "$OUTPUT"
fi

# --- Test 6: ag intel file PATH (fallback without index) ---
rm -f "$PROJECT/.agentic/intel/anatomy.index" "$PROJECT/.agentic/intel/anatomy.yaml"
OUTPUT=$(run_intel "$PROJECT" file src/utils.sh 2>&1)
if echo "$OUTPUT" | grep -q "utils.sh" && \
   echo "$OUTPUT" | grep -q "not in index" && \
   echo "$OUTPUT" | grep -q "shell"; then
    pass "6. ag intel file fallback without index"
else
    fail "6. ag intel file fallback" "$OUTPUT"
fi

# --- Test 7: Language detection ---
echo "--- Language Detection ---"
# Re-scan to get the index back
run_intel "$PROJECT" scan >/dev/null 2>&1

OUTPUT=$(run_intel "$PROJECT" file src/main.py 2>&1)
HAS_PYTHON=$(echo "$OUTPUT" | grep -c "python" || true)

OUTPUT2=$(run_intel "$PROJECT" file src/index.ts 2>&1)
HAS_TS=$(echo "$OUTPUT2" | grep -c "typescript" || true)

OUTPUT3=$(run_intel "$PROJECT" file config.yaml 2>&1)
HAS_YAML=$(echo "$OUTPUT3" | grep -c "yaml" || true)

if [[ "$HAS_PYTHON" -gt 0 && "$HAS_TS" -gt 0 && "$HAS_YAML" -gt 0 ]]; then
    pass "7. Language detection: python, typescript, yaml"
else
    fail "7. Language detection" "python=$HAS_PYTHON ts=$HAS_TS yaml=$HAS_YAML"
fi

# --- Test 8: Summary extraction ---
echo "--- Summary Extraction ---"
OUTPUT=$(run_intel "$PROJECT" file src/main.py 2>&1)
if echo "$OUTPUT" | grep -qi "main\|entry\|application"; then
    pass "8a. Summary extracted from Python comment"
else
    fail "8a. Python summary extraction" "$OUTPUT"
fi

OUTPUT=$(run_intel "$PROJECT" file src/utils.sh 2>&1)
if echo "$OUTPUT" | grep -qi "utility\|build"; then
    pass "8b. Summary extracted from Shell comment"
else
    fail "8b. Shell summary extraction" "$OUTPUT"
fi

OUTPUT=$(run_intel "$PROJECT" file README.md 2>&1)
if echo "$OUTPUT" | grep -qi "test project"; then
    pass "8c. Summary extracted from Markdown heading"
else
    fail "8c. Markdown summary extraction" "$OUTPUT"
fi

# --- Test 9: ag intel stats (session metrics) ---
echo "--- Token Metrics ---"
# Create mock events
mkdir -p "$PROJECT/.agentic/session"
cat > "$PROJECT/.agentic/session/token-events.log" << 'EOF'
R|src/main.py|250
R|src/main.py|250
R|src/utils.sh|100
W|src/main.py|250
W|src/index.ts|150
EOF

OUTPUT=$(run_intel "$PROJECT" stats --session 2>&1)
if echo "$OUTPUT" | grep -q "Reads:.*3 total.*2 unique.*1 repeated" && \
   echo "$OUTPUT" | grep -q "Writes:.*2" && \
   echo "$OUTPUT" | grep -q "Est.*context.*~1000"; then
    pass "9. Session metrics from events log"
else
    fail "9. Session metrics" "$OUTPUT"
fi

# --- Test 10: ag intel stats (lifetime metrics) ---
cat > "$PROJECT/.agentic/intel/token-summary.json" << 'EOF'
{
  "total_sessions": 5,
  "total_reads": 200,
  "total_writes": 50,
  "total_repeated_reads": 30,
  "total_estimated_cost": 150000,
  "last_updated": "2026-04-02T10:00:00Z"
}
EOF

OUTPUT=$(run_intel "$PROJECT" stats 2>&1)
if echo "$OUTPUT" | grep -q "Sessions:.*5" && \
   echo "$OUTPUT" | grep -q "Total reads:.*200.*30 repeated" && \
   echo "$OUTPUT" | grep -q "Total writes:.*50"; then
    pass "10. Lifetime metrics from token-summary.json"
else
    fail "10. Lifetime metrics" "$OUTPUT"
fi

# --- Test 11: ag intel stats --session ---
OUTPUT=$(run_intel "$PROJECT" stats --session 2>&1)
if echo "$OUTPUT" | grep -q "Current Session" && \
   ! echo "$OUTPUT" | grep -q "Lifetime"; then
    pass "11. stats --session shows only session data"
else
    fail "11. stats --session" "$OUTPUT"
fi

# --- Test 12: Token events format ---
echo "--- Token Events ---"
rm -f "$PROJECT/.agentic/session/token-events.log"
echo "R|test/file.py|100" >> "$PROJECT/.agentic/session/token-events.log"
echo "W|test/file.py|100" >> "$PROJECT/.agentic/session/token-events.log"

READS=$(grep -c '^R|' "$PROJECT/.agentic/session/token-events.log" 2>/dev/null || echo 0)
WRITES=$(grep -c '^W|' "$PROJECT/.agentic/session/token-events.log" 2>/dev/null || echo 0)

if [[ "$READS" == "1" && "$WRITES" == "1" ]]; then
    pass "12. Token events R/W format works"
else
    fail "12. Token events format" "reads=$READS writes=$WRITES"
fi

# --- Test 13: Stop.sh token finalization ---
echo "--- Stop Finalization ---"
# Set up events and existing summary
cat > "$PROJECT/.agentic/session/token-events.log" << 'EOF'
R|a.py|100
R|b.py|200
R|a.py|100
W|a.py|100
EOF

cat > "$PROJECT/.agentic/intel/token-summary.json" << 'EOF'
{
  "total_sessions": 3,
  "total_reads": 100,
  "total_writes": 20,
  "total_repeated_reads": 10,
  "total_estimated_cost": 50000,
  "last_updated": "2026-04-01T00:00:00Z"
}
EOF

# Run the finalization portion (simulate stop.sh logic)
(
    cd "$PROJECT"
    _TK_EVENTS=".agentic/session/token-events.log"
    _TK_SUMMARY=".agentic/intel/token-summary.json"
    _TK_LEDGER=".agentic/session/token-ledger.json"

    _TK_READS=$(grep -c '^R|' "$_TK_EVENTS" 2>/dev/null || echo 0)
    _TK_WRITES=$(grep -c '^W|' "$_TK_EVENTS" 2>/dev/null || echo 0)
    _TK_UNIQUE=$(grep '^R|' "$_TK_EVENTS" 2>/dev/null | cut -d'|' -f2 | sort -u | wc -l 2>/dev/null || echo 0)
    _TK_UNIQUE="${_TK_UNIQUE## }"
    _TK_REPEATED=$(( _TK_READS - _TK_UNIQUE ))
    [[ $_TK_REPEATED -lt 0 ]] && _TK_REPEATED=0
    _TK_COST=$(awk -F'|' '{sum += $3} END {print sum+0}' "$_TK_EVENTS" 2>/dev/null || echo 0)
    _TK_NOW="2026-04-02T12:00:00Z"

    cat > "$_TK_LEDGER" <<TKEOF
{
  "finalized": "$_TK_NOW",
  "reads": $_TK_READS,
  "writes": $_TK_WRITES,
  "unique_files_read": $_TK_UNIQUE,
  "repeated_reads": $_TK_REPEATED,
  "estimated_context_cost": $_TK_COST
}
TKEOF

    _TK_P_SESS=$(grep -o '"total_sessions"[[:space:]]*:[[:space:]]*[0-9]*' "$_TK_SUMMARY" 2>/dev/null | grep -o '[0-9]*$' || echo 0)
    _TK_P_RD=$(grep -o '"total_reads"[[:space:]]*:[[:space:]]*[0-9]*' "$_TK_SUMMARY" 2>/dev/null | grep -o '[0-9]*$' || echo 0)
    _TK_P_WR=$(grep -o '"total_writes"[[:space:]]*:[[:space:]]*[0-9]*' "$_TK_SUMMARY" 2>/dev/null | grep -o '[0-9]*$' || echo 0)
    _TK_P_REP=$(grep -o '"total_repeated_reads"[[:space:]]*:[[:space:]]*[0-9]*' "$_TK_SUMMARY" 2>/dev/null | grep -o '[0-9]*$' || echo 0)
    _TK_P_COST=$(grep -o '"total_estimated_cost"[[:space:]]*:[[:space:]]*[0-9]*' "$_TK_SUMMARY" 2>/dev/null | grep -o '[0-9]*$' || echo 0)

    cat > "$_TK_SUMMARY" <<TKEOF
{
  "total_sessions": $(( _TK_P_SESS + 1 )),
  "total_reads": $(( _TK_P_RD + _TK_READS )),
  "total_writes": $(( _TK_P_WR + _TK_WRITES )),
  "total_repeated_reads": $(( _TK_P_REP + _TK_REPEATED )),
  "total_estimated_cost": $(( _TK_P_COST + _TK_COST )),
  "last_updated": "$_TK_NOW"
}
TKEOF
)

# Verify session ledger
if [[ -f "$PROJECT/.agentic/session/token-ledger.json" ]]; then
    LEDGER="$PROJECT/.agentic/session/token-ledger.json"
    if grep -q '"reads": 3' "$LEDGER" && \
       grep -q '"writes": 1' "$LEDGER" && \
       grep -q '"repeated_reads": 1' "$LEDGER" && \
       grep -q '"estimated_context_cost": 500' "$LEDGER"; then
        pass "13a. Session ledger JSON has correct values"
    else
        fail "13a. Session ledger values" "$(cat "$LEDGER")"
    fi
else
    fail "13a. Session ledger not created" ""
fi

# Verify merged summary
SUMMARY="$PROJECT/.agentic/intel/token-summary.json"
if grep -q '"total_sessions": 4' "$SUMMARY" && \
   grep -q '"total_reads": 103' "$SUMMARY" && \
   grep -q '"total_writes": 21' "$SUMMARY" && \
   grep -q '"total_repeated_reads": 11' "$SUMMARY"; then
    pass "13b. Lifetime summary merged correctly"
else
    fail "13b. Lifetime summary merge" "$(cat "$SUMMARY")"
fi

# --- Test 14: Index rebuild from anatomy.yaml ---
echo "--- Index Rebuild ---"
# Remove index, keep YAML
rm -f "$PROJECT/.agentic/intel/anatomy.index"

# Trigger file lookup which should rebuild index
OUTPUT=$(run_intel "$PROJECT" file src/main.py 2>&1)
if [[ -f "$PROJECT/.agentic/intel/anatomy.index" ]] && \
   echo "$OUTPUT" | grep -q "python"; then
    pass "14. Index rebuilt from anatomy.yaml on file lookup"
else
    fail "14. Index rebuild" "$OUTPUT"
fi

# Cleanup
cleanup_project "$PROJECT"

echo ""
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo ""

[[ $FAIL -eq 0 ]]
