#!/usr/bin/env bash
# Tests for F-0226: Post-Merge Dogfooding (dogfood-sync.sh)
#
# Tests the sentinel-based drift detection between root and template
# instruction files, using mock fixtures with controlled drift.
#
# @feature F-0226

set -euo pipefail

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOGFOOD_SCRIPT="$PROJECT_ROOT/.agentic/lib/tools/dogfood-sync.sh"

# --- Helpers ---

setup_tmpdir() {
    TMPDIR=$(mktemp -d)
    mkdir -p "$TMPDIR/.agentic/lib/tools"
    mkdir -p "$TMPDIR/.agentic/lib/agents/claude"
    mkdir -p "$TMPDIR/.agentic/lib/agents/cursor"
    mkdir -p "$TMPDIR/.agentic/lib/agents/copilot"
    mkdir -p "$TMPDIR/.agentic/lib/agents/codex"
    mkdir -p "$TMPDIR/.agentic/lib/init"
    mkdir -p "$TMPDIR/.agentic/lib"
    mkdir -p "$TMPDIR/.github"
    mkdir -p "$TMPDIR/.codex"

    # Framework-dev guard file
    echo "# Framework Development" > "$TMPDIR/FRAMEWORK_DEVELOPMENT.md"

    # Minimal paths.sh stub
    cat > "$TMPDIR/.agentic/lib/paths.sh" << 'EOF'
# Stub paths
EOF

    # Copy the real dogfood-sync.sh
    cp "$DOGFOOD_SCRIPT" "$TMPDIR/.agentic/lib/tools/dogfood-sync.sh"
    chmod +x "$TMPDIR/.agentic/lib/tools/dogfood-sync.sh"
}

cleanup_tmpdir() {
    rm -rf "$TMPDIR"
}

assert_exit() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  ✓ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ✗ $desc (expected exit=$expected, got=$actual)"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -q "$needle" 2>/dev/null; then
        echo "  ✓ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ✗ $desc (expected to contain: '$needle')"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if ! echo "$haystack" | grep -q "$needle" 2>/dev/null; then
        echo "  ✓ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ✗ $desc (should NOT contain: '$needle')"
        FAIL=$((FAIL + 1))
    fi
}

# Create matching root and template files with given content
create_file_pair() {
    local root_path="$1" template_path="$2" content="$3"
    echo "$content" > "$TMPDIR/$root_path"
    echo "$content" > "$TMPDIR/$template_path"
}

# Stub instruction-sync.sh (returns given exit code)
create_instruction_sync_stub() {
    local exit_code="${1:-0}"
    cat > "$TMPDIR/.agentic/lib/tools/instruction-sync.sh" << STUBEOF
#!/usr/bin/env bash
exit $exit_code
STUBEOF
    chmod +x "$TMPDIR/.agentic/lib/tools/instruction-sync.sh"
}

# Stub memory-check.sh (returns given output)
create_memory_check_stub() {
    local output="${1:-Memory: OK (v0.60.0, 4/4 sentinels)}"
    cat > "$TMPDIR/.agentic/lib/tools/memory-check.sh" << STUBEOF
#!/usr/bin/env bash
echo "$output"
exit 0
STUBEOF
    chmod +x "$TMPDIR/.agentic/lib/tools/memory-check.sh"
}

# Standard content with all sentinels
FULL_CONTENT='# Claude Instructions

Quick Commands: `ag start` | `ag sync` | `ag implement` | `ag commit` | `ag done` | `ag plan` | `ag merge` | `ag flush` | `ag backlog` | `ag review` | `ag decompose` | `ag worktree` | `ag intent` | `ag formalize` | `ag kickoff` | `ag run` | `ag feedback`

## Core Rules

- show changes to human before committing
- PR by default: create branches
- Spec + code + tests + docs = done
- Shipped specs are contracts
- Keep changes small and scoped
- Plans are durable
- Multi-agent: check AGENTS.json
- Multi-session safety: before destructive ops

