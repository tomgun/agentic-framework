# Agentic Framework Architecture Exploration Report
**Date**: 2026-03-31
**Purpose**: Comprehensive architecture analysis for F-040 (App Store Publishing) planning

---

## 1. Framework High-Level Purpose & Values

**What it does**: The Agentic AI Framework is a spec-driven, multi-agent orchestration system for sustainable long-term software development. It enables AI agents and humans to collaborate on complex projects using structured workflows, quality gates, and persistent state.

**Core value proposition**:
- **Developer UX**: Session state recovery, decision surfacing, automatic documentation, passive learning
- **Sustainable Quality**: Specs -> acceptance criteria -> tests -> code, all in sync, all enforced
- **Token & Context Optimization**: Minimal context loading, specialized agent roles, token-efficient scripts (40x cheaper than read-modify-write)

**13 Foundational Principles** (F-level, D-level, R-level):
- **F1**: Developer-friendly experience (human remembers nothing, framework remembers)
- **F2**: Sustainable long-term quality (specs + criteria + tests prevent silent regressions)
- **F3**: Token efficiency (minimal context, dedicated scripts, structured file formats)
- **D1**: Human-Agent Partnership (specs are collaboration interface)
- **D2**: Deterministic Enforcement (scripts > documentation; CLI gates prevent bypasses)
- **D3**: Durable Artifacts (CONTEXT_PACK, STATUS, JOURNAL survive context resets)
- **D4**: Small Batch + Acceptance-Driven (one feature at a time, 5-10 files per commit, ACs before code)
- **D5**: Living Documentation (docs updated same commit as code; single source of truth)
- **D6**: Green Coding (environmentally efficient software guidance)
- **D7**: Multi-Environment Portability (works in Claude, Cursor, Copilot, Codex equally)
- **R1**: Anti-Hallucination (never fabricate; state uncertainty or look it up)
- **R2**: No auto-commits without approval (except autonomous execution with critical agent review)
- **R3**: Check before creating (search for duplicates first)

---

## 2. Three-Layer Instruction Architecture

### Layer 1: Constitution (~40-100 lines)
**Structural enforcement + behavioral rules**
- `state_machine_af.yaml` -- Defines workflow states, transitions, gates, modes, profiles
- `CLAUDE.md` (~40 lines) -- Core behavioral rules (anti-hallucination, trigger patterns, decision escalation)
- `.cursorrules`, `copilot-instructions.md`, `codex-instructions.md` -- Tool-specific variants
- Loaded for the **orchestrator agent only**; subagents are context-isolated

### Layer 2: Playbooks (Role-specific JIT guidance)
**Loaded when transitions occur**
- 7 **role prompts** in `.agentic/prompts/`:
  - `planner.md` (planning & designing states)
  - `reviewer.md` (plan_review state)
  - `implementer.md` (implementation & docs states)
  - `verifier.md` (verification & ready_to_ship states)
  - `debugger.md`, `session.md`, `explorer.md`
- 13 **Claude skills** (trigger-word stubs in `.claude/skills/`)
- **Conventions.md** -- Single source of truth for code quality standards

### Layer 3: Project State (Per-feature work items)
**Git-tracked + session-local**
- `.agentic/work/F-XXXX/item.yaml` -- Feature state
- Co-located artifacts: `plan.md`, `spec.md`, `review.md`, `verification.json`, `journal.md`
- `STACK.md` -- Project-level config
- `STATUS.md`, `CONTEXT_PACK.md`, `JOURNAL.md` -- Durable artifacts for session recovery
- `AGENTS.json` (session-local, gitignored) -- Agent registration + WIP tracking

---

## 3. Workflow State Machine & Feature Lifecycle

**States** (in `state_machine_af.yaml`):
```
idea -> queued -> planning -> [optional: designing] -> plan_review -> spec ->
implementation -> verification -> docs -> ready_to_ship -> shipped
```

Plus regression paths and `deprecated` (terminal).

