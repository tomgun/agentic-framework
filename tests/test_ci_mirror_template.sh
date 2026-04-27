#!/usr/bin/env bash
# tests/test_ci_mirror_template.sh — R-006 GitHub Actions template integrity.
#
# Verifies the template ships at the canonical path, is valid YAML, references
# both Tier 0 gates with --ci-mode, and the docs/CI_MIRROR.md cross-link works.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TPL="$ROOT_DIR/.agentic/lib/init/templates/.github/workflows/agentic-gate.yml"
DOC="$ROOT_DIR/docs/CI_MIRROR.md"

PASS=0
FAIL=0

_pass() { echo "ok    $1"; PASS=$((PASS+1)); }
_fail() { echo "FAIL  $1: $2"; FAIL=$((FAIL+1)); }

# ---------------------------------------------------------------------------
# 1. Template exists
# ---------------------------------------------------------------------------
if [ -f "$TPL" ]; then
    _pass "template exists at canonical path"
else
    _fail "template missing" "$TPL"
fi

# ---------------------------------------------------------------------------
# 2. YAML parses
# ---------------------------------------------------------------------------
if python3 -c "
import sys
try:
    import yaml
except Exception:
    sys.exit(0)  # PyYAML missing — skip this assertion in this env.
with open('$TPL', 'r') as fh:
    yaml.safe_load(fh)
" 2>/dev/null; then
    _pass "template is valid YAML (or PyYAML unavailable; skipped)"
else
    _fail "template is not valid YAML" "PyYAML failed to parse"
fi

# ---------------------------------------------------------------------------
# 3. Both gates referenced with --ci-mode (AC-2)
# ---------------------------------------------------------------------------
if grep -q "precommit_gate.py --ci-mode" "$TPL"; then
    _pass "template invokes precommit_gate with --ci-mode"
else
    _fail "template missing precommit_gate --ci-mode" "AC-2"
fi

if grep -q "prepush_gate.py --ci-mode" "$TPL"; then
    _pass "template invokes prepush_gate with --ci-mode"
else
    _fail "template missing prepush_gate --ci-mode" "AC-2"
fi

# ---------------------------------------------------------------------------
# 4. Triggers on push to main AND pull_request to main (AC-1)
# ---------------------------------------------------------------------------
if grep -A2 "^on:" "$TPL" | grep -q "push:"; then
    _pass "template triggers on push"
else
    _fail "template missing push trigger" "AC-1"
fi

if grep -q "pull_request:" "$TPL"; then
    _pass "template triggers on pull_request"
else
    _fail "template missing pull_request trigger" "AC-1"
fi

# ---------------------------------------------------------------------------
# 5. Uploads artifacts (AC-3)
# ---------------------------------------------------------------------------
if grep -q "actions/upload-artifact" "$TPL"; then
    _pass "template uploads workflow artifacts"
else
    _fail "template missing upload-artifact step" "AC-3"
fi

if grep -q "verification.json" "$TPL"; then
    _pass "template includes verification.json in artifacts"
else
    _fail "template doesn't reference verification.json" "AC-3"
fi

# ---------------------------------------------------------------------------
# 6. PR-comment step exists, success-silent failure-detail (AC-4)
# ---------------------------------------------------------------------------
if grep -q "actions/github-script" "$TPL"; then
    _pass "template uses github-script for PR comment"
else
    _fail "template missing github-script PR comment step" "AC-4"
fi

if grep -q "exit_code != '0'" "$TPL"; then
    _pass "template comments only when a gate failed (success-silent)"
else
    _fail "template doesn't gate the comment on failure" "AC-4"
fi

# ---------------------------------------------------------------------------
# 7. Concurrency cancel-in-progress (CI ergonomics)
# ---------------------------------------------------------------------------
if grep -q "cancel-in-progress: true" "$TPL"; then
    _pass "template cancels older runs on the same ref"
else
    _fail "template missing concurrency.cancel-in-progress" "CI ergonomics"
fi

# ---------------------------------------------------------------------------
# 8. Docs file exists and cross-links template (AC-5)
# ---------------------------------------------------------------------------
if [ -f "$DOC" ]; then
    _pass "docs/CI_MIRROR.md exists"
else
    _fail "docs/CI_MIRROR.md missing" "AC-5"
fi

if grep -q "agentic-gate.yml" "$DOC" 2>/dev/null; then
    _pass "docs link to template by name"
else
    _fail "docs don't reference the template filename" "AC-5"
fi

if grep -q "optional" "$DOC" 2>/dev/null; then
    _pass "docs frame the mirror as optional (AC-5)"
else
    _fail "docs don't describe mirror as optional" "AC-5"
fi

# ---------------------------------------------------------------------------
# 9. cmd_init mentions the CI mirror (init.sh integration, AC-modify)
# ---------------------------------------------------------------------------
INIT_SH="$ROOT_DIR/.agentic/lib/tools/commands/operations.sh"
if grep -q "agentic-gate.yml" "$INIT_SH"; then
    _pass "cmd_init surfaces the CI mirror template"
else
    _fail "cmd_init doesn't mention agentic-gate.yml" "init.sh integration"
fi

# ---------------------------------------------------------------------------
echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" = "0" ]
