# Issues & Bugs

<!-- format: issues-v0.1.0 -->

**Purpose**: Track bugs, issues, and technical debt found during development.

**Format**: Similar to FEATURES.md but for problems, not capabilities.

---

## Summary

| Status | Count |
|--------|-------|
| Open | 4 |
| In Progress | 0 |
| Fixed | 1 |
| Won't Fix | 0 |
| **Total** | 5 |

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
2. No ENFORCED GATES section (Formal vs Discovery profile awareness)
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

## I-0002: Plan mode bypasses "create F-XXXX FIRST" trigger — feature specs skipped

**Status**: open
**Priority**: high
**Severity**: major
**Found**: 2026-02-17
**Fixed**:

**Description**:
CLAUDE.md line 19 says: `Build / implement → STOP → create spec/acceptance/F-XXXX.md FIRST, then ag plan + ag implement. Never code before specs.`

This trigger was completely bypassed during the settings-over-profiles implementation (F-0131). The work was planned via plan mode, approved, and implemented across multiple sessions — all without ever creating a feature entry in FEATURES.md or writing acceptance criteria. The feature + acceptance criteria were only created retroactively after the PR was already up.

**How it happened**:
1. User requested implementation of settings-over-profiles architecture
2. Agent entered plan mode and wrote a detailed plan file (`.claude/plans/...`)
3. Plan was approved, implementation began immediately
4. Plan mode treated the plan file as the driving document, never checking for F-XXXX
5. Continuation sessions inherited the gap — none caught the missing feature spec
6. Session-start checklist didn't flag "in-progress work without a feature ID"

**Root cause**:
Plan mode and session continuation are blind spots in the trigger-word enforcement:
- **Plan mode**: The plan itself substitutes for the feature spec in the agent's mind, but it's a session-scoped artifact (`.claude/plans/`) — not a durable framework artifact (`spec/acceptance/F-XXXX.md`). The "STOP → create specs FIRST" gate doesn't fire because plan mode feels like "we already planned it."
- **Session continuation**: When picking up from a previous session summary, the agent continues from where it left off without re-evaluating trigger conditions. The summary says "Phase 2b in progress" and the agent resumes coding, never checking if F-XXXX exists.
- **No programmatic enforcement**: The trigger is purely instruction-based (CLAUDE.md text). There's no `ag plan` or `ag implement` gate that checks "does F-XXXX exist in FEATURES.md?" before proceeding.

**Impact**:
- Feature shipped without formal acceptance criteria — criteria were written post-hoc
- Acceptance criteria might not reflect what was actually intended vs what was built
- Sets a precedent where plan mode can bypass the spec-first workflow

**Proposed fixes**:

1. **`ag plan` gate**: Before allowing plan mode, check if an F-XXXX is referenced. If not, prompt to create one first. (Programmatic enforcement)

2. **`ag implement` gate**: Before starting implementation, verify `spec/acceptance/F-XXXX.md` exists. Block if missing. (Programmatic enforcement)

3. **Session-start checklist**: Add a check — "if there's in-progress work (WIP.md or active branch), verify it has an associated F-XXXX with acceptance criteria"

4. **Plan mode instructions**: Add to plan mode system prompt — "Before writing the plan, verify F-XXXX exists in FEATURES.md. If not, create it first."

**Related**:
- Feature: F-0131 (the feature that was shipped without specs)
- Feature: F-0006 (Acceptance-Driven Development — the principle this violates)
- Feature: F-0091 (Gate-Based Verification — where programmatic enforcement should live)

**Lessons**:
- Instruction-only enforcement is fragile — agents can bypass it unintentionally during mode transitions (plan mode, session continuation)
- Programmatic gates (like pre-commit-check.sh) are more reliable than text-based triggers
- Session continuations are a particularly weak point — the agent resumes "in the middle" and skips initial checks

---

## I-0003: Plan mode plan files are session-scoped, not durable framework artifacts

**Status**: open
**Priority**: medium
**Severity**: minor
**Found**: 2026-02-17
**Fixed**:

**Description**:
Plan mode writes plans to `.claude/plans/` which is tool-specific (Claude Code) and session-scoped. These plans are not committed to the repo, not visible to other agents/tools, and can be lost when context compresses or sessions end.

For F-0131, the plan was the primary design document but it lived only in `.claude/plans/shimmying-foraging-shore.md`. If a different agent or tool needed to understand the design decisions, they'd have no access to it.

The framework has `.agentic-state/` for session state and `spec/` for durable specs, but plan mode doesn't use either.

**Proposed fix**:
- `ag plan` should write the approved plan to `.agentic-state/PLAN.md` or `spec/` as a durable artifact
- Or: plan approval step should prompt to extract key decisions into the acceptance criteria file

**Related**:
- Issue: I-0002 (plan mode bypasses spec-first workflow)
- Feature: F-0006 (Acceptance-Driven Development)

---

## I-0004: No per-command setting overrides

**Status**: open
**Priority**: low
**Severity**: minor
**Found**: 2026-02-16

**Description**:
Settings can only be changed permanently in STACK.md. There's no way to override a setting for a single command (e.g., `ag commit --max-files=25` for a one-off large commit).

**Proposed fix**:
- Environment variable overrides: `MAX_FILES_PER_COMMIT=25 ag commit`
- Command-line flags: `ag commit --override max_files_per_commit=25`

**Related**:
- Feature: F-0131 (Settings-Over-Profiles Architecture)

---

## I-0005: Settings list hardcoded in show_all_settings

**Status**: open
**Priority**: low
**Severity**: minor
**Found**: 2026-02-16

**Description**:
The `show_all_settings()` function in `settings.sh` has a hardcoded list of known settings. Adding a new setting requires updating the list manually.

**Proposed fix**:
- Read setting names from `profiles.conf` automatically
- Or maintain a `settings.registry` file listing all valid settings with types and descriptions

**Related**:
- Feature: F-0131 (Settings-Over-Profiles Architecture)

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


