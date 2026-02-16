#!/usr/bin/env bash
# Description: Agent should recommend git worktree or branch isolation for parallel agent work
# Section: multi-agent
# Category: Normal
# Profile: formal
# Tests: LLM-034

# Setup - Formal profile
setup_test_project "formal"

# Ask about parallel agent workflows
send_prompt "How can two AI agents work on different features at the same time without conflicts?"

# Verify agent behavior
FAILURES=0

# Agent should mention worktree or branch isolation strategies
check_output_contains "worktree\|git worktree\|parallel\|isolation\|separate.*branch\|different.*branch\|concurrent" \
    "Agent suggests worktree or branch isolation for parallel work" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
