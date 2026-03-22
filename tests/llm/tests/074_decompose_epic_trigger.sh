#!/usr/bin/env bash
# Description: Agent triggers ag decompose when user asks to break down an epic into children
# Section: trigger
# Category: Critical
# Tests: LLM-074

# Setup with Formal profile (decompose requires feature tracking)
setup_test_project "formal"

mkdir -p "$TEST_PROJECT/.agentic/spec/contracts" "$TEST_PROJECT/.agentic/spec/acceptance"
cat >> "$TEST_PROJECT/.agentic/spec/FEATURES.md" << 'EOF'

### F-0100: User Management Epic
- **Status**: criteria_set
- **Category**: Core
- **Description**: Complete user management system
EOF

cat > "$TEST_PROJECT/.agentic/spec/acceptance/F-0100.md" << 'EOF'
# F-0100: User Management Epic

## Acceptance Criteria

- AC-001: Users can register with email and password
- AC-002: Users can log in and receive a session token
- AC-003: Admin users can manage roles and permissions
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add epic F-0100" --quiet

# User asks to decompose/break down the epic
send_prompt "Break down F-0100 into smaller child features"

FAILURES=0

# Agent should recognize this as a decomposition request
check_output_contains "decompose\|ag decompose\|child.feature\|break.*down\|split.*into" \
    "Agent recognizes decompose intent" || ((FAILURES++))

# Agent should NOT just start implementing
check_output_not_contains "let me implement\|I.ll start coding\|here.s the code" \
    "Agent does NOT jump to implementation" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
