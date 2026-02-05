# Issues & Bugs

<!-- format: issues-v0.1.0 -->

**Purpose**: Track bugs, issues, and technical debt found during development.

**Format**: Similar to FEATURES.md but for problems, not capabilities.

---

## Summary

| Status | Count |
|--------|-------|
| Open | 1 |
| In Progress | 0 |
| Fixed | 1 |
| Won't Fix | 0 |
| **Total** | 1 |

---

## Issue Template

```markdown
## I-XXXX: [Short descriptive title]

**Status**: open | in_progress | fixed | wont_fix | duplicate
**Priority**: critical | high | medium | low
**Severity**: blocker | major | minor | cosmetic
**Found**: YYYY-MM-DD
**Fixed**: (date or empty)

**Description**:
What's wrong? What's the expected vs actual behavior?

**Steps to Reproduce**:
1. Do X
2. Then Y
3. Observe Z

**Environment**:
- OS: 
- Version:
- Browser/Runtime:

**Related**:
- Feature: F-####
- Caused by: (commit or change)
- Blocks: F-####

**Root Cause**: (once understood)

**Fix**:
- Commit: (link)
- Files changed:

**Lessons**: (what to avoid in future)
```

---

## Open Issues

## I-0001: CLAUDE.md dogfooding inverted - template should be canonical source

**Status**: fixed
**Priority**: high
**Severity**: major
**Found**: 2026-02-04
**Fixed**: 2026-02-04

**Description**:
The dogfooding architecture for CLAUDE.md is backwards:

**Current (wrong):**
```
/CLAUDE.md (root)                    ← Has newer features (ag CLI, gates table)
.agentic/agents/claude/CLAUDE.md     ← Template users get (outdated, 2x longer)
```

**Should be:**
```
.agentic/agents/claude/CLAUDE.md     ← CANONICAL source (what users get)
         ↓ includes/extends
/CLAUDE.md (root)                    ← Adds framework-dev-specific notes only
```

**Specific gaps in template:**
1. No `ag` CLI commands (`ag start`, `ag implement`, `ag commit`, `ag done`)
2. No ENFORCED GATES section (Core+PM vs Core profile awareness)
3. No complexity limits reference
4. No escape hatches documentation (`SKIP_TESTS=1`, `SKIP_COMPLEXITY=1`)
5. Template is 558 lines vs root's 291 lines (users pay 2x token cost)

**Impact:**
- Users don't get features we developed for ourselves
- Framework features (F-0091, F-0116) not reflected in template
- We're not eating our own dogfood properly

**Root Cause**:
Features were added to root CLAUDE.md during framework development but not backported to the template that users receive.

**Proposed Fix:**
1. Update `.agentic/agents/claude/CLAUDE.md` to be the canonical, complete version
2. Refactor root `/CLAUDE.md` to:
   - Include/source the template, OR
   - Be a minimal wrapper that adds only framework-dev notes
3. Add dogfooding check to `validate_framework.sh`

**Related**:
- Feature: F-0091 (Gate-Based Verification)
- Feature: F-0116 (Maintainability Enforcement)
- Feature: F-0103 (Agent Mode Selection)

**Fix**:
- Updated `.agentic/agents/claude/CLAUDE.md` (template) with all new features: ENFORCED GATES, `ag` CLI, escape hatches
- Refactored root `/CLAUDE.md` to be template + framework-specific section only
- Added dogfooding rule to `.agentic/FRAMEWORK_DEVELOPMENT.md`
- Reduced template from 558 → 277 lines (50% token savings for users)
- Root is now 303 lines (template 277 + framework section 26)

**Files changed**:
- `.agentic/agents/claude/CLAUDE.md` (canonical template)
- `/CLAUDE.md` (framework-specific wrapper)
- `.agentic/FRAMEWORK_DEVELOPMENT.md` (dogfooding rule)

---

<!-- Add new issues here -->

---

## In Progress

<!-- Issues being actively worked on -->

---

## Recently Fixed

<!-- Last 5-10 fixed issues for reference -->

---

## Won't Fix / Duplicates

<!-- Issues closed without fix, with explanation -->


