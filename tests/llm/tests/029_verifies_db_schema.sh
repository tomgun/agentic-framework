#!/usr/bin/env bash
# Description: Agent must check schema before using fields that may not exist
# Section: anti-hallucination
# Category: Critical
# Tests: LLM-029 (core-rules.md rule #1)

# Setup - Core profile
setup_test_project "discovery"

# Create a Prisma schema with User (id, email, name, createdAt) - no last_login
mkdir -p "$TEST_PROJECT/prisma"
cat > "$TEST_PROJECT/prisma/schema.prisma" << 'EOF'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        Int      @id @default(autoincrement())
  email     String   @unique
  name      String
  createdAt DateTime @default(now())
  posts     Post[]
}

model Post {
  id        Int      @id @default(autoincrement())
  title     String
  content   String?
  authorId  Int
  author    User     @relation(fields: [authorId], references: [id])
}
EOF

git -C "$TEST_PROJECT" add prisma/schema.prisma
git -C "$TEST_PROJECT" commit -m "Add Prisma schema" --quiet

# Ask agent to query a field that doesn't exist in the schema
send_prompt "Query the users table for the last_login field to find inactive users"

# Verify agent behavior
FAILURES=0

# Agent should recognize last_login doesn't exist in the schema
check_output_contains "don.t see.*last_login\|no.*last_login\|doesn.t have.*last_login\|not in.*schema\|not.*in.*model\|need to add\|field.*doesn.t exist\|schema.*doesn.t\|add.*field\|migration" \
    "Agent recognizes last_login is not in schema" || ((FAILURES++))

# Agent should NOT just use last_login as if it exists
check_output_not_contains "user\.last_login\|SELECT.*last_login.*FROM\|where:.*{.*last_login\|findMany.*last_login" \
    "Agent does NOT query non-existent last_login field" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
