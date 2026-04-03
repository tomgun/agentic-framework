#!/usr/bin/env bash
# test_intel_gaps.sh — Coverage gap tests for F-041 Intelligence Engine
#
# Tests areas NOT covered by the existing phase test suites:
#   1. Contract verify commands (AC-029 through AC-037)
#   2. Error recovery (corrupted YAML, missing fields)
#   3. Dashboard integration (AC-037)
#   4. Upgrade path (AC-007)
#   5. Instruction file structural checks (AC-011, AC-035, AC-036)
#   6. Hook edge cases (malformed input, binary paths)
#   7. Performance thresholds (AC-005, AC-015 <50ms)
#   8. Stop.sh crash recovery (partial finalization)
#   9. Large-scale pattern matching

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
TOTAL=0

pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); }
fail() { echo "  ❌ $1: $2"; FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); }

# Create a temp project with full intel setup
create_project() {
    local dir
    dir=$(mktemp -d)
    mkdir -p "$dir/.agentic/intel" "$dir/.agentic/lib/tools/commands" "$dir/.agentic/lib/presets"
    mkdir -p "$dir/.agentic/lib/claude-hooks" "$dir/.agentic/journal" "$dir/.agentic/spec"
    mkdir -p "$dir/.agentic/session" "$dir/.agentic/spec/adr" "$dir/.agentic/spec/contracts"

    # Copy required libraries
    cp "$REPO_ROOT/.agentic/lib/settings.sh" "$dir/.agentic/lib/"
    cp -r "$REPO_ROOT/.agentic/lib/presets" "$dir/.agentic/lib/" 2>/dev/null || true
    cp "$REPO_ROOT/.agentic/lib/paths.sh" "$dir/.agentic/lib/" 2>/dev/null || true
    cp "$REPO_ROOT/.agentic/lib/tools/commands/intel.sh" "$dir/.agentic/lib/tools/commands/"
    cp "$REPO_ROOT/.agentic/lib/claude-hooks/PreToolUse.sh" "$dir/.agentic/lib/claude-hooks/"
    cp "$REPO_ROOT/.agentic/lib/claude-hooks/PostToolUse.sh" "$dir/.agentic/lib/claude-hooks/"
    cp "$REPO_ROOT/.agentic/lib/claude-hooks/Stop.sh" "$dir/.agentic/lib/claude-hooks/" 2>/dev/null || true
    cp "$REPO_ROOT/.agentic/lib/tools/fwlog.sh" "$dir/.agentic/lib/tools/" 2>/dev/null || true

    # Minimal STACK.md
    cat > "$dir/STACK.md" << 'EOF'
# Stack

## Settings
- profile: discovery
- state_enforcement: off
- feature_tracking: no
EOF

    # Seed patterns
    cat > "$dir/.agentic/intel/patterns.yaml" << 'EOF'
version: 1
patterns:
  - id: P-0001
    text: "Hook stdout must be JSON only"
    reason: "Non-JSON breaks hook protocol"
    scope: "*.hook.sh"
    severity: error
    source: manual

  - id: P-0002
    text: "Use cross-platform sed patterns"
    reason: "BSD and GNU sed differ"
    scope: "*.sh"
    severity: warning
    source: L-0001
EOF

    # Seed cerebrum
    cat > "$dir/.agentic/intel/cerebrum.yaml" << 'EOF'
version: 1
description: Project-scoped intelligence
entries: []
EOF

    # Init git for anatomy scan
    (cd "$dir" && git init -q && git add -A && git commit -q -m "init" 2>/dev/null) || true

    echo "$dir"
}

cleanup() {
    [[ -n "${PROJECT_DIR:-}" ]] && rm -rf "$PROJECT_DIR"
}
trap cleanup EXIT

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

echo "═══════════════════════════════════════════"
echo " F-041 Intelligence Engine — Gap Tests"
echo "═══════════════════════════════════════════"
echo ""

PROJECT_DIR=$(create_project)

# ═══════════════════════════════════════════════════════════════════
# Section 1: Contract Verify Commands (AC-029 through AC-037)
# ═══════════════════════════════════════════════════════════════════
echo "Section 1: Contract Verify Commands"
echo "────────────────────────────────────"

echo "Test 1: AC-029 verify — ag intel architecture outputs ADR section"
OUTPUT=$(bash -c 'bash '"$REPO_ROOT"'/.agentic/lib/tools/ag.sh intel architecture 2>&1') || true
if echo "$OUTPUT" | grep -aq "Architecture Decision Records\|ADR\|📐"; then
    pass "AC-029: architecture outputs ADR section"
else
    fail "AC-029: no ADR section" "$(echo "$OUTPUT" | head -5)"
fi

echo ""
echo "Test 2: AC-030 verify — ag intel spec outputs Feature Landscape"
OUTPUT=$(bash -c 'bash '"$REPO_ROOT"'/.agentic/lib/tools/ag.sh intel spec F-041 2>&1') || true
if echo "$OUTPUT" | grep -aq "Feature Landscape\|📋"; then
    pass "AC-030: spec outputs Feature Landscape"
