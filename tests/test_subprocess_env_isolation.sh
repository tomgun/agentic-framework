#!/usr/bin/env bash
# Regression test for T-0078 — verification subprocesses must not leak
# framework-internal env vars (ROOT_DIR, AGENTIC_ROOT, etc.) into the
# AC/contract verify command. See:
#   .agentic/lib/tools/commands/operations.sh:546 (legacy-markdown path)
#   .agentic/lib/contracts.py:513-525            (YAML contract path)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
PASSED=0; FAILED=0

test_case() { echo -n "Testing: $1... "; }
pass() { echo -e "${GREEN}PASS${NC}"; ((PASSED++)); }
fail() { echo -e "${RED}FAIL${NC}"; [[ -n "${1:-}" ]] && echo "  $1"; ((FAILED++)); }

# The six framework-internal vars that paths.sh exports and that must be
# scrubbed at every subprocess boundary that hosts user-authored verify
# commands. Plus REPO_ROOT (defensive — local-only in test scripts but
# we strip it preemptively).
LEAK_VARS=(ROOT_DIR PROJECT_ROOT MAIN_PROJECT_ROOT AGENTIC_ROOT AGENTIC_LIB AGENTS_JSON REPO_ROOT)

# Poison every leak var before each test so we know stripping is what's
# clearing them, not absence of upstream exports.
poison_env() {
    export ROOT_DIR="/poisoned-by-caller-ROOT_DIR"
    export PROJECT_ROOT="/poisoned-by-caller-PROJECT_ROOT"
    export MAIN_PROJECT_ROOT="/poisoned-by-caller-MAIN_PROJECT_ROOT"
    export AGENTIC_ROOT="/poisoned-by-caller-AGENTIC_ROOT"
    export AGENTIC_LIB="/poisoned-by-caller-AGENTIC_LIB"
    export AGENTS_JSON="/poisoned-by-caller-AGENTS_JSON"
    export FRAMEWORK_ROOT="/poisoned-by-caller-FRAMEWORK_ROOT"
}

#=============================================================================
# 1. operations.sh:546 — legacy-markdown path
#=============================================================================
# Asserts the exact env-strip pattern used at the patched line.

test_case "operations.sh:546 strip — ROOT_DIR not visible to verify command"
poison_env
out=$(env -u ROOT_DIR -u PROJECT_ROOT -u MAIN_PROJECT_ROOT \
          -u AGENTIC_ROOT -u AGENTIC_LIB -u AGENTS_JSON -u REPO_ROOT \
          bash -c 'echo "${ROOT_DIR:-UNSET}"')
if [[ "$out" == "UNSET" ]]; then pass; else fail "saw '$out'"; fi

test_case "operations.sh:546 strip — all six framework vars scrubbed"
poison_env
out=$(env -u ROOT_DIR -u PROJECT_ROOT -u MAIN_PROJECT_ROOT \
          -u AGENTIC_ROOT -u AGENTIC_LIB -u AGENTS_JSON -u REPO_ROOT \
          bash -c 'for v in '"${LEAK_VARS[*]}"'; do echo "$v=${!v:-UNSET}"; done')
if ! echo "$out" | grep -v UNSET | grep -q poisoned; then pass
else fail "leaked: $(echo "$out" | grep poisoned)"; fi

test_case "operations.sh:546 strip — non-agentic vars still pass through"
poison_env
export TEST_PASSTHROUGH="kept"
out=$(env -u ROOT_DIR -u PROJECT_ROOT -u MAIN_PROJECT_ROOT \
          -u AGENTIC_ROOT -u AGENTIC_LIB -u AGENTS_JSON -u REPO_ROOT \
          bash -c 'echo "$TEST_PASSTHROUGH"')
unset TEST_PASSTHROUGH
if [[ "$out" == "kept" ]]; then pass; else fail "lost TEST_PASSTHROUGH ('$out')"; fi

# Confirm the patch is actually in place at operations.sh:546.
test_case "operations.sh:546 — patched line present"
if grep -A4 -B1 '_verify_output=' "$REPO_ROOT/.agentic/lib/tools/commands/operations.sh" \
   | grep -q 'env -u ROOT_DIR'; then pass
else fail "env -u ROOT_DIR not found near _verify_output assignment"; fi

#=============================================================================
# 2. contracts.py — YAML contract path
#=============================================================================
# Invokes verify_assertion directly with a synthetic shipped/structural
# assertion whose verify command asserts ROOT_DIR is absent.