Token-efficient scripts:
- status.sh focus
- journal.sh
- blocker.sh
- feature.sh
- todo.sh'

# ═══════════════════════════════════════════════════════════════════
echo "=== Test 1: Clean state — all sentinels match ==="
# ═══════════════════════════════════════════════════════════════════
setup_tmpdir
create_instruction_sync_stub 0
create_memory_check_stub "Memory: OK (v0.60.0, 4/4 sentinels)"

# Create all 4 file pairs with identical content
create_file_pair "CLAUDE.md" ".agentic/lib/agents/claude/CLAUDE.md" "$FULL_CONTENT"
create_file_pair ".github/copilot-instructions.md" ".agentic/lib/agents/copilot/copilot-instructions.md" "$FULL_CONTENT"
create_file_pair ".codex/instructions.md" ".agentic/lib/agents/codex/codex-instructions.md" "$FULL_CONTENT"

# .cursorrules — reduced mode, only needs Quick Commands
CURSOR_CONTENT='Quick Commands: `ag start` | `ag sync` | `ag implement` | `ag commit` | `ag done` | `ag plan` | `ag merge` | `ag flush` | `ag backlog` | `ag review` | `ag decompose` | `ag worktree` | `ag intent` | `ag formalize` | `ag kickoff` | `ag run` | `ag feedback`'
create_file_pair ".cursorrules" ".agentic/lib/agents/cursor/cursorrules.txt" "$CURSOR_CONTENT"

exit_code=0
output=$(bash "$TMPDIR/.agentic/lib/tools/dogfood-sync.sh" 2>&1) || exit_code=$?
assert_exit "Clean state exits 0" 0 "$exit_code"
assert_contains "Reports no drift" "No drift detected" "$output"
cleanup_tmpdir

# ═══════════════════════════════════════════════════════════════════
echo ""
echo "=== Test 2: Missing sentinel — drift detected ==="
# ═══════════════════════════════════════════════════════════════════
setup_tmpdir
create_instruction_sync_stub 0
create_memory_check_stub "Memory: OK (v0.60.0, 4/4 sentinels)"

# Template has ag backlog, root does NOT
ROOT_NO_BACKLOG='# Claude Instructions
Quick Commands: `ag start` | `ag sync` | `ag implement` | `ag commit` | `ag done`

## Core Rules
- show changes to human before committing
- PR by default
- Spec + code + tests + docs = done
- Shipped specs are contracts
- Keep changes small and scoped
- Plans are durable
- Multi-agent: check
- Multi-session safety

Scripts:
- status.sh focus
- journal.sh
- blocker.sh
- feature.sh
- todo.sh'

echo "$FULL_CONTENT" > "$TMPDIR/.agentic/lib/agents/claude/CLAUDE.md"
echo "$ROOT_NO_BACKLOG" > "$TMPDIR/CLAUDE.md"

# Other pairs in sync
create_file_pair ".github/copilot-instructions.md" ".agentic/lib/agents/copilot/copilot-instructions.md" "$FULL_CONTENT"
create_file_pair ".codex/instructions.md" ".agentic/lib/agents/codex/codex-instructions.md" "$FULL_CONTENT"
create_file_pair ".cursorrules" ".agentic/lib/agents/cursor/cursorrules.txt" "$CURSOR_CONTENT"

exit_code=0
output=$(bash "$TMPDIR/.agentic/lib/tools/dogfood-sync.sh" 2>&1) || exit_code=$?
assert_exit "Missing sentinel exits 1" 1 "$exit_code"
assert_contains "Reports ag backlog drift" "ag backlog" "$output"
assert_contains "Shows drift count" "drift item" "$output"
cleanup_tmpdir

# ═══════════════════════════════════════════════════════════════════
echo ""
echo "=== Test 3: Suppressed sentinel — no drift reported ==="
# ═══════════════════════════════════════════════════════════════════
setup_tmpdir
create_instruction_sync_stub 0
create_memory_check_stub "Memory: OK (v0.60.0, 4/4 sentinels)"

