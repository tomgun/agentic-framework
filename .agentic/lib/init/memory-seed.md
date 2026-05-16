# Memory Seed — Agentic Framework
<!-- memory-seed v0.85.2 -->
<!-- Bump this marker whenever the seed changes. memory-check.sh diffs against the
     commit that introduced the version line, so the marker MUST land in a commit
     that also contains the substantive seed changes. -->

All work is managed by `ag` commands. The CLI enforces the workflow — never skip steps.

<!-- section: key-commands -->
## Key Commands
- `ag start F-XXXX "Title"` — begin feature (creates work item, starts planning)
- `ag transition F-XXXX <state>` — advance workflow (checks artifacts first)
- `ag check F-XXXX` — see what's missing for next transition
- `ag verify F-XXXX` — run tests and record results
- `ag done F-XXXX` — post-merge: doc gate, VERSION bump, state flush
- `ag status` — see current work items
- `ag commit` | `ag commit --skip-gate "<reason>"` (audited Tier 0 bypass) | `ag push` | `ag push --skip-gate "<reason>"` | `ag fix "<reason>"` (R-010 hotfix mode) | `ag tui` (Textual mission control) | `ag watch` (R-009 events.jsonl tail) | `ag intel report --quota` (R-013 Pro/Max usage) | `ag intel report --tokens` (R-101 per-session + rolling-30) | `ag onboard` (R-011 new-contributor playbook) | `ag done` | `ag todo` | `ag backlog` | `ag git-init` | `ag contract` | `ag phase` | `ag persona` | `ag skills`

Decision routing: current state → OVERVIEW.md, work log with reasoning → JOURNAL.md (use `--decision` to mark choices), ADR for significant tradeoffs (formal), user preferences → `ag intel remember`.

