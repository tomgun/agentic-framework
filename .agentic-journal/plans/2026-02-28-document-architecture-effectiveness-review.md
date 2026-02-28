# Document Architecture Effectiveness Review

**Date**: 2026-02-28
**Type**: Critical review / analysis + implementation plan
**Status**: Partially implemented

## Context

The agentic framework creates and maintains ~15 markdown documents per project to help AI agents work efficiently. This review evaluates whether this approach adds genuine value given that Claude already scans and understands repos natively — and identifies where the system leaks.

Methodology: Analyzed framework source code (enforcement mechanisms, token costs, consumption paths), real failure incidents, and production projects.

---

## 1. Does the Document Approach Make Sense?

**Verdict: Yes — but only ~65% of it. The enforcement model has a structural flaw.**

### What Claude CANNOT derive from code (high value, ~65%)

| Category | Examples | Why agents can't infer this |
|----------|----------|----------------------------|
| **Behavioral rules** | Trigger words, pre-commit sequence, `ag` commands | Policy choices — no code signal says "run `ag plan` before coding" |
| **Project vision** | OVERVIEW.md, acceptance criteria | What to build next is a human decision |
| **Session continuity** | STATUS.md focus, JOURNAL.md history, WIP.md | Agent sessions are stateless; without these, each starts cold |
| **Cross-session lessons** | LESSONS.md, HUMAN_NEEDED.md | "BSD sed breaks on macOS" isn't derivable from code |
| **Workflow gates** | docs_gate, wip_before_commit settings | Enforcement policy is arbitrary — can't derive "blocking" vs "warning" |

### What Claude CAN derive but docs make faster (~25%)

These "acceleration docs" save 5-15 tool calls per session (~2,000-5,000 tokens of exploration). In a 500+ file project, that's significant.

### What's genuinely redundant (~10%)

- REFERENCES.md, NFR.md in simple projects, detailed TECH_SPEC.md in discovery profile

---

## 2. The Two-Tier Enforcement Problem (Critical Finding)

### Tier 1 — Hard gates (reliable, docs stay fresh)
- JOURNAL.md, STATUS.md: Pre-commit BLOCKING (mtime vs last commit) → Always current
- FEATURES.md: Pre-commit BLOCKING in formal mode → Usually current
- WIP.md: Pre-commit BLOCKING (file existence) → Works

### Tier 2 — Soft/no gates (docs rot forever)
- CONTEXT_PACK.md: Checklist hint "if architecture changed" → Subjective, agents skip
- OVERVIEW.md: Checklist hint at feature_complete → No staleness detection
- README.md: Nothing → No check anywhere
- AGENTS.md: Nothing → Created once, never refreshed

### The enforcement paradox
The framework's Principle D2 states "Never rely on memory — enforce structurally." But the doc update enforcement itself is largely behavioral — a meta-failure.

---

## 3. Recommendations & Implementation Status

### P0: Close the enforcement gap

**R1: Add OVERVIEW.md + CONTEXT_PACK.md staleness to sync.sh Phase 2** (DONE)
- Added advisory commit-count threshold (15 commits) checks
- Added OVERVIEW.md placeholder detection
- Added spec doc staleness (FEATURES, TECH_SPEC, NFR)
- Runs in both --quiet and full modes

**R2: Verify hooks installed at session start** (ALREADY IMPLEMENTED)
- Review found `_ensure_hooks()` auto-runs on every `ag` invocation (line 2291-2305)
- `cmd_start()` explicitly checks (lines 315-324)
- `sync.sh` Phase 6 checks and auto-fixes
- No action needed — already solved in current version

**R3: Auto-register core docs in scaffold** (DONE)
- Uncommented CHANGELOG.md and README.md entries in STACK.template.md `## Docs` section
- Activates docs_gate enforcement for all new projects

### P1: Token waste reduction

**R4: Eliminate dual-maintenance documents** (DEFERRED)
- Original plan: merge memory-seed.md into CLAUDE.md
- Review finding: memory-seed.md is written ONCE to persistent memory, not loaded every session. Merging would INCREASE cost and violate <100-line constitution limit.
- Revised approach: deduplicate overlapping content within memory-seed.md
- Decision: Deferred — the redundancy is intentional defense-in-depth (two independent enforcement paths: CLAUDE.md loaded by tool, memory-seed in persistent memory). Testing whether removing duplication degrades compliance requires expensive A/B testing (20-30+ runs per scenario with automated compliance checking).

**R5: Context deduplication in context-for-role.sh** (DROPPED)
- File-level disk caching does NOT reduce LLM token consumption
- Each subagent runs in a separate LLM session and reads full text regardless
- The "18,000 tokens saved" claim was incorrect
- Real token reduction requires: better section extraction, smaller manifest required lists, more aggressive token budgets

**R6: Embed session-start reads in CLAUDE.md template** (ALREADY DONE)
- CLAUDE.md line 7 already says: "Read STATUS.md, HUMAN_NEEDED.md, and last 2-3 entries of JOURNAL.md"
- Session-start checklist (354 lines) handles edge cases that don't belong in CLAUDE.md

### P1: Hindsight doc generation

**R7: Create `ag refresh <doc>` command** (DEFERRED)
- Needs feature spec before implementation
- Should narrow to CONTEXT_PACK.md only for v1 (most structured, most automatable)
- Requires LLM invocation — not a simple bash script

**R8: Create `ag audit docs` / `ag sync --audit` command** (DEFERRED)
- Consider as `ag sync --audit` flag rather than new top-level command
- Largely repackaging of `ag sync --check` with more user-friendly output

### P2: Clean up tool sprawl

**R9: Retire stale.sh, consolidate into sync.sh** (DONE)
- Ported ALL stale.sh checks to sync.sh Phase 2 (7+ files, not just 2)
- Replaced stale.sh with deprecation wrapper that delegates to `sync.sh --check`
- Updated 6 reference files: retrospective.md, list-tools.sh, .agentic/README.md, README.md, HOW_IT_WORKS.md, DEVELOPER_GUIDE.md (3 locations)

**R10: Fix testing_standards.md reference** (DONE)
- Fixed both test-agent.yaml and review-agent.yaml (plan only caught test-agent)
- Changed `testing_standards.md` → `test_strategy.md` (the file that actually exists)

---

## 4. Implementation Summary

| Item | Status | Files changed |
|------|--------|---------------|
| R1 | Done | sync.sh |
| R2 | Already implemented | — |
| R3 | Done | STACK.template.md |
| R4 | Deferred (intentional redundancy) | — |
| R5 | Dropped (wrong approach) | — |
| R6 | Already done | — |
| R7 | Deferred (needs spec) | — |
| R8 | Deferred | — |
| R9 | Done | stale.sh, sync.sh, + 6 reference files |
| R10 | Done | test-agent.yaml, review-agent.yaml |

## 5. Key Learnings

1. **File caching ≠ token savings** — LLM context consumption is independent of disk I/O caching
2. **Defense-in-depth has a token cost** — dual CLAUDE.md + memory-seed enforcement costs ~2,650 tokens/session but provides two independent compliance paths
3. **grep -c with `|| echo "0"` is a bash bug** — grep -c returns exit 1 when count is 0, causing `0\n0` in variable capture. Use `|| true` + default instead.
4. **Production project evidence has version bias** — jump-game ran without hooks because `_ensure_hooks()` didn't exist in that framework version, not because of a current gap
