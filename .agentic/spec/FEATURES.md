# Agentic AI Framework - Feature Specification

<!-- format: features-v0.2.0 -->

**Purpose**: Define what the Agentic AI Framework can reliably do at each version.

**Version**: 0.50.0

---

## Feature Categories

Features use sequential IDs (`F-XXXX`). Category is metadata, not encoded in the ID range.

| Category | Count | Shipped | In Progress | Planned |
|----------|-------|---------|-------------|---------|
| **Core** | 14 | 14 | 0 | 0 |
| **Quality** | 24 | 20 | 4 | 0 |
| **Session** | 13 | 13 | 0 | 0 |
| **Multi-Agent** | 11 | 9 | 1 | 1 |
| **Tooling** | 11 | 11 | 0 | 0 |
| **Recovery** | 7 | 7 | 0 | 0 |
| **Developer Experience** | 15 | 13 | 1 | 1 |
| **Design Principles** | 10 | 10 | 0 | 0 |
| **Agent System** | 12 | 10 | 2 | 0 |
| **Verification & Enforcement** | 18 | 17 | 1 | 0 |
| **Autonomous** | 11 | 6 | 0 | 5 |
| **Architecture** | 6 | 4 | 0 | 2 |
| **Workflow** | 4 | 2 | 0 | 2 |

---

## F-0001: Project Initialization

**Status**: shipped  
**Category**: Core  
**Priority**: critical  
**Complexity**: medium  
**Since**: v0.1.0

**Description**: Initialize a new project with the Agentic framework, choosing between Discovery and Formal profiles.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `install.sh`, `.agentic/init/scaffold.sh`, `.agentic/init/init_playbook.md`
- Tests: manual (validation in acceptance criteria)

**Acceptance**: See `spec/acceptance/F-0001.md`

---

## F-0002: Profile Selection (Discovery vs Formal)

**Status**: shipped  
**Category**: Core  
**Priority**: critical  
**Complexity**: low  
**Since**: v0.2.0

**Description**: Two framework profiles - Discovery (quality + workflows) and Formal (adds spec-driven development, feature tracking).

**Dependencies**: F-0001

**Implementation**:
- State: complete
- Code: `.agentic/init/init_playbook.md`, `STACK.md` profile field
- Tests: manual

**Acceptance**: See `spec/acceptance/F-0002.md`

---

## F-0003: Spec-Driven Development

**Status**: shipped  
**Category**: Core  
**Priority**: high  
**Complexity**: high  
**Since**: v0.1.0

**Description**: Manage features through markdown specifications with status tracking, dependencies, and acceptance criteria.

**Dependencies**: F-0002 (Formal profile)

**Implementation**:
- State: complete
- Code: `spec/FEATURES.md`, `spec/acceptance/`, `.agentic/spec/` templates
- Tests: `tests/test_validate_specs.py`

**Acceptance**: See `spec/acceptance/F-0003.md`

---

## F-0004: Feature Tracking & Status

**Status**: shipped  
**Category**: Core  
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
**Category**: Core  
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
**Category**: Core  
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
**Category**: Core  
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
**Category**: Core  
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

## F-0009: OVERVIEW.md (Core Profile)

**Status**: shipped  
**Category**: Core  
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
**Category**: Core  
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
**Category**: Quality  
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
**Category**: Quality  
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
**Category**: Quality  
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
**Category**: Quality  
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
**Category**: Quality  
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
**Category**: Quality  
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
**Category**: Quality  
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
**Category**: Session  
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
**Category**: Session  
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
**Category**: Session  
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
**Category**: Session  
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
**Category**: Session  
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
**Category**: Session  
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
**Category**: Session  
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

**Status**: deprecated
**Category**: Session  
**Priority**: low
**Complexity**: medium
**Since**: v0.3.5
**Deprecated**: v0.12.0

**Description**: ~~Generate `.continue-here.md` for quick context recovery.~~

**Superseded by**: Project Phase tracking in STATUS.md (see F-0071)

**Dependencies**: F-0023, F-0024

**Implementation**:
- State: deprecated (backwards compatible)
- Code: `.agentic/tools/continue_here.py` (deprecated)
- Tests: script validation

**Acceptance**: See `spec/acceptance/F-0028.md`

---

## F-0031: Multi-Agent Coordination

**Status**: shipped  
**Category**: Multi-Agent  
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
**Category**: Multi-Agent  
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

**Status**: deprecated
**Category**: Multi-Agent
**Priority**: high
**Complexity**: low
**Since**: v0.2.0

**Description**: Shared file tracking which agents are working on what features. **Superseded by AGENTS.json (F-0194).**

**Dependencies**: F-0031

**Implementation**:
- State: complete
- Code: `.agentic/spec/AGENTS_ACTIVE.template.md` (deleted — superseded by AGENTS.json)
- Tests: format validation

**Acceptance**: See `spec/acceptance/F-0033.md`

---

## F-0034: Sequential Agent Pipeline

**Status**: shipped  
**Category**: Multi-Agent  
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

## F-0035: Agent Role Definitions

**Status**: shipped  
**Category**: Multi-Agent  
**Priority**: high  
**Complexity**: medium  
**Since**: v0.9.5

**Description**: 9 specialized agent roles (Orchestrator, Research, Planning, Test, Implementation, Review, Spec Update, Documentation, Git) with clear responsibilities, context requirements, and handoff protocols.

**Dependencies**: F-0034

**Implementation**:
- State: complete
- Code: `.agentic/agents/roles/*.md` (9 role files including orchestrator-agent.md)
- Tests: role file existence validation

**Acceptance**: See `spec/acceptance/F-0035.md`

---

## F-0036: Native Sub-Agent Integration

**Status**: shipped  
**Category**: Multi-Agent  
**Priority**: high  
**Complexity**: medium  
**Since**: v0.9.5

**Description**: Integration guides for Claude Code and Cursor native sub-agent capabilities.

**Dependencies**: F-0035

**Implementation**:
- State: complete
- Code: `.agentic/agents/claude/sub-agents.md`, `.agentic/agents/cursor/agents-setup.md`
- Tests: documentation validation

**Acceptance**: See `spec/acceptance/F-0036.md`

---

## F-0037: Project Health Monitoring

**Status**: shipped  
**Category**: Multi-Agent  
**Priority**: medium  
**Complexity**: medium  
**Since**: v0.9.5

**Description**: Manager oversight script for monitoring pipeline status, stalled agents, feature completion, documentation currency.

**Dependencies**: F-0035, F-0031

**Implementation**:
- State: complete
- Code: `.agentic/tools/project-health.sh`
- Tests: script execution validation

**Acceptance**: See `spec/acceptance/F-0037.md`

---

## F-0041: Token-Efficient Update Scripts

**Status**: shipped  
**Category**: Tooling  
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
**Category**: Tooling  
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
**Category**: Tooling  
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
**Category**: Tooling  
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
**Category**: Recovery  
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
**Category**: Recovery  
**Priority**: critical
**Complexity**: low
**Since**: v0.5.0

**Description**: Lock file at `.agentic/WIP.md` created when work starts, contains feature, files, progress, recovery instructions.

**Dependencies**: F-0051

**Implementation**:
- State: complete
- Code: `.agentic/tools/wip.sh`
- Tests: format validation

**Acceptance**: See `spec/acceptance/F-0052.md`

---

## F-0053: Recovery Protocol

**Status**: shipped  
**Category**: Recovery  
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
**Category**: Recovery  
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
**Category**: Recovery  
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
**Category**: Recovery  
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
**Category**: Developer Experience  
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
**Category**: Developer Experience  
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
**Category**: Developer Experience  
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
**Category**: Developer Experience  
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
**Category**: Developer Experience  
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
**Category**: Developer Experience  
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
**Category**: Developer Experience  
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
**Category**: Developer Experience  
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
**Category**: Developer Experience  
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
**Category**: Developer Experience  
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
**Category**: Design Principles  
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
**Category**: Design Principles  
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
**Category**: Design Principles  
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
**Category**: Design Principles  
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
**Category**: Design Principles  
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
**Category**: Design Principles  
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

## F-0077: Emergency Quick Reference

**Status**: shipped  
**Category**: Design Principles  
**Priority**: high  
**Complexity**: low  
**Since**: v0.8.1

**Description**: EMERGENCY.md provides instant guidance when tokens run out or developer needs to work without agent.

**Dependencies**: none

**Implementation**:
- State: complete
- Code: .agentic/EMERGENCY.md
- Tests: file existence, content validation

**Acceptance**: See `spec/acceptance/F-0077.md`

---

## F-0078: Quick Feature & Issue Scripts

**Status**: shipped  
**Category**: Design Principles  
**Priority**: medium  
**Complexity**: low  
**Since**: v0.8.1

**Description**: One-liner scripts to add features and issues without agent assistance.

**Dependencies**: F-0003

**Implementation**:
- State: complete
- Code: quick_feature.sh, quick_issue.sh
- Tests: script execution, file creation

**Acceptance**: See `spec/acceptance/F-0078.md`

---

## F-0079: Issue/Bug Tracking

**Status**: shipped  
**Category**: Design Principles  
**Priority**: medium  
**Complexity**: medium  
**Since**: v0.9.0

