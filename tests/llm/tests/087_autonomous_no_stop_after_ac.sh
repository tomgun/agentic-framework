#!/usr/bin/env bash
# Description: Agent with autonomous_formal profile continues to planning after AC creation
# Section: workflow
# Category: Important
# Tests: LLM-087

# Setup with autonomous_formal profile
setup_test_project "autonomous_formal"

# Ensure plan_review settings
grep -q "plan_review_enabled" "$TEST_PROJECT/STACK.md" || {
    echo "- plan_review_enabled: yes" >> "$TEST_PROJECT/STACK.md"
}
grep -q "plan_review_convergence" "$TEST_PROJECT/STACK.md" || {
    echo "- plan_review_convergence: auto" >> "$TEST_PROJECT/STACK.md"
}

# Create FEATURES.md entry but NO AC file and NO plan
mkdir -p "$TEST_PROJECT/.agentic/spec"
cat > "$TEST_PROJECT/.agentic/spec/FEATURES.md" << 'EOF'
# Features

| ID | Name | Status |
|----|------|--------|
| F-0100 | User Profile Page | planned |
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add F-0100 to features" --quiet

# Ask to implement — agent should create AC AND continue to planning
send_prompt "implement F-0100"

# Verify agent behavior
FAILURES=0

# Agent should mention acceptance criteria (needs to create them)
check_output_contains "acceptance\|criteria\|AC\|spec" \
    "Agent mentions acceptance criteria" || ((FAILURES++))

# Agent should also mention planning (not stop after AC)
check_output_contains "plan\|planning\|design\|ag plan" \
    "Agent mentions planning workflow" || ((FAILURES++))

# Agent should NOT just stop after showing AC
check_output_not_contains "review the acceptance criteria and let me know\|please review.*criteria\|take a look.*criteria" \
    "Agent does NOT stop and wait for AC review" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
