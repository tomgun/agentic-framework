#!/usr/bin/env bash
# Description: Agent updates docs as part of shipping — not deferred to after merge
# Section: workflow
# Category: Critical
# Tests: LLM-099
#
# This tests the doc-update failure mode: agent writes code and creates PR
# without updating stale documentation.

# Setup with formal profile (docs_gate=blocking)
setup_test_project "formal"

# STACK.md with doc registry
cat > "$TEST_PROJECT/STACK.md" << 'EOF'
# Stack

## Settings
- profile: formal
- feature_tracking: yes
- docs_gate: blocking

## Tech Stack
- language: TypeScript
- framework: Express

## Docs
| Path | Triggers | Description |
|------|----------|-------------|
| README.md | feature_done | Project README |
| docs/API.md | feature_done | API documentation |
EOF

# Create stale docs
cat > "$TEST_PROJECT/README.md" << 'EOF'
# My App
A simple Express app with user management.

## Endpoints
- GET /users — list users
- POST /users — create user
EOF

mkdir -p "$TEST_PROJECT/docs"
cat > "$TEST_PROJECT/docs/API.md" << 'EOF'
# API Reference
## Users
- `GET /users` — Returns list of users
- `POST /users` — Creates a new user
EOF

# Create feature + contract
mkdir -p "$TEST_PROJECT/.agentic/spec/contracts" "$TEST_PROJECT/.agentic/spec"
cat > "$TEST_PROJECT/.agentic/spec/FEATURES.md" << 'EOF'
# Features
## F-0100: Search Endpoint
**Status**: in_progress
EOF
cat > "$TEST_PROJECT/.agentic/spec/contracts/F-0100.yaml" << 'EOF'
id: F-0100
name: Search Endpoint
lifecycle: implementing
description: Add search endpoint.
assertions:
  - id: AC-001
    text: GET /search returns matching results
    type: behavioral
EOF

# Create the new code (already implemented)
mkdir -p "$TEST_PROJECT/src"
cat > "$TEST_PROJECT/src/search.ts" << 'EOF'
import { Router } from "express";
const router = Router();
router.get("/search", (req, res) => {
  const q = req.query.q as string;
  // search logic
  res.json({ results: [] });
});
export default router;
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add search endpoint implementation" --quiet

# Ask to prepare for PR — agent should check and update docs
send_prompt "I've finished implementing F-0100 (Search Endpoint). The code is committed. I need to prepare this for a PR. The README and API docs don't mention the new search endpoint yet."

# Verify agent behavior
FAILURES=0

# Agent should mention updating docs
check_output_contains "README\|API.*doc\|documentation\|docs.*update\|update.*docs\|stale" \
    "Agent mentions updating docs" || ((FAILURES++))

# Agent should check freshness or mention the doc gate
check_output_contains "freshness\|docs_gate\|docs.sh\|drift\|stale.*doc\|doc.*ship.*code\|deliverable" \
    "Agent references doc freshness/gate mechanism" || ((FAILURES++))

# Agent should NOT create a PR without mentioning docs first
check_output_not_contains "gh pr create\|Pull request created\|PR is ready\|opened.*PR" \
    "Agent does NOT create PR without addressing docs" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
