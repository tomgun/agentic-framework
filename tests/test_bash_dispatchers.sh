#!/usr/bin/env bash
# tests/test_bash_dispatchers.sh — smoke tests for the Wave B bash dispatchers.
#
# The python modules behind ag watch / ag fix have rich unit coverage at
# tests/test_watch.py and tests/hooks/test_fix_mode.py. The bash dispatchers
# (commands/watch.sh, commands/fix.sh) are thin shims, but a regression in the
# shim — wrong env propagation, wrong python module path, missing breadcrumb —
# would silently break the user-facing command. This file gives them at least
# one happy-path assertion each.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AG="$ROOT_DIR/.agentic/lib/tools/ag.sh"

PASS=0
FAIL=0
_pass() { echo "ok    $1"; PASS=$((PASS+1)); }
_fail() { echo "FAIL  $1: $2"; FAIL=$((FAIL+1)); }

# ---------------------------------------------------------------------------
# Set up an isolated tmp project that has the framework lib symlinked in.
# Avoids touching the real repo's events.jsonl / session state.
# ---------------------------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.agentic/journal" "$TMP/.agentic/session" "$TMP/.agentic/spec/adr"
ln -s "$ROOT_DIR/.agentic/lib" "$TMP/.agentic/lib"
cat > "$TMP/STACK.md" <<EOF
# STACK.md
## Settings
- profile: discovery
- pre_commit_hook: no
EOF
git -C "$TMP" init -b main >/dev/null 2>&1
git -C "$TMP" -c user.email=t@t.t -c user.name=t add -A >/dev/null 2>&1
git -C "$TMP" -c user.email=t@t.t -c user.name=t commit -m initial >/dev/null 2>&1

# ---------------------------------------------------------------------------
# 1. ag watch dispatches to python3 -m watch with --journal-dir set
# ---------------------------------------------------------------------------
# Seed two events.jsonl entries.
EVENTS="$TMP/.agentic/journal/events.jsonl"
cat > "$EVENTS" <<JSON
{"ts":"2026-04-27T10:00:00.000Z","session_id":"s","type":"commit","feature":"F-008","actor":"harness","payload":{"sha":"deadbeef"}}
{"ts":"2026-04-27T10:00:01.000Z","session_id":"s","type":"test_run","feature":"F-009","actor":"harness","payload":{}}
JSON

out=$(cd "$TMP" && ROOT_DIR="$TMP" bash "$AG" watch --once --no-color --from-start 2>&1)
if echo "$out" | grep -q "commit" && echo "$out" | grep -q "test_run"; then
    _pass "ag watch streams events.jsonl through to python module"
else
    _fail "ag watch didn't render expected events" "got: $(echo "$out" | head -3 | tr '\n' '|')"
fi

# Filter passthrough: only commit events should match.
out=$(cd "$TMP" && ROOT_DIR="$TMP" bash "$AG" watch --once --no-color --from-start --filter type=commit 2>&1)
if echo "$out" | grep -q "commit" && ! echo "$out" | grep -q "test_run"; then
    _pass "ag watch passes --filter through to the python module"
else
    _fail "filter not honored" "$out"
fi

# Bad filter: argparse should bubble exit 2 back through bash.
set +e
cd "$TMP" && ROOT_DIR="$TMP" bash "$AG" watch --filter no-equals --once 2>&1 >/dev/null
rc=$?
set -e
if [ "$rc" = "2" ]; then
    _pass "ag watch propagates python argparse exit code on bad input"
else
    _fail "expected rc=2 from bad filter, got rc=$rc" ""
fi

# ---------------------------------------------------------------------------
# 2. ag fix sets AGENT_FIX_MODE + AGENT_FIX_REASON, drops breadcrumb, commits
# ---------------------------------------------------------------------------
# Stage a small change.
echo "x = 1" > "$TMP/foo.py"
git -C "$TMP" -c user.email=t@t.t -c user.name=t add foo.py >/dev/null 2>&1

# `ag fix` should set env vars, drop the breadcrumb, and run git commit.
# Using pre_commit_hook: no in STACK.md so the actual gate is skipped.
# git author identity comes from env vars (extra_args goes to `git commit`,
# not `git -c …`).
out=$(cd "$TMP" && ROOT_DIR="$TMP" \
    GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t.t \
    GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t.t \
    bash "$AG" fix "smoke test reason" \
    2>&1) || true

if [ -f "$TMP/.agentic/session/.gate-invoked-via-ag" ]; then
    _pass "ag fix drops the .gate-invoked-via-ag breadcrumb"
else
    _fail "ag fix didn't drop breadcrumb" "$out"
fi

# The commit message should carry [hotfix] in the footer.
last_msg=$(git -C "$TMP" log -1 --format=%B 2>/dev/null || echo "")
if echo "$last_msg" | grep -q "\[hotfix\]" && echo "$last_msg" | grep -q "smoke test reason"; then
    _pass "ag fix commits with [hotfix] footer + reason in subject"
else
    _fail "commit message wrong" "got: $last_msg"
fi

# ---------------------------------------------------------------------------
# 3. ag fix --help renders without invoking git
# ---------------------------------------------------------------------------
help_out=$(ROOT_DIR="$TMP" bash "$AG" fix --help 2>&1)
if echo "$help_out" | grep -q "hotfix mode commit"; then
    _pass "ag fix --help renders usage"
else
    _fail "ag fix --help missing usage text" "$help_out"
fi

# ---------------------------------------------------------------------------
# 4. ag fix with no args prints help + exits cleanly (doesn't try to commit)
# ---------------------------------------------------------------------------
no_arg_out=$(ROOT_DIR="$TMP" bash "$AG" fix 2>&1)
if echo "$no_arg_out" | grep -q "hotfix mode commit"; then
    _pass "ag fix with no args prints help (no commit attempt)"
else
    _fail "ag fix with no args didn't render help" "$no_arg_out"
fi

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" = "0" ]
