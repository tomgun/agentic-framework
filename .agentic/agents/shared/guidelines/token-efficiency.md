# Token Efficiency Guidelines

**Purpose**: Minimize token usage while maintaining quality.

---

## Delegate to Specialized Agents

| Task | Spawn Agent | Model Tier | Savings |
|------|-------------|------------|---------|
| Codebase exploration | `explore-agent` | Cheap/fast | 83% |
| Documentation lookup | `research-agent` | Cheap/fast | 60% |
| Implementation | `implementation-agent` | Mid-tier | Focused context |
| Test writing | `test-agent` | Mid-tier | Isolated work |
| Code review | `review-agent` | Mid-tier | Fresh perspective |

### Context Handoff Rules

**DO pass to subagent:**
- Feature ID (F-####)
- Acceptance criteria file
- 3-5 relevant source files
- STACK.md build/test commands

**DO NOT pass:**
- Full conversation history
- Unrelated code/modules
- Previous session context
- Large documentation files

### Using context-for-role.sh

```bash
# Get minimal context for a role
bash .agentic/tools/context-for-role.sh implementation-agent F-0042 --dry-run

# Shows token budget and files to load
```

---

## Token-Efficient Scripts (MANDATORY)

**NEVER edit these files directly - use scripts instead:**

| File to Update | USE THIS SCRIPT |
|----------------|-----------------|
| JOURNAL.md | `bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers"` |
| STATUS.md | `bash .agentic/tools/status.sh focus "Task"` |
| HUMAN_NEEDED.md | `bash .agentic/tools/blocker.sh add "Title" "type" "Details"` |
| spec/FEATURES.md | `bash .agentic/tools/feature.sh F-#### status shipped` |

**Why scripts?**
- Scripts append/update fields without reading entire files
- 10-40x cheaper than read-edit-write cycles
- Consistent formatting
- Proper timestamps

---

## Reading Strategies

### Lazy Loading
- Don't read entire files upfront
- Read sections as needed
- Use `context-for-role.sh` for role-specific context

### Section Extraction
```bash
# Read only the build section from STACK.md
awk '/^## Build/,/^## /' STACK.md
```

### File Priorities
1. **Always read**: STATUS.md, CONTEXT_PACK.md (small, essential)
2. **Read if needed**: Acceptance criteria, STACK.md sections
3. **Avoid unless required**: Full source files, JOURNAL.md history

---

## Quick Checklist References

| Task | Read This First |
|------|-----------------|
| Starting a feature | `checklists/feature_start.md` |
| Before any commit | `checklists/before_commit.md` |
| Marking done | `checklists/feature_complete.md` |
| Session start | `checklists/session_start.md` |
| Session end | `checklists/session_end.md` |

---

## Token Budget Guidelines

| Agent Type | Token Budget | Use Case |
|------------|--------------|----------|
| Research | ~3,000 | Lookups, exploration |
| Implementation | ~5,000 | Coding with context |
| Review | ~6,000 | Code + standards |
| Orchestrator | ~2,000 | Coordination only |

See `.agentic/agents/context-manifests/` for all role budgets.