**Transitions are gated** -- preconditions checked before move:
- `planning` -> `plan_review` requires `plan.md`
- `plan_review` -> `spec` requires `review.md`
- `spec` -> `implementation` requires `spec.md`
- `verification` -> `docs` requires tests passing
- `docs` -> `ready_to_ship` requires documentation updated
- `ready_to_ship` -> `shipped` requires PR merged

**Profiles control review checkpoints**:
- **Discovery**: Human reviews everything (default for new projects)
- **Formal**: Human reviews specs + merges; AI reviews code + regressions
- **Autonomous_formal**: AI reviews everything except merge

---

## 4. How AG Commands Work

**`ag.sh`** is the single entry point -- all operations go through CLI dispatch:

```bash
ag start F-XXXX "Title"          # Create feature, initialize work dir
ag transition F-XXXX <state>     # Move to next state (gated by preconditions)
ag check F-XXXX                  # Show what's missing
ag verify F-XXXX                 # Run tests
ag done F-XXXX                   # Post-merge: docs gate, VERSION bump, state flush
ag contract check F-XXXX         # Verify contract assertions pass
ag plan F-XXXX                   # Create plan
ag spec F-XXXX                   # Create/update spec and acceptance criteria
ag implement F-XXXX              # Start implementation (enforces plan approval)
ag commit "message"              # Stage + commit with gates
ag flush                         # Push all pending state to main
ag set <key> <value>             # Update STACK.md settings
```

**Auto execution** (autonomous modes):
```bash
ag auto task F-XXXX              # Implement single feature autonomously
ag auto crunch [--features .]    # Batch multiple features
ag auto epic F-XXXX              # Execute epic + children in parallel
ag auto verify                   # Test-fix loop until green
ag auto pipeline                 # End-to-end: vision -> epic -> ship
```

**Enforcement gates** in `ag.sh`:
- Checks `AGENTS.json` for active WIP
- Validates feature state before transitions
- Loads role prompts when state changes
- Enforces small batch rules (5-10 files per commit)
- Calls `pre-commit-check.sh` before allowing commits

---

## 5. Feature Definition & Contracts

**Features are defined as YAML contracts**: `.agentic/spec/contracts/F-XXXX.yaml`

**Contract structure** (F-031: Spec System Overhaul):
```yaml
id: F-0042
name: Feature Display Name
lifecycle: shipped | in_progress | planned | exploring
since: v0.40.0
profile: both | formal | discovery
protection: contract | open
category: core-workflow | quality | autonomous | etc.

description: |
  What this feature does

assertions:
  - id: AC-001
    text: "What must be true"
    type: structural | behavioral
    verify: "bash check command" | null
    tests:
      - tests/test_file.py::test_name

nfr_refs: [NFR-0001, NFR-0003]

scenarios:
  - name: "Happy path"
    given: "Setup"
    when: "Action"
    then: "Result"

migrations:
  - id: M-DATE-###
    date: "YYYY-MM-DD"
    trigger: "implementation_discovery"
    description: "What changed and why"
```

**Key properties**:
- Shipped contracts are protected -- modifications require a migration entry
- Assertions are verifiable -- structural checks run in CI, behavioral tests are LLM-verified
- `user_input` field for pending human input

---

## 6. Skills & Trigger Words

**Skills** are Claude Code feature stubs matching user intent to framework commands:

**Structure** (in `.claude/skills/<skill-name>/SKILL.md`):
```yaml
name: implementing-features
description: "Use when user says 'build', 'implement', 'add feature'..."
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, Agent]
```

**Trigger examples**:
- `implementing-features` -> "build", "implement", "add feature", "create [thing]"
- `writing-specs` -> "write spec", "create spec", "update spec"
- `fixing-bugs` -> "fix", "debug", "there's a bug"
- `session-start` -> "where were we", "what's the status"
- `planning-features` -> "plan", "design", "architecture"
- `committing-changes` -> "commit", "push", "ship"
- `completing-work` -> "done", "finished", "merged"

---

## 7. Automation & Orchestration

