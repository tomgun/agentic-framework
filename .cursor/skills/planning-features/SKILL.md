---
name: planning-features
description: >
  Create implementation plans with iterative review. Use when user says "plan",
  "design", "ag plan", "how should we build", "let's plan", "architecture",
  or wants to think through an approach before coding.
  Do NOT use for: implementing (use implementing-features after plan approval),
  reviewing existing code (use reviewing-code).
compatibility: "Requires Cursor Agent mode with plan mode support."
allowed-tools: [Read, Glob, Grep, Bash, Agent]
metadata:
  author: agentic-framework
  version: "${VERSION}"
---
# Planning Features

Run `ag start F-XXXX "Title"` to begin — the CLI starts in the planning state.
Explore the codebase, draft a plan, and save it durably.

Key commands:
- `ag start F-XXXX "Title"` — create work item (starts in planning)
- `ag transition F-XXXX plan_review` — submit plan for review
- `ag check F-XXXX` — see what artifacts are missing

Plans are saved to `.agentic/journal/plans/YYYY-MM-DD-F-XXXX-plan.md`.
Plans in `~/.claude/plans/` are session-scoped — always copy to the durable location.