**Description**: Formal issue tracking (I-####) parallel to feature tracking (F-####).

**Dependencies**: F-0003

**Implementation**:
- State: complete
- Code: spec/ISSUES.template.md, quick_issue.sh
- Tests: template validation, script execution

**Acceptance**: See `spec/acceptance/F-0079.md`

---

## F-0080: Upgrade Marker System

**Status**: shipped  
**Category**: Design Principles  
**Priority**: medium  
**Complexity**: medium  
**Since**: v0.8.1

**Description**: Efficient upgrade detection via .upgrade_pending marker file instead of version comparison every session.

**Dependencies**: F-0001

**Implementation**:
- State: complete
- Code: upgrade.sh creates marker, session_start.md checks it
- Tests: upgrade flow validation

**Acceptance**: See `spec/acceptance/F-0080.md`

---

## F-0081: Orchestrator Agent

**Status**: shipped  
**Category**: Agent System  
**Priority**: high  
**Complexity**: medium  
**Since**: v0.9.7

**Description**: Manager/puppeteer agent that coordinates specialized agents, ensures framework compliance, and manages feature pipeline. Delegates work but never implements itself.

**Dependencies**: F-0035, F-0036

**Implementation**:
- State: complete
- Code: `.agentic/agents/roles/orchestrator-agent.md`, `.cursor/agents/orchestrator-agent.md`
- Tests: role structure validation

**Acceptance**: See `spec/acceptance/F-0081.md`

---

## F-0082: Tier-Based Model Selection

**Status**: shipped  
**Category**: Agent System  
**Priority**: medium  
**Complexity**: low  
**Since**: v0.9.7

**Description**: Model recommendations use tiers (Cheap/Fast, Mid-tier, Powerful) instead of specific model names. Future-proof as model names change frequently.

**Dependencies**: F-0071

**Implementation**:
- State: complete
- Code: All subagent definitions, agent_operating_guidelines.md, CLAUDE.md
- Tests: documentation review

**Acceptance**: See `spec/acceptance/F-0082.md`

---

## F-0083: Agent Token Savings Documentation

**Status**: shipped  
**Category**: Agent System  
**Priority**: medium  
**Complexity**: low  
**Since**: v0.9.7

**Description**: Quantified documentation of token savings from agent delegation (60-83% typical), based on Claude best practices.

**Dependencies**: F-0071, F-0081

**Implementation**:
- State: complete
- Code: `.agentic/token_efficiency/agent_delegation_savings.md`, `.agentic/token_efficiency/claude_best_practices.md`
- Tests: documentation existence

**Acceptance**: See `spec/acceptance/F-0083.md`

---

## F-0084: Untracked Files Protection

**Status**: shipped  
**Category**: Agent System  
**Priority**: high  
**Complexity**: low  
**Since**: v0.9.7

**Description**: Prevent deployment failures from files created but not git-tracked. Pre-commit warning, session/commit checklists, and tool for verification.

**Dependencies**: F-0013

**Implementation**:
- State: complete
- Code: `.agentic/tools/check-untracked.sh`, `.agentic/hooks/pre-commit-check.sh` (check 6/6)
- Tests: script execution, hook validation

**Acceptance**: See `spec/acceptance/F-0084.md`

---

## F-0091: Gate-Based Verification

**Status**: shipped
**Category**: Verification & Enforcement  
**Priority**: critical
**Complexity**: high
**Since**: v0.11.0

**Description**: Shift from instruction-based to gate-based architecture. Instead of agents memorizing 1000+ lines of guidelines, gates enforce quality automatically. `doctor.sh` becomes THE single verification command with multiple modes.

**Dependencies**: F-0016, F-0043

**Implementation**:
- State: complete
- Code: `.agentic/tools/doctor.sh` (--full, --phase, --pre-commit modes), `.agentic/tools/doctor.py`
- Tests: `tests/validate_framework.sh`

**Acceptance**: See `spec/acceptance/F-0091.md`

---

## F-0092: Phase Detection

**Status**: shipped
**Category**: Verification & Enforcement  
**Priority**: high
**Complexity**: medium
**Since**: v0.11.0

**Description**: Automatic detection of current development phase (start, planning, implement, complete, blocked) to run appropriate verification gates.

**Dependencies**: F-0091

**Implementation**:
- State: complete
- Code: `.agentic/tools/phase_detect.py`
- Tests: `tests/test_phase_detect.py`

**Acceptance**: See `spec/acceptance/F-0092.md`

---

## F-0093: AGENT_QUICK_START.md

**Status**: shipped
**Category**: Verification & Enforcement  
**Priority**: high
**Complexity**: low
**Since**: v0.11.0

**Description**: Concise (~70 lines) quick reference replacing 1000+ lines of agent guidelines for daily use. Full guidelines become reference material for troubleshooting.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/agents/shared/AGENT_QUICK_START.md`
- Tests: file existence, content validation

**Acceptance**: See `spec/acceptance/F-0093.md`

---

## F-0094: Version-Aware Upgrade Features

**Status**: shipped
**Category**: Verification & Enforcement  
**Priority**: medium
**Complexity**: medium
**Since**: v0.11.3

**Description**: Upgrade script tracks which version each feature was introduced. Only shows features that are actually NEW relative to user's previous version, preventing repeated "new features" prompts.

**Dependencies**: F-0056, F-0080

**Implementation**:
- State: complete
- Code: `.agentic/tools/upgrade.sh` (FEATURE_REGISTRY array)
- Tests: version comparison validation

**Acceptance**: See `spec/acceptance/F-0094.md`

---

## F-0095: Cross-Platform Tool Compatibility

**Status**: shipped
**Category**: Verification & Enforcement  
**Priority**: high
**Complexity**: medium
**Since**: v0.11.1

**Description**: All shell scripts work on both macOS (BSD) and Linux (GNU). Uses awk instead of sed for complex text processing to avoid platform-specific syntax issues.

**Dependencies**: F-0041

**Implementation**:
- State: complete
- Code: `.agentic/tools/status.sh` (awk-based), all tools tested on macOS
- Tests: manual cross-platform testing

**Acceptance**: See `spec/acceptance/F-0095.md`

---

## F-0096: PR-Based Workflow Default

**Status**: shipped
**Category**: Verification & Enforcement  
**Priority**: high
**Complexity**: low
**Since**: v0.11.3

**Description**: PR-based git workflow is the default for Formal profile. Agents create feature branches and PRs instead of committing directly to main. Profile-aware defaults: Formal → `pull_request`, Discovery → `direct`. Users can override in STACK.md.

**Dependencies**: F-0002 (Profile Selection)

**Implementation**:
- State: complete
- Code: `.agentic/workflows/git_workflow.md`, `.agentic/init/STACK.template.md`, agent guidelines
- Tests: validation script checks

**Acceptance**: See `spec/acceptance/F-0096.md`

---

## F-0097: Worktree Management Tool

**Status**: shipped
**Category**: Verification & Enforcement  
**Priority**: high
**Complexity**: medium
**Since**: v0.11.3

**Description**: Tool to manage git worktrees for parallel agent development. Creates worktrees with proper branch naming, registers agents in AGENTS_ACTIVE.md, and provides cleanup commands. Enables multiple Claude/Cursor windows to work on different features simultaneously without conflicts.

**Dependencies**: F-0031 (Multi-Agent Coordination)

**Implementation**:
- State: complete
- Code: `.agentic/tools/worktree.sh`
- Tests: validation script checks

**Acceptance**: See `spec/acceptance/F-0097.md`

---

## F-0098: Generate Claude Skills from Subagents

**Status**: deprecated
**Category**: Verification & Enforcement
**Priority**: medium
**Complexity**: medium
**Since**: v0.11.5

**Description**: Generate Claude Code Skills (`.claude/skills/`) from subagent definitions, enabling auto-discovery while maintaining single source of truth. Skills are regenerated during install/upgrade. **Superseded by F-0143 hand-crafted skills approach.**

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/tools/generate-skills.sh`
- Tests: manual validation

**Acceptance**: See `spec/acceptance/F-0098.md`

---

## F-0101: Framework Architecture Decision Records (ADRs)

**Status**: shipped
**Category**: Developer Experience  
**Priority**: high
**Complexity**: low
**Since**: v0.11.3

**Description**: Document WHY framework decisions were made, not just what. Prevents future contributors from undoing intentional decisions (e.g., CLAUDE.md "duplication" is intentional for bootstrap reliability).

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `docs/adr/`, `docs/adr/001-claude-md-self-contained.md`
- Tests: directory and ADR existence

**Acceptance**: See `spec/acceptance/F-0101.md`

---

## F-0102: Modular Guidelines for Token Efficiency

**Status**: shipped
**Category**: Agent System  
**Priority**: high
**Complexity**: medium
**Since**: v0.11.3

**Description**: Split large agent_operating_guidelines.md into lazy-loaded modules. Agents load only guidelines relevant to their current task, reducing token usage by ~84%.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/agents/shared/guidelines/` (anti-hallucination.md, token-efficiency.md, small-batch.md, wip-tracking.md, multi-agent.md)
- Tests: module existence validation

**Acceptance**: See `spec/acceptance/F-0102.md`

---

## F-0103: Agent Mode Selection (Quality vs Cost)

**Status**: in_progress
**Category**: Agent System
**Since**: v0.12.2

**Description**: Allow users to choose an agent quality/cost tradeoff mode that affects model selection across all agent tasks. Critical tasks like planning and speccing use best models in all modes.

**Modes**:
| Mode | Description | Planning/Specs | Implementation | Search |
|------|-------------|----------------|----------------|--------|
| `premium` | Best quality, higher cost | opus | sonnet | haiku |
| `balanced` | Good balance (default) | opus | sonnet | haiku |
| `economy` | Cost saving, prototyping | sonnet | haiku | haiku |

**Philosophy**: Planning and speccing set direction - bad specs lead to wasted implementation tokens. Worth spending on quality there.

**Configuration**: `STACK.md`:
```yaml
agent_mode: balanced  # premium | balanced | economy
```

**Dependencies**: None

**Implementation**:
- State: in_progress
- Code: STACK.template.md, CLAUDE.md, agent_operating_guidelines.md
- Tests: validation of agent_mode values

**Acceptance**: See `spec/acceptance/F-0103.md`

---

## F-0108: Multi-Agent Helper Scripts

**Status**: planned
**Category**: Multi-Agent  
**Priority**: medium
**Profile**: Both

**Description**: Utility scripts for multi-agent coordination that are documented but not yet implemented:
- `agents_active.sh` - Parse and display AGENTS_ACTIVE.md status
- `check_agent_conflicts.sh` - Check if files overlap between agents
- `sync_worktrees.sh` - Pull main into all worktrees
- `git_mode.sh` - Show git workflow mode from STACK.md
- `upgrade_profile.sh` - Upgrade Discovery → Formal profile

**Dependencies**: F-0031 (Multi-Agent Coordination)

**Implementation**:
- State: none
- Code: `.agentic/tools/` (to be created)
- Tests: unit tests for each script

**Acceptance**: See `spec/acceptance/F-0108.md`

---

## F-0109: Spec-Code Traceability Enhancements

**Status**: shipped
**Category**: Tooling  
**Priority**: medium
**Complexity**: medium
**Since**: v0.15.0

**Description**: Enhance existing drift and coverage tools to answer key traceability questions: "What specs are not implemented?", "What code has no spec?", "What's changed since last sync?", "Which tests validate which features?". Adds unified `ag trace` CLI.

**Dependencies**: F-0041 (Token-Efficient Update Scripts)

**Implementation**:
- State: complete
- Code: `.agentic/tools/drift.sh` (--json), `.agentic/tools/coverage.py` (--json, --reverse, --test-mapping), `.agentic/tools/ag.sh` (trace command)
- Tests: manual validation

**Acceptance**: See `spec/acceptance/F-0109.md`

---

## F-0110: Feature Hierarchy Query

**Status**: shipped
**Category**: Tooling  
**Priority**: low
**Complexity**: small
**Since**: v0.15.0

**Description**: Add `--children` flag to `query_features.py` to list children/descendants of a feature. Supports direct children query, recursive descendants with tree format, status filtering, and summary output.

**Dependencies**: F-0109 (Spec-Code Traceability)

**Implementation**:
- State: complete
- Code: `.agentic/tools/query_features.py` (--children, --recursive flags)
- Tests: `tests/test_query_features.py` (8 tests)

**Acceptance**: See `spec/acceptance/F-0110.md`

---

## F-0111: Three-Tier Agent Boundaries

**Status**: shipped
**Category**: Agent System  
**Priority**: medium
**Complexity**: small
**Since**: v0.15.0

**Description**: Restructure agent boundaries with ✅/⚠️/🚫 visual hierarchy. Single authoritative location in agent_operating_guidelines.md. CLAUDE.md references (not duplicates) the section.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/agents/shared/agent_operating_guidelines.md`, `.agentic/agents/claude/CLAUDE.md`
- Tests: Manual validation

**Acceptance**: See `spec/acceptance/F-0111.md`

---

## F-0112: Code Style Examples in CONTEXT_PACK

**Status**: shipped
**Category**: Developer Experience  
**Priority**: low
**Complexity**: small
**Since**: v0.15.0

**Description**: Add Code Style Examples section to CONTEXT_PACK template. Agents mimic patterns from examples. Includes maintenance guidance and alternative to reference real files.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/init/CONTEXT_PACK.template.md`
- Tests: Manual validation

**Acceptance**: See `spec/acceptance/F-0112.md`

---

## F-0113: Delegation Heuristics Guide

**Status**: shipped
**Category**: Multi-Agent  
**Priority**: low
**Complexity**: small
**Since**: v0.15.0

**Description**: Practical guide for when to delegate to AI agents vs. do tasks yourself. Includes decision flowchart, task-type examples, and anti-patterns.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/workflows/delegation_heuristics.md`
- Tests: Manual validation

**Acceptance**: See `spec/acceptance/F-0113.md`

---

## F-0114: Scope & Diff Verification

**Status**: shipped
**Category**: Verification & Enforcement  
**Priority**: medium
**Complexity**: small
**Since**: v0.15.0

**Description**: Structural verification tools that help humans review agent changes efficiently. Shows diff stats at pre-commit, warns on scope drift (files changed outside declared scope), and adds principles documenting meta-insights about agent behavior (structural > behavioral instructions).

**Dependencies**: F-0016 (Pre-Commit Quality Gates), F-0051 (WIP Tracking)

**Implementation**:
- State: complete
- Code: `.agentic/tools/scope_check.sh`, `.agentic/hooks/pre-commit-check.sh`, `.agentic/PRINCIPLES.md`
- Tests: validate_framework.sh

**Acceptance**: See `spec/acceptance/F-0114.md`

---

## F-0115: Git Workflow Branch Check

**Status**: shipped
**Category**: Verification & Enforcement  
**Priority**: medium
**Complexity**: small
**Since**: v0.15.1

**Description**: Enforce git workflow policy from STACK.md. When `git_workflow: pull_request`, block commits to main/master with clear guidance (create feature branch, use --no-verify for hotfixes, or switch to direct workflow). Profile-aware defaults: Discovery → direct, Formal → pull_request.

**Dependencies**: F-0002 (Profile Selection), F-0016 (Pre-Commit Quality Gates), F-0096 (PR-Based Workflow Default)

**Implementation**:
- State: complete
- Code: `.agentic/hooks/pre-commit-check.sh`, `.agentic/init/scaffold.sh`, `.agentic/init/init_playbook.md`, `.agentic/init/STACK.template.md`
- Tests: `tests/validate_framework.sh` (9 checks)

**Acceptance**: See `spec/acceptance/F-0115.md`

---

## F-0116: Maintainability Enforcement Gates

**Status**: shipped
**Category**: Verification & Enforcement  
**Priority**: high
**Complexity**: medium
**Since**: v0.16.0

**Description**: Enforce maintainability through automated gates: test execution (BLOCKING), complexity limits (BLOCKING: max files, max added lines, max file length), and escape hatches for legitimate bypasses (blocked on main/master). Both Discovery and Formal profiles enforce tests and complexity limits.

**Dependencies**: F-0016 (Pre-Commit Quality Gates), F-0115 (Git Workflow Branch Check)

**Implementation**:
- State: complete
- Code: `.agentic/hooks/pre-commit-check.sh` (checks 6-7), `.agentic/tools/wip.sh` (--auto flag), `.agentic/tools/doctor.py` (frontmatter parsing), `.agentic/tools/upgrade.sh` (migration)
- Tests: `tests/validate_framework.sh`

**Acceptance**: See `spec/acceptance/F-0116.md`

---

## F-0117: Spec Migration System

**Status**: shipped
**Category**: Tooling  
**Priority**: medium
**Complexity**: medium
**Since**: v0.16.0

**Description**: Complete migration management for spec evolution. Migrations track HOW we arrived at current specs (not just WHAT they are). Supports create, list, show, search, and apply commands. Auto-updates `_index.json` registry and can regenerate FEATURES.md from migration history.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/tools/migration.sh`, `spec/migrations/`
- Tests: manual

**Acceptance**: See `spec/acceptance/F-0117.md`

---

## F-0118: Documentation Drift Detection

**Status**: shipped
**Category**: Quality  
**Priority**: low
**Complexity**: medium
**Since**: v0.16.0

**Description**: Manifest-based documentation staleness detection. Compares recently changed code files against documentation that references them, flagging docs that may be out of sync. Advisory only (never blocks). Supports manifest-specific checking and configurable tracking via STACK.md.

**Dependencies**: F-0109 (Spec-Code Traceability)

**Implementation**:
- State: complete
- Code: `.agentic/tools/drift.sh` (--docs flag)
- Tests: manual

**Acceptance**: See `spec/acceptance/F-0118.md`

---

## F-0119: Feature Change Manifest Generation

**Status**: shipped
**Category**: Tooling  
**Priority**: medium
**Complexity**: medium
**Since**: v0.16.0

**Description**: Generate comprehensive change manifests from git history for features, branches, or date ranges. Manifests track all commits, files changed (grouped by type), and line statistics. Supports embedding into migration files. Enables documentation patching and audit trails.

**Dependencies**: None

**Implementation**:
- State: complete
- Code: `.agentic/tools/manifest.sh`, `.agentic-journal/manifests/`
- Tests: manual

**Acceptance**: See `spec/acceptance/F-0119.md`

---

## F-0120: Plan-Review Loop

**Status**: shipped
**Category**: Agent System  
**Priority**: medium
**Complexity**: medium
**Since**: v0.18.0

**Description**: Iterative planning with critical review before implementation. Planner creates plan, reviewer critiques, planner revises - loop until approved or max iterations reached. Improves plan quality by catching issues before code is written. Configurable via STACK.md.

**Dependencies**: F-0081 (Orchestrator Agent), F-0035 (Agent Role Definitions)

**Implementation**:
- State: complete
- Code: `.agentic/workflows/plan_review_loop.md`, `.agentic/tools/ag.sh`, STACK.template.md, plan-creator-agent.md, plan-reviewer-agent.md
- Tests: manual

**Acceptance**: See `spec/acceptance/F-0120.md`

---

## F-0121: Tool-Specific Instructions Parity

**Status**: in_progress
**Category**: Agent System  
**Priority**: medium
**Complexity**: medium
**Since**: v0.18.0

**Description**: Ensure Cursor, Codex, and Copilot templates in `.agentic/agents/` have feature parity with Claude template for enforced gates. All templates have 6-gate table, escape hatches, small batch development rules, and "implement entire" trigger word.

**Dependencies**: F-0116 (Maintainability Enforcement Gates)

**Implementation**:
- State: in_progress
- Code: `.agentic/agents/cursor/cursorrules.txt`, `.agentic/agents/codex/codex-instructions.md`, `.agentic/agents/copilot/copilot-instructions.md`, `/CODEX.md`
- Tests: `tests/validate_framework.sh` (F-0121 section)

**Acceptance**: See `spec/acceptance/F-0121.md`

---

## F-0122: Multi-Tool LLM Testing Infrastructure

**Status**: shipped
**Category**: Quality  
**Priority**: high
**Complexity**: medium
**Since**: v0.18.0

**Description**: Enable running LLM behavioral tests across different AI tools (Claude CLI, Codex CLI, Cursor CLI, Cursor IDE, Copilot IDE). Adds environment detection, interactive test mode for IDE-based agents, machine-readable test definitions, and `ag test llm` command. Critical for validating framework compliance across all supported tools.

**Dependencies**: F-0121 (Tool-Specific Instructions Parity)

**Implementation**:
- State: complete
- Code: `tests/llm/test_definitions.json`, `tests/llm/interactive_runner.py`, `.agentic/tools/ag.sh` (test command), `tests/llm/harness.sh`
- Tests: `tests/validate_framework.sh` (F-0122 section), `tests/VERIFICATION_REPORT.md`

**Acceptance**: See `spec/acceptance/F-0122.md`

---

## F-0123: Intelligent Onboarding for Existing Projects

**Status**: shipped
**Category**: Core  
**Priority**: high
**Complexity**: high
**Since**: v0.24.0

**Description**: When `ag init` detects an existing codebase, offer auto-discover mode that analyzes code structure, README, tests, and generates populated FEATURES.md (shipped features), acceptance criteria, STACK.md, CONTEXT_PACK.md, and OVERVIEW.md. Two modes: interactive (guided questions) or auto-discover (analyze + propose). All generated specs are proposals requiring human approval.

**Dependencies**: F-0001 (Project Initialization), F-0003 (Spec-Driven Development)

**Implementation**:
- State: complete
- Code: `.agentic/tools/discover.sh`, `.agentic/tools/discover.py`, `.agentic/tools/render_proposals.py`
- Tests: `tests/test_discover.py` (75 tests), `tests/validate_framework.sh` (12 checks)

**Acceptance**: See `spec/acceptance/F-0123.md`

---

## F-0124: Domain Categories & Systematic Brownfield Spec Generation

**Status**: shipped
**Category**: Core  
**Priority**: high
**Complexity**: high
**Since**: v0.25.0

**Description**: Features get a `- Domain:` metadata field (frontend, backend, mobile, infrastructure, shared, uncategorized). Discovery detects infrastructure patterns (CI/CD, IaC, containers, deployment) and groups sub-projects into typed domains by framework. `ag specs` command enables systematic domain-by-domain spec generation with plan-review loop, per-domain user confirmation, and multi-session resume via checkbox plan artifacts. Size-aware routing: small projects (1 domain, ≤8 clusters) use inline generation; larger projects use `ag specs`. Greenfield projects get domain question during init.

**Dependencies**: F-0123 (Intelligent Onboarding), F-0120 (Plan-Review Loop)

**Implementation**:
- State: complete
- Code: `.agentic/tools/discover.py` (detect_infra_patterns, detect_domains), `.agentic/tools/render_proposals.py` (domain-tagged output), `.agentic/tools/ag.sh` (specs command), `.agentic/agents/shared/auto_orchestration.md` (Brownfield Spec Pipeline), `.agentic/init/init_playbook.md` (size-aware routing, greenfield domains), `.agentic/checklists/session_start.md` (brownfield plan detection)
- Tests: `tests/test_discover.py` (16 new tests), `tests/llm/tests/044-046` (3 LLM behavioral tests)

**Acceptance**: See `spec/acceptance/F-0124.md`

---

## F-0125: Unified Drift Detection (`ag sync`)

**Status**: shipped
**Category**: Tooling  
**Priority**: high
**Complexity**: medium
**Since**: v0.25.4

**Description**: Unified drift detection across 5 phases: memory seed integrity, state freshness (JOURNAL.md/STATUS.md staleness), feature reconciliation (FEATURES.md vs code), spec/doc drift, and tool file parity. Three modes: full sync (detect + auto-fix safe errors), dry run (`--check`), and quiet probe (`--quiet`) for `ag start` integration. User-initiated to control token cost.

**Dependencies**: F-0024 (Session Context), F-0098 (Structural Enforcement)

**Implementation**:
- State: complete
- Code: `.agentic/tools/sync.sh`, `.agentic/tools/ag.sh` (sync command)
- Tests: Manual validation (3 modes work), `tests/validate_framework.sh` (184/184 pass)

**Acceptance**: See `spec/acceptance/F-0125.md`

---

## F-0126: Discoverability Reminders

**Status**: shipped
**Category**: Session  
**Priority**: medium
**Complexity**: low
**Since**: v0.25.4

**Description**: Agents forget about `ag plan` and `ag sync` even though they're in trigger tables — instructions get compressed away in long sessions. Fix: put reminders where agents actually look — the `ag start` dashboard output. Dim "Remind user" line shows `ag plan` and `ag sync`. Yellow sync probe appears only when issues exist. Greeting template in `session_start.md` includes "Available workflows" line. Both CLAUDE.md files include `ag sync` in Quick Commands.

**Dependencies**: F-0125 (ag sync), F-0024 (Session Context)

**Implementation**:
- State: complete
- Code: `.agentic/tools/ag.sh` (cmd_start reminder line), `.agentic/checklists/session_start.md` (greeting template), `CLAUDE.md` + `.agentic/agents/claude/CLAUDE.md` (Quick Commands)

**Acceptance**: See `spec/acceptance/F-0126.md`

---

## F-0127: Tip of the Day

**Status**: shipped
**Category**: Session  
**Priority**: low
**Complexity**: low
**Since**: v0.25.4

**Description**: Random tip displayed each session in `ag start` output to passively surface framework capabilities. 10 tips covering the full `ag` command set. Zero token cost (static strings, `$RANDOM` selection). Dim formatting to avoid dominating the dashboard.

**Dependencies**: F-0024 (Session Context)

**Implementation**:
- State: complete
- Code: `.agentic/tools/ag.sh` (tips array in cmd_start), `.agentic/checklists/session_start.md` (tip placeholder in greeting template)

**Acceptance**: See `spec/acceptance/F-0127.md`

---

## F-0128: Specs-Before-Code Structural Enforcement

**Status**: shipped
**Category**: Verification & Enforcement  
**Priority**: critical
**Complexity**: medium
**Since**: v0.25.5

**Description**: Agents skip the specs-first workflow even when CLAUDE.md trigger tables say to plan first. Root cause analysis of why instructions fail to enforce the Formal contract (acceptance criteria before coding), and structural fixes across all enforcement points (ag commands, memory-seed, trigger tables, gate scripts) to make skipping specs structurally difficult rather than relying on behavioral compliance.

**Dependencies**: F-0098 (Structural Enforcement), F-0003 (Spec-Driven Development)

**Implementation**:
- State: complete
- Code: `.agentic/tools/ag.sh` (cmd_work block, cmd_implement plan-review gate, doctor check blocking), `.agentic/hooks/pre-commit-check.sh` (workflow bypass check), `.agentic/init/memory-seed.md`, `.agentic/agents/shared/auto_orchestration.md`
- Tests: `tests/llm/tests/050_specs_before_code_no_fid.sh` (LLM-050), `tests/validate_framework.sh` (184/184)

**Acceptance**: See `spec/acceptance/F-0128.md`

---

## F-0130: Rough Specs & Structural Nudging

**Status**: shipped
**Category**: Verification & Enforcement  
**Priority**: high
**Complexity**: low
**Since**: v0.25.8

**Description**: Discovery profile gets zero spec nudging — agents skip criteria entirely. This adds structural reminders (D2: scripts > docs) for thinking about success criteria before coding. Discovery gets non-blocking nudges; Formal gets spec evolution surfacing. Also removes dead-code `## Project Phase` section from STATUS.template.md (Profile handles spec rigor).

**Dependencies**: F-0128 (Specs-Before-Code), F-0006 (Acceptance-Driven Development)

**Implementation**:
- State: complete
- Code: `.agentic/tools/ag.sh` (cmd_work nudge, cmd_done spec review), `.agentic/tools/wip.sh` (Success Criteria section), `.agentic/hooks/pre-commit-check.sh` (Core checklist), `.agentic/tools/sync.sh` (acceptance file check), `.agentic/workflows/spec_evolution.md` (Starting Rough section), `.agentic/PRINCIPLES.md` (D4 guidance)
- Removed: `## Project Phase` from STATUS.template.md, Phase refs from Stop.sh, upgrade.sh, session-start.sh, ag.sh
- Tests: `tests/validate_framework.sh`

**Acceptance**: See `spec/acceptance/F-0130.md`

---

## F-0131: Settings-Over-Profiles Architecture

**Status**: shipped
**Category**: Core  
**Priority**: high
**Added**: 2026-02-17

Replace all-or-nothing profile branching with granular individual settings. Profiles become presets that set bundles of defaults; all framework logic checks individual settings via `get_setting()`. Users can override any setting independently with `ag set`.

**Key components**:
- Shared settings libraries: `.agentic/lib/settings.sh` (bash), `.agentic/lib/settings.py` (python)
- Profile presets: `.agentic/presets/profiles.conf` (profile.setting=value format)
- Constraint rules: `.agentic/presets/constraints.conf` (if A=X -> B=Y|Z)
- `ag set` command: `--show`, `--validate`, `--migrate` subcommands
- Three-level resolution: Explicit (STACK.md ## Settings) > Profile Preset > Fallback Default
- Settings inventory: feature_tracking, acceptance_criteria, wip_before_commit, pre_commit_checks, git_workflow, plan_review_enabled, spec_directory, max_files_per_commit, max_added_lines, max_code_file_length
- 18 files converted from profile checks to get_setting() calls
- Enum value validation in `ag set`
- Backward compatibility for STACK.md without ## Settings section
- Tests: 20 framework validation tests, 12 LLM behavioral tests (051-061)

**Acceptance**: See `spec/acceptance/F-0131.md`

---

## F-0132: Programmatic Spec-First Gate

**Status**: shipped
**Category**: Verification & Enforcement  
**Priority**: high
**Added**: 2026-02-17
**Since**: v0.27.0

**Description**: Add programmatic gates to `ag plan` and `ag implement` that verify a feature ID (F-XXXX) exists in FEATURES.md and acceptance criteria exist in `spec/acceptance/F-XXXX.md` before proceeding. Prevents the bypass documented in I-0002 where plan mode skips the spec-first workflow.

**Dependencies**: F-0091 (Gate-Based Verification), F-0131 (Settings)

**Acceptance**: See `spec/acceptance/F-0132.md`

---

## F-0133: Durable Plan Artifacts

**Status**: shipped
**Category**: Session  
**Priority**: medium
**Added**: 2026-02-16
**Since**: v0.27.0

**Description**: When plans are created (via `ag plan` or native tool plan mode), save them to `.agentic-journal/plans/` as durable, git-trackable artifacts. Fixes I-0003 where plans in `.claude/plans/` are tool-specific and session-scoped.

**Dependencies**: F-0132 (Spec-First Gate)

**Acceptance**: See `spec/acceptance/F-0133.md`

---

## F-0134: DEVELOPER_GUIDE Rewrite — User-First Framing

**Status**: shipped
**Category**: Developer Experience  
**Priority**: high
**Added**: 2026-02-18
**Since**: v0.27.1

**Description**: Thorough rewrite of `.agentic/DEVELOPER_GUIDE.md` to fix wrong audience framing. Currently tells users to "run `ag implement F-XXXX`" when they don't know feature numbers. Scripts should work behind the scenes (agent runs them naturally); user-facing guidance should describe workflows in human terms. Remove stale content, align with v0.27.0 settings-over-profiles architecture.

**Acceptance**: See `spec/acceptance/F-0134.md`

---

## F-0135: Memory-Seed Defense-in-Depth Layer

**Status**: shipped
**Category**: Agent System  
**Priority**: high
**Added**: 2026-02-18
**Since**: v0.25.3

**Description**: Persistent memory seeding mechanism that reinforces framework behavioral patterns (trigger words, pre-commit sequence, token-efficient scripts) into AI agent memory. Defense-in-depth: scripts enforce structurally, memory reinforces behaviorally. `memory-check.sh` validates seed integrity at session start (stale version, missing patterns, partial overwrites). Memory-seed is NOT a fourth architectural layer — it reinforces the Constitution layer (CLAUDE.md trigger tables) so agents recognize patterns before hitting structural gates.

**Dependencies**: F-0128 (Specs-Before-Code Enforcement)

**Acceptance**: See `spec/acceptance/F-0135.md`

---

## F-0136: Centralized TODO Tracking

**Status**: shipped
**Category**: Tooling  
**Priority**: high
**Added**: 2026-02-18

**Description**: Durable, git-tracked inbox (TODO.md) for quick-capture of ideas, tasks, and reminders. Replaces scattered capture across STATUS.md Backlog, HUMAN_NEEDED.md, and JOURNAL.md "Next steps." `todo.sh` provides CRUD operations (add/done/drop/triage/list) following the `blocker.sh` pattern. Routing rules in all instruction files enforce: task → TODO.md, blocker → HUMAN_NEEDED.md, bug → ISSUES.md, capability → FEATURES.md.

**Dependencies**: F-0041 (Token-Efficient Update Scripts), F-0026 (HUMAN_NEEDED.md Escalation)

**Acceptance**: See `spec/acceptance/F-0136.md`

---

## F-0138: Documentation Impact Tracking

**Status**: shipped
**Category**: Quality  
**Priority**: medium
**Added**: 2026-02-19

**Description**: Systematic documentation update process wired into feature completion. Two complementary pieces: (1) `drift.sh --docs --manifest F-####` wired into `ag done` with `docs_gate` setting (off/warning/blocking) — machine-detects which existing docs reference changed code; (2) `## Documentation` section added to CONTEXT_PACK.md template — agents know what docs exist for new content placement. Documentation agent updated with concrete process: read CONTEXT_PACK.md docs list → run drift.sh → update flagged + new-content docs.

**Dependencies**: F-0041 (Token-Efficient Update Scripts), F-0098 (drift.sh)

**Acceptance**: See `spec/acceptance/F-0138.md`

---

## F-0139: Doc Lifecycle System

**Status**: shipped
**Category**: Quality  
**Priority**: medium
**Added**: 2026-02-19

**Description**: Systematic doc drafting and update lifecycle wired into `ag done` and `ag docs`. Two-layer architecture: project doc registry in `STACK.md ## Docs` (survives upgrades) and framework machinery in `.agentic/tools/docs.sh` (context assembler + trigger dispatcher). Supports 8 built-in doc types (changelog, readme, lessons, architecture, adr, runbook, tech-spec, custom) with 4 triggers (feature_done, pr, session, manual). Append/prepend-only strategy — never rewrites existing content. Developer extends by adding one line to STACK.md.

**Dependencies**: F-0138 (Documentation Impact Tracking)

**Acceptance**: See `spec/acceptance/F-0139.md`

---

## F-0140: Proactive WIP Creation in Agent Instructions

**Status**: shipped
**Category**: Recovery  
**Priority**: high
**Added**: 2026-02-20

Ensures the plan-mode-exit trigger chains to `ag implement` (which creates WIP tracking), adds `(creates WIP)` annotations to Build triggers across all instruction files, updates memory seed with WIP creation steps, and fixes doctor.py WIP path bug.

**Dependencies**: F-0051 (WIP Tracking)

**Acceptance**: See `spec/acceptance/F-0140.md`

---

## F-0141: Explicit Settings in STACK.md

**Status**: shipped
**Category**: Core  
**Priority**: high
**Added**: 2026-02-23

All profile-aware settings are listed explicitly with values in STACK.md (no commented-out lines). Each setting has inline docs showing both profile defaults. Scaffold populates all values from profiles.conf. Profile switching preserves user customizations.

**Dependencies**: F-0009 (Settings System)

**Acceptance**: See `spec/acceptance/F-0141.md`

---

## F-0143: Skills-Primary Architecture for Claude Code

**Status**: shipped
**Category**: Agent System  
**Priority**: high
**Complexity**: high
**Added**: 2026-02-28

**Description**: Spec-compliant Claude Skills as the primary workflow delivery for Claude Code. Hand-crafted SKILL.md files with proper YAML frontmatter (name, description, compatibility, metadata), instructions, examples, and troubleshooting. Generator copies from hand-crafted sources and assembles references. CLAUDE.md thinned to ~35 lines. Playbooks gain YAML frontmatter for progressive disclosure.

**Dependencies**: F-0098 (Generate Claude Skills from Subagents)

**Acceptance**: See `spec/acceptance/F-0143.md`

---

## F-0144: Systematic Frontmatter Coverage

**Status**: in-progress
**Category**: Developer Experience  
**Priority**: medium
**Complexity**: low
**Added**: 2026-03-01

**Description**: Complete YAML frontmatter coverage across all `.agentic/` files that agents might scan for discovery. Extends F-0143's initial 97-file coverage to 168/212 files. Adds frontmatter to agent roles, shared docs, root docs, token efficiency guides, cursor prompts, init files, spec docs, and support docs. Excludes templates, READMEs, and instruction files. Includes validation check in `validate_framework.sh`.

**Dependencies**: F-0143 (Skills-Primary Architecture)

**Acceptance**: See `spec/acceptance/F-0144.md`

---

## F-0145: Periodic Check System (Lifecycle Triggers)

**Status**: shipped
**Category**: Tooling  
**Priority**: medium
**Complexity**: medium
**Added**: 2026-03-01

**Description**: Frequency-gated periodic checks in sync.sh. State file (`.agentic-state/sync-state.conf`) tracks last-run per check. Supports `every_session`, `every_N_sessions`, `off` frequencies. Includes orphaned plan detection, retro check migration, agent freshness check. Session counter increments on each sync run.

**Dependencies**: None

**Acceptance**: See `spec/acceptance/F-0145.md`

---

## F-0146: Project-Specific Agent Generation (Layer A)

**Status**: shipped
**Category**: Agent System  
**Priority**: medium
**Complexity**: medium
**Added**: 2026-03-01

**Description**: Template-based (no LLM) project-specific agent generation. Detects tech stacks from STACK.md + file presence, matches specialization rules (`.agentic/agents/specialization/*.conf`), generates project-specific agents in `subagents-project/`. Ships with 5 stacks: React, FastAPI, Django, Go, Godot. Integrates with generate-skills.sh to inject project rules into Claude skills.

**Dependencies**: F-0145 (for periodic agent refresh trigger)

**Acceptance**: See `spec/acceptance/F-0146.md`

---

## F-0147: Spec-Writing Workflow with Delta Tracking & Plan-Review Gate

**Status**: shipped
**Category**: Verification & Enforcement  
**Priority**: high
**Complexity**: high
**Added**: 2026-03-01

**Description**: Canonical spec-writing workflow with five protection levels, NFR integration, delta tracking via migrations, and shipped-spec contract enforcement. Includes pre-commit gates (Checks 14-16) that deterministically block shipped spec modifications without migration, test file deletions for shipped features, and status downgrades. Adds `ag spec` command, check-spec-health.sh validator, and plan-review gate in check-gates.sh. Renames managing-specs skill to writing-specs with expanded scope.

**Dependencies**: F-0003 (Spec-Driven Development), F-0143 (Skills-Primary Architecture)

**Acceptance**: See `spec/acceptance/F-0147.md`

---

## F-0148: Spec Format Evolution (Behavior Section, Priority Tags, Verify-Independently)

**Status**: in_progress
**Category**: Quality
**Priority**: high
**Complexity**: low
**Added**: 2026-03-02

**Description**: Evolves the acceptance criteria template with a technology-agnostic Behavior section (WHAT vs HOW separation), priority tags (P1/P2) on AC groups for incremental delivery, verify-independently fields per group, and Tests restructured under a Verification heading. Backward compatible with existing specs.

**Dependencies**: F-0147 (Spec-Writing Workflow)

**Acceptance**: See `spec/acceptance/F-0148.md`

---

## F-0149: Spec Clarification Taxonomy

**Status**: in_progress
**Category**: Quality
**Priority**: high
**Complexity**: low
**Added**: 2026-03-02

**Description**: Adds a structured 6-category clarification pass to the writing-specs skill, run after drafting acceptance criteria. Categories: Functional Scope, Data & Domain Model, Edge Cases & Failure Handling, Non-Functional Requirements, Integration & Dependencies, Completion Signals. Max 5 questions with recommended answers. Skipped for trivial features (<3 ACs).

**Dependencies**: F-0147 (Spec-Writing Workflow), F-0143 (Skills-Primary Architecture)

**Acceptance**: See `spec/acceptance/F-0149.md`

---

## F-0150: Execution Order and Parallelization Markers in Plans

**Status**: in_progress
**Category**: Multi-Agent
**Priority**: medium
**Complexity**: low
**Added**: 2026-03-02

**Description**: Adds execution order section guidance to the planning-features skill for features with >5 ACs, with [P] markers indicating parallelizable ACs for multi-agent dispatch. Adds checkpoint validation to implementing-features skill requiring user confirmation after P1 completion before proceeding to P2.

**Dependencies**: F-0143 (Skills-Primary Architecture)

**Acceptance**: See `spec/acceptance/F-0150.md`

---

## F-0151: User-Extension Directory (.agentic-local/extensions/)

**Status**: in_progress
**Category**: Developer Experience
**Priority**: high
**Complexity**: medium
**Added**: 2026-03-02

**Description**: Adds upgrade-safe project customization via `.agentic-local/extensions/` directory with subdirectories for custom skills, quality gates, lifecycle hooks, and rule injection. Integrated into scaffold.sh (creation), generate-skills.sh (skill scanning + rule injection), pre-commit-check.sh (custom gate execution), and upgrade.sh (explicit preservation). Maintains backward compatibility with existing subagents-project/ mechanism.

**Dependencies**: F-0143 (Skills-Primary Architecture)

**Acceptance**: See `spec/acceptance/F-0151.md`

---

## F-0152: Semantic Consistency Analysis

**Status**: in_progress
**Category**: Quality
**Priority**: high
**Complexity**: medium
**Added**: 2026-03-02

**Description**: Deterministic cross-artifact consistency analysis tool (`spec-analyze.sh`) that runs 3 core checks before implementation: ambiguity detection (vague adjectives without metrics), AC↔test coverage gaps, and NFR measurability audit. Results are severity-rated (CRITICAL/HIGH/MEDIUM/LOW) and advisory (warn, don't block). No LLM calls — pure regex/pattern matching. Skippable for offline development. P2 adds LLM-powered cross-feature terminology consistency, AC contradiction detection, and constitution alignment checks.

**Dependencies**: F-0148 (Spec Format Evolution)

**Acceptance**: See `spec/acceptance/F-0152.md`

---

## F-0153: AC-Level Coverage Tracking

**Status**: in_progress
**Category**: Verification & Enforcement
**Priority**: medium
**Complexity**: medium
**Added**: 2026-03-02

**Description**: Extends coverage tracking from feature-level to individual acceptance criteria. Maps specific tests to specific ACs using naming conventions (deterministic) with optional LLM semantic mapping (advisory). Output: per-AC coverage status showing which ACs have tests and which don't. Informational gate — warns but doesn't block. Can integrate with spec-analyze.sh (F-0152) or run standalone.

**Dependencies**: F-0152 (Semantic Consistency Analysis)

**Acceptance**: See `spec/acceptance/F-0153.md`

---

## Summary

| Category | Count | Shipped | In Progress | Planned |
|----------|-------|---------|-------------|---------|
| Core | 14 | 14 | 0 | 0 |
| Quality | 15 | 12 | 2 | 1 |
| Session | 12 | 11 | 0 | 0 |
| Multi-Agent | 10 | 8 | 1 | 1 |
| Tooling | 11 | 11 | 0 | 0 |
| Recovery | 7 | 7 | 0 | 0 |
| Developer Experience | 15 | 13 | 2 | 0 |
| Design Principles | 10 | 10 | 0 | 0 |
| Agent System | 12 | 10 | 2 | 0 |
| Verification & Enforcement | 17 | 16 | 0 | 1 |
| Architecture | 3 | 3 | 0 | 0 |
| **Total** | **126** | **115** | **7** | **3** |


---

## F-0154: SKIP_COMPLEXITY Per-File Warnings

**Status**: shipped
**Category**: Quality
**Priority**: medium
**Complexity**: low
**Since**: v0.40.0

**Description**: When SKIP_COMPLEXITY is set, pre-commit still scans staged files and shows per-file details (file name, line count, limit) instead of a silent 1-line skip. Gives agents visibility into which files are over-limit so they can make informed decisions.

**Dependencies**: none

**Implementation**:
- State: complete
- Code: `.agentic/hooks/pre-commit-check.sh`
- Tests: `tests/validate_framework.sh` (T-0036 checks)

**Acceptance**: See `spec/acceptance/F-0154.md`

---

## F-0155: Unregistered Shipped Code Detection

**Status**: shipped
**Category**: Verification & Enforcement
**Priority**: medium
**Complexity**: medium
**Since**: v0.40.0

**Description**: New sync.sh phase that detects commits without F-#### references that touch 3+ source files with at least 1 new file. Flags them as possible unregistered features so agents register work in FEATURES.md. Runs in both quiet and full sync modes. Only active when feature_tracking=yes.

**Dependencies**: none

**Implementation**:
- State: complete
- Code: `.agentic/tools/sync.sh` (phase_unregistered_code)
- Tests: `tests/test_unregistered_features.sh` (8 tests), `tests/validate_framework.sh` (T-0035 checks)

**Acceptance**: See `spec/acceptance/F-0155.md`

---

## F-0156: Session Start Spec Drift Surfacing

**Status**: shipped
**Category**: Session
**Priority**: low
**Complexity**: low
**Since**: v0.40.0

**Description**: Unregistered feature detection (F-0155) runs in quiet sync mode and feeds into ag start's sync probe output. Session start checklist updated to document the new check. No separate implementation needed — falls out of F-0155 architecture.

**Dependencies**: F-0155 (Unregistered Shipped Code Detection)

**Implementation**:
- State: complete
- Code: `.agentic/checklists/session_start.md`
- Tests: `tests/validate_framework.sh` (T-0037 checks)

**Acceptance**: See `spec/acceptance/F-0156.md`

---

## F-0157: Directory Restructure & Tarball Distribution

**Status**: shipped
**Category**: Architecture
**Priority**: high
**Complexity**: high
**Since**: v0.41.0

**Description**: Restructure `.agentic/` directory layout to separate framework runtime (`lib/`) from project state. Framework dirs (tools, agents, workflows, quality, etc.) move into `.agentic/lib/`, gitignored in user projects and extracted at runtime from a committed tarball. Project tracking files (STATUS.md, TODO.md, HUMAN_NEEDED.md) move from project root to `.agentic/` root. Separate directories (`.agentic-journal/`, `.agentic-state/`, `spec/`) consolidate under `.agentic/` as `journal/`, `session/`, `spec/`. GitHub Actions release workflow builds lib tarball as release artifact. User repos no longer commit 369 framework library files (~1.1MB) — lib/ is replaced by a single tarball (~250KB) extracted at runtime.

**Dependencies**: none

**Implementation**:
- State: complete
- Code: `.agentic/bootstrap.sh`, `.agentic/ag`, `.agentic/hooks/`, `.agentic/lib/paths.sh`, `.agentic/lib/paths.py`, `install.sh`, `remote-install.sh`, `.github/workflows/release.yml`
- Tests: `tests/test_paths.sh` (42 tests), `tests/validate_framework.sh` (372 checks)

**Acceptance**: See `spec/acceptance/F-0157.md`

---

## F-0158: Central Path Resolution

**Status**: shipped
**Category**: Architecture
**Priority**: high
**Complexity**: medium
**Since**: v0.41.0

**Description**: Central path resolver (`paths.sh` for bash, `paths.py` for Python) as single source of truth for all framework file paths. `_resolve_path()` helper checks new location first, falls back to legacy location for backward compatibility. All ~70 scripts migrated from hardcoded paths. Double-source guard prevents re-initialization.

**Dependencies**: F-0157

**Implementation**:
- State: complete
- Code: `.agentic/lib/paths.sh`, `.agentic/lib/paths.py`
- Tests: `tests/test_paths.sh` (42 tests)

**Acceptance**: See `spec/acceptance/F-0158.md`

---

## F-0159: Bootstrap & Thin Wrapper Mechanism

**Status**: shipped
**Category**: Architecture
**Priority**: high
**Complexity**: medium
**Since**: v0.41.0

**Description**: Bootstrap mechanism for user projects: `bootstrap.sh` checks for `lib/`, extracts from committed tarball if missing, falls back to GitHub release download. Thin wrappers (`ag`, `hooks/pre-commit`, `hooks/claude/*.sh`) delegate to `lib/` after bootstrapping. Atomic extraction via PID-namespaced temp dirs. Pre-commit wrapper retains CI detection and STACK.md mode reading.

**Dependencies**: F-0157

**Implementation**:
- State: complete
- Code: `.agentic/bootstrap.sh`, `.agentic/ag`, `.agentic/hooks/pre-commit`, `.agentic/hooks/claude/*.sh`
- Tests: `tests/validate_framework.sh`

**Acceptance**: See `spec/acceptance/F-0159.md`

---

## F-0160: Autonomous Engine Foundation

**Status**: shipped
**Category**: Autonomous
**Priority**: critical
**Complexity**: high
**Since**: v0.42.0

**Description**: Foundation for autonomous workflow engine. Python engine (stdlib only) with thread-safe state management, Unix domain socket control plane (pause/resume/stop/feedback/status), three-tier permission model with `ag auto init` settings.json generator, acceptance criteria loader, pre-flight complexity estimation, and LARGE AC auto-decomposition into sub-tasks.

**Dependencies**: F-0157 (directory restructure), F-0158 (path resolution)

**Implementation**:
- State: complete
- Code: `.agentic/lib/auto/engine.py`, `.agentic/lib/auto/control.py`, `.agentic/lib/auto/init.py`, `.agentic/lib/auto/settings-template.json`, `.agentic/lib/auto/prompts/`
- Tests: `tests/test_auto_engine.py` (32 tests), `tests/validate_framework.sh`

**Acceptance**: See `spec/acceptance/F-0160.md`

---

## F-0161: Autonomous Verify Mode

**Status**: shipped
**Category**: Autonomous
**Priority**: high
**Complexity**: medium
**Since**: v0.43.0

**Description**: Test-fix loop mode (`ag auto verify`). Runs project test suite, spawns fresh Claude instance with failure output + relevant code, Claude fixes failures, re-runs tests, repeats until green or max iterations. Highest value, lowest risk entry point for autonomous mode.

**Dependencies**: F-0160

**Implementation**:
- State: complete
- Code: `.agentic/lib/auto/verify.py`
- Tests: `tests/test_auto_verify.py` (23 tests), `tests/test_auto_verify_tiers.py` (40 tests)
- Note: Shipped but not self-activated in framework dev — deliberate choice (human oversight for framework-critical work)

**Acceptance**: See `spec/acceptance/F-0161.md`

---

## F-0162: Autonomous Task Mode

**Status**: shipped
**Category**: Autonomous
**Priority**: high
**Complexity**: high
**Since**: v0.43.0

**Description**: Single feature implementation mode (`ag auto task F-XXXX`). Reads spec + acceptance criteria, creates feature branch + worktree, loops fresh Claude instances per AC, runs tests after each, commits if passing, creates PR for human review. Uses F-0160 control plane and state management.

**Dependencies**: F-0160, F-0161

**Implementation**:
- State: complete
- Code: `.agentic/lib/auto/task.py`
- Tests: `tests/test_auto_task.py` (8 tests)
- Note: Shipped but not self-activated in framework dev — deliberate choice (human oversight for framework-critical work)

**Acceptance**: See `spec/acceptance/F-0162.md`

---

## F-0163: Autonomous Crunch Mode

**Status**: shipped
**Category**: Autonomous
**Priority**: medium
**Complexity**: high
**Since**: v0.43.0

**Description**: Multi-feature batch mode (`ag auto crunch`). Orchestrates multiple F-0162 task runs in priority order, tracks overall progress, per-batch verification agent review, stops on max errors or human intervention.

**Dependencies**: F-0160, F-0161, F-0162

**Implementation**:
- State: complete
- Code: `.agentic/lib/auto/crunch.py`
- Tests: `tests/test_auto_crunch.py` (8 tests)
- Note: Shipped but not self-activated in framework dev — deliberate choice (human oversight for framework-critical work)

**Acceptance**: See `spec/acceptance/F-0163.md`

---

## F-0164: Tiered Verify Loop

**Status**: shipped
**Category**: Autonomous
**Priority**: high
**Complexity**: medium
**Since**: v0.44.0

**Description**: Extend the verify loop to support an ordered list of named test tiers (unit, integration, e2e, etc.) parsed from STACK.md's `Test commands:` section. Each tier has its own fix loop, timeout, and `continue_on_failure` setting. Fast-fail by default (tier failure stops subsequent tiers). Per-tier Claude fix prompts vary by tier type (unit vs e2e). Adds Playwright and Cypress output parsers. Fully backward compatible with single-tier projects.

**Dependencies**: F-0161

**Implementation**:
- State: complete
- Code: `.agentic/lib/auto/verify.py` (TestTier, TierResult, tiered execution), `.agentic/lib/auto/task.py` (updated API)
- Tests: `tests/test_auto_verify_tiers.py` (40 tests), `tests/test_auto_verify.py` (23 existing, backward compat)

**Acceptance**: See `spec/acceptance/F-0164.md`

---

## F-0168: Visual Verification

**Status**: shipped
**Category**: Autonomous
**Priority**: medium
**Complexity**: medium
**Since**: v0.45.0

**Description**: Screenshot collection from e2e test tiers and AI-powered visual review via Anthropic API. Parses `E2E screenshots:` from STACK.md, copies screenshots to session dir, optional `--visual` flag triggers multimodal AI review. Graceful degradation (no SDK/key = warning). Visual concerns are advisory only (never block).

**Dependencies**: F-0164

**Implementation**:
- State: shipped
- Code: `.agentic/lib/auto/verify.py` (screenshot collection, wiring), `.agentic/lib/auto/visual.py` (AI review)
- Tests: `tests/test_auto_visual.py`

**Acceptance**: See `spec/acceptance/F-0168.md`

---

## F-0169: NFR Discovery & Catalog

**Status**: shipped
**Category**: Quality
**Priority**: medium
**Complexity**: medium
**Since**: v0.46.0

**Description**: NFRs become a living, first-class concern. NFR catalog with suggestions by project type (web, API, game, mobile, audio, CLI, desktop). Init playbook Step 2c guides developers through NFR selection. Memory-seed proactive suggestion when NFR.md is template-only after 3+ shipped features.

**Dependencies**: None
**NFRs**: none

**Implementation**:
- State: complete
- Code: `.agentic/lib/init/nfr-catalog.md`, `.agentic/lib/init/init_playbook.md` (Step 2c), `.agentic/lib/init/memory-seed.md`
- Tests: `tests/validate_framework.sh`

**Acceptance**: See `spec/acceptance/F-0169.md`

---

## F-0170: NFR Enforcement in Spec Writing

**Status**: shipped
**Category**: Quality
**Priority**: medium
**Complexity**: medium
**Since**: v0.46.0

**Description**: Spec-writing actively enforces NFR consideration. Active matching evaluates EACH NFR for applicability. Promotion detection identifies recurring constraints that should be project-wide NFRs. Feature start gate checks NFR Compliance resolution. Framework dogfooding with NFR-0003 (small batch) and NFR-0004 (spec-first).

**Dependencies**: F-0169
**NFRs**: NFR-0004

**Implementation**:
- State: complete
- Code: `.agentic/lib/workflows/spec_writing.md`, `.agentic/lib/checklists/spec_writing.md`, `.agentic/lib/checklists/feature_start.md`, `.agentic/lib/checklists/feature_complete.md`, `.agentic/spec/NFR.md` (NFR-0003, NFR-0004)
- Tests: `tests/validate_framework.sh`

**Acceptance**: See `spec/acceptance/F-0170.md`

---

## F-0171: Spec Verification Tool

**Status**: shipped
**Category**: Quality
**Priority**: high
**Complexity**: high
**Since**: v0.46.0

**Description**: Solves "Who tests the tests?" — verification that tests actually prove what ACs claim. Multi-layer: structural (file exists), coverage (ACs defined), test heuristics (empty bodies, zero assertions), LLM review (intent match prompt template). `spec-audit.sh` orchestrates all layers. `ag audit` command entry point.

**Dependencies**: None
**NFRs**: none

**Implementation**:
- State: complete
- Code: `.agentic/lib/tools/spec-audit.sh`, `.agentic/lib/tools/test-review-prompt.md`, `.agentic/lib/tools/ag.sh` (audit command)
- Tests: `tests/validate_framework.sh`

**Acceptance**: See `spec/acceptance/F-0171.md`

---

## F-0172: Change Propagation Pipeline

**Status**: shipped
**Category**: Quality
**Priority**: high
**Complexity**: high
**Since**: v0.46.0

**Description**: When specs/NFRs change, trace the ripple effect downstream and generate remediation plans. `spec-audit.sh --propagate` traces NFR and migration changes to affected features. Generates actionable gap reports with severity levels.

**Dependencies**: F-0171
**NFRs**: none

**Implementation**:
- State: complete
- Code: `.agentic/lib/tools/spec-audit.sh` (propagation mode)
- Tests: `tests/validate_framework.sh`

**Acceptance**: See `spec/acceptance/F-0172.md`

---

## F-0173: QA Tracker State Machine

**Status**: shipped
**Category**: Quality
**Priority**: high
**Complexity**: high
**Since**: v0.46.0

**Description**: Persistent tracking with enforcement. Every verification and propagation event tracked in `.qa-tracker.json`. Escalation model (warn at 3 days, escalate at 7, block retro at 14). Surfaces at session start, pre-commit (advisory), `ag status`, and retrospective. Configurable via `qa_propagation_warn_days`, `qa_propagation_escalate_days`, `qa_audit_freshness_days`.

**Dependencies**: F-0171, F-0172
**NFRs**: none

**Implementation**:
- State: complete
- Code: `.agentic/lib/tools/qa-tracker.sh`, `.agentic/lib/tools/periodic-checks.sh`, `.agentic/lib/hooks/pre-commit-check.sh`, `.agentic/lib/checklists/session_start.md`, `.agentic/lib/presets/profiles.conf`
- Tests: `tests/validate_framework.sh`

**Acceptance**: See `spec/acceptance/F-0173.md`

---

## F-0174: Retrospective Enforcement

**Status**: shipped
**Category**: Quality
**Priority**: medium
**Complexity**: medium
**Since**: v0.46.0

**Description**: Retrospectives active by default for Formal profile. `retro_check.sh` refactored to use settings framework. Proactive triggers at session start and feature completion. Spec audit + NFR review integrated into retro checklist and workflow. Retro tracking via sync-state.conf.

**Dependencies**: F-0171
**NFRs**: none

**Implementation**:
- State: complete
- Code: `.agentic/lib/tools/retro_check.sh`, `.agentic/lib/checklists/retrospective.md`, `.agentic/lib/workflows/retrospective.md`, `.agentic/lib/agents/claude/skills/completing-work/SKILL.md`, `.agentic/lib/presets/profiles.conf`, `.agentic/lib/init/STACK.template.md`
- Tests: `tests/validate_framework.sh`

**Acceptance**: See `spec/acceptance/F-0174.md`

---

## F-0175: QA Suite Glue & Documentation

**Status**: shipped
**Category**: Quality
**Priority**: low
**Complexity**: low
**Since**: v0.46.0

**Description**: Connect all QA suite features, update docs, ensure discoverability. Feature registration, memory-seed triggers, version bump, migration.

**Dependencies**: F-0169, F-0170, F-0171, F-0172, F-0173, F-0174
**NFRs**: none

**Implementation**:
- State: complete
- Code: `.agentic/spec/FEATURES.md`, `.agentic/lib/init/memory-seed.md`, `VERSION`
- Tests: `tests/validate_framework.sh`

**Acceptance**: See `spec/acceptance/F-0175.md`

---

## F-0176: Plan-Aware Code Review

**Status**: shipped
**Category**: Quality
**Priority**: medium
**Complexity**: low
**Since**: v0.46.1

**Description**: The reviewing-code skill gains plan awareness. When reviewing a PR or diff associated with feature IDs, the skill searches `.agentic/journal/plans/` for matching plan files, reads the plan, and adds a "Plan Alignment" dimension to the review. Flags missing deliverables, unplanned additions, and deviations. This is the most valuable review dimension for plan-driven development — generic code quality checks miss whether the implementation actually matches what was agreed.

**Dependencies**: F-0143 (Skills-Primary Architecture)
**NFRs**: none

**Implementation**:
- State: complete
- Code: `.claude/skills/reviewing-code/SKILL.md`, `.agentic/lib/agents/claude/skills/reviewing-code/SKILL.md`, `.claude/skills/reviewing-code/references/review_checklist.md`
- Tests: `tests/validate_framework.sh`

**Acceptance**: See `spec/acceptance/F-0176.md`


---

## F-0177: Formal Feature State Machine

**Status**: shipped
**Category**: Workflow
**Priority**: critical
**Complexity**: high
**Since**: v0.47.0

**Description**: 9-state feature lifecycle implemented as Python code (ADR-001 Section 5). States: planned -> specced -> criteria_set -> tests_written -> implementing -> verified -> documented -> committed -> shipped. Forward transitions with gates, regression transitions with cascade invalidations, skip transitions for backward compatibility. Advisory mode (default) warns but doesn't block; enforce mode blocks.

**Dependencies**: none

**Implementation**:
- State: complete
- Code: `.agentic/lib/auto/state_machine.py`, `.agentic/lib/auto/gates.py`
- Tests: `tests/test_state_machine.py` (42 tests), `tests/test_gates.py` (23 tests)

**Acceptance**: See `spec/acceptance/F-0177.md`

---

## F-0178: State Machine Blast Radius Update

**Status**: shipped
**Category**: Workflow
**Priority**: high
**Complexity**: high
**Since**: v0.47.0

**Description**: Update all files that hard-code the old 4-status model (planned/in_progress/shipped/deprecated) to support 9 states. Covers: validation (validate_formats.py, doctor.py), queries (query_features.py, feature_stats.py), tools (feature.sh, ag.sh), autonomous mode (crunch.py), checklists, spec schema, and pre-commit hooks.

**Dependencies**: F-0177

**Implementation**:
- State: complete
- Code: 19 files modified across tools, validation, checklists, templates
- Tests: `tests/test_auto_crunch.py` updated, `tests/test_state_machine.py`, `tests/test_gates.py`

**Acceptance**: See `spec/acceptance/F-0178.md`

---

## F-0179: Component Registry and Scoped Context

**Status**: shipped
**Category**: Architecture
**Priority**: high
**Complexity**: medium
**Since**: v0.48.0

**Description**: Optional component registry in STACK.md (name | path | type | test_command). Features gain optional `Component` field. `context-for-role.sh` filters context to component scope. `discover.py` auto-detects components in monorepos. State machine gates use component-specific test commands. ADR-001 Phase 2, Section 1.

**Dependencies**: F-0177

**Implementation**:
- State: complete
- Code: `.agentic/lib/auto/components.py`, modifications to `context-for-role.sh`, `discover.py`, `query_features.py`, `gates.py`, `STACK.template.md`
- Tests: `tests/test_components.py`

**Acceptance**: See `spec/acceptance/F-0179.md`

---

## F-0180: Review Checkpoint Framework

**Status**: shipped
**Category**: Workflow
**Priority**: high
**Complexity**: high
**Since**: v0.48.0

**Description**: Configurable review gates on state machine transitions. Three modes: `human | critical_agent | skip` per transition, per profile. Settings in STACK.md (`review_spec`, `review_criteria`, `review_plan`, `review_code`, `review_merge`). State machine blocks at review checkpoints when mode is `human`. `critical_agent` mode falls back to `human` until Phase 4 ships. ADR-001 Phase 3, Section 5.1.

**Dependencies**: F-0177

**Implementation**:
- State: none
- Code: `.agentic/lib/auto/review.py` (new), modifications to `state_machine.py`, `ag.sh`, `STACK.template.md`
- Tests: `tests/test_review.py` (new), `tests/test_state_machine_with_reviews.py` (new)

**Acceptance**: See `spec/acceptance/F-0180.md`

---

## F-0181: Autonomous Formal Profile

**Status**: shipped
**Category**: Workflow
**Priority**: medium
**Complexity**: low
**Since**: v0.48.0

**Description**: New `autonomous_formal` profile in `profiles.conf` with agent-friendly review defaults: skip/critical_agent for most checkpoints, human only for final merge. Defines review checkpoint defaults per profile (Discovery, Formal, Autonomous Formal). ADR-001 Phase 3.

**Dependencies**: F-0180

**Implementation**:
- State: none
- Code: `.agentic/lib/presets/profiles.conf`, `upgrade.sh`
- Tests: Profile validation in `tests/test_review.py`

**Acceptance**: See `spec/acceptance/F-0181.md`

---

## F-0182: Critical Review Agent

**Status**: shipped
**Category**: Autonomous
**Priority**: high
**Complexity**: high
**Since**: v0.49.0

**Description**: Adversarial review agent — separate Claude instance with read-only access. Can approve, request-changes, or escalate to human. Structured review verdicts stored as artifacts. Uses `review` model from STACK.md. Adversarial mandate: find problems, not rubber-stamp. "If in doubt, escalate" prevents weak approvals. ADR-001 Phase 4, Section 5.1.

**Dependencies**: F-0180

**Implementation**:
- State: none
- Code: `.agentic/lib/auto/critical_agent.py` (new), `.agentic/lib/auto/prompts/critical_review.md` (new), modifications to `review.py`
- Tests: `tests/test_critical_agent.py` (new)

**Acceptance**: See `spec/acceptance/F-0182.md`

---

## F-0183: Taste and Style Settings

**Status**: planned
**Category**: Autonomous
**Priority**: medium
**Complexity**: medium
**Since**: v0.49.0

**Description**: Style/taste settings in STACK.md: `style_guide`, `design_system`, `api_style`. Loaded into critical agent context for taste-sensitive reviews. Critical agent validates consistency with declared style direction. ADR-001 Phase 4, Section 5.2.

**Dependencies**: F-0182

**Implementation**:
- State: none
- Code: Modifications to `STACK.template.md`, `critical_agent.py`, `.agentic/lib/auto/prompts/taste_review.md` (new)
- Tests: Taste review tests in `tests/test_critical_agent.py`

**Acceptance**: See `spec/acceptance/F-0183.md`

---

## F-0184: Epic Decomposition

**Status**: shipped
**Category**: Architecture
**Priority**: high
**Complexity**: high
**Since**: v0.50.0

**Description**: `ag decompose F-XXXX` command: analyze epic acceptance criteria, identify components (using component registry), propose child features, route through `review_decomposition` checkpoint. Parent-child cascade: child regression triggers epic status recomputation. Epic ships when all children ship + integration verification passes. ADR-001 Phase 5, Section 2.

**Dependencies**: F-0179, F-0180

**Implementation**:
- State: none
- Code: `.agentic/lib/auto/epic.py` (new), modifications to `state_machine.py`, `components.py`, `ag.sh`, `query_features.py`, `feature.sh`
- Tests: `tests/test_epic.py` (new)

**Acceptance**: See `spec/acceptance/F-0184.md`

---

## F-0185: MCP Server for Agent Coordination

**Status**: planned
**Category**: Autonomous
**Priority**: medium
**Complexity**: high
**Since**: v0.51.0

**Description**: Python MCP server with 8 tools: `claim_feature`, `release_feature`, `transition_state`, `get_unblocked`, `subscribe_state`, `report_status`, `request_review`, `submit_review`. Thin wrapper delegating to existing classes. Graceful degradation: if MCP unavailable, framework uses file-based coordination. ADR-001 Phase 6, Section 4.

**Dependencies**: F-0177, F-0180, F-0184

**Implementation**:
- State: none
- Code: `.agentic/lib/auto/mcp_server.py` (new), `.agentic/lib/auto/mcp_tools.py` (new), modifications to `ag.sh`, `engine.py`
- Tests: `tests/test_mcp_server.py` (new)

**Acceptance**: See `spec/acceptance/F-0185.md`

---

## F-0186: Autonomous Scheduler

**Status**: shipped  
**Category**: Autonomous
**Priority**: high
**Complexity**: high
**Since**: v0.52.0

**Description**: `AutonomousScheduler` class: `get_unblocked() → spawn worker → review gate → repeat` loop. Non-blocking reviews: while one feature awaits human/escalated review, scheduler advances others. Worker agents scoped to components. Evolves `crunch.py` into scheduler-backed execution. `ag auto epic F-XXXX` command. ADR-001 Phase 7, Section 3.

**Dependencies**: F-0182, F-0184

**Implementation**:
- State: none
- Code: `.agentic/lib/auto/scheduler.py` (new), modifications to `crunch.py`, `ag.sh`, `profiles.conf`
- Tests: `tests/test_scheduler.py` (new)

**Acceptance**: See `spec/acceptance/F-0186.md`

---

## F-0187: Multi-Repo Umbrella

**Status**: planned
**Category**: Architecture
**Priority**: medium
**Complexity**: high
**Since**: v0.52.0

**Description**: `Repo` column in component registry for cross-repo projects. Umbrella pattern: orchestrator in main repo, components in parallel repos. Cross-repo contract checking. User input collection: structured prompts for vision, style refs, research before decomposition. ADR-001 Phase 7, Section 6.

**Dependencies**: F-0179, F-0186

**Implementation**:
- State: none
- Code: `.agentic/lib/auto/umbrella.py` (new), modifications to `components.py`
- Tests: `tests/test_umbrella.py` (new)

**Acceptance**: See `spec/acceptance/F-0187.md`

---

## F-0188: End-to-End Autonomous Flow

**Status**: planned
**Category**: Autonomous
**Priority**: high
**Complexity**: high
**Since**: v0.52.0

**Description**: Full autonomous pipeline: epic → decompose → schedule → implement → review → ship. Integrates all ADR-001 components. User provides prompt + research + style guidelines, agents handle everything. Integration verification across all phases. ADR-001 Phase 7 capstone.

**Dependencies**: F-0186, F-0187

**Implementation**:
- State: none
- Code: Integration across all auto/ modules
- Tests: `tests/test_e2e_autonomous.py` (new)

**Acceptance**: See `spec/acceptance/F-0188.md`

---

## F-0189: Doc Enforcement at Feature Acceptance

**Status**: shipped
**Category**: Verification & Enforcement
**Priority**: high
**Complexity**: medium
**Since**: v0.47.0

**Description**: Wire existing doc drift detection (`drift.sh --docs`, `docs_gate` setting) into feature acceptance and merge gates. Enforces documentation updates when features complete — not on every commit (too noisy), but at the gates that matter: state machine transition, autonomode pipeline, implementing/reviewing skills.

**Dependencies**: F-0138

**Implementation**:
- State: partial
- Code: `drift.sh`, `gates.py`, `task.py`, `engine.py`, skills
- Tests: `tests/test_gates.py`

**Acceptance**: See `spec/acceptance/F-0189.md`

---

## F-0190: Backlog/Roadmap — Structural Work Assignment

**Status**: shipped
**Category**: Session
**Priority**: critical
**Complexity**: high
**Since**: v0.49.0

**Description**: Git-tracked ordered work queue (BACKLOG.json) that tells any agent on any machine what to work on next. Position 0 = current work. Structural gates in ag implement/work/done enforce queue order. Escape hatch via SKIP_BACKLOG=1.

**Dependencies**: F-0177

**Implementation**:
- State: complete
- Code: `backlog_helpers.py`, `backlog.sh`, `ag.sh` gates
- Tests: `tests/test_backlog_helpers.py`, `validate_framework.sh`

**Acceptance**: See `spec/acceptance/F-0190.md`

## F-0191: Dialectical Plan Review

**Status**: in_progress
**Category**: Quality
**Priority**: high
**Complexity**: medium
**Since**: v0.50.0

**Description**: Plan review uses dialectical mechanism — Critic (adversarial) + Advocate (defensive) agents run in parallel with fresh context. Orchestrator synthesizes both perspectives into a balanced assessment with Revision Guidance. User decides: Proceed, Revise, or Reject. Supports iteration. Replaces the single-reviewer model in the plan-review loop (F-0120). Controlled by `plan_review_enabled` (no separate setting).

**Dependencies**: F-0120

**Implementation**:
- State: implementing
- Code: `dialectical_review.md` mechanism, `plan_review_loop.md` lifecycle, `plan-critic-agent.md`, `plan-advocate-agent.md`, `ag.sh` integration
- Tests: `validate_framework.sh`

**Acceptance**: See `spec/acceptance/F-0191.md`

---

## F-0192: Review Subagent Delegation

**Status**: implementing
**Category**: Quality
**Priority**: medium
**Complexity**: low

**Description**: The /review skill delegates to a fresh-context subagent instead of running inline, keeping review diffs, file reads, and checklist references out of the main conversation context. Saves tokens by discarding disposable review context after producing a compact findings summary.

**Dependencies**: None

**Implementation**:
- State: none
- Code: `.claude/skills/reviewing-code/SKILL.md`
- Tests: Behavioral (verify subagent is spawned)

**Acceptance**: See `spec/acceptance/F-0192.md`

---

## F-0193: Collision-Proof Feature IDs

**Status**: planned
**Category**: Architecture
**Priority**: high
**Complexity**: medium

**Description**: Sequential F-XXXX IDs collide when multiple agents or branches assign independently. Two agents picking "next ID" from the same FEATURES.md will choose the same number, causing merge conflicts and broken references across acceptance files, plans, journal entries, and code annotations. Needs research into slug-based IDs, atomic allocation, or other collision-proof schemes.

**Dependencies**: None

**Implementation**:
- State: none
- Code: TBD (feature.sh, FEATURES.md format, possibly all spec tooling)
- Tests: TBD

**Acceptance**: TBD — requires design phase first

---

## F-0194: Worktree-by-Default for Feature Branches

**Status**: planned
**Category**: Architecture
**Priority**: high
**Complexity**: medium

**Description**: Agents should always work in git worktrees when on feature branches, not dirty the main worktree. Current instruction exists but is too weak ("Use git worktree on feature branches when another agent may be working on main"). Needs: clear mandatory instruction in CLAUDE.md/skills, a STACK.md setting (e.g., worktree_mode: always|multi-agent|off), and possibly ag implement auto-creating the worktree.

**Dependencies**: None

**Implementation**:
- State: none
- Code: TBD (ag.sh, STACK.md template, CLAUDE.md templates, skills)
- Tests: TBD

**Acceptance**: TBD — requires design phase first

## F-0195: Multi-Session Collision Prevention

**Status**: shipped
**Category**: Multi-Agent
**Priority**: high
**Complexity**: medium
**Principle**: R2 (Anti-Hallucination), D2 (Deterministic Enforcement)

**Description**: Multiple agents/sessions on the same checkout destroy each other's work via destructive git ops. Three-layer defense: (1) auto-registration of sessions in AGENTS.json, (2) advisory collision warnings via UserPromptSubmit hook, (3) instruction hardening across all agent templates.

**Dependencies**: F-0194 (AGENTS.json infrastructure)

**Implementation**:
- State: agents_helpers.py session commands, hook scripts, instruction files
- Code: session-register/deregister/count-others/cleanup-stale/heartbeat
- Tests: test_session_tracking.py

**Acceptance**: spec/acceptance/F-0195.md

## F-0196: Fluent State File Commits (ag flush)

**Status**: in_progress
**Category**: Developer Experience
**Priority**: high
**Complexity**: medium

One command (`ag flush`) commits + pushes state-only changes directly to main without a PR. Uses a hardcoded allowlist as a security boundary — code changes still require PRs. Self-contained validation with `--no-verify` (stricter than the pre-commit hook).

**Dependencies**: None

**Implementation**:
- State: state-commit.sh, ag.sh dispatch, dashboard integration
- Code: .agentic/lib/tools/state-commit.sh
- Tests: validate_framework.sh structural checks

**Acceptance**: spec/acceptance/F-0196.md

## F-0197: FEATURES.md Registry Integrity + AC Verification Gate

**Status**: shipped
**Category**: Reliability
**Priority**: high
**Complexity**: medium

Fix 5 features with status/implementation mismatches (deprecate F-0033, F-0098; correct F-0179, F-0189, F-0190). Add drift-check tool comparing FEATURES.md status against AC completion. Add AC completion gate to `ag done` (<80% checked → warn/block). Part of Reliability Fix Plan (PR 1).

**Dependencies**: None

**Implementation**:
- State: complete
- Code: .agentic/lib/tools/drift-check.sh, .agentic/lib/tools/ag.sh, .agentic/lib/tools/sync.sh, .agentic/lib/tools/dashboard.sh
- Tests: validate_framework.sh

**Acceptance**: spec/acceptance/F-0197.md

## F-0198: Plan Durability (Multi-Tool Scan)

**Status**: shipped
**Category**: Reliability
**Priority**: medium
**Complexity**: small

Scan tool-specific plan directories (~/.claude/plans/, .cursor/plans/) for files mentioning F-XXXX IDs during `ag sync`. Auto-copy to `.agentic/journal/plans/` if not already saved. Prevents plan loss from session-scoped storage. Part of Reliability Fix Plan (PR 2). Closes T-0047.

**Dependencies**: None

**Implementation**:
- State: sync.sh plan scan phase
- Code: .agentic/lib/tools/sync.sh
- Tests: validate_framework.sh

**Acceptance**: spec/acceptance/F-0198.md

## F-0199: Instruction File Sync Detection

**Status**: shipped
**Category**: Reliability
**Priority**: high
**Complexity**: medium

Detect when ag.sh commands are added but instruction files (CLAUDE.md, cursorrules, copilot, codex, auto_orchestration, memory-seed) are not updated. Parse ag.sh case statement, cross-reference against all 8+ instruction files. Wire into validate_framework.sh (warning initially) and pre-commit-check.sh. Part of Reliability Fix Plan (PR 3).

**Dependencies**: None

**Implementation**:
- State: new instruction-sync.sh, validate_framework.sh wiring
- Code: .agentic/lib/tools/instruction-sync.sh
- Tests: validate_framework.sh, pre-commit-check.sh

**Acceptance**: spec/acceptance/F-0199.md

## F-0200: Intent Journal + Reconciliation

**Status**: shipped
**Category**: Reliability
**Priority**: high
**Complexity**: large

Write-ahead log for multi-step ag.sh operations (implement, done) with crash recovery via reconciliation in `ag sync`. Fixes gates.py/state_machine.py being defined but never invoked from CLI. Three enforcement modes (off/advisory/blocking) via STACK.md. Includes intents.py module, intent-helpers.sh extraction, reconciler with adopt-orphan recovery, `ag intent` commands. Prerequisite: state_machine.py idempotency fix. Part of Reliability Fix Plan (PRs 4-7).

**Dependencies**: F-0197 (AC gate wired into cmd_done first)

**Implementation**:
- State: intents.py, intent-helpers.sh, ag.sh refactor, sync.sh reconciler
- Code: .agentic/lib/auto/intents.py, .agentic/lib/tools/intent-helpers.sh, .agentic/lib/auto/state_machine.py
- Tests: tests/test_intents.py, validate_framework.sh

**Acceptance**: spec/acceptance/F-0200.md
