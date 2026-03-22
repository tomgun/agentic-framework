#!/usr/bin/env bash
# Description: Post-merge dance: agent runs ag done, bumps VERSION, flushes state after PR merge
# Section: workflow
# Category: Critical
# Tests: LLM-092

# Setup with formal profile
setup_test_project "formal"

# Override STACK.md to formal profile
cat > "$TEST_PROJECT/STACK.md" << 'EOF'
# Stack

## Settings
- profile: formal
- acceptance_criteria: blocking
- plan_review_enabled: yes
- git_workflow: pull_request

## Tech Stack
- language: Python
- framework: FastAPI
EOF

# Create completed feature state
mkdir -p "$TEST_PROJECT/.agentic/spec/contracts" "$TEST_PROJECT/.agentic/spec/acceptance"
cat > "$TEST_PROJECT/.agentic/spec/FEATURES.md" << 'EOF'
# Features

| ID | Name | Status |
|----|------|--------|
| F-0100 | Payment Processing | in_progress |
EOF

cat > "$TEST_PROJECT/.agentic/spec/acceptance/F-0100.md" << 'EOF'
# F-0100: Payment Processing

## Acceptance Criteria
- [x] AC-001: Process payments via Stripe API
- [x] AC-002: Handle webhook events for payment status
- [x] AC-003: Generate receipts for successful payments
EOF

# Create VERSION file
echo "0.42.0" > "$TEST_PROJECT/VERSION"

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Feature F-0100 in progress" --quiet

# Tell agent PR was merged — should trigger post-merge dance
send_prompt "F-0100 PR just merged to main. What are the post-merge steps? Remember to use ag done and bump the VERSION."

# Verify agent behavior
FAILURES=0

# Agent should mention ag done or the completion workflow
check_output_contains "ag done\|ag.*done\|completion\|post.merge\|mark.*done\|mark.*complete" \
    "Agent mentions ag done or completion workflow" || ((FAILURES++))

# Agent should mention VERSION bump
check_output_contains "VERSION\|version\|bump\|patch\|0\.42" \
    "Agent mentions VERSION bump" || ((FAILURES++))

# Agent should mention flushing/committing state or updating artifacts
check_output_contains "flush\|ag flush\|commit.*state\|state.*commit\|JOURNAL\|STATUS\|artifact" \
    "Agent mentions flushing or updating state artifacts" || ((FAILURES++))

# Agent should mention marking feature as shipped
check_output_contains "shipped\|feature.sh\|FEATURES\|status.*shipped\|mark.*shipped" \
    "Agent mentions marking feature as shipped" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
