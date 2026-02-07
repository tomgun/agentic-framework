# Instruction Architecture Design Document

**Status**: Authoritative design basis for the Agentic AI Framework's instruction file architecture.
**Last validated**: 2026-02-07
**Owner**: Framework maintainer (whoever merges changes to `.agentic/`)

**Rule**: When source research documents and this design document disagree, this document wins.

---

## 1. Research Basis

This design synthesizes two independent research efforts:

- **ChatGPT 5.2 research** (`docs/research/context_and_subagents_research_2026_02_06.md`) — architectural analysis of instruction persistence across multi-agent systems. Excellent framework reasoning; cited sources are generic (e.g., lesswrong.com without specific articles). Evidence quality: ARCHITECTURAL REASONING.
- **Claude Opus 4.6 research** (`docs/research/2026-02-07-subagent-context-inheritance.md`) — tool-specific investigation with verified sources, direct quotes, and per-tool confidence levels. Evidence quality: VERIFIED TOOL DOCS.

### Where sources agree, differ, and differ in evidence quality

| Finding | ChatGPT 5.2 | Claude (Opus 4.6) | Agreement |
|---------|-------------|-------------------|-----------|
| Subagents are context-isolated | YES — architectural analysis | YES — confirmed for Claude (HIGH), Cursor (HIGH), Copilot (UNCLEAR) | FULL |
| Instruction files serve orchestrator only | YES | YES — confirmed across tools with sources | FULL |
| Context retention is unreliable | YES — "never rely on passive retention" | YES — L-0002: degrades past ~100 lines (empirical) | FULL |
| Three-layer architecture needed | YES — Constitution/Playbooks/State | Partially — framework has pieces but no formal layering | ALIGNED |
| Structural enforcement > behavioral | YES — "orchestrator is enforcement layer" | YES — Principle #4, pre-commit gates | FULL |
| Post-task validation mandatory | YES — finalization check pattern | `ag done` runs doctor.sh but `\|\| true` suppresses failures | NARROW GAP |
| Constitution size: 300-800 tokens | YES (no cited empirical basis) | ~100 lines / ~1500 tokens max (LLM test-validated) | DEVIATION |

**Constitution size deviation**: The ChatGPT research recommends 300-800 tokens (~15-40 lines). The framework's empirical finding (L-0002) is that compliance degrades past ~100 lines (~1500 tokens). The proposed slimmed target of ~40-50 lines (~800-1000 tokens) exceeds the ChatGPT upper bound by ~25%. This is a conscious choice: the framework's instruction files carry competing high-priority rules (gates, triggers, protocols) that dilute each other faster than single-purpose constitutions. The 100-line upper bound from L-0002 remains the framework's validated ceiling. The ChatGPT recommendation is noted as aspirational guidance without cited empirical basis.

**Gemini**: The ChatGPT research notes Gemini is stateless between calls, supports up to ~1M tokens, and has no native orchestrator memory. Documented here for future reference — the framework doesn't support Gemini yet. Including unactionable findings in the main design would weaken the document's authority.

---

## 2. The Three-Layer Architecture

### Layer 1: Constitution (instruction files)

**Files**: CLAUDE.md, .cursorrules, copilot-instructions.md, codex-instructions.md

**Current state**: 69-92 lines across tools (template CLAUDE.md: 79, root CLAUDE.md: 92, cursorrules: 71, copilot: 69, codex: 71). These mix constitutional rules with playbook content.

**Research says**: 300-800 tokens, invariant rules only (ChatGPT); under 100 lines for attention quality (L-0002).

**Design principle**: Instruction files ARE the constitution. They should contain ONLY rules that cannot be structurally enforced.

**What stays** (cannot be structurally enforced — agent must choose to comply):
- Trigger table — tested, tests 003/010 pass
- Token-efficient scripts references — tested, tests 004/019 pass
- "Never auto-commit" — behavioral rule
- "Never fabricate APIs" — behavioral rule
- Core behavioral boundaries (ask when uncertain, etc.)

**What moves to Layer 2** (already structurally enforced):
- Gates table — informational; pre-commit-check.sh enforces regardless
- Delegation table — orchestrator implementation detail
- Session protocol details — structurally handled by `ag start`

**Applies to both**: Root CLAUDE.md (framework development) AND template CLAUDE.md (`.agentic/agents/claude/CLAUDE.md`). Different audiences, same constitutional principle.

### Layer 2: Playbooks (already exist)

