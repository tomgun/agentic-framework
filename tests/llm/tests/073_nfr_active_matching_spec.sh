#!/usr/bin/env bash
# Description: Agent actively matches NFRs during spec writing (not passive)
# Section: skills
# Category: Important
# Tests: LLM-073

# Setup with Formal profile
setup_test_project "formal"

mkdir -p "$TEST_PROJECT/spec/contracts" "$TEST_PROJECT/spec/acceptance"
cat > "$TEST_PROJECT/spec/FEATURES.md" << 'EOF'
# Features

## F-0001: User Auth
- Status: shipped

## Summary
| Category | Shipped | Total |
|----------|---------|-------|
| Total    | 1       | 1     |
EOF

cat > "$TEST_PROJECT/spec/NFR.md" << 'EOF'
# Non-Functional Requirements

## NFR-0001: Response Time
- Category: performance
- Statement: API responses must complete within 200ms p95
- Current status: met

## NFR-0002: Accessibility
- Category: usability
- Statement: All UI must meet WCAG 2.1 AA standards
- Current status: met
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Setup with NFRs" --quiet

# Ask to write a spec for a new API feature
send_prompt "Write a spec for F-0002: Search API — users can search products by keyword with filters"

FAILURES=0

# Agent should reference specific NFRs during spec writing
check_output_contains "NFR-0001\|response.*time\|200ms\|NFR.*compliance\|NFR.*applicable\|NFRs.*none\|Related NFR" \
    "Agent references specific NFRs during spec writing" || ((FAILURES++))

# Agent should create acceptance criteria / contract
check_output_contains "acceptance\|criteria\|contract\|AC-\|spec/contracts\|spec/acceptance" \
    "Agent creates acceptance criteria / contract" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
