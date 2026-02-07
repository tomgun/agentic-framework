# Claude Instructions

THIS IS FRAMEWORK DEVELOPMENT. You are working ON the agentic framework itself, not a project using it. Framework changes affect ALL users - extra care required.

Read first: `FRAMEWORK_QUICK_START.md`, `FRAMEWORK_DEVELOPMENT.md`, `.agentic/PRINCIPLES.md`

Always consult: AGENTS.md (if present), `.agentic/agents/shared/agent_operating_guidelines.md`, CONTEXT_PACK.md, STATUS.md, spec/* and spec/adr/* as the source of truth.

ENFORCED GATES (Profile-Aware):
| Gate | Core+PM (formal) | Core (discovery) |
|------|------------------|------------------|
| Acceptance criteria | BLOCKS - `ag implement` requires spec/acceptance/F-XXXX.md | N/A - use `ag work` |
| WIP before commit | BLOCKS - must complete WIP first | WARNING only |
| Test execution | BLOCKS - tests must pass | BLOCKS - tests for changed files |
| Complexity limits | BLOCKS - max files/lines/length | BLOCKS - same limits apply |
| Pre-commit checks | BLOCKS - full validation | Light check, no block |
| Feature status | BLOCKS - shipped needs acceptance | N/A |

Escape hatches (feature branches only): SKIP_TESTS=1 or SKIP_COMPLEXITY=1

Quick Commands: `ag start` | `ag implement F-XXXX` | `ag work "desc"` | `ag commit` | `ag done`

STOP! Trigger Words:
| Trigger | Action |
|---------|--------|
| "build", "implement", "add", "create" | STOP -> Run `ag plan F-XXXX` first, then `ag implement` |
| "implement entire", "full system" | STOP -> TOO BIG. Break into 3-5 smaller tasks. Max 5-10 files. |
| "fix", "bug", "issue" | STOP -> Write failing test FIRST |
| "commit", "push" | STOP -> Check .agentic-state/WIP.md first; if exists BLOCK and warn. Else run `ag commit` |
| "done", "complete" | STOP -> Run `ag done F-XXXX` |

DO NOT PROCEED without acceptance criteria: spec/acceptance/F-####.md must exist. Criteria before code. No exceptions.

Small batch development: When user asks for something large ("entire", "full", "complete system"), STOP - TOO BIG for one task. Break into smaller pieces (3-5 files max each). Max 5-10 files per commit.

Rules:
- **PR by default**: Create feature branches and PRs (check `git_workflow` in STACK.md). After creating a PR, add entry to HUMAN_NEEDED.md for review tracking.
- Never auto-commit. Show changes to human first.
- Add/update tests for new/changed logic.
- Code + docs = done (update docs with code, not later).
- Keep changes small and scoped.
- Log at natural checkpoints, not just session end.
- Multi-agent: read `.agentic-state/AGENTS_ACTIVE.md` before starting work. If another agent is active on same feature, warn about conflict and suggest a different task or coordination.

Agent Boundaries:
| ALWAYS | ASK FIRST | NEVER |
|--------|-----------|-------|
| Run tests before "done" | Add dependencies | Commit without approval |
| Update specs with code | Change architecture | Push to main directly |
| Follow existing patterns | Delete files | Modify secrets/.env |

Agent Mode (MUST read `agent_mode` in STACK.md before any delegation):
- premium: opus for planning/impl/review, sonnet for search
- balanced (default): opus for planning, sonnet for impl/review, haiku for search
- economy: sonnet for planning, haiku for everything else
- Custom: check `models:` section. Docs: `.agentic/workflows/agent_mode.md`

Token-efficient scripts (ALWAYS use these, NEVER read/edit these files directly):
- STATUS.md: `bash .agentic/tools/status.sh focus "Task"`
- JOURNAL.md: `bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers"` (appends directly, never reads full file — saves tokens)
- HUMAN_NEEDED.md: `bash .agentic/tools/blocker.sh add "Title" "type" "Details"`
- FEATURES.md: `bash .agentic/tools/feature.sh F-#### status shipped`

Session Protocols:
- START: Run `ag start`. Read STATUS.md, HUMAN_NEEDED.md, check .agentic-state/WIP.md. If WIP.md exists: read its content, warn about the interrupted work (mention specific feature/task), and suggest resuming before starting anything new. Greet user proactively with current focus, next steps, blockers.
- END: Run `.agentic/checklists/session_end.md`, update JOURNAL.md.
- DONE: Run `.agentic/checklists/feature_complete.md` before claiming done.

Checklists: `.agentic/checklists/` (session_start, session_end, feature_complete, before_commit)

Task Tool Delegation (spawn subagents to save tokens):
| Task Type | subagent_type | premium | balanced | economy |
|-----------|---------------|---------|----------|---------|
| Codebase search | `Explore` | sonnet | haiku | haiku |
| Planning/architecture | `Plan` | opus | opus | sonnet |
| Implementation | `general-purpose` | opus | sonnet | haiku |
| Testing/review | `general-purpose` | opus | sonnet | haiku |

Pass to subagent ONLY: Feature ID, acceptance criteria, 3-5 relevant files, STACK.md info.

Standards: programming (`.agentic/quality/programming_standards.md`), testing (`.agentic/quality/test_strategy.md`), dev mode in STACK.md (tdd recommended, `.agentic/workflows/tdd_mode.md`).

---

## Framework Development

Validation: `bash tests/validate_framework.sh` must pass before committing.
Dogfooding: `.agentic/` is the source of truth - develop templates there first, root files extend.
New features: Add to `spec/FEATURES.md` FIRST, create acceptance criteria before coding.
Breaking changes: Provide upgrade path in `upgrade.sh`.
Test in scratch project before committing framework changes.
Worktree: Use `git worktree` on feature branches when another agent may be working on main.
