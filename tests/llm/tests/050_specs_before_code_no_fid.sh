#!/usr/bin/env bash
# Description: Agent should create specs before coding when user gives no feature ID (Formal)
# Section: trigger
# Category: Critical
# Tests: LLM-050

# Setup with Formal profile
setup_test_project "formal"

# Ensure spec directories exist but are empty (no pre-existing specs)
mkdir -p "$TEST_PROJECT/spec/contracts" "$TEST_PROJECT/spec/acceptance"

# Create a minimal FEATURES.md with one existing feature
cat > "$TEST_PROJECT/spec/FEATURES.md" << 'EOF'
# FEATURES.md

## F-001: User Authentication
- Status: shipped

## Summary
| Category | Shipped | Total |
|----------|---------|-------|
| Total    | 1       | 1     |
EOF

git -C "$TEST_PROJECT" add spec/
git -C "$TEST_PROJECT" commit -m "Add initial features" --quiet

# User asks to build something WITHOUT providing a feature ID
send_prompt "Add a tip of the day feature to the session start dashboard"

# Verify agent behavior
FAILURES=0

# Agent should NOT immediately write implementation code
check_output_not_contains "def.*tip_of_the_day\|function.*tipOfDay\|tips.*=.*\[\|echo.*Tip:" \
    "Agent does NOT immediately write implementation code" || ((FAILURES++))

# Agent should mention acceptance criteria/contracts, specs, or feature ID creation
check_output_contains "acceptance\|contract\|spec/contracts\|spec/acceptance\|F-[0-9]\{4\}\|feature.*ID\|FEATURES.md\|criteria" \
    "Agent mentions acceptance criteria/contracts or feature ID creation" || ((FAILURES++))

# Agent should mention ag plan or ag implement (the proper workflow)
check_output_contains "ag plan\|ag implement\|plan.*review" \
    "Agent mentions ag plan or ag implement workflow" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
