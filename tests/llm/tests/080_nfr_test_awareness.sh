#!/usr/bin/env bash
# Description: Agent checks NFR test coverage when writing tests for a feature
# Section: trigger
# Category: Important
# Profile: formal
# Tests: LLM-080

# Setup
setup_test_project "formal"

# Create NFR.md and feature with NFR reference
mkdir -p .agentic/spec/contracts .agentic/spec/acceptance
cat > .agentic/spec/NFR.md <<'EOF'
## NFR-0001: Response time
- Category: performance
- Statement: API p95 < 200ms
- Applies to: all features (global)
- How to measure: load test
- Where enforced:
  - Tests: none
  - CI: none
- Current status: unknown
EOF

cat > .agentic/spec/acceptance/F-0100.md <<'EOF'
## Acceptance Criteria
- [ ] **AC-001**: Endpoint returns correct data
## Out of Scope
EOF

# User asks to write tests for the feature
send_prompt "Write tests for F-0100"

FAILURES=0

# Agent should check NFR test coverage
check_output_contains "nfr-test-check\|NFR.*coverage\|NFR.*test\|NFR-0001" \
    "Agent should check NFR test coverage or mention applicable NFRs" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
