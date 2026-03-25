# REFERENCES

Purpose: track external resources (papers, docs, examples, repos) that informed design decisions and implementation.

## How to use
- Add references when research informs a feature, ADR, or technical decision
- Link references to the features/ADRs they influenced
- Extract key insights so future sessions don't need to re-read sources
- Keep it concise - this is a pointer system, not a knowledge base

---

## REF-001: Instruction Architecture Design
- Type: internal design doc
- URL: docs/INSTRUCTION_ARCHITECTURE.md
- Date accessed: 2026-02-08
- Related to:
  - Feature: F-0130 (three-layer architecture)
- Key insights:
  - Three layers: Constitution (<100 lines, always loaded) → Playbooks (just-in-time) → State (durable artifacts)
  - Constitution files must stay under 100 lines to avoid context bloat
  - Playbooks loaded on-demand via `ag` commands to save tokens

