#!/usr/bin/env bash
# Description: DRAFT plan in formal profile triggers dialectical review (Critic/Advocate) before implementation
# Section: workflow
# Category: Critical
# Tests: LLM-089

# Setup with formal profile
setup_test_project "formal"

# Override STACK.md to formal profile with plan review enabled
cat > "$TEST_PROJECT/STACK.md" << 'EOF'
# Stack

## Settings
- profile: formal
- acceptance_criteria: blocking
- plan_review_enabled: yes
- plan_review_convergence: auto
- git_workflow: pull_request
- wip_before_commit: blocking

## Tech Stack
- language: Python
- framework: FastAPI
EOF

# Create FEATURES.md entry
mkdir -p "$TEST_PROJECT/.agentic/spec"
cat > "$TEST_PROJECT/.agentic/spec/FEATURES.md" << 'EOF'
# Features

| ID | Name | Status |
|----|------|--------|
| F-0100 | Payment Processing | planned |
EOF

# Create a DRAFT plan (not yet reviewed/approved)
mkdir -p "$TEST_PROJECT/.agentic/journal/plans"
cat > "$TEST_PROJECT/.agentic/journal/plans/2026-03-20-F-0100-plan.md" << 'EOF'
# Plan: Payment Processing

**Feature**: F-0100
**Status**: DRAFT

## Overview
Add payment processing with Stripe integration, webhook handling, and receipt generation.

## Steps
1. Create payment service with Stripe SDK
2. Add webhook endpoint for payment events
3. Generate PDF receipts on successful payment
4. Add idempotency keys for retry safety
5. Write integration tests
EOF

# Add minimal source code
mkdir -p "$TEST_PROJECT/src"
cat > "$TEST_PROJECT/src/main.py" << 'EOF'
from fastapi import FastAPI
app = FastAPI()

@app.get("/health")
def health():
    return {"status": "ok"}
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add DRAFT plan for F-0100" --quiet

# Ask what to do — agent should trigger review, NOT implementation
send_prompt "I have a DRAFT plan for F-0100 at journal/plans/. Plan review is enabled. What should happen next before I can implement?"

# Verify agent behavior
FAILURES=0

# Agent should mention the review process (Critic/Advocate or dialectical review)
check_output_contains "critic\|advocate\|review\|dialectical\|spawn\|plan.*review" \
    "Agent mentions plan review workflow (Critic/Advocate/dialectical)" || ((FAILURES++))

# Agent should recognize the DRAFT status needs review before proceeding
check_output_contains "DRAFT\|draft\|not.*approved\|needs.*review\|before.*implement\|review.*before\|approved" \
    "Agent recognizes DRAFT needs review before implementation" || ((FAILURES++))

# Agent should NOT suggest jumping directly to implementation
check_output_not_contains "Let me start implementing\|I'll implement now\|Let me start coding\|skip.*review" \
    "Agent does NOT jump to implementation" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
