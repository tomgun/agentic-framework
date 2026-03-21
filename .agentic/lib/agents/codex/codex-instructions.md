# Codex Instructions

You are working in a repo that uses the agentic development framework (folder: .agentic/).

Always consult: AGENTS.md (if present), CONTEXT_PACK.md, .agentic/STATUS.md, .agentic/spec/* as the source of truth.

Note: Codex runs commands in a sandbox. Append `|| true` to commands that may fail to prevent non-zero exit codes from halting execution.

## Workflow

All work is managed by `ag` commands. The CLI enforces the workflow — never skip steps.

- `ag start F-XXXX "Title"` — begin a new feature
- `ag transition F-XXXX <state>` — advance the workflow (checks artifacts before proceeding)
- `ag check F-XXXX` — validate artifacts
- `ag verify F-XXXX` — run tests and record results
- `ag ship F-XXXX` — prepare for shipping
- `ag status` — see current work items
- `ag info F-XXXX` — detailed info with next steps
- `ag commit` | `ag done` | `ag merge <pr#> [F-XXXX]` | `ag flush` | `ag backlog` | `ag todo`
- `ag auto task F-XXXX` | `ag auto epic F-XXXX` | `ag auto verify` | `ag auto crunch`

Write artifacts to `.agentic/work/F-XXXX/`: `plan.md`, `spec.md`, `review.md`, `journal.md`, `verification.json`. The CLI tells you what's missing.

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
| Write spec / acceptance criteria | STOP -> Run `ag spec F-XXXX` |
| Decompose / break down epic | STOP -> Run `ag decompose F-XXXX` |
| Plan created / exited plan mode | STOP -> Save plan, run dialectical review if `plan_review_enabled: yes`, then implement |
| Churn / batch / all tasks / build everything | STOP -> Run `ag auto crunch`. NEVER write code for multiple features outside `ag auto`. |

## Rules

- Never auto-commit in interactive sessions. Show changes to human first.
- PR by default: create feature branches and PRs (check `git_workflow` in STACK.md).
- Add/update tests for new/changed logic. Write tests alongside code.
- Spec + code + tests + docs = done (update all artifacts together).
- Keep changes small and scoped (max 5-10 files per commit).
- Multi-session safety: never run destructive git ops when other sessions may be active.
- NEVER write code for multiple features outside of `ag auto` commands. Batch work → `ag auto crunch`.

Token-efficient scripts (ALWAYS use these, NEVER edit state files directly):
- STATUS.md: `bash .agentic/lib/tools/status.sh focus "Task"`
- JOURNAL.md: `bash .agentic/lib/tools/journal.sh "Topic" "Outcomes" "Next" "Blockers" --why "Problem"`
- HUMAN_NEEDED.md: `bash .agentic/lib/tools/blocker.sh add "Title" "type" "Details"`
- TODO.md: `bash .agentic/lib/tools/todo.sh add "Idea"` or `ag todo "Idea"`
