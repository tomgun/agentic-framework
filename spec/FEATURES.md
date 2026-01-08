# Agentic AI Framework - Feature Specification

<!-- format: features-v0.2.0 -->

**Purpose**: Define what the Agentic AI Framework can reliably do at each version.

**Version**: 0.7.0

---

## Feature Categories

| Category | Features | Description |
|----------|----------|-------------|
| **Core** | F-0001 to F-0010 | Essential framework capabilities |
| **Quality** | F-0011 to F-0020 | Quality enforcement and standards |
| **Session** | F-0021 to F-0030 | Session management and continuity |
| **Multi-Agent** | F-0031 to F-0040 | Multi-agent coordination |
| **Tooling** | F-0041 to F-0050 | Scripts and automation |
| **Recovery** | F-0051 to F-0060 | Error recovery and resilience |
| **Developer Experience** | F-0061 to F-0070 | Documentation, onboarding, usability |
| **Design Principles** | F-0071 to F-0080 | Core framework principles as specs |

---

## F-0001: Project Initialization

**Status**: shipped  
**Priority**: critical  
**Complexity**: medium  
**Since**: v0.1.0

**Description**: Initialize a new project with the Agentic framework, choosing between Core and Core+PM profiles.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `install.sh`, `.agentic/init/scaffold.sh`, `.agentic/init/init_playbook.md`
- Tests: manual (validation in acceptance criteria)

**Acceptance**: See `spec/acceptance/F-0001.md`

---

## F-0002: Profile Selection (Core vs Core+PM)

**Status**: shipped  
**Priority**: critical  
**Complexity**: low  
**Since**: v0.2.0

**Description**: Two framework profiles - Core (quality + workflows) and Core+PM (adds spec-driven development, feature tracking).

**Dependencies**: F-0001

**Implementation**:
- State: complete
- Code: `.agentic/init/init_playbook.md`, `STACK.md` profile field
- Tests: manual

**Acceptance**: See `spec/acceptance/F-0002.md`

---

## F-0003: Spec-Driven Development

**Status**: shipped  
**Priority**: high  
**Complexity**: high  
**Since**: v0.1.0

**Description**: Manage features through markdown specifications with status tracking, dependencies, and acceptance criteria.

**Dependencies**: F-0002 (Core+PM profile)

**Implementation**:
- State: complete
- Code: `spec/FEATURES.md`, `spec/acceptance/`, `.agentic/spec/` templates
- Tests: `tests/test_validate_specs.py`

**Acceptance**: See `spec/acceptance/F-0003.md`

---

## F-0004: Feature Tracking & Status

**Status**: shipped  
**Priority**: high  
**Complexity**: medium  
**Since**: v0.1.0

**Description**: Track feature lifecycle (planned → in_progress → shipped), implementation state, test coverage.

**Dependencies**: F-0003

**Implementation**:
- State: complete
- Code: `.agentic/tools/feature.sh`, `spec/FEATURES.md` schema
- Tests: `tests/test_query_features.py`

**Acceptance**: See `spec/acceptance/F-0004.md`

---

## F-0005: Acceptance Criteria Files

**Status**: shipped  
**Priority**: high  
**Complexity**: low  
**Since**: v0.1.0

**Description**: Each feature must have acceptance criteria in `spec/acceptance/F-####.md`.

**Dependencies**: F-0003

**Implementation**:
- State: complete
- Code: `.agentic/hooks/feature-complete.sh`, templates
- Tests: validation in hooks

**Acceptance**: See `spec/acceptance/F-0005.md`

---

## F-0006: Acceptance-Driven Development

**Status**: shipped  
**Priority**: critical  
**Complexity**: medium  
**Since**: v0.7.0

**Description**: Primary development methodology - implement feature, then verify with acceptance tests. Specs evolve during implementation.

**Dependencies**: F-0005

**Implementation**:
- State: complete
- Code: `.agentic/PRINCIPLES.md`, `.agentic/workflows/spec_evolution.md`
- Tests: documented workflow

**Acceptance**: See `spec/acceptance/F-0006.md`

---

## F-0007: Small Batch Development

