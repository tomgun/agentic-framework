#!/usr/bin/env bash
# Description: Agent updates OVERVIEW.md when a design decision changes the project's current state
# Section: workflow
# Category: Important
# Tests: LLM-109

# Setup with discovery profile
setup_test_project "discovery"

# Create OVERVIEW.md showing current state that's about to change
cat > "$TEST_PROJECT/.agentic/OVERVIEW.md" << 'EOF'
# OVERVIEW.md

## What We're Building
A todo app with collaboration features.

## Who Uses This
### End User
- **Goals**: Manage tasks, share lists
- **Platform**: web

## Tech Stack & Architecture
- **Frontend**: React SPA
- **Backend**: Express + Node.js
- **Database**: SQLite

## Phases
### Phase 1 — MVP
- Basic CRUD, single user

### Phase 2
- Collaboration, sharing

## Guiding Principles
- Keep it simple, ship fast
EOF

mkdir -p "$TEST_PROJECT/.agentic/journal"
cat > "$TEST_PROJECT/.agentic/journal/JOURNAL.md" << 'EOF'
# JOURNAL

## Session Log
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "init" --quiet

# Tell the agent about a decision that changes current state
send_prompt "We've decided to switch from SQLite to PostgreSQL and also add a mobile app in Phase 2 using React Native. Please update the project docs to reflect these decisions."

FAILURES=0

# Agent should update OVERVIEW.md (current state)
check_output_contains "OVERVIEW\|overview\|Tech Stack\|PostgreSQL\|React Native" \
    "Agent updates OVERVIEW.md with new current state" || ((FAILURES++))

# Agent should log the decision in journal (history)
check_output_contains "journal\|--decision\|decision.*log\|log.*decision" \
    "Agent logs decision in JOURNAL.md" || ((FAILURES++))

# Agent should NOT just update docs without capturing the reasoning
check_output_contains "reason\|because\|JSONB\|mobile\|why\|alternative\|SQLite" \
    "Agent captures reasoning, not just the outcome" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
