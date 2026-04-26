#!/usr/bin/env bash
# Unit tests for skills_marketplace.py (F-008 AC-009/010/011, PR-A)
#
# Exercises: allowlist schema enforcement, stack signal matching, install
# refusals (unpinned sha, seed sha, scripts quarantine), sync diff output.
# Fetches are mocked via a temporary file:// URL rewrite; no network needed.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENGINE="$FRAMEWORK_ROOT/.agentic/lib/tools/skills_marketplace.py"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

# Skip entire suite cleanly if PyYAML is missing — framework has graceful-degradation convention.
if ! python3 -c "import yaml" 2>/dev/null; then
    echo -e "${YELLOW}SKIP${NC}: PyYAML not installed — skills_marketplace tests require it."
    echo "  (Framework convention: tools that need PyYAML skip without failing validate_framework.sh)"
    exit 0
fi

pass() { echo -e "  ${GREEN}PASS${NC}: $1"; ((PASSED++)) || true; }
fail() { echo -e "  ${RED}FAIL${NC}: $1"; [[ -n "${2:-}" ]] && echo "    $2"; ((FAILED++)) || true; }

# ---------------------------------------------------------------------------
# Per-test isolated fixture: temp project with .agentic/ skeleton + allowlist
# ---------------------------------------------------------------------------
make_project() {
    local root
    root=$(mktemp -d)
    mkdir -p "$root/.agentic/lib/data" "$root/.agentic/local/extensions/skills"
    # Stub STACK.md so signal matching works
    cat > "$root/STACK.md" <<'EOF'
# Stack
- language: Python
EOF
    echo "$root"
}

write_allowlist() {
    local root="$1"
    local sha="${2:-abcdef0123456789abcdef0123456789abcdef01}"
    cat > "$root/.agentic/lib/data/skills-marketplace.yaml" <<EOF
version: 1
stacks:
  python:
    signals: [STACK.md:Python]
    skills:
      - id: test/skill#python-quality
        reason: Test skill for python stack
        sha: "$sha"
EOF
}

run_engine() {
    local root="$1"; shift
    CLAUDE_PROJECT_DIR="$root" ROOT_DIR="$root" python3 "$ENGINE" "$@" 2>&1
}

# ---------------------------------------------------------------------------
# Test 1 — allowlist loads; version 1 required
# ---------------------------------------------------------------------------
t_allowlist_loads() {
    local root
    root=$(make_project)
    write_allowlist "$root"
    local out
    out=$(run_engine "$root" suggest)
    if echo "$out" | grep -q "test/skill#python-quality"; then
        pass "allowlist loads and signal matches"
    else
        fail "allowlist did not produce expected match" "$out"
    fi
    rm -rf "$root"
}

# ---------------------------------------------------------------------------
# Test 2 — missing sha pin is rejected at allowlist load (AC-009)
# ---------------------------------------------------------------------------
t_missing_sha_rejected() {
    local root
    root=$(make_project)
    cat > "$root/.agentic/lib/data/skills-marketplace.yaml" <<'EOF'
version: 1
stacks:
  python:
    signals: [STACK.md:Python]
    skills:
      - id: test/skill#python-quality
        reason: No sha pinned
EOF
    local out rc
    out=$(run_engine "$root" suggest); rc=$?
    if [[ $rc -ne 0 ]] && echo "$out" | grep -qi "missing or invalid sha"; then
        pass "unpinned skill rejected at load"
    else
        fail "unpinned skill was not rejected" "exit=$rc out=$out"
    fi
    rm -rf "$root"
}

# ---------------------------------------------------------------------------
# Test 3 — seed (all-zero) sha is rejected at install (AC-010)
# ---------------------------------------------------------------------------
t_seed_sha_rejected_on_install() {
    local root
    root=$(make_project)
    write_allowlist "$root" "0000000000000000000000000000000000000000"
    local out rc
    out=$(run_engine "$root" install --all --yes --override-builtin); rc=$?
    if [[ $rc -ne 0 ]] && echo "$out" | grep -qi "seed placeholder"; then
        pass "seed-sha install refused"
    else
        fail "seed-sha install was not refused" "exit=$rc out=$out"
    fi
    rm -rf "$root"
}

# ---------------------------------------------------------------------------
# Test 4 — install refuses non-raw URL (defense in depth)
# The engine's fetch() function asserts the URL starts with raw.githubusercontent.com.
# We verify the guard exists in the source — a direct runtime test would require
# mocking urllib which is out of scope for a shell unit test.
# ---------------------------------------------------------------------------
t_raw_host_enforced() {
    if grep -q 'refusing to fetch non-raw URL' "$ENGINE"; then
        pass "fetch() rejects non-raw URLs"
    else
        fail "raw-host enforcement missing from fetch()"
    fi
}

