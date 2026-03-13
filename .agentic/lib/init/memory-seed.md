---
summary: "Action rules agents write to persistent memory at session start"
tokens: ~1130
---

# Memory Seed — Agentic Framework Action Rules

<!-- memory-seed v0.54.1 -->
<!-- sentinels: pre-commit sequence, token-efficient scripts, ag commit, ag done, ag docs, ag docs generate, ag todo, ag backlog, dialectical review, ag review, ag worktree, ag decompose, AGENTS.json, autonomous_formal, silent session start, collision guard, ag intent, intent journal, ag auto epic, ag coord, docs-with-code, instruction-sync, llm-test-advisory, docs-validate, docs-create, docs-mode-deferred, ag kickoff, vision-to-backlog pipeline, staging area, review_commit -->

Write these rules to your persistent memory. They are action triggers — when a condition is met, execute the specified command. Do not treat these as suggestions.

## When the user wants to build something

If the user's intent is to build, implement, add, create, set up, develop, make, or work on a feature — in any phrasing:

**STOP.** Do not write code yet.

1. If no feature ID exists: assign the next available F-XXXX in .agentic/spec/FEATURES.md
2. Create .agentic/spec/acceptance/F-XXXX.md with acceptance criteria FIRST
3. Run `ag plan F-XXXX` (starts the plan-review loop)
4. Run `ag implement F-XXXX` after the plan is approved

**A plan is NOT a spec.** Even when implementing from a detailed plan, create the formal artifacts (FEATURES.md entry + acceptance file) BEFORE writing any code. Plans contain design; specs contain the testable contract.
5. If `spec_analysis` is enabled (default: on for formal/autonomous_formal, off for discovery), `spec-analyze.sh` runs advisory checks — review findings but proceed regardless

**Profiles**: `discovery` (lightweight), `formal` (full spec-driven), `autonomous_formal` (formal rigor but review_code/review_regression delegated to critical_agent — only review_merge stays human). Use `is_formal_like()` to check if a profile has formal rigor (returns true for both formal and autonomous_formal).

`ag implement` auto-creates WIP tracking. If `worktree_mode: always` in STACK.md, `ag implement` also auto-creates a git worktree for the feature branch. Use `ag worktree` (create|list|remove|path|status) to manage worktrees manually. If bypassing ag: run `bash .agentic/lib/tools/wip.sh start F-XXXX "desc" "files"` before coding.

Never write implementation code before acceptance criteria exist. This is a structural rule, not a suggestion.

If they say "implement entire", "full system", "complete", or describe something that would touch >10 files: **STOP — TOO BIG.** Break into 3-5 smaller tasks first.

## Plans must be saved — ALWAYS

Plans are durable artifacts. They WILL BE LOST if not saved to `.agentic/journal/plans/`. Save them regardless of how they arrive:

**After exiting plan mode**: IMMEDIATELY continue with the post-plan-mode steps — do NOT wait for user to say "implement":
1. Save plan to `.agentic/journal/plans/F-XXXX-plan.md` with status DRAFT (tool plan locations like `~/.claude/plans/` are session-scoped and WILL BE LOST)
2. If `plan_review_enabled: yes` in STACK.md: run dialectical review — spawn Critic + Advocate agents in parallel (fresh context), synthesize both perspectives (with Revision Guidance), present to user. User decides: Proceed (→ APPROVED), Revise (→ Planner revises, fresh review), or Reject
3. If review not enabled: set plan status to APPROVED directly

**When the user provides a plan in a message** (e.g., "implement this plan:"): Save the plan content to `.agentic/journal/plans/YYYY-MM-DD-F-XXXX-<slug>-plan.md` BEFORE writing any code. The conversation context will be lost; the plan file persists.

Then:
1. Run `ag implement F-XXXX` (auto-creates WIP lock — prevents work loss on token limits/crashes)
2. `ag implement` requires an approved plan — if no plan exists, it triggers the planning workflow first (plan → save → review → approve). If plan exists but status is not APPROVED, it triggers review first
3. Only proceed to implementation after the plan is APPROVED (or if review is disabled)

