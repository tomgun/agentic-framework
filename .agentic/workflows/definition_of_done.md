# Definition of Done

**⚠️ This document is now a summary. For the full checklist, see [`../checklists/feature_complete.md`](../checklists/feature_complete.md)**

---

## Quick Reference

Every feature marked "shipped" must have:

### ✅ Acceptance Criteria Met
- All criteria in `spec/acceptance/F-####.md` satisfied
- **Smoke test passed** (actually ran the application!)

### ✅ Tests Complete
- Unit tests for all logic
- Integration tests (if crossing boundaries)
- Acceptance tests matching criteria
- All tests pass

### ✅ Code Quality
- Follows programming standards
- Error handling complete
- No debug code left
- Code annotations added (@feature, @acceptance)

### ✅ Documentation Updated
- `FEATURES.md` or `OVERVIEW.md` status = shipped
- `JOURNAL.md` updated
- `CONTEXT_PACK.md` updated (if architecture changed)
- Code comments explain "why"

### ✅ Quality Gates Pass
- `bash .agentic/hooks/pre-commit-check.sh` succeeds
- No untracked files in project directories
- All stack-specific checks pass

---

## Remember

**Shipped ≠ Accepted**

- **Shipped** = Agent believes it's done, tests pass, code committed
- **Accepted** = Human validated it works and solves the problem

This quick reference is for reaching "shipped". Human acceptance is the final gate.

---

**Full Checklist**: [`../checklists/feature_complete.md`](../checklists/feature_complete.md)
