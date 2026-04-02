# Agentic AI Framework - Feature Specification

<!-- format: features-v1.0.0 -->

**Purpose**: Define what the Agentic AI Framework can reliably do. Each feature has a YAML contract in `spec/contracts/`.

**Version**: 0.72.0

---

## Feature Categories

| Category | Count | Shipped | In Progress | Planned |
|----------|-------|---------|-------------|---------|
| **Core Workflow** | 8 | 5 | 1 | 2 |
| **Quality** | 6 | 6 | 0 | 0 |
| **Design Principles** | 1 | 1 | 0 | 0 |
| **Session** | 1 | 1 | 0 | 0 |
| **Multi-Agent** | 4 | 2 | 0 | 2 |
| **Tooling** | 2 | 2 | 0 | 0 |
| **Recovery** | 1 | 1 | 0 | 0 |
| **Developer Experience** | 5 | 3 | 0 | 2 |
| **Agent System** | 1 | 1 | 0 | 0 |
| **Architecture** | 4 | 3 | 0 | 1 |
| **Git Workflow** | 2 | 1 | 0 | 1 |
| **Autonomous** | 3 | 2 | 0 | 1 |
| **Dev Infrastructure** | 4 | 3 | 1 | 0 |
| **Total** | **41** | **30** | **2** | **9** |

> **Feature types** (shown where relevant): `capability` — user-facing (default, unlabeled) · `infrastructure` — permanent dev tooling · `research` — time-bounded experiment · `meta` — organizational container
>
> Development infrastructure items (`DEV-XXXX`) use the full `ag` workflow but are not user-facing capabilities.

---

## F-001: Project Initialization & Profiles

**Status**: shipped | **Category**: core-workflow | **Since**: v0.1.0 | **Profile**: both
**Contract**: [`spec/contracts/F-001.yaml`](contracts/F-001.yaml)
**Consolidates**: F-001, F-0002, F-0009, F-0123, F-0124, F-0131, F-0141

Initialize new projects with Discovery or Formal profiles. Settings in STACK.md control behavior — profiles are preset bundles. Existing projects get intelligent onboarding with domain discovery.

---

## F-002: Spec-Driven Development

**Status**: shipped | **Category**: core-workflow | **Since**: v0.1.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-002.yaml`](contracts/F-002.yaml)
**Consolidates**: F-002, F-0005, F-0006, F-0010, F-0043, F-0117, F-0128, F-0132, F-0147, F-0148, F-0149, F-0152, F-0251

Formal-profile projects manage features through YAML contract specifications with testable acceptance criteria. Features have lifecycle states, enforcement gates, and migration-protected shipped contracts.

---

## F-003: Feature Tracking & Lifecycle

**Status**: shipped | **Category**: core-workflow | **Since**: v0.1.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-003.yaml`](contracts/F-003.yaml)
**Consolidates**: F-003, F-0042, F-0078, F-0109, F-0110, F-0177, F-0178, F-0193, F-0197

State machine manages feature lifecycle from planned through shipped. Transitions are gated, with forward/regression/skip rules. Feature categories, priorities, and complexity tracked in FEATURES.md. Feature ID patterns centralized in ids.py/ids.sh.

---

## F-007: Development Constraints & Principles

**Status**: shipped | **Category**: design-principles | **Since**: v0.1.0 | **Profile**: both
**Contract**: [`spec/contracts/F-007.yaml`](contracts/F-007.yaml)
**Consolidates**: F-007, F-0008, F-0069, F-0070, F-0072, F-0073, F-0074, F-0076, F-0209

Enforced development principles: small batches, one feature at a time, spec before code, tests alongside code. Structural tests verify principle adherence.

---

## F-008: Code Quality Standards

**Status**: shipped | **Category**: quality | **Since**: v0.2.0 | **Profile**: both
**Contract**: [`spec/contracts/F-008.yaml`](contracts/F-008.yaml)
**Consolidates**: F-008, F-0012, F-0013, F-0014, F-0015, F-0116

Consistent code quality across shell and Python: ShellCheck, error handling patterns, naming conventions, function documentation. Structural tests verify standards.

---

## F-009: Pre-Commit Quality Gates

