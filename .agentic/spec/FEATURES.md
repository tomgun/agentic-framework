# Agentic AI Framework - Feature Specification

<!-- format: features-v1.0.0 -->

**Purpose**: Define what the Agentic AI Framework can reliably do. Each feature has a YAML contract in `spec/contracts/`.

**Version**: 0.72.0

---

## Feature Categories

| Category | Count | Shipped | In Progress |
|----------|-------|---------|-------------|
| **Core Workflow** | 7 | 6 | 1 |
| **Quality** | 7 | 7 | 0 |
| **Design Principles** | 1 | 1 | 0 |
| **Session** | 1 | 1 | 0 |
| **Multi-Agent** | 2 | 2 | 0 |
| **Tooling** | 2 | 2 | 0 |
| **Recovery** | 1 | 1 | 0 |
| **Developer Experience** | 3 | 3 | 0 |
| **Agent System** | 2 | 2 | 0 |
| **Architecture** | 3 | 3 | 0 |
| **Git Workflow** | 1 | 1 | 0 |
| **Autonomous** | 2 | 2 | 0 |
| **Total** | **33** | **32** | **1** |

---

## F-0001: Project Initialization & Profiles

**Status**: shipped | **Category**: core-workflow | **Since**: v0.1.0 | **Profile**: both
**Contract**: [`spec/contracts/F-0001.yaml`](contracts/F-0001.yaml)
**Consolidates**: F-0001, F-0002, F-0009, F-0123, F-0124, F-0131, F-0141

Initialize new projects with Discovery or Formal profiles. Settings in STACK.md control behavior — profiles are preset bundles. Existing projects get intelligent onboarding with domain discovery.

---

## F-0003: Spec-Driven Development

**Status**: shipped | **Category**: core-workflow | **Since**: v0.1.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-0003.yaml`](contracts/F-0003.yaml)
**Consolidates**: F-0003, F-0005, F-0006, F-0010, F-0043, F-0117, F-0128, F-0132, F-0147, F-0148, F-0149, F-0152, F-0251

Formal-profile projects manage features through YAML contract specifications with testable acceptance criteria. Features have lifecycle states, enforcement gates, and migration-protected shipped contracts.

---

## F-0004: Feature Tracking & Lifecycle

**Status**: shipped | **Category**: core-workflow | **Since**: v0.1.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-0004.yaml`](contracts/F-0004.yaml)
**Consolidates**: F-0004, F-0042, F-0078, F-0109, F-0110, F-0177, F-0178, F-0197

State machine manages feature lifecycle from planned through shipped. Transitions are gated, with forward/regression/skip rules. Feature categories, priorities, and complexity tracked in FEATURES.md.

---

## F-0007: Development Constraints & Principles

**Status**: shipped | **Category**: design-principles | **Since**: v0.1.0 | **Profile**: both
**Contract**: [`spec/contracts/F-0007.yaml`](contracts/F-0007.yaml)
**Consolidates**: F-0007, F-0008, F-0069, F-0070, F-0072, F-0073, F-0074, F-0076, F-0209

Enforced development principles: small batches, one feature at a time, spec before code, tests alongside code. Structural tests verify principle adherence.

---

## F-0011: Code Quality Standards

**Status**: shipped | **Category**: quality | **Since**: v0.2.0 | **Profile**: both
**Contract**: [`spec/contracts/F-0011.yaml`](contracts/F-0011.yaml)
**Consolidates**: F-0011, F-0012, F-0013, F-0014, F-0015, F-0116

Consistent code quality across shell and Python: ShellCheck, error handling patterns, naming conventions, function documentation. Structural tests verify standards.

---

## F-0016: Pre-Commit Quality Gates

**Status**: shipped | **Category**: quality | **Since**: v0.2.0 | **Profile**: both
**Contract**: [`spec/contracts/F-0016.yaml`](contracts/F-0016.yaml)
**Consolidates**: F-0016, F-0017, F-0091, F-0092, F-0114, F-0115, F-0154, F-0155, F-0229, F-0301

Pre-commit hooks enforce quality: ShellCheck, spec consistency, file size limits, state file freshness. Git hooks installed automatically during init.

---

## F-0021: Session Management

