# Intelligence Engine: Core Framework Value Proposition

**Status**: APPROVED
**Feature**: F-041 (Intelligence Engine)
**Date**: 2026-04-02
**Review**: Dialectical review completed 2026-04-02. Critic + Advocate converged with revisions below.

## Context

**The framework's value is twofold**:
1. **Structural enforcement** (gates, specs, workflow) → prevents bad outcomes
2. **Intelligence** (domain knowledge, quality checks, token awareness) → produces BETTER outcomes than vanilla Claude

Today we're strong on #1 but weak on #2. This plan makes intelligence a first-class system — not an enhancement, but a core pillar equal in importance to the workflow engine.

**Design constraints**:
- Must work naturally in **Discovery mode** (no dependency on formal specs)
- Must work with **any tech stack** (domain-specific via bootstrap, not hardcoded)
- **Claude Code gets the best experience** (automatic hooks), other tools get CLI + instruction guidance
- Must be **measurable** (token ledger proves value to users)

---

## Part 1: What Makes This Better Than Vanilla Claude

| Scenario | Vanilla Claude | With Intelligence Engine |
|---|---|---|
| **New project** | Generic advice, discovers stack conventions mid-session | Bootstrap generates stack-specific patterns, quality rules, test strategy at init |
| **Planning architecture** | Reads random files, misses constraints | Surfaces ADRs, NFRs, existing architecture, domain quality checklist |
| **Writing specs** | Generic ACs, may duplicate features | Shows overlapping features, shipped AC patterns, NFR constraints, domain usability checklist |
| **Writing tests** | Explores test dir ad-hoc | Shows test strategy, infra, helpers, known bugs, coverage gaps, test quality rules |
| **Implementing code** | May reinvent utilities, forget conventions | Injects conventions, reusable code, anti-patterns, domain code quality checklist |
| **Reading files** | Reads everything, wastes tokens on large files | Pre-read hint: "~1200 tok, Express middleware config" — agent can skip |
| **Writing code** | May repeat known mistakes | Pre-write pattern check: "Do-Not-Repeat: Hook stdout is JSON only" |
| **Session cost** | No visibility | Token ledger: "This session: 42K tokens, 12 repeated reads prevented, estimated $X saved" |
| **Over time** | Same quality session after session | Retro identifies recurring issues → new patterns → continuously improving intelligence |

---

## Part 2: Five Core Components

### Component 1: Anatomy — File Intelligence

**What**: Machine-readable index of every project file: summary, token estimate, language, related files.

**Why**: The single biggest token waste is unnecessary file reads. Claude reads files it doesn't need, or re-reads files it already read. Anatomy provides the metadata to make informed read decisions.

**Files**:
- `.agentic/intel/anatomy.yaml` — the curated file index (git-tracked, updated deliberately by `ag intel scan`)
- `.agentic/intel/anatomy.index` — flat key-value format for fast hook lookup (gitignored, regenerated from anatomy.yaml at session start)

**Integration**:
- PreToolUse:Read hook (Claude Code): injects summary + token estimate before every file read
- Repeated-read tracking: session-level counter warns on 3rd+ read of same file
- `ag intel file PATH`: manual query (any tool)

**Discovery mode**: Works identically. File intelligence is profile-agnostic.

### Component 2: Patterns — Enforced Learning

**What**: Machine-matchable rules with scope globs. Do-Not-Repeat (mistakes to avoid), conventions (patterns to follow), and positive patterns (approaches that worked).

**Why**: Passive memory (LESSONS.md, Claude auto-memory) relies on the agent reading and remembering. Active pattern enforcement via hooks catches mistakes at write-time, structurally.

**Files**:
- `.agentic/intel/patterns.yaml` — the pattern database (git-tracked, curated)