**Key files**: auto_orchestration.md (335 lines), agent_operating_guidelines.md (435 lines), 9 checklists, quality standards, workflow docs.

**Loading mechanism**: `ag` commands print relevant instructions at the right moment. auto_orchestration.md is NOT referenced in any instruction file — it is accessed indirectly when agents run `ag implement`, `ag commit`, etc., which print task-specific guidance. This is intentional: just-in-time delivery via scripts.

**Gap**: `ag` commands don't explicitly tell the agent WHICH playbook file to read for deeper details. See Gap 3.

### Layer 3: Project State

**Git-tracked state** (survives across machines):
- STACK.md — git-tracked, parseable config file read by ag.sh with grep/sed
- `.agentic/state/status.json` — holds runtime state (focus, progress, next, blocker). Git-tracked by design so work can continue on another computer.

**Session-local state** (gitignored):
- `.agentic-state/WIP.md` — work-in-progress lock
- `.agentic-state/AGENTS_ACTIVE.md` — multi-agent coordination

**Design property**: State that must survive across machines goes in git-tracked files. State that is session-local goes in gitignored files. This distinction must be preserved.

**Future consideration**: A compact config.json (aggregating STACK.md keys + runtime state) could help subagent context injection. Lower priority than Gaps 1-4 — STACK.md parsing works today.

### Orchestrator Enforcement (distributed model)

The framework uses a **distributed enforcement model** — this is a conscious design choice that diverges from the ChatGPT research's centralized orchestrator recommendation. Rationale: the framework operates across Claude Code, Cursor, Copilot, and Codex — no single orchestrator process is possible. The distributed model (each script enforces its phase) achieves the same guarantees.

**Enforcement points**:
- `ag implement` — checks acceptance criteria + approved plan
- `pre-commit-check.sh` — runs 11 structural checks
- `ag done` — runs `doctor.sh --phase complete` (but `|| true` in `cmd_done()` currently suppresses failures — see Gap 4)
- `context-for-role.sh` — assembles role-specific context for subagents

---

## 3. What Already Works (DO NOT CHANGE)

These mechanisms are proven and stable. Changes require strong justification:

- **pre-commit-check.sh** — 11 structural gates
- **context-for-role.sh** + 24 context manifests — subagent context injection
- **Token-efficient scripts** — journal.sh, status.sh, feature.sh, blocker.sh
- **LLM behavioral test suite** — 23 tests validating instruction compliance
- **auto_orchestration.md** — primary playbook for agent workflows
- **`ag` gateway** — structural enforcement entry point
- **Trigger table format** in instruction files — tested (003/010 pass), proven
- **AGENT_QUICK_START.md** — "one rule: run doctor.sh" pattern
- **Manifest-based guideline injection** in context-for-role.sh — 7 of 24 manifests currently include anti-hallucination.md
- **STACK.md parsing** via ag.sh (grep/sed) — works today, no need to replace
- **Git-tracked vs gitignored state split** — status.json in git for cross-machine; WIP.md/AGENTS_ACTIVE.md gitignored for session-local

---

## 4. Gaps to Close

### Gap 1: Instruction files mix constitution with playbook content

**Current baselines**: Template CLAUDE.md 79 lines, root 92 lines, others 69-71 lines.
**Target**: ~40-50 lines.
**Principle**: Keep what cannot be structurally enforced (trigger table, token scripts, core behavioral rules). Move what IS structurally enforced (gates table, delegation table, session protocol details) to playbooks. The gates table is informational — pre-commit-check.sh enforces it regardless.

### Gap 2: Subagents don't consistently receive critical constitutional rules

Currently, 7 of 24 context manifests (orchestrator, planning, research, review, test, implementation, spec-update) declare anti-hallucination.md as a required file. The remaining 17 manifests do not include it. `context-for-role.sh` has no hardcoded always-inject list — injection is entirely manifest-declared.

A broader set of critical rules (~300 tokens — no fabrication, no auto-commit, use token-efficient scripts) should apply to ALL agents. Two possible mechanisms:
- **(a)** Add the rules file to all 24 manifests
- **(b)** Add a script-level always-inject feature to context-for-role.sh

Choice deferred to implementation plan.

### Gap 3: `ag` commands don't print playbook references

`ag` commands should tell the agent which playbook file to read for deeper details. Example: `ag implement` could reference auto_orchestration.md; `ag commit` could reference before_commit.md.

**Caveat**: This assumes agents follow stdout references — L-0003 notes this is untested. Implementation plan should include a simple validation test. See assumption A7.

