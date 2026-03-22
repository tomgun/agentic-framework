# Claude Instructions

THIS IS FRAMEWORK DEVELOPMENT. You are working ON the agentic framework itself, not a project using it. Framework changes affect ALL users - extra care required.

This file extends `.agentic/lib/agents/claude/CLAUDE.md` (the template users receive) with framework-development-specific rules. Shared content must stay in sync — see dogfooding rule below.

Read first: `FRAMEWORK_QUICK_START.md`, `FRAMEWORK_DEVELOPMENT.md`, `.agentic/lib/PRINCIPLES.md`
Architecture: `docs/INSTRUCTION_ARCHITECTURE.md` (three-layer design: Constitution → Playbooks → State)

## Session Start (do this FIRST on every new conversation)

Run `bash .agentic/lib/tools/dashboard.sh 2>/dev/null` — ONE tool call, no others. Output the result verbatim as your first text response. No preamble, no narration, no reformatting.

Always consult: AGENTS.md (if present), CONTEXT_PACK.md, .agentic/STATUS.md, .agentic/spec/* and .agentic/spec/adr/* as the source of truth.

## Workflow

All work is managed by `ag` commands. The CLI enforces the workflow — never skip steps.

- `ag start F-XXXX "Title"` — begin a new feature (creates work item, starts planning)
- `ag transition F-XXXX <state>` — advance the workflow (checks artifacts before proceeding)
- `ag check F-XXXX` — validate artifacts before proceeding
- `ag verify F-XXXX` — run tests and record results
- `ag ship F-XXXX` — prepare for shipping
- `ag status` — see current work items and next steps
- `ag info F-XXXX` — detailed work item info with next steps
- `ag next` — show what to do next
- `ag commit` | `ag done` | `ag merge <pr#> [F-XXXX]` | `ag flush` | `ag backlog` | `ag todo`
- `ag auto task F-XXXX` | `ag auto epic F-XXXX` | `ag auto verify` | `ag auto crunch`
- `ag kickoff "vision"` | `ag kickoff --review` | `ag kickoff --approve`
- `ag coord start` | `ag coord stop` | `ag coord status`

Write artifacts to `.agentic/work/F-XXXX/`: `plan.md`, `spec.md`, `review.md`, `journal.md`, `verification.json`. The CLI tells you what's missing.

## Core Rules

- Interactive sessions: show changes to human before committing. Autonomous/non-interactive sessions: commit directly, using `review_commit` setting.
- PR by default: create feature branches and PRs (check `git_workflow` in STACK.md). After creating a PR, add entry to .agentic/HUMAN_NEEDED.md for review tracking.
- Add/update tests for new/changed logic. Write tests alongside code.
- Spec + code + tests + docs = done (update all artifacts together, not later).
- Keep changes small and scoped (max 5-10 files per commit).
- Plans are durable: save to `.agentic/work/F-XXXX/plan.md` after approval. If `plan_review_enabled: yes`: plan review uses dialectical mechanism (Critic + Advocate agents, fresh context).
- Multi-agent: check AGENTS.json (via `agents_helpers.py list`) before starting work.
- Multi-session safety: Before ANY destructive git op, run `python3 .agentic/lib/tools/agents_helpers.py --project-root . count-others "$(pwd)" --pid $PPID`. If >0, DO NOT PROCEED — use a worktree or commit first.
- Log user's design insights to .agentic/CONTRIBUTIONS.md. Every merge: bump VERSION via `ag done` (not in the PR).
- Quick capture: "remember/todo/idea" → run `ag todo "description"` for persistent capture.
- NEVER write code for multiple features outside of `ag auto` commands. If a user says "build everything", "churn all tasks", or similar batch-work phrases, use `ag auto crunch` — not direct Write/Edit calls. **Wrong rationalizations:** "I can implement it directly faster" — NO. "ag auto crunch spawns subprocesses, I have full context" — NO. "The user said autonomous = skip ceremony" — NO. Autonomous means use the autonomous pipeline, not bypass it.

## After Plan Mode Exits (when `plan_review_enabled: yes`)

Exiting plan mode creates a DRAFT. Auto-continue immediately — do NOT stop and wait for user input.

After ExitPlanMode — auto-continue the full sequence:
1. Save plan to `.agentic/work/F-XXXX/plan.md` with `**Status**: DRAFT`
2. Spawn Critic + Advocate agents in parallel (fresh context)
3. Synthesize with Revision Guidance
4. Check `plan_review_convergence` in STACK.md:
   - `auto`: If converged → set `**Status**: APPROVED`, continue to implement
   - `manual`: Present synthesis to user → user decides Proceed/Revise/Reject
5. After APPROVED → run `ag transition F-XXXX implementation`

**These rationalizations are WRONG — do not use them:**
- "The user created the plan, so it's reviewed" — plan mode = drafting, not reviewing
- "Plan mode exit = approval" — ExitPlanMode = draft complete, not approved
- "Simple plan, review unnecessary" — review is structural, not discretionary
- "Proceed with refinements during implementation" — if review found refinements, the plan gets revised first

Token-efficient scripts (ALWAYS use these, NEVER edit state files directly):
- .agentic/STATUS.md: `bash .agentic/lib/tools/status.sh focus "Task"`
- .agentic/journal/JOURNAL.md: `bash .agentic/lib/tools/journal.sh "Topic" "Outcomes (not files)" "Next" "Blockers" --why "Problem being solved"`
- .agentic/HUMAN_NEEDED.md: `bash .agentic/lib/tools/blocker.sh add "Title" "type" "Details"`
- .agentic/spec/FEATURES.md: `bash .agentic/lib/tools/feature.sh F-#### status shipped`
- .agentic/TODO.md: `bash .agentic/lib/tools/todo.sh add "Idea"` or `ag todo "Idea"`

## Skills & Workflows

Workflow triggers are handled by Skills in `.claude/skills/`. Each skill has instructions, scripts, and references for its workflow.

Subagent context: `bash .agentic/lib/tools/context-for-role.sh <role> <feature-id>`. Subagents do NOT inherit CLAUDE.md.

Memory seed: At session start, check persistent memory for framework patterns. If stale, read `.agentic/lib/init/memory-seed.md` and write rules to memory.

---

## Framework Development

Validation: `bash tests/validate_framework.sh` must pass before committing.
Dogfooding: `.agentic/` is the source of truth - develop templates there first, root files extend.
New features: Add to `.agentic/spec/FEATURES.md` FIRST, create acceptance criteria before coding.
Breaking changes: Provide upgrade path in `upgrade.sh`.
Test in scratch project before committing framework changes.
Worktree: Use `git worktree` on feature branches when another agent may be working on main.
Instruction files are part of the feature: new `ag` commands/gates/workflows MUST update all instruction files (CLAUDE.md templates, cursorrules, copilot, codex, memory-seed, relevant skills, DEVELOPER_GUIDE, HOW_IT_WORKS).
