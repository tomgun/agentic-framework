# NFR (Non-Functional Requirements)

<!-- format: nfr-v0.1.0 -->

Purpose: capture cross-cutting constraints that apply across many features (performance, security, realtime safety, reliability, etc.) in a stable, referenceable way.

## Vocabulary
- NFRs are constraints/qualities, not features.
- Each NFR gets a stable ID: `NFR-####`, ...
- Features can link to NFR IDs in `spec/FEATURES.md` **when relevant**, but most features will omit NFR links.
- Prefer one of these patterns:
  - **Global NFR**: set "Applies to: all (unless stated otherwise)"
  - **Scoped NFR**: list the components/features it applies to

---

## NFR-0001: Instruction file size limit
- Category: maintainability
- Statement: Constitution-layer instruction files must be under 100 lines (L-0002 empirical finding)
- Applies to: all instruction files (CLAUDE.md, .cursorrules, copilot-instructions.md, codex-instructions.md)
- How to measure: `wc -l` on instruction files
- Where enforced:
  - Tests: `tests/infrastructure/structural/S08_claude_md_under_100_lines.sh`
  - CI: pre-commit-check.sh staleness detection
- Current status: met
- Acceptance: spec/acceptance/NFR-0001.md
- Notes: See docs/INSTRUCTION_ARCHITECTURE.md for the empirical basis (L-0002)

## NFR-0002: Token budget compliance
- Category: performance
- Statement: Subagent context injection must stay within the configured token budget per role
- Applies to: all subagent context manifests in .agentic/agents/*/context-manifests/
- How to measure: `context-for-role.sh` token counting output
- Where enforced:
  - Tests: `tests/test_nfr_validation.py`
  - CI: none
- Current status: met
- Acceptance: spec/acceptance/NFR-0002.md
- Notes: context-for-role.sh counts tokens and warns when over budget at runtime

## NFR-0003: Small batch work
- Category: process
- Statement: Work should be planned and executed in batches small enough that both agent and human can hold the full changeset in reasoning context (~10 files Formal, ~15 Discovery). The constraint belongs at planning time, not pre-commit — by the time a commit is too large, the damage is done.
- Applies to: all work (global)
- How to measure: Batch size at planning/decomposition time; pre-commit file count is a lagging indicator, not the enforcement point
- Where enforced:
  - Primary: memory-seed.md "TOO BIG" rule (>10 files → break into 3-5 tasks), `ag plan` decomposition
  - Advisory: pre-commit-check.sh warns on large commits (too late to be the real gate)
  - Tests: `tests/validate_framework.sh` (batch size checks)
- Current status: met
- Acceptance: spec/acceptance/NFR-0003.md
- Notes: Configurable via `max_files_per_commit` setting in STACK.md. The pre-commit warning is a safety net, not the strategy — the strategy is planning small.

## NFR-0004: Spec-first development
- Category: process
- Statement: Acceptance criteria must exist before implementation code is written for any feature
- Applies to: all features in Formal profile (global)
- How to measure: `ag implement` gate checks acceptance file exists; pre-commit checks FEATURES.md staleness
- Where enforced:
  - Tests: `tests/validate_framework.sh` (spec-first checks), `tests/infrastructure/structural/S07_memory_seed_consistency.sh`
  - CI: pre-commit-check.sh Check 3c, ag.sh implement gate
- Current status: met
- Acceptance: spec/acceptance/NFR-0004.md
- Notes: Discovery profile uses `acceptance_criteria: recommended` (advisory). Formal uses `blocking`.
