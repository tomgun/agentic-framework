# Plan: Reconcile Agent Definitions + Surface Context Manifests

**Status**: APPROVED
**Date**: 2026-03-18
**Review**: Round 2 — Critic APPROVE, Advocate APPROVE

## Context

The framework has two parallel sets of agent definitions with different coverage and no cross-linkage:
- `roles/` (13 agent-agnostic definitions) — used by Cursor, referenced by all tools
- `subagents/` (29 Claude-specific definitions) — used only by Claude, with model_tier, prompt templates, Task tool invocation patterns
- `context-manifests/` (26 YAML files) — used only by `context-for-role.sh` for Claude, invisible to other tools

### Actual inventory (audited)

**Overlap** (9 agents in all three sets): documentation, git, implementation, orchestrator, planning, research, review, spec-update, test

**Roles without subagent** (4): architecture, cloud-expert, monetization, scientific-research

**Subagents without role** (20): api-design, appstore, aws, azure, compliance, db, design, devops, domain, explore, gcp, migration, perf, plan-advocate, plan-creator, plan-critic, plan-reviewer, refactor, security, ux

**Subagents without manifest** (3): explore, plan-creator, plan-reviewer

### Problems

1. **Coverage divergence**: 20 subagents have no role counterpart. 4 roles have no subagent counterpart. The two sets drift independently with no automated parity check.
2. **Cursor agents lack manifest context**: When a Cursor user invokes `@implementation-agent`, the agent file says "Read STACK.md" but doesn't include the focused context loading info from manifests (token budgets, required vs optional files, section extraction).
3. **Copilot/Codex have zero agent awareness**: No catalog, no reference material.
4. **No `.claude/agents/` needed**: Claude Code doesn't auto-discover from this directory. The existing `subagents/` + `context-for-role.sh` pipeline already works for Claude.

### Goal

Reconcile the two definition sets, surface manifest context to non-Claude tools, keep domain specialists opt-in, and add automated drift detection to prevent re-divergence.

### Scope split

This plan is split into two independently shippable features to reduce risk:

- **Feature A** (this plan): Reconcile coverage + add drift detection. Steps 1, 2, 6.
- **Feature B** (follow-up): Surface manifests to non-Claude tools. Cursor enrichment, Copilot/Codex awareness, `--domain` flag. Depends on Feature A.

This document covers **Feature A only**.

---

## What Changes

### 1. Reconcile `roles/` and `subagents/` coverage

**Add 6 new roles** for the most useful subagent-only agents — these are genuinely tool-agnostic capabilities any project might need:

| Add to `roles/` | Why |
|-----------------|-----|
| `api_design_agent.md` | API contract design is tool-agnostic |
| `security_agent.md` | Security review is tool-agnostic |
| `refactor_agent.md` | Refactoring workflows are tool-agnostic |
| `explore_agent.md` | Codebase exploration is tool-agnostic |
| `db_agent.md` | Database schema/migration work is tool-agnostic |
| `design_agent.md` | UI/UX design guidance is tool-agnostic |

