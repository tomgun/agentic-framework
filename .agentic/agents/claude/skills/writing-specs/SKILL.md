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

Spec-writing workflow with protection levels, NFR integration, and delta tracking.

## Instructions

### Step 1: Identify Scenario and Protection Level

Determine the spec operation and its protection level:

| Scenario | Protection | Rules |
|----------|-----------|-------|
| **New Feature** | None | Create FEATURES.md entry + acceptance file + migration |
| **Update Planned/In-Progress** | Low | Update criteria, migration if significant |
| **Evolve Shipped Feature** | **HIGH** | Additive-only, markers, migration mandatory, human approval |
| **Status Update** | Low | Use `feature.sh` script |
| **Audit** | Read-only | Run `check-spec-health.sh` |

### Step 2: Execute Workflow

**For new features:**
1. Find next F-XXXX ID in `spec/FEATURES.md`
2. Read `spec/NFR.md` — identify applicable NFRs
3. Create FEATURES.md entry (Status: planned, Related NFRs)
4. Create `spec/acceptance/F-XXXX.md` from `.agentic/spec/acceptance.template.md`
   - Write `## Behavior` section first (technology-agnostic user goal)
   - Group ACs with priority tags: (P1 — MVP), (P2 — enhanced)
   - Add `**Verify independently**` per AC group
   - Place Tests under `## Verification`
5. Run Clarification Pass (Step 3 below) for features with 3+ ACs
6. Show draft to user for approval
7. `bash .agentic/tools/migration.sh create "Add F-XXXX [Name]"`
8. `bash .agentic/tools/check-spec-health.sh F-XXXX`
9. Handoff: "Run `ag plan F-XXXX` before implementing"

**For status updates:**
```bash
bash .agentic/tools/feature.sh F-XXXX status shipped
```

**For evolving shipped specs (CONTRACT MODIFICATION):**
1. Read current acceptance criteria + linked tests + NFR refs
2. Show current state to user
3. **NEVER** delete existing criteria — additive only
4. Use markers: `[Discovered]`, `[Revised in M-NNN: was "X" now "Y"]`
5. Require justification
6. `bash .agentic/tools/migration.sh create "Evolve F-XXXX: [reason]"`
7. Show changes to user — **human MUST approve**

**For audit:**
```bash
bash .agentic/tools/check-spec-health.sh F-XXXX   # Single feature
bash .agentic/tools/check-spec-health.sh --all     # All features
```

### Step 3: Clarification Pass (after drafting ACs)

For non-trivial features (3+ ACs), scan the acceptance criteria against this taxonomy:

1. **Functional Scope** — Are all user-facing behaviors specified?
2. **Data & Domain Model** — Are entities, relationships, and validation rules clear?
3. **Edge Cases & Failure Handling** — What happens when things go wrong?
4. **Non-Functional Requirements** — Performance, security, accessibility constraints?
5. **Integration & Dependencies** — External systems, APIs, data sources?
6. **Completion Signals** — How do we know it's done? What does "shipped" look like?

For each gap found, ask the user (max 5 questions, multiple-choice with
recommended answer). Record answers as `[Clarified]` markers:
- [ ] **AC-NNN**: [criterion] `[Clarified: user chose option B — offline-first]`

Skip this pass for trivial features (<3 ACs) unless the user requests it.

### Step 4: Validate

After any spec change:
- Feature status in FEATURES.md matches reality
- Acceptance criteria file exists and has required sections
- Migration created for shipped spec changes
- `bash .agentic/tools/check-spec-health.sh F-XXXX` passes

### References

See `references/` for detailed workflows:
- `spec_writing.md` — canonical spec-writing workflow with protection levels
- `spec_evolution.md` — how specs evolve during implementation
- `spec_protection.md` — shipped spec contract rules and markers

## Examples

**Example 1: Create new feature spec**
User says: "Let's spec out the caching feature"
Steps: Find next F-XXXX → check NFRs → create FEATURES.md entry + acceptance file → migration → validate → handoff to `ag plan`.

**Example 2: Evolve shipped spec**
User says: "We need to add rate limiting criteria to F-0010"
Steps: Read current spec → show to user → add `[Discovered]` criteria → create migration → user approves.

**Example 3: Mark feature shipped**
User says: "F-0125 is done"
Steps: `bash .agentic/tools/feature.sh F-0125 status shipped` → verify acceptance criteria met.

**Example 4: Audit specs**
User says: "ag spec --check"
Steps: `bash .agentic/tools/check-spec-health.sh --all` → report issues.

## Troubleshooting

**Pre-commit blocks shipped spec change**
Cause: Modified acceptance criteria for a shipped feature without migration.
Solution: `bash .agentic/tools/migration.sh create "Evolve F-XXXX: [reason]"` and include the migration in the commit.

**Pre-commit blocks status downgrade**
Cause: Changed a shipped feature's status back to in_progress.
Solution: This is intentionally blocked. If truly needed, create a migration documenting why.
