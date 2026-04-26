# Agentic AF 2 — Greenfield Path (alternative to v5 transform)

> **Companion to:** `2026-04-26-framework-ground-up-redesign-plan.md` (v5)
> **Status:** Documented for completeness. **Not the chosen path** as of 2026-04-26 (transform-in-place selected). This document exists so a future fresh-start decision has a complete blueprint.
> **When to choose greenfield:** if you commit to (a) Claude Code as exclusive orchestrator (drop Cursor/Copilot/Codex parity entirely), AND (b) redesigning the spec format itself, AND (c) not preserving install-base from existing v0.7x users.

---

## Why this document exists

The v5 plan recommends transform-in-place because greenfield's only durable advantage is "clean mental model from day 1" — and the v5 plan + spike removed the architecture-uncertainty hedge that had justified greenfield as a competitive option.

But greenfield remains a real choice. If the current install base is small enough that a hard reset is acceptable, and if the user wants to commit fully to Claude Code's primitives without carrying any compatibility weight, AF2 from scratch is materially cleaner. This document captures everything needed to start AF2 properly so a fresh-start session has the full picture.

---

## Section 1: Capability inventory (what AF2 must preserve from v0.7x)

The v5 plan's "What's preserved (the irreducible 1.6%)" list is necessary but not sufficient for a greenfield start. Greenfield needs the full **user-facing capability inventory** so day-1 AF2 doesn't accidentally drop something users rely on.

### Authoritative source: `docs/CAPABILITY_SPEC.md`

The framework's own founding capability spec at `/workspace/docs/CAPABILITY_SPEC.md` (118 lines) is the cleanest user-facing statement of what the framework *actually needs to do* — separate from the implementation complexity. It enumerates **15 required capabilities** that any framework redesign (transform OR greenfield) must deliver. AF2 day-1 must hit all 15.

**Key insight quoted verbatim** (CAPABILITY_SPEC.md line 9): *"~90% of the effort building this framework was compensating for unreliable agent behavior — not solving the actual development problems. Most of the complexity (behavioral tests, redundant instruction files, reinforcement layers, pre-commit gates) exists because agents kept not doing what they were told."*

This is the strongest articulation of the v5 thesis. AF2 succeeds if it delivers all 15 capabilities at materially lower implementation complexity than v0.7x by routing enforcement to git-layer/topology rather than fighting unreliable agents in-session.

### The 15 required capabilities × v5 mechanism mapping

| # | Capability (from CAPABILITY_SPEC.md) | v5 Mechanism (also AF2 day-1) |
|---|---|---|
| 1 | **Session Continuity** | JSONL transcripts (R-007) + FEATURES.md/contracts/JOURNAL git-tracked + plan re-loads |
| 2 | **Spec-Driven Development** | YAML contracts with structural+behavioral assertions; AC priority via persona/platform; `ag contract → tests scaffold` (R-108) for ATDD |
| 3 | **Atomic Delivery** (spec+code+tests+docs together) | Tier 0 pre-commit close-out gate (R-001) blocks if any artifact stale |
| 4 | **Autonomy Profiles** (Hands-on / Guided / Autonomous) | 3 profiles (discovery/formal/autonomous_formal) + 3 modes (ADR-002 Tech Lead / Visionary / Fully Autonomous) as init shortcuts |
| 5 | **Configurable Review Points** | Per-gate setting: `review_plan`, `review_code`, `review_commit`, `review_merge` ∈ {human, critical_agent, skip}; Tier 2 critic per-gate |
| 6 | **Ordered Backlog** | BACKLOG.json + `ag backlog` (preserved); `ag implement` enforces position 0; this redesign-backlog.md is itself an example |
| 7 | **Adversarial Plan Review** | Tier 2 Sonnet-fresh-context critic on every plan (R-204); critic prompt explicitly adversarial; default-on in formal+ |
| 8 | **Spec Contracts & Migration** | YAML contract `lifecycle: shipped` + `protection: contract`; pre-commit blocks edits without `migrations:` entry; `ag contract migrate` is sanctioned mutation path |
| 9 | **Autonomous Workflows** | Tier 3 Agent Teams (`--teams` flag for any task; default-on in Mode 3); `ag auto verify --loop` (R-530); framework verification meta-loop (R-531) |
| 10 | **Context Efficiency** | Anatomy PreToolUse:Read hook (R-103) + Token Ledger visible (R-101) + summary-only subagent return + per-topic memory @include (R-111) |
| 11 | **Multi-Agent Safety** | Worktree isolation (Anthropic Agent tool primitive); Agent Teams file-locking on shared task list; sentinel-based session signals via JSONL events |
| 12 | **Quality Gates** | Tier 0 pre-commit (R-001) + pre-push (R-002); F-008 stack-aware quality_checks.sh; small-batch enforcement at git layer |
| 13 | **Documentation Co-Evolution** | Tier 0 pre-push doc-freshness drift check; `ag intel sync F-XXX` (R-523) per-feature synchronicity reporter |
| 14 | **Idea-to-Ship Pipeline** | `ag kickoff` → BACKLOG → `ag plan` → `ag implement` → `ag verify` → `ag done`. Each stage has gate; runs manually step-by-step or autonomously via `ag auto epic` |
| 15 | **Project Kickoff** | `ag kickoff "vision"` (R-510): vision → epic decomposition → ACs → ordered backlog. Reviewed via Tier 2 critic before commit |