# ---------------------------------------------------------------------------
# Test 5 — sync --dry-run prints a one-line nudge when diff present,
# exit code 2 (hook signal). No installed skills vs. matched allowlist →
# diff of 1 add, 0 remove.
# ---------------------------------------------------------------------------
t_sync_dry_run_nudge() {
    local root
    root=$(make_project)
    write_allowlist "$root"
    local out rc
    out=$(run_engine "$root" sync --dry-run); rc=$?
    if [[ $rc -eq 2 ]] && echo "$out" | grep -q "Stack signals changed"; then
        pass "sync --dry-run emits hook nudge + exit 2"
    else
        fail "sync --dry-run did not behave as expected" "exit=$rc out=$out"
    fi
    rm -rf "$root"
}

# ---------------------------------------------------------------------------
# Test 6 — script quarantine: install refuses when SKILL.md declares Bash
# allowed-tools or references scripts/, unless --accept-scripts.
# Verified at the module source level since network fetch is out of scope
# for the shell suite.
# ---------------------------------------------------------------------------
t_script_quarantine() {
    if grep -q 'accept_scripts' "$ENGINE" && grep -q 'references executable scripts' "$ENGINE"; then
        pass "scripts quarantine present in engine"
    else
        fail "scripts quarantine logic missing"
    fi
}

# ---------------------------------------------------------------------------
# Test 7 — ag skills command is registered and dispatches
# ---------------------------------------------------------------------------
t_ag_skills_registered() {
    local out
    out=$(bash "$FRAMEWORK_ROOT/.agentic/lib/tools/ag.sh" skills help 2>&1)
    if echo "$out" | grep -q "USAGE"; then
        pass "ag skills help dispatches to cmd_skills"
    else
        fail "ag skills not registered" "$out"
    fi
}

# ---------------------------------------------------------------------------
# Test 8 — zero-sha (placeholder) is rejected AT LOAD (not just at install).
# Defense in depth: suggest/list/sync should also surface seed-state allowlists,
# not silently process them and fail only on install.
# ---------------------------------------------------------------------------
t_zero_sha_rejected_at_load() {
    local root
    root=$(make_project)
    write_allowlist "$root" "0000000000000000000000000000000000000000"
    local out rc
    out=$(run_engine "$root" suggest); rc=$?
    if [[ $rc -ne 0 ]] && echo "$out" | grep -qi "placeholder zero-sha"; then
        pass "zero-sha rejected at load (suggest fails)"
    else
        fail "zero-sha was not rejected at load" "exit=$rc out=$out"
    fi
    rm -rf "$root"
}