## When the user reports a bug or wants a fix

If the user's intent is to fix, debug, repair, resolve, investigate, troubleshoot, or address a bug/issue/error — in any phrasing (e.g. "crash", "fails", "regression", "not working", "something's wrong"):

**STOP.** Write a failing test that reproduces the bug FIRST. Then fix it. Then verify the test passes.

## When committing or pushing

If the user wants to commit, push, save, ship, or finalize changes — in any phrasing (e.g. "save changes", "create PR", "ready to go"):

**STOP.** Check AGENTS.json for active WIP (via `bash .agentic/lib/tools/wip.sh check`) — if WIP exists, BLOCK and warn. Otherwise, follow the pre-commit sequence below, then run `ag commit`.

**Spec + code + tests + docs = done.** If your change affects user-visible behavior, run `bash .agentic/lib/tools/drift.sh --docs` to detect stale project docs and `bash .agentic/lib/tools/docs.sh --validate` to check registry health. Update all artifacts in the same commit — don't defer to a follow-up. If you add or substantially change a doc, ensure `## Docs` in STACK.md lists it with correct component/area tags. Use `docs.sh --create <path> --type <type> --trigger <trigger>` to scaffold a new doc and auto-register it.

**Exception: `docs_mode: deferred`** — when set in STACK.md, skip inline doc updates during implementation. `ag done` will log what docs are needed to `.agentic/deferred-docs.json` instead of triggering immediate drafting. Run `ag docs generate` later to process the deferred queue. Framework instruction file updates (framework dev only) are NOT deferred — always inline.

## When the user mentions an idea, todo, or reminder

If the user says remember, todo, idea, note for later, tasklist, or mentions something to track:

**STOP.** Run `ag todo "description"` to capture it in .agentic/TODO.md (git-tracked, survives context compression).

## When the user asks about work queue, backlog, or what's next

If the user says backlog, queue, next up, what's next, what should I work on, prioritize, reorder, or mentions work assignment:

**STOP.** Run `ag backlog` to see the current work queue. Use `ag backlog add F-XXXX` to add items, `ag backlog done` to advance, `ag backlog move F-XXXX 0` to reprioritize. Position 0 = current work. `ag implement` enforces backlog order.

## When the user expresses a system invariant or quality constraint

If the user says "it must always...", "never do X", "performance must stay under...", "security requirement", "accessibility", or describes a cross-cutting constraint that applies beyond a single feature:

**STOP.** This is a Non-Functional Requirement. Check `.agentic/spec/NFR.md` — if no matching NFR exists, assign the next NFR-XXXX ID and write it there. NFRs are invariants that must hold across all features, not just the one being discussed. Don't let them stay informal in conversation.

## When the user wants to decompose an epic

If the user says decompose, break down, split into children, break apart, subdivide, or wants to turn a large feature into smaller child features:

**STOP.** Run `ag decompose F-XXXX`. This analyzes the epic's acceptance criteria, maps them to components, proposes child features, and routes through the `review_decomposition` checkpoint. Child features get `Parent: F-XXXX` in FEATURES.md. The epic's status is automatically derived from its children's statuses after any child transition.

## When the user wants to execute an epic autonomously

If the user says execute epic, implement all children, run epic autonomously, process epic features, or wants to autonomously implement all child features of an epic:

**STOP.** Run `ag auto epic F-XXXX`. This reads the epic's child features, schedules component-scoped workers with non-blocking reviews, and executes each child feature autonomously. Requires the epic to be decomposed first (children must exist in FEATURES.md with acceptance criteria).

## When the user has a product vision to turn into a backlog

If the user says kickoff, vision, draft epic from idea, generate features, turn this idea into a backlog, or wants to convert a product vision into structured spec artifacts:

**STOP.** Run `ag kickoff "vision description"`. This generates OVERVIEW.md, FEATURES.md entries, acceptance criteria stubs, and BACKLOG.json in a staging area (`.agentic/session/kickoff-draft/`). Use `ag kickoff --review` to present staging for review/iteration, `ag kickoff --approve` to promote to real spec files, `ag kickoff --discard` to start over. After approval, suggest `ag auto epic` for autonomous execution.

