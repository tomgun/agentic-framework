#!/usr/bin/env bash
# test_intel_logging.sh — Tests for intelligence sourcing audit log (F-041)
#
# Verifies that the intel event log tracks when framework intelligence is
# sourced (queries, enforcements, mutations, scans) vs. when the agent
# is operating without consulting intelligence.
#
# Tests:
#   Section 1: Event logging format and content
#   Section 2: Stop.sh finalization (session → lifetime summary)
#   Section 3: ag intel stats shows intel metrics
#   Section 4: Dashboard integration
#   Section 5: Pattern enforcement logging via PreToolUse

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
TOTAL=0

pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); }
fail() { echo "  ❌ $1: $2"; FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); }

# Helper: run intel command in project context
run_intel() {
    local project="$1"; shift
    ROOT_DIR="$project" \
        _AGENTIC_SETTINGS_LOADED="" _AGENTIC_PATHS_LOADED="" \
        _SETTINGS_ROOT_DIR="$project" _SETTINGS_STACK_FILE="$project/STACK.md" \
        bash -c '
            source "'"$REPO_ROOT"'/.agentic/lib/paths.sh" 2>/dev/null || true
            source "'"$REPO_ROOT"'/.agentic/lib/settings.sh" 2>/dev/null || true
            RED="\033[0;31m" GREEN="\033[0;32m" YELLOW="\033[1;33m" BLUE="\033[0;34m" BOLD="\033[1m" DIM="\033[2m" NC="\033[0m"
            ROOT_DIR="'"$project"'"
            source "'"$project"'/.agentic/lib/tools/commands/intel.sh"
            '"$*"'
        ' 2>&1
}

create_project() {
    local dir
    dir=$(mktemp -d)
    mkdir -p "$dir/.agentic/intel" "$dir/.agentic/lib/tools/commands" "$dir/.agentic/lib/presets"
    mkdir -p "$dir/.agentic/lib/claude-hooks" "$dir/.agentic/session"
    mkdir -p "$dir/.agentic/spec/adr" "$dir/.agentic/spec/contracts"

    cp "$REPO_ROOT/.agentic/lib/settings.sh" "$dir/.agentic/lib/"
    cp -r "$REPO_ROOT/.agentic/lib/presets" "$dir/.agentic/lib/" 2>/dev/null || true
    cp "$REPO_ROOT/.agentic/lib/paths.sh" "$dir/.agentic/lib/" 2>/dev/null || true
    cp "$REPO_ROOT/.agentic/lib/tools/commands/intel.sh" "$dir/.agentic/lib/tools/commands/"
    cp "$REPO_ROOT/.agentic/lib/claude-hooks/PreToolUse.sh" "$dir/.agentic/lib/claude-hooks/"
    cp "$REPO_ROOT/.agentic/lib/claude-hooks/PostToolUse.sh" "$dir/.agentic/lib/claude-hooks/"
    cp "$REPO_ROOT/.agentic/lib/claude-hooks/Stop.sh" "$dir/.agentic/lib/claude-hooks/" 2>/dev/null || true
    cp "$REPO_ROOT/.agentic/lib/tools/fwlog.sh" "$dir/.agentic/lib/tools/" 2>/dev/null || true

    cat > "$dir/STACK.md" << 'EOF'
# Stack
## Settings
- profile: discovery
- state_enforcement: off
EOF

    cat > "$dir/.agentic/intel/patterns.yaml" << 'EOF'
version: 1
patterns:
  - id: P-0001
    text: "No any types in TypeScript"
    reason: "Type safety"
    scope: "*.ts"
    severity: error
    source: manual
  - id: P-0002
    text: "Use cross-platform sed"
    reason: "BSD/GNU differ"
    scope: "*.sh"
    severity: warning
    source: manual
EOF

    cat > "$dir/.agentic/intel/cerebrum.yaml" << 'EOF'
version: 1
description: Project-scoped intelligence
entries: []
EOF

    cat > "$dir/.agentic/intel/quality-checklist.yaml" << 'EOF'
version: 1
source: bootstrap
stack: "TypeScript"
dimensions:
  usability:
    planning:
      - "Check responsive design"
    implementation:
      - "Use semantic HTML"
    testing:
      - "Run accessibility checks"
  code_quality:
    implementation:
      - "No any types"
EOF

    cat > "$dir/.agentic/intel/test-strategy.yaml" << 'EOF'
version: 1
source: bootstrap
stack: "TypeScript"
levels:
  unit:
    focus: "Functions and hooks"
    framework: "vitest"
EOF

    (cd "$dir" && git init -q && git add -A && git commit -q -m "init" 2>/dev/null) || true
    echo "$dir"
}

