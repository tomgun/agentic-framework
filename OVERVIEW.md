# OVERVIEW.md

<!--
This is the high-level context document. Agents read this during planning
to keep the project vision front and center.

Document separation:
- OVERVIEW.md: What & why we're building (stable) - read during planning
- CONTEXT_PACK.md: How to work here (operational) - read at session start
- STATUS.md: What's happening now (dynamic) - read at session start
-->

## What We're Building

An AI-assisted development framework that provides structured workflows, spec-driven methodology, and quality gates for software projects. The framework installs into any repo as a `.agentic/` directory and provides instruction files (CLAUDE.md, .cursorrules, etc.), state files (STATUS.md, STACK.md, etc.), and tooling (hooks, scripts, validation) that guide AI coding agents toward consistent, high-quality output.

## Why It Matters

AI coding agents (Claude Code, Cursor, Copilot, Codex) are powerful but lack persistent context, consistent methodology, and quality guardrails across sessions. Without structure, agents forget decisions, skip tests, produce inconsistent output, and lose track of project state. This framework solves that by providing a three-layer architecture (Constitution → Playbooks → State) that gives agents just-in-time guidance without bloating context windows.

## Core Capabilities

- [x] Two profiles: Discovery (lightweight, exploratory) and Formal (spec-driven, gated)
- [x] Instruction files auto-generated for Claude Code, Cursor, Copilot, Codex
- [x] State files (STATUS.md, JOURNAL.md, HUMAN_NEEDED.md) for session continuity
- [x] Pre-commit quality gates (complexity limits, staleness checks, branch policy)
- [x] Token-efficient scripts for state management (journal.sh, status.sh, etc.)
- [x] Feature tracking with acceptance criteria gates
- [x] Upgrade path (upgrade.sh) preserving user customizations
- [x] Settings system with profile-aware defaults
- [x] DRY state-file config (state-files.conf)
- [ ] Automated behavioral tests for agent compliance
- [ ] Online documentation site

## In Scope / Out of Scope

**In scope:**
- Framework scaffolding, upgrade, and verification tooling
- Instruction file generation for major AI tools
- Quality gates and pre-commit hooks
- State management scripts and templates
- Documentation and developer guides

**Out of scope (for now):**
- IDE plugins or extensions
- Cloud-hosted agent orchestration
- Language-specific linting or formatting rules
- Project-specific business logic templates

## Success Looks Like

Developers can install the framework into any repo and immediately get structured AI-assisted development with session continuity, quality gates, and spec-driven workflows — without reading a 50-page manual. Upgrades are smooth and preserve customizations.

## Guiding Principles

- **Convention over configuration**: Sensible defaults, override when needed
- **Token efficiency**: Minimize context window usage, load guidance just-in-time
- **Dogfooding**: The framework develops itself using its own methodology
- **Small batches**: Max 10 files per commit, break large tasks into pieces
- **Durable state**: If a session crashes, JOURNAL.md is the recovery point
