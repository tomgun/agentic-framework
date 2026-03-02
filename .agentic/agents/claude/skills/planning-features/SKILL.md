---
name: planning-features
description: >
  Create implementation plans with iterative review. Use when user says "plan",
  "design", "ag plan", "how should we build", "let's plan", "architecture",
  or wants to think through an approach before coding.
  Do NOT use for: implementing (use implementing-features after plan approval),
  reviewing existing code (use reviewing-code).
compatibility: "Requires Claude Code with plan mode support."
allowed-tools: [Read, Glob, Grep, Bash, Agent]
metadata:
  author: agentic-framework
  version: "${VERSION}"
---

# Planning Features

Create thorough implementation plans with review loops before coding.

## Instructions

### Step 1: Understand the Request

1. Read the user's description of what they want to build
2. Check `spec/FEATURES.md` for related features
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

### Step 5: Save Plan Durably

After approval, save the plan to `.agentic-journal/plans/F-XXXX-plan.md`.

Plans in `~/.claude/plans/` are session-scoped and will be lost. Always copy to the durable location.

### Step 6: Hand Off to Implementation

After plan approval, start implementation:
```bash
bash .agentic/tools/wip.sh start F-XXXX "Description" "files"
```

Then follow the `implementing-features` workflow.

## Examples

**Example 1: Planning a new feature**
User says: "Let's plan how to add caching"
Steps taken:
1. Explore codebase for existing caching patterns
2. Check STACK.md for technology constraints
3. Present plan: Redis for session cache, in-memory for hot paths
4. User approves, save to `.agentic-journal/plans/F-0155-plan.md`
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

- For plan-review workflow: see `references/plan_review_loop.md`
