#!/usr/bin/env bash
# test_code_edit_hook.sh — Deterministic test for PostToolUse code-edit hook
#
# Tests on-code-edit.sh behavior:
#   1. DRAFT plan + code file → warning
#   2. DRAFT plan + spec file → no warning (allowlisted)
#   3. DRAFT plan + test file → no warning (allowlisted)
#   4. APPROVED plan + code file → no warning
#   5. No plan + code file → no warning
#   6. plan_review_enabled: no → no warning

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK_SCRIPT="$REPO_ROOT/.agentic/lib/hooks/shared/on-code-edit.sh"

PASS=0
FAIL=0
TOTAL=0

pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); }
fail() { echo "  ❌ $1: $2"; FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); }

# Create a temp project and echo the path
create_project() {
    local profile="${1:-formal}"
    local dir
    dir=$(mktemp -d)
    mkdir -p "$dir/.agentic/journal/plans" "$dir/.agentic/lib" "$dir/spec/acceptance" "$dir/tests" "$dir/src"
    cp "$REPO_ROOT/.agentic/lib/settings.sh" "$dir/.agentic/lib/"
    cp -r "$REPO_ROOT/.agentic/lib/presets" "$dir/.agentic/lib/" 2>/dev/null || true
    cat > "$dir/STACK.md" << EOF
# Stack

## Settings
- profile: $profile
- plan_review_enabled: yes
- plan_review_convergence: auto
EOF
    cat > "$dir/.agentic/lib/paths.sh" << 'PATHSEOF'
#!/usr/bin/env bash
[[ -n "${_AGENTIC_PATHS_LOADED:-}" ]] && return 0
_AGENTIC_PATHS_LOADED=1
FEATURE_ID_ERE='F-[0-9]{4,}'
EPIC_ID_ERE='E-[0-9]{4,}'
PATHSEOF
    echo "$dir"
}

# Run the hook directly (no function wrapper — avoids subshell variable issues)
# Usage: invoke_hook <project_root> <json_input> → sets HOOK_OUTPUT
invoke_hook() {
    HOOK_OUTPUT=$(echo "$2" | \
        CLAUDE_PROJECT_DIR="$1" \
        PROJECT_ROOT="$1" \
        _AGENTIC_SETTINGS_LOADED="" \
        _AGENTIC_PATHS_LOADED="" \
        _SETTINGS_ROOT_DIR="$1" \
        _SETTINGS_STACK_FILE="$1/STACK.md" \
        _SETTINGS_PROFILES_CONF="$REPO_ROOT/.agentic/lib/presets/profiles.conf" \
        _SETTINGS_SECTION_EXTRACTED="" \
        _SETTINGS_SECTION_CACHE="" \
        _SETTINGS_PROFILE_RESOLVED="" \
        _SETTINGS_PROFILE_CACHE="" \
        bash "$HOOK_SCRIPT" 2>/dev/null) || true
}

has_warning() {
    echo "$HOOK_OUTPUT" | grep -qi "unapproved plan\|STOP CODING"
}

# --- Test 1: DRAFT plan + code file → warning ---
echo "Test 1: DRAFT plan + code file → warning"
TD=$(create_project "formal")
cat > "$TD/.agentic/journal/plans/2026-03-19-F-0100-plan.md" << 'EOF'
# Plan

**Status**: DRAFT
EOF
invoke_hook "$TD" '{"tool_name":"Write","tool_input":{"file_path":"src/main.py"}}'
if has_warning; then
    pass "DRAFT plan + code file → warning emitted"
else
    fail "DRAFT plan + code file → warning emitted" "Expected warning, got: $HOOK_OUTPUT"
fi
rm -rf "$TD"

# --- Test 2: DRAFT plan + spec file → no warning ---
echo "Test 2: DRAFT plan + spec file → no warning (allowlisted)"
TD=$(create_project "formal")
cat > "$TD/.agentic/journal/plans/2026-03-19-F-0100-plan.md" << 'EOF'
# Plan

**Status**: DRAFT
EOF
invoke_hook "$TD" '{"tool_name":"Write","tool_input":{"file_path":"spec/acceptance/F-0100.md"}}'
if has_warning; then
    fail "DRAFT plan + spec file → no warning" "Got unexpected warning"
else
    pass "DRAFT plan + spec file → no warning"
fi
rm -rf "$TD"

# --- Test 3: DRAFT plan + test file → no warning ---
echo "Test 3: DRAFT plan + test file → no warning (allowlisted)"
TD=$(create_project "formal")
cat > "$TD/.agentic/journal/plans/2026-03-19-F-0100-plan.md" << 'EOF'
# Plan

**Status**: DRAFT
EOF
invoke_hook "$TD" '{"tool_name":"Edit","tool_input":{"file_path":"tests/test_main.py"}}'
if has_warning; then
    fail "DRAFT plan + test file → no warning" "Got unexpected warning"
else
    pass "DRAFT plan + test file → no warning"
fi
rm -rf "$TD"

# --- Test 4: APPROVED plan + code file → no warning ---
echo "Test 4: APPROVED plan + code file → no warning"
TD=$(create_project "formal")
cat > "$TD/.agentic/journal/plans/2026-03-19-F-0100-plan.md" << 'EOF'
# Plan

**Status**: APPROVED
EOF
invoke_hook "$TD" '{"tool_name":"Write","tool_input":{"file_path":"src/main.py"}}'
if has_warning; then
    fail "APPROVED plan + code file → no warning" "Got unexpected warning"
else
    pass "APPROVED plan + code file → no warning"
fi
rm -rf "$TD"

# --- Test 5: No plan files + code file → no warning ---
echo "Test 5: No plan files + code file → no warning"
TD=$(create_project "formal")
invoke_hook "$TD" '{"tool_name":"Write","tool_input":{"file_path":"src/main.py"}}'
if has_warning; then
    fail "No plan + code file → no warning" "Got unexpected warning"
else
    pass "No plan + code file → no warning"
fi
rm -rf "$TD"

# --- Test 6: plan_review_enabled: no → no warning ---
echo "Test 6: plan_review_enabled: no → no warning"
TD=$(create_project "discovery")
sed -i 's/- plan_review_enabled: yes/- plan_review_enabled: no/' "$TD/STACK.md"
cat > "$TD/.agentic/journal/plans/2026-03-19-F-0100-plan.md" << 'EOF'
# Plan

**Status**: DRAFT
EOF
invoke_hook "$TD" '{"tool_name":"Write","tool_input":{"file_path":"src/main.py"}}'
if has_warning; then
    fail "plan_review disabled → no warning" "Got unexpected warning"
else
    pass "plan_review disabled → no warning"
fi
rm -rf "$TD"

# --- Summary ---
echo ""
echo "═══════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed (of $TOTAL)"
echo "═══════════════════════════════════════════"

[[ $FAIL -eq 0 ]]
