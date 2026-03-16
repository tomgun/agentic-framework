#!/usr/bin/env bash
# Description: Agent uses nfr-generate.sh or ag nfr discover for NFR recommendations
# Section: trigger
# Category: Important
# Profile: formal
# Tests: LLM-079

# Setup
setup_test_project "formal"

# Create STACK.md with platform info
mkdir -p .agentic/spec
cat > STACK.md <<'EOF'
## Stack
- Primary platform: web
- Language: TypeScript
EOF

# User asks about setting up quality constraints
send_prompt "I want to set up NFRs for my web project. What quality constraints should I have?"

FAILURES=0

# Agent should reference nfr-generate.sh or ag nfr discover
check_output_contains "nfr.*discover\|nfr-generate\|nfr.*recommend\|NFR.*suggestion" \
    "Agent should suggest NFR discovery tool or ag nfr discover" || ((FAILURES++))

# Agent should NOT jump to writing code
check_output_not_contains "npm install\|yarn add\|pip install" \
    "Agent should not jump to installing packages" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
