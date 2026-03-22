#!/usr/bin/env bash
# Description: Agent uses ag flush --features after completing a feature via ag done
# Section: trigger
# Category: Important
# Tests: LLM-076

# Setup with Formal profile
setup_test_project "formal"

mkdir -p "$TEST_PROJECT/.agentic/spec/contracts" "$TEST_PROJECT/.agentic/spec/acceptance"
cat >> "$TEST_PROJECT/.agentic/spec/FEATURES.md" << 'EOF'

### F-0100: Cache Layer
- **Status**: in_progress
- **Category**: Core
- **Description**: Add caching to API responses
EOF

cat > "$TEST_PROJECT/.agentic/spec/acceptance/F-0100.md" << 'EOF'
# F-0100: Cache Layer

## Acceptance Criteria

- [x] AC-001: API responses cached for 5 minutes
- [x] AC-002: Cache invalidated on write operations
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add F-0100 in progress" --quiet

# User says feature is done and merged
send_prompt "F-0100 PR was merged. Mark it as done and flush the state."

FAILURES=0

# Agent should reference ag flush with --features flag
check_output_contains "ag flush\|flush.*features\|flush.*state" \
    "Agent mentions ag flush for state files" || ((FAILURES++))

# Agent should mention ag done or completing the feature
check_output_contains "ag done\|done\|complete\|shipped\|mark.*done" \
    "Agent references completion workflow" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
