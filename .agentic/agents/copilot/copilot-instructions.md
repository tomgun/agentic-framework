# Copilot Instructions

You are working in a repo that uses the agentic development framework (folder: .agentic/).

Always consult: AGENTS.md (if present), `.agentic/agents/shared/agent_operating_guidelines.md`, CONTEXT_PACK.md, STATUS.md, spec/* and spec/adr/* as the source of truth.

Quick Commands: `ag start` | `ag implement F-XXXX` | `ag work "desc"` | `ag commit` | `ag done`

STOP! Trigger Words (match on intent, not just exact words):
| User intent | Action |
|-------------|--------|
| Build / implement / add / create / set up / develop / make something | STOP -> Run `ag plan F-XXXX` first, then `ag implement` (creates WIP) |
| Build something large (>10 files, "entire", "full system") | STOP -> TOO BIG. Break into 3-5 smaller tasks. Max 5-10 files. |
| Fix / debug / repair / troubleshoot a bug or issue | STOP -> Write failing test FIRST |
| Commit / push / ship / finalize changes | STOP -> Check .agentic-state/WIP.md first; if exists BLOCK and warn. Else run `ag commit` |
| Done / complete / finished / wrapped up | STOP -> Run `ag done F-XXXX`. Before ending, flush pending ideas to TODO.md via `ag todo`. |
| Idea / remember / todo / tasklist / note for later | STOP -> `ag todo "description"` for persistent capture (git-tracked). |
| Exited plan mode (plan approved) | STOP -> Save plan durably, then `ag implement F-XXXX` (creates WIP). If `plan_review_enabled: yes`: run `/review` on plan before coding. |

Acceptance criteria: Formal requires spec/acceptance/F-####.md before coding | Discovery: define criteria (any form) before coding.

Small batch development: When user asks for something large ("entire", "full", "complete system"), STOP - TOO BIG for one task. Break into smaller pieces (3-5 files max each). Max 5-10 files per commit.

Rules:
- **PR by default**: Create feature branches and PRs (check `git_workflow` in STACK.md). After creating a PR, add entry to HUMAN_NEEDED.md for review tracking.
- Never auto-commit. Show changes to human first.
- Add/update tests for new/changed logic.
- Code + docs = done (update docs with code, not later).
- Keep changes small and scoped.
- Update JOURNAL.md and STATUS.md before every commit (use token-efficient scripts).
- Multi-agent: read `.agentic-state/AGENTS_ACTIVE.md` before starting work.
- **Where to log**: Task/idea → `ag todo`; human blocker (PR, credential, decision) → `blocker.sh`; bug → `quick_issue.sh`; new capability → `feature.sh`. Do NOT put development tasks in HUMAN_NEEDED.md.

Token-efficient scripts (ALWAYS use these, NEVER read/edit these files directly):
- STATUS.md: `bash .agentic/tools/status.sh focus "Task"`
- JOURNAL.md: `bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers"`
- HUMAN_NEEDED.md: `bash .agentic/tools/blocker.sh add "Title" "type" "Details"`
- FEATURES.md: `bash .agentic/tools/feature.sh F-#### status shipped`
- TODO.md: `bash .agentic/tools/todo.sh add "Idea"` or `ag todo "Idea"`

Agent mode: Check `agent_mode` in STACK.md (premium|balanced|economy). Details: auto_orchestration.md

Workflows, delegation, gates, checklists: run `ag` commands or see `.agentic/agents/shared/auto_orchestration.md`
