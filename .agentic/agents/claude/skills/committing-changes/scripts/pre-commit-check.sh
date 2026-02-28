#!/usr/bin/env bash
# pre-commit-check.sh: Verify pre-commit gates before committing
# Delegates to framework tools — this is a thin wrapper.
set -euo pipefail

ERRORS=0
WARNINGS=0

# Check 1: WIP must not be active
if [[ -f ".agentic-state/WIP.md" ]]; then
    echo "✗ WIP still active — complete work first: bash .agentic/tools/wip.sh complete"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ No active WIP"
fi

# Check 2: Branch check
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
    echo "⚠ On $BRANCH — consider creating a feature branch for PR workflow"
    WARNINGS=$((WARNINGS + 1))
else
    echo "✓ On feature branch: $BRANCH"
fi

# Check 3: Uncommitted changes exist
if git diff --quiet && git diff --cached --quiet; then
    echo "⚠ No changes to commit"
    WARNINGS=$((WARNINGS + 1))
else
    CHANGED=$(git diff --stat --cached 2>/dev/null | tail -1)
    UNSTAGED=$(git diff --stat 2>/dev/null | tail -1)
    echo "✓ Changes detected"
    [[ -n "$CHANGED" ]] && echo "  Staged: $CHANGED"
    [[ -n "$UNSTAGED" ]] && echo "  Unstaged: $UNSTAGED"
fi

# Check 4: No secrets
if git diff --cached --name-only 2>/dev/null | grep -qiE '\.env$|credentials|secret|\.key$'; then
    echo "✗ Potential secrets in staged files — review carefully"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ No obvious secrets in staged files"
fi

echo ""
if [[ $ERRORS -gt 0 ]]; then
    echo "✗ ${ERRORS} check(s) failed. Fix before committing."
    exit 1
else
    echo "✓ Pre-commit checks passed (${WARNINGS} warning(s))."
    echo "  Show changes to human for approval before committing."
fi