**Integration**:
- PreToolUse:Write hook (Claude Code): checks patterns matching the file's scope before every write
- `ag intel learn "X" --reason "Y" --scope "*.py"`: add patterns from corrections
- `ag intel check PATH`: manual pattern query (any tool)
- Bootstrap seeds initial patterns from STACK.md analysis
- Retro adds patterns from recurring issues

**Discovery mode**: Works identically. Learning from mistakes is profile-agnostic.

### Component 3: Quality Checklist — Multi-Dimensional Quality Intelligence

**What**: Domain-specific quality checks organized by **dimension** (usability, architecture, code quality, testability, spec adherence) crossed with **workflow phase** (planning, spec, implementation, testing). Generated from the project's stack by bootstrap, curated by the user.

**Why**: This is what makes the framework smarter than vanilla Claude on every quality dimension. A React e-commerce app gets "check ARIA attributes" and "verify payment error states." A Python API gets "check rate limiting" and "verify input validation." Domain-specific, not generic.

**Files**:
- `.agentic/intel/quality-checklist.yaml` — quality checks per dimension × phase (git-tracked)

**Format**:
```yaml
version: 1
source: bootstrap  # or "manual" or "retro"
stack: "react + typescript + e-commerce"
dimensions:
  usability:
    planning:
      - "Accessibility strategy defined (WCAG level)"
      - "Error states designed for all user flows"
      - "Loading/empty states considered"
    spec:
      - "ACs include screen reader behavior for interactive elements"
      - "ACs cover loading, error, and empty states"
    implementation:
      - "ARIA attributes on all interactive elements"
      - "Keyboard navigation works for all flows"
      - "Error messages are user-friendly, not technical"
      - "Images have meaningful alt text"
    testing:
      - "axe-core accessibility checks in component tests"
      - "Keyboard-only navigation tested"
  architecture:
    planning:
      - "Component boundaries and responsibilities clear"
      - "State management strategy documented"
      - "API layer separated from UI components"
    spec:
      - "NFRs addressed: performance, security, scalability"
    implementation:
      - "No circular imports between modules"
      - "Proper separation of concerns (data/logic/presentation)"
      - "New dependencies justified (bundle size impact)"
    testing:
      - "Integration tests cover component boundary contracts"
  code_quality:
    implementation:
      - "Follows project conventions (conventions.md)"
      - "No magic numbers — use named constants"
      - "Error handling is consistent with project patterns"
      - "Functions are focused (<50 lines)"
    testing:
      - "Tests are readable: arrange/act/assert structure"
  testability:
    planning:
      - "Test strategy defined for this feature"
    spec:
      - "Every AC is testable and measurable"
    implementation:
      - "Pure functions where possible for easy unit testing"
      - "External dependencies injected, not hardcoded"
    testing:
      - "Tests verify behavior, not implementation details"
      - "No flaky patterns (no setTimeout, no race conditions)"
  spec_adherence:  # Formal-only items marked, rest works in Discovery
    planning:
      - "Plan references all relevant ACs [formal]"
      - "Clear problem statement exists"
    spec:
      - "ACs are specific and measurable [formal]"
      - "Success criteria defined"
    implementation:
      - "Every AC has corresponding implementation [formal]"
      - "Implementation matches stated intent"
    testing:
      - "Every AC has at least one test [formal]"
      - "Key behaviors verified"
```

**Integration**:
- `ag intel architecture` includes quality-checklist.planning items from architecture + usability dimensions
- `ag intel implement F-XXXX` includes quality-checklist.implementation items from all dimensions
- `ag intel test F-XXXX` includes quality-checklist.testing items from all dimensions
- Items marked `[formal]` only shown when profile is formal/autonomous_formal

**Discovery mode**: All non-`[formal]` items work naturally. Discovery gets "Clear problem statement exists" instead of "ACs are specific and measurable." Same dimensions, lighter touch.

### Component 4: Test Strategy — Stack-Aware Testing Guidance

