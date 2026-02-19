#!/usr/bin/env bash
# S07: Memory-seed ↔ CLAUDE.md consistency
# Both files should contain the same 7 trigger categories and 5 script references
set -euo pipefail
source "$(dirname "$0")/../lib/helpers.sh"

section_header "S07: Memory-seed ↔ CLAUDE.md consistency"

MEMORY_SEED="$FRAMEWORK_ROOT/.agentic/init/memory-seed.md"
CLAUDE_MD="$FRAMEWORK_ROOT/.agentic/agents/claude/CLAUDE.md"

assert_file_exists "$MEMORY_SEED" "memory-seed.md exists"
assert_file_exists "$CLAUDE_MD" "CLAUDE.md template exists"

# Check 7 trigger categories exist in BOTH files

# 1. Build/implement → spec first
for file in "$MEMORY_SEED" "$CLAUDE_MD"; do
    name=$(basename "$file")
    if grep -qi "build\|implement\|create" "$file" && grep -qi "spec\|acceptance\|criteria" "$file"; then
        pass_test "$name: build → spec-first trigger present"
    else
        fail_test "$name: build → spec-first trigger present"
    fi
done

# 2. Fix/debug → test first
for file in "$MEMORY_SEED" "$CLAUDE_MD"; do
    name=$(basename "$file")
    if grep -qi "fix\|debug\|repair" "$file" && grep -qi "test.*first\|failing.*test\|test.*reproduc" "$file"; then
        pass_test "$name: fix → test-first trigger present"
    else
        fail_test "$name: fix → test-first trigger present"
    fi
done

# 3. Commit/push → check WIP
for file in "$MEMORY_SEED" "$CLAUDE_MD"; do
    name=$(basename "$file")
    if grep -qi "commit\|push\|ship" "$file" && grep -qi "WIP" "$file"; then
        pass_test "$name: commit → check WIP trigger present"
    else
        fail_test "$name: commit → check WIP trigger present"
    fi
done

# 4. Done/complete → ag done
for file in "$MEMORY_SEED" "$CLAUDE_MD"; do
    name=$(basename "$file")
    if grep -qi "done\|complete\|finished" "$file" && grep -qi "ag done" "$file"; then
        pass_test "$name: done → ag done trigger present"
    else
        fail_test "$name: done → ag done trigger present"
    fi
done

# 5. Too big → break into smaller
for file in "$MEMORY_SEED" "$CLAUDE_MD"; do
    name=$(basename "$file")
    if grep -qi "TOO BIG\|break.*smaller\|3-5.*task\|5-10 files" "$file"; then
        pass_test "$name: too-big → break-down trigger present"
    else
        fail_test "$name: too-big → break-down trigger present"
    fi
done

# 6. Plan mode exit → save plan + review
for file in "$MEMORY_SEED" "$CLAUDE_MD"; do
    name=$(basename "$file")
    if grep -qi "plan.*mode\|planning.*complete\|plan.*approved" "$file" && grep -qi "agentic-journal/plans\|ag plan --save" "$file"; then
        pass_test "$name: plan-mode-exit → save + review trigger present"
    else
        fail_test "$name: plan-mode-exit → save + review trigger present"
    fi
done

# 7. Todo/idea → ag todo
for file in "$MEMORY_SEED" "$CLAUDE_MD"; do
    name=$(basename "$file")
    if grep -qi "todo\|idea\|remember" "$file" && grep -qi "ag todo\|todo\.sh" "$file"; then
        pass_test "$name: todo/idea → ag todo trigger present"
    else
        fail_test "$name: todo/idea → ag todo trigger present"
    fi
done

# Check 5 token-efficient script references in BOTH files
for script in "journal.sh" "status.sh" "blocker.sh" "feature.sh" "todo.sh"; do
    for file in "$MEMORY_SEED" "$CLAUDE_MD"; do
        name=$(basename "$file")
        if grep -q "$script" "$file"; then
            pass_test "$name: references $script"
        else
            fail_test "$name: references $script"
        fi
    done
done

print_summary
