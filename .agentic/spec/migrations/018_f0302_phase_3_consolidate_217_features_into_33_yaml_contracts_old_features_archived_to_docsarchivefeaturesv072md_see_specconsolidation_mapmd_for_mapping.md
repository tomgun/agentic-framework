<!-- migration-id: 018 -->
<!-- date: 2026-03-22 -->
<!-- author: Tomas Günther -->
<!-- type: feature -->

# Migration 018: F-0302 Phase 3 — Consolidate 217 Features into 33 YAML Contracts

## Context & Why

The spec system overhaul (F-0302) consolidates 217 legacy features into 33 YAML
contracts. Old features are absorbed into consolidated contracts — they aren't
deleted, they're merged. The consolidation mapping is at `spec/CONSOLIDATION_MAP.md`.
Old FEATURES.md archived at `docs/archive/FEATURES-v0.72.md`.

## Changes

### Features Consolidated (shipped → absorbed into parent contract)

The following shipped features are consolidated into 33 parent contracts.
See `spec/CONSOLIDATION_MAP.md` for the full old→new mapping.

- F-0001, F-0002, F-0003, F-0004, F-0005, F-0006, F-0007, F-0008, F-0009, F-0010
- F-0011, F-0012, F-0013, F-0014, F-0015, F-0016, F-0017
- F-0021, F-0022, F-0023, F-0024, F-0025, F-0026, F-0027
- F-0031, F-0032, F-0034, F-0035, F-0036, F-0037
- F-0041, F-0042, F-0043, F-0044
- F-0051, F-0052, F-0053, F-0054, F-0055, F-0056
- F-0061, F-0062, F-0063, F-0064, F-0065, F-0066, F-0067, F-0068
- F-0069, F-0070, F-0071, F-0072, F-0073, F-0074, F-0075, F-0076, F-0077, F-0078
- F-0079, F-0080, F-0081, F-0082, F-0083, F-0084
- F-0091, F-0092, F-0093, F-0094, F-0095, F-0096, F-0097, F-0098
- F-0101, F-0102, F-0103
- F-0109, F-0110, F-0111, F-0112, F-0113, F-0114, F-0115, F-0116, F-0117
- F-0118, F-0119, F-0120, F-0121, F-0122, F-0123, F-0124, F-0125, F-0126, F-0127, F-0128
- F-0130, F-0131, F-0132, F-0133, F-0134, F-0135, F-0136
- F-0138, F-0139, F-0140, F-0141, F-0143, F-0144, F-0145, F-0146, F-0147, F-0148, F-0149, F-0150
- F-0151, F-0152, F-0153, F-0154, F-0155, F-0156, F-0157, F-0158, F-0159
- F-0160, F-0161, F-0162, F-0163, F-0164, F-0168, F-0169, F-0170
- F-0171, F-0172, F-0173, F-0174, F-0175, F-0176, F-0177, F-0178, F-0179
- F-0180, F-0181, F-0182, F-0183, F-0184, F-0185, F-0186, F-0187, F-0188, F-0189
- F-0190, F-0191, F-0192, F-0193, F-0194, F-0195, F-0196, F-0197, F-0198, F-0199
- F-0200, F-0201, F-0202, F-0203, F-0204, F-0205, F-0206, F-0207, F-0208, F-0209
- F-0214, F-0215, F-0216, F-0217, F-0218, F-0219
- F-0221, F-0222, F-0223, F-0224, F-0225, F-0226, F-0229
- F-0234, F-0235, F-0236, F-0237, F-0238, F-0239, F-0240, F-0241, F-0242, F-0244
- F-0245, F-0246, F-0247, F-0248, F-0249, F-0250, F-0251
- F-0300, F-0301

### Features Deprecated

- F-0028: Continue-Here Generator — superseded by CONTEXT_PACK
- F-0033: AGENTS_ACTIVE.md — superseded by AGENTS.json (F-0194)
- F-0098: Generate Skills from Subagents — superseded by hand-crafted skills (F-0143)

## Rollback Plan

1. `git mv docs/archive/acceptance .agentic/spec/acceptance`
2. `git checkout HEAD~1 -- .agentic/spec/FEATURES.md`
3. Revert all path/command changes
