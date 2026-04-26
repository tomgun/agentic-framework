# Ground-Up KISS Redesign: Topology-First Framework for Reliable Autonomous Agents

> **Deliverable type:** Architectural blueprint, not an implementation plan.
> **Decision deferred:** Whether to transform `agentic-framework` in place or rebuild as **Agentic AF 2**.
> **Versions:**
> - v1 (initial): leaked-architecture lens
> - v2: + sibling-doc integration + cross-tool walk-back
> - v3: + abandoned-ambitions archaeology (~70 catalogued items)
> - v4: + production-gap (Theme J: GDPR, web deploy, localization, crash reporting, game publishing)
> - **v5 (this version): center-of-gravity inversion** after the empirical insight that *agents don't follow framework rules* — proven over months despite 27+ hooks, 30+ skills, 17 pre-commit gates, sentinel files, gates.py, multiple instruction files, and LLM behavioral tests. The plan is now organized around **topology + external enforcement + voluntary intelligence**, not single-agent self-enforcement.
> **Sibling document:** `docs/research/2026-04-25-swarm-orchestration-and-close-out-hardening.md` (4 rounds of agent peer review). The sibling proposed Tier 1 (close-out gate) + Tier 2 (Agent Teams) within the existing single-agent paradigm. This v5 plan accepts the sibling's empirical findings but rejects single-agent self-enforcement as a primary reliability mechanism.

---

## Context

Five evidence streams converge:

1. **The leaked Claude Code architecture** (`docs/research/2026-04-26_deep_dive_claude_architecture_2604.14228v1.pdf`, 46 pages, VILA Lab MBZUAI). Headline: ~**1.6% of the codebase is decision logic; 98.4% is operational harness**. Anthropic itself does not try to constrain the model with rules — they invest in deterministic infrastructure *around* the model.

2. **Yesterday's swarm-orchestration synthesis** (sibling doc) identified single-agent self-enforcement's structural ceiling and proposed Tier 1/Tier 2 path forward.

3. **Compliance firefighting tax**: 55% of recent commits are `chore(state)` + `fix(...)` rather than `feat(...)`. Three months ago this ratio was inverted.

4. **OpenCode + cross-tool reality check**: we have deep knowledge for Claude (leaked source) and OpenCode (open source); only behavioral observation for Cursor/Copilot/Codex. The "agent-agnostic D7 portability" claim has been a fiction maintained at significant cost.

5. **The framework's own founding diagnosis**, from `docs/CAPABILITY_SPEC.md` line 9: *"~90% of the effort building this framework was compensating for unreliable agent behavior — not solving the actual development problems. Most of the complexity (behavioral tests, redundant instruction files, reinforcement layers, pre-commit gates) exists because agents kept not doing what they were told."* This is the strongest articulation of the diagnosis.

   **Four co-authoritative sources** (none alone is sufficient; the gap between them is where the redesign opportunity lives):
   - **Foundational design contract:** `.agentic/lib/PRINCIPLES.md` (25KB; KISS meta-principle + F1–F3 foundations + D1–D7 design principles + R1–R3 operational rules) — **the framework's spine. Authoritative; non-negotiable; v5 and AF2 both honor every principle here.** Specific examples that are load-bearing: KISS (meta), D1 Human-Agent Partnership, D2 Deterministic Enforcement (the *full* original ambition), D3 Durable Artifacts, D4 Small Batch + ATDD, D5 Living Documentation, D6 Green Coding, R1 Anti-Hallucination, R3 Check Before Creating.
   - **Required baseline (WHY):** `docs/CAPABILITY_SPEC.md` (15 required capabilities + design constraints)
   - **Built reality (WHAT):** `.agentic/spec/FEATURES.md` (v0.72.0, 42 features × YAML contracts × consolidation maps)
   - **Wishlist (WHAT WE WANTED):** TODO.md, CONTRIBUTIONS.md, proposed ADRs (001 multi-component, 002 user-involvement-modes), JOURNAL future-tense entries, and the Pillar 4 / Theme A–J catalog (~70 items mapped to R-NNN) — what the user wanted but never built because firefighting consumed the runway.

   **Within the principles, a separate observation about toning:** PRINCIPLES.md is the contract; *specific principles within it have been softened during implementation* because full enforcement was too costly. D2's "Critical behavior is enforced by scripts and gates, not by documentation and hope" became a 4-tier hierarchy where tier 4 ("behavioral guidance, ~85% reliability") is a recognized fallback — and many rules ended up there. D4's TDD became opt-in (`development_mode: tdd` in STACK.md) rather than discipline. R2 "No Auto-Commits" became "Without Approval (Conditional)". D7 cross-tool portability is fictional for closed tools. F3's anatomy hook was specced but never wired. **PRINCIPLES.md itself documents a promotion rule** (D2 section): *"If a behavioral rule has been skipped 3+ times across sessions, promote it to a higher enforcement level. Repeated failures are evidence of misclassification, not insufficient documentation."* — v0.7x rarely executed it.

   The v5 redesign delivers the 15 required capabilities at materially lower complexity, **honors all current PRINCIPLES.md design principles**, **executes the principle's own promotion rule en masse to re-tighten the soft spots** (D2 → Tier 0 git-layer enforcement; D4 → Tier 0 TDD; R2 → Tier 2 critic-gated for the conditional; F3 → Tier 1 voluntary intelligence with Anatomy hook; D7 → honest "state portable, enforcement Claude-first" matching observed reality), AND finally ships the wishlist that v0.7x couldn't.

6. **The empirical core finding (months of failure)**: *agents do not reliably follow framework rules.* The framework today has 27+ hooks, 30+ skills, 17 pre-commit gates, sentinel files, gates.py, ag CLI, memory-seed, instruction files for 4 tools, LLM behavioral tests — and a 2-day production session shipped 12 `feat:` commits while ignoring all close-out paths. **This is not an implementation gap. It is a structural property of post-trained models** (OpenAI's Instruction Hierarchy paper [arXiv 2404.13208]; Anthropic's agentic-misalignment research [Nov 2025, Apr 2026]). The framework has been fighting the model's training. That is a losing battle.

The convergence justifies a **center-of-gravity inversion** in the redesign.

---

## The empirical truth: what doesn't work, what does

### What does NOT work (proven empirically over months)

- More instruction files, memory-seed updates, trigger-word tables
- More hooks within the agent's own session
- More skills (model-invoked, optional, ignorable)
- More CLAUDE.md rules (delivered as user context, probabilistic compliance)
- More single-agent enforcement layers
- "Smarter prompting" or "better behavioral guidance"

These are what we have spent months iterating on. The agents still don't follow.

### What DOES work (proven by metaswarm, Agent Teams, opencode-swarm, M.A.'s "tuntikausia autonomisesti" workflow, Cursor 2.0, Anthropic Managed Agents)

Three architectural moves, repeated across every successful autonomous system:

**Move 1 — SEPARATE work-execution from work-acceptance.**
The agent that did the work cannot be the agent that decides "done." Orchestrator/worker. Independent verifier. Critic subagent in a fresh context. **Same-context self-certification is THE structural leak**; nothing inside one session fixes it.

**Move 2 — REDUCE each worker's scope so badness can't compound.**
Specialization (narrow tasks per worker), heterogeneity (different models break correlated errors), iteration caps with escalation, summary-only return between phases, sandbox isolation. The worker has minimal authority and narrow scope.

**Move 3 — PUSH critical enforcement OUT of any single session.**
Hard transition gates (state machines that reject invalid moves), local git-hook enforcement (pre-commit + pre-push that fire regardless of agent cooperation), append-only durable state, optional sandbox isolation. **The agent doesn't control these because they fire in processes the agent doesn't manage.**

These three moves are how successful autonomous systems work. None of them are "more rules in the agent's context."

---

## Design principles (revised)

**Adopted from PDF §2.2** (the 13 Claude Code principles): deny-first with human escalation; graduated trust; defense in depth; externalized programmable policy; context as scarce resource; append-only durable state; minimal scaffolding / maximal harness; values over rules; composable multi-mechanism extensibility; reversibility-weighted risk; transparent file-based config; isolated subagent boundaries; graceful recovery.

**Framework-specific principles (revised in v5):**

1. **Spec is the contract; code is the implementation.** Machine-verifiable structural assertions in YAML are the source of truth.
2. **Closure is structural, not ceremonial — and structurally lives outside the worker session.** The worker can't gate itself; gates fire in the harness or at the git layer.
3. **Quality intelligence is delivered, not described.** Stack-aware quality checks generate concrete tooling at init time.
4. **Personas + platforms scope acceptance.**
5. **Migration entries are non-negotiable for shipped contracts.**
6. **Cross-tool: state is portable, enforcement is Claude-first.** Stop pretending parity for closed tools.
7. **Single-agent self-enforcement raises the ceiling; topology + external enforcement breaks it.** This must land in user-facing docs verbatim.
8. **Framework as productivity tool first, compliance layer second.** If a command isn't demonstrably better than the alternative for the agent, it shouldn't exist.
9. **Local-first; remote-optional.** Pure local development must be a first-class deployment. GitHub/cloud integrations are belt-and-suspenders, never required.
10. **Accept the model's training; design around it.** Stop trying to make framework instructions outrank user instructions in the same context. Different context (different session) or different layer (git hook, CI mirror) is the only reliable way.

---

## The four-tier architecture (replaces "five pillars" framing)

The plan is now organized around **four tiers** that scale by stakes, with each tier providing a different reliability primitive. Tiers compose — Mode 1 work uses Tier 0+1, Mode 2 adds Tier 2, Mode 3 adds Tier 3.