**Status**: shipped  
**Priority**: critical  
**Complexity**: low  
**Since**: v0.7.0

**Description**: Work in small, isolated batches - one feature at a time per agent, max 5-10 files per commit.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/hooks/pre-commit-check.sh`, agent guidelines
- Tests: hook enforcement

**Acceptance**: See `spec/acceptance/F-0007.md`

---

## F-0008: TDD Mode (Optional)

**Status**: shipped  
**Priority**: medium  
**Complexity**: medium  
**Since**: v0.2.0

**Description**: Optional test-driven development mode - write tests first, then implement.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/workflows/tdd_mode.md`, STACK.md config
- Tests: documented workflow

**Acceptance**: See `spec/acceptance/F-0008.md`

---

## F-0009: PRODUCT.md (Core Profile)

**Status**: shipped  
**Priority**: high  
**Complexity**: low  
**Since**: v0.2.0

**Description**: Lightweight product documentation for Core profile - vision, capabilities, known issues.

**Dependencies**: F-0002

**Implementation**:
- State: complete
- Code: `.agentic/init/PRODUCT.template.md`
- Tests: manual

**Acceptance**: See `spec/acceptance/F-0009.md`

---

## F-0010: Spec Evolution Workflow

**Status**: shipped  
**Priority**: high  
**Complexity**: low  
**Since**: v0.7.0

**Description**: Documented workflow for updating specs during implementation with discoveries.

**Dependencies**: F-0006

**Implementation**:
- State: complete
- Code: `.agentic/workflows/spec_evolution.md`
- Tests: documented workflow

**Acceptance**: See `spec/acceptance/F-0010.md`

---

## F-0011: Programming Standards

**Status**: shipped  
**Priority**: high  
**Complexity**: medium  
**Since**: v0.3.0

**Description**: Comprehensive code quality guidelines - naming, functions, error handling, security, green coding.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/quality/programming_standards.md`
- Tests: agent compliance

**Acceptance**: See `spec/acceptance/F-0011.md`

---

## F-0012: Testing Standards

**Status**: shipped  
**Priority**: high  
**Complexity**: medium  
**Since**: v0.3.0

**Description**: Comprehensive testing guidelines - happy path, edge cases, invalid input, time-based, concurrency.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/quality/testing_standards.md`
- Tests: agent compliance

**Acceptance**: See `spec/acceptance/F-0012.md`

---

## F-0013: Smoke Testing Checklist

**Status**: shipped  
**Priority**: critical  
**Complexity**: low  
**Since**: v0.4.3

**Description**: Mandatory verification that code actually works before committing user-facing changes.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/checklists/smoke_testing.md`
- Tests: checklist enforcement

**Acceptance**: See `spec/acceptance/F-0013.md`

---

## F-0014: Library Selection Guidelines

**Status**: shipped  
**Priority**: high  
**Complexity**: low  
**Since**: v0.4.3

**Description**: Decision framework for choosing libraries vs custom code, especially for custom/hybrid projects.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/quality/library_selection.md`
- Tests: agent compliance

**Acceptance**: See `spec/acceptance/F-0014.md`

---

## F-0015: Quality Profiles (Stack-Specific)

**Status**: shipped  
**Priority**: medium  
**Complexity**: high  
**Since**: v0.3.0

**Description**: Stack-specific quality checks - audio plugins, web apps, mobile, backend, games.

**Dependencies**: F-0011

**Implementation**:
- State: complete
- Code: `.agentic/quality/quality_profiles/`
- Tests: per-profile validation

**Acceptance**: See `spec/acceptance/F-0015.md`

---

## F-0016: Pre-Commit Quality Gates

**Status**: shipped  
**Priority**: critical  
**Complexity**: medium  
**Since**: v0.6.0

**Description**: Blocking validation before commits - WIP check, acceptance criteria, batch size warning.

**Dependencies**: F-0007

**Implementation**:
- State: complete
- Code: `.agentic/hooks/pre-commit-check.sh`
- Tests: hook validation

**Acceptance**: See `spec/acceptance/F-0016.md`

---

