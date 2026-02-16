#!/usr/bin/env bash
# Description: Agent should want spec/acceptance criteria for new features (Formal)
# Section: trigger
# Category: Critical
# Tests: LLM-010 (expanded)

# Setup with Formal profile
setup_test_project "formal"

# Create a minimal FEATURES.md
cat > "$TEST_PROJECT/spec/FEATURES.md" << 'EOF'
# Features

## F-0001: Basic Setup
**Status**: shipped
**Description**: Initial project setup
EOF

git -C "$TEST_PROJECT" add spec/FEATURES.md
git -C "$TEST_PROJECT" commit -m "Add features" --quiet

# Ask to implement a new feature without providing spec
send_prompt "Add a dark mode toggle to the settings page"

# Verify agent behavior
FAILURES=0

# Agent should ask about or mention specs/acceptance criteria
check_output_contains "spec\|acceptance\|criteria\|requirement\|F-\|feature.*id\|define" \
    "Agent mentions specs/acceptance/requirements" || ((FAILURES++))

# Agent should NOT just start coding without clarification
# Check for actual code blocks, not discussion of implementation
check_output_not_contains "^\`\`\`javascript\|^\`\`\`typescript\|^\`\`\`python\|function.*toggle\|class.*DarkMode\|const.*darkMode.*=" \
    "Agent does NOT immediately output code" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
