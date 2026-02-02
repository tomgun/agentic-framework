# Overview (Template)

Purpose: one place to understand the **vision**, **current state**, and **where to find truth**.

## Vocabulary
- **Feature (F-####)** is the **canonical unit** in this framework: a shippable capability with acceptance criteria and test notes. Features live in `spec/FEATURES.md`.
- **Requirement (optional)** is an additional way to state needs/outcomes (“what must be true”). Requirements can live in `spec/PRD.md` and be linked from features.
- **NFR (NFR-####)** are non-functional requirements: cross-cutting constraints (security, latency, compliance, realtime safety, reliability). NFRs live in `spec/NFR.md`.
- Acceptance criteria for each feature live in `spec/acceptance/F-####.md`.

## Recommended default
- If you want minimal ceremony: **use Features only** (treat “requirements” as part of each feature’s acceptance criteria).
- If you need stronger traceability or many cross-cutting constraints: use **Requirements + Features** and maintain an explicit mapping.

## Vision (high level)
- What are we building:
- Who is it for:
- What “success” looks like:

## Current state (today)
- Current version/release (optional):
- What works:
- What’s in progress:
- What’s risky:

## Architecture (map)
- Read: `spec/TECH_SPEC.md`
- Entry points:
- Major components:

## Feature registry (source of truth)
- Read: `spec/FEATURES.md`
- Each feature has:
  - a stable ID (e.g. `F-####`)
  - status (planned/in_progress/shipped/deprecated)
  - acceptance criteria location
  - test coverage notes

## Lessons & caveats
- Read: `spec/LESSONS.md` and `spec/adr/*`


