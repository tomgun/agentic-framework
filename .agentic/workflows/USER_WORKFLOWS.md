# User Workflows Guide

**Purpose**: Clear, step-by-step workflows for humans working with agents in Core+PM mode.

## Quick Reference: What Can I Do?

### Working with Features
- ✅ **Add new features** → See [Adding a New Feature](#adding-a-new-feature)
- ✅ **Update feature specs** → See [Updating Feature Specifications](#updating-feature-specifications)
- ✅ **Check feature status** → See [Checking Project Status](#checking-project-status)
- ✅ **Accept completed features** → See [Accepting a Feature](#accepting-a-feature)

### Working with Specs
- ✅ **Edit specs directly** → Yes! Agents will pick up your changes. See [Direct Spec Editing](#direct-spec-editing)
- ✅ **Add acceptance criteria** → See [Adding Acceptance Criteria](#adding-acceptance-criteria)
- ✅ **Update requirements** → See [Updating Requirements](#updating-requirements)

### Development Workflows
- ✅ **TDD workflow** → See [Test-Driven Development](#test-driven-development-workflow)
- ✅ **Sequential agents** → See [Using Sequential Agent Pipeline](#using-sequential-agent-pipeline)
- ✅ **Standard dev loop** → See [Standard Development Workflow](#standard-development-workflow)

---

## Core+Product Mode Overview

When working in **Core+Product** profile, you have:

### Key Documents
| Document | Purpose | Who Updates |
|----------|---------|-------------|
| `PRODUCT.md` | Vision, capabilities, rough plan | Human + Agent |
| `STATUS.md` | Current focus, next up, roadmap | Mostly Agent |
| `JOURNAL.md` | Session-by-session log | Agent |
| `spec/FEATURES.md` | Feature registry with F-#### IDs | Human + Agent |
| `spec/PRD.md` | Requirements, user stories | Mostly Human |
| `spec/TECH_SPEC.md` | Architecture decisions | Human + Agent |
| `spec/acceptance/F-####.md` | Pass/fail criteria per feature | Human + Agent |

### Core Principle: Humans and Agents Both Edit Specs

**✅ You can directly edit any spec file** - agents will:
- Pick up your changes at session start
- Honor your priorities in `STATUS.md`
- Implement features based on your acceptance criteria
- Ask questions if something is unclear

---

## Adding a New Feature

### Option 1: Add to FEATURES.md Yourself (Recommended)

**When**: You know exactly what you want.

**Steps**:
1. Open `spec/FEATURES.md`
2. Choose next available feature ID (e.g., `F-0006`)
3. Add to feature index:
   ```markdown
   ## Feature index
   - F-0001: API Client
   - F-0002: Caching
   - F-0006: New Feature Name  <!-- Your new feature -->
   ```
4. Add full feature entry (copy template from existing features):
   ```markdown
   ## F-0006: New Feature Name
   - Parent: none
   - Dependencies: F-0001, F-0002  <!-- If depends on others -->
   - Complexity: M  <!-- S/M/L -->
   - Status: planned
   - PRD: spec/PRD.md#requirements
   - Requirements: R-0010  <!-- If you have requirement IDs -->
   - NFRs: Performance, Security  <!-- If relevant -->
   - Acceptance: spec/acceptance/F-0006.md
   - Verification:
     - Accepted: no
     - Accepted at: 
   - Implementation:
     - State: none
     - Code: 
   - Tests:
     - Test strategy: unit + integration
     - Unit: todo
     - Integration: todo
     - Acceptance: todo
     - Perf/realtime: n/a
   - Technical debt: none
   - Lessons/caveats:
   - Notes:
     - Add implementation details here
     - Any constraints or considerations
   ```

5. Create acceptance criteria file: `spec/acceptance/F-0006.md`
   ```markdown
   # Acceptance: F-0006 - New Feature Name
   
   ## Happy path
   - [ ] User can do X
   - [ ] System responds with Y
   - [ ] Data is saved to Z
   
   ## Edge cases
   - [ ] Handles empty input gracefully
   - [ ] Shows error for invalid data
   
   ## Non-functional
   - [ ] Response time < 2s
   - [ ] Works in all supported browsers
   ```

6. Tell your agent:
   ```
   "I've added F-0006 to FEATURES.md. Please review the acceptance 
   criteria in spec/acceptance/F-0006.md and implement it using TDD."
   ```

**What happens next**:
- Agent reads `spec/FEATURES.md` and sees F-0006
- Agent reads acceptance criteria from `spec/acceptance/F-0006.md`
- Agent writes tests first (TDD), then implements
- Agent updates `FEATURES.md` as work progresses (Implementation state, Tests, etc.)
- Agent updates `STATUS.md` and `JOURNAL.md`

---

### Option 2: Ask Agent to Add Feature

**When**: You have an idea but want agent help with structure.

**Steps**:
1. Tell your agent:
   ```
   "I want to add a new feature: [describe what it does]. 
   Can you add it to FEATURES.md with proper acceptance criteria?"
   ```

2. Agent will:
   - Choose next available F-#### ID
   - Add entry to `spec/FEATURES.md`
   - Create `spec/acceptance/F-####.md` with initial criteria
   - Ask you to review before implementing

3. Review and adjust:
   - Check `spec/FEATURES.md` for the new feature
   - Review/edit `spec/acceptance/F-####.md`
   - Tell agent: "Looks good, implement it" or "Let me adjust the criteria first"

---

## Updating Feature Specifications

### Scenario: Feature is already planned, you want to change acceptance criteria

**Steps**:
1. Edit `spec/acceptance/F-####.md` directly:
   ```markdown
   # Acceptance: F-0006 - New Feature
   
   ## Happy path
   - [ ] User can do X (NEW: with validation)
   - [ ] System responds with Y (CHANGED from previous)
   - [ ] Data is saved to Z
   ```

2. Tell your agent:
   ```
   "I've updated acceptance criteria for F-0006. Please review and 
   update the implementation/tests to match."
   ```

3. Agent will:
   - Read updated acceptance criteria
   - Identify what changed
   - Update tests first (if TDD mode)
   - Update implementation
   - Mark criteria as complete in acceptance file

**✅ Agents reliably pick up human spec edits** because:
- They read specs at session start
- They check for human edits (see `agent_operating_guidelines.md`)
- They honor your changes as "source of truth"

---

## Direct Spec Editing

**You can edit ANY spec file directly**. Agents are trained to:
- Read specs at every session start
- Check for human modifications
- Honor your changes as the source of truth
- Ask questions if something is ambiguous

### Common Spec Edits

**Adding a requirement** (`spec/PRD.md`):
```markdown
## R-0010: New Requirement
As a user, I want to export data to CSV so I can analyze it in Excel.

### Acceptance
- User clicks "Export" button
- System generates CSV file
- File downloads to user's device
```

**Updating a tech decision** (`spec/TECH_SPEC.md`):
```markdown
## Database Choice

**Decision**: Use PostgreSQL instead of SQLite (updated 2026-01-04)

**Rationale**: Need full-text search and better concurrency.

**Migration plan**: Write migration script in `migrations/001_sqlite_to_postgres.sql`
```

**Marking feature as priority** (`STATUS.md`):
```markdown
## Current focus
- F-0006: Export to CSV (HIGH PRIORITY - user request)
```

---

## Checking Project Status

### Quick Status Check

Run:
```bash
bash .agentic/tools/brief.sh
```

Output shows:
- Current focus from `STATUS.md`
- Features in progress vs planned vs shipped
- Recent work from `JOURNAL.md`

### Detailed Feature Report

Run:
```bash
bash .agentic/tools/report.sh
```

Output shows:
- All features with status
- Missing acceptance criteria
- Test coverage gaps
- Acceptance status

### Verification Check

Run:
```bash
bash .agentic/tools/verify.sh
```

Output shows:
- Missing acceptance files
- Broken cross-references
- Test failures

---

## Accepting a Feature

When agent says "F-0006 is complete", you should:

### Manual Acceptance

1. **Test it yourself**:
   ```bash
   # Run the software, try the feature
   # Check acceptance criteria from spec/acceptance/F-0006.md
   ```

2. **If it works**, tell agent:
   ```
   "F-0006 looks good, mark it as accepted"
   ```

3. Agent will:
   - Update `spec/FEATURES.md`:
     ```markdown
     - Verification:
       - Accepted: yes
       - Accepted at: 2026-01-03
     ```
   - Update `STATUS.md` if needed
   - Log in `JOURNAL.md`

### Automated Acceptance (if tests exist)

Run:
```bash
bash .agentic/tools/accept.sh F-0006
```

This marks F-0006 as accepted if all tests pass.

---

## Test-Driven Development Workflow

**If `development_mode: tdd` in STACK.md** (RECOMMENDED):

### How It Works

1. **You or agent** adds feature to `spec/FEATURES.md` with acceptance criteria
2. **Agent writes tests FIRST** (failing, red)
3. **Agent implements code** to make tests pass (green)
4. **Agent refactors** if needed
5. **Agent updates specs** and commits

### Your Role

- Define clear acceptance criteria in `spec/acceptance/F-####.md`
- Agent will convert those into tests before writing code
- Review tests first: "Show me the tests for F-0006"
- Approve implementation after tests pass

### Example Interaction

```
You: "Add F-0007: User can filter tasks by status"

Agent: "I've added F-0007 to FEATURES.md. Here are the acceptance criteria 
I drafted - please review:
- User can select status filter (All, Active, Complete)
- Task list updates immediately on selection
- Filter state persists in URL

Should I proceed with tests?"

You: "Looks good, add tests"

Agent: [writes failing tests]
"I've added 5 tests for F-0007, all failing (red). Ready to implement?"

You: "Yes, go ahead"

Agent: [implements feature, tests pass]
"All tests green! F-0007 is complete. Review?"

You: "Looks good, commit it"
```

---

## Using Sequential Agent Pipeline

**If `pipeline_enabled: yes` in STACK.md**:

### What It Does

Instead of one agent doing everything, **specialized agents work sequentially**:
1. **Research Agent** - Investigate technologies/approaches
2. **Planning Agent** - Define feature and acceptance criteria
3. **Test Agent** - Write failing tests (TDD)
4. **Implementation Agent** - Make tests pass
5. **Build Agent** - Verify build/bundle
6. **Review Agent** - Code review and quality check
7. **Spec Update Agent** - Update FEATURES.md, STATUS.md, JOURNAL.md
8. **Documentation Agent** - Update docs
9. **Git Agent** - Commit with human approval

### When to Use

✅ **Use for**:
- Complex features (>5 files, multiple components)
- Features requiring research
- High-stakes features (payments, security)

❌ **Skip for**:
- Simple bug fixes
- Documentation-only changes
- Tiny features (1-2 files)

### How to Use

**Option 1: Manual mode** (you control handoffs):
```yaml
# In STACK.md
pipeline_enabled: yes
pipeline_mode: manual
pipeline_handoff_approval: yes
```

Then:
```
You: "Planning Agent: Plan F-0008 (user authentication)"
[Planning Agent works, then asks for handoff approval]

You: "Looks good, hand off to Test Agent"
[Test Agent writes tests, then asks for handoff]

You: "Approved, hand off to Implementation Agent"
[Implementation Agent codes, then asks for handoff]
# ... etc
```

**Option 2: Auto mode** (agents hand off automatically):
```yaml
pipeline_enabled: yes
pipeline_mode: auto
pipeline_handoff_approval: yes  # Still asks for approval between agents
```

Then:
```
You: "Planning Agent: Plan F-0008 (user authentication)"
[Agent automatically hands off through pipeline, asking approval at each step]
```

---

## Standard Development Workflow

**If `development_mode: standard` or TDD not enabled**:

1. **Pick feature**: Check `STATUS.md` for "Current focus"
2. **Read acceptance**: Read `spec/acceptance/F-####.md`
3. **Implement**: Agent writes code
4. **Write tests**: Agent adds tests (after code, not before)
5. **Update specs**: Agent updates `FEATURES.md`, `STATUS.md`
6. **Commit**: Agent commits with your approval

**Your role**:
- Define clear acceptance criteria
- Review implementation
- Test manually if needed
- Approve commits

---

## Common Questions

### Q: Can I edit FEATURES.md myself?
**A**: Yes! Agents are trained to pick up your changes. Edit freely.

### Q: Will agents overwrite my changes?
**A**: No. Agents treat human edits as source of truth. They might add information (like test status) but won't delete your content.

### Q: How do I change feature priority?
**A**: Edit `STATUS.md` "Current focus" or tell your agent: "Make F-0006 the priority"

### Q: Can I skip acceptance criteria?
**A**: Not recommended in Core+PM mode. Acceptance criteria are how agents know when "done" is done. At minimum: 3-5 bullet points.

### Q: What if acceptance criteria are wrong?
**A**: Edit `spec/acceptance/F-####.md` anytime. Tell agent: "I updated F-0006 acceptance, please adjust implementation"

### Q: How do I know what's implemented?
**A**: Run `bash .agentic/tools/report.sh` or check `spec/FEATURES.md` "Implementation: State" field

### Q: What if agent gets stuck?
**A**: Agent should add entry to `HUMAN_NEEDED.md`. Check there for blockers.

### Q: Can I work on code without agent?
**A**: Yes! Just update `FEATURES.md` status and `JOURNAL.md` when done so agent knows what changed.

---

## Best Practices

### 1. Start with Clear Acceptance Criteria
❌ **Bad**: "User can search"
✅ **Good**: 
- User types in search box
- Results appear within 2s
- Shows "No results" if nothing found
- Supports partial matches

### 2. Keep Features Small
❌ **Bad**: F-0010: Complete admin dashboard (20 sub-features)
✅ **Good**: 
- F-0010: Admin login
- F-0011: Admin user list
- F-0012: Admin user edit
- (etc, one feature per capability)

### 3. Update Specs When You Learn Something
If you realize a feature needs more work:
1. Edit `spec/acceptance/F-####.md`
2. Tell agent: "F-0006 needs updates, see acceptance criteria"

### 4. Review Regularly
Run `bash .agentic/tools/verify.sh` weekly to catch:
- Missing acceptance files
- Out-of-sync specs
- Test gaps

### 5. Use PRODUCT.md for Vision
`PRODUCT.md` is your "why we're building this" doc.
`spec/FEATURES.md` is your "what exactly we're building" doc.

Keep both in sync but distinct in purpose.

---

## Troubleshooting

### Agent doesn't see my spec changes
**Fix**: Tell agent explicitly:
```
"Read spec/FEATURES.md and spec/acceptance/F-0006.md - I made updates"
```

### Agent keeps saying feature is done but acceptance not met
**Fix**: Check `spec/acceptance/F-####.md`:
- Are criteria actually met? Test manually
- If yes: Tell agent "mark F-#### as accepted"
- If no: Tell agent "F-#### still doesn't meet criteria [X], please fix"

### Too many features, losing track
**Fix**: 
1. Run `bash .agentic/tools/report.sh`
2. Focus on STATUS.md "Current focus" (1-3 features max)
3. Mark features as `deprecated` if no longer needed

### Agent ignores TDD mode
**Fix**: Check `STACK.md`:
```yaml
development_mode: tdd
```
If missing, add it and tell agent: "Please follow TDD from now on"

---

## Next Steps

After reading this guide:
1. ✅ Review your project's `STATUS.md` - is current focus clear?
2. ✅ Check `spec/FEATURES.md` - are all features documented?
3. ✅ Run `bash .agentic/tools/verify.sh` - any gaps?
4. ✅ Try adding a new feature yourself using [Adding a New Feature](#adding-a-new-feature)

For more details:
- **TDD workflow**: `.agentic/workflows/tdd_mode.md`
- **Sequential agents**: `.agentic/workflows/sequential_agent_specialization.md`
- **Git workflow**: `.agentic/workflows/git_workflow.md`
- **Agent guidelines**: `.agentic/agents/shared/agent_operating_guidelines.md`

