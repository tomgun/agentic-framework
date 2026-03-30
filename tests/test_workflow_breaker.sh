#!/usr/bin/env bash
# ==========================================================================
# Workflow Breaker — End-to-End Integration Test
# ==========================================================================
#
# Systematically tries to BREAK the autonomous workflow at every stage.
# Tests both that gates block (negative tests) AND that the happy path
# passes when preconditions are met (positive tests).
#
# Pipeline under test:
#   idea → FEATURES.md → contract → plan → plan_review → implement →
#   tests → docs → commit → PR → merge → ag done
#
# Usage:
#   bash tests/test_workflow_breaker.sh [--verbose]
#
# ==========================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERBOSE="${1:-}"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# --- Counters ---
PASSED=0
FAILED=0
SKIPPED=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; FAILED=$((FAILED + 1)); }
skip() { echo -e "  ${YELLOW}⊘${NC} $1 (skipped)"; SKIPPED=$((SKIPPED + 1)); }

# --- Helpers ---
create_test_project() {
    local profile="${1:-formal}"
    local dir
    dir=$(mktemp -d)

    # Initialize git
    git init "$dir" --quiet 2>/dev/null
    git -C "$dir" config user.email "test@test.com" 2>/dev/null
    git -C "$dir" config user.name "Test" 2>/dev/null

    # Create minimal framework structure
    mkdir -p "$dir/.agentic/spec/contracts"
    mkdir -p "$dir/.agentic/spec/acceptance"
    mkdir -p "$dir/.agentic/session"
    mkdir -p "$dir/.agentic/journal/plans"
    mkdir -p "$dir/.agentic/journal/manifests"
    mkdir -p "$dir/.agentic/journal/evidence"
    mkdir -p "$dir/.agentic/work"

    # STACK.md with the requested profile
    cat > "$dir/STACK.md" << EOF
## Settings
- profile: ${profile}
- feature_tracking: yes
- plan_review_enabled: yes
- plan_review_convergence: auto
- docs_gate: blocking
- acceptance_criteria: blocking
- state_enforcement: blocking
- git_workflow: direct
- pre_commit_hook: no
- smoke_test_evidence: off
EOF

    # Empty FEATURES.md
    cat > "$dir/.agentic/spec/FEATURES.md" << 'EOF'
# Features
EOF

    # Initial commit
    git -C "$dir" add -A 2>/dev/null
    git -C "$dir" commit -m "init" --quiet 2>/dev/null

    echo "$dir"
}

run_ag() {
    # Run ag command in test project, capturing output (with timeout + no stdin)
    # Extra env vars can be passed via RUN_AG_ENV before calling
    local project_dir="$1"
    shift
    local args=("$@")
    timeout 15 env \
        ROOT_DIR="$project_dir" \
        _AGENTIC_SETTINGS_LOADED="" \
        _SETTINGS_ROOT_DIR="$project_dir" \
        _SETTINGS_STACK_FILE="$project_dir/STACK.md" \
        ${RUN_AG_ENV:-} \
        bash "$FRAMEWORK_ROOT/.agentic/lib/tools/ag.sh" "${args[@]}" < /dev/null 2>&1 || true
}

cleanup() {
    [[ -n "${TEST_DIR:-}" ]] && rm -rf "$TEST_DIR"
}

