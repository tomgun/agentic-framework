# ADR-001: Multi-Component Architecture & Workflow Engine

**Status**: Proposed
**Date**: 2026-03-08
**Deciders**: Tomas Gunther
**Context**: Extended design discussion on framework evolution

---

## Summary

This ADR captures the architectural direction for the Agentic Framework to support multi-component projects, epic decomposition, MCP-based agent coordination, formal state machines for workflow enforcement, and fully autonomous end-to-end execution.

These are interconnected capabilities that build on each other. Components enable scoping. Epics enable decomposition across components. MCP enables real-time coordination across agents. The state machine formalizes workflow enforcement. Together they enable full autonomy.

A cross-cutting concern is **review checkpoints**: transitions where output must be reviewed before proceeding. By default, a human reviews. In autonomous mode, a dedicated **critical review agent** can substitute — a separate agent instance whose sole role is adversarial review of another agent's output. This is configurable per transition and per profile.

---

## 1. Components as Metadata

### Decision

Introduce an optional `## Components` section in STACK.md as a registry of project components.

### Format

```markdown
## Components
| Name | Path | Type | Test Command |
|------|------|------|-------------|
| api | services/api | python-fastapi | pytest services/api/tests |
| web | apps/web | nextjs | npm test --prefix apps/web |
| shared | packages/shared | typescript-lib | npm test --prefix packages/shared |
```

### Implications

- **Feature scoping**: Features in FEATURES.md gain an optional `Component` field. Tooling validates that the component exists in the registry.
- **Context filtering**: When an agent works on a feature, `context-for-role.sh` uses the component field to filter specs, code, and tests to only the relevant subset. This is critical for token efficiency in large projects.
- **Backward compatibility**: Single-component projects simply omit the section. All existing behavior is preserved — component scoping is entirely additive.
- **Component-specific settings**: Components can override parent settings (e.g., test commands, linting rules) while inheriting defaults.

### Example Feature Entry

```markdown
## F-0200: User Authentication API

**Status**: planned
**Component**: api
**Dependencies**: F-0198 (shared auth types)
```

---

## 2. Epics as Parent Features

### Decision

Reuse the existing `Parent` field in FEATURES.md to model epics. No new entity type needed.

### How It Works

- An epic is simply a feature whose children are component-scoped features.
- The epic has **product-level** acceptance criteria (user-visible outcomes).
- Child features have **component-scoped** acceptance criteria (implementation contracts).
- An epic ships when: all children pass their acceptance criteria AND integration verification succeeds.

### Example

```markdown
## F-0300: User Onboarding Flow (Epic)
**Status**: in-progress
**Category**: Product
**Acceptance**: spec/acceptance/F-0300.md  (product-level: "user can sign up and see dashboard")

## F-0301: Onboarding API Endpoints
**Status**: implementing
**Component**: api
**Parent**: F-0300
**Acceptance**: spec/acceptance/F-0301.md  (API contracts, response schemas)

## F-0302: Onboarding UI
**Status**: planned
**Component**: web
**Parent**: F-0300
**Dependencies**: F-0301
**Acceptance**: spec/acceptance/F-0302.md  (visual specs, interaction flows)
```

### Decomposition Command

`ag decompose F-0300` would:
1. Analyze the epic's acceptance criteria
2. Identify which components are involved
3. Propose child features with component assignments
4. Create draft acceptance criteria for each child
5. **Review checkpoint**: decomposition is reviewed before proceeding (see Section 5.1)

---

## 3. Multi-Repo via Umbrella Pattern

### Decision

Support multi-repo projects through an umbrella repository pattern.

### Structure

```
umbrella-repo/
  .agentic/           # Epics, component registry (with repo refs)
  STACK.md             # Components point to external repos
  spec/FEATURES.md     # Epic-level features only

component-repo-api/
  .agentic/            # Own framework instance
  STACK.md             # Own stack, own settings
  spec/FEATURES.md     # Component-scoped features

component-repo-web/
  .agentic/            # Own framework instance
  ...
```

### Component Registry (Multi-Repo)

```markdown
## Components
| Name | Path | Repo | Type | Test Command |
|------|------|------|------|-------------|
| api | ../api-service | git@github.com:org/api.git | python-fastapi | pytest |
| web | ../web-app | git@github.com:org/web.git | nextjs | npm test |
```

### Cross-Component Contracts

