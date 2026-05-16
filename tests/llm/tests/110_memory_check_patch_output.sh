#!/usr/bin/env bash
# Description: Agent applies targeted Edit calls from memory-check PATCH blocks (T-0023)
# Section: memory
# Category: Critical
# Tests: LLM-110

# Setup
setup_test_project "discovery"

# Seed the test project's MEMORY.md with an older seed version so memory-check
# detects stale state and emits PATCH blocks the agent must consume.
PROJECT_HASH=$(echo "$TEST_PROJECT" | tr '/' '-')
MEMORY_DIR="$HOME/.claude/projects/${PROJECT_HASH}/memory"
mkdir -p "$MEMORY_DIR"
cat > "$MEMORY_DIR/MEMORY.md" <<'EOF'
# Project Memory
<!-- memory-seed v0.50.0 -->

## Key Commands
- ag start
- ag commit

## Trigger Words
- "build" → plan first

# project-specific entries (preserve these)
- We use pnpm not npm
- Database is Postgres 16
EOF

# Bump the project's seed file to a newer version with section anchors so the
# diff produces multiple PATCH blocks
SEED="$TEST_PROJECT/.agentic/lib/init/memory-seed.md"
if [ -f "$SEED" ]; then
    # Replace version marker
    sed -i.bak 's/memory-seed v[0-9]*\.[0-9]*\.[0-9]*/memory-seed v0.99.0/' "$SEED" 2>/dev/null
    rm -f "${SEED}.bak"
fi

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "test setup: stale memory + bumped seed" --quiet

# Prompt agent in a way that surfaces the memory-check output
send_prompt "Run memory-check and apply any patches it produces. Do not re-read the whole memory-seed; apply only the structured PATCH blocks."

FAILURES=0

# Agent must explicitly reference the PATCH-block format (proves it consumed
# the structured output, not just "Edit'd the file generically"). Require
# the literal token PATCH together with a kind label.
check_output_contains "PATCH [0-9]+/[0-9]+\|PATCH N/N" \
    "Agent references the numbered PATCH N/N format" || ((FAILURES++))

check_output_contains "MODIFY\|ADD\|REMOVE" \
    "Agent references at least one kind label (ADD/REMOVE/MODIFY)" || ((FAILURES++))

# Agent must use targeted Edit semantics — old_string + new_string. A
# generic "I'll edit the file" without old/new_string would silently pass
# the old version of this test.
check_output_contains "old_string.*new_string\|new_string.*old_string\|Edit.*MEMORY.md" \
    "Agent produces Edit calls referencing old_string/new_string" || ((FAILURES++))

# Anti-pattern: agent should NOT propose wholesale re-read
check_output_not_contains "re-read the entire memory-seed\|read all of memory-seed\|wholesale rewrite\|replace the entire MEMORY.md\|rewrite MEMORY.md from scratch" \
    "Agent avoids whole-file re-read anti-pattern" || ((FAILURES++))

# Agent must explicitly acknowledge preserving project-specific entries
check_output_contains "preserve.*project\|keep.*project-specific\|pnpm\|Postgres" \
    "Agent acknowledges project-specific MEMORY.md content to preserve" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
