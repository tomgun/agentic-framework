#!/usr/bin/env bash
# tests/test_onboard.sh — R-011 ag onboard playbook generator.
#
# Exercises:
#   1. ag onboard creates .agentic/ONBOARDING.md from the template
#   2. Refuses to overwrite without --force
#   3. --force regenerates
#   4. Substitutes STACK.md, FEATURES.md, ADR, journal content
#   5. The 5-minute walkthrough section is present
#   6. Pre-commit gate references ONBOARDING.md when the file exists

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AG="$ROOT_DIR/.agentic/lib/tools/ag.sh"

PASS=0
FAIL=0

_pass() { echo "ok    $1"; PASS=$((PASS+1)); }
_fail() { echo "FAIL  $1: $2"; FAIL=$((FAIL+1)); }

# -- Set up a fresh tmp project that pretends to have STACK/FEATURES/ADR -----
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.agentic/spec/adr"
mkdir -p "$TMP/.agentic/spec"
mkdir -p "$TMP/.agentic/journal"

cat > "$TMP/STACK.md" <<EOF
# STACK.md - tmp project

## Settings
- profile: discovery
- language: python
- framework: fastapi

## Stack
- Python 3.11
- PostgreSQL 14
- Redis 7
EOF

cat > "$TMP/.agentic/spec/FEATURES.md" <<EOF
# Features

| ID | Title | Status |
|---|---|---|
| F-001 | First widget | shipped |
| F-002 | Second widget | planned |
| F-003 | Third widget | in_progress |
EOF

cat > "$TMP/.agentic/spec/adr/ADR-001-architecture.md" <<EOF
# ADR-001: Multi-component architecture

We use modular monolith.
EOF

cat > "$TMP/.agentic/journal/JOURNAL.md" <<EOF
# Journal

## 2026-04-26 — Sprint kickoff

Set up Wave A.

## 2026-04-27 — Wave A merged

Closed Tier 0 honest-limits.
EOF

cat > "$TMP/.agentic/STATUS.md" <<EOF
# STATUS.md

## Current focus
- Wave B: ag watch + quota report + GHA template + ag fix + ag onboard
EOF

# Symlink the framework into the tmp dir so ag.sh can find templates + scripts.
ln -s "$ROOT_DIR/.agentic/lib" "$TMP/.agentic/lib"

# -- 1. ag onboard creates ONBOARDING.md --------------------------------------
output=$(cd "$TMP" && ROOT_DIR="$TMP" bash "$AG" onboard 2>&1)
if [ -f "$TMP/.agentic/ONBOARDING.md" ]; then
    _pass "ag onboard creates .agentic/ONBOARDING.md"
else
    _fail "ag onboard didn't create the file" "$output"
fi

# -- 2. Refuses to overwrite without --force ---------------------------------
out=$(cd "$TMP" && ROOT_DIR="$TMP" bash "$AG" onboard 2>&1)
if echo "$out" | grep -q "already exists"; then
    _pass "ag onboard refuses to overwrite without --force"
else
    _fail "ag onboard didn't refuse re-run" "$out"
fi

# -- 3. --force regenerates --------------------------------------------------
sleep 1  # ensure mtime differs
mtime_before=$(stat -c %Y "$TMP/.agentic/ONBOARDING.md" 2>/dev/null || stat -f %m "$TMP/.agentic/ONBOARDING.md")
cd "$TMP" && ROOT_DIR="$TMP" bash "$AG" onboard --force >/dev/null 2>&1
mtime_after=$(stat -c %Y "$TMP/.agentic/ONBOARDING.md" 2>/dev/null || stat -f %m "$TMP/.agentic/ONBOARDING.md")
if [ "$mtime_after" -gt "$mtime_before" ]; then
    _pass "ag onboard --force regenerates the file"
else
    _fail "--force did not refresh mtime" "before=$mtime_before after=$mtime_after"
fi

# -- 4. Substitutions populated correctly ------------------------------------
ONBOARDING="$TMP/.agentic/ONBOARDING.md"
if grep -q "Python 3.11" "$ONBOARDING"; then
    _pass "tech stack from STACK.md is substituted"
else
    _fail "tech stack not substituted" "expected 'Python 3.11'"
fi

if grep -q "F-002" "$ONBOARDING"; then
    _pass "first-tasks from FEATURES.md is substituted"
else
    _fail "first-tasks not substituted" "expected F-002 (planned feature)"
fi

if grep -q "ADR-001-architecture.md" "$ONBOARDING"; then
    _pass "ADR index includes ADR-001"
else
    _fail "ADR index missing ADR-001" "see .agentic/spec/adr/"
fi

if grep -q "Wave B" "$ONBOARDING"; then
    _pass "current focus from STATUS.md is substituted"
else
    _fail "current focus not substituted" "expected 'Wave B'"
fi

# -- 5. 5-minute walkthrough present (AC-3) ---------------------------------
if grep -q "Make your first commit" "$ONBOARDING"; then
    _pass "5-minute walkthrough section exists (AC-3)"
else
    _fail "walkthrough section missing" "AC-3"
fi

if grep -q "ag commit" "$ONBOARDING"; then
    _pass "walkthrough exercises ag commit"
else
    _fail "walkthrough doesn't reference ag commit" "AC-3"
fi

# -- 6. Pre-commit gate references ONBOARDING.md when present (AC-4) ---------
# Check the source: the gate's print_blocked emits the reference conditionally.
if grep -q "ONBOARDING.md" "$ROOT_DIR/.agentic/lib/hooks/precommit_gate.py"; then
    _pass "precommit_gate.py references ONBOARDING.md (AC-4)"
else
    _fail "precommit_gate.py doesn't reference ONBOARDING.md" "AC-4"
fi

# -- 7. Help flag works ------------------------------------------------------
help_out=$(ROOT_DIR="$TMP" bash "$AG" onboard --help 2>&1)
if echo "$help_out" | grep -q "new-contributor playbook"; then
    _pass "ag onboard --help shows usage"
else
    _fail "--help missing usage text" "$help_out"
fi

# -- 8. -o flag writes to alternate path -------------------------------------
ALT="$TMP/.agentic/ONBOARDING_alt.md"
ROOT_DIR="$TMP" bash "$AG" onboard -o "$ALT" >/dev/null 2>&1
if [ -f "$ALT" ]; then
    _pass "-o flag writes to alternate path"
else
    _fail "-o flag didn't write alternate file" "$ALT"
fi

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" = "0" ]
