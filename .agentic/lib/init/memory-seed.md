---
summary: "Action rules agents write to persistent memory at session start"
tokens: ~900
---

# Memory Seed — Agentic Framework Action Rules

<!-- memory-seed v0.65.0 -->
<!-- sentinels: pre-commit sequence, token-efficient scripts, ag commit, ag done, ag docs, ag docs generate, ag todo, ag backlog, dialectical review, ag review, ag worktree, ag decompose, AGENTS.json, autonomous_formal, silent session start, collision guard, ag intent, intent journal, ag auto epic, ag auto pipeline, ag coord, docs-with-code, instruction-sync, llm-test-advisory, docs-validate, docs-create, docs-mode-deferred, ag kickoff, vision-to-backlog pipeline, staging area, review_commit, review_integration, verify-epic, ag formalize, ag feedback, feedback capture, tdd-mode, checkpoint-phase, check-tdd-phases, ac-clarity-gate, nfr-applicable, p1-ac-threshold, design-trace, source-annotation, smoke-test-evidence, ExitPlanMode-hook, tool-native-hooks, centralized-ids, review_pr, pr-auto-fix, plan-convergence-loop, reviewer-catalog, expert-reviewers, ag start, ag work, ag spec, ag test, ag transition, merged-but-not-done-hook, enforcement-hierarchy -->

Write these rules to persistent memory. They are action triggers — execute the specified command when the condition is met.

## Build / implement / create → spec first

**STOP.** Do not write code yet.
1. Assign F-XXXX in FEATURES.md if none exists
2. Create `spec/acceptance/F-XXXX.md` with acceptance criteria FIRST
3. `ag plan F-XXXX` → plan-review convergence loop
4. `ag implement F-XXXX` after plan is APPROVED

- A plan is NOT a spec — even with a detailed plan, create formal artifacts before coding
- AC clarity gate: vague ACs blocked in formal, advisory in discovery. Bypass: `SKIP_CLARITY=1`
- If `spec_analysis` enabled (default on for formal): `spec-analyze.sh` runs advisory checks
- `ag implement` auto-creates WIP tracking + worktree (if `worktree_mode: always`)
- TDD mode (`development_mode: tdd`): enforces RED→GREEN→REFACTOR per AC
- >10 files scope → **TOO BIG** — break into 3-5 smaller tasks
- **Profiles**: `discovery` (lightweight) | `formal` (spec-driven) | `autonomous_formal` (formal + delegated reviews). `is_formal_like()` checks formal rigor.

## Plans must be saved and reviewed

Plans saved to `.agentic/journal/plans/YYYY-MM-DD-F-XXXX-plan.md` or they are LOST.

**After ExitPlanMode** — auto-continue immediately, do NOT stop:
1. Save plan as DRAFT (tool locations like `~/.claude/plans/` are session-scoped)
2. Spawn Critic + Advocate agents (parallel, fresh context)
3. Synthesize → revise if refinements needed → re-run reviewers
4. Loop until convergence OR max iterations (→ ESCALATED → HUMAN_NEEDED)
5. `plan_review_convergence: auto` → auto-approve on convergence; `manual` → user decides
6. After APPROVED → `ag implement F-XXXX`

**Wrong rationalizations**: "user created it so it's reviewed" / "plan exit = approval" / "I should stop and wait" / "simple plan, skip review" / "proceed with refinements during implementation" — ALL WRONG. See CLAUDE.md for full list.

**User-provided plans**: Same flow — save as DRAFT → spawn reviewers → convergence loop → APPROVED → implement.

## Fix / debug / troubleshoot → failing test first

**STOP.** Write a failing test that reproduces the bug FIRST. Then fix. Then verify.

## Commit / push / ship → pre-commit sequence

**STOP.** Check `wip.sh check` — if WIP exists, BLOCK. Then:
1. `journal.sh "Topic" "Outcomes" "Next" "Blockers" --why "Why"` (outcomes, not file lists)
2. `status.sh focus "Current task"`
3. If shipping: `feature.sh F-#### status shipped`
4. `ag commit` — runs quality gates, shows diff, waits for human approval
5. **Spec + code + tests + docs = done** — run `drift.sh --docs` + `docs.sh --validate`, update all artifacts in same commit. Exception: `docs_mode: deferred` skips inline docs.

## Done / complete / finished / merged

**STOP.** Run `ag done F-XXXX`. P1 ACs must be 100% checked. Before ending: check TaskList, flush to `ag todo`. Review PR for "future work"/"deferred" items → `ag todo` each with **Background** + **Related** fields.

- `ag merge <pr#> F-XXXX` chains merge + `ag done` — use instead of `gh pr merge`
- **Hook enforcement**: UserPromptSubmit warns if recent commits on main have unshipped features. PostToolUse warns if `gh pr merge` used directly. Both remind to run `ag done`.
- `ag done` runs `ag verify F-XXXX` automatically (blocking for formal, advisory for discovery)
- Post-merge dogfood sync (framework dev): `ag done` runs `ag dogfood --brief` automatically
- Doc lifecycle fires if STACK.md `## Docs` has entries. `docs_mode: deferred` → logs to `deferred-docs.json`
- Smoke evidence: when enabled, `ag done` checks for `evidence/F-XXXX-smoke.*`

