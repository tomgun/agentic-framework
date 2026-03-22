#!/usr/bin/env bash
# Description: Agent suggests --parallel flag when user wants concurrent epic execution
# Section: trigger
# Category: Important
# Profile: autonomous_formal
# Tests: LLM-077

# Setup - autonomous_formal profile (most likely to use parallel epics)
setup_test_project "autonomous_formal"

# Create a decomposed epic so context is realistic
mkdir -p "$TEST_PROJECT/.agentic/spec/contracts" "$TEST_PROJECT/.agentic/spec/acceptance"
cat >> "$TEST_PROJECT/.agentic/spec/FEATURES.md" << 'EOF'

## F-0100: Payment System Epic

**Status**: criteria_set
**Category**: Core

**Description**: Complete payment processing system

## F-0101: Payment Gateway Integration

**Status**: criteria_set
**Category**: Core
**Parent**: F-0100

## F-0102: Invoice Generation

**Status**: criteria_set
**Category**: Core
**Parent**: F-0100

## F-0103: Refund Processing

**Status**: criteria_set
**Category**: Core
**Parent**: F-0100
EOF

cat > "$TEST_PROJECT/.agentic/spec/acceptance/F-0101.md" << 'EOF'
# F-0101: Payment Gateway Integration
## AC-001: Process credit card payments via Stripe API
EOF

cat > "$TEST_PROJECT/.agentic/spec/acceptance/F-0102.md" << 'EOF'
# F-0102: Invoice Generation
## AC-001: Generate PDF invoices from completed orders
EOF

cat > "$TEST_PROJECT/.agentic/spec/acceptance/F-0103.md" << 'EOF'
# F-0103: Refund Processing
## AC-001: Process full and partial refunds
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add epic F-0100 with children" --quiet

# User asks to run epic children in parallel
send_prompt "I want to execute all children of epic F-0100 in parallel, with multiple agents running at the same time"

FAILURES=0

# Agent should suggest --parallel flag
check_output_contains "--parallel\|parallel.*worktree\|ag auto epic.*parallel" \
    "Agent suggests --parallel flag for concurrent epic execution" || ((FAILURES++))

# Agent should reference ag auto epic (not just generic advice)
check_output_contains "ag auto epic\|auto epic\|scheduler" \
    "Agent routes to ag auto epic command" || ((FAILURES++))

# Agent should NOT suggest manual worktree creation (--parallel handles it)
check_output_not_contains "worktree.sh create\|git worktree add\|manually.*create.*worktree" \
    "Agent does NOT suggest manual worktree setup" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
