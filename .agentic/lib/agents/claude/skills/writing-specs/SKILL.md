---
name: writing-specs
description: >
  Spec-writing workflow: create new specs, update planned/in-progress specs,
  evolve shipped specs with contract protection. Handles NFR integration,
  YAML contract management, and spec health checks.
  Use when user says "write spec", "create spec", "add contract", "add acceptance criteria",
  "update spec", "evolve spec", "spec for F-XXXX", "ag spec", "ag contract",
  "mark shipped", "feature status", "ag specs", "add feature to FEATURES.md",
  "track this feature".
  Do NOT use for: implementing features (use implementing-features),
  planning architecture (use planning-features).
compatibility: "Requires Claude Code with file access and ag commands."
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
metadata:
  author: agentic-framework
  version: "${VERSION}"
---
# Writing Specs

Run `ag spec` or `ag contract` to manage feature specifications and YAML contracts.

## Key operations
- **New feature**: Find next F-XXXX in FEATURES.md, create contract at `spec/contracts/F-XXXX.yaml`
- **Contract management**: `ag contract check F-XXXX` | `ag contract coverage` | `ag contract pending` | `ag contract list`
- **Status update**: `bash .agentic/lib/tools/feature.sh F-XXXX status shipped`
- **Evolve shipped spec**: Additive-only changes, markers required, migration mandatory, human approval
- **Audit**: `bash .agentic/lib/tools/check-spec-health.sh F-XXXX` (or `--all`)

## Rules
- Shipped specs are contracts — never delete existing assertions
- Contracts are YAML files at `spec/contracts/F-XXXX.yaml` with assertions, verify commands, and test links
- Use markers: `[Discovered]`, `[Revised in M-NNN: was "X" now "Y"]`
- Always create migration for shipped spec changes: `bash .agentic/lib/tools/migration.sh create "reason"`
- Check NFRs: `bash .agentic/lib/tools/nfr-applicable.sh F-XXXX`
