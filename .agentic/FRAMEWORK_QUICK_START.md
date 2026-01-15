# Framework Development Quick Start

**Scope**: Agents working ON the Agentic Framework itself (not projects using it).

**Full reference**: `FRAMEWORK_DEVELOPMENT.md` | **Principles rationale**: `PRINCIPLES.md`

---

## 🚨 CORE PRINCIPLES (Non-Negotiable)

Every decision must align with these. If conflict, re-read `PRINCIPLES.md`.

| Principle | What It Means for Framework Dev |
|-----------|--------------------------------|
| **Token Economics** | Durable artifacts, efficient scripts, context isolation (Core) |
| **Developer UX** | User remembers nothing; specs/WIP/STATUS carry state; agent guides proactively (Core) |
| **Traceability** | Spec ↔ Acceptance Criteria ↔ Tests ↔ Code — ALL must match current committed version |
| **Acceptance-Driven** | Write acceptance criteria BEFORE implementation, not after |
| **Living Documentation** | Update docs WITH code in same commit, never "later" |
| **Documentation = Reality** | Test that workflows actually work; don't assume |
| **Single Source of Truth** | Information lives in ONE place; others reference it |
| **Internal Consistency** | Templates + examples + docs + agent guidelines must align |
| **Dogfooding** | Framework follows its own spec-driven methodology |
| **Small Batch** | One feature at a time, max 5-10 files per commit |
| **Gates > Guidelines** | Enforcement (hooks, scripts) over advice (docs) |
| **Backward Compatibility** | Existing projects must upgrade cleanly |

---

## 📦 TWO PROFILES: Core vs Core+PM

Framework features apply to different profiles:

| Profile | What Users Get | Key Files |
|---------|---------------|-----------|
| **Core** | Token efficiency, developer UX, workflows, quality gates | CONTEXT_PACK.md, JOURNAL.md, PRODUCT.md, WIP.md |
| **Core+PM** | Core + formal specs, feature tracking, acceptance criteria | + spec/FEATURES.md, spec/acceptance/, STATUS.md |

**When adding framework features, know which profile it affects:**
- Core features → affect ALL users
- Core+PM features → only users who enable formal specs
- Both → document clearly in spec/FEATURES.md

**Core is the foundation** - Token Economics and Developer UX must work without any specs.

---

## 🔴 BEFORE ANY FRAMEWORK CHANGE

Ask yourself:

1. **Does it align with principles above?** → If not, reconsider
2. **Will it affect templates?** → Test in scratch project first
3. **Will it affect examples?** → Consider updating `examples/` (not blocking, but recommended)
4. **Is it a new feature?** → Must be specced (see below)
5. **Does it break existing projects?** → Provide upgrade path in `upgrade.sh`
6. **Did you test it actually works?** → Run in scratch project, don't assume

---

## ✅ ADDING A FRAMEWORK FEATURE (Mandatory Steps)

| # | File | Action | Why |
|---|------|--------|-----|
| 1 | `spec/FEATURES.md` | Add F-#### entry | Dogfooding: we spec our own features |
| 2 | `spec/acceptance/F-####.md` | Create acceptance criteria FIRST | Acceptance-Driven: criteria before code |
| 3 | Code | Implement the feature | Now you know what "done" means |
| 4 | `tests/validate_framework.sh` | Add validation tests | Gates > Guidelines: enforce, don't advise |
| 5 | Scratch project | Test the feature works | Documentation = Reality |
| 6 | `CHANGELOG.md` | Document the change | Living docs |
| 7 | `CONTRIBUTIONS.md` | Add version section | Attribution |
| 8 | `upgrade.sh` FEATURE_REGISTRY | If user-visible during upgrade | Developer UX |

**Feature is "accepted" when**: Tests pass in `validate_framework.sh` AND developer has reviewed tests and results.

**Note**: Further development may break features. Re-run `validate_framework.sh` regularly.

---

## 🔄 RELEASE CHECKLIST (Abbreviated)

```
[ ] spec/FEATURES.md has new features (F-####)
[ ] spec/acceptance/F-####.md exists for each new feature
[ ] tests/validate_framework.sh passes (ALL tests)
[ ] Tested in scratch project (install.sh, init, upgrade)
[ ] CHANGELOG.md updated
[ ] CONTRIBUTIONS.md updated
[ ] VERSION file updated
[ ] Version references updated (README, DEVELOPER_GUIDE, etc.)
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
| Spec without acceptance criteria | No definition of "done" | Always create F-####.md BEFORE coding |
| Acceptance without test | Gate doesn't enforce | Always update validate_framework.sh |
| Change templates without testing | Breaks all future projects | Test in scratch project |
| Assume it works | Broken workflows shipped | Actually run it, verify output |
| Docs "later" | Docs become stale/wrong | Same commit as code |
| Scattered version refs | Users install wrong version | Update ALL version references on release |

---

## 🧪 TESTING FRAMEWORK CHANGES

**Before committing**:

```bash
# 1. Create scratch project
mkdir /tmp/test-framework && cd /tmp/test-framework && git init

# 2. Install framework
bash /path/to/agentic-framework/install.sh .

# 3. Test init works
# (run through init_playbook.md with agent)

# 4. Test tools work
python3 .agentic/tools/doctor.py
bash .agentic/tools/wip.sh check

# 5. If changing upgrade.sh, test upgrade path
cd /tmp/old-project  # existing project on older version
bash /path/to/new-framework/.agentic/tools/upgrade.sh .
```

---

**Remember**: Framework changes affect ALL users.

**The chain**: Spec → Acceptance Criteria → Code → Tests → Docs — all in sync, all matching committed version.
