---
name: committing-changes
description: >
  Pre-commit quality gates, branch management, and PR creation.
  Use when user says "commit", "push", "ship", "finalize", "create PR",
  "ag commit", "ready to commit", or wants to save completed work.
  Do NOT use for: writing code (use implementing-features), running tests
  (use writing-tests), reviewing code (use reviewing-code).
compatibility: "Requires Claude Code with shell access and git."
allowed-tools: [Bash, Read, Edit, Glob, Grep]
metadata:
  author: agentic-framework
  version: "${VERSION}"
---
# Committing Changes

Run `ag commit` — it handles quality gates, branch checks, and diff review.

## Before committing
1. Update journal: `bash .agentic/lib/tools/journal.sh "Topic" "Done" "Next" "Blockers" --why "Reason"`
2. Update status: `bash .agentic/lib/tools/status.sh focus "Current task"`
3. If shipping feature: `bash .agentic/lib/tools/feature.sh F-#### status shipped`

## Rules
- Never auto-commit in interactive sessions. Show diff to human first. After every commit/push, state the short hash, branch, and one-line summary.
- Never bypass hooks (`--no-verify`). Fix the underlying issue.
- PR by default. After creating PR, add to HUMAN_NEEDED.md.
- Stage specific files (`git add <files>`), not `git add .`
- Include JOURNAL.md, STATUS.md in commits. Exclude VERSION, BACKLOG.json.
- Before committing, grep `spec/contracts/` for assertions related to changed behavior. If any are affected, **STOP** — present them to the user and wait for approval before modifying any contract or test. Contracts protect shipped behavior; silently updating them to match new code defeats that protection.

## Post-merge
When merging a PR, immediately run `ag done F-XXXX` on main.
