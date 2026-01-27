<!-- migration-id: 001 -->
<!-- date: 2026-01-27 -->
<!-- author: Claude (Opus) -->
<!-- type: feature -->

# Migration 001: Add F-0101 Framework ADRs and F-0102 Modular Guidelines

## Context & Why

Framework development lacked documentation of WHY decisions were made. Contributors could see WHAT was done but not understand the reasoning, leading to well-intentioned "optimizations" that broke things.

Example: CLAUDE.md had content that appeared duplicated with agent_operating_guidelines.md. A contributor consolidated it for "DRY compliance", breaking the bootstrap mechanism. The duplication was intentional.

**Business need**: Prevent future contributors from undoing intentional decisions
**Technical driver**: Token efficiency (modular guidelines) + decision traceability (ADRs)

## Changes

### Features Added

- F-0101: Framework Architecture Decision Records (ADRs)
  - Created `docs/adr/` directory
  - Created ADR-001: CLAUDE.md Must Be Self-Contained
  - Updated CONTEXT_PACK.md to reference ADRs
  - Updated FRAMEWORK_QUICK_START.md with step 9 (sync CLAUDE.md)

- F-0102: Modular Guidelines for Token Efficiency
  - Created `.agentic/agents/shared/guidelines/` directory
  - Extracted 5 modules: anti-hallucination, token-efficiency, small-batch, wip-tracking, multi-agent
  - ~84% token reduction for typical tasks
  - Added JSON backend for status.sh

### Features Modified

None

### Features Deprecated

None

## Dependencies

- **Requires**: None (first migration)
- **Blocks**: None
- **Related**: ADR-001

## Acceptance Criteria

- [x] `docs/adr/` directory exists
- [x] `docs/adr/001-claude-md-self-contained.md` exists
- [x] `.agentic/agents/shared/guidelines/` directory exists
- [x] All 5 guideline modules exist
- [x] CONTEXT_PACK.md references ADRs
- [x] FRAMEWORK_QUICK_START.md includes CLAUDE.md sync step

## Implementation Notes

- ADRs follow format: Status, Context, Decision, Rationale, Consequences
- Guideline modules are for lazy-loading, not replacing CLAUDE.md
- CLAUDE.md must remain self-contained (see ADR-001)
- When updating guidelines, sync both CLAUDE.md and modules

## Rollback Plan

1. Remove `docs/adr/` directory
2. Remove `.agentic/agents/shared/guidelines/` directory (keep README.md)
3. Remove step 9 from FRAMEWORK_QUICK_START.md
4. Update CONTEXT_PACK.md to remove ADR reference
5. Revert spec/FEATURES.md (remove F-0101, F-0102)

## Related Files

- `spec/FEATURES.md` - Added F-0101, F-0102
- `spec/acceptance/F-0101.md` - Created
- `spec/acceptance/F-0102.md` - Created
- `docs/adr/README.md` - Created
- `docs/adr/001-claude-md-self-contained.md` - Created
- `.agentic/agents/shared/guidelines/*.md` - Created (5 modules)
- `CONTEXT_PACK.md` - Added ADR reference
- `.agentic/FRAMEWORK_QUICK_START.md` - Added step 9
- `CHANGELOG.md` - Added entries

## Notes

- This migration documents work done in session 2026-01-27
- ADR-001 was created AFTER the mistake was made (reactive documentation)
- Future: Create ADRs BEFORE implementing controversial decisions
