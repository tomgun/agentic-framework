<!-- migration-id: XXX -->
<!-- date: YYYY-MM-DD -->
<!-- author: agent-name | human-name -->
<!-- type: feature | refactor | bugfix | deprecation | architectural -->

# Migration XXX: [Brief Title]

## Context & Why

[Brief explanation of the problem or opportunity this addresses]

**Business need**: [Why does this matter to users/stakeholders?]
**Technical driver**: [What technical factors motivated this?]

## Changes

[Atomic list of specific changes made to specs]

### Features Added
- F-XXXX: [Feature Name]
  - [Specific change 1]
  - [Specific change 2]

### Features Modified
- F-YYYY: [Existing Feature Name]
  - [What changed and why]

### Features Deprecated
- F-ZZZZ: [Feature to remove]
  - [Why deprecated, migration path]

### Other Spec Changes
- Updated NFR-XXXX: [Non-functional requirement change]
- Updated TECH_SPEC.md: [Architecture change]
- Updated PRD.md: [Requirements change]

## Dependencies

- **Requires**: Migration XXX ([What must exist first])
- **Blocks**: Migration YYY ([What depends on this])
- **Related**: ADR-XXXX, Migration ZZZ

## Acceptance Criteria

[How to verify this change works]

- [ ] [Specific testable criterion 1]
- [ ] [Specific testable criterion 2]
- [ ] [Specific testable criterion 3]

## Implementation Notes

[Guidance for developers implementing this]

- [Technology/library choices]
- [Architecture patterns to follow]
- [Key considerations]
- [Potential pitfalls to avoid]

## Rollback Plan

[If this needs to be undone, how?]

- [Step 1: What to remove]
- [Step 2: What to restore]
- [Step 3: Verification]

## Related Files

[Files affected by this migration]

- `spec/FEATURES.md` - [What changed]
- `spec/NFR.md` - [What changed]
- `spec/TECH_SPEC.md` - [What changed]
- `spec/acceptance/F-XXXX.md` - [Created/updated]

## Notes

[Additional context, links, references]

- [Link to research]
- [Discussion references]
- [User feedback]

