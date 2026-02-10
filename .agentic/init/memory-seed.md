# Memory Seed — Agentic Framework Behavioral Patterns

<!-- memory-seed v0.24.0 -->

These are workflow patterns for agents working in an agentic framework project. Write them to your persistent memory so they survive across sessions.

## Pre-Commit Sequence (never skip steps)

1. Update JOURNAL.md: `bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers"`
2. Update STATUS.md: `bash .agentic/tools/status.sh focus "Current task"`
3. Run `ag commit` (runs quality gates, shows diff, waits for human approval)
4. THEN announce ready — never announce "done" before artifacts are updated

## Session Start

1. Read STATUS.md, HUMAN_NEEDED.md, last 2-3 JOURNAL.md entries
2. Check `bash .agentic/tools/wip.sh check` for interrupted work
3. Greet user with dashboard: current focus, recent progress, blockers, suggested next steps
4. Full protocol: `.agentic/checklists/session_start.md`

## Feature Work Flow

1. **Plan first**: `ag plan F-XXXX` — never start coding without a plan
2. **Acceptance criteria before code**: Core+PM needs `spec/acceptance/F-####.md`; Core needs criteria in any form
3. **Implement**: `ag implement F-XXXX` — small batches, max 5-10 files per commit
4. **Test**: Add/update tests for all new/changed logic
5. **Update state**: Journal + Status before committing
6. **Done**: `ag done F-XXXX` — updates features, status, journal

## Token-Efficient Scripts (always use these)

Never read or edit state files directly. Always use scripts:
- `bash .agentic/tools/status.sh focus "Task"` → STATUS.md
- `bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers"` → JOURNAL.md
- `bash .agentic/tools/blocker.sh add "Title" "type" "Details"` → HUMAN_NEEDED.md
- `bash .agentic/tools/feature.sh F-#### status shipped` → FEATURES.md

## Common Pitfalls

- **Don't bypass gates**: Quality checks exist for a reason. Don't use `--no-verify`.
- **Don't announce before updating artifacts**: Update JOURNAL.md and STATUS.md first, then tell the user you're ready.
- **Don't edit state files directly**: Use the token-efficient scripts above.
- **Don't skip the plan**: Even small features benefit from `ag plan` first.
- **Don't commit without showing changes**: Never auto-commit. Human reviews first.
- **"Too big" check**: If touching >10 files, break it into smaller batches.

## Trigger Word Awareness

When the user says "build/implement/add/create" → plan first.
When the user says "fix/bug" → write failing test first.
When the user says "commit/push" → check WIP.md first.
When the user says "done/complete" → run `ag done`.
