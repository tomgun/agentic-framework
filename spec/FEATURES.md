# Agentic AI Framework - Feature Specification

<!-- format: features-v0.2.0 -->

**Purpose**: Define what the Agentic AI Framework can reliably do at each version.

**Version**: 0.25.0

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
| **Agent System** | F-0081 to F-0090 | Specialized agents, orchestration, token efficiency |
| **Verification & Enforcement** | F-0091 to F-0100 | Gate-based verification, phase detection, enforcement |

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

## F-0009: OVERVIEW.md (Core Profile)

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

**Status**: deprecated
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

## F-0035: Agent Role Definitions

**Status**: shipped  
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

## F-0077: Emergency Quick Reference

**Status**: shipped  
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
**Priority**: high
**Complexity**: low
**Since**: v0.11.3

**Description**: PR-based git workflow is the default for Core+PM profile. Agents create feature branches and PRs instead of committing directly to main. Profile-aware defaults: Core+PM → `pull_request`, Core → `direct`. Users can override in STACK.md.

**Dependencies**: F-0002 (Profile Selection)

**Implementation**:
- State: complete
- Code: `.agentic/workflows/git_workflow.md`, `.agentic/init/STACK.template.md`, agent guidelines
- Tests: validation script checks

**Acceptance**: See `spec/acceptance/F-0096.md`

---

## F-0097: Worktree Management Tool

**Status**: shipped
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

**Status**: in_progress
**Priority**: medium
**Complexity**: medium
**Since**: v0.11.5

**Description**: Generate Claude Code Skills (`.claude/skills/`) from subagent definitions, enabling auto-discovery while maintaining single source of truth. Skills are regenerated during install/upgrade.

**Dependencies**: None

**Implementation**:
- State: partial
- Code: `.agentic/tools/generate-skills.sh`
- Tests: manual validation

**Acceptance**: See `spec/acceptance/F-0098.md`

---

## F-0101: Framework Architecture Decision Records (ADRs)

**Status**: shipped
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
**Since**: v0.12.2
**Category**: Framework Infrastructure

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
**Priority**: medium
**Profile**: Both

**Description**: Utility scripts for multi-agent coordination that are documented but not yet implemented:
- `agents_active.sh` - Parse and display AGENTS_ACTIVE.md status
- `check_agent_conflicts.sh` - Check if files overlap between agents
- `sync_worktrees.sh` - Pull main into all worktrees
- `git_mode.sh` - Show git workflow mode from STACK.md
- `upgrade_profile.sh` - Upgrade Core → Core+PM profile

**Dependencies**: F-0031 (Multi-Agent Coordination)

**Implementation**:
- State: none
- Code: `.agentic/tools/` (to be created)
- Tests: unit tests for each script

**Acceptance**: See `spec/acceptance/F-0108.md`

---

## F-0109: Spec-Code Traceability Enhancements

**Status**: shipped
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
**Priority**: medium
**Complexity**: small
**Since**: v0.15.1

**Description**: Enforce git workflow policy from STACK.md. When `git_workflow: pull_request`, block commits to main/master with clear guidance (create feature branch, use --no-verify for hotfixes, or switch to direct workflow). Profile-aware defaults: Core → direct, Core+PM → pull_request.

**Dependencies**: F-0002 (Profile Selection), F-0016 (Pre-Commit Quality Gates), F-0096 (PR-Based Workflow Default)

**Implementation**:
- State: complete
- Code: `.agentic/hooks/pre-commit-check.sh`, `.agentic/init/scaffold.sh`, `.agentic/init/init_playbook.md`, `.agentic/init/STACK.template.md`
- Tests: `tests/validate_framework.sh` (9 checks)

**Acceptance**: See `spec/acceptance/F-0115.md`

---

## F-0116: Maintainability Enforcement Gates

**Status**: shipped
**Priority**: high
**Complexity**: medium
**Since**: v0.16.0

**Description**: Enforce maintainability through automated gates: test execution (BLOCKING), complexity limits (BLOCKING: max files, max added lines, max file length), and escape hatches for legitimate bypasses (blocked on main/master). Both Core and Core+PM profiles enforce tests and complexity limits.

**Dependencies**: F-0016 (Pre-Commit Quality Gates), F-0115 (Git Workflow Branch Check)

**Implementation**:
- State: complete
- Code: `.agentic/hooks/pre-commit-check.sh` (checks 6-7), `.agentic/tools/wip.sh` (--auto flag), `.agentic/tools/doctor.py` (frontmatter parsing), `.agentic/tools/upgrade.sh` (migration)
- Tests: `tests/validate_framework.sh`

**Acceptance**: See `spec/acceptance/F-0116.md`

---

## F-0117: Spec Migration System

**Status**: shipped
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

## Summary

| Category | Shipped | In Progress | Planned | Total |
|----------|---------|-------------|---------|-------|
| Core (F-0001-0010) | 10 | 0 | 0 | 10 |
| Quality (F-0011-0020) | 7 | 0 | 0 | 7 |
| Session (F-0021-0030) | 8 | 0 | 0 | 8 |
| Multi-Agent (F-0031-0040) | 7 | 0 | 0 | 7 |
| Tooling (F-0041-0050) | 4 | 0 | 0 | 4 |
| Recovery (F-0051-0060) | 6 | 0 | 0 | 6 |
| Developer Experience (F-0061-0070) | 10 | 0 | 0 | 10 |
| Design Principles (F-0071-0080) | 10 | 0 | 0 | 10 |
| Agent System (F-0081-0090) | 4 | 0 | 0 | 4 |
| Verification & Enforcement (F-0091-0100) | 7 | 1 | 0 | 8 |
| Framework Infrastructure (F-0101+) | 12 | 1 | 1 | 14 |
| **Total** | **85** | **2** | **1** | **88** |

