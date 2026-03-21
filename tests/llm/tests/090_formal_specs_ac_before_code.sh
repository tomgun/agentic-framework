#!/usr/bin/env bash
# Description: With approved plan but no AC file, agent creates acceptance criteria before writing code
# Section: workflow
# Category: Critical
# Tests: LLM-090

# Setup with formal profile
setup_test_project "formal"

# Override STACK.md to formal profile
cat > "$TEST_PROJECT/STACK.md" << 'EOF'
# Stack

## Settings
- profile: formal
- acceptance_criteria: blocking
- plan_review_enabled: yes
- plan_review_convergence: auto
- git_workflow: pull_request

## Tech Stack
- language: Python
- framework: FastAPI
EOF

# Create FEATURES.md entry
mkdir -p "$TEST_PROJECT/.agentic/spec/acceptance"
cat > "$TEST_PROJECT/.agentic/spec/FEATURES.md" << 'EOF'
# Features

| ID | Name | Status |
|----|------|--------|
| F-0100 | Payment Processing | planned |
EOF

# Create an APPROVED plan (review already done)
mkdir -p "$TEST_PROJECT/.agentic/journal/plans"
cat > "$TEST_PROJECT/.agentic/journal/plans/2026-03-20-F-0100-plan.md" << 'EOF'
# Plan: Payment Processing

**Feature**: F-0100
**Status**: APPROVED

## Overview
Add payment processing with Stripe integration, webhook handling, and receipt generation.

## Steps
1. Create payment service with Stripe SDK
2. Add webhook endpoint for payment events
3. Generate PDF receipts on successful payment
4. Add idempotency keys for retry safety
5. Write integration tests
EOF

# NOTE: No acceptance criteria file exists at spec/acceptance/F-0100.md

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
git -C "$TEST_PROJECT" commit -m "Add approved plan for F-0100" --quiet

# Ask to implement — agent should notice missing AC before coding
send_prompt "The plan for F-0100 is approved. I want to start implementing. What artifacts are needed before I can write code?"

# Verify agent behavior
FAILURES=0

# Agent should mention acceptance criteria need to be created
check_output_contains "acceptance\|criteria\|AC\|spec.*acceptance\|F-0100.md" \
    "Agent mentions acceptance criteria need to be created" || ((FAILURES++))

# Agent should reference the plan
check_output_contains "plan\|APPROVED\|approved\|plan.*approved" \
    "Agent references the approved plan" || ((FAILURES++))

# Agent should NOT jump straight to writing production code
check_output_not_contains "^\`\`\`javascript.*function\|^\`\`\`typescript.*class\|^\`\`\`python.*def\|Let me start coding\|I'll write the code now" \
    "Agent does NOT jump to production code without AC" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
