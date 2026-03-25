# Spec Consolidation Map

**Purpose**: Maps 217 legacy features → ~35 consolidated contracts.
**Created**: 2026-03-22 (F-031 Phase 0)

## Mapping: New Contract → Old Features Absorbed

| # | Contract ID | Name | Old Features | Count |
|---|------------|------|-------------|-------|
| 1 | F-001 | Project Initialization & Profiles | F-001, F-0002, F-0009, F-0123, F-0124, F-0131, F-0141 | 7 |
| 2 | F-002 | Spec-Driven Development | F-002, F-0005, F-0006, F-0010, F-0043, F-0117, F-0128, F-0132, F-0147, F-0148, F-0149, F-0152, F-0251 | 13 |
| 3 | F-003 | Feature Tracking & Lifecycle | F-003, F-0042, F-0078, F-0109, F-0110, F-0177, F-0178, F-0197 | 8 |
| 4 | F-007 | Development Constraints | F-007, F-0008, F-0069, F-0070, F-0072, F-0073, F-0074, F-0076, F-0209 | 9 |
| 5 | F-008 | Code Quality Standards | F-008, F-0012, F-0013, F-0014, F-0015, F-0116 | 6 |
| 6 | F-009 | Pre-Commit Quality Gates | F-009, F-0017, F-0091, F-0092, F-0114, F-0115, F-0154, F-0155, F-0229, F-0301 | 10 |
| 7 | F-015 | Session Management | F-015, F-0022, F-0023, F-0024, F-0025, F-0026, F-0027, F-0125, F-0126, F-0127, F-0136, F-0145, F-0156, F-0240 | 14 |
| 8 | F-017 | Multi-Agent Coordination | F-017, F-0032, F-0034, F-0035, F-0036, F-0037, F-0194, F-0195, F-0214, F-0250 | 10 |
| 9 | F-019 | Token & Resource Efficiency | F-019, F-0071, F-0102, F-0103, F-0112, F-0237, F-0238, F-0244 | 8 |
| 10 | F-016 | Crash Recovery & Work Tracking | F-016, F-0052, F-0053, F-0054, F-0055, F-0200 | 6 |
| 11 | F-020 | Framework Upgrade & Versioning | F-020, F-0068, F-0094 | 3 |
| 12 | F-026 | Developer Documentation | F-026, F-0062, F-0063, F-0064, F-0065, F-0066, F-0067, F-0134 | 8 |
| 13 | F-010 | Issue & Feedback Tracking | F-010, F-0206 | 2 |
| 14 | F-025 | Agent System & Instructions | F-025, F-0082, F-0083, F-0084, F-0093, F-0111, F-0113, F-0121, F-0135, F-0143, F-0146, F-0234 | 12 |
| 15 | F-024 | Git Workflow & PR Management | F-024, F-0097, F-0182, F-0192, F-0196, F-0235, F-0239 | 7 |
| 16 | F-011 | Architecture Decision Records | F-011 | 1 |
| 17 | F-012 | Documentation Drift & Lifecycle | F-012, F-0119, F-0138, F-0139, F-0144, F-0207 | 6 |
| 18 | F-004 | Plan & Design Review | F-004, F-0133, F-0150, F-0191, F-0236 | 5 |
| 19 | DEV-002 | Testing Infrastructure | DEV-002, F-0153, F-0171, F-0172, F-0173, F-0174, F-0175, F-0241, F-0242 | 9 |
| 20 | F-028 | User Extensions & Customization | F-028, F-0179, F-0183 | 3 |
| 21 | F-022 | Framework Architecture & Paths | F-022, F-0158, F-0159, F-0198, F-0221 | 5 |
| 22 | F-030 | Autonomous Execution Engine | F-030, F-0161, F-0162, F-0163, F-0164, F-0168, F-0186, F-0204, F-0215 | 9 |
| 23 | F-013 | Non-Functional Requirements | F-013, F-0170, F-0216, F-0217, F-0218, F-0219 | 6 |
| 24 | F-014 | Review Checkpoint Framework | F-014, F-0203 | 2 |
| 25 | F-005 | Feature Hierarchy & Decomposition | F-005 | 1 |
| 26 | F-018 | Coordination Server | F-018, F-0187 | 2 |
| 27 | F-006 | Backlog & Work Queue | F-006, F-0201, F-0202, F-0205 | 4 |
| 28 | DEV-003 | Instruction File Integrity | DEV-003, F-0226 | 2 |
| 29 | F-023 | Hook-Based Enforcement | F-023, F-0246, F-0247, F-0248, F-0249 | 5 |
| 30 | F-031 | Spec System Overhaul — YAML Contracts | F-031 | 1 |
| 31 | F-021 | Cross-Platform Compatibility | F-021 | 1 |
| 32 | F-027 | Emergency Quick Reference | F-027 | 1 |
| 33 | F-029 | Autonomous Formal Profile | F-029 | 1 |

**Total**: 33 consolidated contracts absorbing 217 features

## Deprecated Features (archive only)

| Feature | Reason |
|---------|--------|
| F-0028 | Continue-Here Generator — superseded by CONTEXT_PACK |
| F-0033 | AGENTS_ACTIVE.md — superseded by F-0194 AGENTS.json |
| F-0098 | Generate Skills from Subagents — superseded by F-0143 hand-crafted skills |
| F-0106 | (if exists) — check status |
| F-0107 | (if exists) — check status |
| F-0108 | (if exists) — check status |

## Planned Features (post-consolidation cleanup, 2026-03-23)

### Kept as Features (9) — added to FEATURES.md as planned
| Feature | Status |
|---------|--------|
| F-0193 | Collision-Proof Feature IDs — consolidated into F-003 (Feature Tracking & Lifecycle) |
| F-033 | Project-Specific Customization Layer — in backlog |
| F-034 | Project Customization Auto-Sync — in backlog (depends F-033) |
| F-035 | Protected Main Branch Support — in backlog, needs fresh plan |
| F-036 | Workflow Definition File — in backlog |
| F-037 | MCP Coordination Server — in backlog (ADR-001 wave 5) |
| F-038 | Multi-Repo Umbrella — in backlog (ADR-001 wave 5) |
| F-039 | Full Autonomous Scheduling — in backlog (ADR-001 wave 5) |
| DEV-004 | Complexity Tier Experiments — in backlog (ADR-001 roadmap) |

### Converted to Tasks (4) — improvements to existing shipped features
| Original ID | Task Description | Owner Feature |
|-------------|-----------------|---------------|
| F-0223 | Strengthen later state machine gates (advisory→blocking) | F-003 |
| F-0210 | Configurable Definition of Done per task type | F-002 |
| F-0227 | E2E workflow integration test (full lifecycle) | DEV-002 |
| F-0233 | Design phase formalization | F-004 |

### Dropped (1)
| Feature | Reason |
|---------|--------|
| F-0213 | Unified Work Queue Redesign — subsumed by F-031 (shipped). Explicitly marked "merge into F-031 scope" above. |
