#!/usr/bin/env bash
# Description: Phase intelligence: "implement feature" should reference ag intel implement for conventions
# Section: intelligence
# Category: Important
# Tests: LLM-103

# Setup with Formal profile
setup_test_project "formal"

mkdir -p "$TEST_PROJECT/spec/contracts" "$TEST_PROJECT/intel"

# Create conventions and patterns so intel has data
cat > "$TEST_PROJECT/conventions.md" << 'EOF'
# Conventions

## Naming
Use snake_case for all functions.

## Error handling
Always check return codes.
EOF

cat > "$TEST_PROJECT/intel/patterns.yaml" << 'EOF'
version: 1
patterns:
  - id: P-0001
    text: "Never use eval in bash scripts"
    reason: "Security risk — command injection"
    scope: "*.sh"
    severity: error
    source: manual
EOF

cat > "$TEST_PROJECT/spec/contracts/F-0060.yaml" << 'EOF'
id: F-0060
name: Export Feature
lifecycle: implementing
assertions:
  - id: AC-001
    text: Export produces valid CSV
    type: behavioral
EOF

cat > "$TEST_PROJECT/spec/FEATURES.md" << 'EOF'
# Features

## F-0060: Export Feature

**Status**: in_progress
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Setup implementation context" --quiet

# Ask to implement
send_prompt "Implement F-0060, the export feature"

FAILURES=0

# Agent should reference ag intel implement, conventions, or patterns
check_output_contains "ag intel\|intel implement\|convention\|pattern\|quality check\|ag implement" \
    "Agent references phase intelligence or implementation context" || ((FAILURES++))

# Agent should reference the feature contract/acceptance criteria
check_output_contains "contract\|AC-001\|assertion\|F-0060\|acceptance" \
    "Agent references feature contract" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
