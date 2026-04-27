#!/usr/bin/env bash
# tests/test_merge_gate.sh — R-003 acceptance tests for the local merge gate
#
# Validates `.agentic/lib/tools/commands/merge.sh`:
#   AC1: _merge_discover_features extracts unique IDs from commit messages on
#        a branch range
#   AC2: _merge_local_gate refuses unknown branch with a clear message
#   AC3: cmd_merge dispatches numeric → PR path; non-numeric → local path
#   AC4: --skip-gate "<reason>" bypasses the gate and proceeds to git merge,
#        and emits a sanctioned skip-gate event payload
#   AC5: gate blocks (rc=2) when discovered features are not tracked in
#        FEATURES.md
#
# Linux + macOS only.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASSED=0
FAILED=0

case "$(uname -s)" in
    Linux|Darwin) ;;
    *) echo "skipping on $(uname -s)"; exit 0 ;;
esac

test_case() { echo -n "Testing: $1... "; }
pass() { echo -e "${GREEN}PASS${NC}"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC}"; [[ -n "${1:-}" ]] && echo "  $1"; FAILED=$((FAILED + 1)); }

# ── Sandbox: a minimal git repo with the framework lib copied over so we
#    can invoke `ag merge` end-to-end without polluting the real repo.

setup_repo() {
    SANDBOX=$(mktemp -d "/tmp/r003-test-XXXXXX")
    cd "$SANDBOX"
    git init --quiet -b main
    git config user.email "test@example.com"
    git config user.name "test"
    git config commit.gpgsign false

    # Mirror the framework lib so ag.sh works under the sandbox.
    mkdir -p "$SANDBOX/.agentic"
    cp -r "$FRAMEWORK_ROOT/.agentic/lib" "$SANDBOX/.agentic/lib"
    mkdir -p "$SANDBOX/.agentic/spec" "$SANDBOX/.agentic/journal" "$SANDBOX/.agentic/session"
    cat > "$SANDBOX/.agentic/spec/FEATURES.md" <<'EOF'
| ID    | Name           | Status |
|-------|----------------|--------|
| F-001 | Sample feature | shipped |
EOF
    cat > "$SANDBOX/STACK.md" <<'EOF'
Profile: autonomous_formal
git_mode: active
EOF

    # Initial commit on main.
    echo "init" > README.md
    git add README.md
    git commit --quiet -m "chore: init"
}

cleanup_repo() {
    cd "$SCRIPT_DIR"
    [[ -n "${SANDBOX:-}" && -d "$SANDBOX" && "$SANDBOX" == /tmp/r003-test-* ]] && rm -rf "$SANDBOX"
    unset SANDBOX
}

# Run ag.sh inside the sandbox repo.
ag_sandbox() {
    ROOT_DIR="$SANDBOX" \
    AGENTIC_LIB="$SANDBOX/.agentic/lib" \
    AGENTIC_ROOT="$SANDBOX/.agentic" \
    PROJECT_ROOT="$SANDBOX" \
    bash "$SANDBOX/.agentic/lib/tools/ag.sh" "$@"
}

# Source merge.sh helpers in a sub-shell context where ROOT_DIR + colors
# resolve. Used by the unit-style tests.
source_merge_helpers() {
    ROOT_DIR="$SANDBOX"
    SPEC_DIR="$SANDBOX/.agentic/spec"
    RED='' GREEN='' YELLOW='' NC='' BOLD=''
    # ids.sh defines FEATURE_ID_ERE; merge.sh consumes it.
    # shellcheck disable=SC1091
    source "$FRAMEWORK_ROOT/.agentic/lib/ids.sh"
    # shellcheck disable=SC1091
    source "$FRAMEWORK_ROOT/.agentic/lib/tools/commands/merge.sh"
}

echo ""
echo "=== R-003 · ag merge — local merge gate ==="
echo ""

# ── AC1: feature discovery from commit messages ─────────────────────────────

test_case "AC1: _merge_discover_features extracts unique IDs from commit range"
setup_repo
git checkout --quiet -b feat/F-001
echo "a" > a.txt; git add a.txt; git commit --quiet -m "feat(F-001): one"
echo "b" > b.txt; git add b.txt; git commit --quiet -m "test(F-001): two

