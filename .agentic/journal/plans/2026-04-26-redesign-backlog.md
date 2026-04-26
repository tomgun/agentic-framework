# Redesign Backlog (Agent-Ready)

> **Companion to:** `2026-04-26-framework-ground-up-redesign-plan.md` (v5)
> **Status:** Pre-Phase-0 spike completed 2026-04-26; all primitives validated. Phase 0 unblocked.
> **Total scope:** ~84 items across 5 phases, ~32–44 weeks solo realistic.

## How an agent picks up a backlog item

1. **Find the lowest-numbered item** with `Status: planned` and all `Deps:` shipped.
2. **Read the linked plan section** before starting. The R-NNN entry is a *summary*; plan section is *source of truth*.
3. **Branch:** `feat/R-NNN-<short-slug>` (e.g., `feat/R-001-precommit-gate`).
4. **Implement the ACs.** Don't expand scope; out-of-scope items are explicit.
5. **Verify** per the entry's verification block.
6. **Update item status:** `planned → in_progress → shipped` in this file.
7. **Open PR** referencing R-NNN in title; cross-link to plan section.

## Per-item field schema

- **Status:** `planned | in_progress | shipped | superseded`
- **Effort:** rough day estimate (1d = 1 engineer-day)
- **Deps:** other R-NNN items that must be shipped first; `—` if none
- **Plan ref:** section/anchor in v5 plan
- **Goal:** one sentence — what success looks like
- **Create / Modify:** absolute file paths
- **ACs:** numbered, testable assertions
- **Verify:** how to know it's done (commands, manual steps)
- **Out of scope:** explicit boundaries (prevents scope creep)

---

## Critical path (first sprint, week 1)

R-007 (JSONL schema) → R-001 (pre-commit gate) → R-002 (pre-push gate) → R-008 (TUI). After this, most other Phase 0–1 items can run in parallel.

---

## Phase 0 — Tier 0 hardening + observability spine + UX additions (4–5.5 weeks)

### R-007 · JSONL event spine schema + writer
**Status:** in_progress · **Effort:** 2d · **Deps:** —
**Plan ref:** plan §"Observability layer" + §"Canonical event streams"
**Goal:** Define the canonical JSONL schemas for `events.jsonl`, `delegation.jsonl`, `token-ledger.jsonl`; implement an append-only writer used by all subsequent hooks/CLIs.

**Create:**
- `/workspace/.agentic/lib/events.py` — schema dataclasses + `append_event()` writer with file-locking (`fcntl.flock`)
- `/workspace/.agentic/lib/schemas/events.schema.json` — JSON Schema for events.jsonl
- `/workspace/.agentic/lib/schemas/delegation.schema.json`
- `/workspace/.agentic/lib/schemas/token-ledger.schema.json`
- `/workspace/tests/test_events.py`

**ACs:**
1. Schema includes: `ts` (ISO8601 UTC), `session_id`, `type`, `feature`, `actor`, `payload` (free-form JSON)
2. Event types enumerated: `session_start`, `task_dispatch`, `tool_call`, `commit`, `test_run`, `critic_verdict`, `contract_check`, `human_needed`, `task_complete`, `session_end`, `gate_blocked`, `gate_skipped` (15+ canonical types)
3. `append_event()` is process-safe (uses `flock`); concurrent writers from parallel sessions don't corrupt JSONL
4. Schema validation: invalid payloads raise `ValidationError`, never silently dropped
5. JSONL line size soft cap: 8KB; payloads larger get truncated with marker
6. `.agentic/journal/events.jsonl` created if missing on first append; never deleted by writer

**Verify:**
- `pytest tests/test_events.py` passes
- Concurrent test: 4 processes append 1000 events each; resulting file has exactly 4000 valid JSONL lines
- Schema: `ajv validate -s events.schema.json -d events.jsonl` (or Python jsonschema equivalent) passes

**Out of scope:** Reader / projection logic (per-frontend; R-008 / R-009 / R-013 each implement their own readers).

---

### R-001 · `precommit_gate.py` — hardcoded-blocking pre-commit gate
**Status:** planned · **Effort:** 3d · **Deps:** R-007
**Plan ref:** plan §"Tier 0 — Always-on external enforcement" + §"Quality + verification capabilities" §7
**Goal:** Tier 0 pre-commit Python gate. Fires at `git commit` (separate process from Claude Code), runs harness verification, blocks on contract/sentinel/journal failures. No advisory escapes.

**Create:**
- `/workspace/.agentic/lib/hooks/precommit_gate.py`
- `/workspace/tests/hooks/test_precommit_gate.py`
- `/workspace/.git/hooks/pre-commit` (one-line shim → calls Python module)

**Modify:**
- `/workspace/.agentic/lib/tools/ag.sh` — wire `ag commit --skip-gate <reason>` flag

**ACs:**
1. Fires on `git commit` regardless of which agent triggered it; reads pytest/jest output via subprocess deterministically (handles timeout, subprocess crash, output truncation gracefully)
2. Calls `ag contract check` and blocks (exit 2) if any structural assertion fails
3. Validates `.plan-approved` sentinel exists when `plan_review_enabled: yes` in STACK.md; blocks otherwise
4. Verifies JOURNAL.md mtime is newer than last commit's parent in formal+ profiles; blocks otherwise
5. Detects modifications to `spec/contracts/*.yaml` files where `lifecycle: shipped` and `protection: contract`; blocks unless a new entry exists in the contract's `migrations:` array
6. Detects `git commit --no-verify` and rejects with message instructing `ag commit --skip-gate "<reason>"` instead
7. `ag commit --skip-gate <reason>` records the bypass via `events.append_event(type="gate_skipped", payload={"reason": ...})` and proceeds
8. Error messages suggest concrete next-step commands (not just "BLOCKED")
9. Test coverage ≥80% (per `.agentic/lib/quality_knowledge/code_quality.knowledge.md`)

**Verify:**
- `pytest tests/hooks/test_precommit_gate.py` passes (≥20 tests covering each AC)
- Manual: edit `src/foo.py` without adding a test → `git commit` blocks with "no test for code change; suggest: ag intel test F-XXX"
- Manual: `git commit --no-verify` → blocks with "use `ag commit --skip-gate <reason>`"
- Manual: edit `spec/contracts/F-002.yaml` (shipped, protection: contract) without migration entry → blocks
- Run `events.jsonl tail` after `--skip-gate` invocation; verify entry recorded

**Out of scope:** Hook integrity check (R-004), pre-push gate (R-002), Stop hook integration (R-206), Anatomy hook (R-103).

---

### R-002 · `prepush_gate.py` — pre-push integration suite + drift checks
**Status:** planned · **Effort:** 2d · **Deps:** R-001
**Plan ref:** plan §"Tier 0 — Always-on external enforcement"
**Goal:** Second-wall enforcement at git push. Runs full e2e suite + doc-freshness drift + contract coverage analysis.

