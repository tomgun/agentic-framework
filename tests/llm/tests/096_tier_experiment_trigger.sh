#!/usr/bin/env bash
# Description: Agent routes complexity tier experiment requests to ag auto tier-experiment
# Section: trigger
# Category: Important
# Tests: LLM-096, DEV-0243

setup_test_project "formal"

send_prompt "I want to run an empirical comparison of the discovery, formal, and autonomous_formal profiles to see which produces better outcomes when building a feature"

FAILURES=0

check_output_contains "ag auto tier-experiment\|tier-experiment\|tier_experiment" \
    "Agent routes to ag auto tier-experiment" || ((FAILURES++))

check_output_not_contains "ag auto verify-framework" \
    "Agent does NOT confuse with verify-framework" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
