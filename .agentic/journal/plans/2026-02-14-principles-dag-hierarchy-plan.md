# Plan: Restructure Principles into DAG Hierarchy

**Date**: 2026-02-14
**Status**: IMPLEMENTED
**Commit**: d10f072

## Context

The framework had accumulated 12 principles with unclear relationships — some were foundational "why" principles, others were tactical "how" strategies, and others were concrete rules. The flat list didn't communicate which principles derived from which, making it hard to reason about trade-offs or trace rules back to their motivations.

## Design Decision

Restructure the 13 principles (previously 12, with merger/splits) into a 3-tier derivation hierarchy forming a directed acyclic graph (DAG):

- **FOUNDATION (WHY)** — 3 principles: F1 Developer-Friendly Experience, F2 Sustainable Quality, F3 Context Efficiency
- **DESIGN PRINCIPLES (HOW)** — 7 principles: D1-D7 (strategies that serve the foundations)
- **OPERATIONAL RULES (WHAT)** — 3 principles: R1-R3 (concrete, testable constraints)

Each non-foundation principle explicitly declares which parent(s) it derives from, with a mermaid DAG visualization. The tier distinction is abstraction level (WHY → HOW → WHAT), not enforcement level — all 13 are mandatory.

## Changes

10 files updated:
1. `.agentic/PRINCIPLES.md` — Full restructure with DAG, derivation annotations, mermaid diagram
2. `docs/HOW_IT_WORKS.md` — Updated mermaid diagram and section headings
3. `README.md` — Updated principles section with F/D/R prefixes
4. `.agentic/README.md` — Updated principle list
5. `FRAMEWORK_QUICK_START.md` — Updated core principles table
6. `docs/INSTRUCTION_ARCHITECTURE.md` — Updated references
7. `tests/TRACEABILITY_MATRIX.md` — Updated section headings and coverage table
8. `tests/VERIFICATION_REPORT.md` — Updated section headings
9. `CONTRIBUTIONS.md` — Documented the restructure
10. `.agentic/agents/context-manifests/implementation-agent.yaml` — Updated principle references

## Verification

184/184 validation tests pass.
