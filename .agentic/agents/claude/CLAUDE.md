# Claude Instructions

You are working in a repo that uses the agentic development framework (folder: .agentic/).

## Session Start (do this FIRST on every new conversation)

Read STATUS.md, HUMAN_NEEDED.md, and last 2-3 entries of .agentic-journal/JOURNAL.md. Check `bash .agentic/tools/wip.sh check` for interrupted work. Then greet the user with a dashboard: current focus, recent progress, blockers, and suggested next steps. Full protocol: `.agentic/checklists/session_start.md`

Always consult: AGENTS.md (if present), `.agentic/agents/shared/agent_operating_guidelines.md`, CONTEXT_PACK.md, STATUS.md, spec/* and spec/adr/* as the source of truth.

Quick Commands: `ag start` | `ag implement F-XXXX` | `ag work "desc"` | `ag commit` | `ag done`

STOP! Trigger Words:
| Trigger | Action |
|---------|--------|
| "build", "implement", "add", "create" | STOP -> Run `ag plan F-XXXX` first, then `ag implement` |
| "implement entire", "full system" | STOP -> TOO BIG. Break into 3-5 smaller tasks. Max 5-10 files. |
| "fix", "bug", "issue" | STOP -> Write failing test FIRST |
| "commit", "push" | STOP -> Check .agentic-state/WIP.md first; if exists BLOCK and warn. Else run `ag commit` |
| "done", "complete" | STOP -> Run `ag done F-XXXX` |

Acceptance criteria: Core+PM requires spec/acceptance/F-####.md before coding | Core: define criteria (any form) before coding.

Small batch development: When user asks for something large ("entire", "full", "complete system"), STOP - TOO BIG for one task. Break into smaller pieces (3-5 files max each). Max 5-10 files per commit.

Rules:
- **PR by default**: Create feature branches and PRs (check `git_workflow` in STACK.md). After creating a PR, add entry to HUMAN_NEEDED.md for review tracking.
- Never auto-commit. Show changes to human first.
- Add/update tests for new/changed logic.
- Code + docs = done (update docs with code, not later).
- Keep changes small and scoped.
- Update JOURNAL.md and STATUS.md before every commit (use token-efficient scripts).
- Multi-agent: read `.agentic-state/AGENTS_ACTIVE.md` before starting work.

Token-efficient scripts (ALWAYS use these, NEVER read/edit these files directly):
- STATUS.md: `bash .agentic/tools/status.sh focus "Task"`
- JOURNAL.md: `bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers"`
- HUMAN_NEEDED.md: `bash .agentic/tools/blocker.sh add "Title" "type" "Details"`
- FEATURES.md: `bash .agentic/tools/feature.sh F-#### status shipped`

Subagent context: Run `bash .agentic/tools/context-for-role.sh <role> <feature-id>` to assemble minimal context per subagent. Subagents do NOT inherit CLAUDE.md.

Agent mode: Check `agent_mode` in STACK.md (premium|balanced|economy). Details: auto_orchestration.md

Workflows, delegation, gates, checklists: run `ag` commands or see `.agentic/agents/shared/auto_orchestration.md`