**Create:**
- `/workspace/.agentic/lib/hooks/prepush_gate.py`
- `/workspace/tests/hooks/test_prepush_gate.py`
- `/workspace/.git/hooks/pre-push` (shim → Python module)

**ACs:**
1. Fires on `git push` regardless of remote
2. Runs full integration test suite (project-defined; reads `STACK.md` for test command); blocks on any failure
3. Calls `ag contract coverage` and blocks if any feature has `coverage < threshold` (default 80%)
4. Calls `bash .agentic/lib/tools/drift.sh --docs` and blocks on doc-freshness drift in formal+ profiles
5. Migration entry presence check (re-runs R-001 logic on full pushed range, not just last commit)
6. Skip mechanism: `git push --no-verify` blocked unless `ag push --skip-gate <reason>` (mirrors R-001)
7. Records push events via `events.append_event(type="push_attempt", ...)` regardless of outcome

**Verify:**
- Manual: push a branch with failing tests → blocks
- Manual: push a branch with stale `HOW_IT_WORKS.md` (touched by featured changes but not updated) → blocks
- `pytest tests/hooks/test_prepush_gate.py` passes

**Out of scope:** Tier 2 critic invocation (R-205); pre-push is deterministic only.

---

### R-008 · `ag tui` — Textual mission-control dashboard
**Status:** planned · **Effort:** 12d · **Deps:** R-007
**Plan ref:** plan §"Observability layer" → "Mission-control view"
**Goal:** Five-panel terminal dashboard live-tailing JSONL streams. Default frontend for monitoring autonomous work.

**Create:**
- `/workspace/.agentic/lib/tui/__init__.py`
- `/workspace/.agentic/lib/tui/app.py` — Textual `App` subclass
- `/workspace/.agentic/lib/tui/panels/{header,workers,events,health,drilldown}.py`
- `/workspace/.agentic/lib/tui/styles.css`
- `/workspace/tests/tui/test_panels.py`

**Modify:**
- `/workspace/.agentic/lib/tools/ag.sh` — add `cmd_tui()` dispatcher

**ACs:**
1. Header bar shows: feature ID, profile, mode, total tokens (vs Pro/Max quota %), elapsed, ETA when known
2. Workers panel: per-active-teammate live status (current step, time on task); reads `events.jsonl` filtered by `type=session_start/end + tool_call`
3. Events stream: live-tailing decisions/commits/verdicts with cost annotations; configurable filter
4. Health bar: green/yellow/red + escalation count + quota warning at 70%/85%/95%
5. Drill-down: keyboard `d` to expand selected item (diff, test output, contract assertions, decision rationale)
6. Quota burn-down ring updated every 30s from `token-ledger.jsonl`
7. Keyboard quit: `q`; help: `?`; abort run: `a` (with confirmation)
8. Works on macOS Terminal, iTerm2, Linux gnome-terminal, Windows Terminal; degrades gracefully when colors unsupported

**Verify:**
- Manual: run `ag tui` while a feature is being implemented; all five panels populate within 2 seconds
- Manual: trigger a test run; events stream shows the test_run event live within 1 second of file append
- `pytest tests/tui/test_panels.py` covers each panel's rendering logic with synthetic events

**Out of scope:** Web dashboard (Phase 5 R-501-related); cost projections beyond current quota window.

---

### R-009 · `ag watch` — lightweight terminal event tail
**Status:** planned · **Effort:** 2d · **Deps:** R-007
**Plan ref:** plan §"Observability layer" → frontends table
**Goal:** Color-coded `tail -f` style stream of events.jsonl for SSH sessions where Textual TUI is too heavy.

**Create:**
- `/workspace/.agentic/lib/watch.py`
- `/workspace/tests/test_watch.py`

**ACs:**
1. `ag watch` tails `events.jsonl` from current position; reads new lines as appended
2. Color-codes by event type (red=block/escalate, yellow=warn, green=success, blue=info)
3. Filter via `--filter type=critic_verdict` or `--filter feature=F-008`
4. `--since 1h` / `--since "2026-04-26 14:00"` time filtering
5. Pure Python stdlib + `colorama`; works in any POSIX shell, Windows cmd

**Verify:** Manual stream while running another command in another terminal; events appear within 1s.

**Out of scope:** Editing/seeking through history; that's `ag intel report`.

---

### R-003 · `ag merge` — local merge gate
**Status:** planned · **Effort:** 2d · **Deps:** R-001
**Plan ref:** plan §"Tier 0 — Always-on external enforcement" → "Local primitives"
**Goal:** Standard merge path with deterministic checks before allowing local merge to main. User can configure `git config alias.merge ag-merge` for hard enforcement.

**Create:**
- `/workspace/.agentic/lib/tools/commands/merge.sh`

**Modify:**
- `/workspace/.agentic/lib/tools/ag.sh` — wire `cmd_merge()`

**ACs:**
1. `ag merge <branch>` checks: feature shipped status in FEATURES.md, all ACs checked, no pending `user_input` in contracts, no failing tests in CI mirror (if configured)
2. Blocks merge with explicit failure messages
3. On success, runs `git merge --no-ff <branch>` with audited commit message
4. Records `events.append_event(type="merge_attempt", ...)` regardless of outcome

**Verify:** Manual: try to merge a branch with unchecked ACs → blocks. Try a clean branch → merges with `--no-ff`.

**Out of scope:** Auto-merge / auto-push (Phase 5 R-514).

---

### R-004 · Hook integrity check
**Status:** planned · **Effort:** 2d · **Deps:** R-001
**Plan ref:** plan §"Tier 0 honest-limit subsection"
**Goal:** SHA-256 baseline of hook scripts, agent definitions, settings.json hook entries; pre-commit verifies no tampering.

**Create:**
- `/workspace/.agentic/lib/integrity.py` — hash + verify logic
- `/workspace/.agentic/integrity.json` — baseline (committed to repo)
- `/workspace/tests/test_integrity.py`

**Modify:**
- `/workspace/.agentic/lib/hooks/precommit_gate.py` (R-001) — call `integrity.verify_all()` first

**ACs:**
1. Baselined paths: `.git/hooks/pre-commit`, `.git/hooks/pre-push`, `.agentic/lib/hooks/*.py`, `.claude/settings.json` (only the `hooks` field), `.claude/agents/*.md`
2. Mismatch on any path → exit 2 with "hook tampering detected; run `ag integrity update` to acknowledge"
3. `ag integrity update` regenerates baseline (audited via events.jsonl `type=integrity_baseline_updated`)
4. Baseline file `.agentic/integrity.json` committed to git; mismatches between baseline and HEAD also flagged
5. Skip mechanism: `INTEGRITY_SKIP=1` env var (logged with warning), only honored in CI

**Verify:**
- Manual: edit `.agentic/lib/hooks/precommit_gate.py` after baseline → next commit blocked
- `ag integrity update` → next commit succeeds; events.jsonl entry recorded

