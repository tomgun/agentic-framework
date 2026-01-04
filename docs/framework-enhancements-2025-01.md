# Agentic AF: Enhancements from External Framework Analysis

**Source**: Analysis of plugin-freedom-system (audio plugin development framework)  
**Date**: 2025-01-04  
**Purpose**: Identify portable, generalizable improvements for Agentic AF

---

## Key Concepts to Adapt

### 1. **Claude Hooks System** (✓ High Priority)

**What it is**: Automated lifecycle hooks for Claude Desktop that run at specific points:
- `SessionStart.sh` - Validate environment at session start
- `UserPromptSubmit.sh` - Auto-inject context before processing user prompts
- `PostToolUse.sh` - Real-time validation after tool execution
- `PreCompact.sh` - Preserve critical state before context window compaction
- `Stop.sh` - Workflow integrity verification before ending session
- `SubagentStop.sh` - Contract validation after subagent handoff

**Adaptation for Agentic AF**:
- Create `.agentic/claude-hooks/` folder with hook scripts
- Document in `DEVELOPER_GUIDE.md` how to enable Claude hooks
- Provide templates that users can customize for their stack
- Examples:
  - `SessionStart.sh`: Check if dependencies need update, run `doctor.sh`
  - `UserPromptSubmit.sh`: Auto-inject `.continue-here.md` if exists
  - `PostToolUse.sh`: Run linter after code edits
  - `PreCompact.sh`: Save `JOURNAL.md` entry before context reset
  - `Stop.sh`: Remind to update `HUMAN_NEEDED.md` if blockers exist

**Benefits**:
- Automatic context injection (less manual "read X file" prompts)
- Real-time quality gates
- Prevents accidental state loss during compaction
- Enforces workflow discipline

**Implementation**:
- Priority: **High** (unique Claude feature, big UX win)
- Files to create: 6 hook templates + `hooks.json` + documentation
- Testing: Requires Claude Desktop with hooks enabled

---

### 2. **Skills-Based Architecture** (✓ Medium Priority)

**What it is**: Structured "skills" that agents can invoke, each with:
- Clear purpose and preconditions
- Defined input/output contracts
- References to detailed implementation docs
- Error recovery protocols
- Progress tracking checklists

**Current Agentic AF equivalent**:
- We have agent guidelines and checklists
- We have workflow documents
- We have spec templates

**Enhancements to consider**:
- Formalize "skills" as discrete, invokable workflows
- Add precondition checking (agent validates before proceeding)
- Add progress tracking (agent can self-check against checklist)
- Add error recovery protocols (what to do when things go wrong)

**Adaptation for Agentic AF**:
- Don't create a rigid skills system (we value flexibility)
- Instead: Enhance existing workflows with:
  - Explicit preconditions section
  - Progress tracking checklist
  - Error recovery decision tree
  - State contracts (what this workflow reads/writes)

**Example**: Enhance `.agentic/workflows/tdd_mode.md` with:
```markdown
## Preconditions
- [ ] Feature has acceptance criteria file
- [ ] Test framework is set up (check STACK.md)
- [ ] No failing tests in codebase

## Progress Tracking
- [ ] Acceptance criteria read and understood
- [ ] Test cases designed (happy path + edge cases)
- [ ] Tests written and failing (red phase)
- [ ] Implementation complete and tests passing (green phase)
- [ ] Code refactored (refactor phase)
- [ ] FEATURES.md updated

## Error Recovery
**If tests won't run**: Check STACK.md for test command, verify dependencies
**If tests pass immediately**: Tests are too weak, rewrite with realistic expectations
**If stuck in red phase**: Break problem into smaller pieces, write simpler test first
```

**Benefits**:
- More systematic agent behavior
- Self-checking prevents skipped steps
- Error recovery reduces escalations to humans

**Implementation**:
- Priority: **Medium** (incremental improvement to existing workflows)
- Files to update: All workflow documents
- Testing: Verify agents follow enhanced workflows

---

### 3. **Validation Cache** (✓ Low Priority)

**What it is**: Cache validation results to avoid re-running expensive checks

**Current Agentic AF**:
- We run `doctor.sh`, `verify.sh`, `validate_specs.py` on demand
- No caching of results

**Adaptation**:
- Add `validation-cache.sh` tool
- Cache results with timestamps and file hashes
- Invalidate cache when relevant files change
- Used by `doctor.sh` and `verify.sh` to skip redundant checks