## F-0017: Feature Completion Validator

**Status**: shipped  
**Priority**: high  
**Complexity**: medium  
**Since**: v0.6.0

**Description**: Validate feature meets definition of done before marking as shipped.

**Dependencies**: F-0005

**Implementation**:
- State: complete
- Code: `.agentic/hooks/feature-complete.sh`
- Tests: hook validation

**Acceptance**: See `spec/acceptance/F-0017.md`

---

## F-0021: Session Start Protocol

**Status**: shipped  
**Priority**: critical  
**Complexity**: medium  
**Since**: v0.4.0

**Description**: Mandatory steps when starting a work session - WIP check, read context, understand state.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/checklists/session_start.md`, `.agentic/hooks/session-start.sh`
- Tests: hook enforcement

**Acceptance**: See `spec/acceptance/F-0021.md`

---

## F-0022: Session End Protocol

**Status**: shipped  
**Priority**: critical  
**Complexity**: low  
**Since**: v0.4.0

**Description**: Mandatory steps when ending a work session - update JOURNAL, document blockers, clean up.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/checklists/session_end.md`
- Tests: checklist enforcement

**Acceptance**: See `spec/acceptance/F-0022.md`

---

## F-0023: JOURNAL.md Session Tracking

**Status**: shipped  
**Priority**: high  
**Complexity**: low  
**Since**: v0.1.0

**Description**: Session-by-session progress log with achievements, decisions, blockers.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/tools/journal.sh`, templates
- Tests: format validation

**Acceptance**: See `spec/acceptance/F-0023.md`

---

## F-0024: STATUS.md Current State

**Status**: shipped  
**Priority**: high  
**Complexity**: low  
**Since**: v0.1.0

**Description**: Current project state - focus, progress, next steps.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/tools/status.sh`, templates
- Tests: format validation

**Acceptance**: See `spec/acceptance/F-0024.md`

---

## F-0025: CONTEXT_PACK.md Architecture

**Status**: shipped  
**Priority**: high  
**Complexity**: medium  
**Since**: v0.1.0

**Description**: Architecture snapshot - modules, entry points, key files.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: templates
- Tests: manual

**Acceptance**: See `spec/acceptance/F-0025.md`

---

## F-0026: HUMAN_NEEDED.md Escalation

**Status**: shipped  
**Priority**: critical  
**Complexity**: low  
**Since**: v0.1.0

**Description**: Document blockers requiring human action - credentials, decisions, manual setup.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/tools/blocker.sh`, templates
- Tests: format validation

**Acceptance**: See `spec/acceptance/F-0026.md`

---

## F-0027: Automatic Journaling

**Status**: shipped  
**Priority**: high  
**Complexity**: medium  
**Since**: v0.4.3

**Description**: Two-tier logging - SESSION_LOG.md for checkpoints, JOURNAL.md for milestones.

**Dependencies**: F-0023

**Implementation**:
- State: complete
- Code: `.agentic/tools/session_log.sh`, `.agentic/workflows/automatic_journaling.md`
- Tests: script validation

**Acceptance**: See `spec/acceptance/F-0027.md`

---

## F-0028: Continue-Here Generator

**Status**: shipped  
**Priority**: medium  
**Complexity**: medium  
**Since**: v0.3.5

**Description**: Generate `.continue-here.md` for quick context recovery.

**Dependencies**: F-0023, F-0024

**Implementation**:
- State: complete
- Code: `.agentic/tools/continue_here.py`
- Tests: script validation

**Acceptance**: See `spec/acceptance/F-0028.md`

---

## F-0031: Multi-Agent Coordination

**Status**: shipped  
**Priority**: high  
**Complexity**: high  
**Since**: v0.2.0

**Description**: Multiple AI agents working simultaneously on different features using Git worktrees.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/workflows/multi_agent_coordination.md`, `AGENTS_ACTIVE.md` template
- Tests: documented workflow

**Acceptance**: See `spec/acceptance/F-0031.md`

---

## F-0032: Git Worktree Setup

**Status**: shipped  
**Priority**: high  
**Complexity**: medium  
**Since**: v0.2.0

