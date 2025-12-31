# Agent operating guidelines (shared)

These rules are intended to be used by **any** assistant (Cursor, Copilot, Claude, etc.) working in this repo.

## Developer UX contract (keep the user “by the hand”)
- Always make the next step obvious. End each work session with:
  - what changed (1–5 bullets)
  - what to do next (1–5 bullets)
  - what you need from the user (questions/decisions)
- Don’t rely on user memory. When appropriate, suggest running:
  - `bash agentic/tools/brief.sh` (quick context)
  - `bash agentic/tools/report.sh` (what’s missing / what needs acceptance)
  - `bash agentic/tools/sync_docs.sh` (system docs scaffolding)
- When the user asks to start/init the project, prefer to run the scripts yourself (with the user’s consent) rather than asking them to run commands.
- If the user returns after a break, proactively propose a resume protocol:
  - read `CONTEXT_PACK.md`, then `STATUS.md`, then relevant feature acceptance docs.

## Non-negotiables
- **Follow the spec workflow**: treat `/spec/*`, `spec/adr/*`, `STATUS.md`, `STACK.md`, `CONTEXT_PACK.md` as authoritative.
- **Keep feature truth current**: if you change a feature’s behavior/status/tests, update `spec/FEATURES.md` and the relevant acceptance file(s).
- **Keep NFR truth current**: if your change affects cross-cutting constraints (perf/security/realtime/reliability), update `spec/NFR.md` and link relevant NFR IDs from the feature(s).
- **Tests are required** for new/changed logic.
  - If a feature needs acceptance/integration/perf tests (domain-specific), add them or record a concrete follow-up task.
- **Keep the repo truthful**:
  - update `STATUS.md` after meaningful progress
  - update specs when behavior changes
  - write ADRs for real tradeoffs

## Before you edit code
- Read (minimum): `CONTEXT_PACK.md`, `STATUS.md`, `spec/OVERVIEW.md`, `spec/FEATURES.md`.
- If the change touches a specific feature: read its acceptance file `spec/acceptance/F-####.md`.
- If constraints matter: read `spec/NFR.md`.
- Identify the relevant spec section(s) and acceptance criteria.
- Propose a small plan and the tests you will add/adjust.
- If requirements are ambiguous, ask before coding.

## While implementing
- Keep diffs small and incremental.
- Prefer seams and boundaries that enable unit tests.
- Avoid speculative changes outside the task scope.

## After implementing
- Run the relevant tests (or describe what would be run and why you couldn’t).
- Self-review using `agentic/quality/review_checklist.md`.
- Update `STATUS.md` and any relevant docs.
- For the affected feature(s), update `spec/FEATURES.md`:
  - mark implementation/test status truthfully
  - set `Accepted: yes` only when the change meets acceptance criteria and you verified it works in practice

## Token efficiency
- Start sessions by reading `CONTEXT_PACK.md` then `STATUS.md`.
- When you learn something important, capture it in `CONTEXT_PACK.md` so the next session is cheaper.


