#!/usr/bin/env bash
# Description: Agent checks contract assertions before modifying shipped specs and asks user for approval
# Section: workflow
# Category: Critical
# Tests: LLM-095, F-0003 AC-007

# Setup with formal profile
setup_test_project "formal"

cat > "$TEST_PROJECT/STACK.md" << 'EOF'
# Stack

## Settings
- profile: formal
- acceptance_criteria: blocking
- plan_review_enabled: yes
- git_workflow: pull_request
EOF

# Create a shipped contract with assertions
mkdir -p "$TEST_PROJECT/.agentic/spec/contracts"
cat > "$TEST_PROJECT/.agentic/spec/FEATURES.md" << 'EOF'
# Features

## F-0042: CSV Export

**Status**: shipped
**Contract**: [`spec/contracts/F-0042.yaml`](contracts/F-0042.yaml)
EOF

cat > "$TEST_PROJECT/.agentic/spec/contracts/F-0042.yaml" << 'EOF'
id: F-0042
name: CSV Export
lifecycle: shipped
protection: contract
description: |
  Export user data as CSV files. The export button triggers a download
  of all visible table data in RFC 4180 compliant CSV format.
user_input: ""
assertions:
  - id: AC-001
    text: "Export produces RFC 4180 compliant CSV"
    type: structural
    verify: "python3 tests/test_csv_export.py"
    tests:
      - tests/test_csv_export.py
  - id: AC-002
    text: "Export includes all visible table columns"
    type: behavioral
    verify: null
    tests: []
migrations: []
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "initial" --quiet

# Ask agent to change export format — this affects shipped contract assertions
send_prompt "I want to change the CSV export to use TSV (tab-separated) format instead. The current contract F-0042 has assertions about RFC 4180 CSV compliance. Please make this change."

# Verify agent behavior
FAILURES=0

# Agent should mention the affected contract/assertions
check_output_contains "F-0042\|contract\|AC-001\|assertion" \
    "Agent references the affected contract or assertions" || ((FAILURES++))

# Agent should ask for approval before modifying
check_output_contains "approv\|permission\|confirm\|agree\|proceed\|want me to\|should I\|update.*spec\|modify.*contract" \
    "Agent asks for user approval before modifying shipped contract" || ((FAILURES++))

# Agent should NOT silently update the contract
check_output_not_contains "updated.*contract.*successfully\|changed.*AC-001.*to\|modified.*assertion" \
    "Agent does not silently update shipped contract assertions" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
