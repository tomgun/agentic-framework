---
summary: "Action rules agents write to persistent memory at session start"
tokens: ~1130
---

# Memory Seed — Agentic Framework Action Rules

<!-- memory-seed v0.49.0 -->
<!-- sentinels: pre-commit sequence, token-efficient scripts, ag commit, ag done, ag docs, ag todo, ag backlog -->

Write these rules to your persistent memory. They are action triggers — when a condition is met, execute the specified command. Do not treat these as suggestions.

## When the user wants to build something

If the user's intent is to build, implement, add, create, set up, develop, make, or work on a feature — in any phrasing:

**STOP.** Do not write code yet.

1. If no feature ID exists: assign the next available F-XXXX in .agentic/spec/FEATURES.md
2. Create .agentic/spec/acceptance/F-XXXX.md with acceptance criteria FIRST
3. Run `ag plan F-XXXX` (starts the plan-review loop)
4. Run `ag implement F-XXXX` after the plan is approved

**A plan is NOT a spec.** Even when implementing from a detailed plan, create the formal artifacts (FEATURES.md entry + acceptance file) BEFORE writing any code. Plans contain design; specs contain the testable contract.
5. If `spec_analysis` is enabled (default: on for formal, off for discovery), `spec-analyze.sh` runs advisory checks — review findings but proceed regardless

`ag implement` auto-creates WIP tracking. If bypassing ag: run `bash .agentic/lib/tools/wip.sh start F-XXXX "desc" "files"` before coding.

Never write implementation code before acceptance criteria exist. This is a structural rule, not a suggestion.

If they say "implement entire", "full system", "complete", or describe something that would touch >10 files: **STOP — TOO BIG.** Break into 3-5 smaller tasks first.

## Plans must be saved — ALWAYS

Plans are durable artifacts. They WILL BE LOST if not saved to `.agentic/journal/plans/`. Save them regardless of how they arrive:

**After exiting plan mode**: Copy from the tool's plan location to `.agentic/journal/plans/F-XXXX-plan.md` using `ag plan --save <plan-file> F-XXXX`. Tool plan locations (e.g. `~/.claude/plans/`) are session-scoped and WILL BE LOST.

**When the user provides a plan in a message** (e.g., "implement this plan:"): Save the plan content to `.agentic/journal/plans/YYYY-MM-DD-F-XXXX-<slug>-plan.md` BEFORE writing any code. The conversation context will be lost; the plan file persists.

Then:
1. Run `ag implement F-XXXX` (auto-creates WIP lock — prevents work loss on token limits/crashes)
2. Check `plan_review_enabled` in STACK.md — if `yes`, invoke `/review` on the saved plan file first
3. Only proceed to implementation after the review completes (or if review is disabled)

## When the user reports a bug or wants a fix

If the user's intent is to fix, debug, repair, resolve, investigate, troubleshoot, or address a bug/issue/error:

**STOP.** Write a failing test that reproduces the bug FIRST. Then fix it. Then verify the test passes.

## When committing or pushing

If the user wants to commit, push, save, ship, or finalize changes:

**STOP.** Check `.agentic/session/WIP.md` first — if it exists, BLOCK and warn. Otherwise, follow the pre-commit sequence below, then run `ag commit`.

## When the user mentions an idea, todo, or reminder

If the user says remember, todo, idea, note for later, tasklist, or mentions something to track:

**STOP.** Run `ag todo "description"` to capture it in .agentic/TODO.md (git-tracked, survives context compression).

## When the user asks about work queue, backlog, or what's next

If the user says backlog, queue, next up, what's next, what should I work on, prioritize, reorder, or mentions work assignment:

**STOP.** Run `ag backlog` to see the current work queue. Use `ag backlog add F-XXXX` to add items, `ag backlog done` to advance, `ag backlog move F-XXXX 0` to reprioritize. Position 0 = current work. `ag implement` enforces backlog order.

## When the user expresses a system invariant or quality constraint

If the user says "it must always...", "never do X", "performance must stay under...", "security requirement", "accessibility", or describes a cross-cutting constraint that applies beyond a single feature:

**STOP.** This is a Non-Functional Requirement. Check `.agentic/spec/NFR.md` — if no matching NFR exists, assign the next NFR-XXXX ID and write it there. NFRs are invariants that must hold across all features, not just the one being discussed. Don't let them stay informal in conversation.

## When work is done