**Description**: Each agent gets dedicated worktree and branch for isolation.

**Dependencies**: F-0031

**Implementation**:
- State: complete
- Code: documentation in multi_agent_coordination.md
- Tests: manual

**Acceptance**: See `spec/acceptance/F-0032.md`

---

## F-0033: AGENTS_ACTIVE.md Coordination

**Status**: shipped  
**Priority**: high  
**Complexity**: low  
**Since**: v0.2.0

**Description**: Shared file tracking which agents are working on what features.

**Dependencies**: F-0031

**Implementation**:
- State: complete
- Code: `.agentic/spec/AGENTS_ACTIVE.template.md`
- Tests: format validation

**Acceptance**: See `spec/acceptance/F-0033.md`

---

## F-0034: Sequential Agent Pipeline

**Status**: shipped  
**Priority**: medium  
**Complexity**: high  
**Since**: v0.3.0

**Description**: Specialized agents work in sequence - Research → Plan → Test → Implement → Review.

**Dependencies**: F-0031

**Implementation**:
- State: complete
- Code: `.agentic/workflows/sequential_agent_specialization.md`
- Tests: documented workflow

**Acceptance**: See `spec/acceptance/F-0034.md`

---

## F-0041: Token-Efficient Update Scripts

**Status**: shipped  
**Priority**: high  
**Complexity**: medium  
**Since**: v0.4.3

**Description**: Shell scripts for updating docs without reading entire files - journal.sh, status.sh, feature.sh, blocker.sh.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/tools/journal.sh`, `status.sh`, `feature.sh`, `blocker.sh`
- Tests: script validation

**Acceptance**: See `spec/acceptance/F-0041.md`

---

## F-0042: Feature Query Tool

**Status**: shipped  
**Priority**: medium  
**Complexity**: medium  
**Since**: v0.3.0

**Description**: Query and filter features by status, complexity, category.

**Dependencies**: F-0004

**Implementation**:
- State: complete
- Code: `.agentic/tools/query_features.py`
- Tests: `tests/test_query_features.py`

**Acceptance**: See `spec/acceptance/F-0042.md`

---

## F-0043: Spec Validation Tool

**Status**: shipped  
**Priority**: high  
**Complexity**: medium  
**Since**: v0.3.0

**Description**: Validate spec file format, required fields, cross-references.

**Dependencies**: F-0003

**Implementation**:
- State: complete
- Code: `.agentic/tools/validate_specs.py`
- Tests: `tests/test_validate_specs.py`

**Acceptance**: See `spec/acceptance/F-0043.md`

---

## F-0044: Framework Age Check

**Status**: shipped  
**Priority**: low  
**Complexity**: low  
**Since**: v0.4.4

**Description**: Check if framework installation is >1 month old and suggest research for updates.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/tools/framework_age.sh`
- Tests: script validation

**Acceptance**: See `spec/acceptance/F-0044.md`

---

## F-0051: WIP Tracking

**Status**: shipped  
**Priority**: critical  
**Complexity**: medium  
**Since**: v0.5.0

**Description**: Track work-in-progress to prevent loss from interruptions, crashes, token limits.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/tools/wip.sh`, `.agentic/workflows/work_in_progress.md`
- Tests: script validation

**Acceptance**: See `spec/acceptance/F-0051.md`

---

## F-0052: WIP.md Lock File

**Status**: shipped  
**Priority**: critical  
**Complexity**: low  
**Since**: v0.5.0

**Description**: Lock file created when work starts, contains feature, files, progress, recovery instructions.

**Dependencies**: F-0051

**Implementation**:
- State: complete
- Code: `.agentic/tools/wip.sh`
- Tests: format validation

**Acceptance**: See `spec/acceptance/F-0052.md`

---

## F-0053: Recovery Protocol

**Status**: shipped  
**Priority**: high  
**Complexity**: medium  
**Since**: v0.6.0

**Description**: Formal 5-step recovery process for interrupted work.

**Dependencies**: F-0051

**Implementation**:
- State: complete
- Code: `.agentic/workflows/recovery.md`
- Tests: documented workflow

**Acceptance**: See `spec/acceptance/F-0053.md`

---

## F-0054: Multi-Environment Support

**Status**: shipped  
**Priority**: high  
**Complexity**: medium  
**Since**: v0.4.4

**Description**: Seamlessly work across Claude, Cursor, Copilot - switch when tokens run out.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/workflows/environment_switching.md`
- Tests: documented workflow

