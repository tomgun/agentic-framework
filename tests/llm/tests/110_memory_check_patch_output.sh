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

# The agent should recognize the PATCH block format and produce targeted edits
check_output_contains "PATCH\|Edit\|old_string\|MODIFY\|ADD\|REMOVE" \
    "Agent references PATCH-block semantics" || ((FAILURES++))

# Agent should NOT propose wholesale re-read (the anti-pattern we're fixing)
check_output_not_contains "re-read the entire memory-seed\|read all of memory-seed\|wholesale rewrite\|replace the entire MEMORY.md" \
    "Agent avoids whole-file re-read anti-pattern" || ((FAILURES++))

# Project-specific entries should not be touched
check_output_not_contains "remove pnpm\|delete Postgres\|drop project-specific" \
    "Agent preserves project-specific MEMORY.md entries" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