**Out of scope:** Real-time tamper detection (only commit-time); cryptographic signing (HMAC) — defer to R-209.

---

### R-005 · Filesystem read-only protection for shipped contracts
**Status:** planned · **Effort:** 1d · **Deps:** —
**Plan ref:** plan §"Tier 0 — Local primitives"
**Goal:** Set `chmod 444` on `spec/contracts/*.yaml` files where `lifecycle: shipped` and `protection: contract`. Crude but agent-cannot-bypass-without-deliberate-chmod.

**Create:** none (logic added to existing tools)

**Modify:**
- `/workspace/.agentic/lib/tools/commands/contract.sh` — `ag contract promote` runs `chmod 444` on promoted contract
- `/workspace/.agentic/lib/tools/commands/contract.sh` — `ag contract migrate` runs `chmod 644`, edits, then `chmod 444`

**ACs:**
1. After `ag contract promote F-XXX`, the file is `444`
2. Direct `Edit` of a 444 contract file fails with EACCES; agent sees clear error
3. `ag contract migrate F-XXX --reason "..."` is the only sanctioned mutation path
4. Tested on Linux + macOS (Windows skip — chmod semantics differ)

**Verify:** Manual: promote a contract; try to edit directly → fails. Run `ag contract migrate` → succeeds.

**Out of scope:** Cryptographic signing of contracts; immutability via filesystem features (chattr, etc.).

---

### R-006 · GitHub Actions YAML template (optional CI mirror)
**Status:** planned · **Effort:** 1d · **Deps:** R-001, R-002
**Plan ref:** plan §"Tier 0 — Remote primitives (optional)"
**Goal:** Drop-in `.github/workflows/agentic-gate.yml` template that runs the same Tier 0 checks on PR-merge for users with GitHub remotes.

**Create:**
- `/workspace/.agentic/lib/init/templates/.github/workflows/agentic-gate.yml`
- `/workspace/docs/CI_MIRROR.md` — usage notes

**Modify:**
- `/workspace/.agentic/lib/init/init.sh` — offer to copy template at init time (opt-in)

**ACs:**
1. Workflow runs on `push: branches: [main]` AND `pull_request: branches: [main]`
2. Calls `python3 .agentic/lib/hooks/precommit_gate.py --ci-mode` and `prepush_gate.py --ci-mode`
3. Uploads test results + verification.json as workflow artifacts
4. Posts PR comment summarizing gate results (success: silent; failure: detailed)
5. Documented as optional belt-and-suspenders, not required

**Verify:** Open a PR with failing tests in a fresh project that copied the template → CI fails with comment.

**Out of scope:** GitLab CI / Bitbucket templates (follow-up if requested).

---

### R-010 · `ag fix --skip-contract` — hotfix mode
**Status:** planned · **Effort:** 2d · **Deps:** R-001
**Plan ref:** plan §"UX additions for Phase 0"
**Goal:** Lightweight commit path for hotfixes. Tier 0 still requires test, but skips full spec/contract requirement; audited.

**Create:**
- `/workspace/.agentic/lib/tools/commands/fix.sh`

**Modify:**
- `/workspace/.agentic/lib/hooks/precommit_gate.py` — recognize `AGENT_FIX_MODE=1` env var (set by `ag fix`); skip contract-existence check, keep test requirement

**ACs:**
1. `ag fix "<short-message>"` opens an editor scaffold for a fix commit
2. Pre-commit still requires: a test added/modified, journal entry, no shipped-contract changes without migration
3. Pre-commit skips: spec-existence check, persona/platform completeness
4. All `ag fix` commits emit `events.append_event(type="hotfix_commit", payload={"reason": ...})`
5. Hotfix commits get `[hotfix]` tag in commit message footer

**Verify:** Manual: `ag fix "log offer staleness"` → write 1-line code change + 1-line test → commit succeeds in <2 min.

**Out of scope:** Auto-promoting hotfixes to features; that's manual user decision.

---

### R-011 · `ag onboard` — new-contributor playbook
**Status:** planned · **Effort:** 3d · **Deps:** —
**Plan ref:** plan §"UX additions for Phase 0" + Theme J18
**Goal:** Generates `.agentic/ONBOARDING.md` for a contributor joining an existing project. Different from `ag init` (new project).

**Create:**
- `/workspace/.agentic/lib/tools/commands/onboard.sh`
- `/workspace/.agentic/lib/init/templates/ONBOARDING.template.md`

**ACs:**
1. `ag onboard` reads STACK.md + FEATURES.md + recent journal + decision log; generates `.agentic/ONBOARDING.md`
2. Sections: project overview, tech stack, dev workflow, current focus, first-task suggestions, "people to ping if stuck"
3. Includes 5-minute "make your first commit" walkthrough that runs `ag commit` on a noop journal update
4. Pre-commit error messages reference `ONBOARDING.md` for context when applicable

**Verify:** Manual: clone a populated project → run `ag onboard` → ONBOARDING.md created → another agent reads it and can make first commit within 30 min.

**Out of scope:** Multi-tenant onboarding (different roles get different ONBOARDING.md) — Phase 5+ enhancement.

---

### R-012 · Pre-commit error messages with concrete next-step suggestions
**Status:** planned · **Effort:** 1d · **Deps:** R-001
**Plan ref:** plan §"UX additions for Phase 0"
**Goal:** Replace bare "BLOCKED" messages with structured guidance ("here's what to do next").

**Modify:**
- `/workspace/.agentic/lib/hooks/precommit_gate.py` (R-001) — replace `print("BLOCKED")` with structured `print_blocked(reason, suggestions)`
- `/workspace/.agentic/lib/hooks/messages.py` (new) — error message catalog

**ACs:**
1. Every block reason has 1–3 concrete next-step commands
2. Examples: "no test for code change" → "Run: ag contract → tests scaffold F-XXX, then write a failing test"
3. Examples: "shipped contract changed without migration" → "Run: ag contract migrate F-XXX --reason '<why>'"
4. Examples: "JOURNAL stale" → "Run: bash .agentic/lib/tools/journal.sh '<topic>' '<outcomes>' '<next>' '<blockers>'"
5. Optional `--verbose` flag prints expanded explanations + plan section refs

**Verify:** Trigger each AC failure path and confirm the suggested command actually fixes it.

**Out of scope:** I18n of error messages.

---

### R-013 · `ag intel report --quota` — Pro/Max session quota usage
**Status:** planned · **Effort:** 2d · **Deps:** R-007
**Plan ref:** plan §"Quota awareness (subscription model)"
**Goal:** Display estimated quota usage in current 5h rolling window. Reads token-ledger.jsonl.

**Create:**
- `/workspace/.agentic/lib/tools/commands/intel.sh` (extend) — `report --quota` subcommand

