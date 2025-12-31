# Overview

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
- What are we building: a simple Todo web app (example project) built with Next.js + TypeScript.
- Who is it for: the developer using the agentic framework (demo).
- What “success” looks like:
  - the app runs locally with `npm run dev`
  - unit tests pass with `npm test`
  - features are tracked and accepted in `spec/FEATURES.md`

## Current state (today)
- Current version/release (optional): v0 demo
- What works:
  - view todos (local state)
  - add todo
  - toggle todo done/undone
- What’s in progress:
  - persistence to localStorage
- What’s risky:
  - none (demo)

## Architecture (map)
- Read: `spec/TECH_SPEC.md`
- Entry points:
- Major components:
  - UI: `app/page.tsx`
  - Domain logic: `lib/todo.ts`

## Feature registry (source of truth)
- Read: `spec/FEATURES.md`
- Each feature has:
  - a stable ID (e.g. `F-0001`)
  - status (planned/in_progress/shipped/deprecated)
  - acceptance criteria location
  - test coverage notes

## Lessons & caveats
- Read: `spec/LESSONS.md` and `spec/adr/*`


