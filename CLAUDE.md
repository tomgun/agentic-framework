# Claude Instructions

THIS IS FRAMEWORK DEVELOPMENT. You are working ON the agentic framework itself, not a project using it. Framework changes affect ALL users - extra care required.

This file extends `.agentic/lib/agents/claude/CLAUDE.md` (the template users receive) with framework-development-specific rules. Shared content must stay in sync — see dogfooding rule below.

Read first: `FRAMEWORK_QUICK_START.md`, `FRAMEWORK_DEVELOPMENT.md`, `.agentic/lib/PRINCIPLES.md`
Architecture: `docs/INSTRUCTION_ARCHITECTURE.md` (three-layer design: Constitution → Playbooks → State)

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
- `ag commit` | `ag commit --skip-gate "<reason>"` (audited Tier 0 bypass) | `ag done` | `ag merge <pr#> [F-XXXX]` | `ag flush` | `ag backlog` | `ag todo`
- `ag push [args...]` | `ag push --skip-gate "<reason>"` — sanctioned wrapper (R-002) so the pre-push gate records intent
- `ag tui` — Textual mission-control dashboard (R-008) live-tailing JSONL streams; needs `pip install textual`
- `ag contract check F-XXXX` | `ag contract coverage` | `ag contract pending` | `ag contract list` | `ag contract promote F-XXXX` | `ag contract migrate F-XXXX --reason "..." [--set K=V | --add-assertion "..."]` (sanctioned mutation path for shipped/read-only contracts; R-005)
- `ag integrity status` | `ag integrity update` — hook + agent + .claude config baseline (R-004); pre-commit verifies before any other check
- `ag phase list F-XXXX` | `ag phase done F-XXXX <id>` | `ag phase active` | `ag phase sync`
- `ag auto task F-XXXX` | `ag auto epic F-XXXX` | `ag auto verify` | `ag auto crunch`
- `ag kickoff "vision"` | `ag kickoff --review` | `ag kickoff --approve`
- `ag persona list` | `ag persona check` | `ag persona coverage` | `ag persona generate` | `ag persona migrate`
- `ag coord start` | `ag coord stop` | `ag coord status`
- `ag mcp start` | `ag mcp status` — MCP coordination server (tool-native agent integration)

Write artifacts to `.agentic/work/F-XXXX/`: `plan.md`, `spec.md`, `review.md`, `journal.md`, `verification.json`. The CLI tells you what's missing.

## Core Rules

- Interactive sessions: show changes to human before committing. Autonomous/non-interactive sessions: commit directly, using `review_commit` setting. After every commit or push, state explicitly: the short commit hash, the branch, and a one-line summary of what was included (e.g., "`a1b2c3d` on `main` — fix plan-scan dedup + todo.sh entry loss").
- PR by default: create feature branches and PRs (check `git_workflow` in STACK.md). If `git_mode` is `deferred` or `none`, skip git operations — suggest `ag git-init` when the user wants to commit. After creating a PR, add entry to .agentic/HUMAN_NEEDED.md for review tracking.
- Add/update tests for new/changed logic. Write tests alongside code, not after.
- Spec + code + tests + docs = done (update all artifacts together, not later).
- Keep changes small and scoped (max 5-10 files per commit).
- Plans are durable: save to `.agentic/journal/plans/YYYY-MM-DD-F-XXXX-plan.md` after approval. If `plan_review_enabled: yes`: plan review uses dialectical mechanism (Critic + Advocate agents, fresh context).
- Multi-agent: check AGENTS.json (via `agents_helpers.py list`) before starting work.
- Multi-session safety: Before ANY destructive git op, run `python3 .agentic/lib/tools/agents_helpers.py --project-root . count-others "$(pwd)" --pid $PPID`. If >0, DO NOT PROCEED — use a worktree or commit first.
- Log user's design insights to .agentic/CONTRIBUTIONS.md. Every merge: bump VERSION via `ag done` (not in the PR).
- Quick capture: "remember/todo/idea" → run `ag todo "description"` for persistent capture.
- Pending user input: "pending user input/contract input" → run `ag contract pending`. Process each pending contract.
- Migrate specs: "migrate specs/convert acceptance" → run `ag migrate-specs` (converts markdown ACs to YAML contracts).
- Never fabricate APIs, data, or behavior. If uncertain, ask.
- NEVER write code for multiple features outside of `ag auto` commands. If a user says "build everything", "churn all tasks", or similar batch-work phrases, use `ag auto crunch` — not direct Write/Edit calls. The `ag auto` pipeline ensures each feature gets specs, plans, tests, and docs. **Wrong rationalizations:** "I can implement it directly faster" — NO. "ag auto crunch spawns subprocesses, I have full context" — NO. "The user said autonomous = skip ceremony" — NO. Autonomous means use the autonomous pipeline, not bypass it.
- No feature inflation: improvements, enforcement, and hardening of existing features are deliverables on those features — not new F-XXXX. Ask "which existing feature owns this?" before proposing a new capability ID.
- Behavioral corrections belong in instruction files: When a correction applies to this project, update CLAUDE.md or the relevant skill file — don't write a memory as a substitute.

