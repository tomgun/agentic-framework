#!/usr/bin/env bash
# tests/test_contract_readonly.sh — R-005 acceptance tests
#
# Two test groups:
#   1) Bash-only unit tests (no PyYAML required) — exercise the helpers and
#      refusal paths directly against a hand-rolled YAML contract.
#   2) End-to-end integration tests — drive `ag contract` via the dispatcher.
#      Skipped automatically when PyYAML is not importable.
#
# Validates:
#   AC1: `ag contract promote` chmods the contract to 444
#   AC2: Direct write to a 444 contract fails (EACCES)
#   AC3: Direct mutators (`set`, `add-assertion`, `add-migration`) refuse on
#         locked contracts and print the sanctioned `ag contract migrate` path
#   AC4: `ag contract migrate --reason ...` mutates and re-locks
#   AC4b: `ag contract migrate` is idempotent w.r.t. lock state
#
# Linux + macOS only; Windows skipped (chmod semantics differ).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

case "$(uname -s)" in
    Linux|Darwin) ;;
    *)
        echo "skipping on $(uname -s) — chmod semantics differ"
        exit 0
        ;;
esac

# Skip filesystem-permission checks when running as root: chmod 444 doesn't
# stop root from writing, and the EACCES assertion would falsely fail.
if [[ "$(id -u)" -eq 0 ]]; then
    echo -e "${YELLOW}skipping: tests must not run as root (chmod 444 ignored by uid 0)${NC}"
    exit 0
fi

test_case() { echo -n "Testing: $1... "; }
pass() { echo -e "${GREEN}PASS${NC}"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC}"; [[ -n "${1:-}" ]] && echo "  $1"; FAILED=$((FAILED + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} ($1)"; SKIPPED=$((SKIPPED + 1)); }

# Returns 3-digit octal mode. Linux: stat -c %a; macOS: stat -f %A.
file_mode() {
    local f="$1"
    if stat -c %a "$f" >/dev/null 2>&1; then
        stat -c %a "$f"
    else
        stat -f %A "$f"
    fi
}

YAML_OK=0
python3 -c "import yaml" 2>/dev/null && YAML_OK=1

echo ""
echo "=== R-005 · Filesystem read-only protection for shipped contracts ==="
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Group 1: Bash helper unit tests (no PyYAML dependency)
# ─────────────────────────────────────────────────────────────────────────────

# Stub colors that contract.sh references; harmless to leave set across tests.
RED='' GREEN='' YELLOW='' NC='' BOLD='' DIM=''
# shellcheck disable=SC1091
source "$FRAMEWORK_ROOT/.agentic/lib/tools/commands/contract.sh"

# Each unit test makes its own scratch dir + paths. Helpers stay simple so
# variables stay in the caller's scope (no $(subshell)).
make_unit_dir() {
    ROOT_DIR=$(mktemp -d "/tmp/r005-unit-XXXXXX")
    SPEC_DIR="$ROOT_DIR/spec"
    CONTRACTS_DIR="$SPEC_DIR/contracts"
    mkdir -p "$CONTRACTS_DIR"
}

drop_unit_dir() {
    [[ -n "${ROOT_DIR:-}" && -d "$ROOT_DIR" && "$ROOT_DIR" == /tmp/r005-unit-* ]] && rm -rf "$ROOT_DIR"
    unset ROOT_DIR SPEC_DIR CONTRACTS_DIR
}

# Hand-rolled minimal contract YAML — enough for refuse-when-locked checks.
write_dummy_contract() {
    local f="$1"
    local fid="$2"
    cat > "$f" <<EOF
id: $fid
name: dummy
description: r005 unit test
lifecycle: shipped
protection: contract
profile: formal
category: test
assertions: []
migrations: []
EOF
}

test_case "_contract_is_locked: false on writable file"
make_unit_dir
F="$CONTRACTS_DIR/F-99905.yaml"; write_dummy_contract "$F" F-99905
if ! _contract_is_locked "$F"; then pass; else fail "expected writable to be unlocked"; fi
drop_unit_dir

test_case "_contract_lock_shipped: chmods to 444"
make_unit_dir
F="$CONTRACTS_DIR/F-99905.yaml"; write_dummy_contract "$F" F-99905
_contract_lock_shipped "$F"
[[ "$(file_mode "$F")" == "444" ]] && pass || fail "mode=$(file_mode "$F")"
drop_unit_dir

