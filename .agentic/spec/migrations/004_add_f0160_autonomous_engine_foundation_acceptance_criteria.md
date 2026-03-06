<!-- migration-id: 004 -->
<!-- date: 2026-03-06 -->
<!-- author: Tomas -->
<!-- type: feature -->

# Migration 004: Add F-0160 Autonomous Engine Foundation

## Context & Why

New feature: autonomous workflow engine foundation. Adds control plane, settings generation,
AC loading/decomposition. Also registers F-0161/F-0162/F-0163 as planned features.

## Changes

### Features Added

- F-0160: Autonomous Engine Foundation (shipped, 35 ACs)
- F-0161: Autonomous Verify Mode (planned)
- F-0162: Autonomous Task Mode (planned)
- F-0163: Autonomous Crunch Mode (planned)

## Related Files

- `.agentic/spec/acceptance/F-0160.md` - New (35 acceptance criteria)
- `.agentic/spec/acceptance/F-0161.md` - New (planned stub)
- `.agentic/spec/acceptance/F-0162.md` - New (planned stub)
- `.agentic/spec/acceptance/F-0163.md` - New (planned stub)
- `.agentic/lib/auto/` - New engine module