## When the user wants to know how to run the project

If the user says run, how to run, dev server, start the app, run commands, what commands, or wants to know how to run/start/build/test the project:

**STOP.** Run `ag run`. This detects the stack from STACK.md and auto-detection, then displays dev server, build, and test commands with source attribution (STACK.md vs auto-detected).

## When the user wants parallel agent coordination

If the user says start coordination server, parallel agents, remote control, remote review, mobile status, or wants multiple agents working in parallel on different features:

**STOP.** Run `ag coord start` to start the coordination server. This provides an HTTP JSON-RPC API (default 127.0.0.1:4185) with 8 tools: claim_feature, release_feature, transition_state, get_unblocked, poll_changes, report_status, request_review, submit_review. Bearer token auth is generated automatically. Use `ag coord status` to check and `ag coord stop` to shut down.

## When a transition is blocked by a review checkpoint

If a state machine transition is blocked by a review checkpoint, or the user says review, approve, reject, pending review:

**STOP.** Run `ag review` to list all pending reviews. To resolve: `ag review F-XXXX <state>` (approves by default), or `ag review F-XXXX <state> --reject --reason "why"`. Review modes (human/critical_agent/skip) are configurable per transition in STACK.md `### Review checkpoints`. Legacy value "auto" is accepted and mapped to "skip". Taste review (`review_taste`) piggybacks on code review transitions — if style settings are declared in STACK.md `## Style & taste`, the critical agent also validates style consistency.

## When work is done

If the user indicates a feature is complete — in any phrasing (e.g. "done", "complete", "finished", "merged", "PR merged", "shipped", "landed", "wrapped up", "it's in"). Match intent, not exact words.

**STOP.** Run `ag done F-XXXX`. Do not just tell the user it's done — run the command. Before ending, check your TaskList for pending items and flush them to .agentic/TODO.md via `ag todo`. If on main (not in a worktree), run `ag flush --features` to commit state files directly to main.

## When work is done (doc lifecycle)

After `ag done F-XXXX` completes, if STACK.md has a `## Docs` section with entries:
the doc lifecycle fires automatically (docs.sh assembles context, you draft the docs).
You can also run `ag docs F-XXXX` manually to draft registered docs for a feature.

If `docs_mode: deferred` in STACK.md, `ag done` logs deferred items to `.agentic/deferred-docs.json` instead of triggering immediate drafting. Run `ag docs generate` later to process all pending entries, or `ag docs generate F-XXXX` for a single feature.

## When work was interrupted or a session crashed

If the user mentions interrupted work, crashed session, stuck intent, orphaned work, resume, or recovery — in any phrasing:

**STOP.** Run `ag intent list` to see pending and orphaned intents. Orphaned intents are from crashed sessions (dead PID). Use `ag intent clear F-XXXX` to discard an intent, or run `ag sync` to auto-adopt orphans into the current session. The intent journal provides crash recovery: `ag implement` and `ag done` write checkpoints so interrupted work can resume.

## Who tests the tests?

When reviewing test quality — whether during implementation, retro, or audit — ask: "Could this test pass with a broken implementation?" If the answer is yes, the test is weak.

Run `ag audit` to verify the spec→AC→test chain. Use `ag audit --propagate NFR-XXXX` to trace NFR changes downstream.

## Pre-commit sequence (never skip steps)

Every time before committing, execute these commands in order:

1. `bash .agentic/lib/tools/journal.sh "Topic" "What changed (outcomes, not files)" "Next" "Blockers" --why "Problem being solved"` — update JOURNAL.md (always include --why, describe outcomes not implementation details)
2. `bash .agentic/lib/tools/status.sh focus "Current task"` — update .agentic/STATUS.md
3. If shipping a feature (Formal): `bash .agentic/lib/tools/feature.sh F-#### status shipped`
4. Stage any modified state files: BACKLOG.json, STATUS.md, JOURNAL.md, HUMAN_NEEDED.md
   Or use `ag flush` to commit state files directly to main (no PR needed).
