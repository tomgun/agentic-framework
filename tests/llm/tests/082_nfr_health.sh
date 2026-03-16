#!/usr/bin/env bash
# Description: Agent runs ag nfr health when asked about NFR status
# Section: trigger
# Category: Important
# Profile: formal
# Tests: LLM-082

# Setup
setup_test_project "formal"

# Create NFR.md with entries
mkdir -p .agentic/spec
cat > .agentic/spec/NFR.md <<'EOF'
## NFR-0001: Response time
- Category: performance
- Statement: API p95 < 200ms
- Applies to: all features (global)
- How to measure: load test
- Where enforced:
  - Tests: none
  - CI: none
- Current status: met
EOF

# User asks about NFR status
send_prompt "What's the status of our NFRs? Are we meeting our quality constraints?"

FAILURES=0

# Agent should reference nfr health or show NFR status
check_output_contains "nfr.*health\|ag nfr\|NFR.*status\|NFR-0001.*met\|quality.*constraint" \
    "Agent should check NFR health or report NFR status" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
