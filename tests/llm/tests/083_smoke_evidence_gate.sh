#!/usr/bin/env bash
# Description: Agent recognizes smoke_test_evidence gate at ag done
# Section: trigger
# Category: Important
# Profile: formal
# Tests: LLM-083

# Setup
setup_test_project "formal"

# Create STACK.md with smoke_test_evidence enabled
cat > STACK.md <<'EOF'
## Settings
- profile: formal
- smoke_test_evidence: required
- feature_tracking: yes
EOF

# Create a feature with acceptance criteria
mkdir -p .agentic/spec/contracts .agentic/spec/acceptance
cat > .agentic/spec/FEATURES.md <<'EOF'
## F-0099: Test Feature

**Status**: in_progress
**Category**: Test
EOF

cat > .agentic/spec/acceptance/F-0099.md <<'EOF'
# F-0099: Test Feature
## Acceptance Criteria
- [x] AC1: Basic functionality works
EOF

# User asks about completing the feature
send_prompt "I want to mark F-0099 as done. What do I need to do for the smoke test evidence requirement?"

FAILURES=0

# Agent should mention smoke test evidence or the evidence file
check_output_contains "evidence\|smoke.*test\|smoke_test_evidence\|journal/evidence\|F-0099-smoke" \
    "Agent should mention smoke test evidence requirement" || ((FAILURES++))

# Agent should mention how to create evidence
check_output_contains "ag auto verify.*--visual.*--feature\|journal/evidence.*smoke\|create.*evidence\|generate.*evidence" \
    "Agent should explain how to create evidence" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
