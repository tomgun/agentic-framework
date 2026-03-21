#!/usr/bin/env bash
# Description: After committing code in formal workflow, agent creates PR and mentions review process
# Section: workflow
# Category: Important
# Tests: LLM-091

# Setup with autonomous_formal profile (review_code: critical_agent)
setup_test_project "autonomous_formal"

# Ensure git_workflow is PR-based
grep -q "git_workflow" "$TEST_PROJECT/STACK.md" || {
    echo "- git_workflow: pull_request" >> "$TEST_PROJECT/STACK.md"
}

# Create feature branch with committed code
mkdir -p "$TEST_PROJECT/.agentic/spec/acceptance"
cat > "$TEST_PROJECT/.agentic/spec/FEATURES.md" << 'EOF'
# Features

| ID | Name | Status |
|----|------|--------|
| F-0100 | Payment Processing | in_progress |
EOF

cat > "$TEST_PROJECT/.agentic/spec/acceptance/F-0100.md" << 'EOF'
# F-0100: Payment Processing

## Acceptance Criteria
- [x] AC-001: Process payments via Stripe API
- [x] AC-002: Handle webhook events for payment status
- [x] AC-003: Generate receipts for successful payments
EOF

# Simulate committed code on a feature branch
cat > "$TEST_PROJECT/payment_service.py" << 'EOF'
class PaymentService:
    def process_payment(self, amount, currency="usd"):
        """Process a payment via Stripe."""
        pass

    def handle_webhook(self, event):
        """Handle Stripe webhook events."""
        pass
EOF

git -C "$TEST_PROJECT" checkout -b feat/F-0100-payment --quiet
git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "feat: add payment processing (F-0100)" --quiet

# Ask to ship — agent should mention PR creation and review
send_prompt "Code for F-0100 is committed on the feature branch. All tests pass. What's next to ship this?"

# Verify agent behavior
FAILURES=0

# Agent should mention creating a PR
check_output_contains "pull.request\|PR\|ag ship\|gh pr\|git push" \
    "Agent mentions creating a PR or pushing for review" || ((FAILURES++))

# Agent should mention review process
check_output_contains "review\|critical.agent\|code.review\|review_code\|ag commit" \
    "Agent mentions review process" || ((FAILURES++))

# Agent should mention HUMAN_NEEDED for PR tracking
check_output_contains "HUMAN_NEEDED\|human.needed\|tracking\|merge\|approval" \
    "Agent mentions PR tracking or human approval for merge" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
