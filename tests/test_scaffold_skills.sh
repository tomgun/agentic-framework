#!/usr/bin/env bash
# Unit tests for scaffold.sh's marketplace skills integration (F-008 AC-012, PR-B).
#
# Tests cover:
#   - --no-skills flag short-circuits the entire skills block
#   - skip_on_init preference (jq path + grep fallback) honored
#   - CI environment vars suppress the interactive prompt
#   - Preference write is atomic (tmp + mv)
#   - Detection uses `sync --dry-run` exit code, not output grep

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCAFFOLD="$FRAMEWORK_ROOT/.agentic/lib/init/scaffold.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() { echo -e "  ${GREEN}PASS${NC}: $1"; ((PASSED++)) || true; }
fail() { echo -e "  ${RED}FAIL${NC}: $1"; [[ -n "${2:-}" ]] && echo "    $2"; ((FAILED++)) || true; }

# ---------------------------------------------------------------------------
# These are source-level structural tests. The full scaffold.sh runs many
# unrelated steps (stack detection, AGENTS.md, hooks install, git config) and
# isolating just the skills block is impractical without a refactor. We assert
# that the scaffold contains the correct guards, rather than running it
# end-to-end with mocked subprocesses.
# ---------------------------------------------------------------------------

t_no_skills_flag_skips() {
    if grep -Eq '^[[:space:]]*--no-skills\)' "$SCAFFOLD" && \
       grep -q 'NO_SKILLS="yes"' "$SCAFFOLD" && \
       grep -Eq '\[\[ "\$DISCOVERY_RAN" == "yes" && -z "\$NO_SKILLS"' "$SCAFFOLD"; then
        pass "--no-skills flag wired and gates the skills block"
    else
        fail "--no-skills flag not properly wired"
    fi
}

t_skip_on_init_pref_skips() {
    if grep -q 'skip_on_init' "$SCAFFOLD" && \
       grep -q '_SKILLS_SKIPPED_BEFORE' "$SCAFFOLD" && \
       grep -q '! -z "\$_SKILLS_SKIPPED_BEFORE"\|-z "\$_SKILLS_SKIPPED_BEFORE"' "$SCAFFOLD"; then
        pass "skip_on_init preference is read and gates the prompt"
    else
        fail "skip_on_init preference flow missing"
    fi
}

t_ci_env_skips_prompt() {
    # CI env detection covers the major providers. Each must be checked.
    local missing=()
    for var in CI GITHUB_ACTIONS GITLAB_CI BUILDKITE CIRCLECI JENKINS_URL; do
        grep -q "\${${var}:-}" "$SCAFFOLD" || missing+=("$var")
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        pass "CI env vars detected: CI/GITHUB_ACTIONS/GITLAB_CI/BUILDKITE/CIRCLECI/JENKINS_URL"
    else
        fail "CI env detection missing vars: ${missing[*]}"
    fi
}

t_pref_write_atomic() {
    if grep -q '"${SKILLS_PREFS}.tmp"' "$SCAFFOLD" && \
       grep -q 'mv "${SKILLS_PREFS}.tmp" "$SKILLS_PREFS"' "$SCAFFOLD"; then
        pass "preference written atomically (tmp + mv)"
    else
        fail "preference write is not atomic — partial write could corrupt JSON"
    fi
}

t_pref_jq_and_grep_fallback() {
    # Both paths must exist: jq when available, grep fallback when not.
    if grep -q 'command -v jq' "$SCAFFOLD" && \
       grep -q "jq -r '.skip_on_init // false'" "$SCAFFOLD" && \
       grep -q 'grep -Eq.*skip_on_init' "$SCAFFOLD"; then
        pass "preference reader has jq path + grep fallback"
    else
        fail "preference reader missing jq or grep-fallback path"
    fi
}

t_match_detection_uses_dry_run_exit_code() {
    # sync --dry-run returns exit 2 when a diff is present — robust signal.
    # Earlier draft used `grep -q "available"` which has both false-positive
    # and false-negative failure modes.
    if grep -q 'sync --dry-run' "$SCAFFOLD" && \
       grep -Eq '\[\[ \$\? -eq 2 \]\]' "$SCAFFOLD"; then
        pass "match detection uses sync --dry-run exit code (not output grep)"
    else
        fail "match detection still uses output grep instead of exit code"
    fi
}

t_playbook_step_3b_present() {
    # The non-interactive / agent-driven path relies on init_playbook.md Step 3b
    # to guide the agent to invoke ag skills suggest after STACK.md is populated.
    local playbook="$FRAMEWORK_ROOT/.agentic/lib/init/init_playbook.md"
    if grep -q 'ag skills suggest' "$playbook"; then
        pass "init_playbook.md references ag skills suggest (Step 3b)"
    else
        fail "init_playbook.md missing ag skills suggest reference"
    fi
}

# ---------------------------------------------------------------------------
# Run all
# ---------------------------------------------------------------------------
echo "=== scaffold.sh skills integration tests (F-008 PR-B / AC-012) ==="
t_no_skills_flag_skips
t_skip_on_init_pref_skips
t_ci_env_skips_prompt
t_pref_write_atomic
t_pref_jq_and_grep_fallback
t_match_detection_uses_dry_run_exit_code
t_playbook_step_3b_present

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
[[ $FAILED -eq 0 ]]
