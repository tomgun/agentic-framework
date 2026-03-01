---
summary: "Spec-writing checklist: create, update, or evolve feature specifications"
trigger: "write spec, create spec, add acceptance criteria, update spec, ag spec"
tokens: ~800
phase: planning
---

# SPEC-WRITING CHECKLIST

**Canonical workflow**: `.agentic/workflows/spec_writing.md`

---

## STEP 1: Identify Scenario

```
□ Is this a NEW feature (no F-XXXX exists)?           → Go to STEP 2
□ Is this an EXISTING feature?
  ├─ Status: planned / in_progress                    → Go to STEP 3 (Low protection)
  └─ Status: shipped                                  → Go to STEP 4 (HIGH protection)
```

---

## STEP 2: New Feature Spec

```
□ Find next F-XXXX ID in spec/FEATURES.md
□ Read spec/NFR.md → identify applicable NFRs
□ Create FEATURES.md entry (Status: planned, Related NFRs)
□ Create spec/acceptance/F-XXXX.md from template
  □ Has ## Tests section
  □ Has ## Acceptance Criteria section
  □ Has ## Out of Scope section
  □ Has ### NFR Compliance section (if NFRs apply)
□ Show draft to user for approval
□ bash .agentic/tools/migration.sh create "Add F-XXXX [Name]"
□ bash .agentic/tools/check-spec-health.sh F-XXXX
□ Handoff: "Run ag plan F-XXXX before implementing"
```

---

## STEP 3: Update Planned/In-Progress Spec

```
□ Read current acceptance criteria
□ Show existing spec to user
□ Apply changes
□ Create migration if significant (scope change, criteria added/removed)
□ Show to user for approval
```

---

## STEP 4: Evolve Shipped Spec (CONTRACT MODIFICATION)

```
⚠ SHIPPED SPECS ARE CONTRACTS — HIGHEST PROTECTION

□ Read current acceptance criteria + linked tests + NFR refs
□ Show current state to user
□ NEVER delete existing criteria — additive only
□ Use markers: [Discovered], [Revised in M-NNN: was "X" now "Y"]
□ Document justification for change
□ bash .agentic/tools/migration.sh create "Evolve F-XXXX: [reason]"
□ Show changes to user — HUMAN MUST APPROVE
```

---

## STEP 5: Validate

```
□ bash .agentic/tools/check-spec-health.sh F-XXXX
□ Pre-commit will enforce:
  - Check 14: Shipped spec changes need migration
  - Check 15: Test deletions blocked for shipped features
  - Check 16: Status downgrades blocked for shipped features
```
