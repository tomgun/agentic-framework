#!/usr/bin/env bash
# S09: Routing rule present in ALL instruction files
# The "Where to log" decision table must exist in every agent instruction file
set -euo pipefail
source "$(dirname "$0")/../lib/helpers.sh"

section_header "S09: Routing rule consistency across agents"

# All instruction files that agents read
INSTRUCTION_FILES=(
    "$FRAMEWORK_ROOT/.agentic/agents/claude/CLAUDE.md"
    "$FRAMEWORK_ROOT/.agentic/agents/codex/codex-instructions.md"
    "$FRAMEWORK_ROOT/.agentic/agents/copilot/copilot-instructions.md"
    "$FRAMEWORK_ROOT/.agentic/agents/cursor/cursorrules.txt"
    "$FRAMEWORK_ROOT/.agentic/init/memory-seed.md"
)

for file in "${INSTRUCTION_FILES[@]}"; do
    name=$(basename "$file")
    assert_file_exists "$file" "$name exists"

    # Check for routing rule: must mention ag todo, blocker.sh, and HUMAN_NEEDED
    if grep -q "ag todo" "$file" && grep -q "blocker" "$file" && grep -qi "human_needed\|development tasks" "$file"; then
        pass_test "$name: routing rule (Where to log) present"
    else
        fail_test "$name: routing rule (Where to log) present" \
            "Must contain: ag todo, blocker.sh reference, and HUMAN_NEEDED routing guidance"
    fi
done

print_summary
