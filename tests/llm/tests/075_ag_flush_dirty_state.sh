#!/usr/bin/env bash
# Description: Agent runs ag flush (not full PR) when told state files are dirty
# Section: trigger
# Category: Important
# Tests: LLM-075

# Setup with Formal profile
setup_test_project "formal"

# Create dirty state files (STATUS.md modified but not committed)
cat > "$TEST_PROJECT/.agentic/STATUS.md" << 'EOF'
## Current focus
- Implementing F-0100

## Progress
- Core logic complete
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Initial state" --quiet

# Now modify STATUS.md to make it dirty
echo "- Tests passing" >> "$TEST_PROJECT/.agentic/STATUS.md"

# User mentions dirty state files
send_prompt "My state files are dirty after updating the backlog. How should I commit them?"

FAILURES=0

# Agent should suggest ag flush (not a full PR workflow)
check_output_contains "ag flush\|state.commit\|flush" \
    "Agent suggests ag flush for state files" || ((FAILURES++))

# Agent should NOT suggest creating a PR or feature branch for state-only changes
check_output_not_contains "gh pr create\|git checkout -b\|feature branch" \
    "Agent does NOT suggest PR workflow for state files" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
