# JOURNAL.md

Purpose: session-by-session progress log. Agents and humans update this after each session.

---

## 2026-01-02 14:00

**Focus**: Initial MVP - add, list, done commands

**Accomplished**:
- Set up project structure (todo_cli/ package)
- Implemented JSON storage with atomic writes
- Created Task dataclass with id, description, done fields
- Implemented `add` command (creates task, saves to JSON)
- Implemented `list` command (shows all tasks with indices)
- Implemented `done` command (marks task as complete)
- Added unit tests for storage layer (save/load/atomic write)
- Added unit tests for commands
- Added integration test for full CLI flow
- All tests passing ✅

**Technical decisions**:
- Use dataclasses for Task model (simple, clean)
- Atomic writes via tempfile.NamedTemporaryFile + os.replace
- Task IDs start at 1 for users (more intuitive than 0)
- Colorama for colors, but optional (graceful degradation)

**Next steps**:
- Implement filter command (list --status done|pending)
- Add delete command
- Add edit command
- Add more edge case tests (empty file, corrupted JSON, etc.)

**Blockers**: None

---

## Session Template

## YYYY-MM-DD HH:MM
**Focus**: [What you're working on]

**Accomplished**:
- [What was done]

**Technical decisions**:
- [Any decisions made]

**Next steps**:
- [What to do next]

**Blockers**: [None or list issues]
