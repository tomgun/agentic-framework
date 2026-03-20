---
name: updating-documentation
description: >
  Update documentation and README files after feature work. Use when user says
  "update docs", "write readme", "document this", "add docs", "update
  documentation", or after completing a feature that needs doc updates.
  Do NOT use for: code changes (use implementing-features), reading docs for
  understanding (use exploring-codebase).
compatibility: "Requires Claude Code with file access."
allowed-tools: [Read, Write, Edit, Glob, Grep]
metadata:
  author: agentic-framework
  version: "${VERSION}"
---
# Updating Documentation

Run `ag docs` to check doc freshness and identify what needs updating.

## Key commands
- `bash .agentic/lib/tools/docs.sh --list` — see the docs registry (STACK.md `## Docs`)
- `bash .agentic/lib/tools/drift.sh --docs` — detect staleness automatically
- `bash .agentic/lib/tools/docs.sh --validate` — registry health check

## Common updates
- README.md, CHANGELOG.md, API docs, configuration docs, architecture docs
- Code examples must be runnable, links must point to existing files
- Use `journal.sh` and `status.sh` for framework-managed state files