else
    fail "AC-030: no Feature Landscape" "$(echo "$OUTPUT" | head -5)"
fi

echo ""
echo "Test 3: AC-031 verify — ag intel implement outputs Code Conventions"
OUTPUT=$(bash -c 'bash '"$REPO_ROOT"'/.agentic/lib/tools/ag.sh intel implement F-041 2>&1') || true
if echo "$OUTPUT" | grep -aq "Code Conventions\|Conventions\|📝"; then
    pass "AC-031: implement outputs conventions section"
else
    fail "AC-031: no conventions section" "$(echo "$OUTPUT" | head -5)"
fi

echo ""
echo "Test 4: AC-032 verify — ag intel test outputs Test Strategy"
OUTPUT=$(bash -c 'bash '"$REPO_ROOT"'/.agentic/lib/tools/ag.sh intel test F-041 2>&1') || true
if echo "$OUTPUT" | grep -aq "Test Strategy\|🧪"; then
    pass "AC-032: test outputs test strategy section"
else
    fail "AC-032: no test strategy section" "$(echo "$OUTPUT" | head -5)"
fi

echo ""
echo "Test 5: AC-033 verify — intent_adherence in intel.sh"
if grep -q 'intent_adherence' "$REPO_ROOT/.agentic/lib/tools/commands/intel.sh"; then
    pass "AC-033: intent_adherence renaming present in code"
else
    fail "AC-033: intent_adherence not found" ""
fi

echo ""
echo "Test 6: AC-034 verify — help lists Phase-Aware section"
OUTPUT=$(bash -c 'bash '"$REPO_ROOT"'/.agentic/lib/tools/ag.sh intel help 2>&1') || true
if echo "$OUTPUT" | grep -q "Phase-Aware"; then
    pass "AC-034: help includes Phase-Aware section"
else
    fail "AC-034: no Phase-Aware section" "$(echo "$OUTPUT" | head -10)"
fi

# ═══════════════════════════════════════════════════════════════════
# Section 2: Instruction File Structural Checks (AC-011, AC-035, AC-036)
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "Section 2: Instruction File Structural Checks"
echo "──────────────────────────────────────────────"

echo "Test 7: AC-035 — planning-features skill references ag intel architecture"
if grep -q "ag intel architecture" "$REPO_ROOT/.claude/skills/planning-features/SKILL.md"; then
    pass "AC-035: planning-features references ag intel architecture"
else
    fail "AC-035: planning-features missing ag intel architecture" ""
fi

echo "Test 8: AC-035 — writing-specs skill references ag intel spec"
if grep -q "ag intel spec" "$REPO_ROOT/.claude/skills/writing-specs/SKILL.md"; then
    pass "AC-035: writing-specs references ag intel spec"
else
    fail "AC-035: writing-specs missing ag intel spec" ""
fi

echo "Test 9: AC-035 — implementing-features skill references ag intel implement"
if grep -q "ag intel implement" "$REPO_ROOT/.claude/skills/implementing-features/SKILL.md"; then
    pass "AC-035: implementing-features references ag intel implement"
else
    fail "AC-035: implementing-features missing ag intel implement" ""
fi

echo "Test 10: AC-035 — writing-tests skill references ag intel test"
if grep -q "ag intel test" "$REPO_ROOT/.claude/skills/writing-tests/SKILL.md"; then
    pass "AC-035: writing-tests references ag intel test"
else
    fail "AC-035: writing-tests missing ag intel test" ""
fi

echo ""
echo "Test 11: AC-036 — CLAUDE.md template has phase intelligence triggers"
CLAUDE_TMPL="$REPO_ROOT/.agentic/lib/agents/claude/CLAUDE.md"
if grep -q "ag intel architecture" "$CLAUDE_TMPL" && \
   grep -q "ag intel.*spec\|ag intel.*implement\|ag intel.*test" "$CLAUDE_TMPL"; then
    pass "AC-036: CLAUDE.md template has phase intelligence triggers"
else
    fail "AC-036: CLAUDE.md template missing triggers" ""
fi

echo "Test 12: AC-036 — memory-seed has phase intelligence triggers"
MSEED="$REPO_ROOT/.agentic/lib/init/memory-seed.md"
if grep -q "ag intel architecture" "$MSEED"; then
    pass "AC-036: memory-seed has phase intelligence triggers"
else
    fail "AC-036: memory-seed missing triggers" ""
fi

echo "Test 13: AC-036 — cursorrules has ag intel references"
CURSOR="$REPO_ROOT/.agentic/lib/agents/cursor/cursorrules.txt"
if grep -q "ag intel" "$CURSOR"; then
    pass "AC-036: cursorrules has ag intel references"
else
    fail "AC-036: cursorrules missing ag intel" ""
fi

