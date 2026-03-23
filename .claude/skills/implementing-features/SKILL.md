---
name: implementing-features
description: >
  Implements features using contract-driven workflow with structural gates.
  Use when user says "build", "implement", "add feature", "create [thing]",
  "implement F-XXXX", "ag implement", or describes new functionality to build.
  Do NOT use for: one-line fixes (use fixing-bugs), writing tests only
  (use writing-tests), code review (use reviewing-code), documentation-only
  changes (use updating-documentation).
compatibility: "Requires Claude Code with shell access and ag commands."
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, Agent]
metadata:
  author: agentic-framework
  version: "0.62.0"
---
# Implementing Features

Run `ag start F-XXXX "Title"` to begin, then follow the CLI prompts.
The CLI checks artifacts, enforces transitions, and emits role-specific guidance.

Key commands:
- `ag start F-XXXX "Title"` — create work item, begin planning
- `ag transition F-XXXX <state>` — advance when artifacts ready
- `ag check F-XXXX` — see what's missing
- `ag verify F-XXXX` — run tests
- `ag ship F-XXXX` — prepare to ship
- `ag contract check F-XXXX` — verify contract assertions pass

## REQUIRED: Use the CLI

> **Always call `ag implement F-XXXX` as a CLI command — do NOT start coding directly.**
> `ag implement` enforces plan-approval gates (Step 0.5), spec checks, and sets up the
> worktree. Bypassing it breaks the enforcement chain and allows DRAFT plans to reach code.

## Preconditions
- Feature must have a YAML contract at `spec/contracts/F-XXXX.yaml` with assertions
- Contract lifecycle must be `specifying` or later (not `exploring`)
- If pending `user_input` exists on the contract, process it first (write tests → implement → migrate → clear)

## Contract & test impact check
After making code changes, grep `spec/contracts/` for assertions related to the changed behavior. If any are affected, **STOP** — present the affected assertions to the user and wait for approval before modifying any contract or test. Contracts protect shipped behavior; silently updating them to match new code defeats that protection.
