#!/usr/bin/env bash
# Description: When agent discovers a blocker, it should document it in HUMAN_NEEDED.md
# Section: artifact-maintenance
# Category: Important
# Profile: core
# Tests: LLM-040

# Setup - Core profile
setup_test_project "core"

# Create STATUS.md
cat > "$TEST_PROJECT/STATUS.md" << 'EOF'
# Project Status

## Current Focus
Integrating Stripe payment gateway

## Next Steps
- Configure Stripe webhook endpoint
- Add payment confirmation flow

## Blockers
- None
EOF

# Create HUMAN_NEEDED.md (empty)
cat > "$TEST_PROJECT/HUMAN_NEEDED.md" << 'EOF'
# Human Needed

Items requiring human decision or action.

(No items currently)
EOF

# Create source file for context
mkdir -p "$TEST_PROJECT/src"
cat > "$TEST_PROJECT/src/payments.ts" << 'EOF'
export class PaymentService {
  // TODO: Need real Stripe API keys
  private apiKey = 'sk_test_placeholder';
}
EOF

git -C "$TEST_PROJECT" add STATUS.md HUMAN_NEEDED.md src/payments.ts
git -C "$TEST_PROJECT" commit -m "Add project files" --quiet

# Report a blocker
send_prompt "We can't proceed with the Stripe integration. The finance team hasn't provided the production API keys yet, and we've been waiting for a week. Please document this blocker."

# Verify agent behavior - soft checks (proactive behavior)
FAILURES=0
WARNINGS=0

# Soft check: Agent should mention HUMAN_NEEDED or blocker tracking
check_output_contains "HUMAN_NEEDED\|blocker\|human.needed\|block" \
    "Agent mentions HUMAN_NEEDED or blocker tracking" || {
    echo -e "\033[1;33m⚠ SOFT: Agent didn't mention HUMAN_NEEDED for blocker\033[0m"
    ((WARNINGS++))
}

# Soft check: Agent should reference the Stripe/API key issue
check_output_contains "Stripe\|API key\|finance\|document\|recorded\|added\|tracked" \
    "Agent references the blocker details" || {
    echo -e "\033[1;33m⚠ SOFT: Agent didn't reference blocker details\033[0m"
    ((WARNINGS++))
}

# Cleanup
cleanup_test_project

if [[ $WARNINGS -gt 0 ]]; then
    echo -e "\033[1;33m⚠ $WARNINGS soft-check warning(s) (non-blocking)\033[0m"
fi

[[ $FAILURES -eq 0 ]]
