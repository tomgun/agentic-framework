#!/usr/bin/env bash
# Description: When a feature is complete, agent should update FEATURES.md, mention CHANGELOG, and update JOURNAL
# Section: artifact-maintenance
# Category: Important
# Profile: formal
# Tests: LLM-039

# Setup - Formal profile
setup_test_project "formal"

# Create FEATURES.md with F-0001 in_progress
mkdir -p "$TEST_PROJECT/spec/acceptance"
cat > "$TEST_PROJECT/spec/FEATURES.md" << 'EOF'
# Features

## F-0001: User Authentication
- Status: in_progress
- Priority: high
- Acceptance: spec/acceptance/F-0001.md

## F-0002: Product Catalog
- Status: shipped
- Priority: high
EOF

# Create acceptance criteria (all met)
cat > "$TEST_PROJECT/spec/acceptance/F-0001.md" << 'EOF'
# F-0001: User Authentication

## Acceptance Criteria
- [x] Users can register with email/password
- [x] Users can login and receive JWT
- [x] Password reset via email
- [x] Session management with refresh tokens

## Tests
- All 12 auth tests passing
EOF

# Create JOURNAL.md
mkdir -p "$TEST_PROJECT/.agentic-journal"
cat > "$TEST_PROJECT/.agentic/journal/JOURNAL.md" << 'EOF'
# Development Journal

### Session: 2026-02-04
- Finished password reset flow
- All acceptance criteria met
- 12/12 tests passing
EOF

# Create CHANGELOG
cat > "$TEST_PROJECT/CHANGELOG.md" << 'EOF'
# Changelog

## [Unreleased]

## [0.19.0] - 2026-02-01
- Product catalog shipped
EOF

git -C "$TEST_PROJECT" add spec/ .agentic/journal/JOURNAL.md CHANGELOG.md
git -C "$TEST_PROJECT" commit -m "Add project files" --quiet

# Tell agent the feature is complete
send_prompt "F-0001 User Authentication is complete - all acceptance criteria pass and all tests are green. Please mark it as shipped."

# Verify agent behavior
FAILURES=0

# Agent should reference F-0001 and shipped status
check_output_contains "F-0001\|feature\|status\|shipped" \
    "Agent references F-0001 and shipped status" || ((FAILURES++))

# Agent should mention updating FEATURES, CHANGELOG, or JOURNAL
check_output_contains "FEATURES\|feature.sh\|CHANGELOG\|changelog\|journal\|JOURNAL" \
    "Agent mentions updating feature tracking artifacts" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