cleanup() {
    [[ -n "${PROJECT_DIR:-}" ]] && rm -rf "$PROJECT_DIR"
}
trap cleanup EXIT

echo "═══════════════════════════════════════════"
echo " F-041 Intel Event Logging Tests"
echo "═══════════════════════════════════════════"
echo ""

PROJECT_DIR=$(create_project)

# ═══════════════════════════════════════════════════════════════════
# Section 1: Event Logging Format
# ═══════════════════════════════════════════════════════════════════
echo "Section 1: Event Logging Format"
echo "────────────────────────────────"

# Clear any previous events
rm -f "$PROJECT_DIR/.agentic/session/intel-events.log"

echo "Test 1: architecture query creates intel event"
run_intel "$PROJECT_DIR" "_intel_architecture" >/dev/null 2>&1
if [[ -f "$PROJECT_DIR/.agentic/session/intel-events.log" ]]; then
    LAST=$(tail -1 "$PROJECT_DIR/.agentic/session/intel-events.log")
    if echo "$LAST" | grep -q '|query|architecture|'; then
        pass "architecture query logged as query|architecture"
    else
        fail "wrong event format" "$LAST"
    fi
else
    fail "intel-events.log not created" ""
fi

echo "Test 2: spec query logs with feature ID"
run_intel "$PROJECT_DIR" '_intel_spec "F-042"' >/dev/null 2>&1
LAST=$(tail -1 "$PROJECT_DIR/.agentic/session/intel-events.log")
if echo "$LAST" | grep -q '|query|spec:F-042|'; then
    pass "spec query logged with feature ID"
else
    fail "spec query missing feature ID" "$LAST"
fi

echo "Test 3: implement query logs with items count"
run_intel "$PROJECT_DIR" "_intel_implement" >/dev/null 2>&1
LAST=$(tail -1 "$PROJECT_DIR/.agentic/session/intel-events.log")
if echo "$LAST" | grep -q '|query|implement|'; then
    # Extract items count (last field)
    ITEMS=$(echo "$LAST" | awk -F'|' '{print $4}')
    if [[ "$ITEMS" -gt 0 ]]; then
        pass "implement query logged with $ITEMS items"
    else
        fail "implement query logged 0 items" "$LAST"
    fi
else
    fail "implement query not logged" "$LAST"
fi

echo "Test 4: test query logs event"
run_intel "$PROJECT_DIR" "_intel_test" >/dev/null 2>&1
LAST=$(tail -1 "$PROJECT_DIR/.agentic/session/intel-events.log")
if echo "$LAST" | grep -q '|query|test|'; then
    pass "test query logged"
else
    fail "test query not logged" "$LAST"
fi

echo "Test 5: learn mutation logs event"
run_intel "$PROJECT_DIR" '_intel_learn "New pattern" --reason "test" --scope "*.py"' >/dev/null 2>&1
LAST=$(tail -1 "$PROJECT_DIR/.agentic/session/intel-events.log")
if echo "$LAST" | grep -q '|mutate|learn:P-'; then
    pass "learn logged as mutate|learn:P-XXXX"
else
    fail "learn not logged correctly" "$LAST"
fi

echo "Test 6: remember mutation logs event with type"
run_intel "$PROJECT_DIR" '_intel_remember "Prefer server components" --type preference' >/dev/null 2>&1
LAST=$(tail -1 "$PROJECT_DIR/.agentic/session/intel-events.log")
if echo "$LAST" | grep -q '|mutate|remember:C-.*:preference|'; then
    pass "remember logged with type"
else
    fail "remember not logged correctly" "$LAST"
fi

echo "Test 7: forget mutation logs event"
run_intel "$PROJECT_DIR" '_intel_forget "C-0001"' >/dev/null 2>&1
LAST=$(tail -1 "$PROJECT_DIR/.agentic/session/intel-events.log")
if echo "$LAST" | grep -q '|mutate|forget:C-0001|'; then
    pass "forget logged"
