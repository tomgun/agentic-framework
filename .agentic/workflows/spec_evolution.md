# Spec Evolution During Implementation

**Principle**: Specs are discovered, not fully designed upfront. This is expected and encouraged.

---

## Starting Rough Is OK

2-3 bullet points answering "What would success look like?" is a valid starting spec.

**The flow**: rough spec → implement → discover → `[Discovered]` markers → human reviews evolved spec

| Profile | Where criteria live | When to formalize |
|---------|-------------------|-------------------|
| **Discovery** | WIP.md, JOURNAL.md, or inline | Upgrade to Formal when persistence needed |
| **Formal** | `spec/acceptance/F-####.md` | Can start rough, evolve during implementation |

Rough specs lower the barrier to thinking about success criteria — the alternative (no criteria at all) is worse than imperfect criteria.

### Discovery → Formal Graduation

Discovery projects keep criteria informally (WIP.md, JOURNAL.md, conversation). When a project needs persistent, cross-session specs — criteria that survive context loss and agent handoffs — it's time to graduate to Formal.

**Signs you need Formal**:
- Multiple agents working on the same project
- Criteria keep getting rediscovered across sessions
- Features are complex enough that "what does done look like?" needs a persistent answer
- Human wants to review/approve criteria separately from code

**How to graduate**:
1. Set `Profile: formal` in STACK.md
2. Create `spec/FEATURES.md` and `spec/acceptance/` directory
3. Move existing criteria from JOURNAL.md/WIP.md into acceptance files
4. Existing rough bullets become the starting spec — no need to rewrite

The graduation is a one-way door: once specs are formalized, they become the source of truth. But the formalized specs can still be rough — "2-3 bullet points in an acceptance file" is valid Formal.

---

## Why Specs Evolve

During implementation, you will discover:

- **New edge cases**: "What if user enters empty password?"
- **New requirements**: "Need rate limiting for security"
- **Issues to avoid**: "Don't allow duplicate usernames"
- **Ideas for improvement**: "Could add 'remember me' checkbox"
- **Dependencies**: "Needs email service first"
- **Performance constraints**: "Must handle 1000 concurrent users"

**This is normal, not a failure of planning.**

Waterfall design is unrealistic. The best requirements come from building and learning.

---

## When to Update Specs

**Update specs immediately when you discover:**

1. **Missing edge case** - Add to acceptance criteria
2. **Security concern** - Document as requirement
3. **Performance insight** - Add to NFR or acceptance
4. **Future enhancement idea** - Mark as "Future idea" in spec
5. **Dependency on other feature** - Add to Dependencies
6. **User-facing change** - Update acceptance criteria

---

## How to Update Specs

### Immediate Update

Add discoveries to acceptance criteria as you find them:

```markdown
## Acceptance Criteria

### Original
- [ ] User can log in with email/password

### Discovered During Implementation
- [ ] [Discovered] Rate limit: Max 5 failed attempts per 10 minutes
- [ ] [Discovered] Session expires after 24 hours of inactivity
- [ ] [Discovered] Passwords must be hashed with bcrypt

### Future Ideas
- [ ] [Future] Add "remember me" checkbox
- [ ] [Future] Support OAuth login (Google, GitHub)
```

### Token-Efficient Update

Use the feature.sh tool to update without reading the whole file:

```bash
# Update acceptance criteria
bash .agentic/tools/feature.sh F-0010 note "Discovered: Need rate limiting for failed attempts"
```

### Include in Commit

Include spec changes in the same commit as the code:

```bash
git add spec/acceptance/F-0010.md src/auth/login.ts
git commit -m "feat(F-0010): implement login with rate limiting"
```

---

## Example: Login Feature Evolution

### Initial Acceptance Criteria

```markdown
## F-0010: User Login

### Acceptance Criteria
- [ ] User can enter email and password
- [ ] User sees error on invalid credentials
- [ ] User is redirected to dashboard on success
```

### After Implementation

```markdown
## F-0010: User Login

### Acceptance Criteria
- [x] User can enter email and password
- [x] User sees error on invalid credentials
- [x] User is redirected to dashboard on success

### Discovered Requirements
- [x] [Discovered] Rate limit: Max 5 failed attempts per 10 min (prevent brute force)
- [x] [Discovered] Session stored in httpOnly cookie (XSS prevention)
- [x] [Discovered] Password hashed with bcrypt, cost 12 (industry standard)
- [x] [Discovered] Email validation: Must contain @ and domain

### Future Enhancements
- [ ] [Future] Add "remember me" checkbox (longer session)
- [ ] [Future] Support 2FA (TOTP)
- [ ] [Future] OAuth login (Google, GitHub)

### Notes
- Chose bcrypt over argon2 for wider library support
- Rate limiting uses sliding window algorithm
```

---

## Why This Matters

### For Quality

- **Captures real requirements** (not theoretical)
- **Prevents repeating mistakes** (documented issues)
- **Builds comprehensive spec over time** (organic growth)

### For Future Work

- **Clear history** of decisions
- **Future ideas** are captured, not lost
- **Dependencies** are documented
- **Constraints** are explicit

### For AI Agents

- **Context for future sessions** (read evolved spec)
- **Learning from discoveries** (patterns emerge)
- **Complete acceptance criteria** (fewer surprises)

---

## Integration with Acceptance-Driven Development

1. **Start with rough criteria** - "User can log in"
2. **Implement feature** - AI generates code
3. **Discover edge cases** - Update spec immediately
4. **Write tests** - Verify acceptance criteria (including discoveries)
5. **Commit** - Code + updated spec together
6. **Move to next feature** - Spec is now more complete

**The spec grows organically with the implementation.**

---

## Anti-Patterns

❌ **Don't ignore discoveries** - If you find an edge case, document it
❌ **Don't defer spec updates** - Update immediately while fresh
❌ **Don't lose future ideas** - Capture them, even if not implementing now
❌ **Don't commit code without spec updates** - Keep them together
❌ **Don't treat rough specs as failures** - They're the starting point

---

## Related Documents

- [Acceptance-Driven Development](../PRINCIPLES.md#acceptance-driven-development)
- [Feature Implementation Checklist](../checklists/feature_implementation.md)
- [Definition of Done](definition_of_done.md)
- [Feature Tracking](../spec/FEATURES.reference.md)

