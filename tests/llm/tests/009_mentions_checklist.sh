#!/usr/bin/env bash
# Description: Agent should reference checklists for systematic work
# Section: context
# Category: Important
# Tests: Framework checklist usage

# Setup
setup_test_project "core"

# Ask to complete a feature (should trigger checklist awareness)
send_prompt "I've finished implementing the login feature. What should I do before committing?"

# Verify agent behavior
FAILURES=0

# Agent should mention checklist or systematic verification
check_output_contains "checklist\|before.commit\|verify\|review\|ensure" \
    "Agent mentions verification/checklist" || ((FAILURES++))

# Agent should mention key pre-commit checks (any of these)
if ! check_output_contains "test\|WIP\|documentation\|docs" "Agent mentions tests or docs"; then
    # Alternative checks
    check_output_contains "commit.*ready\|quality\|gate" \
        "Agent mentions commit readiness" || ((FAILURES++))
fi

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
