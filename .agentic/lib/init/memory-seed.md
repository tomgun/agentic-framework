# Memory Seed — Agentic Framework

All work is managed by `ag` commands. The CLI enforces the workflow — never skip steps.

## Key Commands
- `ag start F-XXXX "Title"` — begin feature (creates work item, starts planning)
- `ag transition F-XXXX <state>` — advance workflow (checks artifacts first)
- `ag check F-XXXX` — see what's missing for next transition
- `ag verify F-XXXX` — run tests and record results
- `ag done F-XXXX` — post-merge: doc gate, VERSION bump, state flush
- `ag status` — see current work items
- `ag commit` | `ag done` | `ag todo` | `ag backlog` | `ag git-init` | `ag contract` | `ag phase`

## Trigger Words
- "phase done/mark phase/phase progress/which phase" → STOP. Run `ag phase list F-XXXX` to see phases, `ag phase done F-XXXX <id>` to mark complete.
- "pending user input/contract input" → STOP. Run `ag contract pending`. Process each pending contract.
- "contract/assertion/verify contract/check contract" → Run `ag contract check` or `ag contract list`. Contracts are in `spec/contracts/F-XXXX.yaml`.
- "migrate specs/convert acceptance/markdown to yaml" → STOP. Run `ag migrate-specs` (add `--dry-run` to preview, `--archive` to move old files).
- "churn/batch/all tasks/build everything/implement everything/do all features" → STOP. Run `ag auto crunch`.
- "protected branch/can't push to main/push rejected" → Check `main_branch_mode` in STACK.md. If not set, suggest `ag set main_branch_mode protected`. When protected, `ag flush` creates a branch + PR instead of direct push.
- "work autonomously/come back with working/finish everything/do it all" → STOP. Run `ag auto crunch`.
- User correction: "no/don't/stop/always/never/I prefer" → STOP. Capture with `ag intel remember "what they said" --context "what you were doing"`. Preferences and learnings are project-scoped (cerebrum.yaml).
- "intelligence/patterns/quality checks" → Run `ag intel` subcommands (check, learn, remember, patterns, cerebrum).
- Before workflow phases: run `ag intel architecture` (planning), `ag intel spec F-XXXX` (specs), `ag intel implement F-XXXX` (coding), `ag intel test F-XXXX` (testing) for phase-aware quality guidance.
- NEVER write code for multiple features outside of `ag auto` commands.
- **Wrong rationalizations:** "I can do it directly faster" — NO. "User said autonomous = skip ceremony" — NO. Autonomous means use the autonomous pipeline, not bypass it.

## After Plan Mode Exits — Auto-Continue (do NOT stop)
Exiting plan mode creates a DRAFT. Auto-continue immediately — do NOT stop and wait for user input.
1. Save plan to `.agentic/journal/plans/YYYY-MM-DD-F-XXXX-plan.md` with `**Status**: DRAFT`
2. Spawn Critic + Advocate agents in parallel (fresh context) for dialectical review
3. If converged → set `**Status**: APPROVED`; if not → revise plan
4. After APPROVED → run `ag transition F-XXXX implementation`
**Wrong rationalizations:** "The user created the plan" — NO. "Plan mode exit = approval" — NO. Review is structural, not discretionary.

## Documentation — Part of the Deliverable
Docs ship with code, not after merge. Before creating a PR:
1. Check freshness: `bash .agentic/lib/tools/docs.sh --check-freshness --trigger feature_done --manifest F-XXXX`
2. Update each stale doc relevant to the feature
3. Include doc changes in the same PR as code
`ag done` enforces `docs_gate` (blocking in formal profiles) — but that's the safety net, not the trigger.

## Rules
- Follow CLI prompts. It loads role-specific guidance at each phase.
- Write artifacts to `.agentic/work/F-XXXX/` (plan.md, spec.md, review.md, journal.md).
- Use token-efficient scripts: `journal.sh`, `status.sh`, `feature.sh`, `blocker.sh`, `todo.sh`.
- After code changes, grep `spec/contracts/` for affected assertions. If any, STOP and present to user before modifying contracts or tests. Contracts protect shipped behavior; silently updating them defeats that protection.
- NEVER write code for multiple features outside of `ag auto` commands. The `ag auto` pipeline ensures each feature gets specs, plans, tests, and docs — not just code.
- **No feature inflation**: Improvements, enforcement, and hardening of existing features are deliverables on those features — not new F-XXXX. Ask "which existing feature owns this?" before proposing a new ID.
- **Behavioral corrections belong in instruction files**: When a correction applies to this project, update CLAUDE.md or the relevant skill file — don't write a memory as a substitute.
- **Feature ID patterns are centralized**: `ids.py` (Python) and `ids.sh` (shell) are the single source of truth for feature ID regexes. Import `FEATURE_ID_RE`, `FEATURE_HEADER_RE`, etc. — never inline `F-\d{4,}` or `F-[0-9]{4,}` patterns in code.
