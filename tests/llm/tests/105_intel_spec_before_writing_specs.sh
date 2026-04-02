#!/usr/bin/env bash
# Description: Phase intelligence: "write spec" should reference ag intel spec for context
# Section: intelligence
# Category: Important
# Tests: LLM-105

# Setup with Formal profile
setup_test_project "formal"

mkdir -p "$TEST_PROJECT/spec/contracts"

# Create existing features so intel spec has overlap data
cat > "$TEST_PROJECT/spec/FEATURES.md" << 'EOF'
# Features

| Category | Count | Shipped | In Progress | Planned |
|----------|-------|---------|-------------|---------|
| **Core** | 3 | 2 | 0 | 1 |

## F-0080: User Auth

**Status**: shipped

## F-0081: Permission System

**Status**: shipped

## F-0082: Role-Based Access

**Status**: planned
EOF

cat > "$TEST_PROJECT/spec/contracts/F-0080.yaml" << 'EOF'
id: F-0080
name: User Auth
lifecycle: shipped
assertions:
  - id: AC-001
    text: Users can log in with email and password
    type: behavioral
EOF

cat > "$TEST_PROJECT/spec/NFR.md" << 'EOF'
# Non-Functional Requirements

## NFR-0001: Security
All auth flows must use bcrypt for password hashing.
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Setup spec context" --quiet

# Ask to write spec for the planned feature
send_prompt "Write the spec for F-0082, role-based access control"

FAILURES=0

# Agent should reference ag intel spec, feature overlap, or contracts
check_output_contains "ag intel\|intel spec\|overlap\|existing feature\|F-0080\|F-0081\|ag spec\|contract" \
    "Agent references phase intelligence or existing feature context" || ((FAILURES++))

# Agent should reference NFRs when writing security-adjacent specs
check_output_contains "NFR\|security\|requirement\|constraint\|ag spec\|acceptance" \
    "Agent considers NFRs or security constraints" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