**All 15 covered.** Both v5 transform and AF2 greenfield satisfy CAPABILITY_SPEC.md. The differences are in implementation effort, not in what gets delivered.

### CAPABILITY_SPEC.md design constraints (must preserve)

- Spec → AC → Code → Test → Docs ordering is non-negotiable (Tier 0 enforces)
- Shipped specs are contracts — changes require migrations (Tier 0 + Tier 2 enforces)
- "Done" is measurable via acceptance criteria, not vibes (`ag contract check` enforces)
- Users choose involvement level per review point (configurable review_* settings)
- Session state must survive context resets (JSONL + git-tracked artifacts)
- One feature at a time prevents chaos (ordered backlog + close-out gate)
- Small batches (5–10 files) keep changes reviewable (Tier 0 enforces via pre-commit complexity check)



### From `OVERVIEW.md` — Core capabilities (15 shipped, 1 not)

✓ Two profiles: Discovery (lightweight, exploratory) and Formal (spec-driven, gated)
✓ Instruction files auto-generated for Claude Code, Cursor, Copilot, Codex
✓ State files (STATUS.md, JOURNAL.md, HUMAN_NEEDED.md) for session continuity
✓ Pre-commit quality gates (complexity limits, staleness checks, branch policy)
✓ Token-efficient scripts for state management (journal.sh, status.sh, etc.)
✓ Feature tracking with acceptance criteria gates
✓ YAML contract specifications with machine-verifiable assertions
✓ Declarative workflow definition (state_machine_af.yaml) with 10-state lifecycle
✓ Optional design phase with dialectical plan review (Critic/Advocate agents)
✓ Upgrade path (upgrade.sh) preserving user customizations
✓ Project-specific customization layer (.agentic/local/) with auto-sync during upgrades — **NOTE: never actually scaffolded; aspirational; AF2 should ship it for real or drop the claim**
✓ Settings system with profile-aware defaults
✓ Configurable Definition of Done per task type (implementation/spike/bugfix/docs)
✓ DRY state-file config (state-files.conf)
✓ Automated behavioral tests for agent compliance (107 LLM tests in tests/llm/)
✓ Intelligence engine: enforced patterns, project memory, file anatomy, quality checklists, test strategies, phase-aware queries
✓ Quality knowledge system (F-008): 21 files (7 universal + 14 stack-specific) with auto-generated enforcement via `ag quality setup`
✗ Online documentation site (never built; AF2 likely also skips)

### From `FEATURES.md` — 42 shipped/in-progress features across 13 categories