**What**: Testing approach tailored to the project's tech stack: what to test at each level (unit/integration/E2E), which frameworks to use, what anti-patterns to avoid.

**Why**: Test quality is one of the most impactful things the framework can improve. Agents writing tests without domain context produce generic, low-value tests. Stack-aware guidance produces tests that actually catch bugs.

**Files**:
- `.agentic/intel/test-strategy.yaml` — testing approach per level (git-tracked)

**Format**:
```yaml
version: 1
source: bootstrap
stack: "react + typescript"
levels:
  unit:
    focus: "Business logic, custom hooks, utility functions"
    framework: "vitest"
    colocate: true  # tests next to source files
    patterns: ["Test pure functions directly", "Mock only external boundaries"]
    antipatterns: ["Mocking internal modules", "Testing implementation details"]
  component:
    focus: "UI behavior, user interactions, accessibility"
    framework: "React Testing Library + vitest"
    patterns: ["Test what users see and do", "Use role/label selectors"]
    antipatterns: ["Snapshot-only tests", "Testing className changes", "No accessibility assertions"]
  integration:
    focus: "API routes, data flows, auth"
    framework: "MSW for API mocking"
    patterns: ["Test complete user flows without real backend"]
  e2e:
    focus: "Critical user paths"
    framework: "Playwright"
    patterns: ["Happy path + top 3 error scenarios minimum"]
    antipatterns: ["Testing everything E2E (slow, flaky)"]
```

**Integration**:
- `ag intel test F-XXXX` returns test strategy alongside test infra and known bugs
- Helps agents choose the RIGHT test level for what they're testing
- Prevents common anti-patterns specific to the stack

**Discovery mode**: Works identically. Good testing doesn't depend on formal specs.

### Component 5: Token Ledger — Measurement & Optimization

**What**: Per-session and aggregated metrics tracking token usage, waste prevention, and intelligence effectiveness.

**Why**: "What gets measured gets managed." Users need to see the framework's value in concrete numbers. And the framework needs data to optimize its own intelligence (which files need better anatomy? which patterns catch the most issues?).

**Files**:
- `.agentic/session/token-ledger.json` — current session metrics (gitignored)
- `.agentic/intel/token-summary.json` — aggregated stats across sessions (git-tracked)

**Session ledger format**:
```json
{
  "session_id": "2026-04-02-abc",
  "started": "2026-04-02T10:00:00Z",
  "reads": {
    "total": 45,
    "unique_files": 28,
    "repeated": 17,
    "repeated_warned": 12,
    "tokens_estimated": 52000,
    "skipped_after_anatomy": 5
  },
  "writes": {
    "total": 12,
    "tokens_estimated": 8400,
    "patterns_checked": 12,
    "patterns_warned": 3
  },
  "intel_queries": {
    "architecture": 1,
    "implement": 3,
    "test": 2,
    "file": 45
  }
}
```

**Aggregated summary** (updated at session end):
```json
{
  "total_sessions": 47,
  "total_reads": 2100,
  "total_repeated_prevented": 780,
  "total_tokens_estimated": 2400000,
  "average_session_tokens": 51000,
  "top_read_files": ["src/index.ts", "package.json", "tsconfig.json"],
  "pattern_catches": 45,
  "last_updated": "2026-04-02"
}
```

**Integration**:
- PostToolUse:Read hook → increment read counters, estimate tokens
- PostToolUse:Write hook → increment write counters, estimate tokens
- PreToolUse:Read hook → track anatomy effectiveness
- PreToolUse:Write hook → track pattern effectiveness
- Stop hook → finalize session, update aggregated summary
- Dashboard → show session and lifetime metrics at start

**Discovery mode**: Works identically. Token efficiency is profile-agnostic.

---

## Part 3: Bootstrap & Retro — Knowledge Generation

### `ag intel bootstrap` (project init or on-demand)

**Input**: STACK.md (language, framework, domain, deployment, database)

