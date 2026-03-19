#!/usr/bin/env bash
# Description: ag commands still work after ag.sh decomposition into modules
# Section: infrastructure
# Category: Critical
# Tests: LLM-084

# Setup
setup_test_project "formal"

# Send implement command to verify it still works through sourced modules
send_prompt "implement feature F-0100"

# Verify agent behavior
FAILURES=0

# Agent should use ag implement (which is now sourced from commands/implement.sh)
check_output_contains "ag implement\|implement F-0100" "Agent references ag implement" || ((FAILURES++))

# The decomposition should be invisible to agents — no mention of modules
check_output_not_contains "commands/implement.sh\|COMMANDS_DIR\|sourced module" "Agent does not mention internal module structure" || ((FAILURES++))

exit $FAILURES