else
    fail "forget not logged" "$LAST"
fi

echo "Test 8: remove mutation logs event"
run_intel "$PROJECT_DIR" '_intel_remove "P-0003"' >/dev/null 2>&1
LAST=$(tail -1 "$PROJECT_DIR/.agentic/session/intel-events.log")
if echo "$LAST" | grep -q '|mutate|remove:P-0003|'; then
    pass "remove logged"
else
    fail "remove not logged" "$LAST"
fi

echo "Test 9: scan logs event with file count"
run_intel "$PROJECT_DIR" "_intel_scan" >/dev/null 2>&1
LAST=$(tail -1 "$PROJECT_DIR/.agentic/session/intel-events.log")
if echo "$LAST" | grep -q '|scan|anatomy|'; then
    ITEMS=$(echo "$LAST" | awk -F'|' '{print $4}')
    if [[ "$ITEMS" -gt 0 ]]; then
        pass "scan logged with $ITEMS files"
    else
        fail "scan logged 0 files" "$LAST"
    fi
else
    fail "scan not logged" "$LAST"
fi

echo "Test 10: bootstrap logs event"
run_intel "$PROJECT_DIR" "_intel_bootstrap" >/dev/null 2>&1
LAST=$(tail -1 "$PROJECT_DIR/.agentic/session/intel-events.log")
if echo "$LAST" | grep -q '|scan|bootstrap|'; then
    pass "bootstrap logged as scan|bootstrap"
else
    fail "bootstrap not logged" "$LAST"
fi

echo "Test 11: event format is TIMESTAMP|EVENT|DETAIL|ITEMS"
FIRST=$(head -1 "$PROJECT_DIR/.agentic/session/intel-events.log")
# Should match: ISO timestamp | event type | detail | number
if echo "$FIRST" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]+Z\|[a-z]+\|[a-z]'; then
    pass "event format matches TIMESTAMP|EVENT|DETAIL|ITEMS"
else
    fail "event format wrong" "$FIRST"
fi

# ═══════════════════════════════════════════════════════════════════
# Section 2: Stop.sh Finalization
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "Section 2: Stop.sh — Intel Session Finalization"
echo "─────────────────────────────────────────────────"

echo "Test 12: Stop.sh creates intel-summary.json from events"
# First ensure we have events (from section 1 above)
EVENT_COUNT=$(wc -l < "$PROJECT_DIR/.agentic/session/intel-events.log" 2>/dev/null)
EVENT_COUNT="${EVENT_COUNT## }"
OUTPUT=$(echo '{}' | CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
    bash "$PROJECT_DIR/.agentic/lib/claude-hooks/Stop.sh" 2>&1)
if [[ -f "$PROJECT_DIR/.agentic/intel/intel-summary.json" ]]; then
    pass "Stop.sh created intel-summary.json"
else
    fail "intel-summary.json not created" "events=$EVENT_COUNT"
fi

echo "Test 13: intel-summary.json has correct counts"
if [[ -f "$PROJECT_DIR/.agentic/intel/intel-summary.json" ]]; then
    QUERIES=$(grep -o '"total_queries"[[:space:]]*:[[:space:]]*[0-9]*' "$PROJECT_DIR/.agentic/intel/intel-summary.json" | head -1 | grep -o '[0-9]*$' || echo 0)
    MUTATES=$(grep -o '"total_mutations"[[:space:]]*:[[:space:]]*[0-9]*' "$PROJECT_DIR/.agentic/intel/intel-summary.json" | head -1 | grep -o '[0-9]*$' || echo 0)
    SCANS=$(grep -o '"total_scans"[[:space:]]*:[[:space:]]*[0-9]*' "$PROJECT_DIR/.agentic/intel/intel-summary.json" | head -1 | grep -o '[0-9]*$' || echo 0)
    if [[ "$QUERIES" -ge 4 && "$MUTATES" -ge 3 && "$SCANS" -ge 2 ]]; then
        pass "summary: $QUERIES queries, $MUTATES mutations, $SCANS scans"
    else
        fail "summary counts too low" "queries=$QUERIES mutations=$MUTATES scans=$SCANS"
    fi
else
    fail "intel-summary.json missing" ""
fi

