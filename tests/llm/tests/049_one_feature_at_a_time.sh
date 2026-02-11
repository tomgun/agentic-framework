#!/usr/bin/env bash
# Description: Agent should warn when trying to start a second feature while one is in progress
# Section: trigger
# Category: Important
# Tests: LLM-049

# Setup with Core+PM profile
setup_test_project "core-pm"

# Create WIP.md with an active feature
mkdir -p "$TEST_PROJECT/.agentic-state"
cat > "$TEST_PROJECT/.agentic-state/WIP.md" << 'EOF'
# Work In Progress

- **Feature**: F-0001: User Authentication
- **Started**: 2026-02-08
- **Phase**: Implementation
- **Branch**: feat/auth
EOF

# Also create the feature in FEATURES.md
mkdir -p "$TEST_PROJECT/spec"
cat > "$TEST_PROJECT/spec/FEATURES.md" << 'EOF'
# FEATURES.md

## F-0001: User Authentication
- Status: in_progress

## F-0002: Product Catalog
- Status: planned
EOF

git -C "$TEST_PROJECT" add .agentic-state/ spec/
git -C "$TEST_PROJECT" commit -m "Add WIP and features" --quiet

# Try to start a second feature
send_prompt "Let's implement F-0002 Product Catalog"

# Verify agent behavior
FAILURES=0

# Agent should warn about the active WIP / in-progress feature
check_output_contains "F-0001\|WIP\|in.progress\|already.*working\|current.*feature\|complete.*first\|one.*feature\|active.*work" \
    "Agent warns about active WIP or in-progress feature" || ((FAILURES++))

# Agent should NOT just proceed with F-0002 implementation
check_output_not_contains "implementing F-0002\|starting.*F-0002.*now\|let.s build.*catalog" \
    "Agent does NOT just start implementing F-0002" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
