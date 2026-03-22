# GitHub Copilot Instructions - Framework Development

THIS IS FRAMEWORK DEVELOPMENT. You are working ON the agentic framework itself, not a project using it. Framework changes affect ALL users - extra care required.

Read first: `FRAMEWORK_QUICK_START.md`, `FRAMEWORK_DEVELOPMENT.md`, `.agentic/lib/PRINCIPLES.md`

Full template: `.agentic/lib/agents/copilot/copilot-instructions.md`

Always consult: AGENTS.md (if present), CONTEXT_PACK.md, .agentic/STATUS.md, .agentic/spec/* and .agentic/spec/adr/* as the source of truth.

## Workflow

All work is managed by `ag` commands. The CLI enforces the workflow — never skip steps.

- `ag start F-XXXX "Title"` — begin a new feature
- `ag transition F-XXXX <state>` — advance the workflow (checks artifacts)
- `ag check F-XXXX` | `ag verify F-XXXX` | `ag ship F-XXXX` | `ag status` | `ag info F-XXXX`
- `ag commit` | `ag done` | `ag merge <pr#> [F-XXXX]` | `ag flush` | `ag backlog` | `ag todo`
- `ag auto task F-XXXX` | `ag auto epic F-XXXX` | `ag auto verify` | `ag auto crunch`

Write artifacts to `.agentic/work/F-XXXX/`: `plan.md`, `spec.md`, `review.md`, `journal.md`, `verification.json`.

STOP! Trigger Words (match on intent, not just exact words):
| User intent | Action |
|-------------|--------|
| Build / implement / add / create | STOP -> `ag start F-XXXX "Title"`, write plan, then `ag transition F-XXXX implementation` |
| Build something large (>10 files) | STOP -> TOO BIG. Break into 3-5 smaller tasks. |
| Fix / debug / repair / troubleshoot | STOP -> Write failing test FIRST |
| Commit / push / ship / finalize | STOP -> Run `ag commit` |
| Done / complete / finished / merge | STOP -> Run `ag done F-XXXX`. Flush ideas via `ag todo`. |
| Idea / remember / todo / note | STOP -> `ag todo "description"` |
| Decompose / break down epic | STOP -> Run `ag decompose F-XXXX` |
| Plan created / exited plan mode | STOP -> Save plan, run dialectical review if enabled, then implement |
| Churn / batch / all tasks / build everything | STOP -> Run `ag auto crunch`. NEVER write code for multiple features outside `ag auto`. |

## Rules

- Never auto-commit in interactive sessions. Show changes to human first.
- PR by default: create feature branches and PRs (check `git_workflow` in STACK.md).
- Add/update tests for new/changed logic. Write tests alongside code.
- Spec + code + tests + docs = done (update all artifacts together).
- Keep changes small and scoped (max 5-10 files per commit).
- Every merge: bump VERSION via `ag done`. Update CONTRIBUTIONS.md during the PR.
- Multi-session safety: never run destructive git ops when other sessions may be active.
- NEVER write code for multiple features outside of `ag auto` commands. Batch work → `ag auto crunch`.

Token-efficient scripts (ALWAYS use these, NEVER edit state files directly):
- STATUS.md: `bash .agentic/lib/tools/status.sh focus "Task"`
- JOURNAL.md: `bash .agentic/lib/tools/journal.sh "Topic" "Done" "Next" "Blockers" --why "Reason"`
- HUMAN_NEEDED.md: `bash .agentic/lib/tools/blocker.sh add "Title" "type" "Details"`
- TODO.md: `bash .agentic/lib/tools/todo.sh add "Idea"` or `ag todo "Idea"`

---

## Framework Development

Validation: `bash tests/validate_framework.sh` must pass before committing.
New features: Add to `.agentic/spec/FEATURES.md` FIRST, create YAML contract at `spec/contracts/F-XXXX.yaml` before coding.
Breaking changes: Provide upgrade path in `upgrade.sh`.
Instruction files are part of the feature: new `ag` commands/gates MUST update all instruction files (templates, skills, memory-seed, DEVELOPER_GUIDE, HOW_IT_WORKS).