<!-- section: trigger-words -->
## Trigger Words
- "phase done/mark phase/phase progress/which phase" → STOP. Run `ag phase list F-XXXX` to see phases, `ag phase done F-XXXX <id>` to mark complete.
- "pending user input/contract input" → STOP. Run `ag contract pending`. Process each pending contract.
- "contract/assertion/verify contract/check contract" → Run `ag contract check` or `ag contract list`. Contracts are in `spec/contracts/F-XXXX.yaml`.
- "promote/unshipped/planned assertions" → Run `ag contract promote F-XXXX` to promote planned assertions to shipped. Promote chmods the file to `444` (R-005); after that, direct `Edit`/`Write` returns EACCES.
- "EACCES on contract / can't edit shipped contract / contract is read-only / chmod 444" → STOP. Shipped contracts are filesystem-locked (R-005). Use `ag contract migrate F-XXXX --reason "<text>" [--trigger TYPE] [--set KEY=VALUE | --add-assertion "<text>" [--type T]]` — the only sanctioned mutation path. It records an auditable migration entry and re-locks the file.
- "gate blocked / pre-commit BLOCKED / pre-push BLOCKED / what does this mean / why won't it commit" → Read the printed `suggested next steps` (R-012); each blocked check has 1–3 concrete commands. For expanded explanations + plan refs, re-run with `--verbose`: `python3 .agentic/lib/hooks/precommit_gate.py --verbose` (or `prepush_gate.py --verbose`).
- "hook tampering / integrity baseline / integrity check failed / why is precommit_gate.py being baselined" → STOP. R-004 baselines hook + agent + .claude config to detect tampering. Run `ag integrity status` to see mismatches; `ag integrity update` regenerates the baseline (audited). Don't bypass with `INTEGRITY_SKIP=1` outside CI — it's ignored locally on purpose.
- "merge branch / local merge / git merge into main / merge feature branch locally" → STOP. Use `ag merge <branch>` (R-003), not raw `git merge`. The local merge gate checks contract assertions, pending user_input, FEATURES.md tracking, and CI mirror status before running `git merge --no-ff`. `ag merge <pr-number>` (digits-only) still routes to the GitHub PR-merge path. Sanctioned bypass: `ag merge <branch> --skip-gate "<reason>"` (audited).
- "hotfix / quick fix / emergency fix / can't write a spec for this" → Use `ag fix "<reason>"` (R-010). It sets `AGENT_FIX_MODE=1` so the precommit gate skips spec-existence + plan-approval checks; tests, journal freshness, integrity, and shipped-contract migrations are still enforced. Emits a `hotfix_commit` event and tags the commit with `[hotfix]`. For emergencies only — recurring use means the affected feature needs a real spec.
- "watch events / tail events / live event stream / what's happening now" → `ag watch` (R-009). Color-coded `tail -f` of `events.jsonl`. `--filter type=commit` / `--filter feature=F-008`, `--since 1h` / `--since 2026-04-26`, `--from-start` to replay. Stdlib only — works in any SSH session where TUI is too heavy.
- "quota / Pro/Max usage / am I burning quota / 5h window / token consumption" → `ag intel report --quota` (R-013). Reads `token-ledger.jsonl`, shows last-5h usage vs `quota_pro_max_window_tokens` (set in STACK.md), per-tier and per-model breakdown, alerts at 70/85/95% with concrete advice ("pause Tier 3 / --teams"). `--json` for tooling.
- "tokens per session / which feature is burning tokens / rolling token usage / how much did this session cost / session-over-session" → `ag intel report --tokens` (R-101). Same `token-ledger.jsonl` source, but a per-session view: highlights current session, rolls last 30, and breaks down by tier/model/feature. The Stop hook + SessionStart recovery write per-turn records automatically (with feature attribution from gitBranch / AGENTS.json), so the view is populated as you work. Also visible as a second line in `ag tui`'s header below the R-014 quota ring.
- "new contributor / onboarding / where do I start / first commit / playbook" → `ag onboard` (R-011). Generates `.agentic/ONBOARDING.md` from STACK/FEATURES/STATUS/journal/ADR including a 5-minute "make your first commit" walkthrough. `--force` to regenerate. Hand-edit the People / channels section.
- "CI mirror / GitHub Actions enforcement / branch protection / belt-and-suspenders" → R-006 ships `.agentic/lib/init/templates/.github/workflows/agentic-gate.yml`. Optional. Copy to `.github/workflows/` and commit. See `docs/CI_MIRROR.md` for threat model + setup. Mirror runs precommit_gate + prepush_gate in `--ci-mode`; PR comment on failure only.
- "migrate specs/convert acceptance/markdown to yaml" → STOP. Run `ag migrate-specs` (add `--dry-run` to preview, `--archive` to move old files).
- "churn/batch/all tasks/build everything/implement everything/do all features" → STOP. Run `ag auto crunch`.
- "delegate/fresh context/context optimization/subagent" → MCP task delegation via `ag mcp start`. Use `list_acs` → `get_delegation_prompt` → Agent tool → `save_progress` → `get_next_action` loop.
- "protected branch/can't push to main/push rejected" → Check `main_branch_mode` in STACK.md. If not set, suggest `ag set main_branch_mode protected`. When protected, `ag flush` creates a branch + PR instead of direct push.
- "work autonomously/come back with working/finish everything/do it all" → STOP. Run `ag auto crunch`.
- User preferences/corrections/decisions: When the user expresses a preference, corrects your approach, or makes a decision, capture with `ag intel remember "..." --type preference|learning|decision --context "..."`. Recognize these semantically — don't wait for keywords. Project-scoped (project-memory.yaml), NOT Claude's local MEMORY.md. For write-time enforcement: `ag intel learn "..." --reason "user instruction" --scope "*"`.
- Proposing a choice: Before presenting a recommendation, write: `echo "Use Redis for caching" > .agentic/session/pending-decision.txt`. Framework detects "yes/ok" and advises capture.
- "intelligence/patterns/quality checks" → Run `ag intel` subcommands (check, learn, remember, patterns, memory, decisions, review-session).
- "quality check/quality profile/stack quality/quality validation/quality setup" → Run `ag quality setup` (generate profile from detected stack), `ag quality run` (run checks), `ag quality status` (show profile). Stack knowledge in `.agentic/lib/quality_knowledge/`.
- "skills marketplace/install community skill/recommended skill/skill for stack" → Run `ag skills suggest` (matches against detected stack), `ag skills install --all` (interactive install with sha pinning + script quarantine), `ag skills sync` (reconcile installed vs current stack). Allowlist at `.agentic/lib/data/skills-marketplace.yaml`. Built-in F-008 quality_knowledge takes precedence (`--override-builtin` to bypass).
- Before workflow phases: run `ag intel architecture` (planning), `ag intel spec F-XXXX` (specs), `ag intel implement F-XXXX` (coding), `ag intel test F-XXXX` (testing) for phase-aware quality guidance.
- NEVER write code for multiple features outside of `ag auto` commands.
- **Wrong rationalizations:** "I can do it directly faster" — NO. "User said autonomous = skip ceremony" — NO. Autonomous means use the autonomous pipeline, not bypass it.
- "memory: stale / `PATCH N/N` output / memory check produced patches / sectioned diff for MEMORY.md" → STOP. The advisory `memory-check.sh` emits structured `PATCH N/N — ADD|REMOVE|MODIFY section "..."` blocks when the seed has drifted from your auto-memory. Apply each PATCH block to your `MEMORY.md`: `MODIFY` blocks contain unified-diff `-`/`+` lines you map directly to `Edit` calls (`old_string` from `-` lines, `new_string` from `+` lines); `ADD` blocks insert a new section; `REMOVE` blocks delete one. Preserve project-specific entries outside framework sections.

