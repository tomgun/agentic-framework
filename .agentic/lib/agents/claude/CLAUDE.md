# Project Instructions

You are working in a repo that uses the agentic development framework (folder: .agentic/).

## Session Start (do this FIRST on every new conversation)

Run `bash .agentic/lib/tools/dashboard.sh 2>/dev/null` — ONE tool call, no others. Output the result verbatim as your first text response. No preamble, no narration, no reformatting.

Dashboard shows `🚨 FRAMEWORK DISCONNECTED` → offer to run the `FIX` commands shown. Do this BEFORE any other work. Without hooks: no quality gates, no intelligence injection, no workflow automation. After fixing, advise the user to restart Claude Code — hooks only load at session start.

Always consult: AGENTS.md (if present), CONTEXT_PACK.md, .agentic/STATUS.md, .agentic/spec/* and .agentic/spec/adr/* as the source of truth.

## Workflow

All work is managed by `ag` commands. The CLI enforces the workflow — never skip steps.

- `ag start F-XXXX "Title"` — begin a new feature (creates work item, starts planning)
- `ag transition F-XXXX <state>` — advance the workflow (checks artifacts before proceeding)
- `ag check F-XXXX` — validate artifacts before proceeding
- `ag verify F-XXXX` — run tests and record results
- `ag done F-XXXX` — post-merge: doc gate, VERSION bump, state flush
- `ag status` — see current work items and next steps
- `ag info F-XXXX` — detailed work item info with next steps
- `ag next` — show what to do next
- `ag commit` | `ag done` | `ag merge <pr#> [F-XXXX]` | `ag flush` | `ag backlog` | `ag todo`
- `ag contract check F-XXXX` | `ag contract coverage` | `ag contract pending` | `ag contract list`
- `ag phase list F-XXXX` | `ag phase done F-XXXX <id>` | `ag phase active` | `ag phase sync`
- `ag auto task F-XXXX` | `ag auto epic F-XXXX` | `ag auto verify` | `ag auto crunch`
- `ag kickoff "vision"` | `ag kickoff --review` | `ag kickoff --approve`
- `ag coord start` | `ag coord stop` | `ag coord status`

Write artifacts to `.agentic/work/F-XXXX/`: `plan.md`, `spec.md`, `review.md`, `journal.md`, `verification.json`. The CLI tells you what's missing — if a transition is blocked, it shows exactly which artifacts to create.

## After Plan Mode Exits (when `plan_review_enabled: yes`)

Exiting plan mode creates a DRAFT. Auto-continue immediately — do NOT stop and wait for user input.
1. Save plan to `.agentic/journal/plans/YYYY-MM-DD-F-XXXX-plan.md` with `**Status**: DRAFT`
2. Spawn Critic + Advocate agents in parallel (fresh context)
3. Synthesize with Revision Guidance
4. Check `plan_review_convergence` in STACK.md: `auto` → approve on convergence; `manual` → present to user
5. After APPROVED → run `ag transition F-XXXX implementation`

**Wrong rationalizations:** "User created the plan so it's reviewed" — NO. "Plan mode exit = approval" — NO. "Simple plan, review unnecessary" — NO. "Proceed with refinements during implementation" — NO. Review is structural, not discretionary.

## Core Rules

- Interactive sessions: show changes to human before committing. Autonomous/non-interactive sessions: commit directly, using `review_commit` setting.
- PR by default: create feature branches and PRs (check `git_workflow` in STACK.md). If `git_mode` is `deferred` or `none`, skip git operations — suggest `ag git-init` when the user wants to commit. After creating a PR, add entry to .agentic/HUMAN_NEEDED.md for review tracking. If `main_branch_mode: protected`, `ag flush` creates a branch + PR instead of pushing directly to main.
- Add/update tests for new/changed logic. Write tests alongside code, not after.
- Spec + code + tests + docs = done (update all artifacts together, not later).
- Keep changes small and scoped (max 5-10 files per commit).
- Multi-session safety: Before ANY destructive git op, check for other active sessions via `agents_helpers.py count-others`. If >0, use a worktree or commit first.
- Plans are durable: save to `.agentic/journal/plans/YYYY-MM-DD-F-XXXX-plan.md` after approval. If `plan_review_enabled: yes`: plan review uses dialectical mechanism (Critic + Advocate agents, fresh context).
- Multi-agent: check AGENTS.json (via `agents_helpers.py list`) before starting work.
- Quick capture: "remember/todo/idea" → run `ag todo "description"` for persistent capture.
- User correction: "no/don't/stop/always/never/I prefer" → capture with `ag intel remember "what they said" --context "what you were doing"`. Preferences, learnings, and decisions are project-scoped (cerebrum.yaml), not personal memory.
- Phase intelligence: before each workflow phase, run `ag intel architecture|spec|implement|test [F-XXXX]` for context-aware guidance (ADRs, patterns, quality checks). Skills reference these commands.
- Pending user input: "pending user input/contract input" → run `ag contract pending`. Process each pending contract.
- Migrate specs: "migrate specs/convert acceptance" → run `ag migrate-specs` (converts markdown ACs to YAML contracts).
- Never fabricate APIs, data, or behavior. If uncertain, ask.
- NEVER write code for multiple features outside of `ag auto` commands. If a user says "build everything", "churn all tasks", or similar batch-work phrases, use `ag auto crunch` — not direct Write/Edit calls. The `ag auto` pipeline ensures each feature gets specs, plans, tests, and docs. **Wrong rationalizations:** "I can implement it directly faster" — NO. "ag auto crunch spawns subprocesses, I have full context" — NO. "The user said autonomous = skip ceremony" — NO. Autonomous means use the autonomous pipeline, not bypass it.
- No feature inflation: improvements, enforcement, and hardening of existing features are deliverables on those features — not new F-XXXX. Ask "which existing feature owns this?" before proposing a new capability ID.
- Behavioral corrections belong in instruction files: When a correction applies to this project, update CLAUDE.md or the relevant skill file — don't write a memory as a substitute.

Token-efficient scripts (ALWAYS use these, NEVER edit state files directly):
- STATUS.md: `bash .agentic/lib/tools/status.sh focus "Task"`
- JOURNAL.md: `bash .agentic/lib/tools/journal.sh "Topic" "Outcomes" "Next" "Blockers" --why "Problem"`
- HUMAN_NEEDED.md: `bash .agentic/lib/tools/blocker.sh add "Title" "type" "Details"`
- FEATURES.md: `bash .agentic/lib/tools/feature.sh cap add "Name" "Description"` or `feature.sh cap status "Name" built`
- TODO.md: `bash .agentic/lib/tools/todo.sh add "Idea"` or `ag todo "Idea"`

## Enforcement Hierarchy

Framework enforcement uses multiple layers. When adding new gates or enforcement, prefer higher layers:
1. **Claude hooks** (real-time, during session) — PreToolUse blocks/warns before action, PostToolUse tracks after, Stop.sh validates at session end, UserPromptSubmit nudges per-prompt. Primary enforcement layer.
2. **Skills** (just-in-time guidance) — loaded at workflow trigger points via `.claude/skills/`
3. **`ag` commands** (workflow gates) — `ag done`, `ag implement`, `ag commit` validate preconditions
4. **Pre-commit hooks** (git-level safety net) — for non-Claude tools and defense-in-depth only
5. **Instruction files** (behavioral) — guide agent behavior but no structural enforcement

## Design Tracking

Profiles are presets for settings — not separate products. Even without formal feature tracking, keep OVERVIEW.md current (Core Capabilities, Guiding Principles). Journal entries should use `--why` to capture decision motivation. These artifacts are raw material for formal specs if the project later enables `feature_tracking: yes` — OVERVIEW.md capabilities become FEATURES.md entries, journal decisions become ADRs, cerebrum learnings become enforced patterns.

## Skills & Workflows

Workflow triggers are handled by Skills in `.claude/skills/`. Each skill has instructions, scripts, and references for its workflow.

Subagent context: `bash .agentic/lib/tools/context-for-role.sh <role> <feature-id>`. Subagents do NOT inherit CLAUDE.md.

Memory seed: At session start, check persistent memory for framework patterns. If stale, read `.agentic/lib/init/memory-seed.md` and write rules to memory.
