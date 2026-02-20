#!/usr/bin/env bash
# S10: WIP lifecycle referenced in ALL instruction files
# Every instruction template must mention both wip.sh check (session start)
# AND wip.sh start or "creates WIP" (work start) to prevent work loss.
set -euo pipefail
source "$(dirname "$0")/../lib/helpers.sh"

section_header "S10: WIP start + check in all instruction files"

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

    # Must reference wip.sh check (session start / commit gate)
    if grep -q "wip\.sh check\|WIP\.md.*BLOCK" "$file"; then
        pass_test "$name: WIP check (session start / commit gate) referenced"
    else
        fail_test "$name: WIP check referenced" \
            "Must mention 'wip.sh check' or WIP.md BLOCK for session start or commit gating"
    fi

    # Must reference WIP creation (ag implement creates WIP, or wip.sh start)
    if grep -q "creates WIP\|wip\.sh start" "$file"; then
        pass_test "$name: WIP creation (ag implement / wip.sh start) referenced"
    else
        fail_test "$name: WIP creation referenced" \
            "Must mention 'creates WIP' or 'wip.sh start' to ensure WIP tracking begins before coding"
    fi
done

print_summary
