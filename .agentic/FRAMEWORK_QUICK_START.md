# Framework Development Quick Start

**Scope**: Agents working ON the Agentic Framework itself (not projects using it).

**Full reference**: `FRAMEWORK_DEVELOPMENT.md` | **Principles rationale**: `PRINCIPLES.md`

---

## 🚨 CORE PRINCIPLES (Non-Negotiable)

Every decision must align with these. If conflict, re-read `PRINCIPLES.md`.

| Principle | What It Means for Framework Dev |
|-----------|--------------------------------|
| **Traceability** | Spec ↔ Acceptance Criteria ↔ Acceptance Tests ↔ Unit Tests ↔ Code — ALL must match |
| **Living Documentation** | Update docs WITH code in same commit, never "later" |
| **Single Source of Truth** | Information lives in ONE place; others reference it |
| **Dogfooding** | Framework follows its own spec-driven methodology |
| **Developer UX** | Easy to use, clear errors, helpful messages |
| **Small Batch** | One feature at a time, max 5-10 files per commit |
| **Gates > Guidelines** | Enforcement (hooks, scripts) over advice (docs) |
| **Backward Compatibility** | Existing projects must upgrade cleanly |
| **Token Economics** | Durable artifacts, efficient scripts, context isolation |

---

## 🔴 BEFORE ANY FRAMEWORK CHANGE

Ask yourself:

1. **Does it align with principles above?** → If not, reconsider
2. **Will it affect templates?** → Test in scratch project first
3. **Will it affect examples?** → Update `examples/` too
4. **Is it a new feature?** → Must be specced (see below)
5. **Does it break existing projects?** → Provide upgrade path

---

## ✅ ADDING A FRAMEWORK FEATURE (Mandatory Steps)

| # | File | Action | Why |
|---|------|--------|-----|
| 1 | `spec/FEATURES.md` | Add F-#### entry | Dogfooding: we spec our own features |
| 2 | `spec/acceptance/F-####.md` | Create acceptance criteria | Traceability: criteria before code |
| 3 | `tests/validate_framework.sh` | Add validation tests | Gates > Guidelines: enforce, don't advise |
| 4 | Code | Implement the feature | Now code matches spec |
| 5 | `CHANGELOG.md` | Document the change | Living docs |
| 6 | `CONTRIBUTIONS.md` | Add version section | Attribution |
| 7 | `upgrade.sh` FEATURE_REGISTRY | If user-visible during upgrade | Developer UX |

**Verification**: `bash tests/validate_framework.sh` must pass.

---

## 🔄 RELEASE CHECKLIST (Abbreviated)

```
[ ] spec/FEATURES.md has new features
[ ] spec/acceptance/F-####.md exists for each
[ ] tests/validate_framework.sh passes (all tests)
[ ] Examples in examples/ updated and working
[ ] CHANGELOG.md updated
[ ] CONTRIBUTIONS.md updated
[ ] VERSION file updated
[ ] Git tag: git tag -a vX.Y.Z -m "Release vX.Y.Z"
[ ] Push: git push origin main vX.Y.Z
```

Full checklist: `FRAMEWORK_DEVELOPMENT.md` → Section 11

---

## 📁 KEY FILES

| Purpose | File |
|---------|------|
| Framework specs | `spec/FEATURES.md` |
| Acceptance criteria | `spec/acceptance/F-####.md` |
| Validation tests | `tests/validate_framework.sh` |
| Upgrade notifications | `.agentic/tools/upgrade.sh` → FEATURE_REGISTRY |
| Templates | `.agentic/init/*.template.md` |
| Agent guidelines | `.agentic/agents/shared/` |
| Full dev guide | `.agentic/FRAMEWORK_DEVELOPMENT.md` |
| Principles | `.agentic/PRINCIPLES.md` |

---

## ⚠️ COMMON MISTAKES

| Mistake | Consequence | Prevention |
|---------|-------------|------------|
| Code without spec | Untraceable, undocumented | Always F-#### first |
| Spec without acceptance | No verification criteria | Always create F-####.md |
| Acceptance without test | Gate doesn't enforce | Always update validate_framework.sh |
| Change templates without testing | Breaks all future projects | Test in scratch project |
| Forget examples | Examples become stale | Update examples/ with changes |
| Docs "later" | Docs become stale | Same commit as code |

---

**Remember**: Framework changes affect ALL users. Spec → Acceptance → Test → Code → Docs — in sync, always.