**Process**:
1. Read STACK.md for stack details
2. Use Claude to generate domain-specific intelligence:
   - "For a {language} + {framework} project in the {domain} domain, generate: (a) 10 common anti-patterns, (b) quality checklist across usability/architecture/code/test/spec dimensions, (c) testing strategy per level, (d) 5 NFR suggestions"
3. Present all generated content for user review
4. User approves/edits/rejects each section
5. Approved content written to: patterns.yaml, quality-checklist.yaml, test-strategy.yaml
6. NFR suggestions routed to `ag nfr` workflow (existing)

**User experience**:
```
$ ag intel bootstrap

Reading STACK.md... detected: TypeScript + React + Next.js, domain: e-commerce

Generating domain-specific intelligence...

=== Patterns (10 generated) ===
P-STACK-001: Don't use `any` type (defeats TypeScript) [*.ts,*.tsx]
P-STACK-002: Don't mutate state directly in React [*.tsx]
...

=== Quality Checklist (24 items across 5 dimensions) ===
[Preview shown]

=== Test Strategy ===
Unit: vitest, Component: RTL, Integration: MSW, E2E: Playwright

=== NFR Suggestions (5) ===
NFR-P001: Page load <3s
NFR-P002: WCAG 2.1 AA accessibility
...

Accept all? [Y/n/edit]
```

### `ag intel retro` (periodic or on-demand)

**Input**: ISSUES.md, LESSONS.md, shipped features, patterns.yaml (existing patterns)

**Process**:
1. Analyze bugs/issues: find recurring themes
2. Analyze lessons: extract patterns not yet in patterns.yaml
3. Compare quality checklist against actual issues: identify gap dimensions
4. Suggest: new patterns, quality checklist additions, NFR updates
5. Present for user review

**Tied to existing workflow**: Can be triggered by `ag retro` or integrated into periodic health checks at session start.

---

## Part 4: The `ag intel` Command — Unified Interface

```bash
# === Phase-Aware Intelligence (for skills + manual use) ===
ag intel architecture          # ADRs + NFRs + patterns + quality-checklist[planning]
ag intel spec F-XXXX           # Overlapping features + AC patterns + quality-checklist[spec]
ag intel implement F-XXXX      # Conventions + lessons + quality-checklist[implementation] + active spec
ag intel test F-XXXX           # Test strategy + infra + bugs + quality-checklist[testing] + coverage gaps

# === Per-File Intelligence (for hooks + manual use) ===
ag intel file PATH             # Anatomy: summary, tokens, related files
ag intel check PATH            # Pattern check: matching rules for this file's scope

# === Knowledge Generation ===
ag intel bootstrap             # Generate domain intelligence from STACK.md
ag intel retro                 # Analyze issues/lessons → suggest new patterns

# === Maintenance ===
ag intel scan                  # Regenerate anatomy.yaml
ag intel scan --check          # Verify freshness (exit 1 if stale, for CI)
ag intel learn "X" --reason "Y" --scope "*.py"   # Add enforced pattern
ag intel patterns [--scope PATH]                  # List active patterns

# === Metrics ===
ag intel stats                 # Show token metrics (session + lifetime)
ag intel stats --session       # Current session only
```

---

## Part 5: Hook Integration (Claude Code — Automatic)

### PreToolUse.sh — Intelligence Before Action

**Read path** (new, pure bash, <100ms):
```
Before reading: .agentic/lib/gate.py
→ "~1140 tok | Policy enforcement engine — allow/deny decisions with reasons | Related: state_machine.py, PreToolUse.sh"
→ [Read 2x this session — consider if you need to re-read]
```

**Write path** (enhanced, pure bash, <50ms):
```
Before writing: .agentic/lib/claude-hooks/PreToolUse.sh
→ ⚠️ P003: "Hook stdout is JSON only — no debug prints to stdout" [.agentic/lib/claude-hooks/*]
```

