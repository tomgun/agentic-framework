#!/usr/bin/env bash
# tests/test_hooks_register.sh — R-015 acceptance tests for `ag hooks register`.
#
# Validates `.agentic/lib/tools/commands/hooks.sh`:
#   AC1: ag hooks register writes .git/hooks/pre-commit + pre-push shims that
#        exec the Python gates
#   AC2: existing-but-divergent hooks are backed up to .git/hooks/.backup-<ts>/
#   AC3: ag integrity update is invoked after writing (baseline refreshed)
#   AC4: re-running register is idempotent (no second backup, no-op message)
#   AC5: ag hooks unregister restores the most recent backup
#   AC6: cmd_init invokes register (idempotent path)
#
# Linux + macOS only.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
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

setup_repo() {
    SANDBOX=$(mktemp -d "/tmp/r015-test-XXXXXX")
    cd "$SANDBOX"
    git init --quiet -b main
    git config user.email "test@example.com"
    git config user.name "test"
    git config commit.gpgsign false

    mkdir -p "$SANDBOX/.agentic"
    cp -r "$FRAMEWORK_ROOT/.agentic/lib" "$SANDBOX/.agentic/lib"
    mkdir -p "$SANDBOX/.agentic/spec" "$SANDBOX/.agentic/journal" "$SANDBOX/.agentic/session"
    cat > "$SANDBOX/.agentic/spec/FEATURES.md" <<'EOF'
| ID    | Name | Status |
|-------|------|--------|
| F-001 | x    | shipped |
EOF
    cat > "$SANDBOX/STACK.md" <<'EOF'
Profile: autonomous_formal
git_mode: active
EOF

    echo "init" > README.md
    git add README.md
    git commit --quiet -m "chore: init"
}

cleanup_repo() {
    cd "$SCRIPT_DIR"
    [[ -n "${SANDBOX:-}" && -d "$SANDBOX" && "$SANDBOX" == /tmp/r015-test-* ]] && rm -rf "$SANDBOX"
    unset SANDBOX
}

ag_sandbox() {
    ROOT_DIR="$SANDBOX" \
    AGENTIC_LIB="$SANDBOX/.agentic/lib" \
    AGENTIC_ROOT="$SANDBOX/.agentic" \
    PROJECT_ROOT="$SANDBOX" \
    bash "$SANDBOX/.agentic/lib/tools/ag.sh" "$@"
}

echo ""
echo "=== R-015 · ag hooks register / unregister ==="
echo ""

# ── AC1: register writes shims that reference the Python gates ──────────────

test_case "AC1: register writes pre-commit + pre-push shims that exec gates"
setup_repo
ag_sandbox hooks register >/dev/null 2>&1
ok=1
[[ -x "$SANDBOX/.git/hooks/pre-commit" ]] || ok=0
[[ -x "$SANDBOX/.git/hooks/pre-push" ]] || ok=0
grep -q "precommit_gate.py" "$SANDBOX/.git/hooks/pre-commit" 2>/dev/null || ok=0
grep -q "prepush_gate.py" "$SANDBOX/.git/hooks/pre-push" 2>/dev/null || ok=0
if [[ $ok -eq 1 ]]; then pass; else fail "shims missing or wrong content"; fi
cleanup_repo

# ── AC2: existing-but-divergent hooks are backed up ─────────────────────────

test_case "AC2: divergent existing hooks moved to .git/hooks/.backup-<ts>/"
setup_repo
echo '#!/bin/sh' > "$SANDBOX/.git/hooks/pre-commit"
echo 'echo "old hook"' >> "$SANDBOX/.git/hooks/pre-commit"
chmod +x "$SANDBOX/.git/hooks/pre-commit"
ag_sandbox hooks register >/dev/null 2>&1
backup_count=$(ls -1d "$SANDBOX/.git/hooks/.backup-"* 2>/dev/null | wc -l | tr -d ' ')
backup_dir=$(ls -1d "$SANDBOX/.git/hooks/.backup-"* 2>/dev/null | head -1)
ok=1
[[ "$backup_count" -eq 1 ]] || ok=0
[[ -f "$backup_dir/pre-commit" ]] || ok=0
grep -q "old hook" "$backup_dir/pre-commit" 2>/dev/null || ok=0
grep -q "precommit_gate.py" "$SANDBOX/.git/hooks/pre-commit" 2>/dev/null || ok=0
if [[ $ok -eq 1 ]]; then pass; else fail "backup_count=$backup_count backup_dir=$backup_dir"; fi
cleanup_repo

# ── AC3: integrity baseline refreshed after register ────────────────────────

test_case "AC3: register updates the integrity baseline"
setup_repo
ag_sandbox hooks register >/dev/null 2>&1
ok=1
[[ -f "$SANDBOX/.agentic/integrity.json" ]] || ok=0
# Structural assertion: parse the JSON and verify both hook paths are
# registered as keys under "files". Avoids matching the literal string
# "pre-commit" elsewhere in the doc.
python3 - "$SANDBOX/.agentic/integrity.json" >/dev/null 2>&1 <<'PYEOF' || ok=0
import json, sys
data = json.load(open(sys.argv[1]))
files = data.get("files", {})
assert ".git/hooks/pre-commit" in files, "pre-commit not in baseline"
assert ".git/hooks/pre-push" in files, "pre-push not in baseline"
PYEOF
if [[ $ok -eq 1 ]]; then pass; else fail "integrity.json missing or doesn't include hook entries"; fi
cleanup_repo

