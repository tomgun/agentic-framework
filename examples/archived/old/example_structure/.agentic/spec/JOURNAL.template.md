# JOURNAL (Template)

Purpose: capture session-by-session progress so both humans and agents can resume work effortlessly, especially after context window resets or breaks.

## How to use
- Agents should append a new entry at the end of meaningful work sessions.
- Each entry captures: what was accomplished, what's next, blockers encountered.
- Keep entries concise (5-10 bullets max per session).
- This complements `STATUS.md` (high-level roadmap) with granular session-level detail.

## Format
Each entry should include:
- **Session ID/timestamp**: `YYYY-MM-DD HH:MM` or `YYYY-MM-DD-HHMM`
- **Feature/task**: which feature(s) or task(s) were worked on
- **Accomplished**: what was completed this session
- **Next steps**: immediate next actions
- **Blockers/issues**: anything that needs attention or decision

---

## Example Entry (delete this in real use)

### Session: 2025-12-31 14:30
**Feature**: F-0004 (Persistence)
**Accomplished**:
- Implemented localStorage adapter with quota handling
- Added unit tests for happy path and quota exceeded
- Updated FEATURES.md: F-0004 implementation state = partial

**Next steps**:
- Add Safari private mode fallback (in-memory storage)
- Update TECH_SPEC.md with persistence architecture
- Add integration test for full save/load cycle

**Blockers**:
- Safari private mode throws on localStorage access (not just quota) - need research on detection strategy

---

## Session Log (most recent first)

<!-- Agents: append new sessions here -->