**Core Workflow (9):** F-001 init/profiles, F-002 spec-driven dev, F-003 feature lifecycle, F-007 dev constraints, F-008 quality standards, F-009 pre-commit gates, F-015 sessions, F-017 multi-agent coord, F-019 token efficiency

**Quality (6):** F-008 quality standards (above), F-011 ADRs, F-012 doc lifecycle, F-014 review checkpoints, plus quality knowledge layers

**Multi-Agent (4):** F-017 coord, F-018 coord server, F-037 MCP coord (deprecated), F-038 multi-repo umbrella (deprecated)

**Autonomous (3):** F-029 autonomous_formal profile, F-030 autonomous engine, F-039 full autonomous scheduling (deprecated/consolidated)

**Architecture (4):** F-022 framework arch & paths, F-031 spec system overhaul (YAML contracts), F-033 customization layer, F-036 workflow definition file

**Git Workflow (2):** F-024 PR mgmt, F-035 protected main support

**Developer Experience (5):** F-021 cross-platform, F-026 dev docs, F-027 emergency quick reference, F-040 app-store publishing (planned), F-043 personas/platforms

**Recovery / Session (2):** F-016 crash recovery, F-015 sessions (above)

**Tooling (2):** F-020 upgrade & versioning, F-028 user extensions (deferred)

**Dev Infrastructure (4):** DEV-001 dev infra, DEV-002 testing, DEV-003 instruction integrity, DEV-004 complexity tier experiments

**Design Principles (1):** F-007 (above)

**Agent System (1):** F-025 agent system & instructions

**Plus consolidated/legacy:** F-032 plan-derived work items, F-041 intelligence engine, F-042 universal capability catalog

### From `HOW_IT_WORKS.md` (87KB) — Mechanics that must continue working

- The Big Picture diagram (3-layer architecture: Constitution / Playbooks / State)
- Backlog / Work Queue (`ag backlog` CLI)
- Autonomous Workflow Modes: Verify / Task / Crunch
- Three-Tier Trust Model
- Context Window Management in Autonomous Sessions
- Intelligence Engine (v0.77.0) — `ag intel`, project memory, file anatomy
- Coordination Server (v0.53.0) — HTTP JSON-RPC, port 4185, bearer auth, 13 coordination tools
- Formal Feature State Machine (v0.47.0) — 10-state lifecycle
- v2 Workflow Engine (Phases 1–3 — already partially deleted; AF2 inherits the simplified hooks-first design, not the v2 engine itself)
- Principle-by-Principle Breakdown: F1 DX, F2 Quality, F3 Token efficiency, D1 Human-Agent Partnership, D2 Deterministic Enforcement, D3 Durable Artifacts, D4 Small Batches
- The Enforcement Architecture (Three Layers × Three Enforcement Tiers)
- The `ag.sh` Gateway
- Task-Specific Quality Standards (7 quality documents)

### Missing-but-aspirational items (from `OVERVIEW.md` checklist + research docs)

- **`.agentic/local/` customization layer** (F-028 AC-003) — promised; never scaffolded; AF2 should ship it on day 1 or drop the claim
- **Online documentation site** — never built; AF2 likely skips
- **Vision-to-backlog (`ag kickoff`)** — partially shipped; AF2 ships complete version (v5 R-510)
- **`ag preview`** — never shipped; AF2 ships day-1 (v5 R-511)
- **Feedback-from-running-software pipeline** — never shipped; AF2 ships day-1 (v5 R-512)
- **`ag deploy` (web)** — never shipped; AF2 ships day-1 (v5 R-540…R-543)
- **Regulatory compliance modules** (GDPR/CCPA/HIPAA/SOC2) — never shipped; AF2 ships day-1 (v5 R-544…R-546)
- **Localization workflow** — never shipped; AF2 ships day-1 (v5 R-547)
- **Crash reporting integration** — never shipped; AF2 ships day-1 (v5 R-548)
- **Game/itch.io publishing** — never shipped; AF2 ships day-1 (v5 R-549)
- **`ag onboard`** — never shipped; AF2 ships day-1 (v5 R-011)
- **Hot-fix mode (`ag fix`)** — never shipped; AF2 ships day-1 (v5 R-010)
- **Token Ledger visible** — never shipped (F-041 Phase 2 abandoned); AF2 ships day-1 (v5 R-101)
- **Anatomy PreToolUse:Read hook** — never shipped (F-041 Phase 2 abandoned); AF2 ships day-1 (v5 R-103)
- **`ag tui` Textual mission-control dashboard** — never shipped; AF2 ships day-1 (v5 R-008)

