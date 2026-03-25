# Feature ID Migration — v0.73 → v0.74

**Date**: 2026-03-25
**Feature**: F-0184 (now F-005) — Feature Hierarchy & Decomposition, Phase 2

All live feature IDs were renumbered from 4-digit chronological (F-0001–F-0303) to 3-digit sequential (F-001–F-039) grouped by category. Machine-readable mapping at `.agentic/lib/tools/renumber_mapping.json`.

## Mapping

### Core Workflow (F-001 – F-006)

| Old ID | New ID | Name |
|--------|--------|------|
| F-0001 | F-001 | Project Initialization & Profiles |
| F-0003 | F-002 | Spec-Driven Development |
| F-0004 | F-003 | Feature Tracking & Lifecycle |
| F-0120 | F-004 | Plan & Design Review |
| F-0184 | F-005 | Feature Hierarchy & Decomposition |
| F-0190 | F-006 | Backlog & Work Queue |

### Quality (F-007 – F-014)

| Old ID | New ID | Name |
|--------|--------|------|
| F-0007 | F-007 | Development Constraints & Principles |
| F-0011 | F-008 | Code Quality Standards |
| F-0016 | F-009 | Pre-Commit Quality Gates |
| F-0079 | F-010 | Issue & Feedback Tracking |
| F-0101 | F-011 | Architecture Decision Records |
| F-0118 | F-012 | Documentation Drift & Lifecycle |
| F-0169 | F-013 | Non-Functional Requirements |
| F-0180 | F-014 | Review Checkpoint Framework |

### Session & Recovery (F-015 – F-016)

| Old ID | New ID | Name |
|--------|--------|------|
| F-0021 | F-015 | Session Management |
| F-0051 | F-016 | Crash Recovery & Work Tracking |

### Multi-Agent (F-017 – F-018)

| Old ID | New ID | Name |
|--------|--------|------|
| F-0031 | F-017 | Multi-Agent Coordination |
| F-0185 | F-018 | Coordination Server |

### Tooling & Architecture (F-019 – F-024)

| Old ID | New ID | Name |
|--------|--------|------|
| F-0041 | F-019 | Token & Resource Efficiency |
| F-0056 | F-020 | Framework Upgrade & Versioning |
| F-0095 | F-021 | Cross-Platform Compatibility |
| F-0157 | F-022 | Framework Architecture & Paths |
| F-0245 | F-023 | Hook-Based Enforcement |
| F-0096 | F-024 | Git Workflow & PR Management |

### Agent & Developer Experience (F-025 – F-029)

| Old ID | New ID | Name |
|--------|--------|------|
| F-0081 | F-025 | Agent System & Instructions |
| F-0061 | F-026 | Developer Documentation |
| F-0077 | F-027 | Emergency Quick Reference |
| F-0151 | F-028 | User Extensions & Customization |
| F-0181 | F-029 | Autonomous Formal Profile |

### Autonomous & Spec (F-030 – F-032)

| Old ID | New ID | Name |
|--------|--------|------|
| F-0160 | F-030 | Autonomous Execution Engine |
| F-0302 | F-031 | Spec System Overhaul — YAML Contracts |
| F-0303 | F-032 | Plan-Derived Work Items |

### Planned (F-033 – F-039)

| Old ID | New ID | Name |
|--------|--------|------|
| F-0211 | F-033 | Project-Specific Customization Layer |
| F-0212 | F-034 | Project Customization Auto-Sync |
| F-0220 | F-035 | Protected Main Branch Support |
| F-0228 | F-036 | Workflow Definition File |
| F-0230 | F-037 | MCP Coordination Server |
| F-0231 | F-038 | Multi-Repo Umbrella |
| F-0232 | F-039 | Full Autonomous Scheduling |

### Dev Infrastructure (DEV-001 – DEV-004)

| Old ID | New ID | Name |
|--------|--------|------|
| DEV-0001 | DEV-001 | Framework Development Infrastructure |
| DEV-0122 | DEV-002 | Testing Infrastructure |
| DEV-0199 | DEV-003 | Instruction File Integrity |
| DEV-0243 | DEV-004 | Complexity Tier Experiments |

## What was NOT renamed

- **NFR IDs**: NFR-0001, NFR-0003, NFR-0004 — separate namespace, unchanged
- **`consolidated_from` entries**: Dead IDs (F-0042, F-0078, etc.) in contract YAML — historical tombstones
- **`docs/archive/`**: Historical snapshots preserved as-is
- **`.agentic/journal/`**: Historical plan and journal entries
- **Git commit history**: Cannot change existing commits
