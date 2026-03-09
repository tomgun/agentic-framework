#!/usr/bin/env bash
# Description: Agent should output dashboard verbatim on session start
# Section: session
# Category: Critical
# Tests: LLM-001

# Setup
setup_test_project "discovery"

# Send simple greeting
send_prompt "hi"

# Verify agent behavior
FAILURES=0

# Dashboard format: must contain the rendered dashboard borders and sections
check_output_contains "━━━━━━━━━━" "Dashboard contains border lines" || ((FAILURES++))
check_output_contains "📋 Last session" "Dashboard has Last session line" || ((FAILURES++))
check_output_contains "🎯 Focus" "Dashboard has Focus line" || ((FAILURES++))
check_output_contains "📌 Backlog" "Dashboard has Backlog section" || ((FAILURES++))
check_output_contains "⚡ Next steps" "Dashboard has Next steps section" || ((FAILURES++))
check_output_contains "💡 Tip:" "Dashboard has Tip line" || ((FAILURES++))

# No preamble or reformatting
check_output_not_contains "let me check\|let me read\|starting a new session\|I'll check\|I'll read\|checking the\|reading the" "No preamble narration before dashboard" || ((FAILURES++))
check_output_not_contains "Welcome back\|Here's where we are\|here is the\|here's the current" "No chatty greeting replacing the dashboard" || ((FAILURES++))

# No WIP created for greeting
check_file_not_exists ".agentic/session/WIP.md" "No WIP created for simple greeting" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
