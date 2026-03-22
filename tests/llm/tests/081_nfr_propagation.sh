#!/usr/bin/env bash
# Description: Agent uses nfr-propagate.sh derive when writing feature specs
# Section: trigger
# Category: Important
# Profile: formal
# Tests: LLM-081

# Setup
setup_test_project "formal"

# Create NFR.md
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

# User asks to write a spec
send_prompt "Write a spec for F-0100 — a new user registration endpoint"

FAILURES=0

# Agent should use nfr-propagate derive or mention NFR matching
check_output_contains "nfr-propagate.*derive\|nfr.*applicable\|NFR.*Constraints\|NFR-0001" \
    "Agent should use NFR propagation tool or reference applicable NFRs" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