### PostToolUse.sh — Learning After Action

**Read tracking** (new):
- Increment session read counter for the file
- Update token ledger (estimated tokens for this read)

**Write tracking** (new):
- Update anatomy.yaml entry for the modified file (async, non-blocking)
- Update token ledger (estimated tokens for this write)

### Stop.sh — Session Summary

- Finalize token ledger
- Update aggregated token-summary.json
- Log: "Session: 42K tokens estimated, 12 repeated reads prevented"

---

## Part 6: Skill Integration (All Tools)

Each workflow skill gets a ~3-line addition instructing the agent to query intelligence:

| Skill | Added Instruction |
|---|---|
| `planning-features` | "Run `ag intel architecture` to surface ADRs, NFRs, quality checklist for planning phase" |
| `writing-specs` | "Run `ag intel spec F-XXXX` to see overlapping features, AC patterns, spec quality checks" |
| `writing-tests` | "Run `ag intel test F-XXXX` to see test strategy, infra, bugs, quality checks for testing" |
| `implementing-features` | "Run `ag intel implement F-XXXX` to see conventions, quality checks, active spec context" |

For non-Claude tools: instruction file trigger tables get `"intelligence/context/quality checks" → ag intel <phase>`.

---

## Part 7: Cross-Tool Compatibility

| Capability | Claude Code | Cursor | Others |
|---|---|---|---|
| **Pre-read file hint** | ✅ Automatic (hook) | ❌ Cannot do | ❌ Cannot do |
| **Pre-write pattern check** | ✅ Automatic (hook) | ❌ Cannot do | ❌ Cannot do |
| **Token ledger tracking** | ✅ Automatic (hooks) | ❌ Cannot do | ❌ Cannot do |
| **Phase intelligence** | ✅ Skill triggers `ag intel` | ✅ `ag intel` via terminal | ✅ `ag intel` via terminal |
| **Bootstrap/retro** | ✅ `ag intel bootstrap` | ✅ Same CLI | ✅ Same CLI |
| **Quality checklist** | ✅ In phase queries | ✅ In phase queries | ✅ In phase queries |
| **Pattern management** | ✅ `ag intel learn` | ✅ Same CLI | ✅ Same CLI |
| **Metrics** | ✅ Full (hooks populate) | ⚠️ Partial (CLI queries work, no auto-tracking) | ⚠️ Partial |

Per-operation hooks are Claude Code only (architecturally impossible elsewhere). Everything else works universally via CLI. Cursor's context.sh can include `ag intel stats --session` at session start for basic awareness.

---

## Part 8: Discovery Mode — Natural Integration

Intelligence doesn't depend on formal specs. Here's how each component works in Discovery:

| Component | Discovery Behavior |
|---|---|
| **Anatomy** | Identical — file intelligence is profile-agnostic |
| **Patterns** | Identical — learning from mistakes doesn't need specs |
| **Quality checklist** | Items marked `[formal]` hidden; all other items shown. "Clear problem statement" instead of "ACs are specific and measurable" |
| **Test strategy** | Identical — good testing doesn't need formal specs |
| **Token ledger** | Identical — token efficiency is profile-agnostic |
| **Bootstrap** | Identical — generates from STACK.md, not from specs |
| **Phase queries** | `ag intel spec` returns less (no contracts to reference) but still shows overlapping features and NFRs |

**Key design**: Intelligence files (anatomy.yaml, patterns.yaml, quality-checklist.yaml, test-strategy.yaml) have NO dependency on spec artifacts. They're generated from the tech stack and accumulated from experience.

---

## Part 9: Naming Convention

All new files use **lowercase** consistently:
- `.agentic/intel/anatomy.yaml`
- `.agentic/intel/patterns.yaml`
- `.agentic/intel/quality-checklist.yaml`
- `.agentic/intel/test-strategy.yaml`
- `.agentic/intel/token-summary.json`
- `.agentic/session/token-ledger.json`