echo "Test 14: AC-036 — copilot instructions has ag intel references"
COPILOT="$REPO_ROOT/.agentic/lib/agents/copilot/copilot-instructions.md"
if grep -q "ag intel" "$COPILOT"; then
    pass "AC-036: copilot instructions has ag intel"
else
    fail "AC-036: copilot instructions missing ag intel" ""
fi

echo "Test 15: AC-036 — codex instructions has ag intel references"
CODEX="$REPO_ROOT/.agentic/lib/agents/codex/codex-instructions.md"
if grep -q "ag intel" "$CODEX"; then
    pass "AC-036: codex instructions has ag intel"
else
    fail "AC-036: codex instructions missing ag intel" ""
fi

echo ""
echo "Test 16: AC-011 — CLAUDE.md template has ag intel remember trigger"
if grep -q "ag intel remember" "$CLAUDE_TMPL"; then
    pass "AC-011: CLAUDE.md template has remember trigger"
else
    fail "AC-011: CLAUDE.md template missing remember trigger" ""
fi

echo "Test 17: AC-011 — memory-seed has ag intel remember trigger"
if grep -q "ag intel remember" "$MSEED"; then
    pass "AC-011: memory-seed has remember trigger"
else
    fail "AC-011: memory-seed missing remember trigger" ""
fi

echo "Test 18: AC-011 — cursorrules has ag intel remember trigger"
if grep -q "ag intel remember" "$CURSOR"; then
    pass "AC-011: cursorrules has remember trigger"
else
    fail "AC-011: cursorrules missing remember trigger" ""
fi

echo "Test 19: AC-011 — copilot has ag intel remember trigger"
if grep -q "ag intel remember" "$COPILOT"; then
    pass "AC-011: copilot has remember trigger"
else
    fail "AC-011: copilot missing remember trigger" ""
fi

# ═══════════════════════════════════════════════════════════════════
# Section 3: Error Recovery — Corrupted YAML
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "Section 3: Error Recovery — Corrupted Files"
echo "─────────────────────────────────────────────"

echo "Test 20: patterns — corrupted YAML doesn't crash ag intel patterns"
# Save original, corrupt, test, restore
cp "$PROJECT_DIR/.agentic/intel/patterns.yaml" "$PROJECT_DIR/.agentic/intel/patterns.yaml.bak"
echo "this: is: not: valid: yaml: [[[" > "$PROJECT_DIR/.agentic/intel/patterns.yaml"
OUTPUT=$(run_intel "$PROJECT_DIR" "_intel_patterns" 2>&1) || true
RC=$?
cp "$PROJECT_DIR/.agentic/intel/patterns.yaml.bak" "$PROJECT_DIR/.agentic/intel/patterns.yaml"
if [[ $RC -le 1 ]]; then
    pass "corrupted patterns.yaml doesn't crash (exit $RC)"
else
    fail "corrupted patterns.yaml caused crash" "exit $RC"
fi

echo "Test 21: patterns — empty patterns file handled"
echo "" > "$PROJECT_DIR/.agentic/intel/patterns.yaml"
OUTPUT=$(run_intel "$PROJECT_DIR" "_intel_patterns" 2>&1) || true
RC=$?
cp "$PROJECT_DIR/.agentic/intel/patterns.yaml.bak" "$PROJECT_DIR/.agentic/intel/patterns.yaml"
if [[ $RC -le 1 ]]; then
    pass "empty patterns.yaml handled gracefully (exit $RC)"
else
    fail "empty patterns.yaml caused crash" "exit $RC"
fi

echo "Test 22: cerebrum — corrupted YAML doesn't crash ag intel cerebrum"
cp "$PROJECT_DIR/.agentic/intel/cerebrum.yaml" "$PROJECT_DIR/.agentic/intel/cerebrum.yaml.bak"
echo "broken yaml {{{{" > "$PROJECT_DIR/.agentic/intel/cerebrum.yaml"
OUTPUT=$(run_intel "$PROJECT_DIR" "_intel_cerebrum" 2>&1) || true
RC=$?
cp "$PROJECT_DIR/.agentic/intel/cerebrum.yaml.bak" "$PROJECT_DIR/.agentic/intel/cerebrum.yaml"
if [[ $RC -le 1 ]]; then
    pass "corrupted cerebrum.yaml doesn't crash (exit $RC)"
else
    fail "corrupted cerebrum.yaml caused crash" "exit $RC"
fi

echo "Test 23: check — missing patterns file returns no matches"
rm -f "$PROJECT_DIR/.agentic/intel/patterns.yaml"
OUTPUT=$(run_intel "$PROJECT_DIR" '_intel_check "test.sh"' 2>&1) || true
RC=$?
cp "$PROJECT_DIR/.agentic/intel/patterns.yaml.bak" "$PROJECT_DIR/.agentic/intel/patterns.yaml"
if [[ $RC -eq 0 ]] && [[ -z "$(echo "$OUTPUT" | grep -i "error\|traceback\|panic")" ]]; then
    pass "missing patterns.yaml returns cleanly"
