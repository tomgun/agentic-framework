#!/usr/bin/env bash
# Tests for F-0225: spec-metrics.sh — Spec Evolution Metrics
#
# Structural tests with temp dir, synthetic AC files, and git repo.
# Covers: discovery counting, churn analysis, JSON output, summary line, edge cases.

set -euo pipefail

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SPEC_METRICS="$PROJECT_ROOT/.agentic/lib/tools/spec-metrics.sh"

# --- Helpers ---

setup_tmpdir() {
    TMPDIR=$(mktemp -d)
    mkdir -p "$TMPDIR/.agentic/spec/acceptance"
    mkdir -p "$TMPDIR/.agentic/lib/tools"
    mkdir -p "$TMPDIR/.agentic/lib/presets"

    # Copy framework libs needed by spec-metrics.sh
    cp "$PROJECT_ROOT/.agentic/lib/paths.sh" "$TMPDIR/.agentic/lib/paths.sh"
    cp "$PROJECT_ROOT/.agentic/lib/ids.sh" "$TMPDIR/.agentic/lib/ids.sh"
    cp "$PROJECT_ROOT/.agentic/lib/settings.sh" "$TMPDIR/.agentic/lib/settings.sh"
    cp -r "$PROJECT_ROOT/.agentic/lib/presets/"* "$TMPDIR/.agentic/lib/presets/" 2>/dev/null || true
    cp "$PROJECT_ROOT/.agentic/lib/tools/ac-parse.sh" "$TMPDIR/.agentic/lib/tools/ac-parse.sh"
    cp "$SPEC_METRICS" "$TMPDIR/.agentic/lib/tools/spec-metrics.sh"

    # Minimal STACK.md (settings.sh needs it)
    cat > "$TMPDIR/STACK.md" <<'EOF'
# Stack
## Settings
- profile: discovery
EOF

    # Minimal git repo
    git -C "$TMPDIR" init -q 2>/dev/null
    git -C "$TMPDIR" config user.email "test@test.com"
    git -C "$TMPDIR" config user.name "Test"
    touch "$TMPDIR/.gitkeep"
    git -C "$TMPDIR" add . && git -C "$TMPDIR" commit -q -m "init"
}

cleanup_tmpdir() {
    rm -rf "$TMPDIR"
}

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  ✓ $label"
        PASS=$((PASS + 1))
    else
        echo "  ✗ $label (expected='$expected', got='$actual')"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -qF -- "$needle"; then
        echo "  ✓ $label"
        PASS=$((PASS + 1))
    else
        echo "  ✗ $label (expected to contain '$needle')"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_empty() {
    local label="$1" value="$2"
    if [[ -n "$value" ]]; then
        echo "  ✓ $label"
        PASS=$((PASS + 1))
    else
        echo "  ✗ $label (empty)"
        FAIL=$((FAIL + 1))
    fi
}

# Create a FEATURES.md with shipped features
create_features_file() {
    local dir="$1"
    shift
    local content="# Features\n"
    for fid in "$@"; do
        content+="
## ${fid}: Test Feature

**Status**: shipped
**Category**: Test
"
    done
    echo -e "$content" > "$dir/.agentic/spec/FEATURES.md"
    git -C "$dir" add . && git -C "$dir" commit -q -m "add features"
}

# Create an AC file
create_ac_file() {
    local dir="$1" fid="$2" content="$3"
    echo "$content" > "$dir/.agentic/spec/acceptance/${fid}.md"
    git -C "$dir" add . && git -C "$dir" commit -q -m "add AC for $fid"
}

run_metrics() {
    cd "$TMPDIR"
    bash "$TMPDIR/.agentic/lib/tools/spec-metrics.sh" "$@" 2>/dev/null
}

# --- Tests ---

echo "=== Test: Discovery counting ==="
setup_tmpdir
create_features_file "$TMPDIR" "F-0001" "F-0002"
create_ac_file "$TMPDIR" "F-0001" "# F-0001
## Acceptance Criteria
- [ ] **AC-001**: Basic feature
- [ ] **AC-002**: [Discovered] New requirement found
- [ ] **AC-003**: [Discovered] Another discovery"
create_ac_file "$TMPDIR" "F-0002" "# F-0002
## Acceptance Criteria
- [ ] **AC-001**: No discoveries here"

out=$(run_metrics --discovery)
assert_contains "Shows F-0001 with discoveries" "F-0001: 2 discovered" "$out"
assert_contains "Summary shows 1/2 features" "1/2 features have discoveries" "$out"
assert_contains "Summary shows 2 total" "2 total markers" "$out"

# Single feature mode
out=$(run_metrics --discovery F-0001)
assert_contains "Single feature shows discoveries" "F-0001: 2 discovered" "$out"
cleanup_tmpdir

echo ""
echo "=== Test: No discoveries ==="
setup_tmpdir
create_features_file "$TMPDIR" "F-0010"
create_ac_file "$TMPDIR" "F-0010" "# F-0010
## Acceptance Criteria
- [ ] **AC-001**: Plain AC"

