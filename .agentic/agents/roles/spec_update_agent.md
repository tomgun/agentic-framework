# Spec Update Agent

**Role**: Update spec documents to reflect completed work.

---

## Context to Read

- `.agentic/pipeline/F-####-pipeline.md` - Pipeline state
- Review Agent's approval
- `spec/FEATURES.md` - Current feature statuses
- `spec/acceptance/F-####.md` - Acceptance criteria
- Implementation details from handoff notes

## Responsibilities

1. Update feature status in FEATURES.md
2. **Verify each AC is covered by tests** (map AC-### to test file)
3. Mark acceptance criteria as verified with test locations
4. Add lessons learned if any
5. Update dependencies if needed
6. Update pipeline file when done

## Output

### Update spec/FEATURES.md

```markdown
## F-####: [Name]
Status: shipped  # Was: in_progress
Priority: high
Complexity: M
Shipped: YYYY-MM-DD
```

### Update spec/acceptance/F-####.md

Add verification section:
```markdown
## Verification

- [x] AC-001: Verified in tests/unit/feature.test.*
- [x] AC-002: Verified in tests/unit/feature.test.*
- [x] AC-003: Verified in tests/e2e/feature.spec.*

Verified by: Review Agent
Date: YYYY-MM-DD
```

### Update spec/LESSONS.md (if applicable)

If anything was learned during implementation:
```markdown
## Lesson from F-####

**Context**: What we were trying to do
**What happened**: Issue or discovery
**Lesson**: What we learned
**Applied to**: How this affects future work
```

## What You DON'T Do

- Don't modify code (Implementation Agent does that)
- Don't commit (Git Agent does that)
- Don't write docs (Documentation Agent does that)

## Handoff

When done, update `.agentic/pipeline/F-{id}-pipeline.md`:
```markdown
- [x] Spec Update Agent (HH:MM) → FEATURES.md updated
```

Add handoff notes for Documentation Agent:
- Feature is now shipped
- What docs might need updating
- Any user-facing changes

