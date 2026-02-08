#!/usr/bin/env bash
# Description: Agent should notice when STATUS.md is clearly outdated (version/content mismatch) and offer to update it
# Section: artifact-maintenance
# Category: Critical
# Profile: core
# Tests: LLM-037

# Setup - Core profile
setup_test_project "core"

# Create a STATUS.md that references v0.5.0 (very outdated)
cat > "$TEST_PROJECT/STATUS.md" << 'EOF'
# Project Status

## Version: 0.5.0

## Current Focus
Implementing user login form

## In Progress
- Login form component
- Basic password validation

## Next Steps
- Add email verification
- Connect to auth API

## Blockers
- None
EOF

# Create VERSION file showing actual version is 0.20.0
echo "0.20.0" > "$TEST_PROJECT/VERSION"

# Create CHANGELOG showing the project is far ahead
cat > "$TEST_PROJECT/CHANGELOG.md" << 'EOF'
# Changelog

## [0.20.0] - 2026-02-05
- Payment gateway fully integrated
- Order management system complete
- Admin dashboard shipped

## [0.15.0] - 2026-01-20
- User authentication complete
- Product catalog launched

## [0.5.0] - 2025-12-01
- Initial user login form
EOF

# Create journal showing recent work
mkdir -p "$TEST_PROJECT/.agentic-journal"
cat > "$TEST_PROJECT/.agentic-journal/JOURNAL.md" << 'EOF'
# Development Journal

### Session: 2026-02-04
- Completed admin dashboard
- All payment tests passing
- Next: monitoring and analytics
EOF

git -C "$TEST_PROJECT" add STATUS.md VERSION CHANGELOG.md .agentic-journal/JOURNAL.md
git -C "$TEST_PROJECT" commit -m "Add project files with stale status" --quiet

# Start a new session
send_prompt "Hi, let's start a new session. What should we work on?"

# Verify agent behavior
FAILURES=0

# Agent should detect the staleness
check_output_contains "outdated\|stale\|out.of.date\|mismatch\|update.*STATUS\|STATUS.*old\|doesn't match\|inconsistent\|v\?0\.5\|0\.20" \
    "Agent detects STATUS.md is stale" || ((FAILURES++))

# Agent should reference STATUS or need to update
check_output_contains "STATUS\|status\|update\|refresh\|current" \
    "Agent mentions STATUS needs attention" || ((FAILURES++))

# Agent should NOT follow the stale advice as current guidance
check_output_not_contains "should work on.*login\|let's.*password validation\|next.*email verification\|focus on.*login form" \
    "Agent does NOT follow stale STATUS advice" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
