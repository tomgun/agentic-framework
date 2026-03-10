---
name: planning-features
description: >
  Create implementation plans with iterative review. Use when the user wants
  to think through an approach before coding — e.g. "plan", "design",
  "ag plan", "how should we build", "let's plan", "architecture", "scope
  this", "think through", or any request to design before implementing.
  Match intent, not exact words.
  Do NOT use for: implementing (use implementing-features after plan approval),
  reviewing existing code (use reviewing-code).
compatibility: "Requires Claude Code with plan mode support."
allowed-tools: [Read, Glob, Grep, Bash, Agent]
metadata:
  author: agentic-framework
  version: "0.46.1"
---

# Planning Features

Create thorough implementation plans with review loops before coding.

## Instructions

This workflow has two phases separated by a plan-mode boundary.

**Phase 1** (Steps 1-4) runs during plan mode — read-only exploration and plan creation.
**Phase 2** (Steps 5-6) runs after plan mode ends — save, review, and hand off.

**CRITICAL**: After plan mode exits, IMMEDIATELY continue with Phase 2. Do not wait
for the user to say "implement." The plan save and review are part of the planning
workflow, not the implementation workflow.

---

### Phase 1: Plan Creation (during plan mode)

### Step 1: Understand the Request

1. Read the user's description of what they want to build
2. Check `.agentic/spec/FEATURES.md` for related features
3. Check existing code for patterns to follow

### Step 2: Research and Explore

Use the codebase to understand:
- Where the changes should live
- What existing patterns to follow
- What dependencies exist
- What might break

### Step 3: Create the Plan

Write a plan covering:
- **Problem**: What needs to be solved
- **Approach**: How to solve it (with alternatives considered)
- **Files to modify**: Specific files and what changes
- **Acceptance criteria**: How to verify success
- **Risks**: What could go wrong

### Step 4: Add Execution Order (for features with >5 ACs)

After creating the plan, add an Execution Order section that maps ACs to phases:

```
### Execution Order

#### Phase 1: Foundation (do first, blocks everything)
- AC-001, AC-002

#### Phase 2: Core (P1 — MVP)
- AC-003 [P], AC-004 [P]  ← [P] = parallelizable (different files, no dependency)
- AC-005 (depends on AC-003 + AC-004)
✅ CHECKPOINT: Run tests, verify core works

#### Phase 3: Enhanced (P2)
- AC-006, AC-007
```

`[P]` markers indicate ACs that can be assigned to parallel agents in
multi-agent workflows. Even for single-agent work, this clarifies which
ACs are independent.

Skip this section for simple features (≤5 ACs) unless multi-agent dispatch is planned.

---

### Phase 2: Save, Review, Hand Off (after plan mode ends)

Plan mode is read-only — agent spawning and file writes can't happen there.
These steps MUST run after plan mode exits.

### Step 5: Save Plan Durably

**Do this IMMEDIATELY after plan mode ends.**

Save the plan to `.agentic/journal/plans/F-XXXX-plan.md` with status `DRAFT`.

Plans in `~/.claude/plans/` are session-scoped and will be lost. Always copy to the durable location.

### Step 5.5: Dialectical Review (if `plan_review_enabled: yes`)

Check `plan_review_enabled` in STACK.md (default: yes for Formal, no for Discovery).

If enabled, run dialectical review on the saved plan:

1. **Spawn Critic + Advocate in parallel** (both with fresh context):

```
Agent(subagent_type="general-purpose",
  prompt="You are a PLAN CRITIC with fresh context.
    Read plan: .agentic/journal/plans/F-XXXX-plan.md
    Read requirements: .agentic/spec/acceptance/F-XXXX.md
    Follow: .agentic/lib/agents/claude/subagents/plan-critic-agent.md
    Output your structured critique.")

Agent(subagent_type="general-purpose",
  prompt="You are a PLAN ADVOCATE with fresh context.
    Read plan: .agentic/journal/plans/F-XXXX-plan.md
    Read requirements: .agentic/spec/acceptance/F-XXXX.md
    Follow: .agentic/lib/agents/claude/subagents/plan-advocate-agent.md
    Output your structured defense.")
```

2. **Synthesize both perspectives** using rules from `references/dialectical_review.md`
3. **Present synthesis inline** (including Revision Guidance section)
4. **User decides**: Proceed (→ APPROVED), Revise (→ Planner revises, fresh review), or Reject
5. If Revise: Planner revises the saved plan, then fresh Critic + Advocate run again (new iteration)

If review is not enabled, set plan status to `APPROVED` directly.

### Step 6: Hand Off to Implementation

After plan approval (user chooses Proceed), start implementation:
```bash
bash .agentic/lib/tools/wip.sh start F-XXXX "Description" "files"
```

Then follow the `implementing-features` workflow.

## Examples

**Example 1: Planning a new feature**
User says: "Let's plan how to add caching"
Steps taken:
1. Explore codebase for existing caching patterns
2. Check STACK.md for technology constraints
3. Present plan: Redis for session cache, in-memory for hot paths
4. User approves, save to `.agentic/journal/plans/F-0155-plan.md`
Result: Clear plan with file list, ready for implementation.

**Example 2: User wants to think before coding**
User says: "How should we restructure the API?"
Steps taken:
1. Read current API structure
2. Identify pain points and improvement areas
3. Present 2-3 approaches with trade-offs
4. User picks approach B, save plan
Result: Architectural decision documented, ready to implement in batches.

## Troubleshooting

**Plan too vague**
Cause: Not enough codebase exploration.
Solution: Read more files, understand existing patterns, be specific about file changes.

**Plan too large**
Cause: Feature scope too big.
Solution: Break into 3-5 smaller plans, each implementable in one batch (max 5-10 files).

## References

- For plan-review lifecycle: see `references/plan_review_loop.md`
- For dialectical review mechanism: see `references/dialectical_review.md`
