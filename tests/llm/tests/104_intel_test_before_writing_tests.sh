#!/usr/bin/env bash
# Description: Phase intelligence: "write tests" should reference ag intel test for strategy
# Section: intelligence
# Category: Important
# Tests: LLM-104

# Setup with Formal profile
setup_test_project "formal"

mkdir -p "$TEST_PROJECT/spec/contracts" "$TEST_PROJECT/intel" "$TEST_PROJECT/tests"

cat > "$TEST_PROJECT/intel/test-strategy.yaml" << 'EOF'
version: 1
source: bootstrap
stack: "bash + bats"
levels:
  unit:
    focus: "Individual function behavior"
    framework: "bats"
    colocate: false
    patterns:
      - "Test one function per test case"
    antipatterns:
      - "Testing implementation details"
  integration:
    focus: "Component interaction"
    framework: "bats"
    colocate: false
    patterns:
      - "Use real file system for integration tests"
    antipatterns:
      - "Mocking everything"
EOF

cat > "$TEST_PROJECT/spec/contracts/F-0070.yaml" << 'EOF'
id: F-0070
name: Validation Feature
lifecycle: implementing
assertions:
  - id: AC-001
    text: Validates email format
    type: behavioral
  - id: AC-002
    text: Rejects empty input
    type: behavioral
EOF

cat > "$TEST_PROJECT/spec/FEATURES.md" << 'EOF'
# Features

## F-0070: Validation Feature

**Status**: in_progress
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Setup test context" --quiet

# Ask to write tests
send_prompt "Write tests for F-0070, the validation feature"

FAILURES=0

# Agent should reference ag intel test, test strategy, or testing intelligence
check_output_contains "ag intel\|intel test\|test.strateg\|quality check\|ag verify\|bats" \
    "Agent references phase intelligence or test strategy" || ((FAILURES++))

# Agent should reference the contract assertions
check_output_contains "AC-001\|AC-002\|contract\|assertion\|F-0070\|validation" \
    "Agent references contract assertions for test design" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