---

## Section 2: AF2 architecture from day 1

AF2 inherits v5's four-tier architecture **but assembles it without legacy**. Concrete differences from transform-in-place:

### Repo layout (clean from day 1)

```
agentic-af-2/
├── CLAUDE.md                        # ~80 lines max; constitutional only
├── .claude/
│   ├── settings.json                # Declarative hooks + permission rules (NO bash chains)
│   ├── skills/                      # ~15 skills, JIT context-providers (NOT rule-deliverers)
│   ├── agents/
│   │   ├── critic-{haiku,sonnet,opus}.md   # Tier 2 critic ladder
│   │   ├── verifier-deterministic.md       # Tier 2 harness verifier
│   │   ├── doc-drafter-haiku.md
│   │   ├── bulk-refactor-aider.md
│   │   └── teammates/
│   │       ├── planner.md / coder.md / critic.md / verifier.md
│   │       └── (domain-specific roles per project)
│   └── rules/                       # Path-scoped rules, lazy-loaded
├── .agentic/                        # AF2 substrate
│   ├── lib/
│   │   ├── contracts.py             # Spec/contract verifier
│   │   ├── gates.py                 # Tier 0 gate functions
│   │   ├── events.py                # JSONL append-only writer
│   │   ├── critic.py                # Tier 2 critic dispatch
│   │   ├── teams.py                 # Tier 3 Agent Teams orchestration
│   │   ├── quality.py               # Stack-aware quality generator
│   │   ├── quality_knowledge/       # 21+ files (preserved from v0.7x)
│   │   ├── delegation_policy.yaml   # Per-task → worker mapping
│   │   ├── anatomy.yaml             # File-anatomy index
│   │   └── hooks/                   # 4–6 small Python hook scripts
│   │       ├── precommit_gate.py
│   │       ├── prepush_gate.py
│   │       ├── stop_gate.py
│   │       ├── anatomy_inject.py
│   │       └── delegation_router.py
│   ├── tui/                         # Textual mission-control + extensions
│   ├── spec/
│   │   ├── FEATURES.md
│   │   ├── contracts/F-XXXX.yaml    # YAML-only; no legacy spec/acceptance/F-XXXX.md
│   │   ├── nfr/NFR-XXXX.yaml        # Same shape as feature contracts
│   │   ├── personas.yaml
│   │   ├── platforms.yaml
│   │   └── adr/ADR-XXX.md
│   ├── session/                     # Sentinels (gitignored)
│   ├── journal/
│   │   ├── events.jsonl             # Append-only canonical event log
│   │   ├── delegation.jsonl
│   │   ├── token-ledger.jsonl
│   │   └── plans/YYYY-MM-DD-F-XXXX-plan.md
│   ├── memory/                      # Per-topic + @include index
│   ├── local/                       # **First-class customization layer (the one we promised)**
│   │   ├── extensions/              # User-defined gates, hooks, skills
│   │   ├── overrides/               # Per-project overrides for built-in behavior
│   │   └── compliance/              # Per-project compliance configs (which modules to enable)
│   └── deploy/                      # Stack-specific deploy adapters
├── .git/hooks/                      # Pre-commit + pre-push shims
├── .github/workflows/               # Optional CI mirror
├── docs/
│   └── ARCHITECTURE.md              # The v5 plan formalized
├── ag                               # Single Python entrypoint, ~600 lines
└── ag-tui                           # Optional Textual TUI binary
```

