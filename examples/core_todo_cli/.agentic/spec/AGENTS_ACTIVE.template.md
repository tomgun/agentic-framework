# Active Agents (Template)

**Purpose**: Coordinate multiple AI agents working simultaneously on different features.

**When to use**: Multi-agent development with Git worktrees (see `.agentic/workflows/multi_agent_coordination.md`)

---

Last sync: <!-- YYYY-MM-DD HH:MM -->

## Agent 1 (agent-id-1)
- **Feature**: <!-- F-#### (feature name) -->
- **Branch**: <!-- feature/F-#### -->
- **Worktree**: <!-- /path/to/worktree -->
- **Status**: <!-- in_progress | blocked | ready_for_review | pr_created | complete -->
- **Phase**: <!-- planning | implementing | testing | reviewing | waiting | done -->
- **Started**: <!-- YYYY-MM-DD HH:MM -->
- **Last update**: <!-- YYYY-MM-DD HH:MM -->
- **Next sync**: <!-- YYYY-MM-DD HH:MM (update every 15-30 min) -->
- **Blocking**: <!-- F-#### (features that depend on this) -->
- **Blocked by**: <!-- F-#### (features this depends on) -->
- **Files editing**: <!-- comma-separated list of files currently being edited -->
- **PR**: <!-- #123 (if created) -->
- **Notes**: <!-- brief status update, blockers, progress notes -->

## Agent 2 (agent-id-2)
- **Feature**: <!-- F-#### (feature name) -->
- **Branch**: <!-- feature/F-#### -->
- **Worktree**: <!-- /path/to/worktree -->
- **Status**: <!-- in_progress | blocked | ready_for_review | pr_created | complete -->
- **Phase**: <!-- planning | implementing | testing | reviewing | waiting | done -->
- **Started**: <!-- YYYY-MM-DD HH:MM -->
- **Last update**: <!-- YYYY-MM-DD HH:MM -->
- **Next sync**: <!-- YYYY-MM-DD HH:MM -->
- **Blocking**: <!-- none or F-#### -->
- **Blocked by**: <!-- none or F-#### (reason) -->
- **Files editing**: <!-- list -->
- **PR**: <!-- #123 or n/a -->
- **Notes**: <!-- status -->

<!-- Add more agent entries as needed -->

---

## Merge Queue

Priority order for merging PRs (respects dependencies):

1. <!-- F-#### (Agent N) - Status: reason -->
2. <!-- F-#### (Agent N) - Status: reason -->
3. <!-- F-#### (Agent N) - Status: reason -->

---

## Shared File Locks (Prevent Conflicts)

Agents lock shared files before editing to prevent simultaneous changes:

- `spec/FEATURES.md`: <!-- Agent N editing (reason) | No locks -->
- `CONTEXT_PACK.md`: <!-- Agent N editing (reason) | No locks -->
- `spec/TECH_SPEC.md`: <!-- Agent N editing (reason) | No locks -->
- `spec/NFR.md`: <!-- Agent N editing (reason) | No locks -->

**Protocol**: 
1. Check this section before editing shared files
2. Add lock entry before editing
3. Edit quickly (< 5 minutes)
4. Remove lock after committing

---

## Recent Merges

Track recently completed features:

- <!-- YYYY-MM-DD HH:MM: F-#### (feature name) merged by Agent N -->
- <!-- YYYY-MM-DD HH:MM: F-#### (feature name) merged by Agent N -->

---

## Known Conflicts

Document any detected conflicts or coordination issues:

- <!-- None currently -->
<!-- - Agent 1 and Agent 2: Both editing User type (lib/types.ts) - coordinating on F-#### -->

---

## Coordination Notes

Ad-hoc notes for inter-agent communication:

- <!-- Example: "Agent 2: F-0042 auth API is ready at /api/auth/validate" -->
- <!-- Example: "All agents: New shared type added in lib/types.ts - please pull main" -->

---

## Agent Protocol Reminders

**Every agent must:**
1. **Read this file** at session start
2. **Update your entry** every 15-30 minutes (Last update, Phase, Notes)
3. **Check for blockers** before starting work (Blocked by)
4. **Lock shared files** before editing (add to Shared File Locks)
5. **Update merge queue** when PR is ready
6. **Notify dependent agents** when your work completes (add to Coordination Notes)

**See full protocol**: `.agentic/workflows/multi_agent_coordination.md`