## After Plan Mode Exits (when `plan_review_enabled: yes`)

Exiting plan mode creates a DRAFT. Auto-continue immediately — do NOT stop and wait for user input.

After ExitPlanMode — auto-continue the full sequence:
1. Save plan to `.agentic/journal/plans/YYYY-MM-DD-F-XXXX-plan.md` with `**Status**: DRAFT`
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
- .agentic/journal/JOURNAL.md: `bash .agentic/lib/tools/journal.sh "Topic" "Outcomes with reasoning" "Next" "Blockers" --why "Problem" --decision "Choice made"`
- .agentic/HUMAN_NEEDED.md: `bash .agentic/lib/tools/blocker.sh add "Title" "type" "Details"`
- .agentic/spec/FEATURES.md: `bash .agentic/lib/tools/feature.sh cap add "Name" "Description"` or `feature.sh cap status "Name" built`
- .agentic/TODO.md: `bash .agentic/lib/tools/todo.sh add "Idea"` or `ag todo "Idea"`

## Enforcement Hierarchy

Framework enforcement uses multiple layers. When adding new gates or enforcement, prefer higher layers:
1. **Tier 0 git-layer gates** (v5; `precommit_gate.py` / `prepush_gate.py`) — fire in a separate process from any agent session. Pre-commit blocks per-commit shape (tests, contracts, plan-approved sentinel, JOURNAL freshness, shipped-contract migrations). Pre-push blocks range shape (full integration tests, coverage threshold, doc drift, range migrations). Sanctioned bypass: `ag commit --skip-gate "<reason>"` / `ag push --skip-gate "<reason>"` — both audited to events.jsonl. *Honest limit:* pre-commit cannot itself observe `git commit --no-verify` (the flag short-circuits hooks); pre-push catches the same range on push regardless.
2. **Filesystem read-only protection** (R-005; shipped contracts only) — `ag contract promote` chmods `lifecycle: shipped` contracts to `444`, so direct `Edit`/`Write`/`$EDITOR` writes fail with EACCES. The sanctioned mutation path is `ag contract migrate F-XXX --reason "<text>" [--set K=V | --add-assertion "<text>"]`, which records an auditable migration entry, applies the change, and re-locks the file. *Honest limit:* a deliberate `chmod u+w` bypasses this layer; the Tier 0 pre-commit gate's shipped-contract-migration check is the second wall.
3. **Hook integrity baseline** (R-004) — `.agentic/integrity.json` carries SHA-256 hashes of `.git/hooks/pre-{commit,push}`, `.agentic/lib/hooks/*.py`, `.agentic/lib/integrity.py`, `.claude/hooks.json`, `.claude/settings.json[hooks]`, and `.claude/agents/*.md`. Pre-commit verifies the baseline first (before any other check), so an agent that tampered with a later check still trips this one. `ag integrity update` regenerates the baseline (audited via events.jsonl `integrity_baseline_updated`); `INTEGRITY_SKIP=1` is honored only under `CI=true`. *Honest limit:* a determined human can `ag integrity update` to launder a tamper; HMAC signing (R-209) closes that path.
4. **Claude hooks** (real-time, during session) — PreToolUse blocks/warns before action, PostToolUse tracks after, Stop.sh validates at session end, UserPromptSubmit nudges per-prompt. In-session enforcement layer.
5. **Skills** (just-in-time guidance) — loaded at workflow trigger points via `.claude/skills/`
6. **`ag` commands** (workflow gates) — `ag done`, `ag implement`, `ag commit` validate preconditions
7. **Pre-commit hooks (legacy bash)** — `pre-commit-check.sh` 16-check defense-in-depth; will be retired in R-301
8. **Instruction files** (behavioral) — guide agent behavior but no structural enforcement

## Design Tracking

Profiles are presets for settings — not separate products. OVERVIEW.md is the living design document — keep it current. When implementation changes something, read OVERVIEW.md and update any section that no longer reflects reality. Don't update mechanically — compare what you built against what the doc says and fix the delta.

Journal entries are the project's memory. Log with enough context to reconstruct why things are the way they are: what was discussed, what alternatives were considered, what assumptions were made — not just what changed. Use `--decision` flag when a specific choice was made. These entries are raw material for formal specs if the project later graduates to formal profile.

Decision routing:
- **Current state** → OVERVIEW.md sections (personas, capabilities, tech stack, phases, scope, principles)
- **Work log with reasoning** → JOURNAL.md (context, alternatives, assumptions in the outcome text)
- **Decision marker** → JOURNAL.md `--decision` flag (grep-able: `grep "Decision:" JOURNAL.md`)
- **Full ADR** → spec/adr/ (formal profile, architecturally significant only)
- **Ways of working** → STACK.md settings + CONTEXT_PACK.md conventions
- **User preferences** → project-memory.yaml via `ag intel remember`

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
Behavioral corrections go in instruction files: When a correction applies to this project, update the CLAUDE.md template (`.agentic/lib/agents/claude/CLAUDE.md`) or the relevant skill file — don't write a memory as a substitute.
