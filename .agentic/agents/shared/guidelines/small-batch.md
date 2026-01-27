# Small Batch Development (NON-NEGOTIABLE)

**The single most important quality principle: WORK IN SMALL, ISOLATED BATCHES.**

---

## Why This Is Critical

- **Small changes = easy to verify = easy to rollback**
- **If something goes wrong, most of the software still works**
- **Known-good checkpoints after each feature**
- **One feature at a time = clear ownership**

---

## Rules

1. **ONE feature at a time per agent** - Never work on multiple features simultaneously
2. **Acceptance criteria MUST exist** before implementation (even if rough)
3. **Implement → verify with tests → commit** - Small batch rhythm
4. **MAX 5-10 files per commit** - Stop and re-plan if more
5. **Update specs with discoveries** - New edge cases, ideas, issues found

---

## STOP and Re-Plan If

| Warning Sign | Action |
|--------------|--------|
| Need to touch **>10 files** | Break into smaller features |
| Can't define **any** acceptance criteria | Research/planning phase needed |
| Working **>1 hour without commit** | Commit partial progress, checkpoint |
| Multiple features **"in progress"** | Complete one before starting another |

---

## One Feature At A Time (Per Agent)

**RULE**: Each agent works on ONE feature at a time.

**Before starting new feature:**
1. Check spec/FEATURES.md for any "in_progress" features assigned to you
2. If found: **Complete that feature FIRST** or mark as "blocked"
3. Only then start new feature

**Why:** Multiple in-progress features = unclear state, harder rollback, context confusion

---

## Spec Evolution Is Expected

Initial acceptance criteria may be rough. During implementation, you'll discover:
- Edge cases
- Missing requirements
- Technical constraints
- Better approaches

**This is normal.** Update specs with discoveries - see `workflows/spec_evolution.md`.

---

## Multi-Agent Parallel Work

Multiple agents CAN work on different features simultaneously using Git worktrees.

**Rules for parallel work:**
- Each agent follows "one feature at a time" in their own worktree
- Register in `.agentic/AGENTS_ACTIVE.md`
- Avoid touching the same files
- See `workflows/multi_agent_coordination.md`

---

## Summary

| Constraint | Limit |
|------------|-------|
| Features in progress | 1 per agent |
| Files per commit | 5-10 max |
| Time without commit | <1 hour |
| Acceptance criteria | Required before coding |

**Mantra**: Small, isolated, verifiable changes. Commit often.
