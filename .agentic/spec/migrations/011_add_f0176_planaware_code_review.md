<!-- migration-id: 011 -->
<!-- date: 2026-03-07 -->
<!-- author: Tomas Günther -->
<!-- type: feature -->

# Migration 011: Add F-0176 plan-aware code review

## Context & Why

The reviewing-code skill reviews against a generic checklist (correctness, security, performance, etc.) but has no awareness of implementation plans. For plan-driven development, the most valuable review dimension is whether the implementation matches what was agreed in the plan — missing deliverables, unplanned additions, deviations.

## Changes

### Features Added

- F-0176: Plan-Aware Code Review
  - Step 1b searches `.agentic/journal/plans/` for matching plan files
  - "Plan Alignment" added as first review dimension
  - Flags: missing deliverables, unplanned additions, deviations

## Dependencies

- **Requires**: None
- **Blocks**: None
- **Related**: F-0143 (Skills-Primary Architecture)

## Rollback Plan

1. Revert SKILL.md changes in both `.claude/skills/` and `.agentic/lib/agents/claude/skills/`
2. Remove Plan Alignment section from `review_checklist.md`

## Related Files

- `.claude/skills/reviewing-code/SKILL.md` — Step 1b + Plan Alignment dimension
- `.agentic/lib/agents/claude/skills/reviewing-code/SKILL.md` — same
- `.claude/skills/reviewing-code/references/review_checklist.md` — Plan Alignment section
- `.agentic/spec/acceptance/F-0176.md` — new
