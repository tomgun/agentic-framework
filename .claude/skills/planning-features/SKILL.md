---
name: planning-features
description: >
  Create implementation plans with iterative review. Use when user says "plan",
  "design", "ag plan", "how should we build", "let's plan", "architecture",
  or wants to think through an approach before coding.
  Do NOT use for: implementing (use implementing-features after plan approval),
  reviewing existing code (use reviewing-code).
compatibility: "Requires Claude Code with plan mode support."
allowed-tools: [Read, Glob, Grep, Bash, Agent]
metadata:
  author: agentic-framework
  version: "0.62.0"
---
# Planning Features

Run `ag start F-XXXX "Title"` to begin — the CLI starts in the planning state.
Explore the codebase, draft a plan, and save it durably.

**Before planning**: Run `ag intel architecture` to gather ADRs, NFRs, and quality checks for the planning phase.

Key commands:
- `ag start F-XXXX "Title"` — create work item (starts in planning)
- `ag transition F-XXXX plan_review` — submit plan for review
- `ag check F-XXXX` — see what artifacts are missing

Plans are saved to `.agentic/journal/plans/YYYY-MM-DD-F-XXXX-plan.md`.
Plans in `~/.claude/plans/` are session-scoped — always copy to the durable location.

## What's Enforced Automatically
- **DRAFT plan blocks code** → PreToolUse denies code edits when DRAFT plan exists (formal)
- **DRAFT plan blocks session stop** → Stop.sh denies session end when DRAFT plan exists
- **Review evidence required** → Plan can't be marked APPROVED without review.md evidence (autonomous_formal)
- **Plan saved as DRAFT** → ExitPlanMode hook mechanically injects DRAFT status
- **Review-pending sentinel** → Created automatically, blocks code until review complete

## After plan mode exits — auto-continue (do NOT stop)

Exiting plan mode creates a DRAFT. The framework blocks code edits and session stop until resolved. Auto-continue immediately:
1. Save plan to `.agentic/journal/plans/YYYY-MM-DD-F-XXXX-plan.md` with `**Status**: DRAFT`
2. Spawn Critic + Advocate agents in parallel (fresh context) for dialectical review
3. Save review findings to `.agentic/work/F-XXXX/review.md` (required for evidence check)
4. Synthesize feedback — if converged, set `**Status**: APPROVED`; if not, revise
5. After APPROVED → run `ag transition F-XXXX implementation`

**Do NOT stop and wait for user input between plan and review.** Review is structural, not discretionary. The framework enforces this: you literally cannot write code or stop the session with an unreviewed plan.