5. VERSION is bumped post-merge by `ag done`, not in PRs.
6. `ag commit` — runs quality gates, shows diff, waits for human approval
7. Only THEN announce ready — never say "done" before artifacts are updated

## Token-efficient scripts (always use these)

Never read or edit these files directly. Always use the scripts:

| File | Command |
|------|---------|
| .agentic/STATUS.md | `bash .agentic/lib/tools/status.sh focus "Task"` |
| .agentic/journal/JOURNAL.md | `bash .agentic/lib/tools/journal.sh "Topic" "Outcomes" "Next" "Blockers" --why "Why"` |
| .agentic/HUMAN_NEEDED.md | `bash .agentic/lib/tools/blocker.sh add "Title" "type" "Details"` |
| .agentic/spec/FEATURES.md | `bash .agentic/lib/tools/feature.sh F-#### status shipped` |
| .agentic/TODO.md | `bash .agentic/lib/tools/todo.sh add "Idea"` or `ag todo "Idea"` |
| AGENTS.json | Replaces WIP.md and AGENTS_ACTIVE.md for agent/WIP tracking |

## Session start

When a session begins, issue ONE tool call:

```bash
bash .agentic/lib/tools/dashboard.sh 2>/dev/null
```

Output the result **verbatim** as your first text response. No other tool calls, no preamble, no narration, no reformatting. The script renders the final dashboard (with emoji, borders, next steps). Just copy its output.

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

- **Never auto-commit in interactive sessions.** Human reviews every change first. Autonomous workflows (`ag auto task/epic`) may commit when `review_commit: critical_agent` (F-0203).
- **Never bypass gates.** Do not use `--no-verify` or skip quality checks — except `ag flush` which uses `--no-verify` with its own stricter validation (hardcoded allowlist, branch check, JSON validation). See `state-commit.sh` header comment for the conditions that make this safe.
- **NEVER `git stash`.** Stash pop does a silent merge — in multi-agent contexts, when another agent modified the same files, it quietly picks one version with no error, causing data loss. Safe alternatives: worktrees, temp branch + cherry-pick, or commit before switching. Also never `git checkout -- .`, `git restore .`, or `git reset --hard` with uncommitted changes.
- **Multi-session collision guard.** Sessions auto-register in AGENTS.json at start. Before any destructive git op, the framework checks for other active sessions on the same checkout. If others are active, you'll see a COLLISION RISK warning — do NOT proceed with destructive ops. Use a worktree (`ag worktree`) or commit first.
- **One feature at a time.** Complete current WIP before starting another.
- **Small batches.** Max 5-10 files per commit. If bigger, break it up.
- **Keep main in sync with origin.** Push immediately after any direct-to-main commit. Before creating a feature branch, `git pull --rebase origin main` first. Stale local main causes conflicts and content loss during PR rebases.
- **Smoke test before "done".** Actually run the feature. "Tests pass" does not mean "it works."
- **Spec + code + tests + docs = done.** If code changes user-facing behavior, update all artifacts in the same commit. Run `docs.sh --validate` to check registry health (missing files, unregistered docs), `docs.sh --list` to see the registry, and `drift.sh --docs` to detect staleness. If your change touches a component with no registered doc, decide whether it needs one — use `docs.sh --create <path> --type <type> --trigger <trigger>` to scaffold and auto-register. Don't defer updates to a follow-up.
- **Framework dev only — instruction files are part of the feature.** When changing `ag` commands/gates/workflows, also update instruction files (CLAUDE.md templates, cursorrules, copilot, codex, agent_operating_guidelines, auto_orchestration, memory-seed, skills/checklists, DEVELOPER_GUIDE, HOW_IT_WORKS). Run `instruction-sync.sh` to detect drift.
- **Framework dev only — LLM test advisory.** When committing behavioral changes (ag commands, trigger words, agent workflows), check whether `tests/llm/` needs coverage. Unit tests can't catch behavioral gaps.