### Gap 4: `ag done` doesn't block on validation failures

`ag done` (Core+PM) runs `doctor.sh --phase complete` (in `cmd_done()` function of ag.sh) but `|| true` suppresses the exit code. The structural check exists but isn't blocking.

**Fix**: Remove `|| true` to make it blocking. For Core profile, add a basic check instead of the current no-op.

---

## 5. Design Principles

These principles govern future framework changes to instruction architecture:

1. **Never rely on memory** — if a rule must always apply, enforce it structurally (script/gate), not behaviorally (instruction text)
2. **Constitution = what cannot be structurally enforced** — anti-hallucination, "ask when uncertain", trigger word responses
3. **Playbooks = how to follow rules** — loaded by `ag` commands at the right moment, not pinned in context
4. **State = machine-readable** — STACK.md parsed by ag.sh; status.json for runtime state
5. **Distributed enforcement** — ag.sh + pre-commit-check.sh + context-for-role.sh each own their phase. Framework design choice diverging from ChatGPT's centralized recommendation; rationale: cross-tool compatibility
6. **Test behavioral rules empirically** — LLM tests prove which instruction file content agents actually follow. No behavioral rule should be added without a corresponding test

---

## 6. Relationship to Source Research Documents

This design document synthesizes and supersedes the two source research documents:

- `docs/research/context_and_subagents_research_2026_02_06.md` (ChatGPT 5.2 research) — retained as historical source
- `docs/research/2026-02-07-subagent-context-inheritance.md` (Claude Opus 4.6 research) — retained as historical source

**Rule**: Source documents are historical evidence, not authoritative guidance. They should NOT be updated — amendments go into this design document.

---

## 7. Maintenance

**Update triggers**:
- New LLM test results that contradict a finding
- Tool updates that change subagent behavior (e.g., Copilot clarifies context inheritance)
- New tool support added to framework (e.g., Gemini)

**Process**: Changes to this document require the same plan-review discipline as the original creation — no ad-hoc edits that weaken the evidence base.

---

## 8. Testable Assumptions

The design makes assumptions that should be validated over time. Each has a status:

| # | Assumption | Status | How to Test |
|---|-----------|--------|-------------|
| A1 | Trigger table format has high agent compliance | VALIDATED — tests 003/010 pass | LLM test suite |
| A2 | Token-efficient scripts are used when referenced | VALIDATED — tests 004/019 pass | LLM test suite |
| A3 | ~100 lines is the practical instruction file ceiling | VALIDATED — L-0002 empirical finding | LLM tests at varying file sizes |
| A4 | Subagents don't inherit CLAUDE.md (Claude Code) | CONFIRMED — official docs | Check docs on major tool updates |
| A5 | Subagents don't inherit .cursorrules (Cursor) | CONFIRMED — official docs + changelog | Check docs on major tool updates |
| A6 | Distributed enforcement achieves same guarantees as centralized orchestrator | ASSUMED — architectural reasoning, not empirically tested | Run full workflow with deliberate violations, check if gates catch them |
| A7 | `ag` command stdout has high salience to agents | UNTESTED — proposed in Gap 3 | Create LLM test: does agent follow instruction printed by `ag` command? |
| A8 | ~40-50 lines is achievable while keeping trigger table + token scripts + core rules | UNTESTED — proposed in Gap 1 | Attempt the slimdown and run LLM tests |
| A9 | Copilot loads copilot-instructions.md into subagent sessions | UNKNOWN — contradictory docs | Empirical test with distinctive instruction |
| A10 | Git-tracked status.json survives cross-machine workflow | ASSUMED — git fundamentals, untested in practice | Work on feature from machine A, continue from machine B |

**Update this table** when assumptions are validated or invalidated. Failed assumptions trigger design document amendments.

---

## 9. Open Questions

### Blocks implementation decisions (resolve before implementing gaps)

- **How aggressively to slim instruction files?** Proposed ~40-50 lines (keep tested content, remove structurally-enforced content) — directly affects Gap 1
- **Does `ag` command stdout have higher salience than file content?** (Untested) — directly affects Gap 3

### Exploratory (can be deferred)

- Does table format (trigger words) have higher compliance than prose format?
- Would a "router" CLAUDE.md (purely dispatch, no rules) outperform the current hybrid?
- Could the attention budget be relaxed to 150-200 lines now that subagent bloat isn't a concern?
- Does Copilot load copilot-instructions.md into subagent sessions? (Needs empirical test)
- Gemini: when/if support is added, how does its stateless model affect the architecture?