## Trigger-action table

| Trigger | Action |
|---------|--------|
| idea/remember/todo/note | `ag todo "description"` |
| backlog/queue/what's next | `ag backlog` (add/done/move) |
| formalize/promote TODOs | `ag formalize` or `ag formalize T-XXXX` |
| "must always/never" / NFR / constraint | `nfr-capture.sh "statement"`. `nfr-propagate.sh derive F-XXXX` for AC derivation |
| decompose/break down epic | `ag decompose F-XXXX` → `review_decomposition` checkpoint. Source annotation: add `**Source**: <path>` to FEATURES.md when creating from a design doc; `design-trace.sh` tracks completion |
| execute epic autonomously | `ag auto epic F-XXXX [--parallel]` (requires decomposed children) |
| full autonomous pipeline | `ag auto pipeline --features-json '...'` (use `ag kickoff` first) |
| kickoff/vision/generate features | `ag kickoff "vision"` → staging → `--review` → `--approve` |
| feedback/tested it/bug report | `ag feedback "text"` (classifies: bug/feature/ac-adjust) |
| run/how to run/dev server | `ag run` (auto-detects stack) |
| verify epic/integration tests | `ag auto verify-epic F-XXXX` |
| verify framework/self-test | `ag auto verify-framework --project <name>` |
| session start/where were we | `ag start` → output dashboard.sh verbatim, no preamble |
| quick ad-hoc work | `ag work "description"` |
| write/update spec | `ag spec F-XXXX` (shipped specs are contracts AND living documents — migration.sh for changes; evolve affected specs when your changes overlap) |
| run tests | `ag test` or `ag test llm` |
| feature state/transition | `ag transition F-XXXX <state>` or `--status` or `--unblocked` |
| parallel agent coordination | `ag coord start` (HTTP JSON-RPC, port 4185, bearer auth) |
| review/approve/reject | `ag review` to list, `ag review F-XXXX <state>` to resolve |
| interrupted/crashed/resume | `ag intent list` for orphans, `ag sync` to auto-adopt |
| analyze session/workflow violations | `ag analyze-session <path.jsonl> [--json]` — detects plan violations |
| QA coverage map/gap analysis | `ag qa` — generates docs/QA_REGISTRY.md (feature-to-test matrix). `--check` for staleness, `--json` for data |

## State machine enforcement (F-0222)

`state_enforcement` in STACK.md: `off` (discovery default) | `advisory` | `blocking` (formal default). SKIP transitions always valid. `ag done` also checks approved plan when `plan_review_enabled: yes`.

## Session start

ONE tool call: `bash .agentic/lib/tools/dashboard.sh 2>/dev/null` — output verbatim, no preamble.
- Orphaned plans (📝 line): save + review is FIRST action, before anything else
- NFR suggestion: if 3+ features shipped with no project-specific NFRs → suggest `ag nfr discover`

## Token-efficient scripts (always use, never edit files directly)

| File | Command |
|------|---------|
| STATUS.md | `status.sh focus "Task"` |
| JOURNAL.md | `journal.sh "Topic" "Outcomes" "Next" "Blockers" --why "Why"` |
| HUMAN_NEEDED.md | `blocker.sh add "Title" "type" "Details"` |
| FEATURES.md | `feature.sh F-#### status shipped` |
| TODO.md | `todo.sh add "Idea"` or `ag todo "Idea"` |
| FEEDBACK_LOG.md | `feedback.sh add "text"` or `ag feedback "text"` |

## Where to log things

- Prioritized work → `ag backlog add F-XXXX` (BACKLOG.json = ordered queue)
- Idea/task → `ag todo` (TODO.md = unfiltered inbox). Flow: idea → todo → triage → backlog
- Human blocker → `blocker.sh` (HUMAN_NEEDED.md). NOT for dev tasks
- Bug/debt → ISSUES.md | New capability → FEATURES.md

## Rules that always apply

- Interactive: show changes before committing. Autonomous (`ag auto`): commit directly per `review_commit` setting
- Post-PR auto-review (F-0235): `review_pr: critical_agent` → auto-review + auto-fix. `human` → review block. `skip` → nothing
- **Never bypass gates** (`--no-verify`) — exception: `ag flush` has its own validation
- **NEVER `git stash`** — silent merge causes data loss. Use worktrees or commit first
- **Never** `checkout .`, `restore .`, `reset --hard` with uncommitted changes
- Multi-session collision guard: check AGENTS.json before destructive git ops
- One feature at a time. Small batches (5-10 files/commit). Keep main in sync with origin
- Smoke test before "done" — "tests pass" ≠ "it works"
- **Centralized IDs**: Feature IDs in `ids.py`/`ids.sh`. Never hardcode regex. `format_feature_id(n)`, `is_valid_feature_id(s)`
- **Framework dev only**: instruction files are part of the feature. LLM test required for behavioral changes. Agent definition parity enforced (roles + subagents + manifests together)
- **Who tests the tests?** "Could this test pass with a broken implementation?" Run `ag audit` for spec→AC→test chain