Broader CAPS→lowercase migration for existing files (STATUS.md, JOURNAL.md, etc.) is a separate task.

---

## Part 10: Files Summary

**New directory**: `.agentic/intel/`

**New files** (6):
| File | Purpose | Tracked? |
|---|---|---|
| `.agentic/lib/tools/commands/intel.sh` | `ag intel` implementation | git-tracked |
| `.agentic/intel/patterns.yaml` | Do-Not-Repeat + convention patterns | git-tracked |
| `.agentic/intel/quality-checklist.yaml` | Multi-dimensional quality checks per phase | git-tracked (generated by bootstrap, curated) |
| `.agentic/intel/test-strategy.yaml` | Stack-aware testing approach | git-tracked (generated by bootstrap, curated) |
| `.agentic/intel/anatomy.yaml` | File intelligence database (curated snapshot) | **git-tracked** (updated by `ag intel scan`, not by hooks) |
| `.agentic/intel/anatomy.index` | Flat key-value index for fast hook lookup | **gitignored** (regenerated from anatomy.yaml at session start) |
| `.agentic/intel/token-summary.json` | Aggregated token metrics | git-tracked |

**Session-scoped** (gitignored):
| File | Purpose |
|---|---|
| `.agentic/session/token-ledger.json` | Current session token metrics |

**Modified files** (~15):
- `.agentic/lib/tools/ag.sh` — add `intel` command dispatch
- `.agentic/lib/claude-hooks/PreToolUse.sh` — add Read intelligence + Write pattern check
- `.agentic/lib/claude-hooks/PostToolUse.sh` — add Read/Write tracking + anatomy update
- `.agentic/lib/claude-hooks/hooks.json` — add Read to PreToolUse matcher
- `.agentic/lib/claude-hooks/stop.sh` — add token ledger finalization
- `.claude/skills/planning-features/SKILL.md` — add `ag intel architecture`
- `.claude/skills/writing-specs/SKILL.md` — add `ag intel spec`
- `.claude/skills/writing-tests/SKILL.md` — add `ag intel test`
- `.claude/skills/implementing-features/SKILL.md` — add `ag intel implement`
- `.agentic/lib/agents/claude/CLAUDE.md` — add intel trigger words
- `.agentic/lib/agents/cursor/cursorrules.txt` — add intel trigger words
- `.agentic/lib/agents/copilot/copilot-instructions.md` — add intel trigger words
- `.agentic/lib/agents/codex/codex-instructions.md` — add intel trigger words
- `.agentic/lib/init/memory-seed.md` — add intel patterns
- `.agentic/hooks/cursor/context.sh` — add phase intelligence + stats at session start

---

## Part 11: Implementation Phases (Reordered per Review)

**Key revision from review**: Ship pattern enforcement (highest value, lowest risk) FIRST. Defer PreToolUse:Read hook (highest risk) to LAST. Each phase ships independently.

### Phase 1: Patterns + Write Hook (~1-2 days) — HIGHEST VALUE, LOWEST RISK

**Why first**: The write hook already fires. Extending it with pattern checks is minimal risk, maximum immediate value. Every code write gets checked against learned anti-patterns from day one.

1. Create `.agentic/intel/` directory
2. Create `patterns.yaml` — seed from LESSONS.md entries that have clear patterns
3. Implement `ag intel check PATH` — match patterns.yaml against file scope (pure bash)
4. Implement `ag intel learn "X" --reason "Y" --scope "glob"` — append to patterns.yaml
5. Implement `ag intel patterns [--scope PATH]` — list active patterns
6. Extend PreToolUse.sh — Write/Edit path checks patterns.yaml before writes (pure bash, <50ms)
7. Wire `intel` command into ag.sh dispatch
8. Add `upgrade.sh` migration: create `.agentic/intel/` directory
9. **Test**: learn adds patterns, check matches them, PreToolUse:Write warns on match

