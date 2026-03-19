# GitHub Copilot Instructions - Framework Development

THIS IS FRAMEWORK DEVELOPMENT. You are working ON the agentic framework itself, not a project using it. Framework changes affect ALL users - extra care required.

Read first: `FRAMEWORK_QUICK_START.md`, `FRAMEWORK_DEVELOPMENT.md`, `.agentic/lib/PRINCIPLES.md`

Full template: `.agentic/lib/agents/copilot/copilot-instructions.md`

Always consult: AGENTS.md (if present), `.agentic/lib/agents/shared/agent_operating_guidelines.md`, CONTEXT_PACK.md, .agentic/STATUS.md, .agentic/spec/* and .agentic/spec/adr/* as the source of truth.

Quick Commands: `ag start` | `ag sync` | `ag implement F-XXXX` | `ag work "desc"` | `ag commit` | `ag done` | `ag merge <pr#> [F-XXXX]` | `ag verify F-XXXX` | `ag flush` | `ag backlog` | `ag review` | `ag decompose F-XXXX` | `ag worktree` | `ag spec` | `ag plan` | `ag docs` | `ag todo` | `ag feedback` | `ag intent` | `ag formalize` | `ag kickoff "vision"` | `ag run` | `ag audit` | `ag nfr` | `ag transition` | `ag dogfood`
Autonomous: `ag auto verify` | `ag auto verify --visual` | `ag auto task F-XXXX` | `ag auto crunch` | `ag auto epic F-XXXX` | `ag auto epic F-XXXX --parallel` | `ag auto pipeline` | `ag auto verify-framework`
Kickoff: `ag kickoff "vision"` | `ag kickoff --review` | `ag kickoff --approve` | `ag kickoff --discard`
Coordination: `ag coord start` | `ag coord stop` | `ag coord status`

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
| Exited plan mode (plan approved) | STOP -> Save plan as DRAFT. If `plan_review_enabled: yes`: auto-continue — run dialectical review (Critic + Advocate in parallel, fresh context), synthesize. If `convergence: auto`, auto-approve on convergence; if `manual`, present to user. Then `ag implement F-XXXX` (creates WIP). |
| Interrupted / crashed / stuck intent / orphaned work / resume | STOP -> Run `ag intent list` to see pending/orphaned intents. `ag intent clear F-XXXX` to discard. `ag sync` auto-adopts orphans. |
| Fix all tests / make tests pass / run test loop automatically | Suggest `ag auto verify` (add `--visual` if E2E screenshots configured) |
| Implement autonomously / auto-implement / hands-off | Suggest `ag auto task F-XXXX` (needs acceptance criteria) |
| Process all features / batch implement / implement everything | Suggest `ag auto crunch` (processes all planned features) |
| Execute epic / implement all children of epic / run epic autonomously | Suggest `ag auto epic F-XXXX` or `ag auto pipeline` (executes epic's child features with component-scoped workers) |
| Verify framework / test the framework / self-test | Suggest `ag auto verify-framework --project <name>` or `--all` (builds example projects, self-heals framework bugs) |
| Feedback / tested it / tried it / after testing / user reported | STOP -> Run `ag feedback "text"`. Classifies (bug/feature/ac-adjust/unclear), persists to FEEDBACK_LOG.md. `--bug`/`--feature`/`--ac` for direct routing. `ag feedback log` to view. |
| Formalize / promote to formal / migrate TODOs to features | STOP -> Run `ag formalize` to list promotable items. `ag formalize T-XXXX` promotes specific items. `ag formalize --all` for bulk. |

DO NOT PROCEED without acceptance criteria: .agentic/spec/acceptance/F-####.md must exist. Criteria before code. No exceptions.

Small batch development: When user asks for something large ("entire", "full", "complete system"), STOP - TOO BIG for one task. Break into smaller pieces (3-5 files max each). Max 5-10 files per commit.

Rules:
- **PR by default**: Create feature branches and PRs (check `git_workflow` in STACK.md). After creating a PR, add entry to HUMAN_NEEDED.md for review tracking.
- Interactive sessions: show changes to human before committing. Autonomous/non-interactive sessions (e.g. `ag auto` workflows): commit directly, using `review_commit` setting to determine review level (F-0203).
- Add/update tests for new/changed logic.
- Spec + code + tests + docs = done (update all artifacts together, not later).
- Shipped specs are contracts: never modify shipped acceptance criteria without a spec migration.
- Keep changes small and scoped.
- **Every merge**: Bump VERSION via `ag done` (not in the PR). Update .agentic/CONTRIBUTIONS.md with user's insight/direction during the PR.
- Update .agentic/journal/JOURNAL.md and .agentic/STATUS.md before every commit (use token-efficient scripts).
- Multi-agent: check AGENTS.json for active agents before starting work.
- Multi-session safety: Never run destructive git ops (stash, checkout ., restore ., reset --hard, clean -f) when other sessions may be active on the same checkout. Use a worktree or commit first.
- **Where to log**: Prioritized work → `ag backlog add`; task/idea → `ag todo`; human blocker (PR, credential, decision) → `blocker.sh`; bug → `quick_issue.sh`; new capability → `feature.sh`. Do NOT put development tasks in HUMAN_NEEDED.md.

Token-efficient scripts (ALWAYS use these, NEVER read/edit these files directly):
- .agentic/STATUS.md: `bash .agentic/lib/tools/status.sh focus "Task"`
- .agentic/journal/JOURNAL.md: `bash .agentic/lib/tools/journal.sh "Topic" "Done" "Next" "Blockers" --why "Reason"`
- .agentic/HUMAN_NEEDED.md: `bash .agentic/lib/tools/blocker.sh add "Title" "type" "Details"`
- .agentic/spec/FEATURES.md: `bash .agentic/lib/tools/feature.sh F-#### status shipped`
- TODO.md: `bash .agentic/lib/tools/todo.sh add "Idea"` or `ag todo "Idea"`

Workflows, delegation, gates, checklists: run `ag` commands or see `.agentic/lib/agents/shared/auto_orchestration.md`

---

## Framework Development

Validation: `bash tests/validate_framework.sh` must pass before committing.
New features: Add to `.agentic/spec/FEATURES.md` FIRST, create acceptance criteria before coding.
Breaking changes: Provide upgrade path in `upgrade.sh`.
Test in scratch project before committing framework changes.
Instruction files are part of the feature: new `ag` commands/gates MUST update all instruction files (templates, skills, checklists, memory-seed, DEVELOPER_GUIDE, HOW_IT_WORKS).
