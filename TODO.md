# TODO

<!-- format: todo-v0.1.0 -->

Purpose: quick-capture inbox for ideas, tasks, and reminders. Triage to FEATURES.md or ISSUES.md when ready, or resolve directly.

## Inbox

<!-- Use: bash .agentic/tools/todo.sh add "description" -->

### T-0001: Progressive disclosure of complexity
- **Added**: 2026-02-18
- **Context**: Migrated from STATUS.md Backlog

### T-0002: Context7 MCP integration — test in real project
- **Added**: 2026-02-18
- **Context**: Migrated from STATUS.md Backlog

### T-0003: Automated CI for LLM tests via Claude CLI
- **Added**: 2026-02-18
- **Context**: Migrated from STATUS.md Backlog

### T-0007: Batch-verify or grandfather ~50 shipped features with fully unchecked acceptance criteria (F-0001 through F-0102 era). Recent features F-0125+ are properly checked
- **Added**: 2026-02-24

### T-0010: Implement multi-agent helper scripts (F-0108) — agents_active.sh, check_agent_conflicts.sh, sync_worktrees.sh referenced as TODO in multi_agent_coordination.md and doc-check.sh allowlist
- **Added**: 2026-02-24

### T-0012: Update FEATURES.md status: F-0136, F-0139, F-0140, F-0141 are shipped (PRs merged) but still marked in_progress
- **Added**: 2026-02-28

### T-0013: Close or formally assess F-0103 (Agent Mode Selection) — in_progress since v0.12.2, functionally complete. Either ship or document what's missing
- **Added**: 2026-02-28

### T-0014: Verify shipped acceptance criteria for F-0131, F-0132, F-0133, F-0134, F-0135 — check boxes that are actually done, identify genuinely incomplete items
- **Added**: 2026-02-28

### T-0015: F-XXXX: Structural enforcement for durable plan saving. ag implement should check that a plan exists in .agentic-journal/plans/ and warn/block if missing. Needs a setting (e.g. plan_persistence: off|warning|blocking) since not every project wants saved plans. The plan-review loop (ag plan with plan_review_enabled) especially needs this — reviewed plans are high-value artifacts that should never be lost to session-scoped .claude/plans/. Implementation: add check in ag implement, add setting to profiles.conf (discovery: off, formal: warning), add to STACK.template.md ## Settings. See 2026-02-28-document-architecture-effectiveness-review.md for context.
- **Added**: 2026-02-28

## Done

<!-- Resolved/triaged items move here with outcome -->

### T-0005: Migrate Python tools from read_profile() to get_setting()
- **Added**: 2026-02-24
- **Resolved**: 2026-02-24
- **Outcome**: Removed read_profile() wrappers from doctor.py and verify.py; both now call get_setting() directly. phase_detect.py, discover.py, render_proposals.py, continue_here.py already used get_setting().

### T-0011: Automatic git tag after PR merge
- **Added**: 2026-02-24
- **Resolved**: 2026-02-24
- **Outcome**: Added `git tag v$(cat VERSION) && git push origin v$(cat VERSION)` instruction to all 4 framework-dev instruction files.

### T-0004: Fix blocker.sh double-write bug in add command
- **Added**: 2026-02-18
- **Resolved**: 2026-02-24
- **Outcome**: Removed duplicate `>>` append; kept `sed` insert before `## Resolved`

### T-0006: Clean up HUMAN_NEEDED.md resolved items
- **Added**: 2026-02-24
- **Resolved**: 2026-02-24
- **Outcome**: Added Resolved dates and Outcomes to HN-0002 through HN-0011. All PRs confirmed merged.

### T-0008: Remove Cursor prompt stubs referencing nonexistent upgrade_profile.sh
- **Added**: 2026-02-24
- **Resolved**: 2026-02-24
- **Outcome**: Replaced with `ag set profile formal` (exists since F-0141)

### T-0009: Fix README.md:512 template placeholder
- **Added**: 2026-02-24
- **Resolved**: 2026-02-24
- **Outcome**: Replaced `[Your issue tracker]` with GitHub Issues link
