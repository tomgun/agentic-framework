---
summary: "Canonical spec-writing workflow with protection levels, NFR integration, delta tracking"
trigger: "write spec, create spec, add acceptance criteria, update spec, evolve spec, ag spec"
tokens: ~2500
phase: planning
---

# Spec-Writing Workflow

**Purpose**: Specs are contracts that protect working features from accidental changes. Once shipped, acceptance criteria and tests are proof it works. Modifying them requires justification and tracking.

---

## Protection Levels

| Scenario | Protection | Key Rules |
|----------|-----------|-----------|
| **New Feature Spec** | None | Check NFRs, create FEATURES.md entry + acceptance file + migration |
| **Update Planned/In-Progress** | Low | Show existing, update, migration if significant |
| **Evolve Shipped Feature** | **HIGH** | Additive-only, markers required, migration mandatory, human approval |
| **Discovery During Impl** | Medium | `[Discovered]` entries only, migration, journal entry |
| **Audit** | Read-only | Run health checks + drift detection |

---

## New Feature Spec

1. **Find next F-XXXX ID** — scan `spec/FEATURES.md` for highest ID, increment
2. **Check NFRs** — read `spec/NFR.md`, identify applicable constraints
3. **Create FEATURES.md entry** — Status: planned, include Related NFRs
4. **Create acceptance file** — `spec/acceptance/F-XXXX.md` from `.agentic/spec/acceptance.template.md`
   - Required sections: Tests, Acceptance Criteria, Out of Scope
   - Add NFR Compliance section if NFRs apply
5. **Show draft to user** — human reviews before committing
6. **Create migration** — `bash .agentic/tools/migration.sh create "Add F-XXXX [Name]"`
7. **Validate** — `bash .agentic/tools/check-spec-health.sh F-XXXX`
8. **Handoff** — "Run `ag plan F-XXXX` before implementing"

---

## Update Planned/In-Progress Spec

1. **Read current acceptance criteria** — show to user
2. **Apply changes** — update criteria, scope, tests
3. **Migration if significant** — adding/removing criteria, scope change
4. **Show to user for approval**

---

## Evolve Shipped Feature Spec (CONTRACT MODIFICATION)

**This is the highest-protection scenario.** Shipped specs are contracts.

### Rules

- **NEVER** delete existing acceptance criteria — only add with markers
- **NEVER** modify existing test expectations without justification
- **NEVER** weaken criteria — if wrong, mark `[Revised in M-NNN: was "X" now "Y"]`
- Every change creates a migration documenting: what changed, why, impact on tests
- Human **must** approve shipped-spec modifications

### Markers

| Marker | When |
|--------|------|
| `[Discovered]` | New criteria found during implementation |
| `[Revised in M-NNN: was "X" now "Y"]` | Correcting existing criteria (preserves old text) |
| `[Future]` | Enhancement idea, not implemented yet |

### Steps

1. Read current acceptance criteria + linked tests + NFR references
2. Show current state to user
3. Add new criteria with appropriate markers (additive only)
4. Require justification (captured in migration)
5. `bash .agentic/tools/migration.sh create "Evolve F-XXXX: [reason]"`
6. `bash .agentic/tools/drift.sh --check` (if available)
7. Show changes to user — human MUST approve

---

## Discovery During Implementation

See also: `.agentic/workflows/spec_evolution.md`

When implementing and discovering new requirements:

1. Add `[Discovered]` entries to acceptance criteria
2. Create migration if adding multiple criteria or changing scope
3. Log in JOURNAL.md what was discovered and why

---

## NFR Integration

For any spec operation:

1. Read `spec/NFR.md` — identify NFRs that constrain the feature
2. Add `Related NFRs:` field to FEATURES.md entry
3. Add `### NFR Compliance` section to acceptance criteria
4. For shipped features, verify spec changes don't violate linked NFRs

---

## Audit

Read-only health check:

```bash
# Single feature
bash .agentic/tools/check-spec-health.sh F-XXXX

# All features
bash .agentic/tools/check-spec-health.sh --all
```

---

## WIP Warning

If `.agentic-state/WIP.md` exists for the feature being modified, show a warning:
> WIP active for this feature. Spec changes during implementation should use `[Discovered]` markers.

---

## Pre-Commit Enforcement

The following are enforced by `pre-commit-check.sh`:

- **Check 14**: Modifying a shipped feature's acceptance criteria without a migration → BLOCKED
- **Check 15**: Deleting a test file referenced by a shipped feature → BLOCKED
- **Check 16**: Downgrading a shipped feature's status → BLOCKED

These gates have **no escape hatch** by design.

---

## Related Documents

- [Spec Evolution](spec_evolution.md) — how specs grow during implementation
- [Spec Migrations](spec_migrations.md) — migration format and tooling
- [Definition of Done](definition_of_done.md)
- [Acceptance Template](../spec/acceptance.template.md)
