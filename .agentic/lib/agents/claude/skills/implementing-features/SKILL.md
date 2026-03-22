---
name: implementing-features
description: >
  Implements features using contract-driven workflow with structural gates.
  Use when user says "build", "implement", "add feature", "create [thing]",
  "implement F-XXXX", "ag implement", or describes new functionality to build.
  Do NOT use for: one-line fixes (use fixing-bugs), writing tests only
  (use writing-tests), code review (use reviewing-code), documentation-only
  changes (use updating-documentation).
compatibility: "Requires Claude Code with shell access and ag commands."
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, Agent]
metadata:
  author: agentic-framework
  version: "${VERSION}"
---
# Implementing Features

Run `ag start F-XXXX "Title"` to begin, then follow the CLI prompts.
The CLI checks artifacts, enforces transitions, and emits role-specific guidance.

Key commands:
- `ag start F-XXXX "Title"` — create work item, begin planning
- `ag transition F-XXXX <state>` — advance when artifacts ready
- `ag check F-XXXX` — see what's missing
- `ag verify F-XXXX` — run tests
- `ag ship F-XXXX` — prepare to ship
