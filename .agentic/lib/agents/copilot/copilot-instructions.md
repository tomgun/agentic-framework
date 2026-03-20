# Copilot Instructions

You are working in a repo that uses the agentic development framework (folder: .agentic/).

Always consult: AGENTS.md (if present), `.agentic/lib/agents/shared/agent_operating_guidelines.md`, CONTEXT_PACK.md, STATUS.md, spec/* and .agentic/spec/adr/* as the source of truth.

Quick Commands: `ag start` | `ag sync` | `ag implement F-XXXX` | `ag work "desc"` | `ag commit` | `ag done` | `ag merge <pr#> [F-XXXX]` | `ag verify F-XXXX` | `ag flush` | `ag backlog` | `ag review` | `ag decompose F-XXXX` | `ag worktree` | `ag spec` | `ag plan` | `ag docs` | `ag todo` | `ag feedback` | `ag intent` | `ag formalize` | `ag kickoff "vision"` | `ag run` | `ag audit` | `ag nfr` | `ag transition` | `ag dogfood` | `ag test` | `ag analyze-session`
Autonomous: `ag auto verify` | `ag auto verify --visual` | `ag auto task F-XXXX` | `ag auto crunch` | `ag auto epic F-XXXX` | `ag auto epic F-XXXX --parallel` | `ag auto pipeline` | `ag auto verify-framework`
Kickoff: `ag kickoff "vision"` | `ag kickoff --review` | `ag kickoff --approve` | `ag kickoff --discard`
Coordination: `ag coord start` | `ag coord stop` | `ag coord status`

STOP! Trigger Words (match on intent, not just exact words):
| User intent | Action |
|-------------|--------|
| Build / implement / add / create / set up / develop / make something | STOP -> Run `ag plan F-XXXX` first, then `ag implement` (creates WIP). AC clarity gate runs on first `ag implement` — blocks on vague ACs in formal profile. |
| Build something large (>10 files, "entire", "full system") | STOP -> TOO BIG. Break into 3-5 smaller tasks. Max 5-10 files. |
| Fix / debug / repair / troubleshoot a bug or issue | STOP -> Write failing test FIRST |
| Commit / push / ship / finalize changes | STOP -> Check active WIP (AGENTS.json); if exists BLOCK and warn. Else run `ag commit` |
| Done / complete / finished / merge / wrapped up | STOP -> Run `ag done F-XXXX`. P1 ACs must be 100% checked (priority-grouped specs), 80% overall (flat specs). Smoke evidence checked if `smoke_test_evidence` enabled. After merging a PR (`gh pr merge`), IMMEDIATELY run `ag done` — it's part of the merge, not a separate step. Before ending, flush pending ideas to TODO.md via `ag todo`. |
| Idea / remember / todo / tasklist / note for later | STOP -> `ag todo "description"` for persistent capture (git-tracked). |
| Backlog / queue / what's next / prioritize / reorder work | STOP -> `ag backlog` to see queue. `ag backlog add F-XXXX` to add. Position 0 = current work. |
| Write spec / create spec / acceptance criteria / evolve spec | STOP -> Run `ag spec F-XXXX`. Follow spec protection levels. |
| Review blocked / approve transition / reject transition | STOP -> Run `ag review` to list pending. `ag review F-XXXX <state>` to approve. `--reject` to reject. |
| Decompose / break down epic / split into children | STOP -> Run `ag decompose F-XXXX`. Analyzes AC, proposes child features scoped to components, routes through review_decomposition checkpoint. |
| Exited plan mode (plan approved) | STOP -> Save plan as DRAFT. If `plan_review_enabled: yes`: auto-continue — play both Critic and Advocate roles sequentially (self-play), synthesize. If `convergence: auto`, auto-approve on convergence; if `manual`, present to user. Then `ag implement F-XXXX` (creates WIP). |
| Interrupted / crashed / stuck intent / orphaned work / resume | STOP -> Run `ag intent list` to see pending/orphaned intents. `ag intent clear F-XXXX` to discard. `ag sync` auto-adopts orphans. |
| Analyze session / workflow violations / session log | STOP -> Run `ag analyze-session <path.jsonl>` to detect plan violations in Claude JSONL logs |
| Fix all tests / make tests pass / run test loop automatically | Suggest `ag auto verify` (add `--visual` if E2E screenshots configured) |
| Implement autonomously / auto-implement / hands-off | Suggest `ag auto task F-XXXX` (needs acceptance criteria) |
| Process all features / batch implement / implement everything | Suggest `ag auto crunch` (processes all planned features) |
| Execute epic / implement all children of epic / run epic autonomously | Suggest `ag auto epic F-XXXX` or `ag auto pipeline` (executes epic's child features with component-scoped workers) |
| Verify framework / test the framework / self-test | Suggest `ag auto verify-framework --project <name>` or `--all` (builds example projects, self-heals framework bugs) |
| Feedback / tested it / tried it / after testing / user reported | STOP -> Run `ag feedback "text"`. Classifies (bug/feature/ac-adjust/unclear), persists to FEEDBACK_LOG.md. `--bug`/`--feature`/`--ac` for direct routing. `ag feedback log` to view. |
| Formalize / promote to formal / migrate TODOs to features | STOP -> Run `ag formalize` to list promotable items. `ag formalize T-XXXX` promotes specific items. `ag formalize --all` for bulk. |
| Audit / check quality / spec health / test chain | STOP -> Run `ag audit` for spec verification & QA audit. `ag audit --full` for comprehensive. `ag audit --status` for pending items. |
| NFR / non-functional / performance constraint / security requirement | STOP -> Run `ag nfr list` to see NFRs. `ag nfr discover` to auto-detect applicable NFRs. `ag nfr coverage` to check test coverage. |
| Transition / state change / move to next phase / feature status | STOP -> Run `ag transition F-XXXX <state>`. `ag transition F-XXXX --status` to see current. `ag transition --unblocked` for ready features. |

Acceptance criteria: Formal requires .agentic/spec/acceptance/F-####.md before coding | Discovery: define criteria (any form) before coding.

TDD mode: When `development_mode: tdd` in STACK.md, use per-AC red-green-refactor cycle with `wip.sh checkpoint --phase RED|GREEN|REFACTOR "note"`. `wip.sh complete` blocks without phase checkpoints.

Small batch development: When user asks for something large ("entire", "full", "complete system"), STOP - TOO BIG for one task. Break into smaller pieces (3-5 files max each). Max 5-10 files per commit.

Rules:
- **PR by default**: Create feature branches and PRs (check `git_workflow` in STACK.md). After creating a PR, add entry to HUMAN_NEEDED.md for review tracking.
- Interactive sessions: show changes to human before committing. Autonomous/non-interactive sessions (e.g. `ag auto` workflows): commit directly, using `review_commit` setting to determine review level (F-0203).
- Add/update tests for new/changed logic.
- Spec + code + tests + docs = done (update all artifacts together, not later).
- Shipped specs are contracts: never modify shipped acceptance criteria without a spec migration.
- Keep changes small and scoped.
- Update JOURNAL.md and STATUS.md before every commit (use token-efficient scripts).
- Multi-agent: check AGENTS.json for active agents before starting work.
- Multi-session safety: Never run destructive git ops (stash, checkout ., restore ., reset --hard, clean -f) when other sessions may be active on the same checkout. Use a worktree or commit first.
- **Where to log**: Prioritized work → `ag backlog add`; task/idea → `ag todo`; human blocker (PR, credential, decision) → `blocker.sh`; bug → `quick_issue.sh`; new capability → `feature.sh`. Do NOT put development tasks in HUMAN_NEEDED.md.

Token-efficient scripts (ALWAYS use these, NEVER read/edit these files directly):
- STATUS.md: `bash .agentic/lib/tools/status.sh focus "Task"`
- JOURNAL.md: `bash .agentic/lib/tools/journal.sh "Topic" "Outcome for the project" "Next" "Blockers" --why "Problem solved"`
- HUMAN_NEEDED.md: `bash .agentic/lib/tools/blocker.sh add "Title" "type" "Details"`
- FEATURES.md: `bash .agentic/lib/tools/feature.sh F-#### status shipped`
- TODO.md: `bash .agentic/lib/tools/todo.sh add "Idea"` or `ag todo "Idea"`

Agent mode: Check `agent_mode` in STACK.md (premium|balanced|economy). Details: auto_orchestration.md

Workflows, delegation, gates, checklists: run `ag` commands or see `.agentic/lib/agents/shared/auto_orchestration.md`