**Status**: shipped | **Category**: session | **Since**: v0.3.0 | **Profile**: both
**Contract**: [`spec/contracts/F-0021.yaml`](contracts/F-0021.yaml)
**Consolidates**: F-0021, F-0022, F-0023, F-0024, F-0025, F-0026, F-0027, F-0125, F-0126, F-0127, F-0136, F-0145, F-0156, F-0240

Session start shows dashboard with status, focus, health, and next steps. Context packs provide efficient handoff between sessions. TODO capture, journal entries, and status tracking persist across sessions.

---

## F-0031: Multi-Agent Coordination

**Status**: shipped | **Category**: multi-agent | **Since**: v0.5.0 | **Profile**: both
**Contract**: [`spec/contracts/F-0031.yaml`](contracts/F-0031.yaml)
**Consolidates**: F-0031, F-0032, F-0034, F-0035, F-0036, F-0037, F-0194, F-0195, F-0214, F-0250

Multiple agents work on same project safely via AGENTS.json tracking, git worktrees for isolation, collision detection before destructive operations, and lock-free coordination protocols.

---

## F-0041: Token & Resource Efficiency

**Status**: shipped | **Category**: tooling | **Since**: v0.4.0 | **Profile**: both
**Contract**: [`spec/contracts/F-0041.yaml`](contracts/F-0041.yaml)
**Consolidates**: F-0041, F-0071, F-0102, F-0103, F-0112, F-0237, F-0238, F-0244

Token-efficient scripts for state file updates (journal.sh, status.sh, feature.sh, etc.) — agents call scripts instead of editing files directly. Subagent context packs minimize token waste.

---

## F-0051: Crash Recovery & Work Tracking

**Status**: shipped | **Category**: recovery | **Since**: v0.4.0 | **Profile**: both
**Contract**: [`spec/contracts/F-0051.yaml`](contracts/F-0051.yaml)
**Consolidates**: F-0051, F-0052, F-0053, F-0054, F-0055, F-0200

Session start detects interrupted work via AGENTS.json. Recovery shows what was in progress, uncommitted changes, and resume path. Intent journal tracks orphaned operations.

---

## F-0056: Framework Upgrade & Versioning

**Status**: shipped | **Category**: tooling | **Since**: v0.5.0 | **Profile**: both
**Contract**: [`spec/contracts/F-0056.yaml`](contracts/F-0056.yaml)
**Consolidates**: F-0056, F-0068, F-0094

VERSION file tracks framework version. upgrade.sh handles version bumps with backward compatibility. Semantic versioning with changelog.

---

## F-0061: Developer Documentation

**Status**: shipped | **Category**: developer-experience | **Since**: v0.5.0 | **Profile**: both
**Contract**: [`spec/contracts/F-0061.yaml`](contracts/F-0061.yaml)
**Consolidates**: F-0061, F-0062, F-0063, F-0064, F-0065, F-0066, F-0067, F-0134

DEVELOPER_GUIDE.md, HOW_IT_WORKS.md, FRAMEWORK_DEVELOPMENT.md, and other docs explain the framework for users and contributors. Documentation is code — updated alongside features.

---

## F-0077: Emergency Quick Reference

**Status**: shipped | **Category**: developer-experience | **Since**: v0.6.0 | **Profile**: both
**Contract**: [`spec/contracts/F-0077.yaml`](contracts/F-0077.yaml)
**Consolidates**: F-0077

EMERGENCY.md provides quick-reference for common recovery scenarios (stuck builds, merge conflicts, agent crashes).

---

## F-0079: Issue & Feedback Tracking

