# GitHub Copilot Instructions - Framework Development

THIS IS FRAMEWORK DEVELOPMENT. You are working ON the agentic framework itself, not a project using it. Framework changes affect ALL users - extra care required.

Read first: `FRAMEWORK_QUICK_START.md`, `FRAMEWORK_DEVELOPMENT.md`, `.agentic/lib/PRINCIPLES.md`

Full template: `.agentic/lib/agents/copilot/copilot-instructions.md`

Always consult: AGENTS.md (if present), `.agentic/lib/agents/shared/agent_operating_guidelines.md`, CONTEXT_PACK.md, .agentic/STATUS.md, .agentic/spec/* and .agentic/spec/adr/* as the source of truth.

Quick Commands: `ag start` | `ag sync` | `ag implement F-XXXX` | `ag work "desc"` | `ag commit` | `ag done` | `ag flush` | `ag backlog` | `ag review` | `ag decompose F-XXXX` | `ag spec` | `ag docs` | `ag todo` | `ag preview`

STOP! Trigger Words (match on intent, not just exact words):
| User intent | Action |
|-------------|--------|
| Build / implement / add / create / set up / develop / make something | STOP -> Run `ag plan F-XXXX` first, then `ag implement` |
| Build something large (>10 files, "entire", "full system") | STOP -> TOO BIG. Break into 3-5 smaller tasks. Max 5-10 files. |
| Fix / debug / repair / troubleshoot a bug or issue | STOP -> Write failing test FIRST |
| Commit / push / ship / finalize changes | STOP -> Check active WIP via `ag status` or AGENTS.json; if WIP exists BLOCK and warn. Else run `ag commit` |
| Done / complete / finished / wrapped up | STOP -> Run `ag done F-XXXX`. Before ending, flush pending ideas to .agentic/TODO.md via `ag todo`. |
| Idea / remember / todo / tasklist / note for later | STOP -> `ag todo "description"` for persistent capture (git-tracked). |
| Backlog / queue / what's next / prioritize / reorder work | STOP -> `ag backlog` to see queue. `ag backlog add F-XXXX` to add. |
| Write spec / create spec / acceptance criteria / evolve spec | STOP -> Run `ag spec F-XXXX`. Follow spec protection levels. |
| Review blocked / approve transition / reject transition | STOP -> Run `ag review` to list pending. `ag review F-XXXX <state>` to approve. `--reject` to reject. |
| Decompose / break down epic / split into children | STOP -> Run `ag decompose F-XXXX`. Analyzes AC, proposes child features scoped to components, routes through review_decomposition checkpoint. |

DO NOT PROCEED without acceptance criteria: .agentic/spec/acceptance/F-####.md must exist. Criteria before code. No exceptions.

Small batch development: When user asks for something large ("entire", "full", "complete system"), STOP - TOO BIG for one task. Break into smaller pieces (3-5 files max each). Max 5-10 files per commit.

Rules:
- Never auto-commit. Show changes to human first.
- Add/update tests for new/changed logic.
- Spec + code + tests + docs = done (update all artifacts together, not later).
- Keep changes small and scoped.
- **Every merge**: Bump VERSION via `ag done` (not in the PR). Update .agentic/CONTRIBUTIONS.md with user's insight/direction during the PR.
- Update .agentic/journal/JOURNAL.md and .agentic/STATUS.md before every commit (use token-efficient scripts).

Token-efficient scripts (ALWAYS use these, NEVER read/edit these files directly):
- .agentic/STATUS.md: `bash .agentic/lib/tools/status.sh focus "Task"`
- .agentic/journal/JOURNAL.md: `bash .agentic/lib/tools/journal.sh "Topic" "Done" "Next" "Blockers" --why "Reason"`
- .agentic/HUMAN_NEEDED.md: `bash .agentic/lib/tools/blocker.sh add "Title" "type" "Details"`
- .agentic/spec/FEATURES.md: `bash .agentic/lib/tools/feature.sh F-#### status shipped`

Workflows, delegation, gates, checklists: run `ag` commands or see `.agentic/lib/agents/shared/auto_orchestration.md`

---

## Framework Development

Validation: `bash tests/validate_framework.sh` must pass before committing.
New features: Add to `.agentic/spec/FEATURES.md` FIRST, create acceptance criteria before coding.
Breaking changes: Provide upgrade path in `upgrade.sh`.
Test in scratch project before committing framework changes.
Instruction files are part of the feature: new `ag` commands/gates MUST update all instruction files (templates, skills, checklists, memory-seed, DEVELOPER_GUIDE, HOW_IT_WORKS).