test_case "_contract_is_locked: true after lock"
make_unit_dir
F="$CONTRACTS_DIR/F-99905.yaml"; write_dummy_contract "$F" F-99905
_contract_lock_shipped "$F"
if _contract_is_locked "$F"; then pass; else fail "expected locked"; fi
drop_unit_dir

test_case "_contract_unlock_for_migration: restores user write"
make_unit_dir
F="$CONTRACTS_DIR/F-99905.yaml"; write_dummy_contract "$F" F-99905
_contract_lock_shipped "$F"
_contract_unlock_for_migration "$F"
if [[ -w "$F" ]]; then pass; else fail "still not writable"; fi
drop_unit_dir

test_case "_contract_refuse_if_locked: noop on writable file"
make_unit_dir
F="$CONTRACTS_DIR/F-99905.yaml"; write_dummy_contract "$F" F-99905
out=$(_contract_refuse_if_locked "$F" F-99905 2>&1); rc=$?
if [[ $rc -eq 0 ]] && [[ -z "$out" ]]; then pass; else fail "rc=$rc out=$out"; fi
drop_unit_dir

test_case "_contract_refuse_if_locked: refuses + hints sanctioned path on locked file"
make_unit_dir
F="$CONTRACTS_DIR/F-99905.yaml"; write_dummy_contract "$F" F-99905
_contract_lock_shipped "$F"
out=$(_contract_refuse_if_locked "$F" F-99905 2>&1); rc=$?
if [[ $rc -ne 0 ]] && echo "$out" | grep -q "ag contract migrate F-99905 --reason"; then
    pass
else
    fail "rc=$rc out=${out:0:160}"
fi
drop_unit_dir

test_case "AC2: direct write to a 444 contract fails (EACCES)"
make_unit_dir
F="$CONTRACTS_DIR/F-99905.yaml"; write_dummy_contract "$F" F-99905
_contract_lock_shipped "$F"
if (echo "tampered" >> "$F") 2>/dev/null; then
    fail "write succeeded — protection bypassed"
else
    pass
fi
drop_unit_dir

test_case "AC3: _contract_set refuses on locked contract before invoking python"
make_unit_dir
F="$CONTRACTS_DIR/F-99905.yaml"; write_dummy_contract "$F" F-99905
_contract_lock_shipped "$F"
out=$(_contract_set F-99905 notes "tampered" 2>&1); rc=$?
if [[ $rc -ne 0 ]] && echo "$out" | grep -q "ag contract migrate F-99905"; then
    pass
else
    fail "rc=$rc out=${out:0:160}"
fi
drop_unit_dir

test_case "AC3: _contract_add_assertion refuses on locked contract"
make_unit_dir
F="$CONTRACTS_DIR/F-99905.yaml"; write_dummy_contract "$F" F-99905
_contract_lock_shipped "$F"
out=$(_contract_add_assertion F-99905 "tampered AC" --type behavioral 2>&1); rc=$?
if [[ $rc -ne 0 ]] && echo "$out" | grep -q "ag contract migrate F-99905"; then
    pass
else
    fail "rc=$rc out=${out:0:160}"
fi
drop_unit_dir

test_case "AC3: _contract_add_migration refuses on locked contract"
make_unit_dir
F="$CONTRACTS_DIR/F-99905.yaml"; write_dummy_contract "$F" F-99905
_contract_lock_shipped "$F"
out=$(_contract_add_migration F-99905 --trigger external --reason "x" 2>&1); rc=$?
if [[ $rc -ne 0 ]] && echo "$out" | grep -q "ag contract migrate F-99905"; then
    pass
else
    fail "rc=$rc out=${out:0:160}"
fi
drop_unit_dir

test_case "ag contract migrate: usage error without --reason"
make_unit_dir
out=$(_contract_migrate F-99905 2>&1); rc=$?
if [[ $rc -ne 0 ]] && echo "$out" | grep -q "Usage:"; then pass; else fail "rc=$rc out=${out:0:120}"; fi
drop_unit_dir

# ─────────────────────────────────────────────────────────────────────────────
# Group 2: End-to-end integration via `ag contract` (requires PyYAML)
# ─────────────────────────────────────────────────────────────────────────────

