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
- `ag contract check F-XXXX` | `ag contract coverage` | `ag contract pending` | `ag contract list` | `ag contract promote F-XXXX`
- `ag phase list F-XXXX` | `ag phase done F-XXXX <id>` | `ag phase active` | `ag phase sync`
- `ag auto task F-XXXX` | `ag auto epic F-XXXX` | `ag auto verify` | `ag auto crunch`
- `ag kickoff "vision"` | `ag kickoff --review` | `ag kickoff --approve`
- `ag persona list` | `ag persona check` | `ag persona coverage` | `ag persona generate` | `ag persona migrate`
- `ag coord start` | `ag coord stop` | `ag coord status`
- `ag mcp start` | `ag mcp status` — MCP coordination server (tool-native agent integration)

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
- User preferences/corrections/decisions: When the user expresses a preference, corrects your approach, or makes a decision, capture with `ag intel remember "what they said" --type preference|learning|decision --context "..."`. Recognize these semantically — don't wait for keywords. Stored in project-memory.yaml, NOT personal memory. For write-time enforcement: `ag intel learn "..." --reason "user instruction" --scope "*"`.
- Proposing a choice: before asking user to confirm, write: `echo "decision summary" > .agentic/session/pending-decision.txt`. The framework detects "yes/ok" and advises capture.
- Phase intelligence: before each workflow phase, run `ag intel architecture|spec|implement|test [F-XXXX]` for context-aware guidance (ADRs, patterns, quality checks). Skills reference these commands.
- Pending user input: "pending user input/contract input" → run `ag contract pending`. Process each pending contract.
- Migrate specs: "migrate specs/convert acceptance" → run `ag migrate-specs` (converts markdown ACs to YAML contracts).
- Never fabricate APIs, data, or behavior. If uncertain, ask.
- NEVER write code for multiple features outside of `ag auto` commands. If a user says "build everything", "churn all tasks", or similar batch-work phrases, use `ag auto crunch` — not direct Write/Edit calls. The `ag auto` pipeline ensures each feature gets specs, plans, tests, and docs. **Wrong rationalizations:** "I can implement it directly faster" — NO. "ag auto crunch spawns subprocesses, I have full context" — NO. "The user said autonomous = skip ceremony" — NO. Autonomous means use the autonomous pipeline, not bypass it.
- No feature inflation: improvements, enforcement, and hardening of existing features are deliverables on those features — not new F-XXXX. Ask "which existing feature owns this?" before proposing a new capability ID.
- Behavioral corrections belong in instruction files: When a correction applies to this project, update CLAUDE.md or the relevant skill file — don't write a memory as a substitute.

Token-efficient scripts (ALWAYS use these, NEVER edit state files directly):
- STATUS.md: `bash .agentic/lib/tools/status.sh focus "Task"`
- JOURNAL.md: `bash .agentic/lib/tools/journal.sh "Topic" "Outcomes with reasoning" "Next" "Blockers" --why "Problem" --decision "Choice made"`
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

Profiles are presets for settings — not separate products. OVERVIEW.md is the living design document — keep it current. When implementation changes something, read OVERVIEW.md and update any section that no longer reflects reality. Don't update mechanically — compare what you built against what the doc says and fix the delta.

Journal entries are the project's memory. Log with enough context to reconstruct why things are the way they are: what was discussed, what alternatives were considered, what assumptions were made — not just what changed. Use `--decision` flag when a specific choice was made. These entries are raw material for formal specs if the project later graduates to formal profile.

Decision routing:
- **Current state** → OVERVIEW.md sections (personas, capabilities, tech stack, phases, scope, principles)
- **Work log with reasoning** → JOURNAL.md (context, alternatives, assumptions in the outcome text)
- **Decision marker** → JOURNAL.md `--decision` flag (grep-able: `grep "Decision:" JOURNAL.md`)
- **Full ADR** → spec/adr/ (formal profile, architecturally significant only)
- **Ways of working** → STACK.md settings + CONTEXT_PACK.md conventions
- **User preferences** → project-memory.yaml via `ag intel remember` (you capture semantically, hooks may nudge)
- **User instructions** → project-memory.yaml (preference) or patterns.yaml (enforced) via `ag intel learn`

## Skills & Workflows

Workflow triggers are handled by Skills in `.claude/skills/`. Each skill has instructions, scripts, and references for its workflow.

Subagent context: `bash .agentic/lib/tools/context-for-role.sh <role> <feature-id>`. Subagents do NOT inherit CLAUDE.md.

Memory seed: At session start, check persistent memory for framework patterns. If stale, read `.agentic/lib/init/memory-seed.md` and write rules to memory.
