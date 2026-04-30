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
- `ag commit` | `ag commit --skip-gate "<reason>"` (audited Tier 0 bypass) | `ag done` | `ag merge <pr#> [F-XXXX]` (PR via gh) | `ag merge <branch> [--skip-gate "<reason>"]` (local merge gate; R-003) | `ag flush` | `ag backlog` | `ag todo`
- `ag push [args...]` | `ag push --skip-gate "<reason>"` — sanctioned wrapper that drops a breadcrumb so the pre-push gate (R-002) records intent
- `ag fix "<reason>"` — hotfix-mode commit (R-010): skips spec-existence + plan-approval, keeps tests/journal/migrations/integrity; emits `hotfix_commit` event; `[hotfix]` footer
- `ag tui` — Textual mission-control dashboard live-tailing events.jsonl / delegation.jsonl / token-ledger.jsonl (R-008). Requires `pip install textual`.
- `ag watch [--filter k=v] [--since 1h] [--from-start] [--once]` — color-coded stream of events.jsonl for SSH (R-009); stdlib only
- `ag intel report --quota` — Pro/Max session quota usage in last 5h window: per-tier/per-model breakdown, threshold alerts at 70/85/95%, projected exhaustion (R-013)
- `ag intel report --tokens` — current-session + rolling-30-session token usage from token-ledger.jsonl: per-tier/per-model/per-feature breakdown (R-101). Use this to spot which features are burning the most tokens session over session.
- `ag onboard` — generate `.agentic/ONBOARDING.md` for new contributors from STACK/FEATURES/STATUS/journal/ADR (R-011)
- `ag skills suggest|install|sync|list|remove|update-pins|request` — F-008 marketplace integration: install community quality skills from a curated allowlist with mandatory sha pinning, script quarantine, and Claude+Cursor fan-out
- `ag contract check F-XXXX` | `ag contract coverage` | `ag contract pending` | `ag contract list` | `ag contract promote F-XXXX` | `ag contract migrate F-XXXX --reason "..." [--set K=V | --add-assertion "..."]` (sanctioned mutation path for shipped/read-only contracts; R-005)
- `ag integrity status` | `ag integrity update` — hook + agent + .claude config baseline (R-004); pre-commit verifies before any other check
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

- Interactive sessions: show changes to human before committing. Autonomous/non-interactive sessions: commit directly, using `review_commit` setting. After every commit or push, state explicitly: the short commit hash, the branch, and a one-line summary of what was included (e.g., "`a1b2c3d` on `main` — fix plan-scan dedup + todo.sh entry loss").
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
- **Don't autorecord project things to Claude auto-memory** (`~/.claude/projects/.../memory/`). That system is reserved for cross-project / per-user / per-machine context the user manages directly. Anything project-relevant — corrections, decisions, behavior rules, conventions, journal-entry shape — belongs in repo files (CLAUDE.md, the relevant skill in `.claude/skills/`, JOURNAL.md, ADRs), where every contributor and every machine sees it. Auto-memory is gitignored, single-machine, invisible to other contributors. The user manages auto-memory directly when they want something there.

Token-efficient scripts (ALWAYS use these, NEVER edit state files directly):
- STATUS.md: `bash .agentic/lib/tools/status.sh focus "Task"`
- JOURNAL.md: `bash .agentic/lib/tools/journal.sh "Topic" "Outcomes with reasoning" "Next" "Blockers" --why "Problem" --decision "Choice made"`
- HUMAN_NEEDED.md: `bash .agentic/lib/tools/blocker.sh add "Title" "type" "Details"`
- FEATURES.md: `bash .agentic/lib/tools/feature.sh cap add "Name" "Description"` or `feature.sh cap status "Name" built`
- TODO.md: `bash .agentic/lib/tools/todo.sh add "Idea"` or `ag todo "Idea"`

## Enforcement Hierarchy

Framework enforcement uses multiple layers. When adding new gates or enforcement, prefer higher layers:
1. **Tier 0 git-layer gates** (v5; `precommit_gate.py` / `prepush_gate.py`) — fire in a separate process from any agent session. Pre-commit blocks per-commit (tests, contracts, plan-approved sentinel, JOURNAL freshness, shipped-contract migrations). Pre-push blocks range-shaped (full integration tests, coverage threshold, doc drift, range migrations). Sanctioned bypass: `ag commit --skip-gate "<reason>"` / `ag push --skip-gate "<reason>"` — both audited to events.jsonl. *Honest limit:* pre-commit cannot itself observe `git commit --no-verify` (the flag short-circuits hooks); pre-push catches the same range on push regardless.
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
- **User preferences** → project-memory.yaml via `ag intel remember` (you capture semantically, hooks may nudge)
- **User instructions** → project-memory.yaml (preference) or patterns.yaml (enforced) via `ag intel learn`

## Skills & Workflows

Workflow triggers are handled by Skills in `.claude/skills/`. Each skill has instructions, scripts, and references for its workflow.

Subagent context: `bash .agentic/lib/tools/context-for-role.sh <role> <feature-id>`. Subagents do NOT inherit CLAUDE.md.

Memory seed: At session start, check persistent memory for framework patterns. If stale, read `.agentic/lib/init/memory-seed.md` and write rules to memory.
