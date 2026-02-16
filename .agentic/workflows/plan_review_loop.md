# Plan-Review Loop Workflow

**Purpose**: Improve plan quality through iterative planning and critical review before implementation.

**Principle**: Two perspectives catch more issues than one. A planner optimizes for solutions; a reviewer optimizes for problems.

---

## Overview

```
┌─────────┐     ┌──────────┐     ┌─────────┐
│ Planner │────▶│   Plan   │────▶│Reviewer │
└─────────┘     │ Artifact │     └────┬────┘
     ▲          └──────────┘          │
     │                                │
     │    ┌────────────────────┐      │
     └────│ REVISE / APPROVED  │◀─────┘
          └────────────────────┘
```

**When to use**:
- Complex features (3+ files, architectural decisions)
- Unfamiliar domains (reviewer catches knowledge gaps)
- High-stakes changes (auth, payments, data migrations)

**When to skip**:
- Simple bug fixes
- Trivial changes (typos, config tweaks)
- User explicitly requests `--no-review`

---

## Configuration (STACK.md)

```markdown
## Plan-Review Loop (recommended)
- plan_review_enabled: yes        <!-- yes | no (default: yes for Formal, no for Discovery) -->
- plan_review_max_iterations: 3   <!-- Max revisions before human escalation -->
- plan_review_auto_for: [planning]  <!-- planning | implement | both -->
<!-- - plan_review_reviewer_model: same  # same | opus | sonnet -->
```

**Defaults** (if not specified):
- `plan_review_enabled: yes` for Formal profile, `no` for Discovery
- `plan_review_max_iterations: 3`
- `plan_review_auto_for: [planning]`

---

## Plan Artifact Format

Plans are written to `.agentic-journal/plans/F-XXXX-plan.md`:

```markdown
# Plan: F-XXXX [Feature Title]

**Status**: DRAFT | REVIEWING | REVISION_NEEDED | APPROVED | ESCALATED
**Iteration**: 1
**Created**: 2026-02-04
**Last Updated**: 2026-02-04

---

## Context
[What problem we're solving, constraints, dependencies]

## Approach
[High-level strategy, key decisions, trade-offs considered]

## Implementation Steps
1. [ ] Step 1 - [files affected]
2. [ ] Step 2 - [files affected]
3. [ ] Step 3 - [files affected]

## Files to Modify
- `path/to/file.py` - [what changes]
- `path/to/other.py` - [what changes]

## Testing Strategy
- Unit tests: [what to test]
- Integration: [what to test]
- Manual verification: [what to check]

## Risks & Mitigations
- Risk: [potential issue]
  Mitigation: [how to handle]

---

## Review History

### Review 1 (2026-02-04) - iteration 1
**Reviewer**: [agent/human]

**Issues Found**:
- [ ] CRITICAL: [issue description]
- [ ] IMPORTANT: [issue description]
- [ ] SUGGESTION: [nice to have]

**Verdict**: REVISION_NEEDED

**Planner Response** (iteration 2):
- Addressed CRITICAL issue by [change]
- Addressed IMPORTANT issue by [change]
- Deferred SUGGESTION to follow-up

---

### Review 2 (2026-02-04) - iteration 2
**Reviewer**: [agent/human]

**Issues Found**:
- None critical

**Verdict**: APPROVED

**Approval Notes**:
Plan is solid. Ready for implementation.
```

---

## Agent Instructions

### For Planner Agent

When creating/revising a plan:

1. **Read context first**:
   - `spec/acceptance/F-XXXX.md` (requirements)
   - `CONTEXT_PACK.md` (architecture)
   - Related code files

2. **Create comprehensive plan**:
   - Don't just list steps - explain WHY
   - Consider alternatives, document trade-offs
   - Identify risks proactively
   - Be specific about files and changes

3. **On revision**:
   - Address ALL critical/important issues
   - Explain how each issue was addressed
   - Don't just agree - defend your approach if it's correct

