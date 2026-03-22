# Project Instructions

You are working in a repo that uses the agentic development framework (folder: .agentic/).

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

Write artifacts to `.agentic/work/F-XXXX/`: `plan.md`, `spec.md`, `review.md`, `journal.md`, `verification.json`. The CLI tells you what's missing — if a transition is blocked, it shows exactly which artifacts to create.

## After Plan Mode Exits (when `plan_review_enabled: yes`)

Exiting plan mode creates a DRAFT. Auto-continue immediately — do NOT stop and wait for user input.
1. Save plan to `.agentic/work/F-XXXX/plan.md` with `**Status**: DRAFT`
2. Spawn Critic + Advocate agents in parallel (fresh context)
3. Synthesize with Revision Guidance
4. Check `plan_review_convergence` in STACK.md: `auto` → approve on convergence; `manual` → present to user
5. After APPROVED → run `ag transition F-XXXX implementation`

**Wrong rationalizations:** "User created the plan so it's reviewed" — NO. "Plan mode exit = approval" — NO. "Simple plan, review unnecessary" — NO. Review is structural, not discretionary.

## Core Rules

- Never auto-commit in interactive sessions. Show changes to human first.
- PR by default: create feature branches and PRs (check `git_workflow` in STACK.md). If `git_mode` is `deferred` or `none`, skip git operations — suggest `ag git-init` when the user wants to commit.
- Add/update tests for new/changed logic. Write tests alongside code, not after.
- Spec + code + tests + docs = done (update all artifacts together, not later).
- Keep changes small and scoped (max 5-10 files per commit).
- Multi-session safety: Before ANY destructive git op, check for other active sessions via `agents_helpers.py count-others`. If >0, use a worktree or commit first.
- Quick capture: "remember/todo/idea" → run `ag todo "description"` for persistent capture.
- Never fabricate APIs, data, or behavior. If uncertain, ask.
- NEVER write code for multiple features outside of `ag auto` commands. If a user says "build everything", "churn all tasks", or similar batch-work phrases, use `ag auto crunch` — not direct Write/Edit calls. The `ag auto` pipeline ensures each feature gets specs, plans, tests, and docs.

Token-efficient scripts (ALWAYS use these, NEVER edit state files directly):
- STATUS.md: `bash .agentic/lib/tools/status.sh focus "Task"`
- JOURNAL.md: `bash .agentic/lib/tools/journal.sh "Topic" "Outcomes" "Next" "Blockers" --why "Problem"`
- HUMAN_NEEDED.md: `bash .agentic/lib/tools/blocker.sh add "Title" "type" "Details"`
- FEATURES.md: `bash .agentic/lib/tools/feature.sh F-#### status shipped`
- TODO.md: `bash .agentic/lib/tools/todo.sh add "Idea"` or `ag todo "Idea"`