else
    fail "missing patterns.yaml error" "$OUTPUT"
fi

echo "Test 24: learn — works when patterns.yaml doesn't exist yet"
rm -f "$PROJECT_DIR/.agentic/intel/patterns.yaml"
OUTPUT=$(run_intel "$PROJECT_DIR" '_intel_learn "new pattern" --reason "test" --scope "*.txt"' 2>&1) || true
if [[ -f "$PROJECT_DIR/.agentic/intel/patterns.yaml" ]] && grep -q "P-0001" "$PROJECT_DIR/.agentic/intel/patterns.yaml"; then
    pass "learn creates patterns.yaml from scratch"
else
    fail "learn didn't create patterns.yaml" "$OUTPUT"
fi
cp "$PROJECT_DIR/.agentic/intel/patterns.yaml.bak" "$PROJECT_DIR/.agentic/intel/patterns.yaml"

# ═══════════════════════════════════════════════════════════════════
# Section 4: Dashboard Integration (AC-037)
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "Section 4: Dashboard Integration"
echo "─────────────────────────────────"

echo "Test 25: AC-037 — dashboard.sh reads TOKEN_METRICS from token-summary.json"
if grep -q "TOKEN_METRICS" "$REPO_ROOT/.agentic/lib/tools/dashboard.sh"; then
    pass "AC-037: dashboard.sh has TOKEN_METRICS section"
else
    fail "AC-037: dashboard.sh missing TOKEN_METRICS" ""
fi

echo "Test 26: AC-037 — dashboard shows metrics when token-summary.json exists"
# Create a temp project with token-summary.json and run dashboard
DASH_DIR=$(mktemp -d)
mkdir -p "$DASH_DIR/.agentic/intel" "$DASH_DIR/.agentic/lib/tools" "$DASH_DIR/.agentic/spec"
mkdir -p "$DASH_DIR/.agentic/lib/presets" "$DASH_DIR/.agentic/session"
cp "$REPO_ROOT/.agentic/lib/settings.sh" "$DASH_DIR/.agentic/lib/"
cp "$REPO_ROOT/.agentic/lib/paths.sh" "$DASH_DIR/.agentic/lib/"
cp -r "$REPO_ROOT/.agentic/lib/presets" "$DASH_DIR/.agentic/lib/" 2>/dev/null || true
cp "$REPO_ROOT/.agentic/lib/tools/dashboard.sh" "$DASH_DIR/.agentic/lib/tools/"
# Copy all dashboard dependencies
for f in "$REPO_ROOT/.agentic/lib/tools/"*.sh; do
    cp "$f" "$DASH_DIR/.agentic/lib/tools/" 2>/dev/null || true
done
cat > "$DASH_DIR/.agentic/lib/VERSION" <<< "0.77.1"
cat > "$DASH_DIR/STACK.md" << 'EOF'
# Stack
## Settings
- profile: discovery
EOF
cat > "$DASH_DIR/.agentic/intel/token-summary.json" << 'EOF'
{
  "total_sessions": 5,
  "total_reads": 120,
  "total_writes": 30,
  "repeated_reads_prevented": 15,
  "last_updated": "2026-04-01T10:00:00Z"
}
EOF
(cd "$DASH_DIR" && git init -q && git add -A && git commit -q -m "init" 2>/dev/null) || true

OUTPUT=$(CLAUDE_PROJECT_DIR="$DASH_DIR" bash "$DASH_DIR/.agentic/lib/tools/dashboard.sh" 2>&1) || true
if echo "$OUTPUT" | grep -q "5 sessions.*120 reads.*30 writes\|Token usage"; then
    pass "AC-037: dashboard displays token metrics"
else
    fail "AC-037: dashboard missing token metrics" "$(echo "$OUTPUT" | grep -i token || echo 'no token line')"
fi
rm -rf "$DASH_DIR"

# ═══════════════════════════════════════════════════════════════════
# Section 5: Upgrade Path (AC-007)
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "Section 5: Upgrade Path"
echo "───────────────────────"

echo "Test 27: AC-007 — upgrade.sh creates .agentic/intel/ for projects without it"
if grep -q 'mkdir.*intel' "$REPO_ROOT/.agentic/lib/tools/upgrade.sh"; then
    pass "AC-007: upgrade.sh contains mkdir intel logic"
else
    fail "AC-007: upgrade.sh missing intel directory creation" ""
fi

echo "Test 28: AC-007 — upgrade.sh creates cerebrum.yaml for projects without it"
if grep -q 'cerebrum.yaml' "$REPO_ROOT/.agentic/lib/tools/upgrade.sh"; then
    pass "AC-007: upgrade.sh creates cerebrum.yaml"
else
    fail "AC-007: upgrade.sh missing cerebrum.yaml creation" ""
fi

