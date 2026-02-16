#!/usr/bin/env bash
# Description: Agent should proactively update JOURNAL and STATUS when ending a session, not just give a verbal summary
# Section: artifact-maintenance
# Category: Critical
# Profile: core
# Tests: LLM-036

# Setup - Core profile
setup_test_project "discovery"

# Create STATUS.md
cat > "$TEST_PROJECT/STATUS.md" << 'EOF'
# Project Status

## Current Focus
Implementing payment gateway

## In Progress
- Stripe integration (70%)
- Webhook handlers

## Next Steps
- Complete webhook handlers
- Add invoice generation

## Blockers
- None
EOF

# Create JOURNAL.md
mkdir -p "$TEST_PROJECT/.agentic-journal"
cat > "$TEST_PROJECT/.agentic-journal/JOURNAL.md" << 'EOF'
# Development Journal

### Session: 2026-01-28
- Started Stripe integration
- Added payment intent API
- Next: webhook handlers
EOF

# Create a source file for context
mkdir -p "$TEST_PROJECT/src"
cat > "$TEST_PROJECT/src/payments.ts" << 'EOF'
export class PaymentService {
  async createIntent(amount: number) {
    // Stripe payment intent creation
    return { id: 'pi_test', status: 'created' };
  }
}
EOF

git -C "$TEST_PROJECT" add STATUS.md .agentic-journal/JOURNAL.md src/payments.ts
git -C "$TEST_PROJECT" commit -m "Add project files" --quiet

# Ask to wrap up session
send_prompt "I need to stop for today. We finished the webhook handlers and started on invoice generation. Please wrap up the session."

# Verify agent behavior - soft checks (proactive behavior)
FAILURES=0
WARNINGS=0

# Soft check: Agent should mention updating the journal
check_output_contains "journal\|JOURNAL" \
    "Agent mentions journal update" || {
    echo -e "\033[1;33m⚠ SOFT: Agent didn't mention journal update on session end\033[0m"
    ((WARNINGS++))
}

# Soft check: Agent should mention updating status or using scripts
check_output_contains "status.sh\|STATUS.md\|update.*status\|journal.sh\|ag journal\|append.*journal\|update.*journal" \
    "Agent mentions STATUS update or journal script" || {
    echo -e "\033[1;33m⚠ SOFT: Agent didn't mention artifact updates on session end\033[0m"
    ((WARNINGS++))
}

# Cleanup
cleanup_test_project

if [[ $WARNINGS -gt 0 ]]; then
    echo -e "\033[1;33m⚠ $WARNINGS soft-check warning(s) (non-blocking)\033[0m"
fi

[[ $FAILURES -eq 0 ]]