### Phase 2: Anatomy + Token Ledger (~2 days)

1. Implement `ag intel scan` — file walk, token estimation (char-count ratio), summary extraction → anatomy.yaml + anatomy.index
2. Implement `ag intel file PATH` — fast lookup from anatomy.index (pure bash grep)
3. Implement token ledger: session counters in `.agentic/session/token-ledger.json`
4. Implement `ag intel stats` — display session + aggregated metrics
5. Extend PostToolUse.sh — track read/write counts, estimate context cost per operation
6. Extend Stop.sh — finalize session ledger, update token-summary.json
7. **Test**: scan produces valid anatomy, file returns info, stats shows metrics
8. **Note**: anatomy.yaml + anatomy.index are gitignored. `ag intel scan --check` exits 1 if stale.

### Phase 3: Bootstrap + Quality Intelligence (~2 days)

1. Implement `ag intel bootstrap` — read STACK.md + scan actual codebase (imports, patterns, directory structure) → Claude generation → user review → write files
2. Generate: patterns → patterns.yaml, quality-checklist.yaml (5 dimensions × 4 phases), test-strategy.yaml (per test level)
3. Implement `ag intel retro` — analyze ISSUES.md + LESSONS.md + shipped features → suggest new patterns and quality checklist updates
4. Integrate bootstrap as optional step in `ag init` flow
5. **Test**: bootstrap generates useful, stack-specific content (not generic platitudes). Verify for ≥3 stacks.

### Phase 4: Phase-Aware Queries + Skill Integration (~1-2 days)

1. Implement `ag intel architecture` — reads ADRs, NFRs, CONTEXT_PACK, quality-checklist.planning
2. Implement `ag intel spec [F-XXXX]` — reads FEATURES, contracts, NFR, quality-checklist.spec (F-XXXX optional for Discovery)
3. Implement `ag intel test [F-XXXX]` — reads STACK, ISSUES, test-strategy, quality-checklist.testing
4. Implement `ag intel implement [F-XXXX]` — reads conventions, LESSONS, quality-checklist.implementation
5. All commands work with zero args in Discovery mode (no F-XXXX required)
6. Discovery-mode filtering: hide `[formal]` items, rename spec_adherence → intent_adherence in output
7. Update 4 skills with `ag intel` references
8. Update 4 instruction file templates with trigger words
9. Update memory-seed
10. Update dashboard.sh to show token metrics
11. **Test**: each query returns relevant intelligence; works in both formal and discovery profiles

### Phase 5: Read Hook + Full Integration (~1 day) — HIGHEST RISK, LAST

**Why last**: Adding `Read` to PreToolUse matcher means every file read triggers a hook. This is the highest-risk change. By deferring it, Phases 1-4 prove value without this risk.

1. Add `Read` to PreToolUse matcher in hooks.json
2. Implement Read path in PreToolUse.sh: lookup anatomy.index (pure bash grep, <100ms target)
3. Implement repeated-read tracking: session-level counter, warn on 3rd+ read of same file
4. Add `ag set intel_read_hook off` escape hatch (disable Read hook without disabling Write pattern check)
5. Extend Cursor context.sh with phase intelligence at session start
6. **Prerequisite**: F-0300 hook registration must be resolved
7. **Test**: Read hook injects anatomy hint in <100ms, repeated-read warning fires, escape hatch works
8. **Benchmark**: Measure hook latency across 50 file reads, verify <100ms p95

**If Read hook proves too slow**: Fall back to PostToolUse:Read (track and warn after the read, not before). This gives 80% of the value (repeated-read warnings, token tracking) with 0% of the latency risk on the read path.

---

## Part 12: Deferred (Build Later If Needed)