- **Shared schemas**: JSON Schema, OpenAPI specs, or protobuf definitions live in a shared location (umbrella repo or dedicated contracts repo).
- **Contract tests**: Each component has tests that validate it conforms to shared contracts. These run as part of the component's test suite.
- **Contract propagation**: When a contract changes, affected components are flagged for re-verification.

### Challenges (Acknowledged)

- **Atomic cross-repo changes**: No perfect solution. Mitigation: contract-first workflow (update contract → update consumers sequentially).
- **State synchronization**: Each repo has its own `.agentic/` state. The umbrella aggregates status but doesn't own component state.
- **Contract drift**: Needs a detection mechanism (see Open Questions).

---

## 4. MCP Server for Agent Coordination

### Decision

Introduce an MCP (Model Context Protocol) server as a real-time coordination layer, sitting on top of file-based persistence.

### Why MCP

The current file-based state (STATUS.md, WIP.md, AGENTS_ACTIVE.md) works for single-agent workflows but has limitations:
- **Polling overhead**: Agents must read files to check state, wasting tokens.
- **Race conditions**: Multiple agents writing the same file can conflict.
- **Cross-repo communication**: File-based state doesn't cross repo boundaries.
- **No event model**: Agents can't subscribe to state changes.

### Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Agent 1    │     │  Agent 2    │     │  Agent 3    │
│  (api work) │     │  (web work) │     │  (tests)    │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       └───────────┬───────┴───────────────────┘
                   │
           ┌───────▼────────┐
           │   MCP Server   │
           │  (coordinator) │
           │                │
           │  - State store │
           │  - Event bus   │
           │  - Scheduler   │
           └───────┬────────┘
                   │
           ┌───────▼────────┐
           │  File System   │
           │  (persistence) │
           │  .agentic/*    │
           └────────────────┘
```

### Design Principles

- **Files remain the source of truth** for anything that needs git-tracking, durability, or human readability. MCP adds speed and structure on top.
- **Session-local state** (which agent is doing what, lock contention, event subscriptions) lives only in MCP — it doesn't need cross-machine portability or git history.
- **Graceful degradation**: If the MCP server isn't running, the framework falls back to file-based coordination. MCP is an accelerator, not a requirement.
- **MCP as state machine executor**: The MCP server can host the formal state machine (Section 5), executing transitions and enforcing preconditions in real-time.

### MCP Tools (Proposed)

| Tool | Purpose |
|------|---------|
| `claim_feature` | Atomically assign a feature to an agent |
| `release_feature` | Release a feature claim |
| `transition_state` | Request a state transition (validated by state machine) |
| `get_unblocked` | Query for features with available transitions |
| `subscribe_state` | Watch for state changes on a feature |
| `report_status` | Structured status update (replaces file writes) |
| `request_review` | Submit transition output for review (routes to human or critical agent) |
| `submit_review` | Critical agent submits review verdict (approve / request-changes / escalate) |

---

## 5. Formal State Machine for Feature Lifecycle

### Decision

Replace prose checklists with a formal state machine (implemented in Python) that defines the feature lifecycle as code.

### States

```
planned → specced → criteria_set → tests_written → implementing → verified → documented → committed → shipped
```

### Forward Transitions & Gates

| From | To | Preconditions (Gates) | Review |
|------|-----|----------------------|--------|
| planned | specced | FEATURES.md entry exists, description written | **Spec review** |
| specced | criteria_set | Acceptance criteria file exists, criteria are testable | **Criteria review** |
| criteria_set | tests_written | Test file exists, tests reference acceptance criteria | — |
| tests_written | implementing | Tests run (and fail — TDD), WIP.md created | **Plan review** (if plan exists) |
| implementing | verified | All acceptance tests pass, smoke test passes | — (automated) |
| verified | documented | Docs updated (per docs_gate setting), CHANGELOG entry | — |
| documented | committed | Pre-commit checks pass, diff reviewed | **Code review** |
| committed | shipped | PR merged (or direct commit in discovery mode) | **Merge approval** |

Transitions marked with **Review** require review before the transition completes. See Section 5.1 for how reviews are resolved.

### 5.1 Review Checkpoints & Critical Agent

#### The Problem

In a fully autonomous flow, blocking on human review at every transition defeats the purpose. But skipping review produces low-quality output. The solution: a **critical review agent** that can substitute for human review at configurable checkpoints.

#### Review Resolution Modes

Each review checkpoint can be resolved by one of:

| Mode | Setting Value | Behavior |
|------|--------------|----------|
| **Human** | `human` | Blocks until human approves. Default for `committed` and `shipped`. |
| **Critical agent** | `critical_agent` | A separate agent instance reviews adversarially. Can approve, request changes, or escalate to human. |
| **Skip** | `skip` | No review gate — transition proceeds if preconditions pass. For trusted/low-risk transitions. |

#### Settings

```markdown
## Review checkpoints
- review_spec: critical_agent
# Who reviews planned → specced. Options: human | critical_agent | skip
- review_criteria: critical_agent
# Who reviews specced → criteria_set. Options: human | critical_agent | skip
- review_plan: critical_agent
# Who reviews plan before implementation. Options: human | critical_agent | skip
- review_code: human
# Who reviews documented → committed. Options: human | critical_agent
- review_merge: human
# Who approves committed → shipped. Options: human | critical_agent
- review_decomposition: critical_agent
# Who reviews epic decomposition. Options: human | critical_agent
- review_regression: human
# Who approves regression transitions. Options: human | critical_agent
```

Defaults are profile-dependent:
- **Discovery**: most checkpoints default to `skip` or `critical_agent`
- **Formal**: early checkpoints default to `critical_agent`, code review and merge default to `human`
- **Locked-down**: all checkpoints default to `human`

#### Critical Agent Behavior

The critical agent is **not** the same agent that produced the work. It is a separate agent instance with:
- **Adversarial mandate**: its job is to find problems, not to approve
- **Access to specs, NFRs, and style guidelines**: it reviews against the project's standards, not just "does it compile"
- **Escalation path**: if the critical agent is uncertain or finds significant issues, it escalates to human rather than approving
- **Review artifact**: produces a structured review (approve / request-changes / escalate) with reasoning, stored alongside the feature

The critical agent does NOT have the power to modify code or specs — only to approve, reject, or escalate. This separation of concerns prevents a single agent from both producing and rubber-stamping its own work.

### 5.2 Taste, Aesthetics & Subjective Decisions

#### The Problem

Some decisions are subjective — UI component choices, color palettes, layout patterns, naming conventions, API style. These can't be validated by tests or acceptance criteria alone. But they're not arbitrary either.

#### How Agents Make Taste Decisions

Agents handle subjective decisions through a hierarchy of guidance:

1. **User-provided vision & style guidelines** (highest priority): The user can provide style references, brand guidelines, design system docs, or explicit preferences (e.g., "minimal, no rounded corners, monochrome"). These live in project docs (e.g., `STYLE_GUIDE.md`, `DESIGN_SYSTEM.md`, or referenced URLs in STACK.md) and are loaded into agent context for relevant features.

2. **Domain best practices & research**: Agents have knowledge of established patterns (e.g., WCAG accessibility, Nielsen heuristics, API design conventions like REST/JSON:API). For unfamiliar domains, agents can research current best practices before making choices.

3. **Broader-level guidelines**: Project-level defaults that set a "probably correct direction" — e.g., "prefer shadcn/ui components", "follow Material Design 3", "API responses use JSON:API format". These reduce per-decision cognitive load without constraining every detail.

4. **Reasoned defaults** (lowest priority): When no guidance exists, agents make a defensible choice, document the reasoning, and flag it for review. The critical agent can challenge taste decisions that seem inconsistent with the project's established patterns.

#### Settings

```markdown
## Style & taste
- style_guide: docs/STYLE_GUIDE.md
# Path to visual/UI style guidelines. Loaded for UI-component features.
- design_system: https://ui.shadcn.com
# Design system reference. Agents use this for component selection.
- api_style: rest-jsonapi
# API design convention. Options: rest-jsonapi | rest-simple | graphql | rpc
- taste_review: critical_agent
# Who reviews subjective/aesthetic decisions. Options: human | critical_agent | skip
```

#### How This Interacts with Reviews

The critical agent reviewing taste decisions checks:
- Consistency with existing patterns in the codebase
- Alignment with declared style guidelines and design system
- Accessibility and usability best practices
- Whether the choice was documented with reasoning

It does **not** impose its own aesthetic preferences — it validates alignment with the project's declared direction.

### Regression Transitions

Features don't always move forward. The state machine must support going backward:

| From | To | When | Preconditions |
|------|-----|------|--------------|
| implementing | specced | Requirements changed fundamentally | Justification logged, spec revision created |
| implementing | criteria_set | Acceptance criteria need adjustment | Justification logged, criteria diff tracked |
| verified | implementing | Tests reveal deeper issues | Failing test identified, WIP.md re-created |
| verified | criteria_set | Criteria themselves were wrong/incomplete | Justification logged, criteria revision |
| committed | implementing | PR review finds issues | Review comments linked, WIP.md re-created |
| shipped | specced | Shipped spec evolves | Migration created (existing contract), downstream features flagged |

### Cascade Rules

Regressions cascade forward — going back invalidates subsequent states:

- Regressing to `criteria_set` invalidates `tests_written`, `implementing`, `verified`
- Regressing to `specced` invalidates everything from `criteria_set` onward
- Each invalidated state must be re-achieved through its normal transition

### Implementation

```python
# Conceptual — actual implementation in future feature work

class FeatureState(Enum):
    PLANNED = "planned"
    SPECCED = "specced"
    CRITERIA_SET = "criteria_set"
    TESTS_WRITTEN = "tests_written"
    IMPLEMENTING = "implementing"
    VERIFIED = "verified"
    DOCUMENTED = "documented"
    COMMITTED = "committed"
    SHIPPED = "shipped"

class FeatureStateMachine:
    """Formal state machine for feature lifecycle."""

    transitions: dict[tuple[State, State], Callable[..., bool]]

    def can_transition(self, feature_id: str, target: State) -> tuple[bool, list[str]]:
        """Check if transition is possible, return (allowed, blocking_reasons)."""
        ...

    def transition(self, feature_id: str, target: State, **context) -> None:
        """Execute transition: check gates, update state, cascade if regression."""
        ...

    def get_unblocked(self) -> list[tuple[str, State]]:
        """Find all features with at least one available forward transition."""
        ...
```

### Migration Path

- Current bash scripts (`feature.sh`, pre-commit checks) become transition handlers.
- Existing `status` field in FEATURES.md maps to state machine states.
- Gradual adoption: state machine validates transitions but doesn't block until proven reliable.

---

## 6. Full Autonomous Flow

### Vision

With components, epics, MCP coordination, and the state machine in place, fully autonomous execution becomes a scheduling problem — with review checkpoints at quality-critical boundaries:

```
User prompt + research + visual guidelines + style refs
  → ag decompose (epic → component features) → [review: decomposition]
  → state machine scheduler (find features with unblocked transitions)
  → per-component agents:
      plan → [review: plan]
      → spec → [review: spec]
      → criteria → [review: criteria]
      → tests → implement → verify
      → document → [review: code] → commit → [review: merge]
  → integration verification per epic
  → shipped product
```

Reviews marked `[review: X]` are resolved per the checkpoint settings (Section 5.1). In autonomous mode, most are handled by the critical agent; code review and merge default to human.

### Scheduler Logic

The autonomous scheduler is simple because the state machine encodes all the complexity:

1. Query `get_unblocked()` — features with available forward transitions
2. For each unblocked feature, check if an agent is already assigned
3. For unassigned features, spawn a **worker agent** scoped to the feature's component
4. Worker agent executes the next transition (e.g., `criteria_set → tests_written`)
5. If the transition has a review checkpoint:
   - If `critical_agent`: spawn a **critical agent** to review; it may approve, request changes, or escalate
   - If `human`: block and notify; scheduler moves to other unblocked work
   - If `skip`: proceed immediately
6. On approval, scheduler re-evaluates and picks next unblocked transitions
7. Repeat until all features in the epic reach `shipped`

The key insight: review checkpoints don't stall the entire pipeline. While one feature awaits human review, the scheduler advances other features. Human attention becomes the bottleneck only for transitions that truly require it.

### Dependency Ordering

Dependency ordering becomes implicit:
- Feature B depends on Feature A
- Feature B's `implementing` transition has a gate: "dependency A is at least `verified`"
- The scheduler simply skips B until A reaches the required state
- No explicit scheduling logic needed — the state machine handles it

### Taste & Subjective Decisions in Autonomous Mode

For features involving subjective choices (UI, naming, API style), agents follow the taste hierarchy from Section 5.2. The autonomous flow:
1. Worker agent loads style guidelines and design system references from STACK.md
2. Makes choices aligned with declared project direction, documenting reasoning
3. Critical agent validates consistency with project patterns and guidelines
4. Only genuinely ambiguous decisions (no guideline coverage, conflicting precedents) escalate to human

This means autonomous mode can handle most aesthetic decisions without blocking, as long as the user has provided a clear enough vision upfront. The richer the style guidelines, the more autonomous the flow.

### Review Checkpoint Summary

| Checkpoint | Default (Formal) | Default (Discovery) | What's Reviewed |
|-----------|-------------------|---------------------|-----------------|
| Decomposition | critical_agent | skip | Epic → feature breakdown, component assignments |
| Spec | critical_agent | skip | Feature description, scope, dependencies |
| Criteria | critical_agent | skip | Acceptance criteria quality, testability |
| Plan | critical_agent | skip | Implementation approach, risks |
| Code | human | critical_agent | Diff quality, correctness, style |
| Merge | human | human | Final approval before shipping |
| Regression | human | critical_agent | Justification for going backward |
| Taste | critical_agent | skip | Consistency with style guidelines |

---

## 7. Open Questions

These are preserved for future design work. Each should become its own ADR or feature spec when addressed.

1. **Epic acceptance criteria format**: How do product-level criteria differ structurally from component-level criteria? Do they reference child features or stand alone?

2. **NFR component scoping**: Can NFRs (spec/NFR.md) be scoped to specific components, or are they always project-wide? Example: "API response time < 200ms" applies only to the `api` component.

3. **Contract drift detection**: What mechanism detects when a component's implementation has drifted from shared contracts? Options: CI job, pre-commit hook, MCP event on contract file change.

4. **CONTEXT_PACK granularity**: Should each component have its own CONTEXT_PACK.md, or does the project-level one suffice with component filtering?

5. **Multi-repo: submodules vs sibling dirs vs path refs**: What's the recommended directory layout for multi-repo projects? Git submodules have known UX issues. Sibling directories are simpler but harder to version-lock.

6. **State machine persistence format**: Should the state machine's state live in FEATURES.md (current `status` field), a separate state file, or only in MCP (with file sync)?

7. **Regression cascade depth**: Should cascading be configurable? Some teams may want partial cascades (e.g., re-verify but don't re-write tests).

8. **Critical agent model selection**: Should the critical agent always use the best available model (e.g., opus), or should it follow the project's `agent_mode` setting? Adversarial review may need stronger reasoning than the work it reviews.

9. **Review history & learning**: Should review outcomes (approve/reject patterns, common issues found) be accumulated to improve future agent output? E.g., "the critical agent always catches missing error handling in API endpoints" → worker agent learns to include it.

10. **Style guide format standardization**: What's the recommended format for style guidelines that agents can parse effectively? Free-form markdown, structured tokens (colors, spacing, typography), or references to existing design systems?

---

## Consequences

### Positive
- Multi-component support unlocks monorepo and multi-repo projects
- Formal state machine makes workflow enforcement testable, debuggable, and extensible
- MCP coordination eliminates file-polling overhead and race conditions
- Epic decomposition enables product-level thinking with component-level execution
- Full autonomous mode becomes a scheduling problem rather than a prompt-engineering problem
- Critical agent reviews maintain quality without requiring constant human attention
- Taste/style guidance system lets autonomous agents make "probably correct" subjective decisions

### Negative
- Significant implementation effort across multiple features
- Python state machine adds a runtime dependency (currently bash-only)
- MCP server adds operational complexity (process management, failure modes)
- Multi-repo support has inherent complexity that can't be fully abstracted away

### Risks
- Over-engineering: These capabilities may not all be needed simultaneously. Implementation should be incremental and demand-driven.
- State machine rigidity: Too-strict enforcement may frustrate users. Needs escape hatches and profile-based flexibility.
- MCP adoption: MCP is relatively new. Protocol stability and tooling maturity are risks.
- Critical agent rubber-stamping: If the critical agent model is too weak or the review prompt too vague, it may approve everything. Needs calibration and periodic human spot-checks.
- Style guideline quality: Autonomous taste decisions are only as good as the declared guidelines. Sparse or contradictory guidelines produce inconsistent output.

---

## Implementation Order (Suggested)

1. **Components as metadata** (Section 1) — lowest risk, highest standalone value
2. **Epics as parent features** (Section 2) — builds on components, enables decomposition
3. **Formal state machine** (Section 5) — can start with forward-only, add regressions later
4. **MCP server** (Section 4) — becomes the state machine executor
5. **Multi-repo umbrella** (Section 3) — builds on all of the above
6. **Full autonomous flow** (Section 6) — integration of everything

Each step should be its own feature (or set of features) with acceptance criteria and incremental delivery.
