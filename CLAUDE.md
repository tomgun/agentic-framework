# Claude Instructions

THIS IS FRAMEWORK DEVELOPMENT. You are working ON the agentic framework itself, not a project using it. Framework changes affect ALL users - extra care required.

Read first: `FRAMEWORK_QUICK_START.md`, `FRAMEWORK_DEVELOPMENT.md`, `.agentic/lib/PRINCIPLES.md`
Architecture: `docs/INSTRUCTION_ARCHITECTURE.md` (three-layer design: Constitution → Playbooks → State)

## Session Start (do this FIRST on every new conversation)

Read .agentic/STATUS.md, .agentic/HUMAN_NEEDED.md, and last 2-3 entries of .agentic/journal/JOURNAL.md. Check `bash .agentic/lib/tools/wip.sh check` for interrupted work. Then greet the user with a dashboard: current focus, recent progress, blockers, and suggested next steps. Full protocol: `.agentic/lib/checklists/session_start.md`

Always consult: AGENTS.md (if present), `.agentic/lib/agents/shared/agent_operating_guidelines.md`, CONTEXT_PACK.md, .agentic/STATUS.md, .agentic/spec/* and .agentic/spec/adr/* as the source of truth.

Quick Commands: `ag start` | `ag sync` | `ag implement F-XXXX` | `ag work "desc"` | `ag commit` | `ag done`

## Core Rules

- Never auto-commit. Show changes to human first.
- PR by default: create feature branches and PRs (check `git_workflow` in STACK.md). After creating a PR, add entry to .agentic/HUMAN_NEEDED.md for review tracking.
- Add/update tests for new/changed logic.
- Code + docs = done (update docs with code, not later).
- Shipped specs are contracts: never modify shipped acceptance criteria without `bash .agentic/lib/tools/migration.sh create`. Pre-commit Checks 14-16 enforce this with no escape hatch.
- Keep changes small and scoped (max 5-10 files per commit).
- Plans are durable: save to `.agentic/journal/plans/F-XXXX-plan.md` after approval.
- Multi-agent: read `.agentic/session/AGENTS_ACTIVE.md` before starting work.
- Log user's design insights to .agentic/CONTRIBUTIONS.md. Every PR: bump VERSION (at least patch).
- Quick capture: "remember/todo/idea" → run `ag todo "description"` for persistent capture.

Token-efficient scripts (ALWAYS use these, NEVER edit state files directly):
- .agentic/STATUS.md: `bash .agentic/lib/tools/status.sh focus "Task"`
- .agentic/journal/JOURNAL.md: `bash .agentic/lib/tools/journal.sh "Topic" "Outcomes (not files)" "Next" "Blockers" --why "Problem being solved"`
- .agentic/HUMAN_NEEDED.md: `bash .agentic/lib/tools/blocker.sh add "Title" "type" "Details"`
- .agentic/spec/FEATURES.md: `bash .agentic/lib/tools/feature.sh F-#### status shipped`
- .agentic/TODO.md: `bash .agentic/lib/tools/todo.sh add "Idea"` or `ag todo "Idea"`

## Skills & Workflows

Workflow triggers are handled by Skills in `.claude/skills/`. Each skill has instructions, scripts, and references for its workflow. Key skills: `implementing-features`, `committing-changes`, `fixing-bugs`, `writing-specs`, `session-start`, `completing-work`, `planning-features`, `writing-tests`, `reviewing-code`, `updating-documentation`.

Subagent context: `bash .agentic/lib/tools/context-for-role.sh <role> <feature-id>`. Subagents do NOT inherit CLAUDE.md.

Memory seed: At session start, check persistent memory for framework patterns. If stale, read `.agentic/lib/init/memory-seed.md` and write rules to memory.

Workflows, delegation, gates, checklists: run `ag` commands or see `.agentic/lib/agents/shared/auto_orchestration.md`

---

## Framework Development

Validation: `bash tests/validate_framework.sh` must pass before committing.
Dogfooding: `.agentic/` is the source of truth - develop templates there first, root files extend.
New features: Add to `.agentic/spec/FEATURES.md` FIRST, create acceptance criteria before coding.
Breaking changes: Provide upgrade path in `upgrade.sh`.
Test in scratch project before committing framework changes.
Worktree: Use `git worktree` on feature branches when another agent may be working on main.
