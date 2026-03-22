#!/usr/bin/env bash
# Description: Agent should remind to update FEATURES.md when feature work is done
# Section: artifact-maintenance
# Category: Important
# Tests: LLM-047

# Setup with Formal profile
setup_test_project "formal"

# Create a feature in_progress with acceptance criteria done
mkdir -p "$TEST_PROJECT/spec/contracts" "$TEST_PROJECT/spec/acceptance"
cat > "$TEST_PROJECT/spec/FEATURES.md" << 'EOF'
# FEATURES.md

## F-0001: User Authentication
- Status: in_progress
- Acceptance: spec/contracts/F-0001.yaml
EOF

cat > "$TEST_PROJECT/spec/acceptance/F-0001.md" << 'EOF'
# F-0001: User Authentication

## Acceptance Criteria
- [x] Login form validates email and password
- [x] JWT tokens issued on successful login
- [x] Session expires after 30 minutes
EOF

git -C "$TEST_PROJECT" add spec/
git -C "$TEST_PROJECT" commit -m "Add feature spec" --quiet

# Ask about committing completed feature work
send_prompt "F-0001 is complete and all tests pass. I want to commit the changes. What needs updating first?"

# Verify agent behavior
FAILURES=0

# Agent should mention updating FEATURES.md status
check_output_contains "FEATURES.md\|feature.sh\|status.*shipped\|mark.*shipped\|update.*feature.*status" \
    "Agent mentions updating FEATURES.md or feature status" || ((FAILURES++))

# Agent should mention JOURNAL or STATUS updates too
check_output_contains "JOURNAL\|STATUS\|journal.sh\|status.sh" \
    "Agent mentions JOURNAL or STATUS updates" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
