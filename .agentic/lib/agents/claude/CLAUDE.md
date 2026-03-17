# Claude Instructions

You are working in a repo that uses the agentic development framework (folder: .agentic/).

## Session Start (do this FIRST on every new conversation)

Run `bash .agentic/lib/tools/dashboard.sh 2>/dev/null` — ONE tool call, no others. Output the result verbatim as your first text response. No preamble, no narration, no reformatting. Full protocol: `.agentic/lib/checklists/session_start.md`

Always consult: AGENTS.md (if present), `.agentic/lib/agents/shared/agent_operating_guidelines.md`, CONTEXT_PACK.md, .agentic/STATUS.md, .agentic/spec/* and .agentic/spec/adr/* as the source of truth.

Quick Commands: `ag start` | `ag sync` | `ag implement F-XXXX` | `ag work "desc"` | `ag commit` | `ag done` | `ag merge <pr#> [F-XXXX]` | `ag verify F-XXXX` | `ag flush` | `ag backlog` | `ag review` | `ag decompose F-XXXX` | `ag worktree` | `ag intent` | `ag formalize` | `ag kickoff "vision"` | `ag run` | `ag feedback`
Autonomous: `ag auto verify` | `ag auto verify --visual` | `ag auto task F-XXXX` | `ag auto crunch` | `ag auto epic F-XXXX` | `ag auto epic F-XXXX --parallel` | `ag auto pipeline` | `ag auto verify-framework`
Kickoff: `ag kickoff "vision"` | `ag kickoff --review` | `ag kickoff --approve` | `ag kickoff --discard`
Coordination: `ag coord start` | `ag coord stop` | `ag coord status`

## Core Rules

- Interactive sessions: show changes to human before committing. Autonomous/non-interactive sessions (e.g. `--print` mode, `ag auto` workflows): commit directly, using the `review_commit` setting to determine review level.
- PR by default: create feature branches and PRs (check `git_workflow` in STACK.md). After creating a PR, add entry to .agentic/HUMAN_NEEDED.md for review tracking.
- Add/update tests for new/changed logic.
- Spec + code + tests + docs = done (update all artifacts together, not later).
- AC completeness enforced at `ag done`: P1 ACs = 100%, P2/P3 = 80%, flat specs = 80%. AC clarity gate runs on first `ag implement` (formal=blocking, discovery=advisory).
- Smoke test evidence: if `smoke_test_evidence` != `off` in STACK.md, `ag done` checks for `.agentic/journal/evidence/F-XXXX-smoke.*`. Generate via `ag auto verify --visual --feature F-XXXX` or create manually.
- Shipped specs are contracts: never modify shipped acceptance criteria without a spec migration (`bash .agentic/lib/tools/migration.sh create`).
- Keep changes small and scoped (max 5-10 files per commit).
- Plans are durable: save to `.agentic/journal/plans/YYYY-MM-DD-F-XXXX-plan.md` after approval. If `plan_review_enabled: yes`: plan review uses dialectical mechanism (Critic + Advocate agents, fresh context).
- Multi-agent: check AGENTS.json (via `agents_helpers.py list`) before starting work.
- Multi-session safety: Before ANY destructive git op (stash, checkout ., restore ., reset --hard, clean -f), run `python3 .agentic/lib/tools/agents_helpers.py --project-root . count-others "$(pwd)" --pid $PPID`. If >0, DO NOT PROCEED — use a worktree or commit first.
- Quick capture: "remember/todo/idea" → run `ag todo "description"` for persistent capture.

## After Plan Mode Exits (when `plan_review_enabled: yes`)

Exiting plan mode creates a DRAFT. It does NOT approve the plan.

After ExitPlanMode:
1. Save plan to `.agentic/journal/plans/YYYY-MM-DD-F-XXXX-plan.md` with `**Status**: DRAFT`
2. Run `ag implement F-XXXX` — it will block and print dialectical review instructions
3. Follow the review instructions (spawn Critic + Advocate agents)
4. After user says "Proceed" → update `**Status**: APPROVED` → re-run `ag implement`

**These rationalizations are WRONG — do not use them:**
- "The user created the plan, so it's reviewed" — plan mode = drafting, not reviewing
- "Plan mode exit = approval" — ExitPlanMode = draft complete, not approved
- "The user said 'implement'" — `ag implement` will block; it's the gate, not a shortcut
- "Simple plan, review unnecessary" — review is structural, not discretionary
- "I have it in context" — save durably, then `ag implement`
- "ag implement told me to review, I'll assess it myself" — spawn Critic + Advocate, don't self-assess

Token-efficient scripts (ALWAYS use these, NEVER edit state files directly):
- .agentic/STATUS.md: `bash .agentic/lib/tools/status.sh focus "Task"`
- .agentic/journal/JOURNAL.md: `bash .agentic/lib/tools/journal.sh "Topic" "Outcomes (not files)" "Next" "Blockers" --why "Problem being solved"`
- .agentic/HUMAN_NEEDED.md: `bash .agentic/lib/tools/blocker.sh add "Title" "type" "Details"`
- .agentic/spec/FEATURES.md: `bash .agentic/lib/tools/feature.sh F-#### status shipped`
- .agentic/TODO.md: `bash .agentic/lib/tools/todo.sh add "Idea"` or `ag todo "Idea"`

## Skills & Workflows

Workflow triggers are handled by Skills in `.claude/skills/`. Each skill has instructions, scripts, and references for its workflow. Key skills: `implementing-features`, `committing-changes`, `fixing-bugs`, `writing-specs`, `session-start`, `completing-work`, `planning-features`, `writing-tests`, `reviewing-code`, `updating-documentation`.

Subagent context: `bash .agentic/lib/tools/context-for-role.sh <role> <feature-id>`. Subagents do NOT inherit CLAUDE.md.

Memory seed: At session start, check persistent memory for framework patterns. If stale, read `.agentic/lib/init/memory-seed.md` and write rules to memory.

Workflows, delegation, gates, checklists: run `ag` commands or see `.agentic/lib/agents/shared/auto_orchestration.md`
