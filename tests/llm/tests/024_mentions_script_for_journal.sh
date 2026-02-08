#!/usr/bin/env bash
# Description: Agent should know about token-efficient journal script instead of reading JOURNAL.md directly
# Section: token-efficiency
# Category: Important
# Profile: core
# Tests: LLM-024
# Note: Token-efficiency angle of journal.sh usage (see also 004 for scripts angle)

# Setup - Core profile
setup_test_project "core"

# Create a realistic multi-session journal (larger than 004's simple journal)
mkdir -p "$TEST_PROJECT/.agentic-journal"
cat > "$TEST_PROJECT/.agentic-journal/JOURNAL.md" << 'EOF'
# Development Journal

## Session Log

### 2026-01-15: Authentication Module
- Implemented JWT token generation
- Added refresh token rotation
- Fixed CORS issues with auth endpoints
- Performance: 2ms avg response time

### 2026-01-14: Database Migration
- Migrated from SQLite to PostgreSQL
- Added connection pooling
- Schema: users, sessions, tokens tables
- Benchmark: 500 concurrent connections stable

### 2026-01-13: Initial Setup
- Created project structure
- Added CI/CD pipeline
- Configured linting and formatting
- Set up Docker development environment

### 2026-01-12: Planning Session
- Defined architecture: microservices with API gateway
- Tech stack: Node.js, TypeScript, PostgreSQL
- Testing strategy: unit + integration + e2e
- Deployment: Kubernetes with Helm charts
EOF

git -C "$TEST_PROJECT" add .agentic-journal/JOURNAL.md
git -C "$TEST_PROJECT" commit -m "Add journal" --quiet

# Ask to add a journal entry
send_prompt "Add a journal entry about completing the authentication feature"

# Verify agent behavior
FAILURES=0
WARNINGS=0

# Hard check: Agent should NOT read the entire journal
check_output_not_contains "let me read.*JOURNAL\|reading the entire.*JOURNAL\|cat.*JOURNAL" \
    "Agent does NOT read entire JOURNAL.md" || ((FAILURES++))

# Soft check: Agent should mention journal.sh or token-efficient approach
check_output_contains "journal.sh\|tools/journal\|ag journal\|append\|token.efficient\|script" \
    "Agent mentions journal.sh or token-efficient approach" || {
    echo -e "\033[1;33m⚠ SOFT: Agent didn't mention journal.sh (optimization goal)\033[0m"
    ((WARNINGS++))
}

# Cleanup
cleanup_test_project

if [[ $WARNINGS -gt 0 ]]; then
    echo -e "\033[1;33m⚠ $WARNINGS soft-check warning(s) (non-blocking)\033[0m"
fi

[[ $FAILURES -eq 0 ]]
