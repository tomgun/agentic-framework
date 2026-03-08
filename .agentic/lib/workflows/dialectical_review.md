---
summary: "Dialectical review mechanism: critic + advocate in parallel, synthesis for user"
trigger: "Each review iteration within the plan-review loop"
tokens: ~2200
phase: planning
---

# Dialectical Review Mechanism

**Purpose**: Run two agents with opposing mandates — a Critic (adversarial) and an Advocate (defensive) — in parallel with fresh context. The orchestrating agent synthesizes both perspectives into a balanced assessment. The user reads the synthesis and decides: Proceed, Revise, or Reject.

**Principle**: No single reviewer's word should be treated as truth. The user sees a debate, not a verdict.

**Relationship to plan-review loop**: This file describes the *mechanism* for each review round. The full lifecycle (creation, iteration, escalation, approval) is in `plan_review_loop.md`.

---

## How Each Review Round Works

```
┌──────────────┐
│ Plan         │
│ (or revised) │
└──────┬───────┘
       │
  ┌────┴────┐
  │ PARALLEL │
  ▼         ▼
┌──────┐ ┌──────────┐
│Critic│ │Advocate  │
│(find │ │(explain  │
│flaws)│ │choices)  │
└──┬───┘ └────┬─────┘
   │          │
   ▼          ▼
┌──────────────┐
│ Orchestrator │
│ Synthesizes  │
└──────┬───────┘
       │
       ▼
┌──────────────────────────────┐
│ User decides:                │
│  Proceed | Revise | Reject   │
└──────────────────────────────┘
```

**When used**:
- As the review mechanism within the plan-review loop
- When `plan_review_enabled: yes` in STACK.md
- Triggered by `ag plan F-XXXX`

**When NOT used**:
- `plan_review_enabled: no`
- User explicitly skips (`--no-review`)

---

## Configuration (STACK.md)

```markdown
## Settings
- plan_review_enabled: yes
# Review plan before implementation (uses dialectical critic+advocate).
# Profile defaults — Discovery: no | Formal: yes
- plan_review_max_iterations: 3
# Max review rounds before suggesting human escalation (advisory, not blocking)
```

---

## Agent Definitions

### Critic Agent

**Location**: `.agentic/lib/agents/claude/subagents/plan-critic-agent.md`
**Mandate**: Find flaws, risks, blind spots. Adversarial.
**Key instruction**: "Do NOT hold back. The advocate will defend the plan."
**Output format**: High-Confidence Concerns, Possible Concerns, Assumptions Worth Verifying
**No verdict authority** — never says APPROVED/REVISION_NEEDED.

### Advocate Agent

**Location**: `.agentic/lib/agents/claude/subagents/plan-advocate-agent.md`
**Mandate**: Explain trade-off reasoning, defend decisions, articulate strengths.
**Key instruction**: "If something IS weak, say so — but explain why it's acceptable."
**Critical instruction**: "Explain WHY the plan made its choices — a fresh-context critic won't know the reasoning."
**Output format**: Core Strengths, Trade-offs Acknowledged, Risk Management, Honest Weaknesses

Both agents:
- Run in **parallel** with **fresh context** (no shared memory with planner or each other)
- Read the plan file independently
- Follow mid-tier model selection (per `agent_mode` setting)
- If iteration > 1: Review History exists in the plan — read it for context but form your OWN assessment

---

## Synthesis Format

The orchestrating agent synthesizes both outputs and presents inline to the user:

```markdown
# Dialectical Review: F-XXXX (Iteration N)

**Plan**: `.agentic/journal/plans/F-XXXX-plan.md`
**Conducted**: YYYY-MM-DD

## High-Confidence Findings
[Where both critic and advocate agree — strongest signals]

## Points of Contention
| Topic | Critic Position | Advocate Position |
|-------|----------------|-------------------|

## Uncontested Critic Concerns
[Raised by critic, not addressed by advocate]

## Uncontested Advocate Strengths
[Highlighted by advocate, not challenged by critic]

## Revision Guidance (if user chooses to revise)
1. [Most critical — from High-Confidence Findings]
2. [Important — from Uncontested Critic Concerns]
3. [Consider — from Points of Contention where Critic has stronger case]

## Summary
[Neutral: what the user should pay attention to before deciding]
```

### Synthesis Rules (for the orchestrating agent)

1. **Agreement = high confidence**: Both sides see it → strong signal
2. **Disagreement = user judgment**: Present both positions fairly
3. **Never add your own opinion**: Neutral reporter only
4. **No verdicts**: The user decides, not the system
5. **Revision Guidance is actionable**: If the user chooses to revise, the Planner uses this as direction

---

## Iteration Flow

After synthesis, the user chooses:

1. **Proceed**: Plan status → APPROVED. Ready for `ag implement F-XXXX`.
2. **Revise**: User tells Planner what to change (guided by synthesis Revision Guidance). Planner revises plan, increments iteration counter. Fresh Critic + Advocate run on the revised plan.
3. **Reject**: Abandon plan entirely.

At `plan_review_max_iterations`: suggest human escalation (advisory, not blocking). The user can still continue iterating.

Plan artifact status during iteration: `REVIEWING`. User sets `APPROVED` when proceeding.

---

## Claude Code Implementation

Use Agent tool to spawn both in parallel:

```python
# Both run simultaneously with fresh context
Agent(
    subagent_type="general-purpose",
    prompt="""You are a PLAN CRITIC. Read the plan at .agentic/journal/plans/F-XXXX-plan.md
    and the acceptance criteria at .agentic/spec/acceptance/F-XXXX.md.
    Follow instructions in .agentic/lib/agents/claude/subagents/plan-critic-agent.md.
    Output your structured critique."""
)

Agent(
    subagent_type="general-purpose",
    prompt="""You are a PLAN ADVOCATE. Read the plan at .agentic/journal/plans/F-XXXX-plan.md
    and the acceptance criteria at .agentic/spec/acceptance/F-XXXX.md.
    Follow instructions in .agentic/lib/agents/claude/subagents/plan-advocate-agent.md.
    Output your structured defense."""
)
```

After both return, the orchestrating agent synthesizes using the format above.

---

## Cross-Tool Adaptation

| Tool | Approach | Quality |
|------|----------|---------|
| **Claude Code** | Agent tool spawns both in parallel (fresh context) | Best |
| **Cursor** | Orchestrator dispatches sequentially or background agents | Good |
| **Copilot** | Self-play: agent plays both roles sequentially (same context, less independent) | Workable |
| **Codex** | Task dispatch similar to Claude Code | Good |

Copilot self-play acknowledges the independence assumption is weaker — same context window means the advocate has seen the critic's output. Still better than no dialectical review.

---

## Anti-patterns

- **Rubber-stamp synthesis**: Presenting both views without highlighting disagreements
- **Adding opinion**: Orchestrator inserting own judgment into synthesis
- **Skipping advocate**: Running only critic (defeats the purpose)
- **Enforcing**: Adding verdicts or blocking implementation (user decides)

**Good practices**:
- Highlights where perspectives align AND diverge
- Honest advocate: Acknowledges real weaknesses while explaining trade-offs
- Aggressive critic: Finds issues the iterative reviewer would miss (fresh context advantage)
- Actionable Revision Guidance: If user revises, Planner knows where to focus
