# Session Log

**Purpose**: Append-only conversation log for token-efficient session tracking.

**Why append-only**: Large files are expensive to read/rewrite. This file grows by appending, never rewriting.

**Usage**: Agents append entries at natural checkpoints (feature complete, decision made, significant progress).

---


## 2026-01-29 18:15 - Framework Quality Improvement - ag gateway commands

Implemented ag.sh gateway (start/implement/work/commit/done/verify/status/tools). Added profile detection (Core vs Core+PM). Updated all agent instruction files. Reduced CLAUDE.md 571→285 lines, guidelines 1297→336 lines. Validation: 128 passed, 2 failed (pre-existing install.sh issues), 1 warning.

- **version**: 0.12.2
- **model**: claude-opus-4-5
- **tests_passed**: 128
- **tests_failed**: 2
---


## 2026-01-30 21:56 - v0.13.0 Release Prep

Fixed install.sh non-interactive mode (all 130 tests pass). Updated CHANGELOG with v0.13.0 changes (ag gateway, docs cleanup, token reduction). Branch ready for PR/merge/tag.

- **0.13.0**: 0.13.0
---

