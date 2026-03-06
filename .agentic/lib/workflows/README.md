# Workflow Documents Guide

This directory contains workflow and process documents. **Not all are needed for every project.** This guide helps you find the right document.

---

## Primary Approach: Acceptance-Driven Development

The framework recommends **Acceptance-Driven Development** as the default:

1. **Define feature + acceptance criteria** (rough is OK)
2. **Implement feature** (AI can generate large chunks quickly)
3. **Verify with acceptance tests**
4. **Update specs with discoveries** (edge cases, issues, ideas)
5. **Commit when tests pass**
6. **Move to next feature**

See [spec_evolution.md](spec_evolution.md) for how specs evolve during implementation.

---

## Checklists (USE THESE)

**These are the primary documents for day-to-day work:**

| When | Checklist |
|------|-----------|
| Starting session | [../checklists/session_start.md](../checklists/session_start.md) |
| Implementing feature | [../checklists/feature_implementation.md](../checklists/feature_implementation.md) |
| Verifying code works | [../checklists/smoke_testing.md](../checklists/smoke_testing.md) |
| Before commit | [../checklists/before_commit.md](../checklists/before_commit.md) |
| Feature done | [../checklists/feature_complete.md](../checklists/feature_complete.md) |
| Ending session | [../checklists/session_end.md](../checklists/session_end.md) |

---

## Development Modes

| Mode | Description | When to Use |
|------|-------------|-------------|
| **Standard** (default) | Acceptance-Driven: implement then test | Most projects, AI-generated code |
| **TDD** (optional) | Tests first, then implement | Critical logic, refactoring, preference |

Set in `STACK.md` → `development_mode: standard` or `tdd`

- Standard workflow: [spec_evolution.md](spec_evolution.md)
- TDD workflow: [tdd_mode.md](tdd_mode.md)

---

## Quality Documents

| Document | Purpose |
|----------|---------|
| [definition_of_done.md](definition_of_done.md) | What "done" means for features |
| [../quality/programming_standards.md](../quality/programming_standards.md) | Code quality guidelines |
| [../quality/testing_standards.md](../quality/testing_standards.md) | What and how to test |
| [../quality/library_selection.md](../quality/library_selection.md) | When to use libraries vs custom code |

---

## Session & Recovery Documents

| Document | Purpose |
|----------|---------|
| [work_in_progress.md](work_in_progress.md) | WIP tracking for interrupted work |
| [recovery.md](recovery.md) | Recovering from interruptions |
| [automatic_journaling.md](automatic_journaling.md) | Auto-logging checkpoints |
| [environment_switching.md](environment_switching.md) | Switching between AI environments |

---

## Git & Collaboration Documents

| Document | Purpose |
|----------|---------|
| [git_workflow.md](git_workflow.md) | Git practices (direct vs PR mode) |
| [multi_agent_coordination.md](multi_agent_coordination.md) | Multiple AI agents working together |
| [sequential_agent_specialization.md](sequential_agent_specialization.md) | Specialized agents in sequence |

---

## Optional / Advanced Documents

These are for specific scenarios, not everyday use:

| Document | Purpose |
|----------|---------|
| [research_mode.md](research_mode.md) | Deep research into technologies |
| [retrospective.md](retrospective.md) | Periodic project health checks |
| [visual_design_workflow.md](visual_design_workflow.md) | Working with designs/wireframes |
| [media_asset_workflow.md](media_asset_workflow.md) | Sourcing images, audio, etc. |
| [continuous_quality_validation.md](continuous_quality_validation.md) | Automated quality gates |
| [documentation_verification.md](documentation_verification.md) | Ensuring doc versions match |
| [mutation_testing.md](mutation_testing.md) | Advanced test quality validation |

---

## Quick Reference: What to Read When

### Starting a new session
→ [session_start.md](../checklists/session_start.md)

### Implementing a feature
→ [feature_implementation.md](../checklists/feature_implementation.md)

### Before committing
→ [before_commit.md](../checklists/before_commit.md) + [smoke_testing.md](../checklists/smoke_testing.md)

### Choosing a library
→ [library_selection.md](../quality/library_selection.md)

### Recovering from interruption
→ [recovery.md](recovery.md)

### Running retrospective
→ [retrospective.md](retrospective.md)

---

## Key Principle: Small Batches

All workflows support the **Small Batch Development** principle:

- ONE feature at a time
- Acceptance criteria before coding
- Commit when tests pass
- Update specs with discoveries
- Easy rollback via frequent commits

See [PRINCIPLES.md](../PRINCIPLES.md#small-batch-development-non-negotiable) for details.

