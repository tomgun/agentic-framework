#!/usr/bin/env bash
# Description: Post-merge updates all state artifacts: JOURNAL, STATUS, FEATURES, CONTRIBUTIONS
# Section: artifact-maintenance
# Category: Important
# Tests: LLM-093

# Setup with formal profile
setup_test_project "formal"

# Override STACK.md to formal profile
cat > "$TEST_PROJECT/STACK.md" << 'EOF'
# Stack

## Settings
- profile: formal
- acceptance_criteria: blocking
- plan_review_enabled: yes
- git_workflow: pull_request

## Tech Stack
- language: Python
- framework: FastAPI
EOF

# Create completed feature with all artifacts
mkdir -p "$TEST_PROJECT/.agentic/spec/contracts" "$TEST_PROJECT/.agentic/spec/acceptance"
mkdir -p "$TEST_PROJECT/.agentic/journal"
cat > "$TEST_PROJECT/.agentic/spec/FEATURES.md" << 'EOF'
# Features

| ID | Name | Status |
|----|------|--------|
| F-0100 | Payment Processing | in_progress |
| F-0050 | User Auth | shipped |
EOF

cat > "$TEST_PROJECT/.agentic/spec/acceptance/F-0100.md" << 'EOF'
# F-0100: Payment Processing

## Acceptance Criteria
- [x] AC-001: Process payments via Stripe API
- [x] AC-002: Handle webhook events
- [x] AC-003: Generate receipts
EOF

cat > "$TEST_PROJECT/.agentic/journal/JOURNAL.md" << 'EOF'
# Development Journal

### Session: 2026-03-20
- Implemented payment service
- All tests passing
EOF

echo "# Status" > "$TEST_PROJECT/.agentic/STATUS.md"
echo "0.42.0" > "$TEST_PROJECT/VERSION"

# Create CONTRIBUTIONS.md (framework dev artifact)
cat > "$TEST_PROJECT/.agentic/CONTRIBUTIONS.md" << 'EOF'
# Contributions
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Feature F-0100 ready for merge" --quiet

# Tell agent feature merged and ask for post-merge cleanup
send_prompt "F-0100 PR #42 just merged. Run the full post-merge dance — update all artifacts."

# Verify agent behavior
FAILURES=0

# Agent should mention JOURNAL update
check_output_contains "journal\|JOURNAL\|journal.sh" \
    "Agent mentions updating JOURNAL" || ((FAILURES++))

# Agent should mention STATUS update
check_output_contains "status\|STATUS\|status.sh" \
    "Agent mentions updating STATUS" || ((FAILURES++))

# Agent should mention FEATURES update (shipped)
check_output_contains "FEATURES\|feature.sh\|shipped\|feature.*status" \
    "Agent mentions updating FEATURES to shipped" || ((FAILURES++))

# Agent should mention VERSION bump
check_output_contains "VERSION\|version\|bump" \
    "Agent mentions VERSION bump" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
