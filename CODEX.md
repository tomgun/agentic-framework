# Codex CLI Instructions

You are working in a repository that uses the **Agentic Framework**.

---

## Quick Start

Read these first:
- `CONTEXT_PACK.md` - Architecture, entry points
- `STATUS.md` - Current focus
- `STACK.md` - Tech stack, config

---

## Commands

```bash
ag start              # Session start
ag plan F-XXXX        # Plan with review loop
ag implement F-XXXX   # Start feature (Core+PM)
ag work "desc"        # Start task (Core)
ag commit             # Pre-commit gates
ag done F-XXXX        # Completion check
```

---

## Plan-Review Loop

For complex features, use iterative planning:

```bash
ag plan F-XXXX        # Creates plan, triggers review
```

1. Create plan at `.agentic-state/plans/F-XXXX-plan.md`
2. Review critically (adversarial mindset)
3. Revise until APPROVED or max iterations

See: `.agentic/workflows/plan_review_loop.md`

---

## Key Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Full agent instructions |
| `.agentic/agents/claude/subagents/` | Specialized agent roles |
| `.agentic/workflows/` | Process documentation |
| `.agentic/checklists/` | Step-by-step guides |

---

## Rules

1. **Acceptance criteria before code** - Check `spec/acceptance/F-XXXX.md` exists
2. **Small batches** - Max 5-10 files per commit
3. **Never auto-commit** - Show changes to human first
4. **Docs with code** - Update docs in same commit as behavior changes
