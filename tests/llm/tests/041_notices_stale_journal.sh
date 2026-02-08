#!/usr/bin/env bash
# Description: Agent should notice when JOURNAL.md has not been updated for weeks despite active development
# Section: artifact-maintenance
# Category: Important
# Profile: core
# Tests: LLM-041

# Setup - Core profile
setup_test_project "core"

# Create a stale JOURNAL.md (last entry Jan 10, project is now in Sprint 7)
mkdir -p "$TEST_PROJECT/.agentic-journal"
cat > "$TEST_PROJECT/.agentic-journal/JOURNAL.md" << 'EOF'
# Development Journal

### Session: 2026-01-10
- Set up project structure
- Added initial configuration
- Next: start building auth module
EOF

# Create STATUS.md showing project is far ahead
cat > "$TEST_PROJECT/STATUS.md" << 'EOF'
# Project Status

## Current Focus
Building admin dashboard (Sprint 7)

## In Progress
- Admin user management
- Analytics dashboard

## Completed Recently
- Payment gateway (Sprint 5-6)
- Order management (Sprint 6)
- User auth (Sprint 3-4)

## Next Steps
- Deploy admin dashboard
- Set up monitoring

## Blockers
- None
EOF

# Create CHANGELOG showing lots of progress since journal's last entry
cat > "$TEST_PROJECT/CHANGELOG.md" << 'EOF'
# Changelog

## [0.18.0] - 2026-02-04
- Admin dashboard MVP
- Analytics charts

## [0.15.0] - 2026-01-25
- Payment gateway complete
- Order management

## [0.10.0] - 2026-01-15
- User authentication
- Product catalog
EOF

git -C "$TEST_PROJECT" add .agentic-journal/JOURNAL.md STATUS.md CHANGELOG.md
git -C "$TEST_PROJECT" commit -m "Add project files with stale journal" --quiet

# Ask to continue work - agent should notice stale journal
send_prompt "Let's continue working on the admin dashboard. Where did we leave off?"

# Verify agent behavior - soft checks (proactive behavior)
FAILURES=0
WARNINGS=0

# Hard check: Agent should reference admin dashboard (from STATUS)
check_output_contains "admin\|dashboard" \
    "Agent references admin dashboard from STATUS" || ((FAILURES++))

# Soft check: Agent should notice journal is stale
check_output_contains "JOURNAL\|journal\|stale\|outdated\|hasn't been updated\|last entry\|January 10\|gap\|catch.up\|update.*journal\|no recent" \
    "Agent notices stale JOURNAL.md" || {
    echo -e "\033[1;33m⚠ SOFT: Agent didn't notice stale journal (last entry weeks ago)\033[0m"
    ((WARNINGS++))
}

# Cleanup
cleanup_test_project

if [[ $WARNINGS -gt 0 ]]; then
    echo -e "\033[1;33m⚠ $WARNINGS soft-check warning(s) (non-blocking)\033[0m"
fi

[[ $FAILURES -eq 0 ]]
