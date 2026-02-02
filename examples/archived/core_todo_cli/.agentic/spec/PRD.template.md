# PRD (Template)

Purpose: define *why* we’re building this and *what* success means.

## Summary
- Problem (1–2 sentences):
- Target user:
- Primary workflow:

## Goals (measurable)
- G1:
- G2:

## Non-goals (explicit)
- NG1:
- NG2:

## Terminology (requirement vs feature)
- In this framework, **Features (F-####)** are the canonical unit we plan/ship/test (`spec/FEATURES.md`).
- “Requirements” are **optional**:
  - Use them when you want explicit outcome/contract statements, especially for cross-cutting constraints (security/latency/compliance).
  - If you prefer minimal ceremony, skip requirements and express needs directly as feature acceptance criteria in `spec/acceptance/F-####.md`.
- If you do use requirements, keep an explicit mapping (one requirement can map to multiple features and vice versa).

## Requirements (user-facing)
- R-0001:
- R-0002:

## Acceptance criteria (high-level)
- AC1:
- AC2:

## Feature mapping (IDs)
- Feature registry: `spec/FEATURES.md`
- Map requirements to features:
  - R-0001 -> F-####
  - R-0002 -> F-####

## Risks & open questions
- Risk:
- Question:

## Release plan (thin)
- Milestone 1:
- Milestone 2:


