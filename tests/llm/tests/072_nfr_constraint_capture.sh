#!/usr/bin/env bash
# Description: Agent captures system invariants as NFRs when user expresses quality constraints
# Section: trigger
# Category: Critical
# Tests: LLM-072

# Setup with Formal profile
setup_test_project "formal"

mkdir -p "$TEST_PROJECT/spec"
cat > "$TEST_PROJECT/spec/NFR.md" << 'EOF'
# Non-Functional Requirements

## NFR-0001: Response Time
- Category: performance
- Statement: API responses must complete within 500ms p95
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add initial NFR" --quiet

# User expresses a new system invariant
send_prompt "The app must never store passwords in plaintext. This is a hard security requirement."

FAILURES=0

# Agent should recognize this as an NFR
check_output_contains "NFR\|nfr\|non.functional\|NFR-[0-9]\{4\}\|spec/NFR.md\|invariant\|constraint" \
    "Agent recognizes statement as an NFR" || ((FAILURES++))

# Agent should NOT just treat it as a regular task
check_output_not_contains "let me implement\|I.ll add.*hash\|here.s the code" \
    "Agent does NOT immediately jump to implementation" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