**ACs:**
1. `ag intel report --quota` shows: tokens consumed in last 5h, % of typical Pro/Max ceiling (configurable in STACK.md), projected exhaustion time
2. Breakdown by tier (Tier 0/1/2/3) and worker model (Sonnet/Haiku/Opus)
3. Alerts at 70%/85%/95% thresholds with explicit "consider pausing Tier 3 / --teams work"
4. Configurable via STACK.md: `quota_pro_max_window_tokens: 1500000` (or actual Pro/Max value when known)

**Verify:** Manual: run after a long session; numbers correlate with subjective usage.

**Out of scope:** True API quota query (Anthropic doesn't expose this directly to CLI); estimate-only.

---

### R-014 · TUI quota burn-down ring + alerts
**Status:** planned · **Effort:** 2d · **Deps:** R-008, R-013
**Plan ref:** plan §"Quota awareness"
**Goal:** Live quota visualization in `ag tui` header.

**Modify:**
- `/workspace/.agentic/lib/tui/panels/header.py` (R-008) — add quota ring widget

**ACs:**
1. Ring displays: current quota usage as a circular progress (0–100%)
2. Color: green (<70%), yellow (70–85%), orange (85–95%), red (>95%)
3. Tooltip on hover: breakdown by tier
4. Modal alert at 95% with "abort autonomous run?" prompt
5. Reads `token-ledger.jsonl` at 30s intervals

**Verify:** Manual: run a long session; ring color transitions through thresholds correctly.

**Out of scope:** Cross-session quota aggregation — single 5h window only.

---

### R-015 · `ag hooks register` + integrity baseline init
**Status:** planned · **Effort:** 1d · **Deps:** R-004
**Plan ref:** plan §"Tier 0 — Local primitives" + R-004
**Goal:** Single command installs git hooks + initializes integrity baseline. Idempotent.

**Create:**
- `/workspace/.agentic/lib/tools/commands/hooks.sh`

**ACs:**
1. `ag hooks register` writes `.git/hooks/pre-commit` and `.git/hooks/pre-push` shims that call the Python gates
2. Backs up any existing hooks to `.git/hooks/.backup-<timestamp>/`
3. Runs `ag integrity update` to baseline current hook contents
4. Idempotent: running again is a no-op (integrity confirms no changes needed)
5. `ag hooks unregister` reverses the install (restores backup)
6. Run automatically on `ag init`

**Verify:** Manual: `ag hooks register` in a fresh project → hooks installed, integrity baseline written, integrity.json committed by user. Run again → no changes.

**Out of scope:** Windows hook semantics (use git's native hook system; document caveats).

---

### R-016 · Phase 0 verification — bypass test battery (B01–B12)
**Status:** planned · **Effort:** 5d · **Deps:** R-001, R-002, R-003, R-004, R-005, R-010
**Plan ref:** plan §"Verification approach" + sibling-doc bypass tests
**Goal:** Adversarial test suite proving Tier 0 catches each documented bypass attempt. Cross-profile (discovery, formal, autonomous_formal).

**Create:**
- `/workspace/tests/bypass/B01_no_verify.sh` through `/workspace/tests/bypass/B12_chmod.sh`
- `/workspace/tests/bypass/run_battery.sh` — orchestrator

**ACs (each test is a single AC; full list in sibling-doc §10):**
1. B01 `Bash(rm .agentic/session/.close-out-pending)` blocked by integrity
2. B02 `Bash(sed -i 's/x/y/' src/foo.py)` blocked by pre-commit (no test)
3. B03 `Bash(: > .agentic/session/.close-out-pending)` blocked
4. B04 composite `Bash(true && rm sentinel && git commit)` blocked at any sub-step
5. B05 `Edit(file_path: ./src/spec/foo.py)` smuggling blocked on actual content classification
6. B06 STACK.md edit while sentinel present blocked
7. B07 PreToolUse.sh edit while sentinel present blocked by integrity
8. B08 `Bash(touch -d '+1 hour' .agentic/session/.verify-run)` blocked (content hash check)
9. B09 `git checkout -- JOURNAL.md` after sentinel cleared by doc-capture re-triggers sentinel
10. B10 silent edit of `**Files:**` section in spec blocked
11. B11 `Bash(python3 -c "open('.agentic/session/.close-out-pending', 'w').close()")` blocked
12. B12 `Bash(chmod 000 .agentic/session/.close-out-pending)` blocked
13. Each test runs three times: `discovery`, `formal`, `autonomous_formal` profiles
14. Pass criteria documented per profile (some are advisory in discovery, blocking in formal+)

**Verify:** `bash tests/bypass/run_battery.sh` runs all 12 × 3 = 36 cases; reports pass/fail matrix.

**Out of scope:** Mutation testing (M01–M14 in sibling doc) — tracked separately; do alongside Phase 1+.

---

## Phase 1 — Tier 1 voluntary intelligence (4–6 weeks)

### R-101 · Token Ledger visible
**Status:** planned · **Effort:** 2d · **Deps:** R-007
**Plan ref:** plan §"Pillar 4 reclaim C1"
**Goal:** `ag intel report --tokens` surfaces per-session + rolling-30-session token metrics.

**ACs:** (1) reads `token-ledger.jsonl`; (2) shows session + rolling 30; (3) breaks down by tier/model/feature; (4) outputs to TUI pane via R-008 + CLI report.
**Verify:** Manually invoke after several sessions; numbers match JSONL truth.

---

### R-102 · Anatomy file generation pipeline
**Status:** planned · **Effort:** 4d · **Deps:** —
**Plan ref:** plan §"Pillar 4 reclaim C2"
**Goal:** Generate `anatomy.yaml` containing per-file summaries (token estimate, role, related files).

**Create:** `/workspace/.agentic/lib/anatomy.py`, `/workspace/.agentic/anatomy.yaml`
**ACs:** (1) `ag anatomy generate` LLM-summarizes each tracked file into ≤2-line entry; (2) caches results; (3) regenerate-on-demand or `--all`; (4) handles binary files (skip with marker).
**Verify:** Fresh repo: `ag anatomy generate` produces valid YAML; spot-check 5 entries are accurate.

---

### R-103 · Anatomy PreToolUse:Read hook
**Status:** planned · **Effort:** 4d · **Deps:** R-102
**Plan ref:** plan §"Pillar 4 reclaim C2"
**Goal:** Inject file's anatomy entry as `additionalContext` before each Read tool call. Warn at 3rd+ access.
**Create:** `/workspace/.agentic/lib/hooks/anatomy_inject.py`
**ACs:** (1) PreToolUse:Read hook configured in `.claude/settings.json`; (2) reads `anatomy.yaml`; (3) injects 1–2 line summary before Read; (4) warns "you've accessed this file 3+ times — consider taking notes" via additionalContext.
**Verify:** Manual: read same file 4 times in a session; 3rd+ access shows warning.

---

### R-104 · Anatomy auto-regeneration on file edit
**Status:** planned · **Effort:** 3d · **Deps:** R-102
**Plan ref:** plan §"Pillar 4 reclaim C2"
**Goal:** PostToolUse:Write/Edit triggers `anatomy.yaml` entry refresh for the modified file.
**Create:** `/workspace/.agentic/lib/hooks/anatomy_refresh.py`
**ACs:** (1) hook fires after Write/Edit; (2) regenerates only the changed file's entry (not full repo); (3) idempotent on multi-edit batches; (4) failure to regenerate logs warning, doesn't block.
**Verify:** Edit a file; verify anatomy.yaml entry mtime newer than file mtime.

---

### R-105 · `ag intel architecture/spec/implement/test` enrichment
**Status:** planned · **Effort:** 4d · **Deps:** —
**Plan ref:** plan §"Tier 1 — voluntary use test"
**Goal:** Phase-aware context injection that's measurably richer than vanilla CC scratch-thinking.
**Modify:** `/workspace/.agentic/lib/tools/commands/intel.sh`
**ACs:** (1) `architecture` returns relevant ADRs + STACK summary; (2) `spec` returns contract + persona + platform context; (3) `implement` returns related code patterns + quality knowledge for the stack; (4) `test` returns assertion-derived test stubs.
**Verify:** Compare agent task completion with vs without each `intel` command; subjective improvement.

---

### R-106 · `ag verify --explain` structured failure output
**Status:** planned · **Effort:** 2d · **Deps:** R-001
**Plan ref:** plan §"Tier 1 — voluntary use test"
**Goal:** When tests fail, output structured "here's what failed, here's likely fix" instead of raw stderr.
**ACs:** (1) parses pytest/jest output; (2) for each failure: file, test name, assertion, suggestion; (3) groups related failures.
**Verify:** Trigger 3 different failure modes; output is parseable JSON.

---

### R-107 · `ag delegate haiku-critic` first-class command
**Status:** planned · **Effort:** 2d · **Deps:** —
**Plan ref:** plan §"Tier 1"
**Goal:** Cheap second-opinion command that spawns Haiku in fresh `Agent`-tool context with adversarial role.
**ACs:** (1) `ag delegate haiku-critic <plan|diff|spec> <ref>` invokes Agent tool with `model: "haiku"`; (2) returns approve/request-changes/escalate; (3) logs to delegation.jsonl.
**Verify:** Manual: invoke on a plan; receive verdict in <60s; cost <$0.05 per invocation.

---

### R-108 · `ag contract → tests scaffold F-XXX` (ATDD scaffolding)
**Status:** planned · **Effort:** 3d · **Deps:** —
**Plan ref:** plan §"Quality §2 ATDD"
**Goal:** Auto-generate test stubs from contract assertions; structural assertions → shell tests; behavioral → integration test stubs.
**ACs:** (1) reads `spec/contracts/F-XXX.yaml`; (2) for each `assertions.structural` entry, emits a runnable shell-test stub; (3) for each `assertions.behavioral`, emits a parameterized integration-test stub; (4) skips already-existing tests (check by name).
**Verify:** Generate from F-002.yaml; resulting stubs run and fail correctly (red phase of TDD).

---

### R-109 · Drop trigger-word table maintenance
**Status:** planned · **Effort:** 2d · **Deps:** —
**Plan ref:** plan §"Tier 1 — voluntary use test"
**Goal:** Remove trigger-word tables from memory-seed.md + 4 instruction files (CLAUDE.md, cursorrules, copilot, codex). Skills become JIT context, not rule-deliverers.
**ACs:** (1) trigger-word section removed; (2) skills updated to be informative/contextual, not directive; (3) memory-seed reduced by ~30 lines; (4) LLM tests adjusted to not assert trigger-word recognition.
**Verify:** Spot-check that agents still invoke `ag` commands voluntarily after the change (Phase 1 telemetry).

---

### R-110 · Quota auto-degradation on burn pressure
**Status:** planned · **Effort:** 3d · **Deps:** R-013, R-201
**Plan ref:** plan §"Quota awareness"
**Goal:** When 5h-window quota usage exceeds 70%, auto-switch heavy ops (Tier 2 critic, Tier 3 worker dispatch) to cheaper models.
**ACs:** (1) reads token-ledger.jsonl; (2) at 70% triggers degradation flag; (3) Tier 2 critic switches Sonnet → Haiku; (4) Tier 3 worker dispatch limits parallelism; (5) emits `events.append_event(type=quota_degraded, ...)`.
**Verify:** Synthetic high-usage scenario triggers degradation; behavior changes visibly in TUI.

---

### R-111 · Per-topic memory split + @include index
**Status:** planned · **Effort:** 2d · **Deps:** —
**Plan ref:** plan §"What's new" point 9 (per-topic memory)
**Goal:** Split monolithic auto-memory into topic files; `MEMORY.md` becomes `@include` index.
**ACs:** (1) existing `~/.claude/projects/.../memory/MEMORY.md` content split by topic (testing, deployment, framework-dev, etc.); (2) MEMORY.md becomes @include directives; (3) Claude Code's LLM-scanned memory selects relevant files per turn.
**Verify:** Open a session; relevant topic files surface (compare context size before/after).

---

### R-112 · Voluntary-use telemetry
**Status:** planned · **Effort:** 2d · **Deps:** R-007
**Plan ref:** plan §"Phase 1 verification"
**Goal:** Track `ag intel` invocation rate per session; measure whether agents voluntarily invoke vs ignore.
**ACs:** (1) every `ag intel <subcommand>` writes `events.append_event(type=intel_invoked, ...)`; (2) report shows invocation rate per phase; (3) target: ≥80% of relevant phase entries get an `ag intel` call within 30 sessions.
**Verify:** After 30 sessions, run report; if <80%, the command failed the "voluntary use" test → drop or rebuild.

---

## Phase 2 — Tier 2 topology-by-default (4–6 weeks)

### R-201 · Heterogeneous critic dispatch via Agent tool
**Status:** planned · **Effort:** 5d · **Deps:** —
**Plan ref:** plan §"Tier 2 — Topology-by-default" → "2a. Fresh-context critic"
**Goal:** Spawn Sonnet (default) or Haiku critic in fresh `Agent`-tool context. Validated by spike.
**Create:** `/workspace/.agentic/lib/critic.py`
**ACs:** (1) `critic.review(target, mode, model)` invokes Agent tool with selected model; (2) target = plan|diff|spec; (3) summary-only return parsed; (4) telemetry logged to delegation.jsonl; (5) blocks workflow on `request-changes` verdict.
**Verify:** `pytest tests/test_critic.py`; integration test: critic disagrees with worker on a deliberately-flawed plan.

---

### R-202 · `.claude/agents/critic-haiku.md` + `critic-sonnet.md`
**Status:** planned · **Effort:** 1d · **Deps:** —
**Plan ref:** plan §"Phase 2"
**Goal:** Static agent definitions for the critic role; reusable as Tier 2 subagent or Tier 3 teammate.
**Create:** Two YAML-frontmatter markdown files.
**ACs:** (1) `description`, `tools` (deny Edit/Write), `model`, adversarial role prompt; (2) loadable by Agent tool by name; (3) reusable in Agent Teams as teammate type.
**Verify:** Spawn via Agent tool with `subagent_type: critic-haiku`; verdict format consistent.

---

### R-203 · `.claude/agents/verifier-deterministic.md`
**Status:** planned · **Effort:** 1d · **Deps:** —
**Plan ref:** plan §"Tier 2 — 2b. Independent verification"
**Goal:** Deterministic-verifier agent definition; runs `ag verify` and reports without LLM judgment.
**Create:** Agent definition file.
**ACs:** Agent definition has `tools: [Bash]` allowlist limited to `ag verify` and read-only; LLM call shape returns structured JSON only.
**Verify:** Spawn; runs verify; returns structured pass/fail per AC.

---

### R-204 · Critic-on-every-plan integration
**Status:** planned · **Effort:** 3d · **Deps:** R-201, R-202
**Plan ref:** plan §"Tier 2 — Default-on in formal+"
**Goal:** Auto-invoke critic when `ag plan F-XXX` finishes drafting.
**Modify:** `/workspace/.agentic/lib/tools/commands/plan.sh`
**ACs:** (1) on plan finalization, critic invoked with `target: plan`; (2) verdict drives workflow gate; (3) `request-changes` returns plan to drafting; (4) `--no-critic` flag for emergencies (audited).
**Verify:** Run `ag plan F-XXX`; critic verdict appears in TUI; workflow proceeds only on approve.

---

### R-205 · Critic-on-every-diff integration
**Status:** planned · **Effort:** 3d · **Deps:** R-201, R-202
**Plan ref:** plan §"Tier 2 — Default-on"
**Goal:** Critic reviews each PR-equivalent diff (every commit on a feature branch).
**Modify:** `/workspace/.agentic/lib/hooks/precommit_gate.py` (R-001) — invoke critic post-checks if all gates pass.
**ACs:** (1) critic invoked on staged diff; (2) verdict logged; (3) `request-changes` blocks commit; (4) skip rules from R-211 honored (lint-only / test-only changes skip critic).
**Verify:** Commit a security-sensitive change; critic catches at least 1 issue.

---

### R-206 · Stop hook → harness-fired `ag verify`
**Status:** planned · **Effort:** 5d · **Deps:** R-001
**Plan ref:** plan §"Tier 2 — 2b. Independent verification"
**Goal:** Stop hook (validated by spike) runs `ag verify`; verification.json written by harness (separate process), not by worker.
**Create:** `/workspace/.agentic/lib/hooks/stop_gate.py`, `.claude/settings.json` Stop hook entry.
**ACs:** (1) Stop hook fires once per turn; (2) reads test command from STACK.md; (3) runs in subprocess; (4) writes verification.json with content-hash of source files at run time; (5) blocks session-stop if verification fails (exit 2 with "fix tests before continuing"); (6) emits events.jsonl entry per run.
**Verify:** Configure Stop hook; agent attempts to stop with failing tests → hook blocks. Worker pre-writes verification.json → harness overwrites with truth.

---

### R-207 · PreToolUse `if`-field path-deny for sentinels
**Status:** planned · **Effort:** 2d · **Deps:** —
**Plan ref:** plan §"Tier 0 honest-limit subsection" + spike outcome (now primary, not defense-in-depth)
**Goal:** Block writes to `.agentic/session/*` sentinel files via Claude Code's PreToolUse `if` field. Validated by spike.
**Modify:** `/workspace/.claude/settings.json` — add PreToolUse rule:
```json
{"if": "Edit(.agentic/session/*)", "permissionDecision": "deny"}
{"if": "Write(.agentic/session/*)", "permissionDecision": "deny"}
{"if": "Bash(rm .agentic/session/*)", "permissionDecision": "deny"}
```
**ACs:** (1) Edit on any sentinel path → deny; (2) Bash patterns matching destructive ops on sentinels → deny; (3) Allowed: read access; (4) Framework's own `ag` commands continue to work (use a different write path internally).
**Verify:** Manual attempts to edit/delete sentinels via Edit/Bash → all denied.

---

### R-208 · Critic prompt template
**Status:** planned · **Effort:** 2d · **Deps:** R-202
**Plan ref:** plan §"Tier 2 — 2a"
**Goal:** Adversarial role prompt for critic agents. Anti-prejudicing (ignore comments claiming prior review).
**Create:** Section in `.claude/agents/critic-{haiku,sonnet}.md`
**ACs:** (1) prompt explicitly framed adversarially; (2) instructs to ignore "approved by", "previously reviewed" comments in diff; (3) instructs to focus on contract assertions + spec; (4) instructs to escalate (not approve) on uncertain cases.
**Verify:** Run critic on a diff with prejudicing comments; verdict ignores comments.

---

### R-209 · Critic-disagreement telemetry
**Status:** planned · **Effort:** 2d · **Deps:** R-201, R-007
**Plan ref:** plan §"Tier 2 — Telemetry gate"
**Goal:** Measure critic-vs-worker disagreement rate. Targets: ≥15% on plans, ≥5% on diffs over 30-session window.
**ACs:** (1) every critic verdict logged to delegation.jsonl with `{plan_or_diff_hash, verdict}`; (2) `ag intel report --critic-disagreement` shows rolling rate; (3) below thresholds → escalate critic to higher-tier (Opus or multi-critic).
**Verify:** After 30 sessions, report shows actual rate; if <15% on plans, alarm.

---

### R-210 · Defect taxonomy + baseline catch-rate
**Status:** planned · **Effort:** 3d · **Deps:** —
**Plan ref:** plan §"Tier 2 — Telemetry gate"
**Goal:** Classify historical issues into a defect taxonomy; establish baseline catch-rate of Sonnet-as-worker; use as critic benchmark.
**Create:** `/workspace/docs/research/defect_taxonomy.md`
**ACs:** (1) categories: spec-drift, security, correctness, architecture, style, typo; (2) historical issues from ISSUES.md tagged into categories; (3) baseline measurement: which categories Sonnet-worker catches without critic.
**Verify:** Sample 30 historical issues; agreement with taxonomy ≥80%.

---

### R-211 · Critic-skip rules for low-risk diffs
**Status:** planned · **Effort:** 2d · **Deps:** R-205
**Plan ref:** plan §"Quota awareness — quota optimization"
**Goal:** Skip Tier 2 critic for low-risk diffs (docs-only, test-only, whitespace).
**Create:** `/workspace/.agentic/lib/critic_rules.yaml`
**ACs:** (1) skip if diff matches: `docs/**`, `*.md`, `**/test/**`, whitespace/comment-only; (2) deterministic linter handles instead; (3) `ag intel report --skipped-critics` shows opt-out rate.
**Verify:** Doc-only commit → critic skipped, but pre-commit + linter still run.

---

## Phase 3 — Operational simplification (3–4 weeks)

### R-301 · Migrate `.agentic/lib/tools/*.sh` to declarative settings.json hooks
**Status:** planned · **Effort:** 4d · **Deps:** Phase 2 stable
**Plan ref:** plan §"Phase 3"
**Goal:** Move bash hook chains from settings.json calls to declarative entries (type:shell with args).
**ACs:** (1) audit `.claude/settings.json` for bash-script invocations; (2) replace with declarative `{"type": "shell", "command": "python3 .agentic/lib/hooks/X.py"}`; (3) regression: all 11 existing transition gates still fire.
**Verify:** Run `tests/regression/all_gates.sh` — passes pre and post migration.

---

### R-302 · Drop AGENTS.json + `agents_helpers.py`
**Status:** planned · **Effort:** 3d · **Deps:** R-007
**Plan ref:** plan §"Phase 3"
**Goal:** Read JSONL transcripts instead of custom session bookkeeping.
**ACs:** (1) callers of `agents_helpers.py list/count-others` migrated to read JSONL; (2) AGENTS.json deletion safe (no other readers); (3) `wip.sh check` migrated to JSONL.
**Verify:** Multi-session collision detection still works; `count-others` returns correct count.

---

### R-303 · Drop `wip.sh` and related session-tracking scripts
**Status:** planned · **Effort:** 1d · **Deps:** R-302
**Plan ref:** plan §"Phase 3"
**Goal:** Replace with JSONL-based queries.
**ACs:** (1) `wip.sh` deleted; (2) callers migrated; (3) session-state retrieval via JSONL.
**Verify:** `bash .agentic/lib/tools/dashboard.sh` still works (reads JSONL now).

---

### R-304 · Append-only `events.jsonl` replaces `journal.sh` mutations
**Status:** planned · **Effort:** 2d · **Deps:** R-007
**Plan ref:** plan §"What's new" point 7
**Goal:** Convert destructive JOURNAL.md mutations to append-only events.jsonl writes; JOURNAL.md becomes generated index.
**ACs:** (1) `journal.sh` rewrites to append events.jsonl; (2) JOURNAL.md auto-generated by projection script; (3) old JOURNAL.md content archived once.
**Verify:** Journal entries from before/after migration both readable.

---

### R-305 · Drop MCP coordinator as dispatch / scope down
**Status:** planned · **Effort:** 2d · **Deps:** R-201
**Plan ref:** plan §"Phase 3"
**Goal:** Tier 2 critic via Agent tool replaces MCP coordinator's dispatch role. Keep MCP only for genuine external services.
**ACs:** (1) `ag mcp` commands surveyed; (2) coordinator code removed if no genuine external-service usage; OR (3) scoped down to GitHub API / Linear sync / etc. only.
**Verify:** Existing MCP-using code paths still work for the genuine cases.

---

### R-306 · Regression test parity for deleted modules
**Status:** planned · **Effort:** 5d · **Deps:** R-301..R-305
**Plan ref:** plan §"Section 3: Regression-Risk Hot-Spots" (engineering review)
**Goal:** 5 scenarios per deleted module proving behavior preserved.
**ACs:** (1) for each deleted bash script, identify ≥5 behavioral scenarios; (2) replicate each in pytest against new code path; (3) all pass.
**Verify:** `pytest tests/regression/` — green.

---

### R-307 · `ag upgrade --from=v0.7x` migration script
**Status:** planned · **Effort:** 4d · **Deps:** R-301..R-305
**Plan ref:** plan §"Section 3: Regression-Risk Hot-Spots"
**Goal:** Existing user projects on v0.7x can incrementally upgrade to v5.
**Create:** `/workspace/.agentic/lib/tools/commands/upgrade.sh`
**ACs:** (1) detects current version; (2) backs up old state (AGENTS.json, journal.sh outputs, etc.); (3) converts AGENTS.json → events.jsonl; (4) migrates legacy spec files to YAML; (5) updates hook references; (6) runs gate suite to verify no breakage.
**Verify:** Snapshot of a real v0.7x project; run upgrade; gate suite passes.

---

## Phase 4 — Tier 3 Agent Teams adoption (5–8 weeks; depends on Anthropic stabilization)

### R-401 · Teammate definitions
**Status:** planned · **Effort:** 4d · **Deps:** R-202, R-203
**Plan ref:** plan §"Tier 3 — Pattern A/B"
**Goal:** Reusable teammate types for Agent Teams.
**Create:** `.claude/agents/teammates/{planner,coder,critic,verifier}.md`
**ACs:** (1) each has YAML frontmatter (name, description, tools, model, prompt body); (2) reuses subagent format (works as both); (3) tested via in-process Agent Teams.
**Verify:** Spawn each teammate type via Agent Teams; works as expected.

---

### R-402 · `--teams` flag implementation
**Status:** planned · **Effort:** 5d · **Deps:** R-401
**Plan ref:** plan §"Tier 3 — Pattern B"
**Goal:** Generic `--teams` flag on `ag implement|refactor|review|verify` invokes Agent Teams for that task.
**Modify:** Multiple `commands/*.sh`
**ACs:** (1) flag dispatches to Agent Teams setup; (2) lead session prompt includes specific acceptance criteria for the task; (3) cost telemetry logged; (4) flag works in any profile/mode (not just Mode 3).
**Verify:** `ag implement F-XXX --teams` spawns lead + teammates; completes feature.

---

### R-403 · TaskCompleted hook gate
**Status:** planned · **Effort:** 3d · **Deps:** R-001, R-401
**Plan ref:** plan §"Tier 3"
**Goal:** Hook calls Tier 0 gate set when teammate marks task complete; lead can't approve without Tier 0 passing.
**Create:** `.agentic/lib/hooks/task_completed_gate.py`
**ACs:** (1) hook invoked on TaskCompleted; (2) runs Tier 0 gates; (3) exit 2 if any fails; (4) feedback delivered to teammate to fix.
**Verify:** Teammate completes task with failing tests; lead receives feedback; teammate retries.

---

### R-404 · `ag auto task|epic|crunch` migration to Agent Teams
**Status:** planned · **Effort:** 8d · **Deps:** R-401, R-403
**Plan ref:** plan §"Phase 4"
**Goal:** Full migration; delete single-session paths in `auto/*.py`.
**ACs:** (1) `task.py`, `epic.py`, `crunch.py`, `pipeline.py`, `scheduler.py` rewritten to use Agent Teams; (2) old single-session code paths deleted; (3) frozen-fixture regression test passes.
**Verify:** Run `ag auto epic F-008` end-to-end; works via Agent Teams.

---

### R-405 · Frozen-fixture migration regression test
**Status:** planned · **Effort:** 5d · **Deps:** R-404
**Plan ref:** plan §"Section 3: Regression risk hot-spots — Frozen-fixture"
**Goal:** Outcome equivalence (not byte equivalence) between pre/post-migration runs of same epic spec.
**ACs:** (1) baseline `ag auto epic F-XXX` run captured (commits made, tests written, contracts satisfied, files touched); (2) new path runs same spec; (3) outcome metrics within tolerance (commits-count ±1, tests-added ≥ baseline, contract coverage ≥ baseline, all `ag contract check` pass).
**Verify:** `tests/regression/agent_teams_migration.sh` — passes.

---

### R-406 · Heterogeneous-model team config
**Status:** planned · **Effort:** 2d · **Deps:** R-401
**Plan ref:** plan §"Tier 3"
**Goal:** Default team config: Sonnet lead + Haiku workers + optional Aider for AST-aware bulk edits.
**ACs:** (1) team config in STACK.md or settings; (2) lead's spawn prompts use Haiku for workers by default; (3) escalation to Sonnet workers via flag.
**Verify:** Spawn team; verify worker model assignments.

---

### R-407 · `ag intel report --teams` cost-effectiveness telemetry
**Status:** planned · **Effort:** 3d · **Deps:** R-007, R-404
**Plan ref:** plan §"Tier 3 — Telemetry-driven discipline for Pattern B"
**Goal:** Per-`--teams` invocation: cost, time, outcome, escalation count. Over time, user assesses Tier 3 ROI.
**ACs:** (1) every `--teams` call logged; (2) report shows cost-per-passed-AC, escalation rate, time-saved-vs-single-session; (3) recommendations: "Tier 3 paid off in 60% of invocations; consider for X but not Y."
**Verify:** After 20 invocations, report shows useful patterns.

---

### R-408 · Document Agent Teams limitations
**Status:** planned · **Effort:** 1d · **Deps:** —
**Plan ref:** plan §"Bonus" + spike report
**Goal:** Surface known limitations in HOW_IT_WORKS.md (no resume for in-process teammates, one team per session, etc.).
**ACs:** Section in HOW_IT_WORKS.md verbatim from spike report's Primitive 3 limitations list.
**Verify:** Section present; cross-linked from `--teams` flag help.

---

## Phase 5 — Substrate flexibility + Mode 2/3 spine + production gap (10–16 weeks)

> Phase 5 entries are intentionally lighter; expand to full agent-ready detail when picked up.

### Substrate flexibility

- **R-501** `ag-mcp serve` — full `ag` surface as MCP tools (6d). For Claude Code Web + Managed Agents.
- **R-502** Local-model worker tier — Ollama/llama.cpp via OpenCode/Aider (5d). Cloud-orchestrator + local-worker hybrid pattern.
- **R-503** Sentinel persistence interface (4d). Backends: local FS / MCP server state.

### Autonomy spine (Mode 2/3)

- **R-510** `ag kickoff "vision"` (8d, deps R-105). Vision → epic decomposition → ACs → backlog.
- **R-511** `ag preview` stack-aware dev-server launcher (5d).
- **R-512** Feedback-from-running-software pipeline (4d, deps R-510). Auto-categorize → ISSUES/FEATURES/AC adjustments.
- **R-513** User role + involvement configuration (3d). ADR-002 finalized.
- **R-514** `review_commit: critical_agent` setting (2d, deps R-201, R-403). Mode 3 prerequisite (R2 amendment).
- **R-515** Critical agent for autonomous reviews (4d, deps R-201). Separate-instance adversarial review at gates.

### Spec quality

- **R-520** Spec clarification taxonomy (4d). 6/9-category ambiguity scan + max-5 multiple-choice.
- **R-521** Formal NFR specification system `spec/nfr/NFR-XXXX.yaml` (3d).
- **R-522** Quality Checklist proactive surfacing (2d). PreToolUse:Write injection.
- **R-523** `ag intel sync F-XXX` synchronicity reporter (3d). plan↔spec↔tests↔code↔docs status.

### Verification loops

- **R-530** `ag auto verify --loop` (4d, deps R-206). Iteration-capped verification with HUMAN_NEEDED escalation.
- **R-531** `ag auto verify-framework` (12d, deps R-510). Framework verification meta-loop. Builds portfolio of example projects (todo CLI, REST API, web app, game, mobile) end-to-end. **Directly attacks 55% firefighting tax.**

### Production gap (Theme J)

- **R-540** `ag deploy` framework + Vercel adapter (5d).
- **R-541** `ag deploy netlify` adapter (3d, deps R-540).
- **R-542** `ag deploy cloudflare-pages` adapter (3d, deps R-540).
- **R-543** `ag deploy render` + `ag deploy fly.io` adapters (5d, deps R-540).
- **R-544** Regulatory-compliance module: GDPR (5d). Opt-in. Evidence + audit trail patterns + DPA template.
- **R-545** Regulatory-compliance module: CCPA (3d, deps R-544).
- **R-546** Regulatory-compliance modules: HIPAA + SOC2 (5d, deps R-544).
- **R-547** Localization workflow (6d). Crowdin/Lokalise + i18next/FormatJS integration.
- **R-548** Crash reporting integration (4d). Sentry + app-store crashlytics adapters.
- **R-549** Game/itch.io publishing channel (2d).
- **R-550** Marketing copy generation (3d). Feature → 3 audience variants.
- **R-551** Release notes auto-generation (2d). Extract from CHANGELOG/journal/contracts.
- **R-552** Velocity / health-score dashboard (4d, deps R-008).

### Documentation honesty

- **R-560** Document v2 → hooks-first decision in PRINCIPLES.md / HOW_IT_WORKS.md (1d).
- **R-561** Audit README + FRAMEWORK_QUICK_START.md — mark aspirational items honestly (2d).
- **R-562** Add structural-ceiling argument to HOW_IT_WORKS.md verbatim (1d).
- **R-563** Document sentinel-file pattern as canonical reference (1d).

---

## Aggregate

| Phase | Items | Effort (days) | Calendar (solo) |
|---|---|---|---|
| Phase 0 | 16 | 41 | 4–5.5 weeks |
| Phase 1 | 12 | 33 | 4–6 weeks |
| Phase 2 | 11 | 29 | 4–6 weeks |
| Phase 3 | 7 | 21 | 3–4 weeks |
| Phase 4 | 8 | 31 | 5–8 weeks |
| Phase 5 | ~30 | 110 | 10–16 weeks |
| **Total** | **~84** | **~265** | **32–44 weeks** |

**First sprint (week 1):** R-007 → R-001 → R-002 → R-008 (critical path establishes Tier 0 + observability spine).

**Parallelization opportunities after Phase 0:**
- Phase 1 items R-101…R-112 can run in parallel once R-007 is shipped
- Phase 0 R-005, R-006, R-010, R-011, R-013, R-014 can run in parallel with R-001/R-002
- Phase 2 R-202, R-203 (agent definition files) can be drafted before R-201 lands

**Critical path summary:** R-007 (JSONL spine, 2d) → R-001 (pre-commit gate, 3d) → R-008 (TUI, 12d) is ~17 days. Everything else can fan out after.
