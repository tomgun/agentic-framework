# Spec System Overhaul — Final Plan

**Status**: APPROVED
**Feature**: F-0302
**Created**: 2026-03-22
**Estimated sessions**: 13-18

## Summary

Replace markdown acceptance criteria with YAML contract specifications. Consolidate 217 features → ~30-40 with machine-verifiable assertions, migration-protected shipped contracts, and a `user_input` field making specs the control interface.

## Phase Progress

- [x] **Phase 1: Contract Infrastructure** (2 sessions → DONE in 1)
  - contract.schema.json, contracts.py, ag contract command (12 subcommands)
  - verify-contracts.sh, pre-commit Check 23, paths integration
  - 42 unit tests + 7 validate_framework checks
- [ ] **Phase 0: Feature Consolidation & Triage** (2-3 sessions)
  - Walk 217 features, classify as Core/Enforcement/Implementation Detail/Deprecated/Design Constraint/Planned
  - Produce ~30-40 consolidated feature list with draft assertion lists
  - Prune planned features, produce spec/CONSOLIDATION_MAP.md
- [ ] **Phase 2: Contract Writing** (4-6 sessions)
  - Write YAML contracts for each consolidated feature
  - Map test-AC bidirectional traceability
  - Migrate validate_framework.sh assertions into contract verify commands
  - Implement user_input processing workflow
- [ ] **Phase 3: The Switchover** (2-3 sessions)
  - Archive old files (acceptance/, old FEATURES.md)
  - Update path resolution, state machine, all ag commands
  - Update ~50 shell scripts, ~35 Python modules, tests
  - Update all 11 instruction file locations
- [ ] **Phase 4: Protection & V2 Cleanup** (2 sessions)
  - Contract protection enforcement in pre-commit + ag verify
  - User input automation (ag start surfaces pending)
  - V2 dead code cleanup, stale planned feature cleanup
- [ ] **Phase 5: User Project Support** (1-2 sessions)
  - Contract templates in scaffold.sh
  - ag migrate-specs command for existing projects
  - Documentation updates

## Contract Format

```yaml
id: F-XXXX
name: Feature Name
lifecycle: shipped  # exploring|specifying|implementing|verifying|shipping|shipped|deprecated
protection: contract  # contract|advisory|none
assertions:
  - id: AC-001
    text: "What must be true"
    type: structural  # structural|behavioral
    verify: "shell command exits 0 if true"
    tests: [test/file.py::test_name]
user_input: ""  # Non-empty = pending change request
migrations:
  - id: M-YYYY-MM-DD-NNN
    trigger: external|implementation_discovery|user_request
    reason: "Why"
    changes: ["AC-XXX: what changed"]
```

## Design Decisions

- D1: Machine-first (scripts write YAML, not agents directly)
- D2: Unified state machine (contract lifecycle = state machine states)
- D3: Tasks in plan files, not contracts (contracts = permanent spec, tasks = process)
- D4: One-go migration, small verifiable phases (no dual systems)
- D5: NFRs as cross-cutting contracts (spec/contracts/NFR-XXXX.yaml)
- D6: Minimal valid contract (only id, name, lifecycle, description, 1 assertion required)

## Critical Files

- `.agentic/spec/FEATURES.md` — Rewrite with ~30-40 entries (Phase 3)
- `.agentic/spec/acceptance/` — Archive to docs/archive/ (Phase 3)
- `.agentic/spec/contracts/` — YAML contracts (Phase 2)
- `.agentic/lib/contracts.py` — Parser/validator (Phase 1 ✅)
- `.agentic/lib/paths.py` / `paths.sh` — contracts_dir (Phase 1 ✅)
- `.agentic/lib/tools/commands/contract.sh` — ag contract (Phase 1 ✅)
- `.agentic/lib/tools/verify-contracts.sh` — Verification runner (Phase 1 ✅)
- `.agentic/lib/hooks/pre-commit-check.sh` — Contract protection (Phase 1 ✅)