# Root missing "ag backlog" but suppressed via comment
ROOT_SUPPRESSED='# Claude Instructions
Quick Commands: `ag start` | `ag sync` | `ag implement` | `ag commit` | `ag done` | `ag plan` | `ag merge` | `ag flush` | `ag review` | `ag decompose` | `ag worktree` | `ag intent` | `ag formalize` | `ag kickoff` | `ag run` | `ag feedback`
<!-- dogfood:ignore: ag backlog -->

## Core Rules
- show changes to human before committing
- PR by default
- Spec + code + tests + docs = done
- Shipped specs are contracts
- Keep changes small and scoped
- Plans are durable
- Multi-agent: check
- Multi-session safety

Scripts:
- status.sh focus
- journal.sh
- blocker.sh
- feature.sh
- todo.sh'

echo "$FULL_CONTENT" > "$TMPDIR/.agentic/lib/agents/claude/CLAUDE.md"
echo "$ROOT_SUPPRESSED" > "$TMPDIR/CLAUDE.md"

create_file_pair ".github/copilot-instructions.md" ".agentic/lib/agents/copilot/copilot-instructions.md" "$FULL_CONTENT"
create_file_pair ".codex/instructions.md" ".agentic/lib/agents/codex/codex-instructions.md" "$FULL_CONTENT"
create_file_pair ".cursorrules" ".agentic/lib/agents/cursor/cursorrules.txt" "$CURSOR_CONTENT"

exit_code=0
output=$(bash "$TMPDIR/.agentic/lib/tools/dogfood-sync.sh" 2>&1) || exit_code=$?
assert_exit "Suppressed sentinel exits 0" 0 "$exit_code"
assert_not_contains "Does not report ag backlog" "ag backlog" "$output"
cleanup_tmpdir

# ═══════════════════════════════════════════════════════════════════
echo ""
echo "=== Test 4: Reduced mode — .cursorrules only checks Quick Commands ==="
# ═══════════════════════════════════════════════════════════════════
setup_tmpdir
create_instruction_sync_stub 0
create_memory_check_stub "Memory: OK (v0.60.0, 4/4 sentinels)"

# All full-mode pairs in sync
create_file_pair "CLAUDE.md" ".agentic/lib/agents/claude/CLAUDE.md" "$FULL_CONTENT"
create_file_pair ".github/copilot-instructions.md" ".agentic/lib/agents/copilot/copilot-instructions.md" "$FULL_CONTENT"
create_file_pair ".codex/instructions.md" ".agentic/lib/agents/codex/codex-instructions.md" "$FULL_CONTENT"

# .cursorrules template has Core Rules but root doesn't — should NOT be flagged (reduced mode)
echo "$FULL_CONTENT" > "$TMPDIR/.agentic/lib/agents/cursor/cursorrules.txt"
echo "$CURSOR_CONTENT" > "$TMPDIR/.cursorrules"

exit_code=0
output=$(bash "$TMPDIR/.agentic/lib/tools/dogfood-sync.sh" 2>&1) || exit_code=$?
assert_exit "Reduced mode ignores Core Rules in .cursorrules" 0 "$exit_code"
assert_not_contains "No Core Rules drift for cursorrules" "Shipped specs are contracts" "$output"
assert_contains "Reports reduced mode" "reduced mode" "$output"
cleanup_tmpdir

# ═══════════════════════════════════════════════════════════════════
echo ""
echo "=== Test 5: Phase 1 delegation — instruction-sync.sh drift ==="
# ═══════════════════════════════════════════════════════════════════
setup_tmpdir
create_instruction_sync_stub 1  # drift detected
create_memory_check_stub "Memory: OK (v0.60.0, 4/4 sentinels)"

create_file_pair "CLAUDE.md" ".agentic/lib/agents/claude/CLAUDE.md" "$FULL_CONTENT"
create_file_pair ".github/copilot-instructions.md" ".agentic/lib/agents/copilot/copilot-instructions.md" "$FULL_CONTENT"
create_file_pair ".codex/instructions.md" ".agentic/lib/agents/codex/codex-instructions.md" "$FULL_CONTENT"
create_file_pair ".cursorrules" ".agentic/lib/agents/cursor/cursorrules.txt" "$CURSOR_CONTENT"