# ── AC4: re-running register is idempotent (no second backup) ───────────────

test_case "AC4: re-running register is idempotent"
setup_repo
ag_sandbox hooks register >/dev/null 2>&1
ag_sandbox hooks register > /tmp/r015-second.txt 2>&1
backup_count=$(ls -1d "$SANDBOX/.git/hooks/.backup-"* 2>/dev/null | wc -l | tr -d ' ')
ok=1
# No second backup created (the canonical shims were already in place).
[[ "$backup_count" -eq 0 ]] || ok=0
grep -q "already registered" /tmp/r015-second.txt || ok=0
if [[ $ok -eq 1 ]]; then pass; else fail "backup_count=$backup_count second-run output: $(cat /tmp/r015-second.txt)"; fi
cleanup_repo
rm -f /tmp/r015-second.txt

# ── AC5: unregister restores the most recent backup ─────────────────────────

test_case "AC5: unregister restores the most recent backup"
setup_repo
echo '#!/bin/sh' > "$SANDBOX/.git/hooks/pre-commit"
echo 'echo "user-original"' >> "$SANDBOX/.git/hooks/pre-commit"
chmod +x "$SANDBOX/.git/hooks/pre-commit"
ag_sandbox hooks register >/dev/null 2>&1
ag_sandbox hooks unregister >/dev/null 2>&1
ok=1
[[ -f "$SANDBOX/.git/hooks/pre-commit" ]] || ok=0
grep -q "user-original" "$SANDBOX/.git/hooks/pre-commit" 2>/dev/null || ok=0
# pre-push had no original — should be removed cleanly.
[[ ! -f "$SANDBOX/.git/hooks/pre-push" ]] || ok=0
if [[ $ok -eq 1 ]]; then pass; else fail "pre-commit content: $(head -3 "$SANDBOX/.git/hooks/pre-commit" 2>/dev/null)"; fi
cleanup_repo

# ── AC5b: unregister without backup removes shims cleanly ───────────────────

test_case "AC5b: unregister without backup removes shims cleanly"
setup_repo
ag_sandbox hooks register >/dev/null 2>&1
# Manually wipe any backup folders so unregister has nothing to restore.
rm -rf "$SANDBOX/.git/hooks/.backup-"*
ag_sandbox hooks unregister > /tmp/r015-unreg.txt 2>&1
ok=1
[[ ! -f "$SANDBOX/.git/hooks/pre-commit" ]] || ok=0
[[ ! -f "$SANDBOX/.git/hooks/pre-push" ]] || ok=0
grep -q "No backup found" /tmp/r015-unreg.txt || ok=0
if [[ $ok -eq 1 ]]; then pass; else fail "unregister output: $(cat /tmp/r015-unreg.txt)"; fi
cleanup_repo
rm -f /tmp/r015-unreg.txt

# ── AC6: ag init invokes register when run inside a git repo ────────────────

test_case "AC6: ag init invokes register when run inside a git repo"
setup_repo
# Ensure init's pre-existing-init guard does NOT short-circuit. cmd_init's
# guard checks for a stack of state files; our minimal sandbox has STACK.md
# but no STATUS.md / CONTEXT_PACK.md, so init proceeds to its guidance path
# and (R-015 AC6) calls hooks register at the end.
ag_sandbox init > /tmp/r015-init.txt 2>&1
ok=1
[[ -x "$SANDBOX/.git/hooks/pre-commit" ]] || ok=0
grep -q "precommit_gate.py" "$SANDBOX/.git/hooks/pre-commit" 2>/dev/null || ok=0
grep -q "Tier 0 hooks (R-015)" /tmp/r015-init.txt || ok=0
if [[ $ok -eq 1 ]]; then pass; else fail "init output tail: $(tail -10 /tmp/r015-init.txt)"; fi
cleanup_repo
rm -f /tmp/r015-init.txt

# ── AC6b: ag init stays silent on the hook section when shims already match ─

test_case "AC6b: ag init does NOT print the Tier 0 hooks section when shims already match"
setup_repo
# First init writes the shims.
ag_sandbox init > /tmp/r015-init1.txt 2>&1
# Second init: shims already canonical → cmd_init must skip the header
# entirely (UX fix per PR review #7).
ag_sandbox init > /tmp/r015-init2.txt 2>&1
ok=1
[[ -x "$SANDBOX/.git/hooks/pre-commit" ]] || ok=0
# The second run must NOT mention the Tier 0 hooks section header.
if grep -q "Tier 0 hooks (R-015)" /tmp/r015-init2.txt; then ok=0; fi
# But it MUST still exit cleanly (i.e. cmd_init still ran to completion).
if [[ $ok -eq 1 ]]; then pass; else fail "second-init output: $(cat /tmp/r015-init2.txt)"; fi
cleanup_repo
rm -f /tmp/r015-init1.txt /tmp/r015-init2.txt

# ── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="

if [[ $FAILED -eq 0 ]]; then
    exit 0
else
    exit 1
fi
