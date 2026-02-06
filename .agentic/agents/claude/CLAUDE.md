# Claude Instructions

You are working in a repo that uses the agentic development framework (folder: .agentic/).

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
| "build", "implement", "add", "create" | STOP -> Run `ag implement F-XXXX` |
| "implement entire", "full system" | STOP -> TOO BIG. Break into 3-5 smaller tasks. Max 5-10 files. |
| "fix", "bug", "issue" | STOP -> Write failing test FIRST |
| "commit", "push" | STOP -> Run `ag commit` |
| "done", "complete" | STOP -> Run `ag done F-XXXX` |

DO NOT PROCEED without acceptance criteria: spec/acceptance/F-####.md must exist. Criteria before code. No exceptions.

Small batch development: When user asks for something large ("entire", "full", "complete system"), STOP - TOO BIG for one task. Break into smaller pieces (3-5 files max each). Max 5-10 files per commit.

Rules:
- **PR by default**: Create feature branches and PRs (check `git_workflow` in STACK.md)
- Never auto-commit. Show changes to human first.
- Add/update tests for new/changed logic.
- Code + docs = done (update docs with code, not later).
- Keep changes small and scoped.
- Log at natural checkpoints, not just session end.
- Multi-agent: check `.agentic-state/AGENTS_ACTIVE.md`, avoid other agents' files.

Agent Boundaries:
| ALWAYS | ASK FIRST | NEVER |
|--------|-----------|-------|
| Run tests before "done" | Add dependencies | Commit without approval |
| Update specs with code | Change architecture | Push to main directly |
| Follow existing patterns | Delete files | Modify secrets/.env |

Agent Mode (check `agent_mode` in STACK.md):
- premium: opus for planning/impl/review, sonnet for search
- balanced (default): opus for planning, sonnet for impl/review, haiku for search
- economy: sonnet for planning, haiku for everything else
- Custom: check `models:` section. Docs: `.agentic/workflows/agent_mode.md`

Token-efficient scripts (USE THESE, don't edit files directly):
- STATUS.md: `bash .agentic/tools/status.sh focus "Task"`
- JOURNAL.md: `bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers"`
- HUMAN_NEEDED.md: `bash .agentic/tools/blocker.sh add "Title" "type" "Details"`
- FEATURES.md: `bash .agentic/tools/feature.sh F-#### status shipped`

Session Protocols:
- START: Run `ag start`. Read STATUS.md, HUMAN_NEEDED.md, check for WIP.md. Greet user proactively with current focus, next steps, blockers.
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
