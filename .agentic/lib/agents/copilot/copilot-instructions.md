# Copilot Instructions

You are working in a repo that uses the agentic development framework (folder: .agentic/).

Always consult: AGENTS.md (if present), CONTEXT_PACK.md, .agentic/STATUS.md, .agentic/spec/* as the source of truth.

## Workflow

All work is managed by `ag` commands. The CLI enforces the workflow — never skip steps.

- `ag start F-XXXX "Title"` — begin a new feature
- `ag transition F-XXXX <state>` — advance the workflow (checks artifacts before proceeding)
- `ag check F-XXXX` — validate artifacts
- `ag verify F-XXXX` — run tests and record results
- `ag done F-XXXX` — post-merge: doc gate, VERSION bump, state flush
- `ag status` — see current work items
- `ag info F-XXXX` — detailed info with next steps
- `ag commit` | `ag commit --skip-gate "<reason>"` (audited Tier 0 bypass) | `ag done` | `ag merge <pr#> [F-XXXX]` | `ag flush` | `ag backlog` | `ag todo`
- `ag push [args...]` | `ag push --skip-gate "<reason>"` — sanctioned wrapper (R-002 pre-push gate records via breadcrumb)
- `ag tui` — Textual mission-control dashboard live-tailing events.jsonl / delegation.jsonl / token-ledger.jsonl (R-008; needs `pip install textual`)
- `ag watch [--filter k=v] [--since 1h] [--from-start] [--once]` — color-coded events.jsonl tail for SSH (R-009); stdlib only
- `ag fix "<reason>"` — hotfix-mode commit (R-010): skips spec-existence + plan-approval, keeps tests/journal/migrations/integrity
- `ag intel report --quota` — Pro/Max session usage in last 5h: per-tier/per-model breakdown, alerts at 70/85/95% (R-013)
- `ag onboard` — generate `.agentic/ONBOARDING.md` for new contributors (R-011)
- `ag phase list F-XXXX` | `ag phase done F-XXXX <id>` | `ag phase active` | `ag phase sync`
- `ag auto task F-XXXX` | `ag auto epic F-XXXX` | `ag auto verify` | `ag auto crunch`
- `ag persona list` | `ag persona check` | `ag persona coverage` | `ag persona generate` | `ag persona migrate`
- `ag coord start` | `ag coord stop` | `ag coord status`
- `ag mcp start` | `ag mcp status` — MCP coordination server (task delegation + multi-agent)

Write artifacts to `.agentic/work/F-XXXX/`: `plan.md`, `spec.md`, `review.md`, `journal.md`, `verification.json`. The CLI tells you what's missing.

Decision routing: current state → OVERVIEW.md, work log with reasoning → JOURNAL.md (use `--decision` to mark choices), ADR for significant tradeoffs (formal), user preferences → `ag intel remember`.

STOP! Trigger Words (match on intent, not just exact words):
| User intent | Action |
|-------------|--------|
| Build / implement / add / create | STOP -> `ag start F-XXXX "Title"`, write plan, then `ag transition F-XXXX implementation` |
| Build something large (>10 files) | STOP -> TOO BIG. Break into 3-5 smaller tasks. |
| Fix / debug / repair / troubleshoot | STOP -> Write failing test FIRST |
| Commit / push / ship / finalize | STOP -> Run `ag commit` |
| Done / complete / finished / merge | STOP -> Run `ag done F-XXXX`. Flush ideas via `ag todo`. |
| Idea / remember / todo / note | STOP -> `ag todo "description"` |
| Backlog / what's next / prioritize | STOP -> `ag backlog` to see queue |
| Write spec / contract / acceptance criteria | STOP -> Run `ag spec F-XXXX` or `ag contract check F-XXXX` |
| Decompose / break down epic | STOP -> Run `ag decompose F-XXXX` |
| Phase done / mark phase / phase progress / which phase | STOP -> Run `ag phase list F-XXXX` to see phases. `ag phase done F-XXXX <id>` to mark complete. |
| Pending user input / contract input | STOP -> Run `ag contract pending`. Process each pending contract. |
| Migrate specs / convert acceptance | STOP -> Run `ag migrate-specs` (converts markdown ACs to YAML contracts). |
| Plan created / exited plan mode | STOP -> Save plan, run dialectical review if `plan_review_enabled: yes`, then implement |
| Churn / batch / all tasks / build everything | STOP -> Run `ag auto crunch`. NEVER write code for multiple features outside `ag auto`. |
| User preference / correction / decision (recognize semantically) | `ag intel remember "..." --type preference\|learning\|decision --context "..."` |
| Before planning / spec / implementing / testing | Run `ag intel architecture\|spec\|implement\|test [F-XXXX]` for phase-aware quality guidance |

## Rules

- Never auto-commit in interactive sessions. Show changes to human first. After every commit/push, state the short hash, branch, and one-line summary.
- PR by default: create feature branches and PRs (check `git_workflow` in STACK.md).
- Add/update tests for new/changed logic. Write tests alongside code.
- Spec + code + tests + docs = done (update all artifacts together).
- Keep changes small and scoped (max 5-10 files per commit).
- Multi-session safety: never run destructive git ops when other sessions may be active.
- NEVER write code for multiple features outside of `ag auto` commands. Batch work → `ag auto crunch`.
- No feature inflation: improvements/enforcement/hardening of existing features are deliverables on those features, not new F-XXXX.

Token-efficient scripts (ALWAYS use these, NEVER edit state files directly):
- STATUS.md: `bash .agentic/lib/tools/status.sh focus "Task"`
- JOURNAL.md: `bash .agentic/lib/tools/journal.sh "Topic" "Outcomes" "Next" "Blockers" --why "Problem"`
- HUMAN_NEEDED.md: `bash .agentic/lib/tools/blocker.sh add "Title" "type" "Details"`
- FEATURES.md: `bash .agentic/lib/tools/feature.sh cap add "Name" "Description"` or `feature.sh cap status "Name" built`
- TODO.md: `bash .agentic/lib/tools/todo.sh add "Idea"` or `ag todo "Idea"`

Enforcement hierarchy: Agent hooks (real-time, where supported) > Skills (just-in-time) > ag commands (gates) > pre-commit (safety net) > instruction files (behavioral).
