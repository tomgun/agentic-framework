# Claude Instructions

You are working in a repo that uses the agentic development framework (folder: .agentic/).

## Session Start (do this FIRST on every new conversation)

Read STATUS.md, HUMAN_NEEDED.md, and last 2-3 entries of .agentic-journal/JOURNAL.md. Check `bash .agentic/tools/wip.sh check` for interrupted work. Then greet the user with a dashboard: current focus, recent progress, blockers, and suggested next steps. Full protocol: `.agentic/checklists/session_start.md`

Always consult: AGENTS.md (if present), `.agentic/agents/shared/agent_operating_guidelines.md`, CONTEXT_PACK.md, STATUS.md, spec/* and spec/adr/* as the source of truth.

Quick Commands: `ag start` | `ag sync` | `ag implement F-XXXX` | `ag work "desc"` | `ag commit` | `ag done`

## Core Rules

- Never auto-commit. Show changes to human first.
- PR by default: create feature branches and PRs (check `git_workflow` in STACK.md).
- Add/update tests for new/changed logic.
- Code + docs = done (update docs with code, not later).
- Keep changes small and scoped (max 5-10 files per commit).
- Plans are durable: save to `.agentic-journal/plans/F-XXXX-plan.md` after approval.
- Multi-agent: read `.agentic-state/AGENTS_ACTIVE.md` before starting work.
- Quick capture: "remember/todo/idea" → run `ag todo "description"` for persistent capture.

## Token-Efficient Scripts (ALWAYS use these, NEVER edit state files directly)

- STATUS.md: `bash .agentic/tools/status.sh focus "Task"`
- JOURNAL.md: `bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers" --why "Reason"`
- HUMAN_NEEDED.md: `bash .agentic/tools/blocker.sh add "Title" "type" "Details"`
- FEATURES.md: `bash .agentic/tools/feature.sh F-#### status shipped`
- TODO.md: `bash .agentic/tools/todo.sh add "Idea"` or `ag todo "Idea"`

## Skills & Workflows

Workflow triggers are handled by Skills in `.claude/skills/`. Each skill has instructions, scripts, and references for its workflow. Key skills: `implementing-features`, `committing-changes`, `fixing-bugs`, `writing-specs`, `session-start`, `completing-work`, `planning-features`, `writing-tests`, `reviewing-code`, `updating-documentation`.

Subagent context: `bash .agentic/tools/context-for-role.sh <role> <feature-id>`. Subagents do NOT inherit CLAUDE.md.

Memory seed: At session start, check persistent memory for framework patterns. If stale, read `.agentic/init/memory-seed.md` and write rules to memory.

Workflows, delegation, gates, checklists: run `ag` commands or see `.agentic/agents/shared/auto_orchestration.md`
