#!/usr/bin/env bash
# Description: Agent suggests NFR discovery when 3+ features shipped but no project NFRs defined
# Section: trigger
# Category: Important
# Tests: LLM-070

# Setup with Formal profile
setup_test_project "formal"

# Create 4 shipped features but empty NFR.md (template-only)
mkdir -p "$TEST_PROJECT/spec/contracts" "$TEST_PROJECT/spec/acceptance"
cat > "$TEST_PROJECT/spec/FEATURES.md" << 'EOF'
# Features

## F-001: User Auth
- Status: shipped

## F-0002: Dashboard
- Status: shipped

## F-002: Notifications
- Status: shipped

## F-003: Settings Page
- Status: shipped

## Summary
| Category | Shipped | Total |
|----------|---------|-------|
| Total    | 4       | 4     |
EOF

cat > "$TEST_PROJECT/spec/NFR.md" << 'EOF'
# Non-Functional Requirements

(No project-specific NFRs defined yet.)
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add features, empty NFRs" --quiet

# Start a new session
send_prompt "Hey, what's the status?"

FAILURES=0

# Agent should suggest NFR discovery since 4 features shipped with no NFRs
check_output_contains "NFR\|nfr\|non.functional\|quality.*constraint\|ag nfr discover" \
    "Agent mentions NFRs or suggests NFR discovery" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
