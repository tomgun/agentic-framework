# Direct Editing Workflow

**You can edit spec files directly without talking to an agent.** The agent will pick up your changes when it starts the next session.

## ⚠️ Follow the Schema

**All spec edits (human or agent) must follow the defined schema**: [`.agentic/spec/SPEC_SCHEMA.md`](.agentic/spec/SPEC_SCHEMA.md)

This ensures:
- Valid status values (`planned`, `in_progress`, `shipped`, `deprecated`)
- Correct field names and formats
- Consistent cross-references (`F-####`, `NFR-####`, `R-####`)
- Tools can validate your edits

**Quick reference**: See "Quick Reference Card" section in `SPEC_SCHEMA.md` for valid values.

## Why Edit Directly?

Sometimes it's faster to:
- Add a new feature to `FEATURES.md` yourself
- Update priorities in `STATUS.md`
- Write acceptance criteria in a new `spec/acceptance/F-####.md` file
- Create a task file

Instead of describing what you want to an agent, **just write it in the spec**.

## Common Direct Edits

### 1. Add a New Feature

**File**: `spec/FEATURES.md`

Copy the template from the top of the file and fill in:

```markdown
## F-0015: User profile editing
- Parent: none
- Dependencies: F-0001 (complete)  # If depends on other features
- Complexity: M
- Status: planned
- PRD: spec/PRD.md#user-profiles
- Requirements: R-0008
- NFRs: none
- Acceptance: spec/acceptance/F-0015.md
- Verification:
  - Accepted: no
- Implementation:
  - State: none
  - Code:
- Tests:
  - Test strategy: unit
  - Unit: todo
  - Integration: n/a
  - Acceptance: todo
- Technical debt:
- Lessons/caveats:
- Notes:
```

**Then**: Tell the agent "Implement F-0015" or add to STATUS.md "Next up"

### 2. Write Acceptance Criteria

**File**: `spec/acceptance/F-0015.md`

```markdown
# F-0015: User profile editing

## Acceptance Criteria

### AC1: User can edit their profile
- User sees "Edit Profile" button on profile page
- Clicking opens edit form with current values pre-filled
- Form includes: name, email, bio, avatar

### AC2: Validation
- Name: required, 2-100 characters
- Email: required, valid format
- Bio: optional, max 500 characters
- Avatar: optional, image file, max 2MB

### AC3: Save and Cancel
- "Save" button updates profile
- Success message shown after save
- "Cancel" button discards changes
- Changes persist across sessions

## Test Notes
- Unit test validation rules
- Integration test save/load flow
- E2E test full user journey
```

**Then**: Agent will reference this when implementing

### 3. Update Priorities

**File**: `STATUS.md`

Edit the "Next up" section:

```markdown
## Next up
- F-0015 User profile editing (high priority)
- F-0012 Admin dashboard
- F-0008 Export data
```

**Then**: Agent will see this order when picking next work

### 4. Add to Backlog

**File**: `HUMAN_NEEDED.md` or create a task file

For items needing more thought before implementation:

```markdown
### HN-0005: Choose notification system
- **Type**: decision
- **Context**: Need to notify users of events
- **Options**:
  - Option A: Email only (simple, might miss urgent items)
  - Option B: In-app + email (better UX, more complex)
  - Option C: Add push notifications (best UX, most work)
- **Impact**: Blocks F-0020, F-0021
```

Or create a task:

```bash
bash .agentic/tools/task.sh "Evaluate notification systems"
```

### 5. Record a Decision (ADR)

**File**: `spec/adr/ADR-0005-use-postgresql.md`

```markdown
# ADR-0005: Use PostgreSQL for primary database

## Status
Accepted

## Context
Need to choose database for production.

## Decision
Use PostgreSQL 15+.

## Options considered
- PostgreSQL: Strong consistency, JSON support, proven
- MongoDB: Flexible schema, but consistency concerns
- MySQL: Considered, but PostgreSQL has better JSON

## Consequences
- Positive: Strong ACID guarantees, great tooling
- Negative: Slightly more complex setup than SQLite

## Follow-ups
- Set up migrations
- Add connection pooling
```

**Then**: Agent sees this when implementing database code

### 6. Update Context

**File**: `CONTEXT_PACK.md`

Add information you learned:

```markdown
## Where to look first (map)
- Entry points:
  - `app/page.tsx` (home page)
  - `app/api/` (API routes)
  - `lib/db.ts` (database client) ← YOU ADDED THIS
```

**Then**: Agent uses this to find code faster

## Agent Picks Up Changes

When the agent starts a session, it:

1. Reads `CONTEXT_PACK.md`, `STATUS.md`, `JOURNAL.md`
2. Reads `spec/FEATURES.md` for current features
3. **Sees your additions** and incorporates them
4. Works based on what you wrote

## Best Practices

### DO edit directly:
✅ Adding new features to FEATURES.md
✅ Writing acceptance criteria
✅ Updating STATUS.md priorities
✅ Creating task files
✅ Recording decisions in ADRs
✅ Adding references to REFERENCES.md
✅ Noting issues in STATUS.md "Known issues"

### Let agent handle:
🤖 Updating feature implementation status
🤖 Filling in "Code:" paths as it implements
🤖 Updating test status
🤖 Appending to JOURNAL.md
🤖 Replacing "(Not yet created)" placeholders

### Collaborate on:
👥 TECH_SPEC.md architecture (you plan, agent updates)
👥 NFR.md (you define constraints, agent ensures compliance)
👥 HUMAN_NEEDED.md (you add, agent implements resolutions)

## Example Workflow

**You** (directly editing files):
1. Add F-0015 to `spec/FEATURES.md`
2. Write `spec/acceptance/F-0015.md` with criteria
3. Add "F-0015 User profile editing" to STATUS.md "Next up"
4. Commit: `git commit -m "Add F-0015 user profile editing to backlog"`

**Agent** (next session):
1. Reads STATUS.md, sees F-0015 is next
2. Reads spec/FEATURES.md for F-0015 details
3. Reads spec/acceptance/F-0015.md for criteria
4. Implements feature
5. Updates FEATURES.md with code paths and test status
6. Appends to JOURNAL.md what was accomplished
7. Commits: `git commit -m "Implement F-0015: user profile editing"`

**Both work on the same specs, each contributing what they do best.**

## When to Edit Directly vs. Talk to Agent

### Edit directly when:
- You know exactly what you want
- You're defining requirements/acceptance criteria
- You're planning features for the backlog
- You're changing priorities
- You're recording a decision you made

### Talk to agent when:
- You need implementation done
- You want agent to research/explore options
- You need help understanding existing code
- You want agent to update docs based on code changes
- You're unsure of the best approach

## Tools Support This

Check what you added:
```bash
cat spec/FEATURES.md           # See all features including yours
bash .agentic/tools/report.sh   # Status summary
bash .agentic/tools/deps.sh     # Check dependencies
```

The framework is **designed for both humans and agents to edit specs**.

