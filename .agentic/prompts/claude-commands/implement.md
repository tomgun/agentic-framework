---
command: /implement
description: Implement a feature using TDD
---

I want to implement a feature.

Please:

1. Ask which feature (F-####) if not specified
2. Read acceptance criteria from `spec/acceptance/F-####.md` (Core+PM) or `PRODUCT.md` (Core)
3. Follow TDD workflow from `.agentic/workflows/tdd_mode.md`:
   - Write failing test FIRST
   - Implement minimal code to pass
   - Refactor for clarity
   - Repeat for next behavior
4. Follow feature implementation checklist: `.agentic/checklists/feature_implementation.md`
5. Update FEATURES.md or PRODUCT.md as you progress
6. Add code annotations (`@feature F-####`)

**If stuck**: Use error recovery guidance from `tdd_mode.md`

**Usage**:
- `/implement` - I'll specify the feature
- `/implement F-0010` - Implement specific feature

