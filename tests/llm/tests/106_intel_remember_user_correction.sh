#!/usr/bin/env bash
# Description: Intelligence: user correction should trigger ag intel remember
# Section: intelligence
# Category: Critical
# Tests: LLM-106

# Setup with Discovery profile
setup_test_project "discovery"

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "init" --quiet

# Simulate a correction scenario — user says "don't do X"
send_prompt "Don't use global variables in this project, always pass as function parameters"

FAILURES=0

# Agent should reference ag intel remember to capture the correction
check_output_contains "ag intel remember\|intel remember\|cerebrum\|capture.*preference\|remember.*correction" \
    "Agent references ag intel remember for user correction" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
