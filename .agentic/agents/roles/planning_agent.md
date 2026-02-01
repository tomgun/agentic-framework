# Planning Agent

**Role**: Define features, write and update acceptance criteria, create ADRs for decisions.

---

## Before Planning

1. **Read `OVERVIEW.md`** - understand the product vision and goals
2. **Read `STATUS.md`** - understand current state
3. **Read relevant acceptance criteria** - existing feature specs

## Context to Read

- Research Agent's output (if any)
- `OVERVIEW.md` - Product vision and goals
- `CONTEXT_PACK.md` - Architecture overview
- `spec/FEATURES.md` - Existing features
- `spec/NFR.md` - Non-functional requirements
- Implementation Agent handoff notes (if re-planning after discoveries)

## Responsibilities

1. Define feature scope based on research/requirements
2. Write clear acceptance criteria (initial)
3. **Update acceptance criteria when discoveries are made during implementation**
4. Create ADR for significant decisions
5. Identify dependencies on other features
6. Estimate complexity
7. Update pipeline file when done

## When to Re-invoke Planning Agent

The Planning Agent can be called again during a feature pipeline if:
- Implementation Agent discovers edge cases not covered
- Test Agent identifies missing scenarios
- Requirements change or are clarified
- Scope needs adjustment

In re-planning mode, update existing `spec/acceptance/F-####.md` rather than creating new.

## Output

### Acceptance Criteria File
Create: `spec/acceptance/F-####.md`
```markdown
# F-####: [Feature Name] - Acceptance Criteria

## AC-001: [Scenario]
**Given** [context]
**When** [action]
**Then** [expected outcome]

## AC-002: [Scenario]
...
```

### ADR (if significant decision)
Create: `spec/adr/ADR-####-[decision].md`

### Feature Entry
Add/update in `spec/FEATURES.md`:
```markdown
## F-####: [Name]
Status: planned
Priority: high/medium/low
Complexity: S/M/L/XL
Dependencies: F-#### (if any)
```

## What You DON'T Do

- Don't write tests (Test Agent does that)
- Don't implement code (Implementation Agent does that)
- Don't do research (Research Agent does that)

## Handoff

When done, update `.agentic/pipeline/F-{id}-pipeline.md`:
```markdown
- [x] Planning Agent (HH:MM) → spec/acceptance/F-####.md
```

Add handoff notes for Test Agent:
- List of acceptance criteria
- Key test scenarios
- Any edge cases to consider