### For Reviewer Agent

When reviewing a plan:

1. **Adopt adversarial mindset**:
   - Assume the plan has flaws (it probably does)
   - Look for what's MISSING, not just what's wrong
   - Consider edge cases, error scenarios, security

2. **Check for**:
   - [ ] Does plan address ALL acceptance criteria?
   - [ ] Are there simpler approaches not considered?
   - [ ] What could go wrong? Is it handled?
   - [ ] Are estimates realistic?
   - [ ] Is testing strategy adequate?
   - [ ] Are there hidden dependencies?

3. **Categorize issues**:
   - **CRITICAL**: Must fix before implementation (blockers, security, data loss)
   - **IMPORTANT**: Should fix (significant improvement, catches bugs)
   - **SUGGESTION**: Nice to have (style, minor optimization)

4. **Verdict options**:
   - `APPROVED`: Plan is ready for implementation
   - `REVISION_NEEDED`: Has critical/important issues
   - `ESCALATE`: Fundamental disagreement, need human input

---

## Integration with ag Commands

### ag plan F-XXXX

```bash
ag plan F-XXXX              # Create plan with review loop
ag plan F-XXXX --no-review  # Skip review (simple cases)
```

### ag implement F-XXXX

When `auto_for` includes `implement`:

```bash
ag implement F-XXXX
# 1. Check if approved plan exists
# 2. If not, run plan-review loop first
# 3. Then implement from approved plan
```

---

## Claude Code Implementation

Use Task tool to spawn planner and reviewer:

```python
# Planner
Task(
    subagent_type="Plan",
    model="opus",  # or from STACK.md
    prompt="""
    Create implementation plan for F-XXXX.
    Read: spec/acceptance/F-XXXX.md, CONTEXT_PACK.md
    Write plan to: .agentic-journal/plans/F-XXXX-plan.md
    Follow format in: .agentic/workflows/plan_review_loop.md
    """
)

# Reviewer
Task(
    subagent_type="general-purpose",
    model="opus",  # critical review needs quality
    prompt="""
    Critically review plan at .agentic-journal/plans/F-XXXX-plan.md
    Follow reviewer instructions in: .agentic/workflows/plan_review_loop.md
    Add your review to the Review History section.
    Set verdict: APPROVED, REVISION_NEEDED, or ESCALATE
    """
)
```

---

## Cursor Implementation

In `.cursor/agents/`:

```yaml
# plan-agent.md
You are a planning agent. Create detailed implementation plans.
[Include planner instructions from above]

# review-agent.md
You are a critical reviewer. Find flaws in plans before implementation.
[Include reviewer instructions from above]
```

Cursor's agent mode can orchestrate the loop via the orchestrator agent.

---

## Human Escalation

When `ESCALATE` verdict or `max_iterations` reached:

1. Plan file shows current state and all review history
2. Agent notifies human: "Plan needs your input - see .agentic-journal/plans/F-XXXX-plan.md"
3. Human can:
   - Edit plan directly and set status to `APPROVED`
   - Provide guidance and request another iteration
   - Reject the approach entirely

---

## Benefits

1. **Catches issues early** - Cheaper to fix in planning than implementation
2. **Better coverage** - Two perspectives, adversarial review
3. **Documentation** - Plan artifact documents decisions for future
4. **Consistency** - Same quality process regardless of agent "mood"
5. **Learning** - Review history shows common issues to avoid

---

## Anti-patterns

❌ **Rubber-stamp reviews**: Reviewer always approves without critique
❌ **Infinite loops**: Never approving, always finding issues
❌ **Scope creep**: Reviewer adding features not in acceptance criteria
❌ **Bike-shedding**: Focusing on trivial issues, missing critical ones

✅ **Good reviews**: Focused on acceptance criteria, security, correctness
✅ **Constructive**: Issues include suggested solutions
✅ **Time-bounded**: Max iterations prevents endless loops