exit_code=0
output=$(bash "$TMPDIR/.agentic/lib/tools/dogfood-sync.sh" --brief 2>&1) || exit_code=$?
assert_exit "Phase 1 drift causes exit 1" 1 "$exit_code"
assert_contains "Reports Phase 1 drift" "Phase 1.*drift" "$output"
cleanup_tmpdir

# ═══════════════════════════════════════════════════════════════════
echo ""
echo "=== Test 6: Phase 3 delegation — stale memory-seed ==="
# ═══════════════════════════════════════════════════════════════════
setup_tmpdir
create_instruction_sync_stub 0
create_memory_check_stub "Memory: stale (v0.58.0 vs seed v0.60.0)"

create_file_pair "CLAUDE.md" ".agentic/lib/agents/claude/CLAUDE.md" "$FULL_CONTENT"
create_file_pair ".github/copilot-instructions.md" ".agentic/lib/agents/copilot/copilot-instructions.md" "$FULL_CONTENT"
create_file_pair ".codex/instructions.md" ".agentic/lib/agents/codex/codex-instructions.md" "$FULL_CONTENT"
create_file_pair ".cursorrules" ".agentic/lib/agents/cursor/cursorrules.txt" "$CURSOR_CONTENT"

exit_code=0
output=$(bash "$TMPDIR/.agentic/lib/tools/dogfood-sync.sh" --brief 2>&1) || exit_code=$?
assert_exit "Stale memory-seed causes exit 1" 1 "$exit_code"
assert_contains "Reports Phase 3 needs update" "Phase 3.*needs update" "$output"
cleanup_tmpdir

# ═══════════════════════════════════════════════════════════════════
echo ""
echo "=== Test 7: --brief output format ==="
# ═══════════════════════════════════════════════════════════════════
setup_tmpdir
create_instruction_sync_stub 0
create_memory_check_stub "Memory: OK (v0.60.0, 4/4 sentinels)"

create_file_pair "CLAUDE.md" ".agentic/lib/agents/claude/CLAUDE.md" "$FULL_CONTENT"
create_file_pair ".github/copilot-instructions.md" ".agentic/lib/agents/copilot/copilot-instructions.md" "$FULL_CONTENT"
create_file_pair ".codex/instructions.md" ".agentic/lib/agents/codex/codex-instructions.md" "$FULL_CONTENT"
create_file_pair ".cursorrules" ".agentic/lib/agents/cursor/cursorrules.txt" "$CURSOR_CONTENT"

output=$(bash "$TMPDIR/.agentic/lib/tools/dogfood-sync.sh" --brief 2>&1) || true
line_count=$(echo "$output" | grep -c "Phase" || true)
assert_exit "Brief mode has exactly 3 phase lines" 3 "$line_count"
assert_contains "Phase 1 line present" "Phase 1" "$output"
assert_contains "Phase 2 line present" "Phase 2" "$output"
assert_contains "Phase 3 line present" "Phase 3" "$output"
cleanup_tmpdir

# ═══════════════════════════════════════════════════════════════════
echo ""
echo "=== Test 8: Framework-dev guard — skips when not framework repo ==="
# ═══════════════════════════════════════════════════════════════════
setup_tmpdir
rm "$TMPDIR/FRAMEWORK_DEVELOPMENT.md"  # remove guard file

exit_code=0
output=$(bash "$TMPDIR/.agentic/lib/tools/dogfood-sync.sh" 2>&1) || exit_code=$?
assert_exit "Non-framework repo exits 0" 0 "$exit_code"
assert_contains "Reports skipped" "skipped" "$output"
cleanup_tmpdir

# ═══════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════"
echo "Results: $PASS passed, $FAIL failed"
echo "════════════════════════════"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