### Tier 0 — Always-on external enforcement (local-first, remote-optional)

**Mechanism:** enforcement that fires regardless of which agent runs in any session. The agent doesn't control invocation because the agent doesn't manage these processes.

**Local primitives (always required):**
- **Git pre-commit hook** — hardcoded blocking: `ag verify` runs (harness reads test output, agent can't claim "tests pass"), contract assertions checked, sentinel state validated, journal-since-last-commit verified. No advisory escapes; no `--no-verify` allowed without explicit `ag commit --skip-gate <reason>` audit trail.
- **Git pre-push hook** — second wall: full integration test suite, contract coverage, doc-freshness drift check.
- **`ag merge` as the standard merge path** — runs deterministic checks before allowing local merge to main; user configures git alias if they want hard enforcement (`alias git-merge='ag merge'`).
- **Filesystem read-only protection** for shipped contract YAMLs (chmod-based, brittle but agent-cannot-bypass-without-realizing).

**Remote primitives (optional belt-and-suspenders for users who push to remotes):**
- **GitHub Actions / GitLab CI / Gitea Actions** mirror running the same gate set on PR-merge. For users with shared remotes; not required for solo local development.
- **Branch protection** at the remote provider (when used).

**Why this works where in-session hooks failed:** pre-commit fires when `git commit` runs in a different process the agent doesn't drive. To bypass casually, the agent must rewrite history or skip git entirely — both unusual and detectable.

**Honest limit (per stress-test review):** Tier 0 hooks themselves live in `.git/hooks/`, `.agentic/lib/hooks/`, `.claude/agents/`, and `settings.json` — all of which are file paths the agent has Edit access to. **Tier 0 prevents casual bypass; it does not prevent a determined or adversarial agent from editing hook scripts before commit.** To raise the bar further:

- **Hook integrity check** (hardcoded in `precommit_gate.py`): on each invocation, verify SHA-256 of `.git/hooks/pre-commit`, `.git/hooks/pre-push`, `.agentic/lib/hooks/*.py`, `.claude/settings.json`'s hook entries, and `.claude/agents/*.md` match a known-good baseline (stored in `.agentic/integrity.json`). Mismatch → block commit and require `ag integrity update` (audited).
- **Sealed harness option** (Phase 4+): for Mode 3 use, run `ag verify` and gate logic in a sub-process with a different working directory, making it harder for the agent to intercept. Anthropic Managed Agents provides this naturally.
- **JSONL append signing** (Phase 1+): events.jsonl entries signed with HMAC keyed off a secret in `.agentic/integrity.json`. Forged entries detectable post-hoc.

These are defense-in-depth, not perfect. **Honest framing for HOW_IT_WORKS.md:** "Tier 0 + integrity checks raise the casual-bypass cost from ~30 seconds to ~10 minutes of deliberate hook editing. Combined with Tier 2 critic in fresh context, the determined-bypass scenario also requires forging events.jsonl and editing critic prompts. No layer alone is invincible; defense-in-depth is the design."

**T-0094 reframing (per Claude-expert review):** PostToolUse for built-in tools fires *after* the result is already in context (PDF §5.3 line 844) — too late to gate. Tier 0 sidesteps this entirely by firing at the git layer in a separate process, not by depending on PostToolUse.

### Tier 1 — Voluntary intelligence (always on, parallel to Tier 0)

**Mechanism:** every `ag` command must pass the test "would the agent invoke this voluntarily because it makes the agent's work better?" If yes, the agent uses it because it's the path of least resistance to its own goal. If no, the command shouldn't exist.

**The test, applied:**
- **`ag intel architecture | spec | implement | test`** → returns richer context than vanilla CC scratch-thinking. PASS.
- **`ag verify F-XXX --explain`** → structured failure output that's actionable, not raw stderr dumps. PASS.
- **`ag contract check F-XXX`** → exact assertion failures with file/line; tells the agent precisely what's left. PASS.
- **`ag delegate haiku-critic <plan|diff>`** → cheap second-opinion in 30s vs. no critic. PASS.
- **`ag deploy <provider>`** → handles secrets/health-checks/rollback vs. manual `vercel deploy`. PASS.
- **`ag handoff`** → structured artifact for next contributor vs. explaining orally. PASS.
- Anatomy hook (PreToolUse:Read injects file metadata) → agent uses because re-reading is expensive. PASS.
- Token Ledger visible (`ag intel report --tokens`) → agent self-optimizes. PASS.
- The current `ag commit` "you must run this or commit fails" — FAIL the test. The agent doesn't *want* to run it; replace with something the agent benefits from invoking.

**Implication:** **stop maintaining the trigger-word tables, instruction-file rule lists, and skill-as-enforcer patterns.** Skills become JIT context-providers (PASS) rather than rule-deliverers (FAIL).

### Tier 2 — Topology-by-default (default for any work that matters)

**Mechanism:** acceptance of work is structurally separated from execution. Even within a single human-driven Claude session, the framework defaults to a topology where the worker doesn't approve itself.

**Three topology primitives, ranked by cost:**

**2a. Fresh-context critic via Agent tool (default-on for Mode 1+).**

Two jobs separated explicitly:
- **Job A — catch subtle bugs** (security, race conditions, spec drift, architectural mistakes). Needs strong reasoning; weaker models risk false sense of security.
- **Job B — break same-context self-certification.** Needs *different context*, not *weaker model*. Sonnet in a fresh conversation without the worker's "make progress" pressure breaks the rubber-stamp.

**Default critic: Sonnet (same tier as worker) in fresh `Agent`-tool context with explicit adversarial role prompt.** Cost: ~2× tokens. Covers both Job A (strong reasoning preserved) and Job B (fresh context breaks self-certification). The critic sees the diff + contract assertions + spec but NOT the worker's deliberation.

**Heterogeneity ladder (escalate when warranted):**

| Level | Use | Cost | When |
|---|---|---|---|
| 1. Sonnet-fresh-context (default) | All plans + diffs in formal+ | ~2× tokens | Default-on |
| 2. Haiku as cheap pre-screen | High-volume mechanical checks (lint-style, doc draft, test-stub validation) — **NOT security/architectural review** | ~1.2× tokens | Volume-driven |
| 3. Cross-provider critic (Gemini Flash, GPT-4o-mini) | High-stakes diffs (security-sensitive paths, shipped-contract changes) | ~3× tokens | Configured per-path |
| 4. Multi-critic vote (Sonnet + Haiku + cross-provider) | Mode 3 / production-grade work | ~5× tokens | Mode 3 default |

**Telemetry gate (Phase 3):** define defect taxonomy first (categorical: spec-drift / security / correctness / architecture / style / typo). Establish Sonnet-on-Sonnet baseline catch rate from historical issues. Default critic must catch ≥85% of baseline; if <85%, escalate to Opus critic or layer multi-critic vote.

This uses Claude Code's *existing* `Agent` tool primitive (PDF §8) — no new infrastructure. **Default ON in formal and autonomous_formal profiles. Opt-in in discovery.**

**2b. Independent verification (deterministic, harness-fired, default-on always).**
- `ag verify` is invoked **by the harness** (Stop hook + pre-commit + CI mirror), not by the worker.
- The worker cannot claim "tests pass" because the worker doesn't run them; the harness reads pytest/jest/etc. output directly.
- This is sibling §3 Layer 4 ("orchestrator validates independently, never trusts subagent self-reports") implemented within a single human session.

**2c. Full orchestrator/worker via Agent Teams (Tier 3, see below).**

**Why 2a + 2b together break the structural leak in single-session work:**
- 2b ensures factual claims (tests pass, assertions hold) are deterministically verified, not negotiated.
- 2a ensures judgment claims (plan is sound, diff matches spec) are reviewed in a different reasoning frame.
- Together they cover the two failure modes the same-context-self-certification creates.

### Tier 3 — Full orchestrator/worker (callable primitive; Mode 3 default-on)

**Mechanism:** Anthropic Agent Teams (when stable) or equivalent. Lead session ≠ teammate sessions. `TaskCompleted` hook gates completion. Heterogeneous models (Sonnet lead, Haiku workers, optional Aider for AST-aware bulk edits). Optional sandbox isolation via Anthropic Managed Agents or microVM.

**Cost:** 7–15× tokens (median); 4–220× tail per Galileo. Justified where reliability stakes outweigh cost.

**Tier 3 is a callable primitive, not exclusively a Mode 3 feature.** Two activation patterns:

**Pattern A — Mode 3 default-on (autonomous flow):**
- `profile: autonomous_formal` + `mode: fully_autonomous`
- `ag auto task | epic | crunch` always run via Agent Teams
- Hours-of-autonomous reliability requires this

**Pattern B — On-demand per-task (any mode, any profile):**
- `ag implement F-XXX --teams` — invoke a Tier 3 team for this specific feature
- `ag refactor --scope <path> --teams` — security-critical refactor with orchestrator/worker
- `ag review F-XXX --teams` — high-stakes review with orchestrator-independent verification
- `ag verify F-XXX --teams` — paranoid verification for shipped-contract-affecting changes
- Generic `--teams` flag enables Tier 3 topology for the invoked command without changing profile/mode

**When Pattern B makes sense (single tasks worth the cost):**
- Security-critical code paths (auth, payment, secrets handling)
- Changes to shipped contracts (regression risk → orchestrator-independent verification)
- Multi-AC features where parallel worker sessions on independent ACs cut wall-clock time
- Hard bug fixes where you want an independent verifier (worker writes the fix; verifier runs the failing test, confirms fix works without trusting worker's claim)
- Architectural decisions where you want adversarial debate across teammate types
- Production-blocking work where the 7–15× token cost is much cheaper than the failure cost

**What Tier 3 adds beyond Tier 2:**
- Cross-session orchestrator (different context, no "make progress" pressure)
- Parallel worker sessions on independent ACs (worktree-isolated, real wall-clock parallelism)
- Structural impossibility of self-marking-done (TaskCompleted hook in lead's runtime)
- Specialized teammate types (planner, coder, critic, verifier, security-reviewer) — heterogeneity by role *and* model
- Sandbox-grade isolation when paired with Managed Agents

**Activation matrix:**

| Profile / mode | Tier 3 default | `--teams` flag |
|---|---|---|
| discovery | Off | Available (opt-in per-task) |
| formal / Mode 1 (Tech Lead) | Off | Available; recommend for security-critical or shipped-contract-affecting work |
| autonomous_formal / Mode 2 (Visionary) | Off (single-session implementation between checkpoints) | Recommend for `ag auto epic` between vision/preview checkpoints |
| autonomous_formal / Mode 3 (Fully Autonomous) | **On (always)** | n/a (already on) |

**Telemetry-driven discipline for Pattern B:**
- Log Tier 3 invocations with `{task_type, token_cost, wall_time, outcome}` to delegation.jsonl
- Surface in `ag intel report --teams` so the user can see when `--teams` paid off vs. wasted tokens
- The user develops a sense over time for which task shapes warrant Tier 3

---

## Observability layer (transverse — sits across all tiers)

Autonomous work without observability is faith-based. Tier 3 specifically — multiple parallel workers, accumulating tokens, asynchronous decisions — *requires* a "mission control" view or the user can't trust the cost or catch failures fast.

**Design: append-only JSONL streams as canonical source; multiple thin frontends consume the same stream.**

### Canonical event streams (already in plan, now elevated)

- **`.agentic/journal/events.jsonl`** — every framework decision, commit, test run, critic verdict, escalation
- **`.agentic/journal/delegation.jsonl`** — every Tier 2/3 worker invocation with cost/outcome
- **`.agentic/journal/token-ledger.jsonl`** — per-session and per-worker token spend

**Critical property: the harness writes events from its view of workers, not from worker self-reports.** A worker cannot lie about progress because the orchestrator (or the harness in single-session mode) generates the event records.

### Common event types (canonical schema)

```json
{"ts": "2026-04-26T14:30:01Z", "session_id": "...", "type": "...", "feature": "F-XXX", "actor": "lead|teammate-coder|teammate-critic|harness", "payload": {...}}
```

Event types: `session_start`, `task_dispatch`, `tool_call` (with cost), `commit` (hash, files, message), `test_run` (pass/fail counts), `critic_verdict` (approve/reject/escalate), `contract_check`, `human_needed` (escalation), `task_complete` (TaskCompleted hook fired), `session_end`.

### Four frontends, all local-first

| Frontend | Use case | Stack | LoC | Phase |
|---|---|---|---|---|
| **`ag tui`** | Default terminal mission control | Textual (Python) | ~1000 | Phase 0 |
| **`ag dashboard serve`** | Browser at `localhost:PORT`, live updates via SSE; viewable from tablet/phone on same LAN | FastAPI + small JS | ~1500 | Phase 5 |
| **`ag dashboard export`** | Static HTML regenerated on commit; optional GitHub Pages publish | Plain HTML/CSS/JS | ~300 | Phase 5 |
| **`ag watch`** | Lightweight live event tail with formatting | Pure shell/Python | ~200 | Phase 0 |

All four frontends read the same JSONL. **Each is independently optional; the JSONL streams are the truth.** A user can build their own frontend (Grafana, custom Streamlit, etc.) by tailing the same files.

### Mission-control view (the "is this working?" screen)

The most important view for Tier 3 / autonomous work:

```
┌─ ag auto epic F-008 ─────────────────────── 14:32 ──────────────────┐
│ Mode: autonomous_formal / Mode 3   Tokens: 142K / 500K budget       │
│ Started: 14:18 (14 min)            ETA: ~22 min                      │
├─────────────────────────────────────────────────────────────────────┤
│ ACTIVE WORKERS                                                      │
│ ◉ teammate-coder-1  → AC-003: implement skill validation [3 min]    │
│ ◉ teammate-coder-2  → AC-005: add allowlist registry [1 min]        │
│ ◐ teammate-critic   → reviewing AC-002 diff [waiting]               │
│ ○ teammate-verifier → idle                                          │
├─────────────────────────────────────────────────────────────────────┤
│ RECENT EVENTS                                            COST  STATUS│
│ 14:31 critic approved AC-002 (Sonnet, fresh ctx)         2.4K  ✓    │
│ 14:30 commit  AC-002: skills.sh marketplace engine       —     ✓    │
│ 14:29 verify  AC-002 tests passing (12/12)               —     ✓    │
│ 14:27 dispatch AC-003 → teammate-coder-1                 —     →    │
│ 14:25 critic REQUESTED CHANGES on AC-001 plan            1.8K  ⚠    │
├─────────────────────────────────────────────────────────────────────┤
│ STATUS: ✓ healthy  |  no human input needed              [ q quit ] │
└─────────────────────────────────────────────────────────────────────┘
```

Five panels in any frontend:
1. **Header bar**: feature, mode, profile, total tokens (vs budget), elapsed, ETA
2. **Active workers**: per-teammate live status (current step, time on task)
3. **Event stream**: live-tailing decisions/commits/verdicts with cost annotations
4. **Health bar**: green/yellow/red + escalation count + budget warning
5. **Drill-down panes**: click/expand for diff, test output, contract assertions, decision rationale

### Other views (same data, different lens)

- **Cost dashboard** — token spend over time chart, per-worker breakdown, budget remaining, cost-per-AC trend (driven by `delegation.jsonl` + `token-ledger.jsonl`)
- **Progress / kanban** — backlog → in-progress → in-review → done with cards per feature/AC
- **Decision log** — critic verdicts, plan-review outcomes, escalations to human (filterable)
- **Diff explorer** — recent commits with which AC each touched, test status per commit
- **Health overview** — across all features: doc freshness, test coverage trend, contract drift, deprecation candidates

### Local-first verification

- All frontends work fully offline. JSONL is just files; no cloud, no DB, no SaaS.
- `ag dashboard serve` listens on localhost by default; the user can bind to LAN-IP for tablet/phone viewing on same Wi-Fi (still no cloud).
- For remote viewing across networks, the user can SSH-tunnel the port — explicit user choice, not framework dependency.
- Optional: `ag dashboard export` regenerates a static `docs/dashboard.html` after every `ag done`; user can publish to GitHub Pages if they want, but no requirement to do so.

### Why this matters specifically for Tier 3

When `ag implement F-XXX --teams` runs (Pattern B from Tier 3), the user needs to:
- See multiple workers' progress without sshing into each worktree
- Watch token spend live and abort if budget overrun
- Catch human-needed escalations fast (not 2 hours after they happened)
- Verify the orchestrator made the right calls (TaskCompleted decisions)

In Mode 3 (autonomous_formal default-on Tier 3), the user might walk away for hours; the dashboard is the only thing connecting them back to what's happening. **Without it, Tier 3 is faith-based, the same way single-agent in-session enforcement was faith-based.**

---

## Quality + verification capabilities (mapped to the tier architecture)

The framework's quality story spans seven concrete capabilities. Each is supported across multiple tiers; nothing depends on a single layer.

### 1. TDD (Test-Driven Development)
**Discipline: failing test before source code; red → green → refactor.**

- **Tier 0**: pre-commit gate blocks source-file edits committed without a corresponding test added/modified in the same commit. Hardcoded blocking; no advisory.
- **Tier 0**: `tdd_mode` setting in STACK.md (off / advisory / blocking) — when blocking, pre-commit verifies a failing test existed in the previous commit before allowing source edits in this commit (chronology check via git log).
- **Tier 1**: `ag intel test F-XXX` returns failing-test scaffolds derived from contract assertions, making TDD the path of least resistance for the agent.
- **Tier 2**: critic-in-fresh-context checks the diff for "test exists for this code change?" as part of standard review.
- **Tier 3**: dedicated `verifier` teammate runs the failing-test cycle, reports red→green transition to lead.

### 2. ATDD (Acceptance Test-Driven Development)
**Discipline: contract assertions are the acceptance tests; code is written to satisfy them.**

- **Tier 1**: `ag contract → tests scaffold F-XXX` auto-generates test stubs from each assertion (structural assertions → shell-test stubs; behavioral assertions → integration-test stubs). Voluntary use because it saves the agent typing time.
- **Tier 0**: `ag contract check F-XXX` runs structural assertions in pre-commit; failures block.
- **Tier 0**: pre-push runs behavioral assertions (slower, e2e-style).
- **Tier 2**: harness-fired `ag verify --acceptance` reports per-assertion pass/fail; agent can't claim "tests pass" — the harness runs them.
- **Tier 3**: verifier teammate runs assertion suite in worktree-isolated container; lead receives structured pass/fail per AC.

### 3. End-to-end testing
**Discipline: full integration tests with real dependencies (DB, browser, network).**

- **Tier 0**: pre-push hook runs e2e suite (slower than pre-commit's unit tests). Failures block push.
- **Tier 0**: optional CI mirror runs e2e in clean container (defense-in-depth for users with remotes).
- **Tier 1**: `ag preview` (Phase 5) launches stack-aware dev server for manual e2e + Playwright integration for visual regression.
- **Tier 3**: verifier teammate runs e2e in isolated worktree/sandbox; reports per-feature outcomes to lead.

### 4. Autonomous verification loops
**Discipline: `ag auto verify` runs tests, captures failures, dispatches fixes, re-tests; iterates with capped retry count.**

- **Tier 2**: harness-fired `ag verify --loop F-XXX` invokes verifier in fresh subagent context, reads test output, writes verification.json. If failures: dispatches a "fix" subagent with structured failure context. Iteration cap = 3 (matches plan_review_max_iterations); on cap-out, escalates to human via HUMAN_NEEDED.
- **Tier 3**: full Agent Teams version — verifier teammate runs continuously, reports to lead; lead dispatches coder teammates with structured failure feedback. Lead has independent test-running ability (sibling §3 Layer 4: orchestrator runs tests itself, never trusts subagent self-reports).
- **Critical: harness or lead runs the tests, not the worker.** Worker can't claim "tests pass" because worker doesn't run them.

### 5. Framework verification tools (the meta-loop, autonomous too)
**Discipline: the framework tests itself by building example projects end-to-end; catches behavioral gaps no unit test finds.**

- **Phase 5 ships E1 from the catalog**: `ag auto verify-framework` builds a portfolio of example projects (todo CLI, REST API, web app, game, mobile app) from scratch using the framework. Detects bugs in framework workflow, hooks, gates. Iterates until clean. Final output: a single PR with all framework fixes.
- **Tier 3 mode**: framework verification runs as an Agent Teams flow — lead orchestrates the example-project builds, verifier teammates run tests, critic teammates evaluate quality. Catches issues like "T-0094 PostToolUse-doesn't-fire" before they ship to user projects.
- **Operationally:** runs nightly or on every framework PR. Reduces the "compliance firefighting tax" (currently 55% of commits) by catching framework regressions before users do.
- **Telemetry:** verification.json from each example project is logged; a regression in any example fails the framework PR.

### 6. Spec migrations (audit trail for shipped contracts)
**Discipline: shipped contracts are immutable without explicit migration entries; protects against silent regression.**

- **Tier 0**: pre-commit detects modifications to YAML files where `lifecycle: shipped` and `protection: contract`. Blocks commit unless a new entry is added to the contract's `migrations:` array. Migration entry must include `id` (date-stamped), `trigger`, `reason`, `changes`, `approved_by`. Hardcoded blocking.
- **Tier 1**: `ag contract migrate F-XXX --reason "..."` is the standard path to add a migration entry. Easier than editing YAML by hand.
- **Tier 2**: critic-in-fresh-context verifies the migration's `reason` field is meaningful (not "fix" or "update"); flags weak reasons for human review.
- **`ag contract promote` semantics**: only promotes `planned → shipped`; does NOT support replacing shipped assertions (sibling §8 round-3 framework-expert finding). Use migration entries for changes.

### 7. Plan ↔ spec ↔ tests ↔ code ↔ docs synchronicity
**Discipline: "spec + code + tests + docs = done"; nothing ships out of sync.**

This is the close-out discipline now enforced at the Tier 0 git layer:

- **Tier 0 pre-commit checks (every one is hardcoded blocking):**
  - Plan file exists in `.agentic/journal/plans/*F-XXX-plan.md` with `Status: APPROVED` (when `plan_review_enabled: yes`)
  - Spec file at `spec/contracts/F-XXX.yaml` with assertions covering the changes
  - Tests added/modified per TDD rule above
  - Code changes match scope declared in plan's `**Files:**` section (declared file scope per sibling Step 11)
  - Docs registered in STACK.md `## Docs` section that touch changed files are updated since last commit
  - JOURNAL entry added since last commit (the agent has logged WHY)
  - Contract assertions verified by harness-run `ag contract check`
- **Tier 0 pre-push checks (additional):**
  - Doc-freshness drift across all registered docs
  - NFR compliance (e.g., LCP, bundle size) for stack-relevant features
  - Migration entries added for any shipped-contract change
- **Tier 0 close-out gate** (special pre-commit subset): after a `feat:`/`fix:` commit, before the *next* commit, verify the previous commit had:
  - Either: full close-out (`ag commit` ran and updated FEATURES.md status)
  - Or (in discovery): doc-capture (JOURNAL/OVERVIEW/STACK/STATUS updated)
  - This is the structural fix for the "12 commits + continue" failure, now at git-hook layer instead of Claude Code hook layer.
- **Tier 1**: `ag intel sync F-XXX` returns the synchronicity status (which artifacts are stale vs current); voluntary use because the agent benefits from knowing what's left.
- **Tier 2**: critic-in-fresh-context checks the diff for sync drift across these five artifacts.
- **Tier 3**: lead session has dedicated `sync verifier` teammate type that gates `TaskCompleted` on full synchronicity.

### Quality + verification × tier responsibility matrix

| Capability | Tier 0 | Tier 1 | Tier 2 | Tier 3 |
|---|---|---|---|---|
| TDD | pre-commit blocks code without tests | `ag intel test` scaffolds | critic checks test presence | verifier teammate runs red→green |
| ATDD | `ag contract check` in pre-commit | `ag contract → tests scaffold` | harness-fired `ag verify --acceptance` | verifier teammate runs assertions per AC |
| End-to-end testing | pre-push runs e2e | `ag preview` for manual + Playwright | harness-fired e2e in `ag verify` | verifier teammate in isolated container |
| Autonomous verification loops | n/a (Tier 0 is single-shot) | `ag auto verify` invokes Tier 2 | `ag verify --loop` with iteration cap → escalation | full Agent Teams loop (lead orchestrates fix dispatches) |
| Framework verification (meta) | n/a | n/a | n/a | **Phase 5 E1**: `ag auto verify-framework` runs example-project portfolio nightly |
| Spec migrations | pre-commit blocks shipped-contract edits without migration entry | `ag contract migrate` standard path | critic verifies migration `reason` is meaningful | lead enforces migration discipline across teammates |
| Plan-spec-test-code-docs sync | hardcoded multi-check pre-commit + close-out gate | `ag intel sync` reports status | critic checks diff for sync drift | dedicated sync-verifier teammate gates `TaskCompleted` |

**Key principle across all seven:** every capability has a deterministic, harness-fired enforcement layer (Tier 0) AND an LLM-judgment layer (Tier 2/3). The deterministic layer is uncircumventable; the LLM layer adds judgment for what determinism can't catch. **No quality property depends solely on the worker's cooperation.**

---

## Visual decision trees

Two trees the user/agent can scan quickly. The matrix that follows is the same information in tabular form for reference.

### Tree A: "Which tiers fire for this work?"

```
START — about to do work
│
├─ Quick prototype, throwaway code, exploring an idea
│  └─ profile: discovery
│     ├─ Tier 0 (advisory mode in discovery — pre-commit warns, doesn't block)
│     ├─ Tier 1 voluntary (skills, ag intel — invoked when helpful)
│     ├─ Tier 2 critic — opt-in only (ag review --critic)
│     └─ Tier 3 — off
│     ⇒ ~baseline cost, friction-lite
│
├─ Production code, human reviews everything before merge
│  └─ profile: formal | mode: Tech Lead
│     ├─ Tier 0 hardcoded blocking
│     ├─ Tier 1 voluntary
│     ├─ Tier 2 critic default-on (Sonnet fresh context on plans + diffs)
│     │   └─ heterogeneous-by-config: critic-sonnet.md, critic-haiku.md, etc.
│     └─ Tier 3 — opt-in per-task via --teams flag for high-stakes work
│     ⇒ ~2× quota usage vs baseline
│
├─ Vision-driven product, human reviews vision/taste/architecture
│  └─ profile: autonomous_formal | mode: Product Visionary
│     ├─ Tier 0 hardcoded blocking
│     ├─ Tier 1 voluntary
│     ├─ Tier 2 default-on (critic + harness-fired verify)
│     ├─ Tier 3 recommended for ag auto epic between checkpoints
│     └─ ag preview / feedback pipeline / ag kickoff
│     ⇒ ~3× quota usage; auto-runs between human checkpoints
│
├─ Hours of autonomous work, human only for final acceptance
│  └─ profile: autonomous_formal | mode: Fully Autonomous
│     ├─ Tier 0 hardcoded blocking
│     ├─ Tier 1 voluntary
│     ├─ Tier 2 default-on
│     ├─ Tier 3 ALWAYS-ON (Agent Teams)
│     │   └─ TaskCompleted hook + heterogeneous teammates + sandbox
│     └─ Optional: Anthropic Managed Agents for sandbox-grade isolation
│     ⇒ ~7–15× quota usage; suitable when reliability stakes >> token costs
│
└─ Per-task escalation (any profile, any mode)
   └─ ag implement F-XXX --teams
      ag refactor --scope <path> --teams
      ag review F-XXX --teams
      ag verify F-XXX --teams
      ⇒ Tier 3 invoked for THIS task only; reverts to default for next
      ⇒ Use for: security-critical refactor, shipped-contract change,
                  multi-AC parallel implementation, paranoid verification
```

### Tree B: "Will this commit ship?"

```
git commit triggered (in any profile)
│
├─ Tier 0 pre-commit fires (separate process, agent doesn't drive)
│  ├─ Hook integrity check — files match SHA-256 baseline?
│  │  └─ no → BLOCK + alert "hook tampering detected"
│  ├─ Tests run by harness — pass?
│  │  └─ no → BLOCK
│  ├─ Spec exists for changed code?
│  │  ├─ no, formal+ → BLOCK
│  │  └─ no, discovery → WARN
│  ├─ Plan approved (if plan_review_enabled)?
│  │  └─ no → BLOCK
│  ├─ Journal updated since last commit?
│  │  ├─ no, formal+ → BLOCK
│  │  └─ no, discovery → WARN
│  ├─ Migration entry for shipped-contract changes?
│  │  └─ no → BLOCK (no advisory; shipped contracts are immutable without audit)
│  ├─ TDD: failing test exists for this code change?
│  │  └─ no, tdd_mode=blocking → BLOCK
│  └─ Close-out gate: previous feature closed out?
│     └─ no → BLOCK with "ag done F-PREV first"
│
├─ If all Tier 0 checks pass: commit succeeds locally
│  └─ Tier 2 critic invoked (formal+ default-on)
│     └─ Verdict: approve | request-changes | escalate-to-human
│        ├─ request-changes → user/agent fixes, re-commits
│        └─ escalate → HUMAN_NEEDED.md, blocked until reviewed
│
└─ git push triggered → Tier 0 pre-push fires
   ├─ Full e2e suite passes? → no → BLOCK
   ├─ Doc-freshness drift? → stale → BLOCK
   ├─ Contract coverage adequate? → no → BLOCK
   └─ Optional CI mirror at remote (defense-in-depth for users with remotes)

(The agent can attempt bypass via hook editing / --no-verify / wrapper script
 / API commits — see "Honest limit" subsection above. Tier 0 raises the bar
 from ~30s casual bypass to ~10min deliberate bypass; integrity checks +
 Tier 2 critic + Tier 3 lead acceptance compose for defense in depth.)
```

---

## Tier × profile × mode matrix (the actual default behavior)

| Profile | Mode | Tier 0 | Tier 1 | Tier 2 | Tier 3 |
|---|---|---|---|---|---|
| **discovery** | (no formal modes) | ✅ Always on (pre-commit, pre-push, `ag merge`) | ✅ Always on (skills, intel, intelligence) | Opt-in (heterogeneous critic) | Off |
| **formal** | Mode 1 (Tech Lead) | ✅ | ✅ | ✅ Default-on (critic + indep verify) | Off |
| **autonomous_formal** | Mode 2 (Visionary) | ✅ | ✅ | ✅ Default-on | Recommended for `ag auto epic` |
| **autonomous_formal** | Mode 3 (Fully Autonomous) | ✅ | ✅ | ✅ | ✅ Required |

**Reading the matrix:**
- Every profile gets Tier 0 + Tier 1. These are the framework's bedrock — local enforcement + voluntary intelligence.
- Formal/Mode 1 adds Tier 2 by default. Tiny atomic edits can opt out per-command.
- Mode 2 is Tier 2 default; Tier 3 recommended for between-checkpoint runs.
- Mode 3 is Tier 3 required. There is no path to Mode 3 reliability through Tiers 0–2 alone.

---

## Mechanism mapping: how each tier uses Claude Code primitives

| Tier | Primary primitives | Why these |
|---|---|---|
| Tier 0 | Git hooks (pre-commit, pre-push), filesystem permissions, optional CI mirror | Outside any agent session; agent doesn't control. T-0094-immune. |
| Tier 1 | Skills (low context cost, JIT), `ag` CLI commands (deterministic Python, no LLM cost), MCP-only-for-genuine-external-services | Agent invokes these voluntarily because they help. Doesn't try to enforce. |
| Tier 2 | `Agent` tool with worktree isolation + summary-only return (PDF §8) for heterogeneous critic; harness-fired Stop hook for independent verification | Existing Claude Code primitives. No T-0094 dependency. |
| Tier 3 | Anthropic Agent Teams + `TaskCompleted` hook + Managed Agents for sandbox | When Anthropic ships stably. Activate behind feature flag until then. |

**Notably absent from primary mechanisms:**
- **PreToolUse with path-based deny** — Claude-expert reviewer flagged this isn't documented in the leaked source. Demote to defense-in-depth, not primary.
- **PostToolUse for built-in tools (T-0094)** — empirically doesn't fire. Don't depend on it.
- **In-session enforcement via more skills/instruction-files** — empirically agents ignore. Stop investing.

---

## What's preserved (the irreducible 1.6%)

1. **YAML contract format** at `spec/contracts/F-XXXX.yaml` with assertions, persona/platform scoping, migrations.
2. **`ag contract` CLI** — `check`, `coverage`, `pending`, `promote`, `validate`, `add-migration`.
3. **`gates.py`** — 11 transition gates; extended for Tier 0 deterministic checks.
4. **Sentinel files** as cross-tool state primitive (`.plan-approved`, `.spec-first-checked`, etc.) — read by pre-commit, not relied on for in-session hooks.
5. **Quality knowledge base** (`.agentic/lib/quality_knowledge/`, 21 files) — Tier 1 voluntary intelligence.
6. **`ag intel`** (architecture/spec/implement/test) — Tier 1 voluntary intelligence.
7. **`ag` CLI for human-explicit ops** — `start`, `transition`, `done`, `verify`, `kickoff`, `backlog`, `commit`, `merge`, `delegate`.
8. **Three modes** (ADR-002: Tech Lead, Product Visionary, Fully Autonomous) as init shortcuts.
9. **Three profiles** (discovery / formal / autonomous_formal).

## What's dropped (rejected as failed approach)

1. **The "more single-session enforcement" thesis itself.** Months of evidence say no.
2. **AGENTS.json + custom session bookkeeping** — JSONL transcripts already exist.
3. **Most of `.agentic/lib/tools/*.sh`** as in-session enforcement chains.
4. **MCP coordinator as custom dispatch layer** — use `Agent` tool with worktree isolation.
5. **The 209 legacy `spec/acceptance/F-XXXX.md` files** — finish F-031 migration to YAML.
6. **Multi-format trigger-word table** scattered across CLAUDE.md / memory-seed / 4 tool instruction files. Skills as rule-deliverers fail; Skills as JIT context-providers stay.
7. **The "agent-agnostic D7 parity" claim.** State portable; enforcement Claude-first; honest framing.
8. **Single-session paths in `auto/`** (after Tier 3 lands) — ~3,400 LoC across 5 files.
9. **The implicit theory that smarter hooks/skills/instruction-files will eventually achieve compliance.** Stop iterating on this.

## What's new

1. **Tier 0 local external enforcement** — pre-commit + pre-push + `ag merge` with hardcoded blocking gates. No advisory escapes. Optional CI mirror for remote-using projects.
2. **Tier 2 heterogeneous critic by default** — Haiku-via-Agent-tool reviews every plan and every diff in formal+ profiles.
3. **Tier 2 harness-fired independent verification** — `ag verify` invoked by Stop hook + pre-commit, not by worker.
4. **Voluntary intelligence pillar (Tier 1)** as the framework's productivity story — every `ag` command must pass "agent invokes voluntarily" test.
5. **Tier 3 Agent Teams adoption** when Anthropic stabilizes the experimental flag.
6. **Reclaimed ambitions** — Token Ledger, Anatomy hook, vision-to-backlog (`ag kickoff`), `ag preview`, feedback loop, formal NFR system.
7. **Production-gap items (Theme J)** — `ag deploy`, regulatory compliance modules (GDPR / CCPA / HIPAA / SOC2, opt-in by jurisdiction), localization, crash reporting, game/itch.io publishing.
8. **Local-first DX** — Textual TUI dashboard (`ag tui`), static HTML dashboard, optional GitHub Issues sync.
9. **Append-only journal events** (JSONL) — replaces destructive mutations.
10. **Per-topic memory** with `@include` index.

---

## Cross-tool stance (final, honest)

Two layers of portability:

**Strong portability (genuinely tool-neutral, just files):**
- YAML contracts, FEATURES.md, JOURNAL.md, NFR catalog
- Sentinel files in `.agentic/session/`
- Pre-commit + pre-push git hooks (fire regardless of which agent authored)
- `ag` CLI (any shell can invoke)
- All Tier 1 voluntary intelligence (any agent that can run shell commands can use)

**Not portable (Claude-first, others files-only):**
- Tier 2 heterogeneous critic (uses Claude Code's `Agent` tool primitive)
- Tier 3 Agent Teams (Claude Code only)
- Real-time hook semantics (each tool's hooks differ structurally)
- Subagent / orchestrator primitives

**Cursor / Copilot / Codex stance:** files-only consumers. Read state, invoke `ag` CLI, get pre-commit gating for free at the git layer. Don't get Tier 2/3 topology. Documented honestly in HOW_IT_WORKS.md.

---

## Local-first deployment: pure offline operation must work

The framework runs in three deployment shapes, **all functional without GitHub or any cloud service**:

1. **Pure local (default).** `ag` CLI + git pre-commit/pre-push + Tier 1 voluntary intelligence + Tier 2 heterogeneous critic via local Claude Code. **Zero external dependencies.** This is the user's deals-marketplace and Phaser-game baseline.

2. **Local + remote git (most common).** Pure local + push to GitHub/GitLab/self-hosted git. CI mirror runs the same gate set as pre-push (defense-in-depth, not primary). GitHub Issues sync optional.

3. **Cloud orchestrator (Mode 3, opt-in).** Lead session in Anthropic Managed Agents or local; workers in Managed Agents containers or local; MCP bridges (e.g., user's local Ollama exposed to cloud orchestrator). Required for Mode 3 sandboxing, optional otherwise.

**Test of local-first compliance:** every Phase below must work end-to-end with `gh` uninstalled, the user offline, and no remote configured. Failures mean the feature requires GitHub; flag and provide a local-only equivalent.

---

## Pre-Phase-0 spike: COMPLETED 2026-04-26 — all primitives validated

**Spike report:** `docs/research/2026-04-26-pre-phase-0-spike-results.md`
**Effort:** ~30 minutes (vs. 1 week budgeted).
**Outcome:** All three load-bearing primitives confirmed. The v5 reviewer-flagged risks were largely artifacts of working from incomplete leaked PDF rather than current Anthropic docs.

| Primitive | Status | Detail |
|---|---|---|
| **Agent tool `model` parameter** | ✅ CONFIRMED | Empirically tested: spawned Haiku subagent via `Agent` tool with `model: "haiku"`; subagent self-reported as `claude-haiku-4-5-20251001`. Tier 2 heterogeneous critic invocation works as designed; no fallback needed. |
| **Stop hook + PreToolUse semantics** | ✅ CONFIRMED + bonus | Stop fires reliably once per turn; supports exit code 2 block + `{decision: "block"}` return. PreToolUse fires for Read tool. PreToolUse `if` field supports permission-rule path matching (e.g., `"if": "Edit(*.ts)"`) — **restore Tier 0 path-based deny as primary, not just defense-in-depth.** |
| **Agent Teams** | ✅ CONFIRMED (still experimental) | Activation: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`; min Claude Code v2.1.32+. Hooks: `TeammateIdle`, `TaskCreated`, `TaskCompleted`. Subagent definitions reusable as teammates. **Architecture is final-shape and stable enough for Phase 4 prototyping.** Documented limitations (no resume for in-process teammates; one team per session; etc.) surface in v5 docs. |

**Hook count corrected: 28 events** (one more than the v5 plan's "27" — the leaked PDF was older).

**Anthropic's own caveat about Agent Teams (verbatim, validates sibling §4.1 heterogeneity argument):** *"The lead makes approval decisions autonomously. To influence the lead's judgment, give it criteria in your prompt, such as 'only approve plans that include test coverage' or 'reject plans that modify the database schema.'"* — same-model rubber-stamp risk Anthropic itself recommends mitigating via explicit acceptance criteria.

**Bonus architectural clarification from docs:** Subagents (Agent tool) and Agent Teams are *different mechanisms*, not scale variants of the same thing.
- **Tier 2** uses subagents — own context window, results return to caller, no inter-subagent comms, lower token cost.
- **Tier 3** uses Agent Teams — own context windows, mailbox messaging between teammates, shared task list with file-locking, higher token cost.
- They use Anthropic's two distinct primitives by design. Clean architectural fit.

**Phase 0 is unblocked. Proceed.**

---

## Migration path: five phases, restructured

### Phase 0 — Tier 0 hardening (3–4 weeks)
**Goal: ship the strongest reliability primitive — external enforcement that the agent cannot bypass.**

- Hardcoded-blocking pre-commit hook running `ag verify` + contract checks + sentinel-state + journal-since-last-commit. No advisory escapes; `--no-verify` blocked unless `ag commit --skip-gate <reason>` (audited).
- Pre-push hook running full integration suite + contract coverage + doc-freshness drift.
- `ag merge` as the standard merge path with deterministic checks; documented git alias for users who want hard enforcement.
- Filesystem read-only protection for shipped contracts (chmod-based).
- Optional GitHub Actions YAML template (drop into `.github/workflows/agentic-gate.yml`) — same checks, runs on PR-merge for users with remotes.

**Observability spine (now standard, not optional):**
- **`events.jsonl` + `delegation.jsonl` + `token-ledger.jsonl`** — append-only canonical event streams. Every Tier 0/1/2 invocation writes events. Schema documented above.
- **`ag tui`** — Textual TUI mission-control view. Default terminal frontend. Five-panel layout (header / workers / events / health / drill-down). Reads JSONL, no server.
- **`ag watch`** — lightweight live event tail with color-coded formatting; for SSH sessions where TUI is too heavy.

**Quota awareness (subscription model — costs are capped by Claude Pro/Max plan):**

Under Claude subscription plans, $/month is fixed; the relevant constraint is **session quota** (5-hour rolling windows on Pro; higher on Max). Token-efficient framework operation = staying within quota = staying productive.

- **`ag intel report --quota`** — shows estimated quota usage in current 5h window: tokens consumed, % of typical Pro/Max ceiling, projected exhaustion time
- **TUI dashboard quota pane** — live quota burn-down ring; alerts at 70%/85%/95% so user can pause Tier 3 / `--teams` work before hitting the wall
- **Auto-degradation on quota pressure** (Phase 1+) — when within-window usage exceeds ~70%, auto-switch heavy ops (Tier 2 critic, Tier 3 worker dispatch) to lighter alternatives so the user finishes the session rather than getting cut off mid-feature
- **Pre-flight quota estimator** — before `ag auto epic` or `--teams` invocation, estimate token consumption and warn if the run would likely exhaust the current window (e.g., "this will likely use ~40% of your remaining 5h quota")
- **Heterogeneous worker tier as quota optimization, not cost optimization** — Haiku/Gemini Flash workers consume the same Anthropic subscription quota at lower per-token rates; non-Anthropic workers (Gemini, GPT, local Ollama) consume separate quotas / no quota; mix accordingly when subscription is tight

**Note: this section is NOT about $/month surprise bills.** Subscription users don't get surprise bills. The discipline here is staying within rolling-window limits so autonomous runs don't get cut off and human work isn't blocked.

**UX additions for Phase 0 (per UX review):**
- **`ag fix --skip-contract`** for hotfixes — pre-commit still requires test, but skips full spec requirement; audited
- **`ag onboard`** — generates `.agentic/ONBOARDING.md` for new contributors at init time. Don't defer to Phase 5; ship in Phase 0.
- **Pre-commit error messages suggest next steps** — not just "BLOCKED"; show concrete commands the user/agent can run to satisfy the gate

**Verification:** end-to-end test with `gh` uninstalled, no remote configured, agent runs in autonomous mode for 4 hours — hardcoded pre-commit blocks every commit attempt that lacks close-out artifacts. **The 2-day, 12-commit failure becomes structurally impossible at the git layer.**

### Phase 1 — Tier 1 voluntary intelligence reclaim (3–5 weeks)
**Goal: make the framework provably productive for the agent.**

- **Token Ledger visible** (`ag intel report --tokens`).
- **Anatomy PreToolUse:Read hook** — file summaries injected before Reads; warn on 3rd+ access. ~200 LoC; estimated 2–3× token efficiency on large repos.
- **`ag intel architecture | spec | implement | test`** — phase-aware context injection, richer than vanilla CC scratch-thinking.
- **`ag verify --explain`** — structured failure output, not raw stderr.
- **`ag delegate haiku-critic`** — first-class command for cheap second opinions.
- **Drop or refactor** any `ag` command that fails the "voluntary use" test. Specifically: stop maintaining trigger-word tables in memory-seed and instruction files; let skills be JIT context-providers, not rule-deliverers.

**Verification:** Token Ledger shows agent voluntarily invoking `ag intel` ≥80% of relevant phase entries within 30 sessions, without instruction-file prompts requiring it.

### Phase 2 — Tier 2 topology-by-default (3–4 weeks)
**Goal: structurally separate work-execution from work-acceptance in single-session work.**

- **Heterogeneous critic by default** for every plan and every PR-equivalent diff. Spawned via existing `Agent` tool with `--model haiku`. Default ON in formal and autonomous_formal; opt-in in discovery.
- **Harness-fired independent verification.** `ag verify` invoked by Stop hook + pre-commit + CI mirror. Verification.json written by harness, not worker. Worker cannot claim "tests pass."
- **`.claude/agents/critic-haiku.md`** + `verifier-deterministic.md` definitions shipped.

**Verification:** in autonomous mode, worker session attempts to commit with failing tests → pre-commit reads test output → blocks. Worker spawns plan → Haiku critic in fresh context disagrees → user sees both perspectives. Same-model rubber-stamp pattern from sibling §4.1 is structurally broken.

### Phase 3 — Operational-harness simplification (3–4 weeks)
**Goal: drop ~85% of `.agentic/lib/tools/*.sh` enforcement chains and AGENTS.json bookkeeping; lean on Claude Code primitives directly.**

- Migrate remaining bash hook chains to declarative entries in `settings.json` (where the hook actually fires reliably; Stop, pre-commit, etc.).
- Drop AGENTS.json + custom session tracking; read JSONL transcripts.
- Per-topic memory split with `@include` index.
- Append-only `events.jsonl` replaces destructive `journal.sh` mutations.
- Drop MCP coordinator as custom dispatch (or scope down to genuine external services only).

**Note:** Phase 3 follows Phase 2 deliberately — we drop the failed enforcement layer AFTER the new topology + Tier 0 enforcement is in place, not before. No reliability regression during transition.

### Phase 4 — Tier 3 Agent Teams adoption (4–6 weeks, when Anthropic stabilizes)
**Goal: structural break for Mode 3 (Fully Autonomous) and high-reliability `ag auto` runs.**

- Adopt `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (when promoted to stable).
- Teammate definitions in `.agentic/lib/agents/claude/teammates/` (planner, coder, critic, verifier).
- Full `ag auto task | epic | crunch` migration; single-session paths deleted.
- `TaskCompleted` hook calls Tier 0 gate set.
- Heterogeneous models: Sonnet lead, Haiku workers, optional Aider for AST-aware bulk edits.
- Frozen-fixture migration regression test.

### Phase 5 — Mode 2/3 autonomy spine + production gap (8–12 weeks)
**Goal: complete the autonomy story for users who want Mode 2/3, AND ship the production-gap items that directly unblock the user's two real projects.**

**Substrate flexibility:**
- `ag-mcp serve` — `ag` exposed as MCP tools; framework works in Claude Code Web + Anthropic Managed Agents.
- Local-model worker tier (Ollama / llama.cpp via OpenCode/Aider).
- Sentinel persistence interface with named backends (local FS, MCP server state).

**Mode 2/3 autonomy spine:**
- `ag kickoff "vision"` (vision → epic decomposition → backlog).
- `ag preview` (stack-aware dev-server / preview-deploy launcher).
- Feedback-from-running-software pipeline.
- `user_role` configuration (ADR-002 finalized).
- `review_commit: critical_agent` (Mode 3 prerequisite) — properly governed via Tier 0 gates and Tier 2 critic.

**Spec quality:**
- Spec clarification taxonomy (6/9-category ambiguity scan).
- Formal NFR specification system (`spec/nfr/NFR-XXXX.yaml`).
- Quality Checklist proactive surfacing (PreToolUse:Write injection, voluntary).
- `ag contract → tests scaffold F-XXX` for ATDD: auto-generate test stubs from contract assertions.
- `ag intel sync F-XXX` returning per-feature plan↔spec↔tests↔code↔docs synchronicity status.

**Verification loops (autonomous, multi-tier):**
- `ag auto verify` enhanced with Tier 2 harness-fired verification (3-iteration cap, escalates to HUMAN_NEEDED on cap-out).
- Tier 3 verifier teammate type for full Agent Teams verification flow.
- **Framework verification meta-loop (E1):** `ag auto verify-framework` builds a portfolio of example projects (todo CLI, REST API, web app, game, mobile app) end-to-end using the framework. Catches behavioral gaps no unit test finds. Runs nightly or on every framework PR. **Operationally reduces the 55% compliance-firefighting tax** by catching framework regressions before users do. Tier 3 mode: lead orchestrates example-project builds, verifier teammates run tests, critic teammates evaluate quality.

**Production gap (Theme J — directly blocking for the user's two projects):**
- **J7 Regulatory compliance modules** (GDPR / CCPA / HIPAA / SOC2 — opt-in by jurisdiction) — evidence + audit trail patterns. Generic across regulations; users enable the relevant module(s) for their target market.
- **J1 `ag deploy`** for web (Vercel / Netlify / Cloudflare Pages / Render / Fly.io).
- **J21 Localization workflow** (Crowdin / Lokalise / native i18n).
- **J11 Crash reporting integration** (Sentri / app-store crashlytics).
- **J5 Game / itch.io publishing channel** for Algebra Rush.

**Documentation honesty:**
- Document v2 → hooks-first decision in PRINCIPLES.md.
- Audit README + FRAMEWORK_QUICK_START against current code; mark aspirational items "requires Tier 3."
- **Add explicitly to HOW_IT_WORKS.md:** "Single-agent enforcement raises the ceiling; topology + external enforcement breaks it. The framework's Tier 0 (local external enforcement) is the bedrock; Tier 2 (topology-by-default) is recommended for any work that matters; Tier 3 (Agent Teams) is required for Mode 3 reliability. There is no path to autonomous reliability through more in-session rules."

**Plan-claimed total: ~22–32 weeks** (5–8 months) for solo execution.

**Realistic total per engineering review: 32–44 weeks solo** (8–11 months). The plan underestimates:
- `ag tui` (1000 LoC plan → 1800–2500 LoC realistic; first-time Textual)
- Anatomy hook (200 LoC plan → 600–1000 LoC realistic; cache invalidation, auto-regeneration)
- `ag deploy` (5 providers in 1–2 weeks → 1 week per provider × 5 + abstraction = 6–8 weeks)
- `ag auto verify-framework` meta-loop (1–2 weeks → 5–9 weeks; novel work, example projects, iteration)
- Production testing gap between phases (0 weeks → 2–4 weeks needed to find edge cases)

**With pair (2 engineers): 24–32 weeks. With team of 3: 18–24 weeks.**

Phase 0 ships in week 4–5.5 (realistic) and **delivers more reliability than the entire current framework** because external enforcement actually fires regardless of agent cooperation.

**Firefighting tax forecast (per engineering review):** Phases 0–2 will INCREASE firefighting short-term (~10–20 fix commits during rollout as new hooks introduce new bugs). Phase 3 deletion (~28K LoC bash tools) starts reducing it. Inflection point: Week 12–16. Net reduction visible by Week 22+.

---

## The catalog of abandoned ambitions (preserved from v4)

The plan retains the ~70-item catalog organized across 10 themes (A–G, G', H, I, J). Each item has source citation, effort estimate, and priority hint. The catalog is a triage menu the user picks from based on real needs.

The most user-impactful items remain:

### Theme A: User-facing autonomy (Mode 2/3 spine — Phase 5)
- A1 ★ Vision-to-backlog (`ag kickoff "vision"`)
- A2 `ag preview` (stack-aware dev-server / preview-deploy)
- A3 Feedback-from-running-software pipeline
- A4 User role + involvement configuration (ADR-002 finalization)
- A6 Auto-commit/merge with Tier 0 + Tier 2 gating

### Theme B: Spec quality
- B1 Spec clarification taxonomy
- B3 Formal NFR specification system
- B4 Quality Checklist proactive surfacing
- B5 Taste/style system (F-0183)

### Theme C: Token economy + intelligence
- C1 ★ Token Ledger visible
- C2 ★ Anatomy PreToolUse:Read hook
- C3 Memory-seed sync intelligence
- C4 STACK.md → YAML/TOML schema with validation
- C6 Skills marketplace finished

### Theme D: Multi-component / multi-team / scale
- D1 Multi-component architecture
- D2 Epics as parent features
- D5 Multi-agent parallel execution with worktree isolation

### Theme E: Verification + quality assurance
- E1 Autonomous framework verification loop
- E2 AC-level scheduling + parallel execution
- E4 Critical agent for autonomous reviews (now Tier 2 default)

### Theme F: Documentation honesty (Phase 5)
- F1 Document v2 → hooks-first decision
- F2 Audit README/FRAMEWORK_QUICK_START honesty
- **F5 (NEW): Document the structural-ceiling argument** in user-facing HOW_IT_WORKS.md

### Theme G': Hidden infrastructure aspirations (templates + profile orphans)
- G'1 Sequential agent pipeline (subsumed by Tier 3 Agent Teams)
- G'2 `design_phase` workflow
- G'5 Component interface contracts (monorepo)
- G'8 Ad-hoc plan-review experts (subsumed by Tier 2 critic + Theme D4 personas)
- G'12 `.agentic/local/` customization layer

### Theme H: Framework debug + introspection
- H1 ~~T-0094 fix~~ — **deprioritized** in v5; Tier 0 doesn't need it
- H2 Hooks-detection automation tests (resurrect for Tier 2 verification)
- H3 `debugging-framework` skill (resurrect narrowly)
- H5 NFR auto-generation stalled branch
- H6 Stalled MCP task delegation branch

### Theme J: Ship + iterate + handoff (production gap — Phase 5)
- J1 Web deployment (`ag deploy` for Vercel/Netlify/etc.)
- J5 Game / itch.io publishing
- J7 Regulatory compliance modules (GDPR / CCPA / HIPAA / SOC2, opt-in)
- J11 Crash reporting integration
- J15 Velocity / health-score dashboard
- J18 `ag onboard` new-contributor playbook
- J19 `ag handoff` vacation-coverage playbook
- J21 Localization workflow
- J22 Linear integration (alternative to GitHub Issues sync)
- J23 Persona-driven assertion generation

---

## File layout (target)

```
agentic-af/                          # Repo root
├── CLAUDE.md                        # ~80 lines, root constitution
├── .claude/
│   ├── settings.json                # Hook entries (Stop, pre-commit shim) + permission rules
│   ├── skills/                      # ~15 skills, JIT context-providers (NOT rule-deliverers)
│   └── agents/
│       ├── critic-haiku.md          # Tier 2 default heterogeneous critic
│       ├── verifier-deterministic.md# Tier 2 harness-fired verifier
│       ├── doc-drafter-haiku.md     # Cheap doc first pass
│       ├── bulk-refactor-aider.md   # Tool delegation
│       └── teammates/               # Tier 3 Agent Teams variants (Phase 4)
├── .agentic/
│   ├── lib/
│   │   ├── contracts.py             # KEEP
│   │   ├── gates.py                 # KEEP, extended with Tier 0 deterministic gates
│   │   ├── quality.py               # KEEP
│   │   ├── quality_knowledge/       # KEEP (21 files)
│   │   ├── delegation_policy.yaml   # NEW (Tier 2 worker routing)
│   │   ├── anatomy.yaml             # RECLAIM (F-041)
│   │   └── hooks/                   # 4–6 small Python hook scripts
│   │       ├── verify_runner.py     # Tier 0/2 — runs tests, writes verification.json
│   │       ├── precommit_gate.py    # Tier 0 — git pre-commit
│   │       ├── prepush_gate.py      # Tier 0 — git pre-push
│   │       ├── stop_gate.py         # Tier 2 — Stop hook deterministic verifier
│   │       ├── anatomy_inject.py    # Tier 1 — PreToolUse:Read voluntary value
│   │       └── delegation_router.py # Tier 2 — heterogeneous critic dispatch
│   ├── spec/
│   │   ├── FEATURES.md
│   │   ├── contracts/F-XXXX.yaml
│   │   ├── nfr/NFR-XXXX.yaml        # RECLAIM
│   │   └── adr/ADR-XXX.md
│   ├── session/                     # Sentinel files (gitignored)
│   ├── journal/
│   │   ├── events.jsonl             # NEW append-only event log
│   │   ├── delegation.jsonl         # NEW Tier 2 telemetry
│   │   ├── token-ledger.jsonl       # RECLAIM (F-041 Phase 2)
│   │   └── plans/YYYY-MM-DD-F-XXXX-plan.md
│   └── memory/                      # Per-topic + @include index
├── .git/hooks/
│   ├── pre-commit                   # Tier 0 — calls .agentic/lib/hooks/precommit_gate.py
│   └── pre-push                     # Tier 0 — calls .agentic/lib/hooks/prepush_gate.py
├── .github/workflows/               # OPTIONAL — for users with remotes
│   └── agentic-gate.yml             # CI mirror of Tier 0 (belt-and-suspenders)
├── docs/
│   ├── ARCHITECTURE.md              # NEW — this document, formalized
│   └── dashboard.html               # OPTIONAL — local static dashboard
├── ag                               # Single executable
└── ag-tui                           # OPTIONAL — Textual TUI binary
```

---

## Verification approach

Three properties must be proven before each Phase ships:

1. **Tier 0 enforcement is uncircumventable for typical agent behavior.**
   - Test: in autonomous mode for 4 hours with no human, the agent attempts close-out bypass. Result: pre-commit blocks every bypass attempt. `--no-verify` is blocked. Composite Bash chains targeting sentinels are denied. The 2-day, 12-commit failure becomes structurally impossible at the git layer.
   - **Crucially: this works without `gh` installed and with no remote configured.**

2. **Tier 1 commands pass the voluntary-use test.**
   - Test: in 30-session telemetry window, agent voluntarily invokes `ag intel` ≥80% of relevant entries WITHOUT instruction-file prompts requiring it. If <80%, the command fails the test → drop or rebuild.

3. **Tier 2 topology breaks self-certification.**
   - Test: heterogeneous critic disagrees with worker on ≥30% of plans and ≥10% of diffs over 30 sessions (proving real review, not rubber-stamp).
   - Test: harness-fired `ag verify` produces verification.json that the worker cannot pre-write or pre-empt (worker attempts to write verification.json directly → file is owned by harness process or has different mtime than tests imply → caught).

The sibling doc's bypass-test matrix (B01–B12 cross-profile), mutation tests (M01–M14), and discovery-command-matrix verification all carry over.

---

## Open questions (require user input before implementation)

1. **Transform vs. Agentic AF 2.** My recommendation: transform per the 5-phase sequencing above. Greenfield only if we explicitly drop cross-tool D7 *and* want to redesign the spec format itself.
2. **Tier 0 strictness in discovery.** Discovery defaults: should pre-commit be hardcoded-blocking (override sibling's `state_enforcement: warn` framing) or stay advisory? My instinct: hardcoded blocking. Discovery's lightness is in *content* (no contracts required), not in *enforcement* (commits should still verify).
3. **Tier 2 critic model selection.** Default Haiku, or should the user pick (Haiku / Gemini Flash / GPT-4o-mini / local model)? Heterogeneity argues for choice; simplicity argues for one default.
4. **Tier 3 Anthropic dependency.** Tier 3 depends on Agent Teams stabilizing. If Anthropic delays, do we ship a metaswarm-style alternative, or wait?
5. **Sandbox isolation.** Theme J + Mode 3 imply sandboxing. Anthropic Managed Agents covers this when used; for local-only deployment, do we ship Firecracker/Kata templates or defer?
6. **Local-only vs. remote-optional.** The plan commits to local-first with remote optional. Some Theme J items (CI mirror, GitHub Issues sync, Linear integration) are remote-only by nature. Confirm: these stay strictly opt-in, never required.
7. **Critic-on-every-plan default.** Tier 2 ships heterogeneous critic by default for Mode 1 too. ~2× tokens. Acceptable for solo/small-team users? Or default to opt-in for cost-sensitive users?

---

## Decisions explicitly made (revising the plan from prior iterations)

| Decision | Old plan | v5 plan | Rationale |
|---|---|---|---|
| Primary reliability mechanism | Single-session close-out gate (Tier 1 sibling) | **Tier 0 local external enforcement (pre-commit + pre-push + `ag merge`)** | Months of empirical failure proved single-agent self-enforcement asymptotes below required reliability. |
| T-0094 fix | First Phase 1 sub-task; "blocker for Phase 1" | **Demoted.** Tier 0 doesn't depend on PostToolUse for built-in tools. | Tier 0 fires at git layer, not via Claude Code hooks. |
| Path-based PreToolUse deny | Core close-out mechanism | **Defense-in-depth only.** Tier 0 is primary. | Claude-expert reviewer flagged path-based matching may not be supported by Claude Code; don't bet the architecture on unverified primitives. |
| Heterogeneous critic | Pillar 2 opt-in (Phase 3) | **Tier 2 default-on (Phase 2)** for formal+ profiles. | Same-model self-certification is the structural leak; cheapest break is heterogeneous critic. |
| Tier 2 / Agent Teams | Phase 4 (after operational simplification) | **Phase 4 (after Tier 0+1+2 core ships).** Sequencing unchanged but framing emphasizes it's the structural break for Mode 3, not a single-session reliability fix. | Single-session reliability comes from Tier 0+2. Tier 3 is for Mode 3 specifically. |
| Operational simplification | Phase 2 | **Phase 3** (after Tier 2 lands) | Drop the failed enforcement layer AFTER the new topology is in place; no reliability regression during transition. |
| Cross-tool stance | Files-only for Cursor/Copilot/Codex | **Files-only confirmed; pre-commit fires for them too** (it's at the git layer). They get Tier 0 for free; Tier 1 partially via `ag` CLI; not Tier 2/3. | Tier 0 being at git layer is a happy accident: it's universally portable. |
| GitHub dependency | Pillar 3 GitHub Issues sync was structural to DX story | **All GitHub usage is opt-in.** Local-first DX via `ag tui` / static HTML. GitHub Issues sync is one of several Linear-replacement options. | User explicitly requires framework-autonomous-from-GitHub. |
| The catalog of ~70 abandoned items | Five pillars framing | Same items, organized across the four tiers + production gap (Theme J) | Re-skin only; the catalog work is preserved. |

---

## Summary

The framework's core problem — proven over months of failure — is that **agents do not reliably follow framework rules.** This is structural (post-trained models weight user goals over framework instructions) and confirmed by both internal experience and external research (OpenAI Instruction Hierarchy paper, Anthropic agentic-misalignment research). Adding more in-session enforcement is more of what already failed.

The redesign inverts the center of gravity from "make agents follow rules" to **topology + external enforcement + voluntary intelligence**:

- **Tier 0 — Always-on local external enforcement** (pre-commit + pre-push + `ag merge` with hardcoded blocking gates). Fires regardless of agent cooperation because the agent doesn't manage these processes. Works fully offline; GitHub Actions optional belt-and-suspenders.
- **Tier 1 — Voluntary intelligence** (every `ag` command must be demonstrably better than the alternative; agent invokes voluntarily because it helps).
- **Tier 2 — Topology-by-default** (heterogeneous critic via Agent tool + harness-fired independent verification). Default-on in formal+ profiles. Breaks the same-context self-certification leak at ~2× token cost.
- **Tier 3 — Full orchestrator/worker** (Anthropic Agent Teams when stable, optional sandbox via Managed Agents). Required for Mode 3 reliability; opt-in for Mode 2.

**Local-first, GitHub-optional.** The framework runs end-to-end with `gh` uninstalled, no remote, fully offline. Cloud integrations are opt-in for users who want them.

**Cross-tool: state portable, enforcement Claude-first** — Cursor/Copilot/Codex get Tier 0 for free (it's at the git layer) plus `ag` CLI invocation; they don't get Tier 2/3 topology. Honest framing replaces the fictional D7 parity claim.

**For the user's two real projects (used as testbeds, not built into the framework's design):** Phase 0 (Tier 0 hardening) is the highest-value early ship — it structurally prevents the documented "12 commits + continue" failure at the git layer, regardless of agent compliance. Phases 1–2 add voluntary intelligence and Tier 2 topology. Phase 5 ships the production-gap items (`ag deploy`, regulatory-compliance modules, localization, crash reporting, game/itch.io publishing) that directly unblock the marketplace product and the Phaser game.

**Recommendation: transform in place, 5 phases, ~32–44 weeks realistic solo (8–11 months).** Phase 0 (4–5.5 weeks) alone delivers more reliability than the entire current framework because Tier 0 git-layer enforcement actually fires regardless of agent cooperation.

**The Pre-Phase-0 spike (completed 2026-04-26) validated all three load-bearing primitives** (Agent tool `model` parameter, Stop hook semantics + PreToolUse `if` field path matching, Agent Teams architecture). Reviewer-flagged risks were artifacts of working from incomplete leaked PDF; current Anthropic docs confirm everything v5 needs. **Phase 0 is unblocked.**

Greenfield (Agentic AF 2) was a hedge against architecture-level uncertainty. The spike removes that uncertainty; transform is the right call. Greenfield justified only by an explicit *product* decision to drop cross-tool support entirely AND redesign the spec format — neither of which the user has signalled.

**The user-facing message must be honest:** *"Single-agent enforcement raises the ceiling; topology + external enforcement breaks it."* This belongs in HOW_IT_WORKS.md verbatim. The framework's reliability is a function of which Tier the user is willing to invest in — not a promise that more rules will eventually achieve compliance.