**Example**:
```bash
# Check cache first
CACHE_FILE=".agentic/.cache/doctor-results.json"
if cache_valid "$CACHE_FILE"; then
  echo "Using cached validation results (1 minute old)"
  cat "$CACHE_FILE"
  exit 0
fi

# Run actual validation
run_doctor_checks > "$CACHE_FILE"
```

**Benefits**:
- Faster feedback loops
- Reduces redundant work
- Still catches real issues (cache invalidation on file change)

**Implementation**:
- Priority: **Low** (optimization, not critical)
- Complexity: Medium (need proper cache invalidation)
- Testing: Verify cache invalidates correctly

---

### 4. **Command-Based Interface** (✗ Not Applicable)

**What it is**: Slash commands like `/continue`, `/dream`, `/implement`

**Why not for Agentic AF**:
- Claude-specific feature (not portable to Cursor/Copilot)
- Our ready-to-use prompts already serve this purpose
- We prefer flexibility over rigid command structure

**Decision**: Skip this (already covered by `.agentic/prompts/`)

---

### 5. **Aesthetic/Design System Library** (✓ Consider for Visual Design Workflow)

**What it is**: Reusable design specifications for UI styling

**Relevance to Agentic AF**:
- We already have visual design workflow (wireframes, mockups, annotation)
- Could add: Design system templates for common UI patterns

**Adaptation**:
- Create `.agentic/support/design_systems/` with templates:
  - `modern-minimal.md` - Tailwind-style utility classes
  - `material-design.md` - Material Design spec adaptation
  - `ios-human-interface.md` - iOS HIG adaptation
- Reference from `visual_design_workflow.md`

**Benefits**:
- Consistent design language
- Faster UI implementation
- Reduces design decisions agents need to make

**Implementation**:
- Priority: **Low** (nice-to-have, not core feature)
- Files to create: 3-5 design system templates
- Testing: Use in example project

---

## Summary Recommendation

**Implement immediately** (High Priority):
1. ✅ **Claude Hooks System** - Big UX win for Claude users
   - Auto-inject context
   - Real-time quality gates
   - Prevent state loss

**Implement soon** (Medium Priority):
2. ✅ **Enhanced Workflows with Preconditions & Error Recovery**
   - Improve existing workflow documents
   - Add progress tracking, preconditions, error recovery
   - Makes agents more systematic and self-sufficient

**Consider later** (Low Priority):
3. **Validation Cache** - Optimization, not critical
4. **Design System Templates** - Nice-to-have for visual projects

**Skip** (Not Applicable):
- Command-based interface (Claude-specific, we have prompts instead)
- Skills as separate invocable entities (our workflows are already good)

---

## Implementation Plan

### Phase 1: Claude Hooks (Immediate)
1. Create `.agentic/claude-hooks/` directory
2. Create hook templates: SessionStart, UserPromptSubmit, PostToolUse, PreCompact, Stop
3. Create `hooks.json` with hook configuration
4. Document in `DEVELOPER_GUIDE.md` and `START_HERE.md`
5. Add to `prompts/claude/README.md`

### Phase 2: Enhanced Workflows (This Week)
1. Update `.agentic/workflows/tdd_mode.md` with preconditions/progress/errors
2. Update `.agentic/workflows/proactive_agent_loop.md`
3. Update `.agentic/checklists/*.md` with error recovery
4. Test with agents to verify improved behavior

### Phase 3: Optimizations (Later)
- Validation cache
- Design system templates

---

## Files to Create

**New folders**:
- `.agentic/claude-hooks/`

**New files**:
- `.agentic/claude-hooks/hooks.json`
- `.agentic/claude-hooks/SessionStart.sh`
- `.agentic/claude-hooks/UserPromptSubmit.sh`
- `.agentic/claude-hooks/PostToolUse.sh`
- `.agentic/claude-hooks/PreCompact.sh`
- `.agentic/claude-hooks/Stop.sh`
- `.agentic/claude-hooks/README.md`

**Files to update**:
- `.agentic/DEVELOPER_GUIDE.md` (add Claude Hooks section)
- `.agentic/START_HERE.md` (mention hooks for Claude users)
- `.agentic/prompts/claude/README.md` (document hooks)
- All workflow files in `.agentic/workflows/*.md` (add preconditions/progress/errors)
- All checklist files in `.agentic/checklists/*.md` (add error recovery)

---

## Version Bump

After Phase 1 (Claude Hooks): `0.3.4` → `0.3.5`  
After Phase 2 (Enhanced Workflows): `0.3.5` → `0.4.0` (significant improvements to agent behavior)


