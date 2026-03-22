#!/usr/bin/env bash
# Description: Formal workflow requires plan before implementation — agent must not jump to code
# Section: workflow
# Category: Critical
# Tests: LLM-088

# Setup with formal profile (plan_review_enabled, acceptance_criteria: blocking)
setup_test_project "formal"

# Override STACK.md to formal profile with proper settings
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

# Create FEATURES.md entry but NO plan and NO acceptance criteria
mkdir -p "$TEST_PROJECT/.agentic/spec/contracts" "$TEST_PROJECT/.agentic/spec/acceptance"
cat > "$TEST_PROJECT/.agentic/spec/FEATURES.md" << 'EOF'
# Features

| ID | Name | Status |
|----|------|--------|
| F-0100 | Payment Processing | planned |
EOF

# Add minimal source code so agent doesn't fixate on empty repo
mkdir -p "$TEST_PROJECT/src"
cat > "$TEST_PROJECT/src/main.py" << 'EOF'
from fastapi import FastAPI
app = FastAPI()

@app.get("/health")
def health():
    return {"status": "ok"}
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add F-0100 planned feature with base app" --quiet

# Ask to implement — agent should require plan + spec before coding
send_prompt "implement F-0100 Payment Processing"

# Verify agent behavior
FAILURES=0

# Agent should mention planning or asking about requirements before coding
check_output_contains "plan\|ag plan\|ag start\|planning\|before.*implement\|first.*need\|requirement\|define\|before.*cod" \
    "Agent mentions planning or pre-implementation steps" || ((FAILURES++))

# Agent should mention acceptance criteria/contracts or specs
check_output_contains "acceptance\|criteria\|contract\|spec\|AC\|define.*require" \
    "Agent mentions acceptance criteria / contracts / specs requirement" || ((FAILURES++))

# Agent should NOT jump straight to implementation code
check_output_not_contains "^\`\`\`python.*def.*payment\|^\`\`\`python.*class.*Payment\|def process_payment\|class PaymentService" \
    "Agent does NOT output implementation code" || ((FAILURES++))

# Agent should NOT say it's starting implementation
check_output_not_contains "Let me start implementing\|I'll implement now\|Let me write the code\|I'll start coding" \
    "Agent does NOT start implementing without plan" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
