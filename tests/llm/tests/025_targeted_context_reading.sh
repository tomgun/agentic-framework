#!/usr/bin/env bash
# Description: Agent should use durable artifacts (CONTEXT_PACK) for targeted info instead of scanning source files
# Section: token-efficiency
# Category: Important
# Profile: core
# Tests: LLM-025

# Setup - Core profile
setup_test_project "discovery"

# Create CONTEXT_PACK with detailed architecture info
cat > "$TEST_PROJECT/CONTEXT_PACK.md" << 'EOF'
# Context Pack

## Project Overview
E-commerce platform with microservices architecture.

## Frontend Layer
- React 18 with TypeScript
- Next.js for SSR
- Tailwind CSS for styling
- State: Zustand

## API Gateway
- Express.js reverse proxy
- Rate limiting: 100 req/min per user
- JWT validation middleware

## Database Layer
- PostgreSQL 15 for primary data
- Redis for caching and sessions
- Prisma ORM for type-safe queries
- Migrations in db/migrations/
- Connection pooling via PgBouncer

## Authentication
- JWT with RS256 signing
- Refresh token rotation
- OAuth2 providers: Google, GitHub

## Deployment
- Kubernetes on AWS EKS
- Helm charts in deploy/
- CI/CD via GitHub Actions
EOF

# Create source files that the agent could wastefully scan
mkdir -p "$TEST_PROJECT/src/db"
cat > "$TEST_PROJECT/src/index.ts" << 'EOF'
import express from 'express';
const app = express();
app.listen(3000);
EOF

cat > "$TEST_PROJECT/src/db/connection.ts" << 'EOF'
import { PrismaClient } from '@prisma/client';
export const prisma = new PrismaClient();
EOF

git -C "$TEST_PROJECT" add CONTEXT_PACK.md src/
git -C "$TEST_PROJECT" commit -m "Add context pack and source files" --quiet

# Ask about the database layer
send_prompt "I need to understand the database layer for my next task"

# Verify agent behavior
FAILURES=0
WARNINGS=0

# Hard check: Agent should reference specific database layer details from CONTEXT_PACK
check_output_contains "PostgreSQL\|Prisma\|Redis\|PgBouncer\|db/migrations" \
    "Agent references database layer details" || ((FAILURES++))

# Soft check: Agent should mention CONTEXT_PACK as its source
check_output_contains "CONTEXT_PACK\|context pack\|architecture\|database layer" \
    "Agent references CONTEXT_PACK or architecture overview" || {
    echo -e "\033[1;33m⚠ SOFT: Agent didn't explicitly reference CONTEXT_PACK\033[0m"
    ((WARNINGS++))
}

# Soft check: Agent should not wastefully scan all source files
check_output_not_contains "scanning all.*src\|reading all source\|let me search every" \
    "Agent does NOT wastefully scan all source files" || {
    echo -e "\033[1;33m⚠ SOFT: Agent may be scanning source files unnecessarily\033[0m"
    ((WARNINGS++))
}

# Cleanup
cleanup_test_project

if [[ $WARNINGS -gt 0 ]]; then
    echo -e "\033[1;33m⚠ $WARNINGS soft-check warning(s) (non-blocking)\033[0m"
fi

[[ $FAILURES -eq 0 ]]
