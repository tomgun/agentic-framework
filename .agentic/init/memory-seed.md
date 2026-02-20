# Memory Seed — Agentic Framework Action Rules

<!-- memory-seed v0.31.0 -->
<!-- sentinels: pre-commit sequence, token-efficient scripts, ag commit, ag done, ag docs, ag todo -->

Write these rules to your persistent memory. They are action triggers — when a condition is met, execute the specified command. Do not treat these as suggestions.

## When the user wants to build something

If the user's intent is to build, implement, add, create, set up, develop, make, or work on a feature — in any phrasing:

**STOP.** Do not write code yet.

1. If no feature ID exists: assign the next available F-XXXX in spec/FEATURES.md
2. Create spec/acceptance/F-XXXX.md with acceptance criteria FIRST
3. Run `ag plan F-XXXX` (starts the plan-review loop)
4. Run `ag implement F-XXXX` after the plan is approved

`ag implement` auto-creates WIP tracking. If bypassing ag: run `bash .agentic/tools/wip.sh start F-XXXX "desc" "files"` before coding.

Never write implementation code before acceptance criteria exist. This is a structural rule, not a suggestion.

If they say "implement entire", "full system", "complete", or describe something that would touch >10 files: **STOP — TOO BIG.** Break into 3-5 smaller tasks first.

## After exiting plan mode

When you exit the tool's native plan mode and the plan is approved:

1. Save the plan to `.agentic-journal/plans/F-XXXX-plan.md` using `ag plan --save <plan-file> F-XXXX` (tool-specific plan locations are session-scoped and will be lost)
2. Run `ag implement F-XXXX` (auto-creates WIP lock — prevents work loss on token limits/crashes)
3. Check `plan_review_enabled` in STACK.md — if `yes`, invoke `/review` on the saved plan file first
4. Only proceed to implementation after the review completes (or if review is disabled)

## When the user reports a bug or wants a fix

If the user's intent is to fix, debug, repair, resolve, investigate, troubleshoot, or address a bug/issue/error:

**STOP.** Write a failing test that reproduces the bug FIRST. Then fix it. Then verify the test passes.

## When committing or pushing

If the user wants to commit, push, save, ship, or finalize changes:

**STOP.** Check `.agentic-state/WIP.md` first — if it exists, BLOCK and warn. Otherwise, follow the pre-commit sequence below, then run `ag commit`.

## When the user mentions an idea, todo, or reminder

If the user says remember, todo, idea, note for later, tasklist, or mentions something to track:

**STOP.** Run `ag todo "description"` to capture it in TODO.md (git-tracked, survives context compression).

## When work is done

If the user says done, complete, finished, wrapped up, or indicates a feature is ready:

**STOP.** Run `ag done F-XXXX`. Do not just tell the user it's done — run the command. Before ending, check your TaskList for pending items and flush them to TODO.md via `ag todo`.

## When work is done (doc lifecycle)

After `ag done F-XXXX` completes, if STACK.md has a `## Docs` section with entries:
the doc lifecycle fires automatically (docs.sh assembles context, you draft the docs).
You can also run `ag docs F-XXXX` manually to draft registered docs for a feature.

## Pre-commit sequence (never skip steps)

Every time before committing, execute these commands in order:

1. `bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers" --why "Problem being solved"` — update JOURNAL.md (always include --why)
2. `bash .agentic/tools/status.sh focus "Current task"` — update STATUS.md
3. If shipping a feature (Formal): `bash .agentic/tools/feature.sh F-#### status shipped`
4. `ag commit` — runs quality gates, shows diff, waits for human approval
5. Only THEN announce ready — never say "done" before artifacts are updated

## Token-efficient scripts (always use these)

Never read or edit these files directly. Always use the scripts:

| File | Command |
|------|---------|
| STATUS.md | `bash .agentic/tools/status.sh focus "Task"` |
| JOURNAL.md | `bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers" --why "Reason"` |
| HUMAN_NEEDED.md | `bash .agentic/tools/blocker.sh add "Title" "type" "Details"` |
| FEATURES.md | `bash .agentic/tools/feature.sh F-#### status shipped` |
| TODO.md | `bash .agentic/tools/todo.sh add "Idea"` or `ag todo "Idea"` |

## Session start

When a session begins, immediately:

1. Read STATUS.md, HUMAN_NEEDED.md, last 2-3 JOURNAL.md entries
2. Run `bash .agentic/tools/wip.sh check` for interrupted work
3. Greet user with dashboard: current focus, recent progress, blockers, suggested next steps

## Where to log things

- Development idea or task → `ag todo "description"` (TODO.md)
- Needs human action (PR review, credentials, decision) → `blocker.sh` (HUMAN_NEEDED.md)
- Bug or technical debt → ISSUES.md
- New capability to spec → FEATURES.md

Do NOT put development tasks in HUMAN_NEEDED.md.

## Rules that always apply

- **Never auto-commit.** Human reviews every change first.
- **Never bypass gates.** Do not use `--no-verify` or skip quality checks.
- **One feature at a time.** Complete current WIP before starting another.
- **Small batches.** Max 5-10 files per commit. If bigger, break it up.
- **Smoke test before "done".** Actually run the feature. "Tests pass" does not mean "it works."