out=$(run_metrics --discovery)
assert_contains "Summary shows 0 features with discoveries" "0/1 features have discoveries" "$out"
cleanup_tmpdir

echo ""
echo "=== Test: Churn analysis ==="
setup_tmpdir
create_features_file "$TMPDIR" "F-0020"
create_ac_file "$TMPDIR" "F-0020" "# F-0020
## Acceptance Criteria
- [ ] **AC-001**: Initial"

# Add more commits to create churn
for i in $(seq 2 5); do
    echo "# Update $i" >> "$TMPDIR/.agentic/spec/acceptance/F-0020.md"
    git -C "$TMPDIR" add . && git -C "$TMPDIR" commit -q -m "update AC $i"
done

out=$(run_metrics --churn)
# 1 initial + 4 updates = 5 commits → medium churn
assert_contains "Shows medium churn" "medium" "$out"
cleanup_tmpdir

echo ""
echo "=== Test: Churn buckets ==="
setup_tmpdir
create_features_file "$TMPDIR" "F-0030"
create_ac_file "$TMPDIR" "F-0030" "# F-0030
## Acceptance Criteria
- [ ] **AC-001**: Initial"

# Add 11 more commits → high churn (12 total)
for i in $(seq 2 12); do
    echo "# Update $i" >> "$TMPDIR/.agentic/spec/acceptance/F-0030.md"
    git -C "$TMPDIR" add . && git -C "$TMPDIR" commit -q -m "churn $i"
done

out=$(run_metrics --churn)
assert_contains "Shows high churn" "high churn" "$out"
cleanup_tmpdir

echo ""
echo "=== Test: JSON output ==="
setup_tmpdir
create_features_file "$TMPDIR" "F-0040"
create_ac_file "$TMPDIR" "F-0040" "# F-0040
## Acceptance Criteria
- [ ] **AC-001**: [Discovered] Found during impl
- [x] **AC-002**: Done"

out=$(run_metrics --json)
# Validate JSON
if echo "$out" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
    assert_eq "JSON is valid" "true" "true"
else
    assert_eq "JSON is valid" "true" "false"
fi
assert_contains "JSON has feature ID" "F-0040" "$out"
assert_contains "JSON has discoveries field" '"discoveries": 1' "$out"
assert_contains "JSON has churn_level field" '"churn_level":' "$out"
assert_contains "JSON has ac_count field" '"ac_count": 2' "$out"
cleanup_tmpdir

echo ""
echo "=== Test: Summary line ==="
setup_tmpdir
create_features_file "$TMPDIR" "F-0050" "F-0051"
create_ac_file "$TMPDIR" "F-0050" "# F-0050
- [ ] **AC-001**: [Discovered] Something"
create_ac_file "$TMPDIR" "F-0051" "# F-0051
- [ ] **AC-001**: Normal"

out=$(run_metrics --summary-line)
assert_contains "Summary has spec count" "2 specs tracked" "$out"
assert_contains "Summary mentions discovered" "1 discovered" "$out"
cleanup_tmpdir

echo ""
echo "=== Test: Summary line — no anomalies ==="
setup_tmpdir
create_features_file "$TMPDIR" "F-0060"
create_ac_file "$TMPDIR" "F-0060" "# F-0060
- [ ] **AC-001**: Normal"

out=$(run_metrics --summary-line)
assert_contains "Summary says no anomalies" "no anomalies" "$out"
cleanup_tmpdir

echo ""
echo "=== Test: No features — empty output ==="
setup_tmpdir
# No FEATURES.md at all
out=$(run_metrics --summary-line)
assert_eq "Empty summary for no features" "" "$out"
cleanup_tmpdir

echo ""
echo "=== Test: Help flag ==="
out=$(bash "$SPEC_METRICS" --help 2>&1)
assert_contains "Help shows usage" "Usage:" "$out"
assert_contains "Help shows --discovery" "--discovery" "$out"
assert_contains "Help shows --json" "--json" "$out"

echo ""
echo "=== Test: Exit code is always 0 ==="
setup_tmpdir
bash "$TMPDIR/.agentic/lib/tools/spec-metrics.sh" --discovery >/dev/null 2>&1
assert_eq "Exit code 0 for discovery" "0" "$?"
bash "$TMPDIR/.agentic/lib/tools/spec-metrics.sh" --churn >/dev/null 2>&1
assert_eq "Exit code 0 for churn" "0" "$?"
bash "$TMPDIR/.agentic/lib/tools/spec-metrics.sh" --json >/dev/null 2>&1
assert_eq "Exit code 0 for json" "0" "$?"
bash "$TMPDIR/.agentic/lib/tools/spec-metrics.sh" --summary-line >/dev/null 2>&1
assert_eq "Exit code 0 for summary-line" "0" "$?"
cleanup_tmpdir

# --- Summary ---
echo ""
echo "==============================="
echo "Results: $PASS passed, $FAIL failed"
echo "==============================="

[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
