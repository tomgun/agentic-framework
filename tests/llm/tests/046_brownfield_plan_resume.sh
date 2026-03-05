#!/usr/bin/env bash
# Description: Agent should detect and suggest resuming an active brownfield spec plan on session start
# Section: brownfield
# Category: Important
# Tests: LLM-046

# Setup with Formal profile
setup_test_project "formal"

# Create an in-progress brownfield specs plan
mkdir -p "$TEST_PROJECT/.agentic/journal/plans"
cat > "$TEST_PROJECT/.agentic/journal/plans/brownfield-specs-plan.md" << 'EOF'
# Brownfield Spec Generation Plan

**Status**: APPROVED
**Created**: 2026-02-08

## Domains

- [x] Frontend Web App (type: frontend, ~12 features)
- [ ] Backend API (type: backend, ~10 features)
- [ ] Mobile App (type: mobile, ~5 features)

## Approach
- Work domains in priority order (most user-facing first)
- Cross-match frontend features with backend endpoints
EOF

git -C "$TEST_PROJECT" add .agentic/journal/plans/
git -C "$TEST_PROJECT" commit -m "Add brownfield specs plan" --quiet

# Start a session — agent should notice the active plan
send_prompt "Hi, starting a new session. What should we work on?"

# Verify agent behavior
FAILURES=0

# Agent should mention the brownfield spec plan or domain progress
check_output_contains "spec.*plan\|brownfield\|domain.*completed\|1.*3\|backend.*API\|ag specs\|resume" \
    "Agent notices the active brownfield specs plan" || ((FAILURES++))

# Agent should know that Frontend is done and Backend/Mobile remain
check_output_contains "frontend.*done\|frontend.*completed\|backend\|mobile\|remaining\|next.*domain\|uncompleted" \
    "Agent knows which domains are done vs remaining" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
