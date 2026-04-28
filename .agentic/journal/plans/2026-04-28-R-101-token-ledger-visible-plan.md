---
plan_id: R-101-token-ledger-visible
date: 2026-04-28
backlog_ref: 2026-04-26-redesign-backlog.md §R-101
status: APPROVED
profile: autonomous_formal
plan_review_enabled: yes
reviewers: critic, advocate
review_round: 3
convergence_round: 3
convergence_verdicts: critic=APPROVE-WITH-MINOR-NOTES, advocate=APPROVE
deps_satisfied: R-007 (shipped — events.append_token_ledger primitive), R-013 (shipped — quota.py reader), R-014 (shipped — TUI ring), R-015 (shipped — hook integrity baseline owns Stop hook)
scope_change: expanded from read-only projection (2d) to emission + read-side + TUI (5d) to fix the spec gap
---

# R-101 — Token Ledger visible (with usable data), v3 APPROVED

## Why this expansion exists

The original R-101 in the redesign-backlog (lines 451–457) reads:
> **Goal:** `ag intel report --tokens` surfaces per-session + rolling-30-session token metrics.
> **ACs:** (1) reads `token-ledger.jsonl`; (2) shows session + rolling 30; (3) breaks down by tier/model/feature; (4) outputs to TUI pane via R-008 + CLI report.
> **Deps:** R-007.

The spec assumes `token-ledger.jsonl` is populated. Reality:

- `events.append_token_ledger()` exists at `.agentic/lib/events.py:408` (R-007 ship).
- `quota.py` (R-013) already reads it, with breakdowns by tier/model — its 5h-window projection is a superset of AC-3 minus the session/30-window cut.
- The TUI quota ring (R-014) already visualizes it.
- **No production code calls `append_token_ledger`.** Only `tests/test_events.py:304,324` does. Confirmed via grep.
- `.agentic/journal/token-ledger.jsonl` does not exist.
- `quota.py:22-27` documents this: *"If those hooks miss a request… the report under-counts."*

Phase 1's stated purpose in the v5 plan is *"make the framework provably productive for the agent"* — voluntary use because the report helps the agent self-optimize. **A report showing zeros fails the voluntary-use test cold.** Shipping R-101 read-side as specced is procedurally complete and substantively useless.

The fix is not a new R; per the no-feature-inflation rule, hardening of the existing token-ledger pipeline is a deliverable on R-101 itself. This plan expands R-101 to include emission so the read-side has data to read.

## Goal (revised)

After R-101, an agent running a normal Claude Code session in this repo writes a `token-ledger.jsonl` entry per assistant turn (without changing agent behavior), and `ag intel report --tokens` projects current-session + rolling-30-session usage — both via CLI and a TUI pane that complements the existing R-014 quota ring.

## Surface inventory (anchor for changes)