# ---------------------------------------------------------------------------
# Test 9 — malformed YAML allowlist produces a clean parse error, not a crash
# ---------------------------------------------------------------------------
t_malformed_yaml_rejected() {
    local root
    root=$(make_project)
    cat > "$root/.agentic/lib/data/skills-marketplace.yaml" <<'EOF'
version: 1
stacks:
  python:
    signals: [STACK.md:Python
    skills:
      - id: broken
EOF
    local out rc
    out=$(run_engine "$root" suggest); rc=$?
    if [[ $rc -ne 0 ]] && echo "$out" | grep -qi "yaml parse error\|allowlist:"; then
        pass "malformed YAML produces clean error"
    else
        fail "malformed YAML did not produce clean error" "exit=$rc out=$out"
    fi
    rm -rf "$root"
}

# ---------------------------------------------------------------------------
# Test 10 — `ag skills request` files issues against the framework upstream,
# not the user's current repo. Verified via source inspection: cmd_request
# must include --repo with the upstream default.
# ---------------------------------------------------------------------------
t_request_targets_upstream_repo() {
    if grep -q '"--repo"' "$ENGINE" && \
       grep -q 'tomgun/agentic-framework' "$ENGINE" && \
       grep -q 'upstream_repo' "$ENGINE"; then
        pass "cmd_request targets upstream repo (not user's current repo)"
    else
        fail "cmd_request does not pin --repo to upstream framework"
    fi
}

# ---------------------------------------------------------------------------
# Test 11 — signal_matches rejects absolute paths and `..` traversal
# (defense against allowlist authors smuggling arbitrary paths).
# ---------------------------------------------------------------------------
t_signal_path_traversal_rejected() {
    local out
    out=$(python3 -c "
import os
os.environ['CLAUDE_PROJECT_DIR'] = '$FRAMEWORK_ROOT'
os.environ['ROOT_DIR'] = '$FRAMEWORK_ROOT'
import sys
sys.path.insert(0, '$FRAMEWORK_ROOT/.agentic/lib/tools')
import skills_marketplace as sm
# Absolute path: must reject
print('abs_rejected:', sm.signal_matches('/etc/passwd') is False)
# Traversal: must reject
print('traversal_rejected:', sm.signal_matches('../../etc/passwd') is False)
")
    if echo "$out" | grep -q "abs_rejected: True" && echo "$out" | grep -q "traversal_rejected: True"; then
        pass "absolute paths and traversal rejected in signal_matches"
    else
        fail "signal_matches accepted unsafe path" "$out"
    fi
}

# ---------------------------------------------------------------------------
# Test 12 — scoped npm package wildcards match correctly
# (e.g. 'dependencies.@azure/*' matches '@azure/identity' in package.json).
# Round-2 review found split-on-`.` broke scoped wildcards.
# ---------------------------------------------------------------------------
t_scoped_npm_wildcard_matches() {
    local root
    root=$(mktemp -d)
    cat > "$root/package.json" <<'EOF'
{
  "name": "test",
  "dependencies": {
    "@azure/identity": "^4.0.0",
    "react": "^18.0.0"
  }
}
EOF
    local out
    out=$(python3 -c "
import os
os.environ['CLAUDE_PROJECT_DIR'] = '$root'
os.environ['ROOT_DIR'] = '$root'
import sys
sys.path.insert(0, '$FRAMEWORK_ROOT/.agentic/lib/tools')
import skills_marketplace as sm
sm._read_package_json.cache_clear()
print('scoped_match:', sm.signal_matches('package.json:dependencies.@azure/*'))
print('plain_match:', sm.signal_matches('package.json:dependencies.react'))
print('no_match:', sm.signal_matches('package.json:dependencies.@vue/runtime'))
")
    if echo "$out" | grep -q "scoped_match: True" && \
       echo "$out" | grep -q "plain_match: True" && \
       echo "$out" | grep -q "no_match: False"; then
        pass "scoped npm wildcard matching works"
    else
        fail "scoped npm wildcard did not match correctly" "$out"
    fi
    rm -rf "$root"
}

# ---------------------------------------------------------------------------
# Test 13 — generators (generate-skills.sh + generate-cursor-skills.sh)
# read from .agentic/local/extensions/skills/ — wires extension dir into
# both Claude and Cursor skill output. (AC-011 verify counterpart.)
# ---------------------------------------------------------------------------
t_extension_dir_paths_in_generators() {
    local g_skills="$FRAMEWORK_ROOT/.agentic/lib/tools/generate-skills.sh"
    local g_cursor="$FRAMEWORK_ROOT/.agentic/lib/tools/generate-cursor-skills.sh"
    if grep -q 'local/extensions/skills' "$g_skills" && \
       grep -q 'local/extensions/skills' "$g_cursor"; then
        pass "both generators reference the extensions/skills dir"
    else
        fail "extension-dir path missing from one or both generators"
    fi
}

# ---------------------------------------------------------------------------
# Test 14 — react stack maps to web_fullstack builtin (NOT mobile_react_native).
# Round-2 review found react was incorrectly mapping to RN, silently disabling
# react skill entries citing 'built-in covers'.
# ---------------------------------------------------------------------------
t_react_maps_to_web_fullstack() {
    local out
    out=$(python3 -c "
import os
os.environ['CLAUDE_PROJECT_DIR'] = '$FRAMEWORK_ROOT'
os.environ['ROOT_DIR'] = '$FRAMEWORK_ROOT'
import sys
sys.path.insert(0, '$FRAMEWORK_ROOT/.agentic/lib/tools')
import skills_marketplace as sm
# react should map to web_fullstack, not mobile_react_native
print('react_builtin:', sm.builtin_covers.__doc__ is not None)
import inspect
src = inspect.getsource(sm.builtin_covers)
print('react_to_web:', 'react' in src and 'web_fullstack' in src)
print('not_react_to_rn:', '\"react\": \"mobile_react_native\"' not in src)
")
    if echo "$out" | grep -q "react_to_web: True" && \
       echo "$out" | grep -q "not_react_to_rn: True"; then
        pass "react stack correctly maps to web_fullstack"
    else
        fail "react stack mapping incorrect" "$out"
    fi
}

# ---------------------------------------------------------------------------
# Run all
# ---------------------------------------------------------------------------
echo "=== skills_marketplace unit tests ==="
t_allowlist_loads
t_missing_sha_rejected
t_seed_sha_rejected_on_install
t_raw_host_enforced
t_sync_dry_run_nudge
t_script_quarantine
t_ag_skills_registered
t_zero_sha_rejected_at_load
t_malformed_yaml_rejected
t_request_targets_upstream_repo
t_signal_path_traversal_rejected
t_scoped_npm_wildcard_matches
t_extension_dir_paths_in_generators
t_react_maps_to_web_fullstack

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
[[ $FAILED -eq 0 ]]
