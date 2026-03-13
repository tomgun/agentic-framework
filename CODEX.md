# Codex CLI Instructions - Framework Development

THIS IS FRAMEWORK DEVELOPMENT. You are working ON the agentic framework itself, not a project using it. Framework changes affect ALL users - extra care required.

Read first: `FRAMEWORK_QUICK_START.md`, `FRAMEWORK_DEVELOPMENT.md`, `.agentic/lib/PRINCIPLES.md`

Full template: `.agentic/lib/agents/codex/codex-instructions.md`

---

## Session Start

On first message, give a briefing:
- Read .agentic/STATUS.md, .agentic/HUMAN_NEEDED.md, .agentic/journal/JOURNAL.md, VERSION, and git status
- Greet user with: current state, focus, blockers, next steps, recent work
- Do NOT wait to be asked

## Git Workflow

- Always create a separate git worktree on a feature branch before making changes (another agent may be working on main)
- Never auto-commit in interactive sessions without human approval. (Autonomous workflows use `review_commit` setting — F-0203.)

---

## The Core Chain (Never Break This)

**Spec -> Acceptance Criteria -> Code -> Tests -> Docs**

All must match. All must be in sync with committed code.

---

## Adding Framework Features (Mandatory)

| Step | Action |
|------|--------|
| 1 | Add F-#### to `.agentic/spec/FEATURES.md` |
| 2 | Create `.agentic/spec/acceptance/F-####.md` BEFORE coding |
| 3 | Implement the feature |
| 4 | Add tests to `tests/validate_framework.sh` |
| 5 | Update `CHANGELOG.md` |
| 6 | Update `.agentic/CONTRIBUTIONS.md` |
| 7 | If user-visible during upgrade: add to `FEATURE_REGISTRY` in `upgrade.sh` |

Verify: `bash tests/validate_framework.sh` must pass

---

## Before ANY Change

1. Does it align with principles in `PRINCIPLES.md`?
2. Will it affect templates? -> Test in scratch project first
3. Is it a new feature? -> Spec it FIRST
4. Does it break existing projects? -> Provide upgrade path

---

## Key Principles

| Principle | Meaning |
|-----------|---------|
| **Traceability** | Spec <-> Acceptance <-> Tests <-> Code must match |
| **Acceptance-Driven** | Criteria BEFORE implementation |
| **Living Docs** | Update docs WITH code, same commit |
| **Gates > Guidelines** | Enforce with scripts, not just docs |
| **Backward Compatibility** | Existing projects must upgrade cleanly |

---

## Reference

- Quick start: `FRAMEWORK_QUICK_START.md`
- Full guide: `FRAMEWORK_DEVELOPMENT.md`
- Principles: `.agentic/lib/PRINCIPLES.md`
- Specs: `.agentic/spec/FEATURES.md`
- Validation: `tests/validate_framework.sh`
