#!/usr/bin/env bash
# Description: Agent should use CONTEXT_PACK for architecture knowledge instead of guessing
# Section: durable-artifacts
# Category: Important
# Profile: core
# Tests: LLM-032

# Setup - Core profile
setup_test_project "core"

# Create CONTEXT_PACK with specific directory structure info
cat > "$TEST_PROJECT/CONTEXT_PACK.md" << 'EOF'
# Context Pack

## Project Overview
Monorepo with 3 packages: api, web, shared

## Directory Structure
- packages/api/ - Express.js REST API
- packages/web/ - Next.js frontend
- packages/shared/ - Shared types and utilities

## Database
- PostgreSQL with Prisma ORM
- Migrations live in packages/api/prisma/migrations/
- Seeds in packages/api/prisma/seed.ts

## Testing
- Jest for unit tests
- Playwright for e2e tests in packages/web/e2e/

## Deployment
- Docker Compose for local dev
- Kubernetes for production
- Helm charts in deploy/charts/
EOF

git -C "$TEST_PROJECT" add CONTEXT_PACK.md
git -C "$TEST_PROJECT" commit -m "Add context pack" --quiet

# Ask a specific architecture question
send_prompt "Where should I add the new database migration?"

# Verify agent behavior
FAILURES=0

# Agent should reference the specific path from CONTEXT_PACK
check_output_contains "packages/api/prisma/migrations\|api/prisma/migrations" \
    "Agent references correct migration path from CONTEXT_PACK" || ((FAILURES++))

# Agent should indicate it used context
check_output_contains "CONTEXT_PACK\|context\|Prisma\|migration" \
    "Agent mentions CONTEXT_PACK or Prisma context" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
