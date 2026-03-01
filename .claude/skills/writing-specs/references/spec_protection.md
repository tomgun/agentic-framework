---
summary: "Shipped spec contract rules: what agents can and cannot do"
tokens: ~600
---

# Spec Protection Rules

## What "Shipped" Means

A shipped feature's acceptance criteria are a **contract**. They document what works and how it was verified. Modifying them risks breaking features that users rely on.

## What Agents CAN Do

- Add `[Discovered]` criteria (new requirements found during related work)
- Add new tests that verify existing criteria more thoroughly
- Add NFR references linking the feature to non-functional requirements
- Add `[Future]` markers for enhancement ideas

## What Agents CANNOT Do

- Delete existing acceptance criteria
- Weaken test expectations (e.g., relaxing error handling checks)
- Modify existing shipped expectations without justification + migration
- Downgrade feature status from shipped (blocked by pre-commit Check 16)
- Delete test files referenced by shipped features (blocked by Check 15)

## Marker System

| Marker | Purpose | Example |
|--------|---------|---------|
| `[Discovered]` | New criteria found during implementation | `- [ ] [Discovered] Rate limit: Max 5 attempts/10min` |
| `[Revised in M-NNN: was "X" now "Y"]` | Correcting an existing criterion (preserves old text) | `- [ ] [Revised in M-005: was "5s timeout" now "10s timeout"] API timeout` |
| `[Future]` | Enhancement idea, not yet implemented | `- [ ] [Future] Support OAuth login` |

## How Tests Lock Acceptance Criteria

Test files referenced in a shipped feature's `## Tests` section cannot be deleted (pre-commit Check 15). This ensures that shipped acceptance criteria remain verifiable.

## Pre-Commit Enforcement

| Check | What | Result |
|-------|------|--------|
| 14 | Shipped spec acceptance file modified without migration | BLOCKED |
| 15 | Test file deleted when referenced by shipped feature | BLOCKED |
| 16 | Shipped feature status downgraded | BLOCKED |

These gates have **no escape hatch** by design. If a modification is needed, create a migration documenting the change with `bash .agentic/tools/migration.sh create "Evolve F-XXXX: [reason]"`.
