# Task Board - Example Project

This folder demonstrates using the Agentic Framework in **Core mode** (no formal product management).

## What This Shows

- ✅ `OVERVIEW.md` - Lightweight planning (what's done, what's next)
- ✅ `STACK.md` - Tech stack and how to run
- ✅ `CONTEXT_PACK.md` - Architecture overview
- ✅ `JOURNAL.md` - Session history
- ✅ Code with `@feature` annotations
- ✅ Unit tests with pytest
- ❌ No `STATUS.md` or formal `spec/` - simpler workflow

## Running the Example

```bash
# Check project health
python3 .agentic/tools/doctor.py

# View product status
cat OVERVIEW.md

# See recent work
tail -20 JOURNAL.md
```

## Key Files

- `OVERVIEW.md` - What we're building (lightweight, checkboxes)
- `STACK.md` - Python 3.12, pytest, no dependencies
- `CONTEXT_PACK.md` - Simple CLI architecture
- `JOURNAL.md` - MVP session logged
- `todo_cli/` - Implementation with `@feature` annotations
- `tests/` - Unit tests

## For Agents

This project uses **Core** profile (no formal PM). When resuming work:

1. Read `OVERVIEW.md` to understand what's built and what's next
2. Read `CONTEXT_PACK.md` for architecture
3. Read recent `JOURNAL.md` entries
4. Ask user: "Which capability from OVERVIEW.md should I work on?"

No `STATUS.md` or feature IDs - just build what the user asks for.