**Acceptance**: See `spec/acceptance/F-0054.md`

---

## F-0055: Anti-Hallucination Rules

**Status**: shipped  
**Priority**: critical  
**Complexity**: low  
**Since**: v0.3.5

**Description**: Non-negotiable rules preventing agents from making things up.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/agents/shared/agent_operating_guidelines.md`
- Tests: agent compliance

**Acceptance**: See `spec/acceptance/F-0055.md`

---

## F-0056: Framework Upgrade

**Status**: shipped  
**Priority**: medium  
**Complexity**: medium  
**Since**: v0.2.4

**Description**: Upgrade existing project to newer framework version.

**Dependencies**: F-0001

**Implementation**:
- State: complete
- Code: `upgrade.sh`, `UPGRADING.md`
- Tests: manual

**Acceptance**: See `spec/acceptance/F-0056.md`

---

## F-0061: DEVELOPER_GUIDE.md

**Status**: shipped  
**Priority**: high  
**Complexity**: high  
**Since**: v0.2.4

**Description**: Comprehensive user guide covering installation, usage, customization, troubleshooting.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/DEVELOPER_GUIDE.md`
- Tests: manual review

**Acceptance**: See `spec/acceptance/F-0061.md`

---

## F-0062: START_HERE.md First-Time Guidance

**Status**: shipped  
**Priority**: high  
**Complexity**: low  
**Since**: v0.2.0

**Description**: Clear entry point for new users with profile selection and next steps.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/START_HERE.md`
- Tests: manual review

**Acceptance**: See `spec/acceptance/F-0062.md`

---

## F-0063: README Documentation Quality

**Status**: shipped  
**Priority**: high  
**Complexity**: medium  
**Since**: v0.1.0

**Description**: Clear, accurate README with quick start, installation, feature overview.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `README.md`, `.agentic/README.md`
- Tests: manual review

**Acceptance**: See `spec/acceptance/F-0063.md`

---

## F-0064: Script Help Messages

**Status**: shipped  
**Priority**: medium  
**Complexity**: low  
**Since**: v0.3.0

**Description**: All scripts have clear --help / usage messages with examples.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: All scripts in `.agentic/tools/`, `.agentic/hooks/`
- Tests: script validation

**Acceptance**: See `spec/acceptance/F-0064.md`

---

## F-0065: Error Message Quality

**Status**: shipped  
**Priority**: medium  
**Complexity**: low  
**Since**: v0.3.0

**Description**: Scripts provide clear, actionable error messages when things go wrong.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: All scripts
- Tests: error scenario testing

**Acceptance**: See `spec/acceptance/F-0065.md`

---

## F-0066: Template Quality

**Status**: shipped  
**Priority**: high  
**Complexity**: medium  
**Since**: v0.1.0

**Description**: All templates are well-documented with examples and clear placeholders.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/init/*.template.md`, `.agentic/spec/*.template.md`
- Tests: manual review

**Acceptance**: See `spec/acceptance/F-0066.md`

---

## F-0067: MANUAL_OPERATIONS.md

**Status**: shipped  
**Priority**: medium  
**Complexity**: low  
**Since**: v0.2.0

**Description**: Human-readable guide for querying project state without AI agents.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/MANUAL_OPERATIONS.md`
- Tests: manual review

**Acceptance**: See `spec/acceptance/F-0067.md`

---

## F-0068: Upgrade Experience

**Status**: shipped  
**Priority**: high  
**Complexity**: medium  
**Since**: v0.2.4

**Description**: Clear upgrade path with UPGRADING.md guide and upgrade.sh script.

**Dependencies**: F-0001

**Implementation**:
- State: complete
- Code: `UPGRADING.md`, `upgrade.sh`
- Tests: manual testing

**Acceptance**: See `spec/acceptance/F-0068.md`

---

## F-0069: Checklist-Driven Workflows

**Status**: shipped  
**Priority**: high  
**Complexity**: medium  
**Since**: v0.4.0

**Description**: All major workflows have clear checklists that agents can follow systematically.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/checklists/` (7 checklists)
- Tests: checklist validation

