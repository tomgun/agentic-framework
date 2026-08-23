# CONTINUATION.md — how to resume development in this repo

**Status: PAUSED 2026-08-23, mid-v5-transform.** Focus moved to
[agentic-af-for-claude](https://github.com/tomgun/agentic-af-for-claude) ("Claude AF"), the
Claude Code–first v6 rebuild. This document records — from a full-repo review performed at
pause time (three parallel deep-exploration passes over design docs, project state, and
machinery) — exactly where this multitool repo stands and how to pick it back up. The last
substantive commit before pausing was 2026-05-16.

## Where the v5 redesign stands

The v5 "ground-up KISS redesign" (blueprint: `.agentic/journal/plans/2026-04-26-framework-ground-up-redesign-plan.md`,
backlog: `.agentic/journal/plans/2026-04-26-redesign-backlog.md`, ~84 R-items in 5 phases):

- **Phase 0 — SHIPPED** (all 16 items): R-001/R-002 Tier 0 git-layer gates (`precommit_gate.py`/`prepush_gate.py`),
  R-007 JSONL event spine, R-003 `ag merge` gate, R-004 hook-integrity baseline, R-005 read-only
  shipped contracts, R-006 CI mirror template, R-008 TUI, R-009 `ag watch`, R-010 `ag fix`,
  R-011 `ag onboard`, R-012 message catalog, R-013 quota reporting, R-014 TUI burn-down,
  R-015 `ag hooks register`, R-016 bypass-test battery.
- **Phase 1 — only R-101 landed** (token ledger + statusline; later rewritten to read Claude Code's
  `rate_limits` envelope). R-102…R-112 not started.
- **Phases 2–5 — not started.** Phase 3 ("Operational simplification" — the deletion list:
  retire `lib/tools/*.sh` chains, drop AGENTS.json/wip.sh/journal.sh mutations, scope down MCP,
  retire the legacy bash pre-commit) is the most important unexecuted work: the repo currently
  carries BOTH architectural generations.

## Known landmines (verified at pause time — fix these first if resuming)

1. **The shipped v5 gates do not fire.** `core.hooksPath` is set to `.agentic/hooks` (the legacy
   bash chain via `pre-commit-check.sh`), which means git ignores `.git/hooks/*` — where the
   R-015 shims for `precommit_gate.py`/`prepush_gate.py` live. Worse, `ag.sh:_ensure_hooks()`
   re-asserts `core.hooksPath` on every `ag` invocation, and `.agentic/integrity.json` guards the
   *inactive* hook pair. **First resume task: pick ONE pre-commit wall (the Python Tier 0 gates),
   point hooks at it, delete the other, and stop `_ensure_hooks` from re-installing the old one.**
2. **The TODO/backlog refinement was never applied.** `.agentic/journal/plans/2026-04-26-todo-backlog-refinement.md`
   classifies every TODO/backlog item against v5: ~18 closeable as obsolete, ~14 map to R-items,
   ~5 genuinely standalone. It was gated on "apply when v5 is committed" — v5 Phase 0 WAS
   committed, but the refinement never ran, so the backlog still serves work the architecture
   declared dead (this bit twice in May: T-0023 and T-0090 were both implemented/promoted after
   the doc marked them superseded). **Second resume task: apply that refinement.**
3. **STATUS.md is stale and contradictory** (claims F-031 as current focus; F-031 shipped long
   ago; the machine-updated current item was T-0090). Regenerate or ignore it.
4. **HUMAN_NEEDED.md has drifted**: 9 entries were open at pause; at least #233, #235, #248 are
   already merged on main. Reconcile against `gh pr list` before trusting it.
5. **Two state-machine definitions** (`.agentic/lib/auto/state_machine.py` — authoritative — vs
   `state_machine_af.yaml` with different state names + a reconciler). The v2 engine that would
   consume the YAML was removed (F-0244); the YAML is a shadow spec.
6. **VERSION drift** between root `VERSION` and `.agentic/lib/VERSION` recurred on every
   `ag done` cycle (see the `VERSION,VERSION` double entries in `chore(state)` commits). In sync
   at pause (0.85.3); watch it.
7. Deferred small items: T-0098 (manual TUI smokes), T-0100 (ROOT_DIR parent-boot poisoning,
   unconfirmed repro), T-0101 (memory-seed version marker).

## Open PRs at pause

PR reviews were queued in `HUMAN_NEEDED.md` (HN-0070..HN-0091); several are stale or already
merged — reconcile with `gh pr list --state open` rather than trusting the file. PR #251 is the
pause-notice PR itself.

## How this repo relates to Claude AF (and what "continuing" means)

- Claude AF **supersedes this repo conceptually**: its `docs/CAPABILITIES.md` maps every
  capability here to keep / native / drop-or-defer, and its `docs/ANTIPATTERNS.md` +
  `product/VISION.md` distill this repo's lessons and values. Read those before resuming here —
  they are the most compact accurate description of what this codebase learned.
- The one thing Claude AF deliberately dropped is **multitool support** (Cursor/Copilot/Codex
  parity — principle D7). That is exactly this repo's remaining raison d'être: if multitool
  demand returns, resume HERE rather than bolting parity onto Claude AF.
- Recommended resume order: fix landmine 1 → apply landmine 2's refinement → execute v5 Phase 3
  (deletion) → re-cut remaining R-items against what Claude AF has since proven (many Phase 1/2
  R-items are obsoleted by its simpler mechanisms — check its `product/decisions/LOG.md`).
- Design learnings now accrue in Claude AF; anything multitool-relevant should be *consciously
  backported* here, not assumed to sync.

## Where the knowledge lives (durable artifacts, all in-repo)

- Session-by-session history: `.agentic/journal/JOURNAL.md` (grep `**Decision**:` — 64 markers).
- Plans incl. the whole v5 design debate: `.agentic/journal/plans/` (see also the greenfield
  alternative `2026-04-26-agentic-af-2-greenfield-path.md`, which Claude AF ultimately realized).
- Lessons: `.agentic/spec/LESSONS.md`, `.agentic/journal/lessons/`, `docs/KEY_INSIGHTS.md`.
- User-originated design insights: `.agentic/CONTRIBUTIONS.md` (275 entries; the v5 pivot
  section is the key one).
- Specs: `.agentic/spec/contracts/` (46 YAML contracts, the real spec) + `FEATURES.md` (mirror).

*Note on external logs: Claude Code session transcripts are machine-local and rotate; nothing
durable lives there by design (durable-artifacts principle). The pause-time repo review that
produced this document is itself distilled here and in Claude AF's founding plan.*