**Status**: shipped | **Category**: quality | **Since**: v0.2.0 | **Profile**: both
**Contract**: [`spec/contracts/F-009.yaml`](contracts/F-009.yaml)
**Consolidates**: F-009, F-0017, F-0091, F-0092, F-0114, F-0115, F-0154, F-0155, F-0229, F-0301

Pre-commit hooks enforce quality: ShellCheck, spec consistency, file size limits, state file freshness. Git hooks installed automatically during init.

---

## F-015: Session Management

**Status**: shipped | **Category**: session | **Since**: v0.3.0 | **Profile**: both
**Contract**: [`spec/contracts/F-015.yaml`](contracts/F-015.yaml)
**Consolidates**: F-015, F-0022, F-0023, F-0024, F-0025, F-0026, F-0027, F-0125, F-0126, F-0127, F-0136, F-0145, F-0156, F-0240

Session start shows dashboard with status, focus, health, and next steps. Context packs provide efficient handoff between sessions. TODO capture, journal entries, and status tracking persist across sessions.

---

## F-017: Multi-Agent Coordination

**Status**: shipped | **Category**: multi-agent | **Since**: v0.5.0 | **Profile**: both
**Contract**: [`spec/contracts/F-017.yaml`](contracts/F-017.yaml)
**Consolidates**: F-017, F-0032, F-0034, F-0035, F-0036, F-0037, F-0194, F-0195, F-0214, F-0250

Multiple agents work on same project safely via AGENTS.json tracking, git worktrees for isolation, collision detection before destructive operations, and lock-free coordination protocols.

---

## F-019: Token & Resource Efficiency

**Status**: shipped | **Category**: tooling | **Since**: v0.4.0 | **Profile**: both
**Contract**: [`spec/contracts/F-019.yaml`](contracts/F-019.yaml)
**Consolidates**: F-019, F-0071, F-0102, F-0103, F-0112, F-0237, F-0238, F-0244

Token-efficient scripts for state file updates (journal.sh, status.sh, feature.sh, etc.) — agents call scripts instead of editing files directly. Subagent context packs minimize token waste.

---

## F-016: Crash Recovery & Work Tracking

**Status**: shipped | **Category**: recovery | **Since**: v0.4.0 | **Profile**: both
**Contract**: [`spec/contracts/F-016.yaml`](contracts/F-016.yaml)
**Consolidates**: F-016, F-0052, F-0053, F-0054, F-0055, F-0200

Session start detects interrupted work via AGENTS.json. Recovery shows what was in progress, uncommitted changes, and resume path. Intent journal tracks orphaned operations.

---

## F-020: Framework Upgrade & Versioning

**Status**: shipped | **Category**: tooling | **Since**: v0.5.0 | **Profile**: both
**Contract**: [`spec/contracts/F-020.yaml`](contracts/F-020.yaml)
**Consolidates**: F-020, F-0068, F-0094

VERSION file tracks framework version. upgrade.sh handles version bumps with backward compatibility. Semantic versioning with changelog.

---

## F-026: Developer Documentation

**Status**: shipped | **Category**: developer-experience | **Since**: v0.5.0 | **Profile**: both
**Contract**: [`spec/contracts/F-026.yaml`](contracts/F-026.yaml)
**Consolidates**: F-026, F-0062, F-0063, F-0064, F-0065, F-0066, F-0067, F-0134

DEVELOPER_GUIDE.md, HOW_IT_WORKS.md, FRAMEWORK_DEVELOPMENT.md, and other docs explain the framework for users and contributors. Documentation is code — updated alongside features.

---

## F-027: Emergency Quick Reference

**Status**: shipped | **Category**: developer-experience | **Since**: v0.6.0 | **Profile**: both
**Contract**: [`spec/contracts/F-027.yaml`](contracts/F-027.yaml)
**Consolidates**: F-027

EMERGENCY.md provides quick-reference for common recovery scenarios (stuck builds, merge conflicts, agent crashes).

---

## F-010: Issue & Feedback Tracking

