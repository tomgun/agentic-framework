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
  version: "0.62.0"
---
# Committing Changes

**Git required**: If `git_mode` in STACK.md is `deferred` or `none`, `ag commit` will print a message suggesting `ag git-init`. Guide the user to activate git first.

Run `ag commit` — it handles quality gates, branch checks, and diff review.

## What's Enforced Automatically (hooks — you can't bypass these)
- **Destructive git ops blocked** → PreToolUse denies reset --hard, stash, checkout --, force push
- **Shipped spec protection** → PreToolUse denies editing shipped contracts without migration (formal)
- **DRAFT plan blocks commit** → PreToolUse denies git commit when DRAFT plan exists (formal)
- **Stale journal/status reminder** → UserPromptSubmit warns per-prompt when uncommitted changes exist
- **Doc freshness nudge** → UserPromptSubmit warns after 3+ impl writes with 0 doc writes
- **Progress nudge** → UserPromptSubmit suggests committing after 15+ edits
- **Pre-commit gates** → 23 checks including spec consistency, test execution, shipped spec protection
- **Session stop blocked** → Can't end session with unshipped merges or branches without PRs

## Before committing
1. Update journal: `bash .agentic/lib/tools/journal.sh "Topic" "Done" "Next" "Blockers" --why "Reason"`
2. Update status: `bash .agentic/lib/tools/status.sh focus "Current task"`
3. If shipping feature: `bash .agentic/lib/tools/feature.sh F-#### status shipped`
4. Check doc freshness: `bash .agentic/lib/tools/docs.sh --check-freshness --trigger feature_done --manifest F-XXXX`

## Rules
- Never auto-commit in interactive sessions. Show diff to human first.
- Never bypass hooks (`--no-verify`). Fix the underlying issue.
- PR by default. After creating PR, add to HUMAN_NEEDED.md.
- Stage specific files (`git add <files>`), not `git add .`
- Include JOURNAL.md, STATUS.md in commits. Exclude VERSION, BACKLOG.json.
- Before committing, grep `spec/contracts/` for assertions related to changed behavior. If any are affected, **STOP** — present them to the user. Contracts protect shipped behavior.

## Post-merge
ALWAYS run `ag done F-XXXX` on main after merge. Never skip it — it runs doc freshness gates (Gate 4), contract checks, VERSION bump, and state flush.
