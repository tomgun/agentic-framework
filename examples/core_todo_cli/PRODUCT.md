# PRODUCT.md

Purpose: what we're building, what's done, and what's next. No ceremony, no IDs, just shared context for humans + agents.

## What we're building
A simple command-line todo manager for developers. No database, no web UI - just fast, keyboard-driven task management that stores todos in a local JSON file.

## Core capabilities
- [x] User can add tasks with description
- [x] User can list all tasks
- [x] User can mark tasks as done
- [ ] User can filter by status (done/pending)
- [ ] User can delete tasks
- [ ] User can edit task descriptions
- [ ] System persists tasks to JSON file

## Technical approach
- Stack: Python 3.12, no external dependencies for MVP
- Architecture: Simple CLI with argparse command dispatch
- Key decisions:
  - JSON for storage (human-readable, easy debugging, no DB needed)
  - Colorama for terminal colors (optional, degrades gracefully)
  - XDG_DATA_HOME for storage location (~/.local/share/todo-cli/)

## In scope (for now)
- Basic CRUD operations for tasks
- File-based persistence
- Colored terminal output
- Cross-platform (Linux, macOS, Windows)

## Out of scope (for now)
- Cloud sync
- Multiple users
- Categories/tags
- Due dates
- Priority levels
- Web UI

## Rough phases
1. **MVP** ✅: Add/list/done commands, JSON storage (DONE)
2. **Next**: Filter, delete, edit commands
3. **Later**: Categories, priorities, due dates