New role files follow the established format: YAML frontmatter (`summary`, `tokens`) + sections (Context to Read, Responsibilities, Output, What You DON'T Do, Handoff). Content derived from corresponding subagent definitions, stripped of Claude-specific fields (model_tier, Task tool patterns).

**Add 1 missing manifest** for `explore-agent` (the only new role that has a subagent but no manifest).

**Deprecate 4 role-only agents**: architecture, cloud-expert, monetization, scientific-research. These are example/template agents that were never promoted to subagents or manifests. They add to the false impression of parity without providing real value. Deprecation = add `deprecated: true` to frontmatter + note in file pointing to subagents/ if a replacement exists.

**Skip domain specialists** (10): aws, azure, gcp, appstore, compliance, devops, domain, migration, perf, ux — these remain opt-in Claude subagents only. They are project-specific, not universal.

**Explicitly out of scope — plan-\* agents** (4): plan-advocate, plan-creator, plan-critic, plan-reviewer. These are Claude-specific workflow primitives used by the dialectical review mechanism. They invoke the Task tool to spawn subagents — a capability that doesn't exist in Cursor/Copilot/Codex. They are not domain agents and should not become roles. plan-reviewer is already deprecated.

After this step: 15 active roles (13 − 4 deprecated + 6 new), 29 subagents, 27 manifests.

**Deprecation contract**: `deprecated: true` in YAML frontmatter means:
- `setup_cursor_agents()` skips the file (not copied to `.cursor/agents/`)
- `context-for-role.sh` skips the role (returns error if invoked directly)
- Drift detection excludes deprecated roles from "missing counterpart" failures
- The file remains in `roles/` as documentation with a note explaining why it was deprecated and pointing to alternatives if any exist

### 2. Add automated drift detection to `validate_framework.sh`

Add a parity check section that verifies:

1. **Every active role has a corresponding subagent** (kebab-case match after snake→kebab conversion)
2. **Every active role has a corresponding manifest** (same matching)
3. **Deprecated roles are flagged** if they lack `deprecated: true` frontmatter
4. **Warning (not failure)** for subagents that have no role — this is expected for domain specialists and plan-* agents

This prevents the reconciliation from degrading over time. The check runs as part of the existing `validate_framework.sh` flow (pass/fail/warning).

Additionally: **subagents without manifests** emit a warning (currently explore, plan-creator, plan-reviewer — explore will be fixed by this plan; plan-creator and plan-reviewer are Claude workflow internals and the warning is informational). Plan-* agent drift detection is tracked as part of Feature B's scope.

Implementation: ~30 lines of bash in `tests/validate_framework.sh`, using file listing + comm/diff comparison (same technique used above to audit inventory).

### 3. Update instruction files and documentation

| File | Change | Why |
|------|--------|-----|
| `.agentic/lib/agents/roles/README.md` | Update agent count (15 active, 4 deprecated), list new additions, note deprecation convention | Accuracy |
| `.agentic/lib/agents/cursor/agents-setup.md` | Note expanded role set, deprecation of 4 template agents | Cursor users see accurate info |
| `.cursor/agents/README.md` | Update available roles table (add 6, mark 4 deprecated) | Cursor users see accurate catalog |
| `.agentic/lib/init/memory-seed.md` | Add note: "roles/ and subagents/ parity enforced by validate_framework.sh" | Agents know about the enforcement |
| `.agentic/lib/agents/claude/CLAUDE.md` | No change needed — Claude path already works | — |
| Root `CLAUDE.md` | No change needed | — |
| `.agentic/lib/agents/copilot/copilot-instructions.md` | No change (deferred to Feature B) | — |
| `.agentic/lib/agents/codex/codex-instructions.md` | No change (deferred to Feature B) | — |
| `.cursorrules` | No change needed — doesn't reference agent definitions | — |
| `docs/DEVELOPER_GUIDE.md` | Add section on role/subagent/manifest relationship | Developers understand the three sets |
| `docs/HOW_IT_WORKS.md` | No change (manifest surfacing deferred to Feature B) | — |

---

## Files Summary

| Action | File |
|--------|------|
| CREATE | `.agentic/lib/agents/roles/api_design_agent.md` |
| CREATE | `.agentic/lib/agents/roles/security_agent.md` |
| CREATE | `.agentic/lib/agents/roles/refactor_agent.md` |
| CREATE | `.agentic/lib/agents/roles/explore_agent.md` |
| CREATE | `.agentic/lib/agents/roles/db_agent.md` |
| CREATE | `.agentic/lib/agents/roles/design_agent.md` |
| CREATE | `.agentic/lib/agents/context-manifests/explore-agent.yaml` |
| MODIFY | `.agentic/lib/agents/roles/architecture_agent.md` (add deprecated frontmatter) |
| MODIFY | `.agentic/lib/agents/roles/cloud_expert_agent.md` (add deprecated frontmatter) |
| MODIFY | `.agentic/lib/agents/roles/monetization_agent.md` (add deprecated frontmatter) |
| MODIFY | `.agentic/lib/agents/roles/scientific_research_agent.md` (add deprecated frontmatter) |
| MODIFY | `tests/validate_framework.sh` (add parity check) |
| MODIFY | `.agentic/lib/agents/roles/README.md` |
| MODIFY | `.agentic/lib/agents/cursor/agents-setup.md` |
| MODIFY | `.cursor/agents/README.md` |
| MODIFY | `.agentic/lib/init/memory-seed.md` |
| MODIFY | `docs/DEVELOPER_GUIDE.md` |

**Total**: 7 new/create, 10 modify = 17 files. Commit in 2-3 batches: (1) new roles + deprecations, (2) drift detection, (3) documentation updates.

---

## What We Explicitly Do NOT Do

- **No `.claude/agents/` directory** — Claude Code doesn't auto-discover from it. The existing `subagents/` + `context-for-role.sh` is the right mechanism.
- **No `generate-agents.sh`** — Not needed. The existing `setup_cursor_agents()` in `setup-agent.sh` handles the copy+transform.
- **No dumping all 29+ agents into Cursor** — Domain specialists stay opt-in (Feature B will add `--domain` flag).
- **No modifying scaffold.sh or upgrade.sh** — `setup-agent.sh all` already runs during install/upgrade and calls `setup_cursor_agents()`, which picks up new roles automatically.
- **No Cursor manifest enrichment yet** — Deferred to Feature B. Avoids the bash YAML parsing risk in this feature.
- **No Copilot/Codex catalog table yet** — Deferred to Feature B. A one-liner pointer to roles/README.md will be added then (not a full table — review found that disproportionate).
- **No `--domain` flag yet** — Deferred to Feature B. Needs design for how Claude-specific fields (model_tier, Task tool patterns) are transformed for Cursor format.
- **No plan-\* agent roles** — These are Claude-specific workflow primitives, not domain agents.
- **No specialization overrides for new roles** — The 5 existing specialization configs (react, django, fastapi, go, godot) don't override the existing 13 roles today. New roles follow the same pattern — specializations are added per-project demand, not preemptively.

---

## Feature B Outline (for reference, not part of this plan)

Feature B depends on Feature A and covers:
1. **Cursor manifest enrichment**: Modify `setup_cursor_agents()` to append `## Recommended Context` from manifests. Use a Python helper (~40 lines) instead of bash YAML parsing — reuses the YAML structure already parsed by `context-for-role.sh` but outputs Markdown. Token budgets framed as "guidelines" not constraints.
2. **Copilot/Codex agent awareness**: Add a one-liner pointer to `.agentic/lib/agents/roles/README.md` (not a full catalog table).
3. **`--domain` flag**: `setup-agent.sh cursor-agents --domain aws,security` copies domain-specialist subagents with Claude-specific fields stripped (model_tier removed, Task tool invocation patterns replaced with generic delegation guidance).

---

## Verification

1. `ls .agentic/lib/agents/roles/*.md | wc -l` → 19 (15 active + 4 deprecated)
2. New role files follow established format (frontmatter + Context to Read, Responsibilities, Output, What You DON'T Do, Handoff)
3. Deprecated role files have `deprecated: true` in YAML frontmatter
4. `explore-agent.yaml` exists in `context-manifests/`
5. `bash tests/validate_framework.sh` passes — including new parity checks
6. Parity check catches intentional violations: temporarily rename a role file → validate_framework.sh fails → rename back
7. `bash .agentic/lib/tools/setup-agent.sh cursor-agents` still works — 15 active roles copied (deprecated roles skipped or flagged)

---

## Review Findings Addressed

| Finding | Severity | Resolution |
|---------|----------|------------|
| Scope mapping inaccurate (C1) | CRITICAL | Audited actual inventory: 13 roles, 29 subagents, 26 manifests. Numbers corrected throughout. |
| No drift detection (C2) | CRITICAL | Added Step 2: validate_framework.sh parity check |
| Bash YAML parsing fragile (C3) | CRITICAL | Deferred manifest enrichment to Feature B; Feature B will use Python helper |
| Plan-* agents unaddressed (M1) | MAJOR | Explicitly out of scope with rationale |
| Copilot/Codex catalog low value (M2) | MAJOR | Downgraded to one-liner pointer in Feature B |
| --domain flag unclear (M3) | MAJOR | Deferred to Feature B with design requirement for field transformation |
| Role-only agents need decision (M4) | MAJOR | Decision: deprecate all 4 |
| Naming inconsistency (M4b) | MAJOR | New roles use snake_case (matching existing convention); validate_framework.sh handles conversion for matching |
| scaffold/upgrade gaps (N1) | MINOR | Confirmed: setup-agent.sh all already called by both — no changes needed |
| Vague instruction file list (N2) | MINOR | Full 11-file enumeration in Step 3 table |
| Specializations unaddressed (N3) | MINOR | Explicitly out of scope — specializations are demand-driven |
| Missing explore manifest (N4) | MINOR | Added to Step 1 file list |
| Splittable scope (T1) | NOTE | Split into Feature A (this) and Feature B (follow-up) |
| Token budget UX framing (T2) | NOTE | Feature B will frame as "guidelines" not constraints |
