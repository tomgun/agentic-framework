---
summary: "Plan-review lifecycle: create plan, dialectical review, iterate, approve"
trigger: "plan, design, ag plan, review plan"
tokens: ~2800
phase: planning
---

# Plan-Review Loop Workflow

**Purpose**: Improve plan quality through iterative planning and dialectical review (critic + advocate with fresh context) before implementation.

**Principle**: No single reviewer's word is the final truth. The user sees a debate between opposing perspectives and decides.

---

## Overview

```
┌─────────┐     ┌──────────┐     ┌────────────────────┐
│ Planner │────▶│   Plan   │────▶│ Critic + Advocate  │
└─────────┘     │ Artifact │     │ (parallel, fresh)  │
     ▲          └──────────┘     └─────────┬──────────┘
     │                                     │
     │                              ┌──────▼──────┐
     │                              │  Synthesis   │
     │                              └──────┬──────┘
     │                                     │
     │          ┌──────────────────────┐    │
     └──────────│ User: Proceed/Revise │◀──┘
                └──────────────────────┘
```

**When to use**:
- Complex features (3+ files, architectural decisions)
- Unfamiliar domains (fresh-context reviewers catch knowledge gaps)
- High-stakes changes (auth, payments, data migrations)

**When to skip**:
- Simple bug fixes
- Trivial changes (typos, config tweaks)
- User explicitly requests `--no-review`

---

## Configuration (STACK.md)

```markdown
## Settings
- plan_review_enabled: yes        <!-- yes | no (default: yes for Formal, no for Discovery) -->
- plan_review_max_iterations: 3   <!-- Max rounds before suggesting human escalation (advisory) -->
- plan_review_auto_for: [planning]  <!-- planning | implement | both -->
```

**Defaults** (if not specified):
- `plan_review_enabled: yes` for Formal profile, `no` for Discovery
- `plan_review_max_iterations: 3`
- `plan_review_auto_for: [planning]`

---

## Plan Artifact Format

Plans are written to `.agentic/journal/plans/F-XXXX-plan.md`:

```markdown
# Plan: F-XXXX [Feature Title]

**Status**: DRAFT | REVIEWING | APPROVED | ESCALATED
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

**Critic**: [summary of key concerns]
**Advocate**: [summary of key strengths and trade-off reasoning]
**Synthesis**: [what agreed, what contested]
**User Decision**: Revise — [user's direction]

**Planner Response** (iteration 2):
- Addressed [concern] by [change]
- Kept [decision] because [reasoning]

---

### Review 2 (2026-02-04) - iteration 2

**Critic**: [summary]
**Advocate**: [summary]
**Synthesis**: [summary]
**User Decision**: Proceed

**Status**: APPROVED
```

---

## Agent Instructions

### For Planner Agent

When creating/revising a plan:

1. **Read context first**:
   - `.agentic/spec/acceptance/F-XXXX.md` (requirements)
   - `CONTEXT_PACK.md` (architecture)
   - Related code files

2. **Create comprehensive plan**:
   - Don't just list steps - explain WHY
   - Consider alternatives, document trade-offs
   - Identify risks proactively
   - Be specific about files and changes

3. **On revision**:
   - Read the user's direction and the synthesis's Revision Guidance
   - Address what the user asked for
   - Defend your approach where it's correct
   - Increment iteration counter, set status to REVIEWING

### For Review (Dialectical Mechanism)

Each review round uses the dialectical mechanism described in `dialectical_review.md`:

1. **Spawn Critic + Advocate** in parallel with fresh context
2. **Critic** finds flaws, risks, blind spots (no verdicts)
3. **Advocate** explains trade-off reasoning, defends decisions honestly
4. **Orchestrator synthesizes** both perspectives with Revision Guidance
5. **User decides**: Proceed (→ APPROVED), Revise (→ new iteration), or Reject

See `.agentic/lib/workflows/dialectical_review.md` for the full mechanism, synthesis format, and cross-tool adaptation.

---

## Integration with ag Commands

### ag plan F-XXXX

```bash
ag plan F-XXXX              # Create plan with dialectical review loop
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

Use Agent tool to spawn planner and reviewers:

```python
# Step 1: Planner
Agent(
    subagent_type="Plan",
    prompt="""
    Create implementation plan for F-XXXX.
    Read: .agentic/spec/acceptance/F-XXXX.md, CONTEXT_PACK.md
    Write plan to: .agentic/journal/plans/F-XXXX-plan.md
    Follow format in: .agentic/lib/workflows/plan_review_loop.md
    """
)

# Step 2: Critic + Advocate (parallel, fresh context)
Agent(
    subagent_type="general-purpose",
    prompt="""You are a PLAN CRITIC. Read plan at .agentic/journal/plans/F-XXXX-plan.md
    and acceptance criteria at .agentic/spec/acceptance/F-XXXX.md.
    Follow: .agentic/lib/agents/claude/subagents/plan-critic-agent.md
    Output structured critique."""
)

Agent(
    subagent_type="general-purpose",
    prompt="""You are a PLAN ADVOCATE. Read plan at .agentic/journal/plans/F-XXXX-plan.md
    and acceptance criteria at .agentic/spec/acceptance/F-XXXX.md.
    Follow: .agentic/lib/agents/claude/subagents/plan-advocate-agent.md
    Output structured defense."""
)

# Step 3: Orchestrator synthesizes, presents to user
# Step 4: User decides → iterate or proceed
```

---

## Human Escalation

When `max_iterations` reached:

1. Plan file shows current state and all review history
2. Agent notifies human: "Plan has been through N iterations — see .agentic/journal/plans/F-XXXX-plan.md"
3. This is advisory, not blocking. User can:
   - Approve the plan as-is
   - Edit plan directly and set status to `APPROVED`
   - Provide guidance and request another iteration
   - Reject the approach entirely

---

## Cost Acknowledgment

Fresh context per iteration = 2 agents x N iterations. More expensive than a single-reviewer model. Worth it: independence catches groupthink. Mid-tier models keep costs reasonable.

---

## Benefits

1. **No authority problem** - Neither reviewer has the final word; user decides
2. **Fresh context** - Independent agents catch things the planner has normalized
3. **Balanced perspective** - Critic finds flaws, Advocate explains reasoning
4. **Iterative improvement** - User can revise based on synthesis guidance
5. **Documentation** - Plan artifact with review history documents decisions

---

## Anti-patterns

- **Rubber-stamp synthesis**: Presenting both views without highlighting disagreements
- **Infinite loops**: Never approving, always finding issues
- **Scope creep**: Critic raising issues not related to acceptance criteria
- **Bike-shedding**: Focusing on trivial issues, missing critical ones

**Good practices**:
- Focused on acceptance criteria, security, correctness
- Constructive synthesis with actionable Revision Guidance
- Time-bounded: max iterations prevents endless loops
- User authority: no automated enforcement