test_case "contracts.py verify_assertion — ROOT_DIR scrubbed from assertion subprocess"
poison_env
cd "$REPO_ROOT"
python3 - <<'PY'
import os, sys, tempfile
from pathlib import Path

sys.path.insert(0, str(Path('.agentic/lib').resolve()))
from contracts import Assertion, verify_assertion

# verify command exits 0 only if ROOT_DIR is unset AND every other leak var
# (except PROJECT_ROOT, which contracts.py intentionally re-injects with the
# sandbox path) is unset.
verify_cmd = (
    '[ -z "${ROOT_DIR:-}" ] && '
    '[ -z "${MAIN_PROJECT_ROOT:-}" ] && '
    '[ -z "${AGENTIC_ROOT:-}" ] && '
    '[ -z "${AGENTIC_LIB:-}" ] && '
    '[ -z "${AGENTS_JSON:-}" ] && '
    '[ -z "${REPO_ROOT:-}" ]'
)

a = Assertion(
    id="A-test",
    text="leak vars must be stripped",
    type="structural",
    verify=verify_cmd,
    status="shipped",
)
with tempfile.TemporaryDirectory() as td:
    result = verify_assertion(a, Path(td))

if not result.passed:
    print(f"FAIL: assertion did not pass; output: {result.output!r}")
    sys.exit(1)
PY
if [[ $? -eq 0 ]]; then pass; else fail "Python assertion check failed"; fi

test_case "contracts.py verify_assertion — PROJECT_ROOT re-injected with sandbox path"
poison_env
cd "$REPO_ROOT"
python3 - <<'PY'
import os, sys, tempfile
from pathlib import Path

sys.path.insert(0, str(Path('.agentic/lib').resolve()))
from contracts import Assertion, verify_assertion

a = Assertion(
    id="A-test-project-root",
    text="PROJECT_ROOT should equal the sandbox path the caller passed in",
    type="structural",
    verify='[ "$PROJECT_ROOT" = "$EXPECTED" ]',
    status="shipped",
)
with tempfile.TemporaryDirectory() as td:
    os.environ["EXPECTED"] = td
    result = verify_assertion(a, Path(td))
    del os.environ["EXPECTED"]

if not result.passed:
    print(f"FAIL: PROJECT_ROOT mismatch; output: {result.output!r}")
    sys.exit(1)
PY
if [[ $? -eq 0 ]]; then pass; else fail "PROJECT_ROOT was not the sandbox path"; fi

# Confirm the _LEAK_VARS constant and filter exist in contracts.py.
test_case "contracts.py — _LEAK_VARS constant + os.environ filter present"
if grep -q '^_LEAK_VARS' "$REPO_ROOT/.agentic/lib/contracts.py" \
   && grep -q 'k not in _LEAK_VARS' "$REPO_ROOT/.agentic/lib/contracts.py"; then
    pass
else
    fail "_LEAK_VARS filter not found in contracts.py"
fi

#=============================================================================
# 3. Cross-checkout sanity — verify-contracts.sh still honors explicit ROOT_DIR
#=============================================================================
# operations.sh:511's bash invocation of verify-contracts.sh is deliberately
# NOT scrubbed. Confirm the legitimate cross-checkout pathway (parent sets
# ROOT_DIR to point the framework at a different project) is unbroken.

test_case "operations.sh:511 — verify-contracts.sh inherits parent ROOT_DIR"
# Spin up a tiny temp project with a contracts/ dir + empty FEATURES list.
# verify-contracts.sh exits 0 when there are no contracts.
TEST_DIR=$(mktemp -d "/tmp/t0078-XXXXXX")
mkdir -p "$TEST_DIR/.agentic/spec/contracts"
out=$(ROOT_DIR="$TEST_DIR" bash "$REPO_ROOT/.agentic/lib/tools/verify-contracts.sh" 2>&1)
rc=$?
rm -rf "$TEST_DIR"
if [[ "$rc" -eq 0 ]] && echo "$out" | grep -qiE "contracts|summary|0 passed"; then
    pass
else
    fail "rc=$rc out='$out'"
fi

#=============================================================================
echo ""
echo "Tests: $((PASSED + FAILED)) total, $PASSED passed, $FAILED failed"
[[ "$FAILED" -eq 0 ]]
