# F-0198: Plan Durability (Multi-Tool Scan) — Plan

**Status**: APPROVED
**Parent Plan**: reliability-fix-plan.md (Priority 3)

## Scope

PR 2 of the Reliability Fix Plan:
- Add plan scan phase to ag sync
- Scan ~/.claude/plans/ and .cursor/plans/ for F-XXXX references
- Auto-copy unsaved plans to .agentic/journal/plans/
- Close T-0047

## Implementation Steps

1. Add phase_plan_scan() to sync.sh
2. Scan known tool plan directories for F-XXXX pattern
3. Compare against existing .agentic/journal/plans/ files
4. Auto-copy with notification
5. Close T-0047 in TODO.md

## Files Changed

- `.agentic/lib/tools/sync.sh` (new phase)
- `.agentic/TODO.md` (close T-0047)
