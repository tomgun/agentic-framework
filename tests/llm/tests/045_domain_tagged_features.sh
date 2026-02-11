#!/usr/bin/env bash
# Description: Agent should include Domain metadata when creating features in multi-domain projects
# Section: brownfield
# Category: Important
# Tests: LLM-045

# Setup with Core+PM profile
setup_test_project "core-pm"

# Create FEATURES.md with domain-tagged features (as brownfield discovery would produce)
mkdir -p "$TEST_PROJECT/spec/acceptance"
cat > "$TEST_PROJECT/spec/FEATURES.md" << 'EOF'
# FEATURES.md

<!-- format: features-v0.1.0 -->

## F-0001: User Dashboard
- Status: shipped
- Domain: frontend
- Acceptance: spec/acceptance/F-0001.md
- State: complete

## F-0002: Products API
- Status: shipped
- Domain: backend
- Acceptance: spec/acceptance/F-0002.md
- State: complete
EOF

cat > "$TEST_PROJECT/spec/acceptance/F-0001.md" << 'EOF'
# F-0001: User Dashboard - Acceptance Criteria
- [x] Dashboard displays user data
EOF

cat > "$TEST_PROJECT/spec/acceptance/F-0002.md" << 'EOF'
# F-0002: Products API - Acceptance Criteria
- [x] API returns product catalog data
EOF

git -C "$TEST_PROJECT" add spec/
git -C "$TEST_PROJECT" commit -m "Add domain-tagged features" --quiet

# Ask to add a new feature — agent should include Domain metadata
send_prompt "Add a new feature F-0003 for a mobile shopping cart screen to FEATURES.md. This is a mobile feature."

# Verify agent behavior
FAILURES=0

# Agent should include Domain metadata on the new feature
check_output_contains "Domain.*mobile\|domain.*mobile\|- Domain:" \
    "Agent includes Domain metadata" || ((FAILURES++))

# Agent should use the correct F-0003 ID format
check_output_contains "F-0003\|F.0003" \
    "Agent uses correct feature ID" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
