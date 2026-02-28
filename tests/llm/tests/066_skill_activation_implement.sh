#!/usr/bin/env bash
# Description: Skills-primary: "implement feature" should activate implementing-features skill behavior
# Section: skills
# Category: Important
# Tests: LLM-066

# Setup with Formal profile (has spec/ and skills installed via install.sh)
setup_test_project "formal"

# Create acceptance criteria so the agent can proceed
mkdir -p "$TEST_PROJECT/spec/acceptance"
cat > "$TEST_PROJECT/spec/FEATURES.md" << 'EOF'
## F-0010: Search Feature

**Status**: planned
**Priority**: high

**Description**: Add search functionality to the app.

**Acceptance**: See `spec/acceptance/F-0010.md`
EOF

cat > "$TEST_PROJECT/spec/acceptance/F-0010.md" << 'EOF'
# F-0010: Search Feature

## Tests
- Search returns matching results
- Empty search returns all items

## Acceptance Criteria
- [ ] Search input field on main page
- [ ] Results update as user types
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add search feature spec" --quiet

# Ask to implement a feature
send_prompt "Implement F-0010, the search feature"

# Verify agent follows skill-driven workflow (not just raw coding)
FAILURES=0

# Agent should reference ag implement, acceptance criteria, or plan — skill workflow behavior
check_output_contains "ag implement\|acceptance\|criteria\|plan\|WIP\|spec/acceptance\|F-0010" \
    "Agent references workflow steps (ag implement, acceptance, plan, WIP)" || ((FAILURES++))

# Agent should NOT just start writing code without any workflow awareness
check_output_not_contains "^here.s the implementation\|^I.ll write the code\|^Let me code" \
    "Agent does NOT jump straight to code without workflow" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