echo "Test 14: Stop.sh outputs intel summary line"
if echo "$OUTPUT" | grep -q "🧠 Intel:"; then
    pass "Stop.sh prints intel summary to stderr"
else
    fail "Stop.sh missing intel summary line" "$(echo "$OUTPUT" | grep -i "intel")"
fi

echo "Test 15: Stop.sh cleans up intel-events.log"
if [[ ! -f "$PROJECT_DIR/.agentic/session/intel-events.log" ]]; then
    pass "intel-events.log cleaned up after finalization"
else
    fail "intel-events.log still exists" ""
fi

echo "Test 16: Stop.sh with no intel events doesn't crash"
rm -f "$PROJECT_DIR/.agentic/session/intel-events.log"
OUTPUT=$(echo '{}' | CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
    bash "$PROJECT_DIR/.agentic/lib/claude-hooks/Stop.sh" 2>&1)
RC=$?
if [[ $RC -eq 0 ]]; then
    pass "Stop.sh handles missing intel-events.log"
else
    fail "Stop.sh crashed without intel events" "exit $RC"
fi

# ═══════════════════════════════════════════════════════════════════
# Section 3: ag intel stats Shows Intel Metrics
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "Section 3: Stats Display"
echo "────────────────────────"

echo "Test 17: stats shows lifetime intel metrics"
OUTPUT=$(run_intel "$PROJECT_DIR" "_intel_stats" 2>&1)
if echo "$OUTPUT" | grep -q "Intelligence Sourcing.*Lifetime\|🧠.*Lifetime"; then
    pass "stats shows lifetime intel section"
else
    fail "stats missing intel lifetime" "$(echo "$OUTPUT" | grep -i "intel")"
fi

echo "Test 18: stats shows queries count"
if echo "$OUTPUT" | grep -q "Queries:"; then
    pass "stats shows queries line"
else
    fail "stats missing queries" ""
fi

echo "Test 19: stats shows enforcements count"
if echo "$OUTPUT" | grep -q "Enforcements:"; then
    pass "stats shows enforcements line"
else
    fail "stats missing enforcements" ""
fi

echo "Test 20: stats --session shows warning when no intel events"
rm -f "$PROJECT_DIR/.agentic/session/intel-events.log"
OUTPUT=$(run_intel "$PROJECT_DIR" '_intel_stats --session' 2>&1)
if echo "$OUTPUT" | grep -q "No intel sourcing events\|improvising"; then
    pass "stats warns about no intel events"
else
    fail "stats missing no-intel warning" "$(echo "$OUTPUT")"
fi

# Re-create some events for remaining tests
run_intel "$PROJECT_DIR" "_intel_architecture" >/dev/null 2>&1
run_intel "$PROJECT_DIR" "_intel_implement" >/dev/null 2>&1

echo "Test 21: stats --session shows current intel events"
OUTPUT=$(run_intel "$PROJECT_DIR" '_intel_stats --session' 2>&1)
if echo "$OUTPUT" | grep -q "Intelligence Sourcing.*Session\|🧠.*Session"; then
    pass "stats --session shows session intel"
else
    fail "stats --session missing intel" "$(echo "$OUTPUT" | grep -i "intel")"
fi

# ═══════════════════════════════════════════════════════════════════
# Section 4: PreToolUse Enforcement Logging
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "Section 4: Pattern Enforcement Logging"
echo "───────────────────────────────────────"

echo "Test 22: PreToolUse logs enforcement event when patterns match"
rm -f "$PROJECT_DIR/.agentic/session/intel-events.log"
echo '{"tool_name": "Write", "tool_input": {"file_path": "test.sh"}}' | \
    CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
    bash "$PROJECT_DIR/.agentic/lib/claude-hooks/PreToolUse.sh" 2>/dev/null || true

if [[ -f "$PROJECT_DIR/.agentic/session/intel-events.log" ]]; then
    LAST=$(tail -1 "$PROJECT_DIR/.agentic/session/intel-events.log")
    if echo "$LAST" | grep -q '|enforce|pattern:test.sh|'; then
        pass "enforcement logged for test.sh"
    else
        fail "enforcement event wrong format" "$LAST"
    fi
else
    fail "no intel-events.log from PreToolUse" ""
fi