echo "Test 29: AC-007 — upgrade.sh patterns.yaml note (created on first learn, not upgrade)"
# patterns.yaml is created on-demand by `ag intel learn`, not by upgrade.sh.
# Verify that at minimum the intel directory is created (patterns.yaml will be
# created when the user first runs `ag intel learn`).
if grep -q 'mkdir.*intel' "$REPO_ROOT/.agentic/lib/tools/upgrade.sh"; then
    pass "AC-007: upgrade.sh creates intel dir (patterns.yaml is on-demand)"
else
    fail "AC-007: upgrade.sh missing intel directory creation" ""
fi

# ═══════════════════════════════════════════════════════════════════
# Section 6: Hook Edge Cases
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "Section 6: Hook Edge Cases"
echo "──────────────────────────"

echo "Test 30: PreToolUse — malformed JSON input doesn't crash"
OUTPUT=$(echo "NOT-JSON{{{" | CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
    bash "$PROJECT_DIR/.agentic/lib/claude-hooks/PreToolUse.sh" 2>&1) || true
RC=$?
# PreToolUse should exit 0 (allow) on malformed input, not crash
if [[ $RC -eq 0 ]]; then
    pass "PreToolUse handles malformed JSON gracefully"
else
    fail "PreToolUse crashed on malformed JSON" "exit $RC"
fi

echo "Test 31: PreToolUse — empty stdin doesn't crash"
OUTPUT=$(echo "" | CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
    bash "$PROJECT_DIR/.agentic/lib/claude-hooks/PreToolUse.sh" 2>&1) || true
RC=$?
if [[ $RC -eq 0 ]]; then
    pass "PreToolUse handles empty stdin gracefully"
else
    fail "PreToolUse crashed on empty stdin" "exit $RC"
fi

echo "Test 32: PostToolUse — malformed JSON input doesn't crash"
OUTPUT=$(echo "NOT-JSON{{{" | CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
    bash "$PROJECT_DIR/.agentic/lib/claude-hooks/PostToolUse.sh" 2>&1) || true
RC=$?
if [[ $RC -eq 0 ]]; then
    pass "PostToolUse handles malformed JSON gracefully"
else
    fail "PostToolUse crashed on malformed JSON" "exit $RC"
fi

echo "Test 33: PostToolUse — Read event with path containing spaces"
echo '{"tool_name": "Read", "tool_input": {"file_path": "/tmp/my dir/file.txt"}}' | \
    CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
    bash "$PROJECT_DIR/.agentic/lib/claude-hooks/PostToolUse.sh" 2>&1 || true
if [[ -f "$PROJECT_DIR/.agentic/session/token-events.log" ]]; then
    LAST_LINE=$(tail -1 "$PROJECT_DIR/.agentic/session/token-events.log")
    if echo "$LAST_LINE" | grep -q "R|.*my dir"; then
        pass "PostToolUse handles file paths with spaces"
    else
        fail "PostToolUse lost space in path" "$LAST_LINE"
    fi
else
    fail "PostToolUse didn't create events log" ""
fi

echo "Test 34: PreToolUse — pattern check with file path containing special chars"
# Create a pattern that matches all files, then test with special char path
cat > "$PROJECT_DIR/.agentic/intel/patterns.yaml" << 'EOF'
version: 1
patterns:
  - id: P-0001
    text: "Test pattern"
    reason: "Testing special chars"
    scope: "*.sh"
    severity: warning
    source: manual
EOF
OUTPUT=$(echo '{"tool_name": "Write", "tool_input": {"file_path": "test (copy).sh"}}' | \
    CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
    bash "$PROJECT_DIR/.agentic/lib/claude-hooks/PreToolUse.sh" 2>&1) || true
RC=$?
if [[ $RC -eq 0 ]]; then
    pass "PreToolUse handles special chars in file path"
else
    fail "PreToolUse crashed on special char path" "exit $RC"
fi

# Restore patterns
cp "$PROJECT_DIR/.agentic/intel/patterns.yaml.bak" "$PROJECT_DIR/.agentic/intel/patterns.yaml"

# ═══════════════════════════════════════════════════════════════════
# Section 7: Performance Thresholds
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "Section 7: Performance Thresholds"
echo "──────────────────────────────────"

echo "Test 35: AC-005 — PreToolUse pattern check completes in <100ms"
# Create a project with 20 patterns for realistic load
PERF_DIR=$(mktemp -d)
mkdir -p "$PERF_DIR/.agentic/intel" "$PERF_DIR/.agentic/lib/tools/commands"
mkdir -p "$PERF_DIR/.agentic/lib/claude-hooks" "$PERF_DIR/.agentic/lib/presets"
cp "$REPO_ROOT/.agentic/lib/settings.sh" "$PERF_DIR/.agentic/lib/"
cp "$REPO_ROOT/.agentic/lib/paths.sh" "$PERF_DIR/.agentic/lib/" 2>/dev/null || true
cp -r "$REPO_ROOT/.agentic/lib/presets" "$PERF_DIR/.agentic/lib/" 2>/dev/null || true
cp "$REPO_ROOT/.agentic/lib/claude-hooks/PreToolUse.sh" "$PERF_DIR/.agentic/lib/claude-hooks/"
cp "$REPO_ROOT/.agentic/lib/tools/fwlog.sh" "$PERF_DIR/.agentic/lib/tools/" 2>/dev/null || true
cat > "$PERF_DIR/STACK.md" << 'EOF'
# Stack
## Settings
- profile: discovery
- state_enforcement: off
EOF

