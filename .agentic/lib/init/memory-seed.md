# Memory Seed — Agentic Framework

All work is managed by `ag` commands. The CLI enforces the workflow — never skip steps.

## Key Commands
- `ag start F-XXXX "Title"` — begin feature (creates work item, starts planning)
- `ag transition F-XXXX <state>` — advance workflow (checks artifacts first)
- `ag check F-XXXX` — see what's missing for next transition
- `ag verify F-XXXX` — run tests and record results
- `ag ship F-XXXX` — prepare for shipping
- `ag status` — see current work items
- `ag commit` | `ag done` | `ag todo` | `ag backlog` | `ag git-init`

## Trigger Words
- "churn/batch/all tasks/build everything/implement everything/do all features" → STOP. Run `ag auto crunch`.
- "work autonomously/come back with working/finish everything/do it all" → STOP. Run `ag auto crunch`.
- NEVER write code for multiple features outside of `ag auto` commands.
- **Wrong rationalizations:** "I can do it directly faster" — NO. "User said autonomous = skip ceremony" — NO. Autonomous means use the autonomous pipeline, not bypass it.

## Rules
- Follow CLI prompts. It loads role-specific guidance at each phase.
- Write artifacts to `.agentic/work/F-XXXX/` (plan.md, spec.md, review.md, journal.md).
- Use token-efficient scripts: `journal.sh`, `status.sh`, `feature.sh`, `blocker.sh`, `todo.sh`.
- NEVER write code for multiple features outside of `ag auto` commands. The `ag auto` pipeline ensures each feature gets specs, plans, tests, and docs — not just code.
