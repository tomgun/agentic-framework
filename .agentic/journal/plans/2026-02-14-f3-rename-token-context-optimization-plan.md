# Plan: Rename F3 to "Token & Context Optimization"

**Date**: 2026-02-14
**Status**: IMPLEMENTED
**Branch**: docs/principles-dag-hierarchy

## Context

The DAG hierarchy restructure carried F3 over as "Context Efficiency" from the old naming. The user identified this name hides the original "Token Economics" motivation — tokens cost money, and being smart about token usage is half the principle. After iterating on options, settled on **"Token & Context Optimization"** — captures both the economic angle (token savings) and the technical angle (context engineering), matches F2's "&" pattern.

## Change

**Old**: `F3: Context Efficiency`
**New**: `F3: Token & Context Optimization`

Also updated the **What** description in PRINCIPLES.md to lead with the economic motivation:
> **What**: Tokens cost money, context windows are limited, and compute has environmental impact. Every framework decision respects these constraints — from choosing appropriate models per task to loading minimal context to using scripts that are 40x cheaper than read-modify-write.

## Files Updated (8 files, 15 edits)

1. **`.agentic/PRINCIPLES.md`** — Heading, mermaid node label, What description
2. **`docs/HOW_IT_WORKS.md`** — Mermaid node label, section heading, quote, 2 mermaid comments, 3 table references
3. **`README.md`** — Heading + description paragraph
4. **`.agentic/README.md`** — F3 bullet in principle list
5. **`tests/TRACEABILITY_MATRIX.md`** — Section heading + coverage summary table row
6. **`tests/VERIFICATION_REPORT.md`** — Section heading
7. **`FRAMEWORK_QUICK_START.md`** — Core principles table row
8. **`.agentic/agents/shared/auto_orchestration.md`** — Design basis reference (also fixed old #3/#4/#5 numbering to F3/D2/D3)

Historical files (CONTRIBUTIONS.md, JOURNAL.md, docs/reviews/) left untouched — they record what was true at the time.

## Verification

- 184/184 validation tests pass
- No stale "Context Efficiency" in any active file
- "Token & Context Optimization" confirmed in all 8 updated files
