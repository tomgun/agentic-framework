# F-0197: FEATURES.md Registry Integrity + AC Verification Gate — Plan

**Status**: APPROVED
**Parent Plan**: reliability-fix-plan.md (Priorities 1 + 2)

## Scope

This feature implements PR 1 of the Reliability Fix Plan:
- P1a: Deprecate F-0033, F-0098
- P1b: Fix impl-state for F-0190, F-0179, F-0189
- P1c: drift-check.sh tool wired into ag sync
- P2a: AC completion gate in cmd_done
- P2b: AC summary in dashboard

## Implementation Steps

1. Mark F-0033 and F-0098 as deprecated in FEATURES.md
2. Delete AGENTS_ACTIVE.template.md if exists
3. Close T-0017 in TODO.md
4. Fix F-0190 impl-state to complete, check off passing ACs
5. Fix F-0179 impl-state to complete, check off passing ACs
6. Clarify F-0189 partial state
7. Create drift-check.sh (compare FEATURES.md status vs AC completion)
8. Wire drift-check into ag sync
9. Add AC completion gate to cmd_done in ag.sh
10. Add AC summary to dashboard.sh
11. Run validate_framework.sh

## Files Changed

- `.agentic/spec/FEATURES.md` (status corrections)
- `.agentic/spec/acceptance/F-0179.md`, `F-0189.md`, `F-0190.md` (check off ACs)
- `.agentic/spec/AGENTS_ACTIVE.template.md` (delete)
- `.agentic/TODO.md` (close T-0017)
- `.agentic/lib/tools/drift-check.sh` (new)
- `.agentic/lib/tools/sync.sh` (wire drift-check)
- `.agentic/lib/tools/ag.sh` (AC gate in cmd_done)
- `.agentic/lib/tools/dashboard.sh` (AC summary)
