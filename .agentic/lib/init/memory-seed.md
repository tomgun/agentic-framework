# Memory Seed — Agentic Framework

All work is managed by `ag` commands. The CLI enforces the workflow — never skip steps.

## Key Commands
- `ag start F-XXXX "Title"` — begin feature (creates work item, starts planning)
- `ag transition F-XXXX <state>` — advance workflow (checks artifacts first)
- `ag check F-XXXX` — see what's missing for next transition
- `ag verify F-XXXX` — run tests and record results
- `ag done F-XXXX` — post-merge: doc gate, VERSION bump, state flush
- `ag status` — see current work items
- `ag commit` | `ag done` | `ag todo` | `ag backlog` | `ag git-init` | `ag contract` | `ag phase` | `ag persona`

Decision routing: current state → OVERVIEW.md, work log with reasoning → JOURNAL.md (use `--decision` to mark choices), ADR for significant tradeoffs (formal), user preferences → `ag intel remember`.

## Trigger Words
- "phase done/mark phase/phase progress/which phase" → STOP. Run `ag phase list F-XXXX` to see phases, `ag phase done F-XXXX <id>` to mark complete.
- "pending user input/contract input" → STOP. Run `ag contract pending`. Process each pending contract.
- "contract/assertion/verify contract/check contract" → Run `ag contract check` or `ag contract list`. Contracts are in `spec/contracts/F-XXXX.yaml`.
- "promote/unshipped/planned assertions" → Run `ag contract promote F-XXXX` to promote planned assertions to shipped.
- "migrate specs/convert acceptance/markdown to yaml" → STOP. Run `ag migrate-specs` (add `--dry-run` to preview, `--archive` to move old files).
- "churn/batch/all tasks/build everything/implement everything/do all features" → STOP. Run `ag auto crunch`.
- "delegate/fresh context/context optimization/subagent" → MCP task delegation via `ag mcp start`. Use `list_acs` → `get_delegation_prompt` → Agent tool → `save_progress` → `get_next_action` loop.
- "protected branch/can't push to main/push rejected" → Check `main_branch_mode` in STACK.md. If not set, suggest `ag set main_branch_mode protected`. When protected, `ag flush` creates a branch + PR instead of direct push.
- "work autonomously/come back with working/finish everything/do it all" → STOP. Run `ag auto crunch`.
- User preferences/corrections/decisions: When the user expresses a preference, corrects your approach, or makes a decision, capture with `ag intel remember "..." --type preference|learning|decision --context "..."`. Recognize these semantically — don't wait for keywords. Project-scoped (project-memory.yaml), NOT Claude's local MEMORY.md. For write-time enforcement: `ag intel learn "..." --reason "user instruction" --scope "*"`.
- Proposing a choice: Before presenting a recommendation, write: `echo "Use Redis for caching" > .agentic/session/pending-decision.txt`. Framework detects "yes/ok" and advises capture.
- "intelligence/patterns/quality checks" → Run `ag intel` subcommands (check, learn, remember, patterns, memory, decisions, review-session).
- Before workflow phases: run `ag intel architecture` (planning), `ag intel spec F-XXXX` (specs), `ag intel implement F-XXXX` (coding), `ag intel test F-XXXX` (testing) for phase-aware quality guidance.
- NEVER write code for multiple features outside of `ag auto` commands.
- **Wrong rationalizations:** "I can do it directly faster" — NO. "User said autonomous = skip ceremony" — NO. Autonomous means use the autonomous pipeline, not bypass it.

## After Plan Mode Exits — Auto-Continue (do NOT stop)
Exiting plan mode creates a DRAFT. The framework BLOCKS code edits and session stop until resolved. Auto-continue immediately:
1. Save plan to `.agentic/journal/plans/YYYY-MM-DD-F-XXXX-plan.md` with `**Status**: DRAFT` (injected automatically)
2. Spawn Critic + Advocate agents in parallel (fresh context) for dialectical review
3. Save review to `.agentic/work/F-XXXX/review.md` (required — framework checks for evidence)
4. If converged → set `**Status**: APPROVED`; if not → revise plan
5. After APPROVED → run `ag transition F-XXXX implementation`
**Enforcement**: PreToolUse denies code edits when DRAFT plan exists. Stop.sh denies session end. Review evidence (review.md) required for APPROVED status in autonomous_formal.

## Documentation — Part of the Deliverable
Docs ship with code, not after merge. Before creating a PR:
1. Check freshness: `bash .agentic/lib/tools/docs.sh --check-freshness --trigger feature_done --manifest F-XXXX`
2. Update each stale doc relevant to the feature
3. Include doc changes in the same PR as code
`ag done` enforces `docs_gate` (blocking in formal profiles) — but that's the safety net, not the trigger.

## Rules
- Follow CLI prompts. It loads role-specific guidance at each phase.
- Write artifacts to `.agentic/work/F-XXXX/` (plan.md, spec.md, review.md, journal.md).
- Use token-efficient scripts: `journal.sh`, `status.sh`, `feature.sh`, `blocker.sh`, `todo.sh`.
- After code changes, grep `spec/contracts/` for affected assertions. If any, STOP and present to user before modifying contracts or tests. Contracts protect shipped behavior; silently updating them defeats that protection.
- NEVER write code for multiple features outside of `ag auto` commands. The `ag auto` pipeline ensures each feature gets specs, plans, tests, and docs — not just code.
- **No feature inflation**: Improvements, enforcement, and hardening of existing features are deliverables on those features — not new F-XXXX. Ask "which existing feature owns this?" before proposing a new ID.
- **Behavioral corrections belong in instruction files**: When a correction applies to this project, update CLAUDE.md or the relevant skill file — don't write a memory as a substitute.
- **Feature ID patterns are centralized**: `ids.py` (Python) and `ids.sh` (shell) are the single source of truth for feature ID regexes. Import `FEATURE_ID_RE`, `FEATURE_HEADER_RE`, etc. — never inline `F-\d{4,}` or `F-[0-9]{4,}` patterns in code.
- **Track what you build**: When `feature_tracking=yes`, update FEATURES.md. Otherwise, update OVERVIEW.md (Core Capabilities section). Claude hooks (Stop.sh, UserPromptSubmit) nudge if you write implementation code but forget to update the design doc.
- **Enforcement hierarchy**: Agent hooks (real-time, where supported: Claude hooks, Cursor hooks) > Skills (just-in-time) > ag commands (gates) > pre-commit (safety net) > instruction files (behavioral). New gates go in agent hooks, not pre-commit.

## What the Framework Enforces Structurally (you can't bypass these)
- **Spec-first**: PreToolUse denies code edits without spec+AC (formal)
- **DRAFT plan blocks code**: PreToolUse denies code edits when DRAFT plan exists (formal)
- **Shipped spec protection**: PreToolUse denies editing shipped contracts without migration (formal)
- **Destructive git blocked**: PreToolUse denies reset --hard, stash, checkout --, force push
- **Session stop gates**: Stop.sh denies with DRAFT plans, unshipped merges, branches without PR
- **Review evidence**: Plan can't be APPROVED without review.md evidence (autonomous_formal)
- **Intelligence push**: Framework auto-pushes conventions, patterns, TDD nudges at decision points (all profiles)
- **Token awareness**: PostToolUse warns on repeated reads and budget overruns
- **Doc freshness**: UserPromptSubmit nudges after 3+ impl writes with 0 doc writes
- **Batch work blocked**: UserPromptSubmit detects batch patterns, suggests ag auto crunch