**Status**: shipped | **Category**: quality | **Since**: v0.6.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-010.yaml`](contracts/F-010.yaml)
**Consolidates**: F-010, F-0206

ISSUES.md tracks bugs and tech debt. FEEDBACK_LOG.md captures user feedback. Both integrated into session start awareness.

---

## F-025: Agent System & Instructions

**Status**: shipped | **Category**: agent-system | **Since**: v0.6.0 | **Profile**: both
**Contract**: [`spec/contracts/F-025.yaml`](contracts/F-025.yaml)
**Consolidates**: F-025, F-0082, F-0083, F-0084, F-0093, F-0111, F-0113, F-0121, F-0135, F-0143, F-0146, F-0234

Three-layer instruction architecture (Constitution → Playbooks → State). Multi-tool agent support (Claude, Cursor, Copilot, Codex). Skills provide just-in-time guidance. Memory seed bootstraps agent knowledge.

---

## F-021: Cross-Platform Compatibility

**Status**: shipped | **Category**: architecture | **Since**: v0.8.0 | **Profile**: both
**Contract**: [`spec/contracts/F-021.yaml`](contracts/F-021.yaml)
**Consolidates**: F-021

Framework works on macOS and Linux. Shell scripts use portable constructs. Path resolution handles both platforms.

---

## F-024: Git Workflow & PR Management

**Status**: shipped | **Category**: git-workflow | **Since**: v0.8.0 | **Profile**: both
**Contract**: [`spec/contracts/F-024.yaml`](contracts/F-024.yaml)
**Consolidates**: F-024, F-0097, F-0182, F-0192, F-0196, F-0235, F-0239

Feature branches, PR creation, commit gates, and merge workflow. HUMAN_NEEDED.md tracks PRs awaiting review. Worktree-based isolation for parallel work.

---

## F-011: Architecture Decision Records

**Status**: shipped | **Category**: quality | **Since**: v0.8.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-011.yaml`](contracts/F-011.yaml)
**Consolidates**: F-011

ADR directory tracks architectural decisions with status, context, and consequences.

---

## F-012: Documentation Drift & Lifecycle

**Status**: shipped | **Category**: quality | **Since**: v0.10.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-012.yaml`](contracts/F-012.yaml)
**Consolidates**: F-012, F-0119, F-0138, F-0139, F-0144, F-0207

drift.sh detects stale documentation. docs.sh manages doc registry in STACK.md. Doc lifecycle integrated into feature shipping: spec + code + tests + docs = done.

---

## F-004: Plan & Design Review

**Status**: shipped | **Category**: core-workflow | **Since**: v0.10.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-004.yaml`](contracts/F-004.yaml)
**Consolidates**: F-004, F-0133, F-0150, F-0191, F-0236

Dialectical plan review: Critic + Advocate agents evaluate plans in fresh context. Plans saved to journal/plans/ with DRAFT/APPROVED/REJECTED status. Convergence modes: auto or manual.

---

## DEV-002: Testing Infrastructure

**Status**: shipped | **Category**: dev-infrastructure | **Since**: v0.10.0 | **Profile**: both
**Type**: infrastructure | **Parent**: DEV-001
**Contract**: [`spec/contracts/DEV-002.yaml`](contracts/DEV-002.yaml)
**Consolidates**: DEV-002, F-0153, F-0171, F-0172, F-0173, F-0174, F-0175, F-0241, F-0242

validate_framework.sh (structural tests), LLM behavioral tests, QA registry mapping features to tests, spec-code traceability. Framework verification at multiple layers.

---

## F-028: User Extensions & Customization

**Status**: shipped | **Category**: developer-experience | **Since**: v0.15.0 | **Profile**: both
**Contract**: [`spec/contracts/F-028.yaml`](contracts/F-028.yaml)
**Consolidates**: F-028, F-0179, F-0183

Component registry, user-defined extensions, project-specific customizations via STACK.md settings.

---

## F-022: Framework Architecture & Paths

**Status**: shipped | **Category**: architecture | **Since**: v0.20.0 | **Profile**: both
**Contract**: [`spec/contracts/F-022.yaml`](contracts/F-022.yaml)
**Consolidates**: F-022, F-0158, F-0159, F-0198, F-0221

Central path resolver (paths.py/paths.sh) with backward-compatible dual-location support. Directory structure: .agentic/lib/ (code), .agentic/spec/ (specs), .agentic/session/ (ephemeral), .agentic/journal/ (history).

---