### Spec format from day 1: YAML only

No `spec/acceptance/F-XXXX.md` legacy format. Single canonical YAML contract per feature. Includes:
- Identity: id, name, lifecycle, version
- Description
- Personas (which user types this serves)
- Platforms (web / mobile / CLI / desktop / cross-cutting)
- NFR refs
- Assertions: `structural` (machine-verifiable) and `behavioral` (LLM-judged or integration-test-judged)
- `user_input` field (control plane for human-to-spec change requests)
- Migrations array (audit trail for shipped contracts)
- Optional `metadata`: expected_cost, cost_ceiling, expected_complexity

### `ag` CLI surface (target: ~25 commands, vs v0.7x ~37+)

**Workflow (8):** start, transition, check, verify, done, implement, plan, commit
**Contract (5):** check, coverage, pending, validate, migrate
**Phase / backlog (3):** backlog, kickoff, decompose
**Autonomy (3):** auto (task|epic|crunch), delegate, review
**Intel (1):** intel (architecture|spec|implement|test|sync|report)
**Quality (1):** quality (setup|run|status)
**Deploy / publish (2):** deploy, publish
**Compliance (1):** compliance (gdpr|ccpa|hipaa|soc2)
**Onboarding / handoff (2):** onboard, handoff
**Maintenance (3):** hooks, integrity, upgrade
**Observability (2):** tui, watch, dashboard

Removed from v0.7x: `wip`, `coord` (subsumed by Tier 3 Agent Teams), `mcp` (subsumed; only kept if genuine external service exists)

### Profiles + modes from day 1

**Profiles:**
- `discovery` — exploratory (Tier 0+1 always, Tier 2 opt-in, Tier 3 off)
- `formal` — production code (Tier 0+1+2 default, Tier 3 opt-in via `--teams`)
- `autonomous_formal` — autonomy-supported (Tier 0+1+2 default, Tier 3 default-on for Mode 3)

**Modes (init shortcuts, not persisted):**
- Mode 1 Tech Lead — formal profile, human reviews everything
- Mode 2 Product Visionary — autonomous_formal, human at vision/taste/architecture only
- Mode 3 Fully Autonomous — autonomous_formal, Tier 3 always-on

### What AF2 explicitly drops vs v0.7x

- `.agentic/spec/acceptance/F-XXXX.md` legacy format (YAML-only)
- `AGENTS.json` + `agents_helpers.py` + `wip.sh` (use JSONL transcripts)
- Most of `.agentic/lib/tools/*.sh` (declarative hooks instead)
- MCP coordinator as custom dispatch (only if genuine external service)
- v2 state-machine engine (already removed in v0.7x; AF2 inherits hooks-first)
- Three trigger-word tables across CLAUDE.md / memory-seed / cursorrules / copilot / codex (single source: skill descriptions + permission rules)
- Bash hook-approximation scripts (replaced by 4–6 Python hooks)
- Cross-tool D7 parity claim (replaced by "state portable, enforcement Claude-first")

---

## Section 3: How to start AF2 from scratch

If the user commits to greenfield, this is the day-1 procedure:

### Day 1 — Repo + scaffolding

1. `mkdir agentic-af-2 && cd agentic-af-2 && git init`
2. Create the repo layout from Section 2 (empty directories + skeleton README)
3. Copy these from v0.7x verbatim (irreducible value):
   - `.agentic/lib/quality_knowledge/*` (21 files)
   - `.agentic/lib/contracts.py` (YAML loader + verifier)
   - `.agentic/lib/schemas/contract.schema.json` (extend with platforms/personas)
   - `.agentic/spec/contracts/*.yaml` (existing YAML contracts; rename if redesigning IDs)
4. Write `CLAUDE.md` (~80 lines) — constitutional only
5. Write `docs/ARCHITECTURE.md` — formalize the v5 four-tier architecture
6. First commit: "AF2 day-1 scaffolding"

