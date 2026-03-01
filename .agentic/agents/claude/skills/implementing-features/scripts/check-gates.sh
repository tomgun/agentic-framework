#!/usr/bin/env bash
# check-gates.sh: Verify pre-implementation gates before coding
# Delegates to framework tools — this is a thin wrapper.
set -euo pipefail

FEATURE_ID="${1:-}"

if [[ -z "$FEATURE_ID" ]]; then
    echo "Usage: check-gates.sh <F-XXXX>"
    echo "Checks: acceptance criteria exist, scope is small, WIP not active"
    exit 1
fi

ERRORS=0

# Gate 1: Acceptance criteria
if [[ -f "spec/acceptance/${FEATURE_ID}.md" ]]; then
    echo "✓ Acceptance criteria found: spec/acceptance/${FEATURE_ID}.md"
else
    echo "✗ No acceptance criteria at spec/acceptance/${FEATURE_ID}.md"
    echo "  Create criteria FIRST: use .agentic/spec/acceptance.template.md"
    ERRORS=$((ERRORS + 1))
fi

# Gate 2: WIP check
if bash .agentic/tools/wip.sh check 2>/dev/null; then
    echo "✓ No conflicting WIP active"
else
    echo "✗ WIP already active — complete or abandon existing work first"
    ERRORS=$((ERRORS + 1))
fi

# Gate 3: Feature in FEATURES.md
if grep -q "## ${FEATURE_ID}:" spec/FEATURES.md 2>/dev/null || \
   grep -q "## ${FEATURE_ID} " spec/FEATURES.md 2>/dev/null; then
    echo "✓ Feature tracked in spec/FEATURES.md"
else
    echo "⚠ Feature ${FEATURE_ID} not found in spec/FEATURES.md (add it)"
fi

# Gate 4: Approved plan required (if plan_review_enabled in STACK.md)
PLAN_REVIEW=$(grep "plan_review_enabled:" STACK.md 2>/dev/null | head -1 | awk '{print $NF}' || true)
if [[ "$PLAN_REVIEW" == "yes" ]]; then
    PLAN_FILE=$(find .agentic-journal/plans/ -name "*${FEATURE_ID}*plan*.md" -print -quit 2>/dev/null)
    if [[ -n "$PLAN_FILE" ]] && grep -q "^.*Status.*APPROVED" "$PLAN_FILE"; then
        echo "✓ Approved plan exists: $PLAN_FILE"
    else
        echo "✗ plan_review_enabled but no approved plan for $FEATURE_ID"
        echo "  Run: ag plan $FEATURE_ID"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "✓ Plan review not required (plan_review_enabled != yes)"
fi

if [[ $ERRORS -gt 0 ]]; then
    echo ""
    echo "✗ ${ERRORS} gate(s) failed. Fix before implementing."
    exit 1
else
    echo ""
    echo "✓ All gates passed. Ready to implement."
fi
