# JOURNAL - Examples and Guidelines

**Purpose**: This file contains examples and format guidelines for using `JOURNAL.md`. Keep this in `.agentic/` for reference.

---

## Format Options

**Two formats supported (choose one and be consistent):**

### Format A: Simple (recommended for most projects)
```markdown
### Session: YYYY-MM-DD HH:MM
**Feature**: F-####
**Accomplished**:
- Items completed
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
**Feature**: F-0004 (Persistence)

**Accomplished**:
- Implemented localStorage adapter with quota handling
- Added unit tests for happy path and quota exceeded
- Updated FEATURES.md: F-0004 implementation state = partial

**Next steps**:
- Add Safari private mode fallback (in-memory storage)
- Update TECH_SPEC.md with persistence architecture
- Add integration test for full save/load cycle

**Blockers**:
- Safari private mode throws on localStorage access (not just quota) - need research on detection strategy

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
- **Accomplished**: Concrete items (code, tests, docs)
- **Next steps**: Immediate actionable items (not long-term plans)
- **Blockers**: Specific issues preventing progress
- **Feature ID**: Link to feature if applicable

### What NOT to include
- Vague statements ("worked on feature")
- Long explanations (keep bullets concise)
- Future plans (use STATUS.md for roadmap)
- Every single file change (focus on meaningful progress)

### Keep it clean
- Most recent entries at top
- 5-10 bullets max per session
- Archive old entries (>60 days) to `docs/journal_archive.md`

