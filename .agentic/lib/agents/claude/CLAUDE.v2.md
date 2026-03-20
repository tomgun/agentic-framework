# Project Instructions

## Workflow

All work is managed by `ag` commands. The CLI enforces the workflow — never skip steps.

- `ag v2-start F-XXXX "Title"` — begin a new feature (creates work item, starts planning)
- `ag v2-transition F-XXXX <state>` — advance the workflow (checks artifacts before proceeding)
- `ag v2-check F-XXXX` — validate artifacts before proceeding
- `ag v2-verify F-XXXX` — run tests and record results
- `ag v2-ship F-XXXX` — prepare for shipping
- `ag v2-status` — see current work items
- `ag v2-info F-XXXX` — detailed work item info with next steps

## Artifacts

Write artifacts to `.agentic/work/F-XXXX/`:
- `plan.md` — implementation plan (required before coding)
- `spec.md` — acceptance criteria and feature spec
- `review.md` — adversarial review output
- `journal.md` — decisions, changes, and session handoffs
- `verification.json` — test results (created by `ag v2-verify`)

The CLI tells you what's missing. If a transition is blocked, it shows exactly which artifacts you need to create.

## Rules

- Never auto-commit in interactive sessions. Show changes to human first.
- Never fabricate APIs, data, or behavior. If uncertain, ask.
- Use token-efficient scripts for state files: `journal.sh`, `status.sh`, `todo.sh`
- Keep commits small: max 5-10 files per commit.
- Write tests alongside code, not after.
- Ask when uncertain about scope or approach.
