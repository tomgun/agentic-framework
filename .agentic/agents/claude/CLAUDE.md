# Claude Instructions

You are working in a repo that uses the agentic development framework (folder: .agentic/).

## Session Start (do this FIRST on every new conversation)

Read STATUS.md, HUMAN_NEEDED.md, and last 2-3 entries of .agentic-journal/JOURNAL.md. Check `bash .agentic/tools/wip.sh check` for interrupted work. Then greet the user with a dashboard: current focus, recent progress, blockers, and suggested next steps. Full protocol: `.agentic/checklists/session_start.md`

Always consult: AGENTS.md (if present), `.agentic/agents/shared/agent_operating_guidelines.md`, CONTEXT_PACK.md, STATUS.md, spec/* and spec/adr/* as the source of truth.

Quick Commands: `ag start` | `ag sync` | `ag implement F-XXXX` | `ag work "desc"` | `ag commit` | `ag done`

STOP! Trigger Words (match on intent, not just exact words):
| User intent | Action |
|-------------|--------|
| Build / implement / add / create / set up / develop / make something | STOP -> If no F-XXXX: create spec/acceptance/F-XXXX.md FIRST, then `ag plan` + `ag implement` (creates WIP). Never code before specs. |
| Build something large (>10 files, "entire", "full system") | STOP -> TOO BIG. Break into 3-5 smaller tasks. Max 5-10 files. |
| Fix / debug / repair / troubleshoot a bug or issue | STOP -> Write failing test FIRST |
| Commit / push / ship / finalize changes | STOP -> Check .agentic-state/WIP.md first; if exists BLOCK and warn. Else run `ag commit` |
| Done / complete / finished / wrapped up | STOP -> Run `ag done F-XXXX`. Before ending, check TaskList for pending items and flush to TODO.md via `ag todo`. |
| Idea / remember / todo / tasklist / note for later | STOP -> `ag todo "description"` for persistent capture (git-tracked). |
| Exited plan mode (plan approved) | STOP -> Save plan durably, then `ag implement F-XXXX` (creates WIP). If `plan_review_enabled: yes`: run `/review` on plan before coding. |

Acceptance criteria: When `feature_tracking=yes` (formal profile): spec/acceptance/F-####.md required before coding | When `feature_tracking=no` (discovery): define criteria (any form) before coding. Override settings: `ag set <key> <value>`

Small batch development: When user asks for something large ("entire", "full", "complete system"), STOP - TOO BIG for one task. Break into smaller pieces (3-5 files max each). Max 5-10 files per commit.

Rules:
- **PR by default**: Create feature branches and PRs (check `git_workflow` in STACK.md). After creating a PR, add entry to HUMAN_NEEDED.md for review tracking, then offer: "Want me to run `/review` on this PR?"
- **Plans are durable**: After plan approval (plan mode or otherwise), save to `.agentic-journal/plans/F-XXXX-plan.md`. Use `ag plan --save <file> F-XXXX` or write directly. Plans in `.claude/plans/` are session-scoped and will be lost.
- Never auto-commit. Show changes to human first.
- Add/update tests for new/changed logic.
- Code + docs = done (update docs with code, not later).
- Keep changes small and scoped.
- Update JOURNAL.md and STATUS.md before every commit (use token-efficient scripts).
- Multi-agent: read `.agentic-state/AGENTS_ACTIVE.md` before starting work.
- **Where to log**: Task/idea → `ag todo`; human blocker (PR, credential, decision) → `blocker.sh`; bug → `quick_issue.sh`; new capability → `feature.sh`. Do NOT put development tasks in HUMAN_NEEDED.md.

Token-efficient scripts (ALWAYS use these, NEVER read/edit these files directly):
- STATUS.md: `bash .agentic/tools/status.sh focus "Task"`
- JOURNAL.md: `bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers" --why "Reason"`
- HUMAN_NEEDED.md: `bash .agentic/tools/blocker.sh add "Title" "type" "Details"`
- FEATURES.md: `bash .agentic/tools/feature.sh F-#### status shipped`
- TODO.md: `bash .agentic/tools/todo.sh add "Idea"` or `ag todo "Idea"`

Subagent context: Run `bash .agentic/tools/context-for-role.sh <role> <feature-id>` to assemble minimal context per subagent. Subagents do NOT inherit CLAUDE.md.

Framework roles (review, test, implementation, etc.) are invoked via `/review`, `/test`, etc. — NOT via the Task tool's subagent_type. The Task tool only has built-in types (Bash, general-purpose, Explore, Plan). Use `/review` for code review, `/test` for test writing, `/implementation` for coding.

Agent mode: Check `agent_mode` in STACK.md (premium|balanced|economy). Details: auto_orchestration.md

Memory seed: At session start, check your persistent memory for framework workflow patterns (trigger→action rules, pre-commit sequence, token-efficient scripts). If missing or stale, read `.agentic/init/memory-seed.md` and write the rules to your memory. These are action triggers, not suggestions — they tell you exactly what command to run when a condition is met.

Workflows, delegation, gates, checklists: run `ag` commands or see `.agentic/agents/shared/auto_orchestration.md`