## F-030: Autonomous Execution Engine

**Status**: shipped | **Category**: autonomous | **Since**: v0.30.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-030.yaml`](contracts/F-030.yaml)
**Consolidates**: F-030, F-0161, F-0162, F-0163, F-0164, F-0168, F-0186, F-0204, F-0215

VerifyLoop engine executes acceptance criteria autonomously: load ACs → implement → verify → repeat. Supports task-level and epic-level autonomous execution. Feedback mechanism for mid-flight corrections.

---

## F-013: Non-Functional Requirements

**Status**: shipped | **Category**: quality | **Since**: v0.25.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-013.yaml`](contracts/F-013.yaml)
**Consolidates**: F-013, F-0170, F-0216, F-0217, F-0218, F-0219

NFR.md tracks cross-cutting quality requirements. NFR assertions verified structurally. `ag nfr discover` suggests NFRs from project patterns. NFR coverage tracked per feature.

---

## F-014: Review Checkpoint Framework

**Status**: shipped | **Category**: quality | **Since**: v0.30.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-014.yaml`](contracts/F-014.yaml)
**Consolidates**: F-014, F-0176, F-0203

Configurable review checkpoints: human, critical_agent, or skip. Controls for plan review, code review, regression review, merge review, commit review. Critical agent provides automated review for autonomous workflows.

---

## F-029: Autonomous Formal Profile

**Status**: shipped | **Category**: autonomous | **Since**: v0.30.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-029.yaml`](contracts/F-029.yaml)
**Consolidates**: F-029

autonomous_formal profile: formal rigor with review_code and review_regression delegated to critical_agent. Only review_merge stays human. Enables autonomous execution with quality guarantees.

---

## F-005: Feature Hierarchy & Decomposition

**Status**: shipped
**Contract**: [`spec/contracts/F-005.yaml`](contracts/F-005.yaml)
**Consolidates**: F-005

`ag decompose` breaks epics into child features by component. Parent-child relationships tracked. review_decomposition checkpoint validates decomposition quality.

---

## F-018: Coordination Server

**Status**: shipped | **Category**: multi-agent | **Since**: v0.35.0 | **Profile**: both
**Contract**: [`spec/contracts/F-018.yaml`](contracts/F-018.yaml)
**Consolidates**: F-018, F-0187

HTTP JSON-RPC coordination server (port 4185) for multi-agent orchestration. Bearer token auth. Start/stop/status via `ag coord`.

---

## F-006: Backlog & Work Queue

