---
name: exploring-codebase
description: >
  Navigate and understand codebase structure, find files, trace dependencies.
  Use when user says "find", "where is", "explore", "show me", "what files",
  "how does this work", "codebase structure", or asks about code location.
  Do NOT use for: modifying code (use implementing-features), reviewing
  changes (use reviewing-code), web research (use researching-topics).
compatibility: "Requires Claude Code with file access."
allowed-tools: [Read, Glob, Grep, Bash]
metadata:
  author: agentic-framework
  version: "0.62.0"
---
# Exploring Codebase

Read-only codebase navigation. No ag command needed — use tools directly.

- **File by name**: `Glob` with pattern (e.g., `**/*.test.js`)
- **Code by content**: `Grep` with pattern (e.g., `function calculateTotal`)
- **Structure overview**: `ls` key directories
- **Dependency tracing**: Read import/require statements

Start broad, then narrow. Check `CONTEXT_PACK.md` for "Where to look first."
