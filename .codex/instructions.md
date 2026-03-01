# Codex Instructions

THIS IS FRAMEWORK DEVELOPMENT. You are working ON the agentic framework itself, not a project using it. Framework changes affect ALL users - extra care required.

Note: Codex runs commands in a sandbox. Append `|| true` to commands that may fail to prevent non-zero exit codes from halting execution.

Read first: `FRAMEWORK_QUICK_START.md`, `FRAMEWORK_DEVELOPMENT.md`, `.agentic/PRINCIPLES.md`

Always consult: AGENTS.md (if present), `.agentic/agents/shared/agent_operating_guidelines.md`, CONTEXT_PACK.md, STATUS.md, spec/* and spec/adr/* as the source of truth.

Quick Commands: `ag start` | `ag sync` | `ag implement F-XXXX` | `ag work "desc"` | `ag commit` | `ag done` | `ag spec` | `ag docs` | `ag todo`

STOP! Trigger Words (match on intent, not just exact words):
| User intent | Action |
|-------------|--------|
| Build / implement / add / create / set up / develop / make something | STOP -> Run `ag plan F-XXXX` first, then `ag implement` |
| Build something large (>10 files, "entire", "full system") | STOP -> TOO BIG. Break into 3-5 smaller tasks. Max 5-10 files. |
| Fix / debug / repair / troubleshoot a bug or issue | STOP -> Write failing test FIRST |
| Commit / push / ship / finalize changes | STOP -> Check .agentic-state/WIP.md first; if exists BLOCK and warn. Else run `ag commit` |
| Done / complete / finished / wrapped up | STOP -> Run `ag done F-XXXX`. Before ending, flush pending ideas to TODO.md via `ag todo`. |
| Idea / remember / todo / tasklist / note for later | STOP -> `ag todo "description"` for persistent capture (git-tracked). |
| Write spec / create spec / acceptance criteria / evolve spec | STOP -> Run `ag spec F-XXXX`. Follow spec protection levels. |

DO NOT PROCEED without acceptance criteria: spec/acceptance/F-####.md must exist. Criteria before code. No exceptions.

Small batch development: When user asks for something large ("entire", "full", "complete system"), STOP - TOO BIG for one task. Break into smaller pieces (3-5 files max each). Max 5-10 files per commit.

Rules:
- **PR by default**: Create feature branches and PRs (check `git_workflow` in STACK.md). After creating a PR, add entry to HUMAN_NEEDED.md for review tracking.
- Never auto-commit. Show changes to human first.
- Add/update tests for new/changed logic.
- Code + docs = done (update docs with code, not later).
- Keep changes small and scoped.
- **Every PR**: Bump VERSION (at least patch) and update CONTRIBUTIONS.md with user's insight/direction. After merge: `git tag v$(cat VERSION) && git push origin v$(cat VERSION)`.
- Multi-agent: read `.agentic-state/AGENTS_ACTIVE.md` before starting work.

Token-efficient scripts (ALWAYS use these, NEVER read/edit these files directly):
- STATUS.md: `bash .agentic/tools/status.sh focus "Task"`
- JOURNAL.md: `bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers" --why "Reason"`
- HUMAN_NEEDED.md: `bash .agentic/tools/blocker.sh add "Title" "type" "Details"`
- FEATURES.md: `bash .agentic/tools/feature.sh F-#### status shipped`

Workflows, delegation, gates, checklists: run `ag` commands or see `.agentic/agents/shared/auto_orchestration.md`

---

## Framework Development

Validation: `bash tests/validate_framework.sh` must pass before committing.
Dogfooding: `.agentic/` is the source of truth - develop templates there first, root files extend.
New features: Add to `spec/FEATURES.md` FIRST, create acceptance criteria before coding.
Breaking changes: Provide upgrade path in `upgrade.sh`.
Test in scratch project before committing framework changes.