**Status**: shipped | **Category**: quality | **Since**: v0.6.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-0079.yaml`](contracts/F-0079.yaml)
**Consolidates**: F-0079, F-0206

ISSUES.md tracks bugs and tech debt. FEEDBACK_LOG.md captures user feedback. Both integrated into session start awareness.

---

## F-0081: Agent System & Instructions

**Status**: shipped | **Category**: agent-system | **Since**: v0.6.0 | **Profile**: both
**Contract**: [`spec/contracts/F-0081.yaml`](contracts/F-0081.yaml)
**Consolidates**: F-0081, F-0082, F-0083, F-0084, F-0093, F-0111, F-0113, F-0121, F-0135, F-0143, F-0146, F-0234

Three-layer instruction architecture (Constitution → Playbooks → State). Multi-tool agent support (Claude, Cursor, Copilot, Codex). Skills provide just-in-time guidance. Memory seed bootstraps agent knowledge.

---

## F-0095: Cross-Platform Compatibility

**Status**: shipped | **Category**: architecture | **Since**: v0.8.0 | **Profile**: both
**Contract**: [`spec/contracts/F-0095.yaml`](contracts/F-0095.yaml)
**Consolidates**: F-0095

Framework works on macOS and Linux. Shell scripts use portable constructs. Path resolution handles both platforms.

---

## F-0096: Git Workflow & PR Management

**Status**: shipped | **Category**: git-workflow | **Since**: v0.8.0 | **Profile**: both
**Contract**: [`spec/contracts/F-0096.yaml`](contracts/F-0096.yaml)
**Consolidates**: F-0096, F-0097, F-0182, F-0192, F-0196, F-0235, F-0239

Feature branches, PR creation, commit gates, and merge workflow. HUMAN_NEEDED.md tracks PRs awaiting review. Worktree-based isolation for parallel work.

---

## F-0101: Architecture Decision Records

**Status**: shipped | **Category**: quality | **Since**: v0.8.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-0101.yaml`](contracts/F-0101.yaml)
**Consolidates**: F-0101

ADR directory tracks architectural decisions with status, context, and consequences.

---

## F-0118: Documentation Drift & Lifecycle

**Status**: shipped | **Category**: quality | **Since**: v0.10.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-0118.yaml`](contracts/F-0118.yaml)
**Consolidates**: F-0118, F-0119, F-0138, F-0139, F-0144, F-0207

drift.sh detects stale documentation. docs.sh manages doc registry in STACK.md. Doc lifecycle integrated into feature shipping: spec + code + tests + docs = done.

---

## F-0120: Plan & Design Review

**Status**: shipped | **Category**: core-workflow | **Since**: v0.10.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-0120.yaml`](contracts/F-0120.yaml)
**Consolidates**: F-0120, F-0133, F-0150, F-0191, F-0236

Dialectical plan review: Critic + Advocate agents evaluate plans in fresh context. Plans saved to journal/plans/ with DRAFT/APPROVED/REJECTED status. Convergence modes: auto or manual.

---

## F-0122: Testing Infrastructure

**Status**: shipped | **Category**: quality | **Since**: v0.10.0 | **Profile**: both
**Contract**: [`spec/contracts/F-0122.yaml`](contracts/F-0122.yaml)
**Consolidates**: F-0122, F-0153, F-0171, F-0172, F-0173, F-0174, F-0175, F-0241, F-0242

validate_framework.sh (structural tests), LLM behavioral tests, QA registry mapping features to tests, spec-code traceability. Framework verification at multiple layers.

---

## F-0151: User Extensions & Customization

**Status**: shipped | **Category**: developer-experience | **Since**: v0.15.0 | **Profile**: both
**Contract**: [`spec/contracts/F-0151.yaml`](contracts/F-0151.yaml)
**Consolidates**: F-0151, F-0179, F-0183

Component registry, user-defined extensions, project-specific customizations via STACK.md settings.

---

## F-0157: Framework Architecture & Paths

**Status**: shipped | **Category**: architecture | **Since**: v0.20.0 | **Profile**: both
**Contract**: [`spec/contracts/F-0157.yaml`](contracts/F-0157.yaml)
**Consolidates**: F-0157, F-0158, F-0159, F-0198, F-0221

Central path resolver (paths.py/paths.sh) with backward-compatible dual-location support. Directory structure: .agentic/lib/ (code), .agentic/spec/ (specs), .agentic/session/ (ephemeral), .agentic/journal/ (history).

---

## F-0160: Autonomous Execution Engine

**Status**: shipped | **Category**: autonomous | **Since**: v0.30.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-0160.yaml`](contracts/F-0160.yaml)
**Consolidates**: F-0160, F-0161, F-0162, F-0163, F-0164, F-0168, F-0186, F-0204, F-0215

VerifyLoop engine executes acceptance criteria autonomously: load ACs → implement → verify → repeat. Supports task-level and epic-level autonomous execution. Feedback mechanism for mid-flight corrections.

---

## F-0169: Non-Functional Requirements

**Status**: shipped | **Category**: quality | **Since**: v0.25.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-0169.yaml`](contracts/F-0169.yaml)
**Consolidates**: F-0169, F-0170, F-0216, F-0217, F-0218, F-0219

