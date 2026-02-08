#!/usr/bin/env bash
# Description: Agent should read STATUS.md and reference its content when asked about next steps
# Section: durable-artifacts
# Category: Important
# Tests: LLM-030

# Setup - Core profile
setup_test_project "core"

# Create STATUS.md with specific sprint/task info
cat > "$TEST_PROJECT/STATUS.md" << 'EOF'
# Project Status

## Current Sprint: Sprint 7
**Goal**: Complete payment gateway integration

## Completed
- User authentication (Sprint 5)
- Product catalog (Sprint 6)
- Shopping cart (Sprint 6)

## In Progress
- Payment gateway - Stripe integration (70% done)
- Order confirmation emails

## Next Steps
- Implement the payment gateway webhook handlers
- Add invoice PDF generation
- Set up monitoring dashboards

## Blockers
- Waiting for Stripe API keys from finance team
EOF

git -C "$TEST_PROJECT" add STATUS.md
git -C "$TEST_PROJECT" commit -m "Update STATUS.md" --quiet

# Ask about next steps - agent should read STATUS.md
send_prompt "What should I work on next?"

# Verify agent behavior
FAILURES=0

# Agent should reference specific content from STATUS.md
check_output_contains "payment\|gateway\|webhook\|Stripe\|invoice\|monitoring" \
    "Agent references STATUS.md content (payment/gateway/webhook)" || ((FAILURES++))

# Agent should indicate it read status or project context
check_output_contains "STATUS\|status\|next step\|priority\|sprint" \
    "Agent mentions STATUS or project context" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
