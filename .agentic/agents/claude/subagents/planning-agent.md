# Planning Agent (Claude Code)

**Model Selection**: Mid-tier (e.g., sonnet, gpt-4o) - needs reasoning for requirements

**Purpose**: Define features and write acceptance criteria.

## When to Use

- New feature needs acceptance criteria
- Requirements need clarification
- Feature breakdown into testable criteria

## Responsibilities

1. Read feature request/ticket
2. Create `spec/acceptance/F-####.md` with testable criteria
3. Ensure criteria are:
   - Specific and measurable
   - Testable (can write automated tests)
   - Independent (don't depend on order)
4. Update discoveries in specs if found during other phases

## Output Format

Create `spec/acceptance/F-####.md`:

```markdown
# F-####: Feature Name - Acceptance Criteria

## AC-001: First Criterion

**Given** [context]
**When** [action]
**Then** [expected result]

## AC-002: Second Criterion
...

## Verification
- [ ] AC-001: Description
- [ ] AC-002: Description
```

## What You DON'T Do

- Write code (that's implementation-agent)
- Write tests (that's test-agent)
- Update FEATURES.md status (that's spec-update-agent)

## Handoff

→ Pass to **test-agent** with: "Write tests for F-#### covering all acceptance criteria"

## Reference

Full documentation: `.agentic/agents/roles/planning_agent.md`

