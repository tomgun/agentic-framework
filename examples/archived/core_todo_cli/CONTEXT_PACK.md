# CONTEXT_PACK.md

Purpose: durable context for agents. Read this first when resuming work.

## What this is
A minimal command-line todo manager. No frills, no dependencies (except optional colorama for colors). JSON storage, fast, keyboard-driven.

## Architecture (high level)
```
todo_cli/
├── __main__.py       # Entry point, CLI dispatch
├── commands/         # Command handlers (add, list, done, etc.)
│   ├── add.py
│   ├── list.py
│   └── done.py
├── storage.py        # JSON file read/write
└── models.py         # Task dataclass

tests/
├── test_storage.py
├── test_commands.py
└── integration/
    └── test_cli.py
```

## Key design decisions
1. **No database**: JSON file is enough for personal task management
2. **Single file storage**: All tasks in one JSON file, loaded on every command (acceptable for <1000 tasks)
3. **No categories/tags in MVP**: Keep it simple, add later if needed
4. **XDG_DATA_HOME**: Follows XDG Base Directory spec on Linux/macOS, uses AppData on Windows

## How to run
```bash
# Development
python -m todo_cli add "My task"
python -m todo_cli list
python -m todo_cli done 1

# Tests
pytest tests/ -v
```

## Current state
- ✅ MVP complete: add, list, done commands work
- ✅ JSON storage implemented
- ✅ Tests passing
- ⬜ Filter command (next)
- ⬜ Delete/edit commands (after filter)

## Gotchas / lessons
- JSON file must be created atomically (use temp file + rename to avoid corruption)
- Task IDs are 1-indexed for user-friendliness (but 0-indexed internally)
- Colorama is optional: gracefully degrade if not installed

## Where things are
- Entry point: `todo_cli/__main__.py`
- Command handlers: `todo_cli/commands/`
- Storage logic: `todo_cli/storage.py`
- Data model: `todo_cli/models.py`
- Tests: `tests/`