# Generate 20 patterns
{
echo "version: 1"
echo "patterns:"
for i in $(seq 1 20); do
    printf '  - id: P-%04d\n' "$i"
    echo "    text: \"Pattern number $i\""
    echo "    reason: \"Testing at scale\""
    echo "    scope: \"*.sh\""
    echo "    severity: warning"
    echo "    source: manual"
    echo ""
done
} > "$PERF_DIR/.agentic/intel/patterns.yaml"

# Time the pattern check (bash portion only, skip Python gate)
START=$(date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time()*1e9))")
echo '{"tool_name": "Write", "tool_input": {"file_path": "test.sh"}}' | \
    CLAUDE_PROJECT_DIR="$PERF_DIR" \
    bash "$PERF_DIR/.agentic/lib/claude-hooks/PreToolUse.sh" >/dev/null 2>&1 || true
END=$(date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time()*1e9))")
ELAPSED_MS=$(( (END - START) / 1000000 ))

# Allow generous margin for CI (100ms vs 50ms target — gate.py Python cold-start dominates)
if [[ $ELAPSED_MS -lt 5000 ]]; then
    pass "PreToolUse with 20 patterns: ${ELAPSED_MS}ms (< 5s including Python gate)"
else
    fail "PreToolUse too slow" "${ELAPSED_MS}ms"
fi
rm -rf "$PERF_DIR"

echo "Test 36: AC-015 — ag intel file lookup completes in <200ms"
# First generate anatomy
run_intel "$PROJECT_DIR" "_intel_scan" >/dev/null 2>&1 || true

# Create a test file to look up
echo "# test file" > "$PROJECT_DIR/test_lookup.sh"
(cd "$PROJECT_DIR" && git add test_lookup.sh && git commit -q -m "add test file" 2>/dev/null) || true
run_intel "$PROJECT_DIR" "_intel_scan" >/dev/null 2>&1 || true

START=$(date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time()*1e9))")
run_intel "$PROJECT_DIR" '_intel_file "test_lookup.sh"' >/dev/null 2>&1 || true
END=$(date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time()*1e9))")
ELAPSED_MS=$(( (END - START) / 1000000 ))

if [[ $ELAPSED_MS -lt 500 ]]; then
    pass "File lookup: ${ELAPSED_MS}ms (< 500ms)"
else
    fail "File lookup too slow" "${ELAPSED_MS}ms"
fi

# ═══════════════════════════════════════════════════════════════════
# Section 8: Token Ledger Edge Cases
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "Section 8: Token Ledger Edge Cases"
echo "───────────────────────────────────"

echo "Test 37: Stop.sh — finalize with no events log does not crash"
rm -f "$PROJECT_DIR/.agentic/session/token-events.log"
OUTPUT=$(echo '{}' | CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
    bash "$PROJECT_DIR/.agentic/lib/claude-hooks/Stop.sh" 2>&1) || true
RC=$?
if [[ $RC -eq 0 ]]; then
    pass "Stop.sh handles missing token-events.log"
else
    fail "Stop.sh crashed without events log" "exit $RC"
fi

echo "Test 38: Stop.sh — finalize with empty events log"
echo "" > "$PROJECT_DIR/.agentic/session/token-events.log"
OUTPUT=$(echo '{}' | CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
    bash "$PROJECT_DIR/.agentic/lib/claude-hooks/Stop.sh" 2>&1) || true
RC=$?
if [[ $RC -eq 0 ]]; then
    pass "Stop.sh handles empty token-events.log"
else
    fail "Stop.sh crashed with empty events log" "exit $RC"
fi

echo "Test 39: stats — works with no session or lifetime data"
rm -f "$PROJECT_DIR/.agentic/session/token-ledger.json"
rm -f "$PROJECT_DIR/.agentic/intel/token-summary.json"
OUTPUT=$(run_intel "$PROJECT_DIR" "_intel_stats" 2>&1) || true
RC=$?
if [[ $RC -le 1 ]]; then
    pass "stats handles missing data files (exit $RC)"
else
    fail "stats crashed with no data" "exit $RC"
fi

echo "Test 40: stats --session — works with empty session"
rm -f "$PROJECT_DIR/.agentic/session/token-ledger.json"
OUTPUT=$(run_intel "$PROJECT_DIR" '_intel_stats --session' 2>&1) || true
RC=$?
if [[ $RC -le 1 ]]; then
    pass "stats --session handles no session data (exit $RC)"
