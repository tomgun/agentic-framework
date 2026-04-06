#!/usr/bin/env bash
# Description: Agent logs decisions with reasoning, alternatives, and assumptions — not just outcomes
# Section: workflow
# Category: Important
# Tests: LLM-108

# Setup with discovery profile
setup_test_project "discovery"

# Create OVERVIEW.md with tech stack section
cat > "$TEST_PROJECT/.agentic/OVERVIEW.md" << 'EOF'
# OVERVIEW.md

## What We're Building
A price comparison web service.

## Tech Stack & Architecture
- **Backend**: undecided
- **Database**: undecided
- **Frontend**: React

## Guiding Principles
- Keep it simple
EOF

mkdir -p "$TEST_PROJECT/.agentic/journal"
cat > "$TEST_PROJECT/.agentic/journal/JOURNAL.md" << 'EOF'
# JOURNAL

## Session Log
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "init" --quiet

# Ask about a technical decision
send_prompt "We need to pick a database. I'm thinking PostgreSQL because we need JSONB for flexible product schemas. SQLite would be simpler but can't do JSON queries efficiently. What do you think? Let's go with PostgreSQL and log this decision."

FAILURES=0

# Agent should use journal.sh with --decision flag
check_output_contains "journal.sh\|--decision\|Decision.*PostgreSQL" \
    "Agent uses journal.sh --decision or mentions logging the decision" || ((FAILURES++))

# Agent should include reasoning in the journal entry — not just "chose PostgreSQL"
check_output_contains "JSONB\|JSON.*quer\|flexible.*schema\|alternative\|SQLite\|reason\|consider" \
    "Agent includes reasoning/alternatives in journal entry" || ((FAILURES++))

# Agent should also update OVERVIEW.md tech stack
check_output_contains "OVERVIEW\|Tech Stack\|update.*overview\|overview.*update" \
    "Agent updates OVERVIEW.md to reflect decision" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
