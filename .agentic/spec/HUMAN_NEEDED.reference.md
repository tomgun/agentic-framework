# HUMAN_NEEDED - Examples and Guidelines

**Purpose**: This file contains examples and guidelines for using `HUMAN_NEEDED.md`. Keep this in `.agentic/` for reference.

---

## Example entries

### HN-0001: Choose payment provider
- **Type**: decision
- **Added**: 2025-12-15
- **Context**:
  - Feature F-0023 (payment processing) needs a provider
  - Technical integration is straightforward for Stripe or PayPal
- **Why human needed**:
  - Business decision: pricing, compliance, international support
  - Agent lacks context on budget and business priorities
- **Options**:
  - Stripe: Better API, higher fees, modern
  - PayPal: Lower fees, older API, more trusted by some users
- **Impact**:
  - Blocking: F-0023, F-0024 (subscriptions)
- **Agent recommendation**:
  - Stripe for MVP (better developer experience), revisit later if needed

### HN-0002: Intermittent test failure on CI
- **Type**: bug
- **Added**: 2025-12-20
- **Context**:
  - Test `user.test.ts:42` fails ~10% of time on CI only
  - Appears to be timing/race condition
  - Attempted fixes: added waits, mocked clock - no improvement
- **Why human needed**:
  - Requires debugging with actual CI environment access
  - May need specialized CI logs or hardware insight
  - After 5 attempts, agent cannot reproduce locally
- **Impact**:
  - Blocking: CI deployments fail randomly
- **Agent note**:
  - Test involves async file operations - suspect filesystem timing difference between local and CI

### HN-0003: Large-scale codebase refactor
- **Type**: refactor
- **Added**: 2025-12-22
- **Context**:
  - Need to migrate from REST to GraphQL across 80+ files
  - Technically understood, but extremely large scope
- **Why human needed**:
  - Changes touch >50 files (complexity threshold)
  - High risk of regression
  - Human should drive strategy and review increments
- **Impact**:
  - Affects: F-0005 through F-0025
- **Agent recommendation**:
  - Split into 10 phases, 8-10 files per phase
  - Agent can handle each phase with human review between phases

### HN-0004: Security implications unclear
- **Type**: security
- **Added**: 2025-12-23
- **Context**:
  - Feature F-0030 requires storing user tokens
  - Technical implementation options clear
  - Security implications (encryption, storage location, rotation) require expertise
- **Why human needed**:
  - Security decisions need human review
  - Compliance implications (GDPR, SOC2)
  - Agent lacks security threat modeling expertise
- **Impact**:
  - Blocking: F-0030 (OAuth integration)

---

## Guidelines for agents

### When to add entries

**Always escalate:**
- Decisions requiring business context (pricing, partnerships, user priorities)
- Security decisions (encryption, authentication strategies, data handling)
- Compliance/legal matters (privacy, data retention, accessibility)
- Hardware/environment-specific issues you can't reproduce
- After 3-5 failed attempts at debugging a complex issue
- Refactoring >50 files
- Changes with unclear impact on production systems

**Consider escalating:**
- Performance optimizations with unclear business value
- API design decisions (REST vs GraphQL, versioning strategy)
- Database schema changes affecting production data
- Architectural changes with significant migration cost
- Technical debt prioritization

**Don't escalate (handle these):**
- Straightforward implementation within specs
- Bug fixes with clear root cause and solution
- Adding unit tests
- Updating documentation
- Small refactors (<10 files, well-scoped)

### How to write entries

**Good entry:**
- Clear context (what's happening)
- Specific reason human needed (not just "complex")
- Options presented with pros/cons
- Impact clearly stated (blocking what?)
- Recommendation if agent has one

**Bad entry:**
- "This is hard" (vague)
- No context
- No options explored
- No indication of impact or urgency

### Entry template

```markdown
### HN-####: [Short description]
- **Type**: decision | bug | refactor | security | external | other
- **Added**: YYYY-MM-DD
- **Context**:
  - [What's the situation?]
- **Why human needed**:
  - [Specific reason]
- **Options** (if applicable):
  - Option A:
  - Option B:
- **Impact**:
  - Blocking: [feature IDs]
  - Affects: [areas]
- **Agent recommendation**:
  - [If any]
```

---

## Guidelines for humans

### Reviewing this file
- Check HUMAN_NEEDED.md periodically (daily for active projects)
- Prioritize items marked as "Blocking"
- Provide clear decisions/direction so agent can proceed
- Add decision to ADR if it's architecturally significant

### Resolving items
- Add resolution to STATUS.md so agent sees it
- Update the relevant spec if decision changes architecture/approach
- Create task for agent if implementation is needed
- Move resolved item to "Resolved" section

### Keeping it clean
- Archive resolved items older than 30 days
- Remove obsolete entries (if context changed)
- Keep active section <10 items (or split into urgent/non-urgent)

