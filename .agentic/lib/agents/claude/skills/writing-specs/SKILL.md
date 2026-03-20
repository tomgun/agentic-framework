---
name: writing-specs
description: >
  Spec-writing workflow: create new specs, update planned/in-progress specs,
  evolve shipped specs with contract protection. Handles NFR integration,
  delta tracking via migrations, and spec health checks.
  Use when user says "write spec", "create spec", "add acceptance criteria",
  "update spec", "evolve spec", "spec for F-XXXX", "ag spec", "mark shipped",
  "feature status", "ag specs", "add feature to FEATURES.md", "track this feature".
  Do NOT use for: implementing features (use implementing-features),
  planning architecture (use planning-features).
compatibility: "Requires Claude Code with file access and ag commands."
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
metadata:
  author: agentic-framework
  version: "${VERSION}"
---
# Writing Specs

Run `ag spec` to manage feature specifications and acceptance criteria.

## Key operations
- **New feature**: Find next F-XXXX in FEATURES.md, create acceptance file from template, create migration
- **Status update**: `bash .agentic/lib/tools/feature.sh F-XXXX status shipped`
- **Evolve shipped spec**: Additive-only changes, markers required, migration mandatory, human approval
- **Audit**: `bash .agentic/lib/tools/check-spec-health.sh F-XXXX` (or `--all`)

## Rules
- Shipped specs are contracts — never delete existing criteria
- Use markers: `[Discovered]`, `[Revised in M-NNN: was "X" now "Y"]`
- Always create migration for shipped spec changes: `bash .agentic/lib/tools/migration.sh create "reason"`
- Check NFRs: `bash .agentic/lib/tools/nfr-applicable.sh F-XXXX`
- Template: `.agentic/spec/acceptance.template.md`