| Deferred | When to Revisit |
|---|---|
| MCP server for Cursor/others | If demand exists for on-demand intelligence queries beyond CLI |
| LLM-powered anatomy summaries | If simple extraction produces low-quality summaries |
| Spec adherence drift detection | `ag intel spec-drift F-XXXX` comparing implementation against spec |
| Predictive context loading | "Based on task description, you'll probably need these files" |
| Cost attribution | Map token usage to specific features/workflow phases |

---

## Verification Plan

**Functionality**:
1. `ag intel scan` produces valid anatomy.yaml for this repo
2. `ag intel file .agentic/lib/gate.py` returns summary, tokens, related files
3. `ag intel check .agentic/lib/claude-hooks/PreToolUse.sh` returns matching patterns
4. `ag intel learn "test" --reason "why" --scope "*.sh"` appends to patterns.yaml
5. `ag intel bootstrap` generates domain-relevant patterns + quality checklist + test strategy
6. `ag intel retro` identifies patterns from existing ISSUES.md + LESSONS.md
7. `ag intel architecture` returns ADR/NFR/quality checklist for planning
8. `ag intel spec F-XXXX` returns overlapping features + AC patterns
9. `ag intel test F-XXXX` returns test strategy + infra + quality checks
10. `ag intel implement F-XXXX` returns conventions + quality checks + active spec
11. `ag intel stats` shows session and lifetime metrics
12. Discovery mode: `ag intel implement` returns quality checks without `[formal]` items

**Hooks (Claude Code)**:
13. PreToolUse:Read injects anatomy hint in <100ms
14. PreToolUse:Write pattern check completes in <100ms
15. PostToolUse tracking updates token ledger
16. Stop hook finalizes and aggregates metrics
17. Repeated-read warning fires on 3rd+ read of same file

**Integration**:
18. validate_framework.sh still passes
19. `ag intel` CLI works standalone without Claude Code hooks
20. Dashboard shows token metrics at session start
21. Skills trigger `ag intel` at appropriate workflow phases

**Quality**:
22. Bootstrap output is useful for ≥3 different stacks (React, Python API, mobile)
23. Quality checklist items are actionable, not generic platitudes (each must reference concrete file/tool/criterion)
24. Context cost estimates within ~20% of actual character count (spot-check 10 files)

---

## Revision Guidance (from Dialectical Review)

**Accepted revisions** (integrated into plan above):
1. **Phase reordering**: Patterns + write hook first (highest value, lowest risk). Read hook last (highest risk). Each phase ships independently.
2. **anatomy.yaml tracked, index gitignored**: anatomy.yaml is git-tracked (curated snapshot, updated deliberately by `ag intel scan`). anatomy.index is gitignored (flat fast-lookup file, regenerated from anatomy.yaml at session start). PostToolUse hooks update only the index, never the tracked YAML.
3. **Honest metrics**: Call them "estimated context cost" not "tokens." Track factual data (read counts, repeated reads, file sizes). Don't claim "prevented reads" — unfalsifiable.
4. **Discovery mode zero-arg**: All `ag intel` commands work without F-XXXX in Discovery. `ag intel implement` returns conventions + quality checks for working directory.
5. **Bootstrap scans codebase**: Analyze actual imports, patterns, directory structure alongside STACK.md — not just stack metadata.
6. **conventions.md relationship clarified**: Prose guidance (conventions.md) vs machine-matchable enforcement (patterns.yaml). Complementary layers, not duplicates. patterns.yaml supplements, doesn't replace.
7. **Upgrade path**: `upgrade.sh` creates `.agentic/intel/` directory for existing projects.
8. **Read hook escape hatch**: `ag set intel_read_hook off` from day one.
9. **Read hook fallback**: If PreToolUse:Read proves too slow, fall back to PostToolUse:Read (warn after read, not before).

**Convergence**: Both Critic and Advocate agree the core design is sound. The intelligence-as-core-value positioning is correct per the framework's own F3 principle. The main risk (Read hook latency) is mitigated by deferring it to Phase 5 with a fallback plan.