**Status**: shipped | **Category**: core-workflow | **Since**: v0.40.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-006.yaml`](contracts/F-006.yaml)
**Consolidates**: F-006, F-0201, F-0202, F-0205

Ordered work queue in BACKLOG.json. `ag backlog add/list/done/move/remove`. Position 0 = current work. Enforced order: `ag implement` checks backlog position. Feature formalization promotes TODOs to features.

---

## DEV-003: Instruction File Integrity

**Status**: shipped | **Category**: dev-infrastructure | **Since**: v0.45.0 | **Profile**: both
**Type**: infrastructure | **Parent**: DEV-001
**Contract**: [`spec/contracts/DEV-003.yaml`](contracts/DEV-003.yaml)
**Consolidates**: DEV-003, F-0226

Instruction files are part of the feature. 11 locations must be updated when shipping framework features. `ag dogfood` detects template vs root drift.

---

## F-023: Hook-Based Enforcement

**Status**: shipped | **Category**: architecture | **Since**: v0.65.0 | **Profile**: both
**Contract**: [`spec/contracts/F-023.yaml`](contracts/F-023.yaml)
**Consolidates**: F-023, F-0246, F-0247, F-0248, F-0249

Claude Code hooks for automated enforcement: pre-commit checks, post-tool validation, workflow triggers. Hook installation via `ag hooks install`.

---

## F-031: Spec System Overhaul — YAML Contracts

**Status**: shipped
**Contract**: [`spec/contracts/F-031.yaml`](contracts/F-031.yaml)

YAML contracts replace markdown acceptance criteria as source of truth. Machine-verifiable assertions, migration-protected shipped contracts, user_input as control interface. Consolidates 217 legacy features into ~33 contracts.

---

## F-033: Project-Specific Customization Layer

**Status**: shipped | **Category**: developer-experience | **Profile**: both

Allow projects to define custom workflow steps, validation rules, and enforcement policies beyond STACK.md settings. Includes auto-sync engine that preserves user overrides during framework upgrades.

---

## F-035: Protected Main Branch Support

**Status**: shipped | **Category**: git-workflow | **Profile**: both

Support workflows where main branch is protected (no direct push). Adapt commit, done, and flush commands for PR-only merging.

---

## F-036: Workflow Definition File

**Status**: shipped | **Category**: architecture | **Profile**: formal

Declarative workflow.yaml defining state machine transitions, gates, and review checkpoints as data instead of code.

---

## F-037: MCP Coordination Server

**Status**: planned | **Category**: multi-agent | **Profile**: both

MCP-protocol coordination server for multi-agent orchestration. Extends beyond HTTP JSON-RPC (F-018) with tool-native integration.

---

## F-038: Multi-Repo Umbrella

**Status**: planned | **Category**: multi-agent | **Profile**: both

Coordinate work across multiple repositories with shared backlog, cross-repo dependencies, and unified status tracking.

---

## F-039: Full Autonomous Scheduling

**Status**: planned | **Category**: autonomous | **Profile**: formal

Autonomous scheduling engine that assigns work to agents based on priority, dependencies, and capacity. ADR-001 wave 5.

---

## F-040: App Store Publishing

**Status**: planned | **Category**: deployment | **Profile**: formal

Provider-based mobile app publishing (`ag publish`) with platform auto-detection, preflight validation, phased execution with state tracking, and automated screenshot generation. Supports Fastlane and custom script backends for iOS and Android.

---

## DEV-004: Complexity Tier Experiments

**Status**: shipped | **Category**: dev-infrastructure
**Type**: research | **Parent**: DEV-001
**Contract**: [`spec/contracts/DEV-004.yaml`](contracts/DEV-004.yaml)

Empirically compare framework outcomes across three real configuration profiles (discovery, formal, autonomous_formal) by running the same build task N times per tier and collecting structured metrics. Produces a comparison report showing what each tier costs (time, token spend, ceremony) and what it buys (spec coverage, test count, commit quality, violation rate). ADR-001 roadmap item.

---

## Development Infrastructure

Work tracked here uses the same `ag` workflow as capabilities — specs, plans,
ACs, shipping ceremony. These are how the framework is built and validated.
Not user-facing.

| Type | Meaning |
|------|---------|
| `infrastructure` | Permanent internal tooling (maintained indefinitely) |
| `research` | Time-bounded experiment (concludes when question is answered) |
| `meta` | Organizational container |

### DEV-001: Framework Development Infrastructure

**Status**: ongoing | **Type**: meta

Organizational parent for all framework development tooling and research.

**Children**: DEV-002, DEV-003, DEV-004
**Contract**: [`spec/contracts/DEV-001.yaml`](contracts/DEV-001.yaml)

---

## Legacy Feature Archive

The original 217 features (v0.1.0–v0.72.0) are archived at [`docs/archive/FEATURES-v0.72.md`](../../docs/archive/FEATURES-v0.72.md). Old acceptance criteria files are at [`docs/archive/acceptance/`](../../docs/archive/acceptance/). The consolidation mapping is at [`spec/CONSOLIDATION_MAP.md`](CONSOLIDATION_MAP.md).

---

## F-032: Plan-Derived Work Items

**Status**: shipped
**Category**: general
**Priority**: medium
**Complexity**: medium

**Description**: (TODO: add description)

**Implementation**:
- State: none
- Code: (TODO)
- Tests: (TODO)

**Contract**: See `spec/contracts/F-032.yaml`

---

## F-041: Intelligence Engine

**Status**: in_progress
**Category**: Core intelligence system: file anatomy, enforced patterns, quality checklists, test strategy, token ledger. Makes framework smarter than vanilla Claude through domain-specific, stack-aware guidance at every workflow phase.
**Priority**: medium
**Complexity**: medium

**Description**: (TODO: add description)

**Implementation**:
- State: none
- Code: (TODO)
- Tests: (TODO)

**Contract**: See `spec/contracts/F-041.yaml`
