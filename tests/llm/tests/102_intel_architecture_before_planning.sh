#!/usr/bin/env bash
# Description: Phase intelligence: "plan a feature" should reference ag intel architecture for context
# Section: intelligence
# Category: Important
# Tests: LLM-102

# Setup with Formal profile
setup_test_project "formal"

# Create ADR and NFR files so intel has data to surface
mkdir -p "$TEST_PROJECT/spec/adr" "$TEST_PROJECT/spec/contracts"
cat > "$TEST_PROJECT/spec/adr/ADR-001-modular.md" << 'EOF'
# ADR-001: Modular Architecture

Status: accepted

## Decision
Use modular architecture with clear component boundaries.
EOF

cat > "$TEST_PROJECT/spec/NFR.md" << 'EOF'
# Non-Functional Requirements

## NFR-0001: Performance
All API responses must complete in under 200ms.
EOF

cat > "$TEST_PROJECT/spec/FEATURES.md" << 'EOF'
# Features

## F-0050: Search API

**Status**: planned
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Setup feature context" --quiet

# Ask to plan a feature
send_prompt "Plan F-0050, the search API feature"

FAILURES=0

# Agent should reference ag intel architecture or show awareness of phase intelligence
check_output_contains "ag intel\|intel architecture\|architecture.*intelligence\|ADR\|NFR\|quality check" \
    "Agent references phase intelligence or architectural context before planning" || ((FAILURES++))

# Agent should still reference the planning workflow
check_output_contains "plan\|ag start\|ag plan\|F-0050" \
    "Agent references planning workflow" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