Also touches F-002."
echo "c" > c.txt; git add c.txt; git commit --quiet -m "chore: no feature ref"
git checkout --quiet main
source_merge_helpers
features=$(_merge_discover_features feat/F-001 main | tr '\n' ' ')
if [[ "$features" == *"F-001"* && "$features" == *"F-002"* ]]; then
    pass
else
    fail "expected F-001 + F-002, got: $features"
fi
cleanup_repo

# ── AC2: unknown branch is refused ──────────────────────────────────────────

test_case "AC2: _merge_local_gate refuses an unknown branch"
setup_repo
source_merge_helpers
out=$(_merge_local_gate "definitely-not-a-branch" 2>&1); rc=$?
if [[ $rc -ne 0 ]] && echo "$out" | grep -q "Branch not found"; then
    pass
else
    fail "rc=$rc out=${out:0:120}"
fi
cleanup_repo

# ── AC3: dispatch — numeric vs branch ───────────────────────────────────────

test_case "AC3: cmd_merge dispatches numeric arg to PR-merge path"
setup_repo
# Numeric arg → PR-merge path tries to call gh; with no gh + no remote,
# gh pr merge fails fast. Either way: the local-gate banner must NOT print.
out=$(ag_sandbox merge 999999 2>&1 || true)
if ! echo "$out" | grep -q "ag merge gate"; then
    pass
else
    fail "numeric arg hit local-gate banner unexpectedly: ${out:0:160}"
fi
cleanup_repo

test_case "AC3: cmd_merge dispatches branch-name arg to local merge gate"
setup_repo
git checkout --quiet -b feat/F-001
echo "x" > x.txt; git add x.txt; git commit --quiet -m "feat(F-001): change"
git checkout --quiet main
out=$(ag_sandbox merge feat/F-001 2>&1 || true)
if echo "$out" | grep -q "ag merge gate · feat/F-001"; then
    pass
else
    fail "expected local-gate banner, got: ${out:0:200}"
fi
cleanup_repo

# ── AC5: gate blocks when feature is untracked in FEATURES.md ───────────────

test_case "AC5: gate blocks when discovered feature is untracked in FEATURES.md"
setup_repo
git checkout --quiet -b feat/F-099
echo "y" > y.txt; git add y.txt; git commit --quiet -m "feat(F-099): missing from FEATURES.md"
git checkout --quiet main
out=$(ag_sandbox merge feat/F-099 2>&1); rc=$?
if [[ $rc -eq 2 ]] && echo "$out" | grep -q "untracked in FEATURES.md"; then
    pass
else
    fail "rc=$rc; expected exit 2 + 'untracked' message; got ${out:0:200}"
fi
cleanup_repo

# ── AC4: --skip-gate "<reason>" bypasses gate and proceeds to git merge ────

test_case "AC4: --skip-gate \"<reason>\" bypasses gate and merges"
setup_repo
git checkout --quiet -b feat/F-099
echo "z" > z.txt; git add z.txt; git commit --quiet -m "feat(F-099): untracked but skipped"
git checkout --quiet main
out=$(ag_sandbox merge feat/F-099 --skip-gate "test bypass" 2>&1)
rc=$?
# Verify: rc=0, the bypass banner printed, branch was merged into main, and
# events.jsonl recorded the gate_skipped entry.
merged_into_main=0
git log --oneline main | grep -q "Merge branch 'feat/F-099'" && merged_into_main=1
events_logged=0
events_file="$SANDBOX/.agentic/journal/events.jsonl"
if [[ -f "$events_file" ]] && grep -q '"merge_local"' "$events_file" \
                          && grep -q '"test bypass"' "$events_file"; then
    events_logged=1
fi
if [[ $rc -eq 0 ]] \
    && echo "$out" | grep -q "skipped (audited)" \
    && [[ $merged_into_main -eq 1 ]] \
    && [[ $events_logged -eq 1 ]]; then
    pass
else
    fail "rc=$rc merged=$merged_into_main events_logged=$events_logged out=${out:0:200}"
fi
cleanup_repo

echo ""
echo "─────────────────────────────────────────────"
total=$((PASSED + FAILED))
if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}${PASSED}/${total} passed${NC}"
    exit 0
else
    echo -e "${RED}${FAILED}/${total} failed${NC} ($PASSED passed)"
    exit 1
fi
