# JOURNAL - Examples and Guidelines

**Purpose**: This file contains examples and format guidelines for using `JOURNAL.md`. Keep this in `.agentic/` for reference.

---

## Format Options

**Two formats supported (choose one and be consistent):**

### Format A: Simple (recommended for most projects)
```markdown
### Session: YYYY-MM-DD HH:MM
**Why**: Problem being solved or motivation for this work
**What changed**:
- Outcome-oriented descriptions (what the project can do now, not what files were edited)
**Next steps**:
- Immediate actions
**Blockers**:
- Issues or decisions needed
```

### Format B: Detailed (for complex sessions with lessons)
```markdown
## YYYY-MM-DD HH:MM - Description (Session N)

**Feature**: F-####

**What was done:**
- Items completed

**Tests added:**
- Tests implemented

**What's next:**
- Immediate actions

**Blockers:**
- Issues or decisions needed

**Lessons:**
- Learnings from this session
```

**Both formats work with framework tools.** Choose based on preference:
- Format A: Simpler, less structure
- Format B: More detailed, better for complex sessions

---

## Example Entries

### Format A Example

### Session: 2025-12-31 14:30

**Why**: App data was lost on page refresh — users had to re-enter everything.

**What changed**:
- App now persists state to localStorage with automatic quota handling
- Gracefully degrades when storage is full (warns user, continues working)

**Next steps**:
- Safari private mode fallback (throws on access, not just quota)
- Integration test for full save/load cycle

**Blockers**:
- Safari private mode throws on localStorage access — need research on detection strategy

---

### Format B Example

## 2025-12-31 14:30 - Authentication Implementation (Session 5)

**Feature**: F-0012 (User Authentication)

**What was done:**
- Implemented JWT token generation and validation
- Added password hashing with bcrypt
- Created login and signup endpoints
- Added rate limiting middleware

**Tests added:**
- Unit tests for token generation/validation (10 test cases)
- Integration tests for auth endpoints
- Security tests for SQL injection and XSS

**What's next:**
- Implement refresh token mechanism
- Add email verification workflow
- Set up session management

**Blockers:**
- Need decision on token expiry time (1hr vs 24hr) - add to HUMAN_NEEDED

**Lessons:**
- bcrypt rounds should be 12-14 for good security/performance balance
- JWT payload should be minimal (just user ID, not full user object)

---

## Guidelines

### When to add entries
- After completing a meaningful unit of work (feature, bug fix, refactor)
- Before taking a break if context is important
- Before context window reset or session end
- When encountering blockers worth documenting

### What to include
- **Why**: The problem or motivation (lead with this — it's the most important context for future readers)
- **What changed**: Outcomes and capabilities, not implementation details. "Projects can now declare multiple test tiers" not "Added TestTier dataclass to verify.py"
- **Next steps**: Immediate actionable items (not long-term plans)
- **Blockers**: Specific issues preventing progress
- **Lessons**: What was learned that wasn't obvious (optional but valuable)

### What NOT to include
- File names and line counts (that's what git log is for)
- Vague statements ("worked on feature")
- Long explanations (keep bullets concise)
- Future plans (use STATUS.md for roadmap)

### Keep it clean
- Most recent entries at top
- 5-10 bullets max per session
- Archive old entries (>60 days) to `docs/journal_archive.md`

