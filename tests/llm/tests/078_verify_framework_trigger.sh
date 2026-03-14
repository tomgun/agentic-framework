#!/usr/bin/env bash
# Description: Agent suggests ag auto verify-framework when user wants to self-test the framework
# Section: trigger
# Category: Important
# Profile: formal
# Tests: LLM-078

# Setup - formal profile (framework development context)
setup_test_project "formal"

# User asks to verify the framework itself
send_prompt "I want to test the framework itself end-to-end by building a real project with it, to find any bugs"

FAILURES=0

# Agent should suggest ag auto verify-framework
check_output_contains "ag auto verify-framework\|verify-framework\|auto verify-framework" \
    "Agent routes to ag auto verify-framework command" || ((FAILURES++))

# Agent should mention scenario selection (--project or --all)
check_output_contains "project\|scenario\|todo.app\|--all" \
    "Agent mentions scenario selection" || ((FAILURES++))

# Agent should NOT suggest ag auto verify (that's the test-fix loop, not framework self-test)
check_output_not_contains "ag auto verify[^-]" \
    "Agent does NOT confuse verify-framework with verify" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