### Days 2–5 — Sprint 1 (same as v5 first sprint)

7. Implement R-007 (JSONL event spine)
8. Implement R-001 (precommit_gate.py) — but cleaner without legacy compat
9. Implement R-002 (prepush_gate.py)
10. Implement R-008 (`ag tui`)

### Weeks 2–6 — Phase 0 + Phase 1 in parallel (no transition risk)

Greenfield's advantage materializes here: **no need to dual-run old + new during transition** (Phase 3 in transform plan). AF2 just builds the new stack directly.

Effort estimate: **~24–32 weeks solo** for AF2 (vs 32–44 for transform-in-place). Greenfield saves ~8–12 weeks because:
- No `ag upgrade --from=v0.7x` migration path needed
- No regression-test parity for deleted modules
- No "drop bash hook chains" Phase 3 separately
- No compatibility shims during transition

### Migration tool for v0.7x users (if any)

If existing v0.7x users need to migrate to AF2:
- Provide `ag2 migrate-from-v0.7x` — one-way conversion script
- Converts AGENTS.json → events.jsonl
- Converts spec/acceptance/F-XXX.md → spec/contracts/F-XXX.yaml
- Updates hook references
- **Documented as one-way; no rollback path** (clean break is the point of greenfield)

---

## Section 4: Decision criteria — when to switch from transform to greenfield

Even if transform-in-place is the chosen path now (2026-04-26), reasons to switch to greenfield mid-flight:

1. **Phase 0/1 reveals the operational-harness simplification (Phase 3) is more painful than expected.** If too many edge cases surface in the bash-to-declarative migration, abandoning legacy is faster.
2. **Anthropic Agent Teams takes a hard incompatible turn.** If the API shifts in Phase 4 in a way that breaks legacy assumptions, AF2 starting fresh is cleaner.
3. **The cross-tool D7 abstraction layer has hidden compatibility cost** that surfaces in Phase 0/1. AF2 can drop it from day 1.
4. **A new spec format insight emerges** — e.g., consolidating FEATURES.md + contracts + NFRs into a single schema. Legacy migration is painful; greenfield is clean.
5. **User-facing pain in v0.7x base accumulates** during the 32-week transform window faster than the transform delivers fixes. Restart is then cheaper.

The transform plan is reversible: at any phase boundary, the user can pivot to greenfield and lift the work-in-progress (especially Phases 0–2 deliverables: hooks, TUI, critic dispatch are reusable).

---

## Section 5: Cross-references

- **v5 plan:** `/workspace/.agentic/journal/plans/2026-04-26-framework-ground-up-redesign-plan.md`
- **v5 backlog:** `/workspace/.agentic/journal/plans/2026-04-26-redesign-backlog.md`
- **v5 refinement:** `/workspace/.agentic/journal/plans/2026-04-26-todo-backlog-refinement.md`
- **Spike report:** `/workspace/docs/research/2026-04-26-pre-phase-0-spike-results.md`
- **Sibling research:** `/workspace/docs/research/2026-04-25-swarm-orchestration-and-close-out-hardening.md`
- **Capability sources surveyed:** `/workspace/docs/CAPABILITY_SPEC.md` (authoritative — 15 capabilities + design constraints), `/workspace/.agentic/spec/FEATURES.md` (42 shipped/planned features across 13 categories), `/workspace/.agentic/OVERVIEW.md` (16 core capabilities), `/workspace/docs/HOW_IT_WORKS.md` (87KB; 50+ section outline), `/workspace/FRAMEWORK_QUICK_START.md`, `/workspace/FRAMEWORK_DEVELOPMENT.md`

---

## Final note

This greenfield path is **not currently being executed**. It exists so a future fresh-start decision has a complete blueprint without re-doing 30+ turns of architectural work. If the transform-in-place path runs into structural blockers in Phases 0–2, this document gives the user a clean exit option with the day-1 procedure already specified.

The chosen path remains: **transform in place across 5 phases, ~32–44 weeks solo. Phase 0 unblocked.**
