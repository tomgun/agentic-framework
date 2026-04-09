#!/usr/bin/env bash
# Description: Intelligence: agent should be aware of ag intel commands for pattern/quality checks
# Section: intelligence
# Category: Important
# Tests: LLM-107

# Setup with Discovery profile
setup_test_project "discovery"

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "init" --quiet

# Ask about intelligence/patterns/quality
send_prompt "What intelligence and quality checks are available in this project?"

FAILURES=0

# Agent should reference ag intel subcommands
check_output_contains "ag intel\|patterns\|project.memory\|bootstrap\|quality.check\|intel check\|intel learn" \
    "Agent references ag intel commands" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
