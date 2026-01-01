# CONTEXT_PACK.md

**Quick intent**: This is a simple CLI task manager demo using the agentic framework v0.1.0.

## Where to look first (map)

**Entry points:**
- CLI: `task_cli.py` (main entry point)
- Core logic: `task_manager.py` (business logic)
- Tests: `test_task_manager.py` (unit tests)

**Project structure:**
```
inited_project/
├── task_cli.py           # CLI interface (@feature F-0001, F-0002)
├── task_manager.py       # Core logic (@feature F-0001, F-0002, F-0003)
├── test_task_manager.py  # Unit tests
├── tasks.json            # Data storage
├── spec/                 # Requirements & features
└── agentic/              # Framework
```

## How to run / test

**Run the app:**
```bash
python task_cli.py add "Buy milk"
python task_cli.py list
python task_cli.py complete 1
```

**Run tests:**
```bash
pytest
```

## Current top priorities

1. F-0001: Add tasks ✅ (shipped)
2. F-0002: List tasks ✅ (shipped)
3. F-0003: Complete tasks ✅ (shipped)

## Architecture snapshot

**Style:** Simple CLI application with JSON persistence

**Key modules:**
- `task_manager.py`: Core business logic (add, list, complete tasks)
- `task_cli.py`: Command-line interface using argparse
- `tasks.json`: JSON file storage

**Data flow:**
```
CLI → TaskManager → JSON file
```

## Technology choices

- **Python 3.12**: Modern Python with type hints
- **pytest**: Unit testing framework (TDD)
- **JSON**: Simple file-based persistence
- **No external dependencies**: Keep it simple for demo

## Known risks / sharp edges

- JSON file must be writable
- No concurrent access handling (single-user tool)
- Task IDs are simple integers (not UUIDs)

## Onboarding cost

**Time to understand:** 10 minutes
- Read: STACK.md, spec/FEATURES.md
- Run: `pytest` then `python task_cli.py --help`