If the user says done, complete, finished, wrapped up, or indicates a feature is ready:

**STOP.** Run `ag done F-XXXX`. Do not just tell the user it's done — run the command. Before ending, check your TaskList for pending items and flush them to .agentic/TODO.md via `ag todo`.

## When work is done (doc lifecycle)

After `ag done F-XXXX` completes, if STACK.md has a `## Docs` section with entries:
the doc lifecycle fires automatically (docs.sh assembles context, you draft the docs).
You can also run `ag docs F-XXXX` manually to draft registered docs for a feature.

## Who tests the tests?

When reviewing test quality — whether during implementation, retro, or audit — ask: "Could this test pass with a broken implementation?" If the answer is yes, the test is weak.

Run `ag audit` to verify the spec→AC→test chain. Use `ag audit --propagate NFR-XXXX` to trace NFR changes downstream.

## Pre-commit sequence (never skip steps)

Every time before committing, execute these commands in order:

1. `bash .agentic/lib/tools/journal.sh "Topic" "What changed (outcomes, not files)" "Next" "Blockers" --why "Problem being solved"` — update JOURNAL.md (always include --why, describe outcomes not implementation details)
2. `bash .agentic/lib/tools/status.sh focus "Current task"` — update .agentic/STATUS.md
3. If shipping a feature (Formal): `bash .agentic/lib/tools/feature.sh F-#### status shipped`
4. `ag commit` — runs quality gates, shows diff, waits for human approval
5. Only THEN announce ready — never say "done" before artifacts are updated

## Token-efficient scripts (always use these)

Never read or edit these files directly. Always use the scripts:

| File | Command |
|------|---------|
| .agentic/STATUS.md | `bash .agentic/lib/tools/status.sh focus "Task"` |
| .agentic/journal/JOURNAL.md | `bash .agentic/lib/tools/journal.sh "Topic" "Outcomes" "Next" "Blockers" --why "Why"` |
| .agentic/HUMAN_NEEDED.md | `bash .agentic/lib/tools/blocker.sh add "Title" "type" "Details"` |
| .agentic/spec/FEATURES.md | `bash .agentic/lib/tools/feature.sh F-#### status shipped` |
| .agentic/TODO.md | `bash .agentic/lib/tools/todo.sh add "Idea"` or `ag todo "Idea"` |

## Session start

When a session begins, immediately:

1. Read .agentic/STATUS.md, .agentic/HUMAN_NEEDED.md, last 2-3 .agentic/journal/JOURNAL.md entries
2. Run `bash .agentic/lib/tools/wip.sh check` for interrupted work
3. Greet user with dashboard: current focus, recent progress, blockers, suggested next steps

## NFR proactive suggestion

If NFR.md exists but only has template content (no project-specific NFRs) after 3+ features are shipped, suggest NFR discovery at session start:

> "You've shipped 3+ features but haven't defined project-specific NFRs yet. Quality constraints help catch issues early. Run `ag nfr discover` to review suggestions for your stack."

## Where to log things

- Prioritized work item → `ag backlog add F-XXXX` or `ag backlog add --task "desc"` (.agentic/BACKLOG.json)
- Development idea or task → `ag todo "description"` (.agentic/TODO.md)
- Needs human action (PR review, credentials, decision) → `blocker.sh` (.agentic/HUMAN_NEEDED.md)
- Bug or technical debt → .agentic/spec/ISSUES.md
- New capability to spec → .agentic/spec/FEATURES.md

**Backlog vs TODO**: Backlog = committed, ordered work queue (what to do next). TODO = unfiltered idea inbox. Flow: idea → `ag todo` → triage → `ag backlog add`.

Do NOT put development tasks in .agentic/HUMAN_NEEDED.md.

## Rules that always apply

- **Never auto-commit.** Human reviews every change first.
- **Never bypass gates.** Do not use `--no-verify` or skip quality checks.
- **NEVER `git stash`.** Stash pop does a silent merge — in multi-agent contexts, when another agent modified the same files, it quietly picks one version with no error, causing data loss. Safe alternatives: worktrees, temp branch + cherry-pick, or commit before switching. Also never `git checkout -- .`, `git restore .`, or `git reset --hard` with uncommitted changes.
- **One feature at a time.** Complete current WIP before starting another.
- **Small batches.** Max 5-10 files per commit. If bigger, break it up.
- **Smoke test before "done".** Actually run the feature. "Tests pass" does not mean "it works."