setup_e2e_sandbox() {
    local sandbox
    sandbox=$(mktemp -d "/tmp/r005-e2e-XXXXXX")
    mkdir -p "$sandbox/.agentic/spec/contracts"
    mkdir -p "$sandbox/.agentic/journal"
    mkdir -p "$sandbox/.agentic/session"
    cp -r "$FRAMEWORK_ROOT/.agentic/lib" "$sandbox/.agentic/lib"
    cat > "$sandbox/STACK.md" <<'EOF'
Profile: formal
EOF
    echo "$sandbox"
}

cleanup_e2e_sandbox() {
    local d="$1"
    [[ -n "$d" && -d "$d" && "$d" == /tmp/r005-e2e-* ]] && rm -rf "$d"
}

ag_contract_in_sandbox() {
    local sandbox="$1"; shift
    ROOT_DIR="$sandbox" \
    AGENTIC_LIB="$sandbox/.agentic/lib" \
    AGENTIC_ROOT="$sandbox/.agentic" \
    PROJECT_ROOT="$sandbox" \
    bash "$sandbox/.agentic/lib/tools/ag.sh" contract "$@"
}

if [[ $YAML_OK -eq 1 ]]; then
    test_case "AC1 (e2e): ag contract promote sets file mode to 444"
    SB=$(setup_e2e_sandbox)
    ag_contract_in_sandbox "$SB" create F-99905 >/dev/null 2>&1
    ag_contract_in_sandbox "$SB" add-assertion F-99905 "test" --type behavioral >/dev/null 2>&1
    ag_contract_in_sandbox "$SB" promote F-99905 >/dev/null 2>&1
    CFILE="$SB/.agentic/spec/contracts/F-99905.yaml"
    if [[ -f "$CFILE" ]] && [[ "$(file_mode "$CFILE")" == "444" ]]; then pass; else fail "missing or mode=$(file_mode "$CFILE" 2>/dev/null)"; fi
    cleanup_e2e_sandbox "$SB"

    test_case "AC4 (e2e): ag contract migrate adds assertion + migration entry, re-locks to 444"
    SB=$(setup_e2e_sandbox)
    ag_contract_in_sandbox "$SB" create F-99905 >/dev/null 2>&1
    ag_contract_in_sandbox "$SB" add-assertion F-99905 "first" --type behavioral >/dev/null 2>&1
    ag_contract_in_sandbox "$SB" promote F-99905 >/dev/null 2>&1
    CFILE="$SB/.agentic/spec/contracts/F-99905.yaml"
    out=$(ag_contract_in_sandbox "$SB" migrate F-99905 --reason "test migration" --trigger external --add-assertion "added via migrate" --type behavioral 2>&1); rc=$?
    mode_after=$(file_mode "$CFILE" 2>/dev/null || echo "?")
    if [[ $rc -eq 0 ]] \
        && [[ "$mode_after" == "444" ]] \
        && grep -q "added via migrate" "$CFILE" \
        && grep -q "test migration" "$CFILE"; then
        pass
    else
        fail "rc=$rc mode=$mode_after"
    fi
    cleanup_e2e_sandbox "$SB"

    test_case "AC4b (e2e): re-promote leaves mode 444 (idempotent)"
    SB=$(setup_e2e_sandbox)
    ag_contract_in_sandbox "$SB" create F-99905 >/dev/null 2>&1
    ag_contract_in_sandbox "$SB" add-assertion F-99905 "test" --type behavioral >/dev/null 2>&1
    ag_contract_in_sandbox "$SB" promote F-99905 >/dev/null 2>&1
    ag_contract_in_sandbox "$SB" promote F-99905 >/dev/null 2>&1
    CFILE="$SB/.agentic/spec/contracts/F-99905.yaml"
    [[ "$(file_mode "$CFILE")" == "444" ]] && pass || fail "mode=$(file_mode "$CFILE")"
    cleanup_e2e_sandbox "$SB"
else
    test_case "AC1 (e2e): ag contract promote sets file mode to 444";          skip "PyYAML not installed"
    test_case "AC4 (e2e): ag contract migrate adds + re-locks";                 skip "PyYAML not installed"
    test_case "AC4b (e2e): re-promote idempotent";                              skip "PyYAML not installed"
fi

echo ""
echo "─────────────────────────────────────────────"
total=$((PASSED + FAILED + SKIPPED))
if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}${PASSED}/${total} passed${NC} ($SKIPPED skipped)"
    exit 0
else
    echo -e "${RED}${FAILED}/${total} failed${NC} ($PASSED passed, $SKIPPED skipped)"
    exit 1
fi