NFR.md tracks cross-cutting quality requirements. NFR assertions verified structurally. `ag nfr discover` suggests NFRs from project patterns. NFR coverage tracked per feature.

---

## F-0180: Review Checkpoint Framework

**Status**: shipped | **Category**: quality | **Since**: v0.30.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-0180.yaml`](contracts/F-0180.yaml)
**Consolidates**: F-0180, F-0203

Configurable review checkpoints: human, critical_agent, or skip. Controls for plan review, code review, regression review, merge review, commit review. Critical agent provides automated review for autonomous workflows.

---

## F-0181: Autonomous Formal Profile

**Status**: shipped | **Category**: autonomous | **Since**: v0.30.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-0181.yaml`](contracts/F-0181.yaml)
**Consolidates**: F-0181

autonomous_formal profile: formal rigor with review_code and review_regression delegated to critical_agent. Only review_merge stays human. Enables autonomous execution with quality guarantees.

---

## F-0184: Feature Hierarchy & Decomposition

**Status**: shipped | **Category**: core-workflow | **Since**: v0.30.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-0184.yaml`](contracts/F-0184.yaml)
**Consolidates**: F-0184

`ag decompose` breaks epics into child features by component. Parent-child relationships tracked. review_decomposition checkpoint validates decomposition quality.

---

## F-0185: Coordination Server

**Status**: shipped | **Category**: multi-agent | **Since**: v0.35.0 | **Profile**: both
**Contract**: [`spec/contracts/F-0185.yaml`](contracts/F-0185.yaml)
**Consolidates**: F-0185, F-0187

HTTP JSON-RPC coordination server (port 4185) for multi-agent orchestration. Bearer token auth. Start/stop/status via `ag coord`.

---

## F-0190: Backlog & Work Queue

**Status**: shipped | **Category**: core-workflow | **Since**: v0.40.0 | **Profile**: formal
**Contract**: [`spec/contracts/F-0190.yaml`](contracts/F-0190.yaml)
**Consolidates**: F-0190, F-0201, F-0202, F-0205

Ordered work queue in BACKLOG.json. `ag backlog add/list/done/move/remove`. Position 0 = current work. Enforced order: `ag implement` checks backlog position. Feature formalization promotes TODOs to features.

---

## F-0199: Instruction File Integrity

**Status**: shipped | **Category**: agent-system | **Since**: v0.45.0 | **Profile**: both
**Contract**: [`spec/contracts/F-0199.yaml`](contracts/F-0199.yaml)
**Consolidates**: F-0199, F-0226

Instruction files are part of the feature. 11 locations must be updated when shipping framework features. `ag dogfood` detects template vs root drift.

---

## F-0245: Hook-Based Enforcement

**Status**: shipped | **Category**: architecture | **Since**: v0.65.0 | **Profile**: both
**Contract**: [`spec/contracts/F-0245.yaml`](contracts/F-0245.yaml)
**Consolidates**: F-0245, F-0246, F-0247, F-0248, F-0249

Claude Code hooks for automated enforcement: pre-commit checks, post-tool validation, workflow triggers. Hook installation via `ag hooks install`.

---

## F-0302: Spec System Overhaul — YAML Contracts

**Status**: shipped
**Contract**: [`spec/contracts/F-0302.yaml`](contracts/F-0302.yaml)

YAML contracts replace markdown acceptance criteria as source of truth. Machine-verifiable assertions, migration-protected shipped contracts, user_input as control interface. Consolidates 217 legacy features into ~33 contracts.

---

## Legacy Feature Archive

The original 217 features (v0.1.0–v0.72.0) are archived at [`docs/archive/FEATURES-v0.72.md`](../../docs/archive/FEATURES-v0.72.md). Old acceptance criteria files are at [`docs/archive/acceptance/`](../../docs/archive/acceptance/). The consolidation mapping is at [`spec/CONSOLIDATION_MAP.md`](CONSOLIDATION_MAP.md).

---

## F-0303: Plan-Derived Work Items

**Status**: implementing
**Category**: general
**Priority**: medium
**Complexity**: medium

**Description**: (TODO: add description)

**Implementation**:
- State: none
- Code: (TODO)
- Tests: (TODO)

**Contract**: See `spec/contracts/F-0303.yaml`