**Acceptance**: See `spec/acceptance/F-0069.md`

---

## F-0070: Workflow Document Organization

**Status**: shipped  
**Priority**: medium  
**Complexity**: low  
**Since**: v0.7.0

**Description**: Clear README in workflows/ explaining which documents to use when.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/workflows/README.md`
- Tests: manual review

**Acceptance**: See `spec/acceptance/F-0070.md`

---

## F-0071: Token Economics

**Status**: shipped  
**Priority**: critical  
**Complexity**: high  
**Since**: v0.1.0

**Description**: Durable artifacts prevent repeated context waste - CONTEXT_PACK, JOURNAL, structured reading protocols.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: Templates, reading_protocols.md, token-efficient scripts
- Tests: manual validation

**Acceptance**: See `spec/acceptance/F-0071.md`

---

## F-0072: Living Documentation

**Status**: shipped  
**Priority**: high  
**Complexity**: medium  
**Since**: v0.1.0

**Description**: Documentation stays current - specs updated with code, no stale placeholders, automatic sync.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: agent_operating_guidelines.md, checklists
- Tests: manual validation

**Acceptance**: See `spec/acceptance/F-0072.md`

---

## F-0073: Human-Agent Collaboration

**Status**: shipped  
**Priority**: critical  
**Complexity**: medium  
**Since**: v0.1.0

**Description**: Both humans and agents work on project truth - readable specs, clear escalation, dual editing.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: All spec templates, HUMAN_NEEDED.md, MANUAL_OPERATIONS.md
- Tests: workflow validation

**Acceptance**: See `spec/acceptance/F-0073.md`

---

## F-0074: Green Coding Principles

**Status**: shipped  
**Priority**: medium  
**Complexity**: medium  
**Since**: v0.3.5

**Description**: Efficient software reduces environmental impact - algorithm optimization, resource minimization, caching.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/quality/green_coding.md`, programming_standards.md
- Tests: agent compliance

**Acceptance**: See `spec/acceptance/F-0074.md`

---

## F-0075: Traceability

**Status**: shipped  
**Priority**: high  
**Complexity**: medium  
**Since**: v0.1.0

**Description**: Clear path from requirements to code to tests - stable IDs, @feature annotations, dependency visualization.

**Dependencies**: F-0003

**Implementation**:
- State: complete
- Code: Feature IDs, code annotations, feature_graph tools
- Tests: validation scripts

**Acceptance**: See `spec/acceptance/F-0075.md`

---

## F-0076: Iterative & Incremental Development

**Status**: shipped  
**Priority**: high  
**Complexity**: low  
**Since**: v0.1.0

**Description**: Ship in small, validated steps - learn and adapt through building.

**Dependencies**: F-0006, F-0007

**Implementation**:
- State: complete
- Code: Workflows, STATUS.md, feature tracking
- Tests: workflow validation

**Acceptance**: See `spec/acceptance/F-0076.md`

---

## Summary

| Category | Shipped | In Progress | Planned | Total |
|----------|---------|-------------|---------|-------|
| Core (F-0001-0010) | 10 | 0 | 0 | 10 |
| Quality (F-0011-0020) | 7 | 0 | 0 | 7 |
| Session (F-0021-0030) | 8 | 0 | 0 | 8 |
| Multi-Agent (F-0031-0040) | 4 | 0 | 0 | 4 |
| Tooling (F-0041-0050) | 4 | 0 | 0 | 4 |
| Recovery (F-0051-0060) | 6 | 0 | 0 | 6 |
| Developer Experience (F-0061-0070) | 10 | 0 | 0 | 10 |
| Design Principles (F-0071-0080) | 6 | 0 | 0 | 6 |
| **Total** | **55** | **0** | **0** | **55** |

