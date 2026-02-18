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
- Notes: context-for-role.sh counts tokens and warns when over budget at runtime