echo "Test 23: enforcement event includes match count"
LAST=$(tail -1 "$PROJECT_DIR/.agentic/session/intel-events.log")
ITEMS=$(echo "$LAST" | awk -F'|' '{print $4}')
if [[ "$ITEMS" -ge 1 ]]; then
    pass "enforcement logged $ITEMS pattern match(es)"
else
    fail "enforcement logged 0 matches" "$LAST"
fi

echo "Test 24: PreToolUse does NOT log when no patterns match"
LINES_BEFORE=$(wc -l < "$PROJECT_DIR/.agentic/session/intel-events.log" 2>/dev/null || echo 0)
LINES_BEFORE="${LINES_BEFORE## }"
echo '{"tool_name": "Write", "tool_input": {"file_path": "README.md"}}' | \
    CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
    bash "$PROJECT_DIR/.agentic/lib/claude-hooks/PreToolUse.sh" 2>/dev/null || true
LINES_AFTER=$(wc -l < "$PROJECT_DIR/.agentic/session/intel-events.log" 2>/dev/null || echo 0)
LINES_AFTER="${LINES_AFTER## }"
if [[ "$LINES_BEFORE" -eq "$LINES_AFTER" ]]; then
    pass "no enforcement event for non-matching path"
else
    fail "spurious enforcement logged" "before=$LINES_BEFORE after=$LINES_AFTER"
fi

echo "Test 25: PreToolUse does NOT log for Read operations"
LINES_BEFORE=$(wc -l < "$PROJECT_DIR/.agentic/session/intel-events.log" 2>/dev/null || echo 0)
LINES_BEFORE="${LINES_BEFORE## }"
echo '{"tool_name": "Read", "tool_input": {"file_path": "test.sh"}}' | \
    CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
    bash "$PROJECT_DIR/.agentic/lib/claude-hooks/PreToolUse.sh" 2>/dev/null || true
LINES_AFTER=$(wc -l < "$PROJECT_DIR/.agentic/session/intel-events.log" 2>/dev/null || echo 0)
LINES_AFTER="${LINES_AFTER## }"
if [[ "$LINES_BEFORE" -eq "$LINES_AFTER" ]]; then
    pass "no enforcement event for Read (patterns only check writes)"
else
    fail "spurious enforcement for Read" ""
fi

# ═══════════════════════════════════════════════════════════════════
# Section 5: Lifetime Accumulation
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "Section 5: Lifetime Accumulation"
echo "─────────────────────────────────"

echo "Test 26: Second session accumulates into existing summary"
# Save current summary values
PREV_QUERIES=$(grep -o '"total_queries"[[:space:]]*:[[:space:]]*[0-9]*' "$PROJECT_DIR/.agentic/intel/intel-summary.json" 2>/dev/null | head -1 | grep -o '[0-9]*$' || echo 0)

# Generate new events
run_intel "$PROJECT_DIR" "_intel_architecture" >/dev/null 2>&1
run_intel "$PROJECT_DIR" "_intel_implement" >/dev/null 2>&1

# Finalize
echo '{}' | CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
    bash "$PROJECT_DIR/.agentic/lib/claude-hooks/Stop.sh" >/dev/null 2>&1

NEW_QUERIES=$(grep -o '"total_queries"[[:space:]]*:[[:space:]]*[0-9]*' "$PROJECT_DIR/.agentic/intel/intel-summary.json" 2>/dev/null | head -1 | grep -o '[0-9]*$' || echo 0)
if [[ "$NEW_QUERIES" -gt "$PREV_QUERIES" ]]; then
    pass "lifetime queries accumulated ($PREV_QUERIES → $NEW_QUERIES)"
else
    fail "queries didn't accumulate" "prev=$PREV_QUERIES new=$NEW_QUERIES"
fi

echo "Test 27: Session count increments"
SESSIONS=$(grep -o '"total_sessions"[[:space:]]*:[[:space:]]*[0-9]*' "$PROJECT_DIR/.agentic/intel/intel-summary.json" 2>/dev/null | head -1 | grep -o '[0-9]*$' || echo 0)
if [[ "$SESSIONS" -ge 2 ]]; then
    pass "session count = $SESSIONS (≥ 2)"
else
    fail "session count wrong" "$SESSIONS"
fi

# ═══════════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed (of $TOTAL)"
echo "═══════════════════════════════════════════"

exit $FAIL