| Surface | Location | Status |
|---------|----------|--------|
| `append_token_ledger(...)` | `.agentic/lib/events.py:408` | exists; validated; flock-safe |
| Token-ledger JSONL schema | `.agentic/lib/schemas/token-ledger.schema.json` | exists |
| `validate_token_ledger` | `.agentic/lib/events.py:225` | accepts `tokens_in`, `tokens_out`, `cache_read_tokens`, `cache_write_tokens`, `cost_usd`, `delegation_id`, `feature`, `actor`, `tier ∈ TIERS`, `model` |
| `quota.py` 5h projection | `.agentic/lib/quota.py` | reads ledger, breaks down by tier+model, alerts at 70/85/95% |
| `ag intel report --quota` | `.agentic/lib/tools/commands/intel.sh:112-181` | dispatches `python3 -m quota` |
| TUI quota ring (R-014) | `.agentic/lib/tui/panels/header.py` | live-updates from ledger |
| Stop hook chain | `.claude/hooks.json` `Stop` event | exists; integrity-baselined (R-004/R-015) |
| Claude Code transcript | `~/.claude/projects/<encoded-cwd>/<sessionId>.jsonl` (slashes→dashes; `/workspace` → `-workspace`, `/workspace-f-006` → `-workspace-f-006`) | per-turn fields verified by probe: `type`, `isSidechain`, `sessionId`, `timestamp`, `cwd`, `gitBranch`, `version`, `message.model`, `message.usage` (with `input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`, `service_tier`) |
| Hook integrity baseline | `.agentic/integrity.json` (R-004) | will need regeneration via `ag integrity update` after settings.json + new hook script land |
| Active-feature sentinel | `.agentic/session/AGENTS.json` | currently `[]`; existing wip.sh reads it |
| **F-041 session intel ledger (DIFFERENT subsystem; naming collision)** | `.agentic/session/token-ledger.json` (singular `.json`, single object) | written by `.agentic/lib/claude-hooks/Stop.sh:80-104` per session: `reads`, `writes`, `unique_files_read`, `repeated_reads`, `estimated_context_cost`. Read by `tests/test_intel_{gaps,anatomy,integration}.sh`. **Not stale. Not deleted.** |
| R-007 token-spend ledger (this plan's target) | `.agentic/journal/token-ledger.jsonl` (plural `.jsonl`, append-only records) | the target this plan emits to via `events.append_token_ledger()` |

## New components

### Component 1 — Token emission Stop-hook + SessionStart recovery (~1.5d)

**Create:** `/workspace/.agentic/lib/hooks/token_emit.py`

Two entry points sharing one parsing core:
- `python3 -m hooks.token_emit stop` — invoked by the Stop hook chain
- `python3 -m hooks.token_emit recover` — invoked by SessionStart to catch up on turns left behind by abrupt termination (Ctrl+C, terminal close, OOM kill — Stop never fires for those; see R7)

**Stop-hook stdin contract (per Anthropic Stop hook envelope, ref. claude.com/docs/en/hooks):** the hook receives a JSON payload on stdin with these fields:
```json
{
  "session_id": "<uuid>",
  "transcript_path": "/home/<user>/.claude/projects/<encoded-cwd>/<sessionId>.jsonl",
  "cwd": "/workspace",
  "hook_event_name": "Stop",
  "stop_hook_active": false
}
```

The `transcript_path` is **authoritative**. We do not enumerate the projects directory and we do not use mtime as a fallback — under parallel sessions and worktree projects (where `cwd` encoding produces directories like `~/.claude/projects/-workspace-f-006/`), mtime selection picks the wrong file. If stdin is empty or `transcript_path` is missing, the hook logs `{type: "token_emit_skipped", payload: {reason: "no_transcript_path"}}` to events.jsonl and exits 0. **No fallback enumeration.**

**Recovery-mode contract (SessionStart):** SessionStart receives a similar envelope with `session_id`, `cwd`, and `transcript_path`. The recovery handler reads watermarks, finds entries for `session_id`s whose transcripts have unprocessed turns past their watermark (or no watermark at all), and processes them. This closes the Ctrl+C data-leak gap.

**Other inputs:**
- `CLAUDE_PROJECT_DIR` env var (project root) for resolving `.agentic/` paths
- High-water-mark file `/workspace/.agentic/session/.token-ledger-watermarks.json` (created on first run; gitignored; format `{<sessionId>: <last_processed_uuid>}`); pruned to last-30-days on each invocation (R2 mitigation)

**Behavior (shared core):**
1. Acquire `flock` on the watermark file (cross-process safe).
2. Read last-processed UUID for `sessionId`. Absent → start from beginning.
3. Stream transcript JSONL line-by-line. **Skip:** lines where `type != "assistant"`, `isSidechain == true`, or `message.usage` is absent. For each remaining turn past the watermark:

   ```python
   usage = line["message"]["usage"]
   append_token_ledger(
       session_id=line["sessionId"],
       model=line["message"]["model"],
       tier=current_tier(),                # see Component 4
       tokens_in=int(usage["input_tokens"]),                      # NET NEW input only
       tokens_out=int(usage["output_tokens"]),
       cache_read_tokens=int(usage.get("cache_read_input_tokens", 0)),
       cache_write_tokens=int(usage.get("cache_creation_input_tokens", 0)),
       feature=current_feature(line.get("cwd"), line.get("gitBranch")),  # see Component 4
       actor="assistant",
       ts=line["timestamp"],
   )
   ```

   **Critical accounting choice (resolves Critic M1 + Open Q2):** `tokens_in` carries ONLY `input_tokens` (net-new prompt tokens). Cache-creation tokens go to `cache_write_tokens`; cache-read tokens to `cache_read_tokens`. This matches the convention `quota.py:228` already uses (`ti = _coerce_int(rec.get("tokens_in"))` summed straight as billable input — line 233 `line_total = ti + to`). If we had summed `cache_creation_input_tokens` into `tokens_in`, R-013's quota report would silently inflate vs. all numbers it produced before R-101 — a G5 regression. The schema's separate `cache_write_tokens` field exists exactly so callers needing cache-aware accounting can compute it themselves.

4. Update watermark to the UUID of the last successfully processed turn (atomic write to a temp file then rename, all under flock). Release flock.
5. **Defensive schema-drift logging (R9 mitigation):** if `usage` is present but missing `input_tokens` or `output_tokens` (the contract minimum), emit `{type: "token_emit_schema_change", payload: {sessionId, line_no, observed_keys}}` to events.jsonl. This lets the user see Anthropic-side schema drift before it becomes a silent count drop.
6. On any exception: log to `events.jsonl` as `{type: "token_emit_skipped", payload: {reason, line_no}}` and continue. Hook NEVER blocks (always returns exit 0 — telemetry must not gate work).

**Idempotence:** running the hook twice without new turns is a no-op. Tested explicitly (G3).

**Skip rules (logged, not failed):**
- Transcript file missing → emit telemetry skip event, exit 0
- `transcript_path` missing from stdin → emit skip event, exit 0 (no fallback)
- `message.usage` absent on a turn → skip line, continue
- `tokens_in`/`tokens_out` non-int or negative → skip line, log validation error
- Sidechain (`isSidechain: true`) → skip; tracked via R-201 dispatcher when that lands

### Component 2 — `.claude/hooks.json` registration (~0.5d)

**Modify:** `/workspace/.claude/hooks.json` — add ONE entry to existing `Stop` array AND ONE entry to existing `SessionStart` array:

```json
// Stop chain — emit ledger for just-completed turn
{
  "type": "command",
  "command": "${CLAUDE_PROJECT_DIR}/.agentic/lib/claude-hooks/Stop-token-emit.sh",
  "timeout": 5000,
  "description": "Emit token-ledger records for the just-completed turn(s) (R-101)"
}

// SessionStart chain — recover any turns left behind by abrupt termination
{
  "type": "command",
  "command": "${CLAUDE_PROJECT_DIR}/.agentic/lib/claude-hooks/SessionStart-token-recover.sh",
  "timeout": 5000,
  "description": "Recover unprocessed token-ledger entries from prior session crashes (R-101)"
}
```

**Create:**
- `/workspace/.agentic/lib/claude-hooks/Stop-token-emit.sh` — thin shim execs `python3 -m hooks.token_emit stop`
- `/workspace/.agentic/lib/claude-hooks/SessionStart-token-recover.sh` — thin shim execs `python3 -m hooks.token_emit recover`

Both with `PYTHONPATH` set to `.agentic/lib` and `set -euo pipefail`. Both follow existing shim conventions so they compose with current chain order without ordering coupling.

**Integrity-baseline ordering procedure (resolves Critic M5):** because R-001's pre-commit gate verifies the integrity baseline FIRST (R-004 ship), changing hook scripts and `.claude/hooks.json` in the same commit as the baseline is a chicken-and-egg. The mandated commit sequence is:

1. Write hook script + edit `hooks.json` (working tree only — do NOT commit yet)
2. Run `ag integrity update` — regenerates `.agentic/integrity.json` (this command is itself audited; emits `integrity_baseline_updated` to events.jsonl)
3. Stage all three (hook script, hooks.json, integrity.json) together
4. `git commit` — pre-commit gate now matches the new baseline; passes

This procedure is documented in commit-2's commit message + tested in G4.

### Component 3 — `ag intel report --tokens` reader (~1.5d)

**Modify:** `/workspace/.agentic/lib/quota.py` — add a second projection:

```python
@dataclass(frozen=True)
class TokenReport:
    current_session: SessionRow             # totals + first/last ts + breakdown
    rolling_window: list[SessionRow]        # most-recent N sessions (default N=30)
    by_tier: dict[str, int]                 # across rolling window
    by_model: dict[str, int]
    by_feature: dict[str, int]              # AC-3
    record_count: int
```

`SessionRow` carries `session_id`, `started_at`, `ended_at`, `tokens_in`, `tokens_out`, `cache_read`, `model`, `tier`, `feature`. `tokens_total = tokens_in + tokens_out` for quota arithmetic. (Cache reads ARE billed by Anthropic at a discount, but they don't burn the rolling-window quota — `quota.py:231-232` is the canonical comment to mirror; we display cache reads separately so the user sees the cache-savings story without conflating it with quota.)

`build_token_report(token_ledger_path, session_id=None, window_sessions=30)` — when `session_id is None`, use the most-recent session's id (from records). Reads same JSONL as quota.py via `_iter_records()` (already tolerant of malformed lines).

**Modify:** `/workspace/.agentic/lib/tools/commands/intel.sh:112-181` (`_intel_report` function) — extend the flag parser:

```sh
--tokens) kind="tokens"; shift ;;
--session) session_arg=("$2"); shift 2 ;;
--window-sessions) window_arg=("$2"); shift 2 ;;
--json|--no-color) extra+=("$1"); shift ;;
```

Dispatch `kind="tokens"` to `python3 -m quota --report tokens`. Update `--quota`-specific code paths to pass `--report quota`. Update help text + the existing `_intel_help` printout.

**Modify:** `/workspace/.agentic/lib/quota.py:__main__` — add subcommand routing on `--report quota|tokens`. **No default**: existing R-013 callers (`intel.sh:174`) currently invoke `python3 -m quota` without `--report` — that single call site is updated to pass `--report quota` explicitly. Cleaner namespace; no backward-compat tax (Critic L1 fix; `intel.sh` is the only caller per grep).

**Output (CLI, human-readable):**
```
Token Ledger — current session (1.2h)
  Session: 6e664d59-…  Branch: main  Tokens: 287K (in 244K • out 43K)
  Cache reads: 312K (saved 312K input)  Top model: claude-opus-4-7
Rolling 30 sessions (last 7d)
  Total: 4.1M  Avg/session: 137K  Heaviest: 612K (F-006 implementation)
  By tier: T1 4.0M • T2 0.1M • T3 0
  By model: opus-4-7 3.7M • haiku-4-5 0.4M
  By feature: F-006 612K • F-008 401K • (untagged) 2.8M
```

`--json` flag: emits `TokenReport` as JSON for tooling/TUI consumption.

### Component 4 — Tier + feature attribution (~0.5d) — REVISED for v2 (resolves Critic H1)

**v1 had a wrong contract.** The original draft matched AGENTS.json by `pid == os.getppid()` and field name `feature`. The actual schema (verified at `.agentic/lib/tools/agents_helpers.py:10-29`):

- Feature/WIP entries use `feature_id` (NOT `feature`) and have NO `pid` field
- `pid` exists only on `type: "session"` entries (heartbeat tracking)
- Match key for the active feature is `worktree` (an absolute path), not `cwd` or `pid`
- AGENTS.json is "always in main repo, not worktrees" per CLAUDE.md, so a worktree session's `os.getcwd()` won't match unless we resolve to the worktree's registered `worktree` path first

v2 uses **git branch as primary signal** (more reliable — every feature in this framework branches as `feat/F-XXXX-…`) with AGENTS.json as a defensive secondary lookup.

**`current_tier()`:** returns `"1"` always for the main session. Tier 2/3 invocations write delegation.jsonl entries via the future R-201 dispatcher (R-201 will also emit token-ledger entries with `tier="2"`/`"3"` for those subagent costs). This is explicitly out of R-101 scope. The `"1" always` choice is load-bearing per the v5 tier matrix, not a shortcut.

**`current_feature(cwd: str | None, git_branch: str | None) -> str | None`:** resolution order:

1. **Primary — git branch parser.** Pattern: `^(?:feat|fix|hotfix)/(F-\d{3,4})(?:[-_].*)?$`. If branch matches, return the captured `F-XXXX`. Source comes either from the transcript line's `gitBranch` field (Claude Code already records it per turn — verified in transcript probe; see "Surface inventory") or from `git rev-parse --abbrev-ref HEAD` as fallback when the line lacks `gitBranch`.

2. **Secondary — AGENTS.json by worktree path.** When branch yields no match: read `.agentic/session/AGENTS.json`, find the entry where `worktree` equals the resolved git toplevel of `cwd` (`subprocess.check_output(["git", "-C", cwd, "rev-parse", "--show-toplevel"]).strip()`). Return that entry's `feature_id`. This catches the case where work is done on `main` directly with an active WIP entry registered.

3. **Fallback — None.** No branch match, no AGENTS.json entry. Records carry `feature: null`; report renders these under "(untagged)". This is explicit in the schema (`_require_optional_feature` allows None).

**No new sentinels created.** The plan reuses two existing contracts (git branch naming convention enforced by `ag implement` and the documented AGENTS.json schema); inventing a `.current-feature` file would have been the proliferation we want to avoid.

**Test fixtures (corrected):**
- Branch `feat/F-0006-token-ledger` + transcript with `gitBranch: "feat/F-0006-token-ledger"` → `feature_id="F-0006"`
- Branch `main` + AGENTS.json `[{"feature_id": "F-0006", "worktree": "/workspace", "branch": "feat/F-0006-..."}]` + cwd `/workspace` → `feature_id="F-0006"`
- Branch `chore/something` + empty AGENTS.json → `feature_id=None`
- Worktree at `/tmp/worktree-f6` + AGENTS.json (in main repo) entry with `worktree: "/tmp/worktree-f6"` → resolves correctly via git toplevel match

### Component 5 — TUI tokens panel (~0.5d)

**Modify:** `/workspace/.agentic/lib/tui/panels/header.py` (extend, do NOT replace R-014's quota ring):
- Add a third line under the quota ring: `Session 287K • 30-roll 4.1M • F-006 of 612K`
- Polls `build_token_report()` at the same 30s cadence as the quota ring (R-014)
- Color-coded: gray when no records; default theme otherwise (no extra alert thresholds — quota ring already does that job)

**No new panel file.** Folding into header.py keeps the five-panel layout intact (header / workers / events / health / drilldown).

### Component 6 — Tests (~1d)

**Create:**
- `/workspace/tests/hooks/test_token_emit.py`
  - Fixture transcript A: 5 assistant turns, 2 sidechain turns → ledger has 5 entries (sidechain skipped); each entry has correct `tokens_in`/`out`/`cache_read`, model string, ISO ts.
  - Fixture transcript B: identical first 3 turns + 2 new turns → second invocation produces 2 new entries (watermark idempotence).
  - Fixture transcript C: malformed JSONL line in middle → skipped; ledger still gets entries before+after; events.jsonl has `token_emit_skipped` record.
  - Fixture transcript D: missing transcript file → hook returns 0; events.jsonl skip event; no crash.
  - Fixture transcript E (feature attribution, v3): four cases mirroring §Component 4 fixtures — (i) `gitBranch: "feat/F-0006-..."` → `feature_id="F-0006"` via branch-parser primary; (ii) `gitBranch: "main"` + AGENTS.json with matching `worktree` → `feature_id="F-0006"` via secondary; (iii) `gitBranch: "chore/something"` + empty AGENTS.json → `feature_id=None` (untagged); (iv) worktree at `/tmp/wt-f6` + AGENTS.json (in main repo) entry with `worktree: "/tmp/wt-f6"` → resolves correctly via git-toplevel match.
  - Concurrency: 4 processes invoke hook simultaneously on same transcript → ledger has exactly N entries (no dupes, no drops); watermark file consistent.

- `/workspace/tests/test_token_report.py`
  - Synthetic ledger of 35 sessions × 4 records each → report shows current session + 30 most-recent; by_tier/by_model/by_feature sums match.
  - Empty ledger → graceful "No data yet — run a session and try again."
  - Single-session ledger → rolling_window has 1 row, current_session populated.
  - `--json` output validates against a minimal schema (typed dict).

**Existing test refactors:**
- `tests/test_events.py:304,324` already covers `append_token_ledger` happy path; no changes.
- `tests/test_quota_*.py` (existing for R-013) — unchanged; R-013's `--quota` projection is preserved.

## Tier × profile × mode behavior

| Profile | Mode | Hook fires? | Records get tier? | Records get feature? |
|---|---|---|---|---|
| discovery | Mode 1 | yes | "1" | from gitBranch or AGENTS.json or None |
| formal | Mode 1 | yes | "1" | from gitBranch or AGENTS.json or None |
| autonomous_formal | Mode 2 | yes | "1" | from gitBranch or AGENTS.json or None |
| autonomous_formal | Mode 3 | yes | "1" (main session); delegation costs tracked via delegation.jsonl when R-201/R-401 land | from gitBranch or AGENTS.json or None |

R-101 is profile-agnostic — the hook always fires, never blocks, and skip telemetry is auditable.

## Out of scope (deferred, with track-where notes)

| Item | Why deferred | Tracked at |
|---|---|---|
| 1. Tier 2/3 token attribution from Agent-tool subagents | depends on R-201 dispatcher emitting both delegation.jsonl + token-ledger.jsonl entries; not the right component to wire that | R-201 |
| 2. Cost-USD column | needs a per-model pricing table the framework doesn't currently maintain; orthogonal to "is the ledger filled?" | R-407 (`ag intel report --teams`) — already calls for cost-effectiveness telemetry |
| 3. Subagent / Sidechain transcripts | Stop fires in main session; subagent JSONL files have separate session ids and `isSidechain: true`; needs a separate enumeration strategy | new R-NNN follow-up after R-201 lands |
| 4. Cross-machine ledger aggregation | single-machine local-first scope per v5 plan principle 9 | not planned |
| 5. Token-ledger.jsonl rotation / size cap | LINE_BYTE_CAP is per-record (R-007); whole-file rotation is observability hygiene | future operational item |
| 6. Auto-degradation on burn pressure | R-110 explicitly | R-110 |

## Verification

Five gates, each a separate AC.

**G1 — Schema integrity:** `pytest tests/hooks/test_token_emit.py tests/test_token_report.py` green; ≥85% coverage on `token_emit.py` and the new `quota.py` projection (per `code_quality.knowledge.md`).

**G2 — End-to-end on this repo, exact-equality criterion (revised for v2 to resolve Critic H3):** install the hook. Pick the active transcript at `~/.claude/projects/<encoded-cwd>/<sessionId>.jsonl`. Synthesize a stdin payload matching the Stop hook envelope (`{"session_id": "...", "transcript_path": "...", "cwd": "/workspace", "hook_event_name": "Stop", "stop_hook_active": false}`); pipe it to `bash .agentic/lib/claude-hooks/Stop-token-emit.sh`. Then assert:

   1. `.agentic/journal/token-ledger.jsonl` exists.
   2. `count(records where session_id == <sessionId>) == count(transcript lines where type=="assistant" AND isSidechain==false AND message.usage exists AND has input_tokens AND has output_tokens)` — exact equality, not "≥1".
   3. `Σ(tokens_in for those records) == Σ(input_tokens for those transcript lines)` — exact equality (NOT including cache_creation; per the v2 accounting choice).
   4. `Σ(tokens_out) == Σ(output_tokens)` — exact equality.
   5. `Σ(cache_read_tokens) == Σ(cache_read_input_tokens)` — exact equality.
   6. `ag intel report --tokens` renders the populated session without falling into the "no data yet" branch.

   This catches the trivial-implementation bug Critic H3 flagged: a hook that emits one record per call, or that omits cache_creation from cache_write, or that mis-attributes any field, fails one of equalities 2-5.

**G3 — Idempotence + cross-session concurrency (revised for v2 to resolve Critic M3):** Two sub-tests:

   - **Same-session idempotence:** run the hook 10× in a tight loop on a static transcript → ledger size unchanged after first run.
   - **Different-session concurrency:** spawn 4 processes simultaneously, each invoking the hook with a different `session_id` and pointing at a different fixture transcript. After all complete, the ledger has exactly `Σ(per-session expected counts)` records; per-session subsets each match their own transcript exactly. (Same-session-id 4× parallel is a degenerate flock test; different-session-ids is what proves the cross-process append story.)

**G4 — Hook integrity baseline procedure (revised for v2 to resolve Critic M5):** numbered:

   1. Pre-install state: `git status` clean. Run `bash .agentic/lib/tools/dashboard.sh` — no integrity drift.
   2. Edit `.claude/hooks.json` and create the two shim files (working tree only, not committed).
   3. Run `git commit` (without `ag integrity update` first) → expected: BLOCKED by R-004 with "hook tampering detected" (proves the baseline is doing its job).
   4. Run `ag integrity update` → emits `integrity_baseline_updated` event to events.jsonl (verify with `ag watch --since 1m`).
   5. Stage hooks.json + shims + integrity.json together → `git commit` succeeds.
   6. Tampering regression: post-baseline, edit `Stop-token-emit.sh` → next commit blocks → `ag integrity update` clears.

**G5 — Quota report regression (load-bearing on M1 resolution):** golden-master test. Capture `ag intel report --quota --json` output for a fixed ledger fixture (committed to `tests/fixtures/quota-fixture.jsonl`) BEFORE landing R-101 emission. After v3's emission lands, the same fixture must produce **stable-equal output** — compared after `json.loads(...)` round-trip with `sort_keys=True`, not raw byte equality (Python dict ordering across versions can shift bytes without changing meaning; per Advocate round-2 note). Plus a live test: emit 50 turns into a fresh ledger via the new hook, run `--quota`, verify `tokens_in` matches `Σ(input_tokens)` from the fixture transcript (NOT including cache_creation). This is the explicit guard against the M1 accounting drift Critic flagged.

**Manual smoke test:** run a 30-min coding session, then `ag intel report --tokens`. Numbers should be in the same order of magnitude as `ccusage` or any external token-counting tool the user trusts (sanity check, not regression test).

## Effort + sequencing

| Component | Effort | Sequencing |
|---|---|---|
| 1. Stop-hook + SessionStart-recovery emission | 1.5d | first |
| 2. hooks.json (Stop + SessionStart) + integrity baseline | 0.5d | after C1 |
| 3. `ag intel report --tokens` | 1.5d | depends on C1 schema, can interleave with later C1 polish |
| 4. Tier/feature attribution | 0.5d | consumed by C1 + C3 (write while C1 stubs exist) |
| 5. TUI panel | 0.5d | after C3 |
| 6. Tests | 1d | written alongside each component (TDD per STACK.md) |

**Total wall-clock: 5d solo, serial.** Earlier "3-4d realistic with parallelism" estimate is removed — solo work is interleaved, not concurrent; calling that parallelism was misleading (Critic L3 fix).

**Branch:** `feat/R-101-token-ledger-visible`

**Naming-collision note (resolves Critic round-2 H4):** the v1/v2 plan claimed `.agentic/session/token-ledger.json` was a "stale stub from 2026-04-03 with no readers" and proposed deleting it as commit 0. That claim was false. The file is the F-041 session intel ledger, actively written by `.agentic/lib/claude-hooks/Stop.sh:80-104` every Stop and read by three intel test files. R-101's target is the *different* file `.agentic/journal/token-ledger.jsonl`. The two coexist and serve unrelated subsystems. **Commit 0 (deletion) is dropped from v3.** The naming collision is acknowledged in the surface inventory; future work may rename one of them (renaming the v3 target to `token-spend.jsonl` is the cleaner option since it's not yet shipped, but that change cascades through R-007 / R-013 / R-014 / TUI / schemas — a separate R-NNN, not a v3 detour).

**Commit boundaries** (5 commits, 3-7 files each):

1. C1+C4 — `token_emit.py` (Stop + recover entry points) + attribution helpers + unit tests for emission
2. C2 — `hooks.json` Stop+SessionStart entries + two shims + `.agentic/integrity.json` regen (per the numbered procedure in G4)
3. C3 — `quota.py` extension + `intel.sh` `--tokens` wiring + report tests + G5 golden-master fixture
4. C5 — TUI panel update (header.py)
5. Docs: instruction-file updates (memory-seed, CLAUDE.md template, agent-instructions in `.agentic/lib/agents/{claude,cursor,copilot,codex}`) — per "instruction files are part of the feature" rule

## Risks

**R1. Transcript path discovery depends on Anthropic's Stop hook stdin contract being honored.**
- Per Anthropic Stop hook envelope, `transcript_path` is provided on stdin. v2 spike confirmed Stop semantics generally; v3 trusts the path absolutely.
- Mitigation: **no fallback enumeration** (v2 H2 fix). If stdin is empty or `transcript_path` is missing/invalid, the hook emits `{type: "token_emit_skipped", payload: {reason: "no_transcript_path"}}` to events.jsonl and exits 0. Telemetry surfaces via `ag watch --filter type=token_emit_skipped`. This is consistent with §Component 1 line 76 and R8.
- If Anthropic ever stops sending `transcript_path` (unlikely; documented contract), the user sees skip events accumulating and can patch — fail-open with audit trail beats silent guessing.

**R2. Watermark file bloats over many sessions.**
- One entry per session; ~80 bytes each; 30 sessions = 2.4KB. Real-world long-running users might accumulate hundreds.
- Mitigation: prune entries older than 30d on each invocation (cheap; same code path that reads/writes the file).

**R3. Race between Stop-token-emit.sh and other Stop hooks.**
- Each Stop hook gets its own subprocess per Claude Code semantics; flock on watermark prevents within-process races. Across hooks running simultaneously, no shared mutable state besides the ledger (already flock-protected by `_append_jsonl`).
- Verified by G3 concurrency test.

**R4. Phase 0 R-001 pre-commit gate may block first commit if integrity baseline regen is forgotten.**
- Mitigation: explicit verification step (G4) and an entry in commit-1 description: "regen via `ag integrity update` then commit `.agentic/integrity.json`".
- Documented precedent: R-014/R-015 PR #246 went through the same baseline-regen.

**R5. Naming collision between `.agentic/session/token-ledger.json` (F-041 intel) and `.agentic/journal/token-ledger.jsonl` (this plan's target).**
- Both files exist; both are live; they serve unrelated subsystems. v1/v2's claim that the JSON file was stale was false (Critic round-2 H4 — Stop.sh:80-104 writes it; three test files read it).
- Mitigation: surface inventory documents the collision explicitly; commit messages and the intel.sh report help text disambiguate (`session intel ledger` vs `R-007 token spend ledger`). Future cleanup (renaming `.jsonl` to `token-spend.jsonl`) is a separate R-NNN scope because it cascades through R-007 / R-013 / R-014 / TUI / schemas. Out of R-101 scope.

**R6. The "Stop hook can fire mid-stream" edge case.**
- If user sends a follow-up before the hook completes, two Stop invocations can interleave on the same transcript.
- Mitigation: watermark flock + atomic rename means worst case is the second invocation processes 0 new turns. No data loss; no duplicates.

**R7. Ctrl+C / abrupt termination data leak (added in v2 per Critic M2).**
- Stop hook fires on natural turn end and on graceful "stop" prompts. It does NOT fire on Ctrl+C, terminal close, parent-shell crash, or OOM kill. Long sessions terminated abruptly leak the entire session's token data — exactly the case where the user most needs the report.
- Mitigation: SessionStart-token-recover.sh (Component 2) runs on every new session. It reads watermarks for all known sessionIds whose transcripts still exist, advances each to the current end-of-file, and emits any backlog. Recovery is bounded by the watermark prune rule (last 30 days), so cost stays small.
- Limit: a session whose transcript is deleted by Claude Code's own retention before SessionStart catches up is unrecoverable. Anthropic doesn't document a transcript retention policy; in practice files in `~/.claude/projects/` persist indefinitely on this machine.

**R8. Worktree project-folder encoding (added in v2 per Critic H2).**
- Claude Code derives the projects subdirectory from `cwd` by replacing slashes with dashes (`/workspace` → `~/.claude/projects/-workspace/`; `/workspace-f-006` → `~/.claude/projects/-workspace-f-006/`). The v1 fallback enumerator that scanned `~/.claude/projects/-workspace/*.jsonl` would have missed worktree sessions entirely.
- Mitigation: v2 trusts the stdin `transcript_path` absolutely; no enumeration of any kind. If `transcript_path` is missing the hook logs a skip event and exits 0.

**R9. Claude Code transcript schema drift (added in v2 per Critic recommendation).**
- Anthropic may extend or rename `usage` block fields without notice. v1 silently fell through `dict.get(..., 0)` — a rename of `input_tokens` to anything else would silently drop tokens to zero with no signal.
- Mitigation: defensive validation (Component 1, step 5). If a turn has `usage` but is missing the contract minimum (`input_tokens`, `output_tokens`), emit `token_emit_schema_change` with observed keys. User sees these in `ag watch --filter type=token_emit_schema_change` and can patch the parser before more data is lost.

## Open questions

**Resolved in v2:**

- ~~Q2 `tokens_in` cache_creation semantic~~ — RESOLVED. `tokens_in` carries pure `input_tokens`; `cache_write_tokens` carries `cache_creation_input_tokens` separately. Matches `quota.py:228` convention; preserves G5.
- ~~Q3 `current_feature()` fallback~~ — RESOLVED. Branch-parser primary, AGENTS.json secondary, None tertiary. Branch derivation is in fact reliable in this framework because `ag implement` enforces `feat/F-XXXX-…` branch names; not "more magic" — the convention is explicit.

**Remaining (implementation-time, defer-acceptable):**

1. **Watermark storage location.** `.agentic/session/.token-ledger-watermarks.json` is gitignored (consistent with other session/ contents). Alternative: encode watermarks as `token_emit_watermark` events in events.jsonl, read back. Trade-off: events.jsonl is canonical but reading the whole file every Stop is O(N) over all-time events. Decision deferred — JSON-file-with-flock is the obvious win for now.
2. **TUI panel placement.** Folding the tokens line into header.py. Alternative: a 6th panel between events and health. Folding is cheaper; the header gets crowded with quota ring + tokens line. Decision deferred to implementation; test in TUI and pick.
3. **Commit boundaries for instruction-file updates (commit 5).** Single commit vs. one per agent (claude/cursor/copilot/codex). Deferred — single commit is fine if the diff stays under ~200 lines.

---

## Revision history

- **v3 APPROVED (2026-04-28)** — round-3 dialectical review converged. Critic verdict: APPROVE-WITH-MINOR-NOTES; Advocate verdict: APPROVE. Trajectory: round 1 = 3 HIGH + 5 MEDIUM → round 2 = 1 new HIGH + 1 MEDIUM + 3 LOW → round 3 = 0 HIGH + 0 MEDIUM + 3 LOW (all implementation-time fixes). Architecture (Stop-hook emitter + watermark + read-side projection + TUI fold-in) survived two rounds of dialectical pressure intact — convergence reached. Round-3 LOW-1 (tier-matrix prose alignment for formal/autonomous_formal rows) applied during APPROVED finalization. Round-3 LOW-2 (`git rev-parse` fallback dead-code in §C4 line 220) and LOW-3 (verify `_require_optional_feature` exists in `events.py`) deferred to implementation-time cleanup as they require touching the actual code.

- **v3 DRAFT (2026-04-28)** — round-2 dialectical review found one new HIGH and two prose contradictions left over from v2.
  - **HIGH H4:** v2 claimed `.agentic/session/token-ledger.json` was a stale stub and proposed a commit-0 deletion. Verified false: that file is the F-041 session intel ledger, written by `.agentic/lib/claude-hooks/Stop.sh:80-104` every Stop and read by three intel test files. v3 drops commit 0 entirely, documents the naming collision in the surface inventory + R5, and notes that renaming `.agentic/journal/token-ledger.jsonl` to `token-spend.jsonl` (the cleaner long-term fix) is a separate R-NNN scope because it cascades through R-007 / R-013 / R-014 / TUI / schemas.
  - **MEDIUM (R1 prose contradiction):** R1's mitigation still mentioned mtime fallback enumeration, contradicting v2's §Component 1 line 76 ("No fallback enumeration") and R8. Rewritten — R1 now states the no-fallback policy explicitly and describes the fail-open audit-trail behavior.
  - **LOW (C6 fixture E leftover):** v1 pid-based fixture wording survived in §Component 6 line 249 despite v2's contract change. Replaced with four fixtures mirroring §Component 4 (gitBranch primary, AGENTS.json secondary, None tertiary, worktree-toplevel resolution).
  - **LOW (G5 byte-equality):** Advocate round-2 flagged that `json.dumps` ordering across Python versions could break byte-equality without changing meaning. Switched to "stable-equal after JSON round-trip with `sort_keys=True`."
  - **LOW (Tier matrix discovery row):** "n/a" → "Mode 1" + feature column updated to reflect v2's gitBranch-primary attribution.

- **v2 DRAFT (2026-04-28)** — round-1 dialectical review converged on architecture but flagged 3 HIGH + 5 MEDIUM correctness issues. v2 resolves:
  - **HIGH H1:** `current_feature()` contract was fictional (wrong field name `feature` vs actual `feature_id`; pid-based match against entries that have no pid). Replaced with git-branch primary + AGENTS.json-by-worktree secondary + None tertiary. Component 4 fully rewritten.
  - **HIGH H2:** Stop-hook stdin contract documented (Anthropic envelope with `transcript_path`, `session_id`, `cwd`); mtime fallback removed entirely (broke for worktree projects whose folders use `-workspace-f-XXX` encoding). Surface inventory now lists the verified per-turn schema. Risk R8 added.
  - **HIGH H3:** G2 strengthened from "≥1 record matching" to per-field exact equality on count + sum-of-tokens_in + sum-of-tokens_out + sum-of-cache_read.
  - **MEDIUM M1:** `tokens_in` accounting locked: pure `input_tokens` (no cache_creation), matching `quota.py:228`. Open Q2 closed in plan; G5 strengthened with golden-master fixture.
  - **MEDIUM M2:** Ctrl+C / abrupt-termination data leak — added SessionStart-token-recover entry point and hook registration; risk R7 documents the limit.
  - **MEDIUM M3:** G3 expanded to test different concurrent sessionIds (cross-process append story), not only same-session 4× parallel.
  - **MEDIUM M4:** Stale `.agentic/session/token-ledger.json` cleanup pulled into commit 0 (separate atomic hygiene commit).
  - **MEDIUM M5:** Integrity-baseline procedure numbered as G4 sequence (1: edit, 2: integrity update, 3: stage all, 4: commit succeeds).
  - **MEDIUM (R9 added):** schema-drift defensive logging on `usage` block contract minimum.
  - **LOW L1:** quota.py `--report` flag has no default; `intel.sh:174` updated to pass `--report quota` explicitly.
  - **LOW L2:** cache_read comment sharpened (cache reads ARE billed but at discount; don't burn rolling-window quota — mirrors `quota.py:231-232`).
  - **LOW L3:** dropped misleading "3-4d realistic with parallelism" claim; serial 5d for solo work.

- v1 DRAFT (2026-04-28) — initial draft addressing the spec gap discovered while planning. Synthesized from: `2026-04-26-framework-ground-up-redesign-plan.md` (Pillar 4 / C1), `2026-04-26-redesign-backlog.md` §R-101 (original 2d scope), the v5 plan's Phase 1 voluntary-use test, and `quota.py:22-27` honest-limit disclaimer.
