# Spec Consolidation Map

**Purpose**: Maps 217 legacy features → ~35 consolidated contracts.
**Created**: 2026-03-22 (F-0302 Phase 0)

## Mapping: New Contract → Old Features Absorbed

| # | Contract ID | Name | Old Features | Count |
|---|------------|------|-------------|-------|
| 1 | F-0001 | Project Initialization & Profiles | F-0001, F-0002, F-0009, F-0123, F-0124, F-0131, F-0141 | 7 |
| 2 | F-0003 | Spec-Driven Development | F-0003, F-0005, F-0006, F-0010, F-0043, F-0117, F-0128, F-0132, F-0147, F-0148, F-0149, F-0152, F-0251 | 13 |
| 3 | F-0004 | Feature Tracking & Lifecycle | F-0004, F-0042, F-0078, F-0109, F-0110, F-0177, F-0178, F-0197 | 8 |
| 4 | F-0007 | Development Constraints | F-0007, F-0008, F-0069, F-0070, F-0072, F-0073, F-0074, F-0076, F-0209 | 9 |
| 5 | F-0011 | Code Quality Standards | F-0011, F-0012, F-0013, F-0014, F-0015, F-0116 | 6 |
| 6 | F-0016 | Pre-Commit Quality Gates | F-0016, F-0017, F-0091, F-0092, F-0114, F-0115, F-0154, F-0155, F-0229, F-0301 | 10 |
| 7 | F-0021 | Session Management | F-0021, F-0022, F-0023, F-0024, F-0025, F-0026, F-0027, F-0125, F-0126, F-0127, F-0136, F-0145, F-0156, F-0240 | 14 |
| 8 | F-0031 | Multi-Agent Coordination | F-0031, F-0032, F-0034, F-0035, F-0036, F-0037, F-0194, F-0195, F-0214, F-0250 | 10 |
| 9 | F-0041 | Token & Resource Efficiency | F-0041, F-0071, F-0102, F-0103, F-0112, F-0237, F-0238, F-0244 | 8 |
| 10 | F-0051 | Crash Recovery & Work Tracking | F-0051, F-0052, F-0053, F-0054, F-0055, F-0200 | 6 |
| 11 | F-0056 | Framework Upgrade & Versioning | F-0056, F-0068, F-0094 | 3 |
| 12 | F-0061 | Developer Documentation | F-0061, F-0062, F-0063, F-0064, F-0065, F-0066, F-0067, F-0134 | 8 |
| 13 | F-0079 | Issue & Feedback Tracking | F-0079, F-0206 | 2 |
| 14 | F-0081 | Agent System & Instructions | F-0081, F-0082, F-0083, F-0084, F-0093, F-0111, F-0113, F-0121, F-0135, F-0143, F-0146, F-0234 | 12 |
| 15 | F-0096 | Git Workflow & PR Management | F-0096, F-0097, F-0182, F-0192, F-0196, F-0235, F-0239 | 7 |
| 16 | F-0101 | Architecture Decision Records | F-0101 | 1 |
| 17 | F-0118 | Documentation Drift & Lifecycle | F-0118, F-0119, F-0138, F-0139, F-0144, F-0207 | 6 |
| 18 | F-0120 | Plan & Design Review | F-0120, F-0133, F-0150, F-0191, F-0236 | 5 |
| 19 | F-0122 | Testing Infrastructure | F-0122, F-0153, F-0171, F-0172, F-0173, F-0174, F-0175, F-0241, F-0242 | 9 |
| 20 | F-0151 | User Extensions & Customization | F-0151, F-0179, F-0183 | 3 |
| 21 | F-0157 | Framework Architecture & Paths | F-0157, F-0158, F-0159, F-0198, F-0221 | 5 |
| 22 | F-0160 | Autonomous Execution Engine | F-0160, F-0161, F-0162, F-0163, F-0164, F-0168, F-0186, F-0204, F-0215 | 9 |
| 23 | F-0169 | Non-Functional Requirements | F-0169, F-0170, F-0216, F-0217, F-0218, F-0219 | 6 |
| 24 | F-0180 | Review Checkpoint Framework | F-0180, F-0203 | 2 |
| 25 | F-0184 | Feature Hierarchy & Decomposition | F-0184 | 1 |
| 26 | F-0185 | Coordination Server | F-0185, F-0187 | 2 |
| 27 | F-0190 | Backlog & Work Queue | F-0190, F-0201, F-0202, F-0205 | 4 |
| 28 | F-0199 | Instruction File Integrity | F-0199, F-0226 | 2 |
| 29 | F-0245 | Hook-Based Enforcement | F-0245, F-0246, F-0247, F-0248, F-0249 | 5 |
| 30 | F-0302 | Spec System Overhaul — YAML Contracts | F-0302 | 1 |
| 31 | F-0095 | Cross-Platform Compatibility | F-0095 | 1 |
| 32 | F-0077 | Emergency Quick Reference | F-0077 | 1 |
| 33 | F-0181 | Autonomous Formal Profile | F-0181 | 1 |

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

## Planned Features (evaluate for backlog vs drop)

| Feature | Decision |
|---------|----------|
| F-0193 | Collision-Proof Feature IDs — keep in backlog |
| F-0210 | Configurable Definition of Done — keep in backlog |
| F-0211 | Project-Specific Customization Layer — keep in backlog |
| F-0212 | Project Customization Auto-Sync — keep in backlog |
| F-0213 | Unified Work Queue Redesign — merge into F-0302 scope |
| F-0220 | Protected Main Branch — keep in backlog |
| F-0223 | Later State Machine Gates — keep in backlog |
| F-0227 | E2E Workflow Integration Test — keep in backlog |
| F-0228 | Workflow Definition File — keep in backlog |
| F-0230 | MCP Coordination Server — keep in backlog |
| F-0231 | Multi-Repo Umbrella — keep in backlog |
| F-0232 | Full Autonomous Scheduling — keep in backlog |
| F-0233 | Design Phase Formalization — keep in backlog |
| F-0243 | Complexity Tier Experiments — keep in backlog |
