# GitHub Copilot Instructions - Framework Development

You are working ON the **Agentic Framework** itself, not a project using it.

**Different rules apply** — framework changes affect ALL users.

---

## 🚨 READ FIRST

**Read `.agentic/FRAMEWORK_QUICK_START.md`** (~140 lines) - it has everything you need.

---

## The Core Chain (Never Break This)

**Spec → Acceptance Criteria → Code → Tests → Docs**

All must match. All must be in sync with committed code.

---

## Adding Framework Features (Mandatory)

| Step | Action |
|------|--------|
| 1 | Add F-#### to `spec/FEATURES.md` |
| 2 | Create `spec/acceptance/F-####.md` BEFORE coding |
| 3 | Implement the feature |
| 4 | Add tests to `tests/validate_framework.sh` |
| 5 | Update `CHANGELOG.md` |
| 6 | Update `CONTRIBUTIONS.md` |
| 7 | If user-visible during upgrade: add to `FEATURE_REGISTRY` in `upgrade.sh` |

**Verify**: `bash tests/validate_framework.sh` must pass

---

## Before ANY Change

1. Does it align with principles in `PRINCIPLES.md`?
2. Will it affect templates? → Test in scratch project first
3. Is it a new feature? → Spec it FIRST
4. Does it break existing projects? → Provide upgrade path

---

## Key Principles

| Principle | Meaning |
|-----------|---------|
| **Traceability** | Spec ↔ Acceptance ↔ Tests ↔ Code must match |
| **Acceptance-Driven** | Criteria BEFORE implementation |
| **Living Docs** | Update docs WITH code, same commit |
| **Documentation = Reality** | Test that workflows work, don't assume |
| **Gates > Guidelines** | Enforce with scripts, not just docs |
| **Backward Compatibility** | Existing projects must upgrade cleanly |
| **Single Source of Truth** | Info in ONE place, others reference |

---

## Testing Framework Changes

```bash
# 1. Create scratch project
mkdir /tmp/test-fw && cd /tmp/test-fw && git init

# 2. Install framework
bash /path/to/agentic-framework/install.sh .

# 3. Test init, tools, upgrade work
python3 .agentic/tools/doctor.py
bash .agentic/tools/wip.sh check

# 4. Run validation
bash tests/validate_framework.sh
```

---

## Reference Material

- **Quick start**: `.agentic/FRAMEWORK_QUICK_START.md`
- **Full guide**: `.agentic/FRAMEWORK_DEVELOPMENT.md`
- **Principles**: `.agentic/PRINCIPLES.md`
- **Framework specs**: `spec/FEATURES.md`
- **Validation tests**: `tests/validate_framework.sh`

---

## Never Auto-Commit

ALWAYS show changes to human first. ONLY commit when human explicitly approves.
