# Context budgeting (token efficiency)

## Principle
Context is expensive. Maintain **durable artifacts** so agents don’t repeatedly re-ingest the repo.

## Durable context (authoritative)
- `CONTEXT_PACK.md`: where to look, how to run, architecture snapshot
- `STATUS.md`: what’s happening now and what’s next
- `STACK.md`: how to build/test and key constraints
- `/spec/*` and `spec/adr/*`: what and why

## "Start of session" protocol
Read in this order:
1. `CONTEXT_PACK.md`
2. `STATUS.md`
3. `JOURNAL.md` (recent entries for session-level context)
4. The relevant spec section(s) in `/spec/`
5. Only then: open code files

Detailed token budgeting: see `.agentic/token_efficiency/reading_protocols.md`

## “Before coding” protocol (avoid token waste)
- Restate the change in 1–3 bullets.
- Identify the minimal files to touch.
- Identify the tests to add/adjust.

## Summarize instead of scrolling
If you have to open a large file, write a 5–10 line summary into:
- `CONTEXT_PACK.md` (if broadly useful), or
- the task doc (if specific)