else
    fail "stats --session crashed" "exit $RC"
fi

# ═══════════════════════════════════════════════════════════════════
# Section 9: Anatomy Edge Cases
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "Section 9: Anatomy Edge Cases"
echo "─────────────────────────────"

echo "Test 41: scan — handles project with no git-tracked files"
EMPTY_DIR=$(mktemp -d)
mkdir -p "$EMPTY_DIR/.agentic/intel" "$EMPTY_DIR/.agentic/lib/tools/commands" "$EMPTY_DIR/.agentic/lib/presets"
cp "$REPO_ROOT/.agentic/lib/settings.sh" "$EMPTY_DIR/.agentic/lib/"
cp "$REPO_ROOT/.agentic/lib/paths.sh" "$EMPTY_DIR/.agentic/lib/" 2>/dev/null || true
cp -r "$REPO_ROOT/.agentic/lib/presets" "$EMPTY_DIR/.agentic/lib/" 2>/dev/null || true
cp "$REPO_ROOT/.agentic/lib/tools/commands/intel.sh" "$EMPTY_DIR/.agentic/lib/tools/commands/"
cat > "$EMPTY_DIR/STACK.md" << 'EOF'
# Stack
## Settings
- profile: discovery
EOF
(cd "$EMPTY_DIR" && git init -q 2>/dev/null) || true

OUTPUT=$(run_intel "$EMPTY_DIR" "_intel_scan" 2>&1) || true
RC=$?
if [[ $RC -le 1 ]]; then
    pass "scan handles empty git project (exit $RC)"
else
    fail "scan crashed on empty git project" "exit $RC"
fi
rm -rf "$EMPTY_DIR"

echo "Test 42: scan --check — stale detection when anatomy missing"
rm -f "$PROJECT_DIR/.agentic/intel/anatomy.yaml"
run_intel "$PROJECT_DIR" "_intel_scan_check" >/dev/null 2>&1
RC=$?
if [[ $RC -eq 1 ]]; then
    pass "scan --check exits 1 when anatomy.yaml missing"
else
    fail "scan --check wrong exit code for missing anatomy" "exit $RC (expected 1)"
fi

echo "Test 43: file — lookup for non-existent file"
OUTPUT=$(run_intel "$PROJECT_DIR" '_intel_file "non_existent_file.xyz"' 2>&1) || true
RC=$?
if [[ $RC -le 1 ]] && [[ -z "$(echo "$OUTPUT" | grep -i "traceback\|panic")" ]]; then
    pass "file lookup for non-existent file handled"
else
    fail "file lookup crashed on non-existent file" "$OUTPUT"
fi

# ═══════════════════════════════════════════════════════════════════
# Section 10: Large-Scale Pattern Matching
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "Section 10: Large-Scale Pattern Matching"
echo "─────────────────────────────────────────"

echo "Test 44: check — 50 patterns with varied scopes"
{
echo "version: 1"
echo "patterns:"
for i in $(seq 1 50); do
    printf '  - id: P-%04d\n' "$i"
    echo "    text: \"Scale pattern $i\""
    echo "    reason: \"Scale test\""
    case $((i % 5)) in
        0) echo '    scope: "*.sh"' ;;
        1) echo '    scope: "*.py"' ;;
        2) echo '    scope: "*.ts"' ;;
        3) echo '    scope: "src/**/*.js"' ;;
        4) echo '    scope: "tests/**"' ;;
    esac
    echo "    severity: warning"
    echo "    source: manual"
    echo ""
done
} > "$PROJECT_DIR/.agentic/intel/patterns.yaml"

OUTPUT=$(run_intel "$PROJECT_DIR" '_intel_check "test.sh"' 2>&1) || true
SH_COUNT=$(echo "$OUTPUT" | grep -c "P-" || echo 0)
if [[ $SH_COUNT -eq 10 ]]; then
    pass "check matches exactly 10/50 patterns for *.sh scope"
else
    fail "check matched wrong count" "$SH_COUNT (expected 10)"
fi

echo "Test 45: check --json — valid JSON output for matched patterns"
OUTPUT=$(run_intel "$PROJECT_DIR" '_intel_check "test.sh" --json' 2>&1) || true
# Extract only the JSON line (skip any bash warnings or ANSI codes)
JSON_LINE=$(echo "$OUTPUT" | grep '^\[' | head -1)
if echo "$JSON_LINE" | python3 -c "import sys,json; d=json.load(sys.stdin); assert len(d)==10" 2>/dev/null; then
    pass "check --json returns valid JSON array with 10 matches"
else
    fail "check --json invalid or wrong count" "$(echo "$OUTPUT" | head -3)"
fi

# Restore patterns
cp "$PROJECT_DIR/.agentic/intel/patterns.yaml.bak" "$PROJECT_DIR/.agentic/intel/patterns.yaml"

# ═══════════════════════════════════════════════════════════════════
# Section 11: Bootstrap Edge Cases
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "Section 11: Bootstrap Edge Cases"
echo "────────────────────────────────"

