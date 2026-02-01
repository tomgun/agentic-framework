# OVERVIEW.md

## What We're Building

A simple command-line todo manager for developers. No database, no web UI - just fast, keyboard-driven task management that stores todos in a local JSON file.

## Why It Matters

Developers need quick task capture without leaving the terminal. Existing solutions are either too complex (full project management) or require external services. This tool provides dead-simple task tracking with zero dependencies.

## Core Capabilities

- [x] User can add tasks with description
- [x] User can list all tasks
- [x] User can mark tasks as done
- [ ] User can filter by status (done/pending)
- [ ] User can delete tasks
- [ ] User can edit task descriptions
- [ ] System persists tasks to JSON file

## In Scope / Out of Scope

**In scope:**
- Basic CRUD operations for tasks
- File-based persistence (JSON)
- Colored terminal output
- Cross-platform (Linux, macOS, Windows)

**Out of scope (for now):**
- Cloud sync
- Multiple users
- Categories/tags
- Due dates
- Priority levels
- Web UI

## Success Looks Like

- `todo add "My task"` captures a task in under 1 second
- `todo list` shows all tasks with clear status indicators
- `todo done 1` marks task complete instantly
- Zero configuration required - works out of the box

## Guiding Principles

- **Simplicity first**: No unnecessary features or configuration
- **No external dependencies for MVP**: Just Python standard library
- **XDG compliance**: Store data in standard locations (~/.local/share/todo-cli/)
- **Graceful degradation**: Colors optional, falls back to plain text