<!-- section: after-plan-mode -->
## After Plan Mode Exits — Auto-Continue (do NOT stop)
Exiting plan mode creates a DRAFT. The framework BLOCKS code edits and session stop until resolved. Auto-continue immediately:
1. Save plan to `.agentic/journal/plans/YYYY-MM-DD-F-XXXX-plan.md` with `**Status**: DRAFT` (injected automatically)
2. Spawn Critic + Advocate agents in parallel (fresh context) for dialectical review
3. Save review to `.agentic/work/F-XXXX/review.md` (required — framework checks for evidence)
4. If converged → set `**Status**: APPROVED`; if not → revise plan
5. After APPROVED → run `ag transition F-XXXX implementation`
**Enforcement**: PreToolUse denies code edits when DRAFT plan exists. Stop.sh denies session end. Review evidence (review.md) required for APPROVED status in autonomous_formal.

<!-- section: documentation -->
## Documentation — Part of the Deliverable
Docs ship with code, not after merge. Before creating a PR:
1. Check freshness: `bash .agentic/lib/tools/docs.sh --check-freshness --trigger feature_done --manifest F-XXXX`
2. Update each stale doc relevant to the feature
3. Include doc changes in the same PR as code
`ag done` enforces `docs_gate` (blocking in formal profiles) — but that's the safety net, not the trigger.

<!-- section: rules -->
## Rules
- Follow CLI prompts. It loads role-specific guidance at each phase.
- Write artifacts to `.agentic/work/F-XXXX/` (plan.md, spec.md, review.md, journal.md).
- Use token-efficient scripts: `journal.sh`, `status.sh`, `feature.sh`, `blocker.sh`, `todo.sh`.
- After code changes, grep `spec/contracts/` for affected assertions. If any, STOP and present to user before modifying contracts or tests. Contracts protect shipped behavior; silently updating them defeats that protection.
- NEVER write code for multiple features outside of `ag auto` commands. The `ag auto` pipeline ensures each feature gets specs, plans, tests, and docs — not just code.
- **No feature inflation**: Improvements, enforcement, and hardening of existing features are deliverables on those features — not new F-XXXX. Ask "which existing feature owns this?" before proposing a new ID.
- **Don't autorecord project things to Claude auto-memory**: Auto-memory is for cross-project / per-user / per-machine context the user manages directly. Project corrections / decisions / conventions / journal-entry shape go in repo files (CLAUDE.md, the relevant skill in `.claude/skills/`, JOURNAL.md, ADRs) where every contributor and every machine sees them. Auto-memory is gitignored, single-machine, invisible to teammates.
- **Feature ID patterns are centralized**: `ids.py` (Python) and `ids.sh` (shell) are the single source of truth for feature ID regexes. Import `FEATURE_ID_RE`, `FEATURE_HEADER_RE`, etc. — never inline `F-\d{4,}` or `F-[0-9]{4,}` patterns in code.
- **Track what you build**: When `feature_tracking=yes`, update FEATURES.md. Otherwise, update OVERVIEW.md (Core Capabilities section). Claude hooks (Stop.sh, UserPromptSubmit) nudge if you write implementation code but forget to update the design doc.
- **Enforcement hierarchy** (v5 redesign): Tier 0 git-layer gates (`precommit_gate.py` + `prepush_gate.py` — fire in a process the agent doesn't manage; sanctioned bypass via `ag commit --skip-gate` / `ag push --skip-gate`, audited to events.jsonl) > Agent hooks (real-time, in-session: Claude hooks, Cursor hooks) > Skills (just-in-time) > ag commands (workflow gates) > legacy pre-commit (defense-in-depth, R-301 retires) > instruction files (behavioral). **Honest limit**: pre-commit cannot itself observe `git commit --no-verify` (the flag short-circuits hooks); pre-push catches the same range.

<!-- section: framework-enforcement -->
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
