# STATUS.md

<!-- format: status-v0.1.0 -->

Purpose: the living "truth" of where the Agentic Framework development is today.

## Current session state
- F-033 shipped. Next: F-034 Project Customization Auto-Sync (Updated: 2026-03-28 20:58 UTC)

## Current focus
- **F-031: Spec System Overhaul — YAML Contracts (HIGH PRIORITY, MULTI-SESSION)**
  - Phase 1 DONE: contract infrastructure (parser, ag contract, verify-contracts.sh, pre-commit, tests)
  - Phase 0 NEXT: Consolidate 217 features → ~30-40 contracts (triage + classification)
  - Phase 2: Write YAML contracts for each consolidated feature
  - Phase 3: Switchover all ag commands, engine, paths to use contracts
  - Phase 4: Protection enforcement, V2 cleanup
  - Phase 5: User project support (templates, migration tool)
  - Plan: `.agentic/work/F-031/plan.md`

## In progress
- F-031: Spec System Overhaul — Phase 1 complete, 5 phases remaining

## Next up (after F-031)
- DEV-004: Complexity Tier Experiments
- F-0223: Later State Machine Gates Strengthening
- F-035: Protected Main Branch Support

## Known issues / risks
- Some CHANGELOG.md historical references point to old file locations (acceptable)

## Decisions needed
- None currently

## Release notes (optional)
- v0.58.0: F-0239 structural enforcement for post-merge workflow
- See CHANGELOG.md for full history
- QA: QA: 0/1 verified, 10 pending
