# Todo CLI

A simple command-line todo manager for developers.

## Quick Start

```bash
# Add a task
python -m todo_cli add "Implement feature X"

# List tasks
python -m todo_cli list

# Mark task as done
python -m todo_cli done 1
```

## Development

```bash
# Run tests
pytest tests/ -v

# Check code quality
bash quality_checks.sh --pre-commit  # (if set up)
```

## Architecture

See `CONTEXT_PACK.md` for architecture overview.

## Current Status

- ✅ MVP complete: add, list, done commands
- ⬜ Next: filter, delete, edit commands

See `PRODUCT.md` for full roadmap and `JOURNAL.md` for session history.