**Autonomous execution engine** (Python, in `.agentic/lib/auto/`):

**Components**:
- `engine.py` -- Core execution loop
- `task.py` -- Single-feature implementation
- `crunch.py` -- Batch mode
- `scheduler.py` + `epic.py` -- Epic execution with parallel children
- `verify.py` -- Test-fix loop
- `pipeline.py` -- End-to-end workflow
- `control.py` -- Unix socket control server
- `critical_agent.py` -- Adversarial reviewer for autonomous code review
- `framework_verify.py` -- Self-verification

**Control plane** (F-018):
- HTTP JSON-RPC on port 4185
- Bearer token auth
- `ag coord start`, `ag coord stop`, `ag coord status`

**Execution flow** (`ag auto task F-XXXX`):
1. Preconditions check (gates.py)
2. Context assembly (context-for-role.sh + orchestrator-agent.yaml)
3. Spawn subagent (Python spawner, fresh context)
4. Verification loop (verify.py)
5. Commit gate (pre-commit-check.sh)
6. Transition gate (state_machine.py)
7. Documentation gate (docs.sh)

---

## 8. STACK.md - Project Configuration

**Purpose**: Single source of truth for "how we build and run software here"

**Key sections**:
- `## Settings` -- Profile, workflow, quality gates (~50 settings)
- `## Summary` -- What we're building, primary platform
- `## Languages & runtimes` -- Tech stack
- `## Frameworks & libraries` -- App framework, UI framework
- `## Testing` -- Test frameworks, commands
- `## Development approach` -- Standard (acceptance-driven) or TDD
- `## Agent mode` -- premium | balanced | economy
- `## Plan-Review Loop` -- Iterative planning config
- `## PR Review` -- Auto-review config
- `## Sequential agent pipeline` -- Multi-agent specialization

---

## 9. Existing Features & Capabilities (v0.77.0)

**Core workflow** (8 features): F-001 through F-009
**Quality** (6 features): F-008 through F-014
**Session & recovery** (5 features): F-015 through F-019
**Autonomous execution** (3 features): F-029, F-030, F-039
**Architecture** (4 features): F-020 through F-023
**Git workflow** (2 features): F-024, F-035
**Developer experience** (5 features): F-025 through F-028, F-036
**Development infrastructure** (4 features): DEV-001 through DEV-004

---

## 10. Architecture Patterns for New Features

1. **Feature consolidation** (F-031 pattern): Consolidate into major contracts with `consolidated_from:` field
2. **Multi-mode execution**: Formal, autonomous, autonomous_formal profiles
3. **Modular engines**: Core logic in Python, CLI dispatch in bash, tools in scripts, role prompts in markdown
4. **Acceptance-driven**: ACs first, verification loops test each AC independently
5. **State machine gating**: Preconditions checked structurally, modes control reviewer roles
6. **Token-efficient context**: Minimal viable context per task (5-10K tokens)
7. **Living documentation**: Docs updated same commit as code, doc registry in STACK.md
8. **Anti-hallucination + verification**: Structural assertions in CI, behavioral via LLM tests

---

## 11. Key Files Reference

- `.agentic/spec/FEATURES.md` -- Feature list with consolidation mapping
- `.agentic/spec/contracts/` -- All contract definitions
- `.agentic/lib/tools/ag.sh` -- CLI entry point, command dispatch
- `.agentic/lib/auto/` -- Autonomous execution engines
- `.agentic/state_machine_af.yaml` -- Workflow states and transitions
- `.agentic/conventions.md` -- Coding standards
- `.agentic/prompts/` -- Role prompts (7 files)
- `.claude/skills/*/SKILL.md` -- Skill definitions
- `FRAMEWORK_QUICK_START.md` -- Dev quick reference
- `FRAMEWORK_DEVELOPMENT.md` -- Full framework dev guide
- `.agentic/lib/PRINCIPLES.md` -- Foundational principles
- `docs/INSTRUCTION_ARCHITECTURE.md` -- Three-layer instruction design
- `STACK.md` -- Framework's own configuration