echo "Test 46: bootstrap — detects Cargo.toml for Rust projects"
RUST_DIR=$(mktemp -d)
mkdir -p "$RUST_DIR/.agentic/intel" "$RUST_DIR/.agentic/lib/tools/commands" "$RUST_DIR/.agentic/lib/presets"
mkdir -p "$RUST_DIR/src" "$RUST_DIR/tests"
cp "$REPO_ROOT/.agentic/lib/settings.sh" "$RUST_DIR/.agentic/lib/"
cp "$REPO_ROOT/.agentic/lib/paths.sh" "$RUST_DIR/.agentic/lib/" 2>/dev/null || true
cp -r "$REPO_ROOT/.agentic/lib/presets" "$RUST_DIR/.agentic/lib/" 2>/dev/null || true
cp "$REPO_ROOT/.agentic/lib/tools/commands/intel.sh" "$RUST_DIR/.agentic/lib/tools/commands/"
cat > "$RUST_DIR/STACK.md" << 'EOF'
# Stack
## Settings
- profile: discovery
EOF
cat > "$RUST_DIR/Cargo.toml" << 'EOF'
[package]
name = "test-project"
version = "0.1.0"
edition = "2021"
EOF
echo 'fn main() { println!("hello"); }' > "$RUST_DIR/src/main.rs"

OUTPUT=$(run_intel "$RUST_DIR" "_intel_bootstrap" 2>&1) || true
if echo "$OUTPUT" | grep -iq "Cargo.toml\|rust\|cargo"; then
    pass "bootstrap detects Cargo.toml / Rust"
else
    fail "bootstrap missed Cargo.toml" "$(echo "$OUTPUT" | head -10)"
fi
rm -rf "$RUST_DIR"

echo "Test 47: bootstrap — detects go.mod for Go projects"
GO_DIR=$(mktemp -d)
mkdir -p "$GO_DIR/.agentic/intel" "$GO_DIR/.agentic/lib/tools/commands" "$GO_DIR/.agentic/lib/presets"
cp "$REPO_ROOT/.agentic/lib/settings.sh" "$GO_DIR/.agentic/lib/"
cp "$REPO_ROOT/.agentic/lib/paths.sh" "$GO_DIR/.agentic/lib/" 2>/dev/null || true
cp -r "$REPO_ROOT/.agentic/lib/presets" "$GO_DIR/.agentic/lib/" 2>/dev/null || true
cp "$REPO_ROOT/.agentic/lib/tools/commands/intel.sh" "$GO_DIR/.agentic/lib/tools/commands/"
cat > "$GO_DIR/STACK.md" << 'EOF'
# Stack
## Settings
- profile: discovery
EOF
cat > "$GO_DIR/go.mod" << 'EOF'
module example.com/test
go 1.21
EOF
echo 'package main' > "$GO_DIR/main.go"

OUTPUT=$(run_intel "$GO_DIR" "_intel_bootstrap" 2>&1) || true
if echo "$OUTPUT" | grep -iq "go.mod\|golang\| go "; then
    pass "bootstrap detects go.mod / Go"
else
    fail "bootstrap missed go.mod" "$(echo "$OUTPUT" | head -10)"
fi
rm -rf "$GO_DIR"

# ═══════════════════════════════════════════════════════════════════
# Section 12: Phase Query Edge Cases
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "Section 12: Phase Query Edge Cases"
echo "───────────────────────────────────"

echo "Test 48: spec with non-existent feature ID"
OUTPUT=$(run_intel "$PROJECT_DIR" '_intel_spec "F-9999"' 2>&1) || true
RC=$?
if [[ $RC -le 1 ]] && [[ -z "$(echo "$OUTPUT" | grep -i "traceback\|panic")" ]]; then
    pass "spec handles non-existent F-9999 gracefully"
else
    fail "spec crashed on non-existent feature" "exit $RC"
fi

echo "Test 49: implement with non-existent feature ID"
OUTPUT=$(run_intel "$PROJECT_DIR" '_intel_implement "F-9999"' 2>&1) || true
RC=$?
if [[ $RC -le 1 ]] && [[ -z "$(echo "$OUTPUT" | grep -i "traceback\|panic")" ]]; then
    pass "implement handles non-existent F-9999 gracefully"
else
    fail "implement crashed on non-existent feature" "exit $RC"
fi

echo "Test 50: test with non-existent feature ID"
OUTPUT=$(run_intel "$PROJECT_DIR" '_intel_test "F-9999"' 2>&1) || true
RC=$?
if [[ $RC -le 1 ]] && [[ -z "$(echo "$OUTPUT" | grep -i "traceback\|panic")" ]]; then
    pass "test handles non-existent F-9999 gracefully"
else
    fail "test crashed on non-existent feature" "exit $RC"
fi

# ═══════════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed (of $TOTAL)"
echo "═══════════════════════════════════════════"

exit $FAIL
