# Development loop (agent-friendly)

Goal: ship in **small, test-backed increments** while keeping `STATUS.md` and specs trustworthy.

## Loop
1. **Pick work**
   - Start from `STATUS.md` (current focus / next up).
   - Choose one small, testable task (create `/spec/tasks/...` if useful).
2. **Clarify acceptance**
   - Ensure acceptance criteria exist (PRD/Tech Spec or task doc).
   - If unclear, ask before coding.
3. **Plan the change**
   - Identify minimal files to touch.
   - Identify tests to add/adjust.
4. **Implement**
   - Keep diffs small.
   - Create seams for testability.
5. **Test**
   - Add/update unit tests (required).
   - Add domain/acceptance tests where relevant.
6. **Review yourself**
   - Use `agentic/quality/review_checklist.md`.
7. **Update docs**
   - Update `STATUS.md` (always).
   - Update specs/ADRs if behavior/architecture changed.
   - Append session summary to `JOURNAL.md` (what was done, what's next, blockers).

## Token efficiency rules
- Prefer updating `CONTEXT_PACK.md` over re-reading the whole repo repeatedly.
- When starting a new session after a break, read:
  1) `CONTEXT_PACK.md`
  2) `STATUS.md`
  3) `JOURNAL.md` (recent entries for session-level context)
  4) the relevant spec section(s)

## Resuming after context reset
- If context window resets mid-implementation:
  - Check `STATUS.md` "Current session state" section for immediate context
  - Check recent `JOURNAL.md` entries for detailed progress trail
  - Continue from "Next immediate step" rather than re-planning from scratch