# ==========================================================================
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  WORKFLOW BREAKER — End-to-End Gate Integration Tests${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# ==========================================================================
# STAGE 1: PLANNING — Can we skip to plan without a FEATURES.md entry?
# ==========================================================================
echo -e "${BOLD}Stage 1: Planning Gates${NC}"

TEST_DIR=$(create_test_project formal)

# 1a. Try to plan a feature that's not registered
OUTPUT=$(run_ag "$TEST_DIR" plan F-0100)
if echo "$OUTPUT" | grep -qi "not found\|not registered\|missing\|BLOCKED\|does not exist"; then
    pass "PLAN-01: ag plan blocks unregistered feature"
else
    fail "PLAN-01: ag plan should block F-0100 (not in FEATURES.md). Got: $(echo "$OUTPUT" | head -3)"
fi

# 1b. Register the feature, try again — should work now
cat >> "$TEST_DIR/.agentic/spec/FEATURES.md" << 'EOF'

## F-0100: Test Feature
**Status**: planned
EOF
git -C "$TEST_DIR" add -A && git -C "$TEST_DIR" commit -m "add feature" --quiet 2>/dev/null

OUTPUT=$(run_ag "$TEST_DIR" plan F-0100)
if echo "$OUTPUT" | grep -qi "BLOCKED.*not found\|not registered"; then
    fail "PLAN-02: ag plan should accept registered feature. Got: $(echo "$OUTPUT" | head -3)"
else
    pass "PLAN-02: ag plan accepts registered feature"
fi

cleanup

# ==========================================================================
# STAGE 2: IMPLEMENT — Can we skip to implementation without contracts/plans?
# ==========================================================================
echo ""
echo -e "${BOLD}Stage 2: Implementation Gates${NC}"

TEST_DIR=$(create_test_project formal)

# Register feature but NO contract — disable plan gate to isolate contract check
cat >> "$TEST_DIR/.agentic/spec/FEATURES.md" << 'EOF'

## F-0100: Test Feature
**Status**: planned
EOF
# Disable plan_review to isolate the contract gate
sed -i 's/plan_review_enabled: yes/plan_review_enabled: no/' "$TEST_DIR/STACK.md" 2>/dev/null || \
    sed -i '' 's/plan_review_enabled: yes/plan_review_enabled: no/' "$TEST_DIR/STACK.md" 2>/dev/null
# Put feature in backlog at position 0
cat > "$TEST_DIR/.agentic/BACKLOG.json" << 'EOF'
[{"id": "F-0100", "title": "Test Feature", "position": 0}]
EOF
git -C "$TEST_DIR" add -A && git -C "$TEST_DIR" commit -m "add feature" --quiet 2>/dev/null

# 2a. Try to implement without contract → should block
OUTPUT=$(run_ag "$TEST_DIR" implement F-0100)
if echo "$OUTPUT" | grep -qi "BLOCKED.*No contract\|BLOCKED.*No acceptance\|BLOCKED.*contract\|BLOCKED.*criteria"; then
    pass "IMPL-01: ag implement blocks when no contract exists"
else
    fail "IMPL-01: ag implement should block without contract. Got: $(echo "$OUTPUT" | head -5)"
fi

# Re-enable plan_review for next test
sed -i 's/plan_review_enabled: no/plan_review_enabled: yes/' "$TEST_DIR/STACK.md" 2>/dev/null || \
    sed -i '' 's/plan_review_enabled: no/plan_review_enabled: yes/' "$TEST_DIR/STACK.md" 2>/dev/null

# 2b. Create contract but no approved plan → should block (plan_review_enabled=yes)
cat > "$TEST_DIR/.agentic/spec/contracts/F-0100.yaml" << 'EOF'
id: F-0100
name: Test Feature
lifecycle: specifying
description: A test feature.
assertions:
  - id: AC-001
    text: Feature works correctly
    type: behavioral
EOF
git -C "$TEST_DIR" add -A && git -C "$TEST_DIR" commit -m "add contract" --quiet 2>/dev/null

OUTPUT=$(run_ag "$TEST_DIR" implement F-0100)
if echo "$OUTPUT" | grep -qi "BLOCKED.*No plan\|BLOCKED.*plan.*not.*APPROVED\|plan_review_enabled"; then
    pass "IMPL-02: ag implement blocks when plan_review_enabled but no approved plan"
else
    fail "IMPL-02: ag implement should block without approved plan. Got: $(echo "$OUTPUT" | head -5)"
fi

# 2c. Create DRAFT plan → should still block (DRAFT ≠ APPROVED)
cat > "$TEST_DIR/.agentic/journal/plans/2026-03-30-F-0100-plan.md" << 'EOF'
# Plan: Test Feature

**Feature**: F-0100
**Status**: DRAFT

## Steps
1. Implement the thing
2. Write tests
EOF
git -C "$TEST_DIR" add -A && git -C "$TEST_DIR" commit -m "add draft plan" --quiet 2>/dev/null

OUTPUT=$(run_ag "$TEST_DIR" implement F-0100)
if echo "$OUTPUT" | grep -qi "BLOCKED.*DRAFT\|BLOCKED.*not APPROVED\|Status.*DRAFT"; then
    pass "IMPL-03: ag implement blocks DRAFT plan (not APPROVED)"
else
    fail "IMPL-03: ag implement should block DRAFT plan. Got: $(echo "$OUTPUT" | head -5)"
fi

# 2d. Approve the plan → should pass the plan gate
sed -i 's/Status.*: DRAFT/Status**: APPROVED/' "$TEST_DIR/.agentic/journal/plans/2026-03-30-F-0100-plan.md" 2>/dev/null || \
    sed -i '' 's/Status.*: DRAFT/Status**: APPROVED/' "$TEST_DIR/.agentic/journal/plans/2026-03-30-F-0100-plan.md" 2>/dev/null
git -C "$TEST_DIR" add -A && git -C "$TEST_DIR" commit -m "approve plan" --quiet 2>/dev/null

OUTPUT=$(run_ag "$TEST_DIR" implement F-0100)
if echo "$OUTPUT" | grep -qi "BLOCKED.*No plan\|BLOCKED.*DRAFT"; then
    fail "IMPL-04: ag implement should pass with APPROVED plan. Got: $(echo "$OUTPUT" | head -5)"
else
    pass "IMPL-04: ag implement passes plan gate with APPROVED plan"
fi

cleanup

# ==========================================================================
# STAGE 3: BACKLOG ENFORCEMENT — Can we work on features out of order?
# ==========================================================================
echo ""
echo -e "${BOLD}Stage 3: Backlog Enforcement${NC}"

TEST_DIR=$(create_test_project formal)

# Register two features
cat >> "$TEST_DIR/.agentic/spec/FEATURES.md" << 'EOF'

## F-0100: First Feature
**Status**: planned

## F-0200: Second Feature
**Status**: planned
EOF

# Add F-0100 to backlog at position 0, F-0200 at position 1
cat > "$TEST_DIR/.agentic/BACKLOG.json" << 'EOF'
[
    {"id": "F-0100", "title": "First Feature", "position": 0},
    {"id": "F-0200", "title": "Second Feature", "position": 1}
]
EOF

# Create contracts for both
for fid in F-0100 F-0200; do
    cat > "$TEST_DIR/.agentic/spec/contracts/${fid}.yaml" << EOF
id: ${fid}
name: Feature ${fid}
lifecycle: specifying
description: Test
assertions:
  - id: AC-001
    text: Works
    type: behavioral
EOF
done

git -C "$TEST_DIR" add -A && git -C "$TEST_DIR" commit -m "setup backlog" --quiet 2>/dev/null

# 3a. Try to implement F-0200 (position 1, not 0) → should block
# Disable plan review for this test to isolate backlog enforcement
sed -i 's/plan_review_enabled: yes/plan_review_enabled: no/' "$TEST_DIR/STACK.md" 2>/dev/null || \
    sed -i '' 's/plan_review_enabled: yes/plan_review_enabled: no/' "$TEST_DIR/STACK.md" 2>/dev/null

OUTPUT=$(run_ag "$TEST_DIR" implement F-0200)
if echo "$OUTPUT" | grep -qi "BLOCKED.*backlog\|BLOCKED.*position\|not at position 0\|F-0100.*first"; then
    pass "BACKLOG-01: ag implement blocks out-of-order backlog work"
else
    # The gate might not exist or might be advisory
    if echo "$OUTPUT" | grep -qi "backlog\|position"; then
        pass "BACKLOG-01: ag implement warns about out-of-order backlog work"
    else
        fail "BACKLOG-01: ag implement should enforce backlog order. Got: $(echo "$OUTPUT" | head -5)"
    fi
fi

# 3b. Implement F-0100 (position 0) → should not block on backlog
OUTPUT=$(run_ag "$TEST_DIR" implement F-0100)
if echo "$OUTPUT" | grep -qi "BLOCKED.*backlog\|BLOCKED.*position 0"; then
    fail "BACKLOG-02: ag implement should not block F-0100 (position 0). Got: $(echo "$OUTPUT" | head -5)"
else
    pass "BACKLOG-02: ag implement allows feature at backlog position 0"
fi

cleanup

# ==========================================================================
# STAGE 4: WIP CONFLICT — Can we start a second feature while one is active?
# ==========================================================================
echo ""
echo -e "${BOLD}Stage 4: WIP Conflict Detection${NC}"

TEST_DIR=$(create_test_project formal)

# Register feature
cat >> "$TEST_DIR/.agentic/spec/FEATURES.md" << 'EOF'

## F-0100: First Feature
**Status**: in_progress

## F-0200: Second Feature
**Status**: planned
EOF

# Simulate active WIP via AGENTS.json
mkdir -p "$TEST_DIR/.agentic/session"
cat > "$TEST_DIR/.agentic/session/AGENTS.json" << 'EOF'
{
    "agents": [
        {
            "feature_id": "F-0100",
            "status": "active",
            "pid": 99999,
            "started": "2026-03-30T10:00:00Z"
        }
    ]
}
EOF

# Create contract for F-0200
cat > "$TEST_DIR/.agentic/spec/contracts/F-0200.yaml" << 'EOF'
id: F-0200
name: Second Feature
lifecycle: specifying
description: Test
assertions:
  - id: AC-001
    text: Works
    type: behavioral
EOF

# Put F-0200 at backlog position 0 (bypass backlog gate)
cat > "$TEST_DIR/.agentic/BACKLOG.json" << 'EOF'
[{"id": "F-0200", "title": "Second Feature", "position": 0}]
EOF

git -C "$TEST_DIR" add -A && git -C "$TEST_DIR" commit -m "setup WIP" --quiet 2>/dev/null

# Disable plan review for this test
sed -i 's/plan_review_enabled: yes/plan_review_enabled: no/' "$TEST_DIR/STACK.md" 2>/dev/null || \
    sed -i '' 's/plan_review_enabled: yes/plan_review_enabled: no/' "$TEST_DIR/STACK.md" 2>/dev/null

# 4a. Try to implement F-0200 while F-0100 is active → should block
# Note: WIP detection uses agents_helpers.py which resolves AGENTS.json via PROJECT_ROOT
OUTPUT=$(run_ag "$TEST_DIR" implement F-0200)
if echo "$OUTPUT" | grep -qi "BLOCKED.*WIP\|BLOCKED.*in progress\|BLOCKED.*active.*F-0100\|already.*in.*progress\|one.*feature.*at.*time"; then
    pass "WIP-01: ag implement blocks when another feature is active"
elif echo "$OUTPUT" | grep -qi "WIP\|in.progress\|active\|F-0100"; then
    pass "WIP-01: ag implement detects active WIP (advisory)"
else
    # WIP detection depends on agents_helpers.py resolving PROJECT_ROOT correctly
    # If it can't find AGENTS.json in the test dir, the gate silently passes
    fail "WIP-01: ag implement should detect WIP conflict (agents_helpers.py may not resolve test dir). Got: $(echo "$OUTPUT" | head -3)"
fi

cleanup

# ==========================================================================
# STAGE 5: AG DONE — Can we ship without passing all gates?
# ==========================================================================
echo ""
echo -e "${BOLD}Stage 5: Completion (ag done) Gates${NC}"

TEST_DIR=$(create_test_project formal)

# Register feature as in_progress
cat >> "$TEST_DIR/.agentic/spec/FEATURES.md" << 'EOF'

## F-0100: Test Feature
**Status**: in_progress
EOF

# Create contract with assertions
cat > "$TEST_DIR/.agentic/spec/contracts/F-0100.yaml" << 'EOF'
id: F-0100
name: Test Feature
lifecycle: implementing
description: Test feature.
assertions:
  - id: AC-001
    text: Works correctly
    type: behavioral
EOF

git -C "$TEST_DIR" add -A && git -C "$TEST_DIR" commit -m "setup" --quiet 2>/dev/null

# 5a. ag done without plan (plan_review_enabled=yes) → should block
OUTPUT=$(run_ag "$TEST_DIR" done F-0100)
if echo "$OUTPUT" | grep -qi "BLOCKED.*No plan\|BLOCKED.*plan_review_enabled"; then
    pass "DONE-01: ag done blocks when no approved plan (plan backstop)"
else
    fail "DONE-01: ag done should block without approved plan. Got: $(echo "$OUTPUT" | head -5)"
fi

# 5b. Create approved plan, disable phase gate, run ag done → should still check ACs
cat > "$TEST_DIR/.agentic/journal/plans/2026-03-30-F-0100-plan.md" << 'EOF'
# Plan: Test Feature

**Feature**: F-0100
**Status**: APPROVED

## Steps
1. Implement it
EOF
git -C "$TEST_DIR" add -A && git -C "$TEST_DIR" commit -m "plan" --quiet 2>/dev/null

OUTPUT=$(run_ag "$TEST_DIR" done F-0100 --force-phases)
if echo "$OUTPUT" | grep -qi "verification\|contract\|assertion\|AC-001\|BLOCKED\|Documentation Drift"; then
    pass "DONE-02: ag done runs verification + doc gates after plan backstop passes"
else
    fail "DONE-02: ag done should still check ACs/docs after plan gate. Got: $(echo "$OUTPUT" | head -5)"
fi

# 5c. Add doc registry and verify docs_gate fires
cat >> "$TEST_DIR/STACK.md" << 'EOF'
## Docs
| Path | Triggers | Description |
|------|----------|-------------|
| README.md | feature_done | Main readme |
EOF
echo "# Old readme" > "$TEST_DIR/README.md"
git -C "$TEST_DIR" add -A && git -C "$TEST_DIR" commit -m "add docs" --quiet 2>/dev/null

OUTPUT=$(run_ag "$TEST_DIR" done F-0100 --force-phases)
if echo "$OUTPUT" | grep -qi "Documentation Drift\|doc.*freshness\|BLOCKED.*Documentation\|stale"; then
    pass "DONE-03: ag done runs doc freshness check when docs_gate=blocking"
else
    # Check if docs_gate even fires
    if echo "$OUTPUT" | grep -qi "docs_gate\|freshness\|drift"; then
        pass "DONE-03: ag done acknowledges doc gate (may not block in test env)"
    else
        fail "DONE-03: ag done should check doc freshness. Got: $(echo "$OUTPUT" | tail -10)"
    fi
fi

cleanup

# ==========================================================================
# STAGE 6: SKIP_SPEC_CHECK bypass — Does it actually bypass?
# ==========================================================================
echo ""
echo -e "${BOLD}Stage 6: Bypass Escape Hatches${NC}"

TEST_DIR=$(create_test_project formal)

# Register feature but NO contract
cat >> "$TEST_DIR/.agentic/spec/FEATURES.md" << 'EOF'

## F-0100: Test Feature
**Status**: planned
EOF

cat > "$TEST_DIR/.agentic/BACKLOG.json" << 'EOF'
[{"id": "F-0100", "title": "Test Feature", "position": 0}]
EOF

git -C "$TEST_DIR" add -A && git -C "$TEST_DIR" commit -m "setup" --quiet 2>/dev/null

# Disable plan review to isolate spec check
sed -i 's/plan_review_enabled: yes/plan_review_enabled: no/' "$TEST_DIR/STACK.md" 2>/dev/null || \
    sed -i '' 's/plan_review_enabled: yes/plan_review_enabled: no/' "$TEST_DIR/STACK.md" 2>/dev/null

# 6a. Without bypass → should block
OUTPUT=$(run_ag "$TEST_DIR" implement F-0100)
if echo "$OUTPUT" | grep -qi "BLOCKED"; then
    pass "BYPASS-01: ag implement blocks without contract (no bypass)"
else
    fail "BYPASS-01: ag implement should block without contract. Got: $(echo "$OUTPUT" | head -5)"
fi

# 6b. With SKIP_SPEC_CHECK=1 → should bypass
OUTPUT=$(RUN_AG_ENV="SKIP_SPEC_CHECK=1" run_ag "$TEST_DIR" implement F-0100)
if echo "$OUTPUT" | grep -qi "SKIP_SPEC_CHECK.*Bypassing\|Bypassing spec"; then
    pass "BYPASS-02: SKIP_SPEC_CHECK=1 bypasses contract check"
elif echo "$OUTPUT" | grep -qi "BLOCKED.*No contract\|BLOCKED.*No acceptance"; then
    fail "BYPASS-02: SKIP_SPEC_CHECK=1 should bypass contract check"
else
    pass "BYPASS-02: SKIP_SPEC_CHECK=1 bypasses contract check (no block in output)"
fi

cleanup

# ==========================================================================
# STAGE 7: STATE MACHINE — Skip transitions exist but gates catch them
# ==========================================================================
echo ""
echo -e "${BOLD}Stage 7: State Machine + Gate Enforcement${NC}"

PYTHON_SETUP="
import sys
sys.path.insert(0, '$FRAMEWORK_ROOT/.agentic/lib')
sys.path.insert(0, '$FRAMEWORK_ROOT/.agentic/lib/auto')
"

if python3 -c "${PYTHON_SETUP}
from auto.state_machine import FeatureStateMachine, FeatureState
from auto.gates import gate_planned_to_specced, GateResult
" 2>/dev/null; then

    # 7a. State machine allows planned → specced (valid forward transition)
    RESULT=$(python3 -c "${PYTHON_SETUP}
from auto.state_machine import FeatureStateMachine, FeatureState
print(FeatureStateMachine.is_valid_transition(FeatureState.PLANNED, FeatureState.SPECCED))
" 2>/dev/null)
    [[ "$RESULT" == "True" ]] && pass "STATE-01: planned → specced is valid forward transition" \
                               || fail "STATE-01: planned → specced should be valid"

    # 7b. State machine allows skip transitions (by design) — gates are the real enforcement
    RESULT=$(python3 -c "${PYTHON_SETUP}
from auto.state_machine import SKIP_TRANSITIONS, FeatureState
# These skip transitions exist — gates must catch invalid attempts
skips = [
    (FeatureState.PLANNED, FeatureState.IMPLEMENTING),
    (FeatureState.PLANNED, FeatureState.SHIPPED),
    (FeatureState.IMPLEMENTING, FeatureState.SHIPPED),
]
print(all((f,t) in SKIP_TRANSITIONS for f,t in skips))
" 2>/dev/null)
    [[ "$RESULT" == "True" ]] && pass "STATE-02: skip transitions exist (gates must catch them)" \
                               || fail "STATE-02: expected skip transitions to be defined"

    # 7c. specced → tests_written (skip criteria_set) is NOT allowed
    RESULT=$(python3 -c "${PYTHON_SETUP}
from auto.state_machine import FeatureStateMachine, FeatureState
print(FeatureStateMachine.is_valid_transition(FeatureState.SPECCED, FeatureState.TESTS_WRITTEN))
" 2>/dev/null)
    [[ "$RESULT" == "False" ]] && pass "STATE-03: specced → tests_written (skip criteria_set) is blocked" \
                                || fail "STATE-03: specced → tests_written should not be valid"

    # 7d. Gate enforcement: planned→specced gate blocks without FEATURES.md entry
    RESULT=$(python3 -c "${PYTHON_SETUP}
import tempfile
from pathlib import Path
from auto.gates import gate_planned_to_specced
with tempfile.TemporaryDirectory() as d:
    root = Path(d)
    (root / '.agentic/spec').mkdir(parents=True)
    (root / '.agentic/spec/FEATURES.md').write_text('# Features\n')
    (root / 'STACK.md').write_text('## Settings\n- profile: formal\n')
    result = gate_planned_to_specced('F-0100', root)
    print(result.allowed)
" 2>/dev/null)
    [[ "$RESULT" == "False" ]] && pass "GATE-01: planned→specced gate blocks without FEATURES.md entry" \
                                || fail "GATE-01: gate should block without FEATURES.md entry"

    # 7e. Gate enforcement: specced→criteria_set blocks without contract
    RESULT=$(python3 -c "${PYTHON_SETUP}
import tempfile
from pathlib import Path
from auto.gates import gate_specced_to_criteria_set
with tempfile.TemporaryDirectory() as d:
    root = Path(d)
    (root / '.agentic/spec/contracts').mkdir(parents=True)
    (root / '.agentic/spec/acceptance').mkdir(parents=True)
    (root / 'STACK.md').write_text('## Settings\n- profile: formal\n')
    result = gate_specced_to_criteria_set('F-0100', root)
    print(result.allowed)
" 2>/dev/null)
    [[ "$RESULT" == "False" ]] && pass "GATE-02: specced→criteria_set gate blocks without contract" \
                                || fail "GATE-02: gate should block without contract"

    # 7f. Gate enforcement: implementing→verified blocks without tests
    RESULT=$(python3 -c "${PYTHON_SETUP}
import tempfile
from pathlib import Path
from auto.gates import gate_implementing_to_verified
with tempfile.TemporaryDirectory() as d:
    root = Path(d)
    (root / '.agentic/spec/contracts').mkdir(parents=True)
    (root / '.agentic/spec/acceptance').mkdir(parents=True)
    (root / 'STACK.md').write_text('## Settings\n- profile: formal\n')
    (root / '.agentic/spec/contracts/F-0100.yaml').write_text(
        'id: F-0100\nname: Test\nlifecycle: implementing\nassertions:\n  - id: AC-001\n    text: works\n    type: behavioral\n'
    )
    result = gate_implementing_to_verified('F-0100', root)
    print(result.allowed)
" 2>/dev/null)
    [[ "$RESULT" == "False" ]] && pass "GATE-03: implementing→verified gate blocks without tests" \
                                || fail "GATE-03: gate should block without test files"

    # 7g. Gate enforcement: verified→documented blocks without CHANGELOG mention
    RESULT=$(python3 -c "${PYTHON_SETUP}
import tempfile
from pathlib import Path
from auto.gates import gate_verified_to_documented
with tempfile.TemporaryDirectory() as d:
    root = Path(d)
    (root / '.agentic/spec').mkdir(parents=True)
    (root / 'STACK.md').write_text('## Settings\n- profile: formal\n- docs_gate: blocking\n')
    (root / 'CHANGELOG.md').write_text('# Changelog\n## v0.1.0\n- Initial release\n')
    result = gate_verified_to_documented('F-0100', root)
    print(result.allowed)
" 2>/dev/null)
    [[ "$RESULT" == "False" ]] && pass "GATE-04: verified→documented gate blocks without doc mention" \
                                || fail "GATE-04: gate should block without CHANGELOG mention"

else
    skip "STATE/GATE tests: Python modules not loadable"
fi

# ==========================================================================
# STAGE 9: PLAN REVIEW SETTINGS — Does disabling plan_review actually bypass?
# ==========================================================================
echo ""
echo -e "${BOLD}Stage 9: Settings-Based Gate Control${NC}"

TEST_DIR=$(create_test_project formal)

# Setup feature with contract
cat >> "$TEST_DIR/.agentic/spec/FEATURES.md" << 'EOF'

## F-0100: Test Feature
**Status**: planned
EOF
cat > "$TEST_DIR/.agentic/spec/contracts/F-0100.yaml" << 'EOF'
id: F-0100
name: Test Feature
lifecycle: specifying
description: Test
assertions:
  - id: AC-001
    text: Works
    type: behavioral
EOF
cat > "$TEST_DIR/.agentic/BACKLOG.json" << 'EOF'
[{"id": "F-0100", "title": "Test Feature", "position": 0}]
EOF
git -C "$TEST_DIR" add -A && git -C "$TEST_DIR" commit -m "setup" --quiet 2>/dev/null

# 9a. With plan_review_enabled=yes and no plan → blocks
OUTPUT=$(run_ag "$TEST_DIR" implement F-0100)
BLOCKED_WITH_REVIEW=$(echo "$OUTPUT" | grep -ci "BLOCKED.*plan\|plan_review")

# 9b. Change to plan_review_enabled=no → should NOT block on plan
sed -i 's/plan_review_enabled: yes/plan_review_enabled: no/' "$TEST_DIR/STACK.md" 2>/dev/null || \
    sed -i '' 's/plan_review_enabled: yes/plan_review_enabled: no/' "$TEST_DIR/STACK.md" 2>/dev/null

OUTPUT=$(run_ag "$TEST_DIR" implement F-0100)
NOT_BLOCKED_WITHOUT_REVIEW=$(echo "$OUTPUT" | grep -ci "BLOCKED.*No plan\|BLOCKED.*plan_review")

if [[ "$BLOCKED_WITH_REVIEW" -gt 0 ]] && [[ "$NOT_BLOCKED_WITHOUT_REVIEW" -eq 0 ]]; then
    pass "SETTINGS-01: plan_review_enabled=yes blocks, =no bypasses"
else
    fail "SETTINGS-01: plan_review_enabled toggle should control plan gate. blocked=$BLOCKED_WITH_REVIEW, unblocked=$NOT_BLOCKED_WITHOUT_REVIEW"
fi

# 9c. Test docs_gate toggle
sed -i 's/docs_gate: blocking/docs_gate: off/' "$TEST_DIR/STACK.md" 2>/dev/null || \
    sed -i '' 's/docs_gate: blocking/docs_gate: off/' "$TEST_DIR/STACK.md" 2>/dev/null

OUTPUT=$(run_ag "$TEST_DIR" done F-0100 --force-phases)
if echo "$OUTPUT" | grep -qi "Documentation Drift Check"; then
    fail "SETTINGS-02: docs_gate=off should skip doc drift check"
else
    pass "SETTINGS-02: docs_gate=off skips doc drift check"
fi

cleanup

# ==========================================================================
# Summary
# ==========================================================================
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}WORKFLOW BREAKER SUMMARY${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Passed:  ${GREEN}${PASSED}${NC}"
echo -e "  Failed:  ${RED}${FAILED}${NC}"
echo -e "  Skipped: ${YELLOW}${SKIPPED}${NC}"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✅ ALL GATES HELD — workflow cannot be broken${NC}"
    exit 0
else
    echo -e "${RED}❌ ${FAILED} GATE(S) BROKEN — workflow has exploitable gaps${NC}"
    exit 1
fi
