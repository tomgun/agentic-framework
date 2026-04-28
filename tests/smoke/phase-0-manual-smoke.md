# Phase 0 manual smoke tests — R-014 + R-015

Two manual smoke tests deferred from the PR #246 merge. Both verify
behaviour that can't be covered by the deterministic test suite — Textual
rendering for R-014, fresh-project install ergonomics for R-015.

**Trigger to run:** after the V5 ground-up refactoring is complete (Phase
0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 all shipped). The procedures
below are captured at the time R-014/R-015 shipped (2026-04-28); if the
TUI surface or `ag hooks register` flags drift between then and now,
adapt the commands accordingly. The **expected behaviour** column is
the load-bearing part — the commands are how you observe it on the
surface as it stood in v0.84.3.

---

## R-014 — TUI quota burn-down ring + 95% modal alert

**What this verifies:** the colored Unicode quarter-circle ring renders,
transitions through colour thresholds as token usage climbs, the by-tier
tooltip shows on header hover, and the rising-edge 95% modal fires
once per episode with both buttons routed correctly.

**Surfaces under test:** `.agentic/lib/tui/panels/header.py`,
`.agentic/lib/tui/panels/quota_alert.py`, `.agentic/lib/tui/app.py`,
`.agentic/lib/tui/state.py`.

### Preconditions

```sh
pip install textual
git checkout main   # or wherever R-014 has shipped
```

### Step 1 — seed a token-ledger that walks the colour thresholds

The deterministic test suite covers the math; this smoke is about
*seeing* the rendered colour transitions. Append the four records below
to `.agentic/journal/token-ledger.jsonl` with a 100k-token ceiling so
the cumulative percentages land in each band: 30% (green) → 75%
(yellow) → 90% (orange) → 97% (red).

```sh
mkdir -p .agentic/journal
cat > .agentic/journal/token-ledger.jsonl <<'EOF'
{"ts":"2026-04-28T12:00:00Z","session_id":"smoke","model":"haiku","tier":"tier1","tokens_in":30000,"tokens_out":0}
{"ts":"2026-04-28T12:01:00Z","session_id":"smoke","model":"sonnet","tier":"tier2","tokens_in":45000,"tokens_out":0}
{"ts":"2026-04-28T12:02:00Z","session_id":"smoke","model":"opus","tier":"tier3","tokens_in":15000,"tokens_out":0}
{"ts":"2026-04-28T12:03:00Z","session_id":"smoke","model":"opus","tier":"tier3","tokens_in":7000,"tokens_out":0}
EOF
```

### Step 2 — launch the TUI

```sh
ag tui --quota-ceiling 100000 --from-start
```

If `--quota-ceiling` isn't a flag in the surface you're testing
against, set the ceiling via `STACK.md` (`quota_pro_max_window_tokens:
100000`) or whatever the current convention is, then run `ag tui
--from-start`.

### Step 3 — observe

| Observation | Expected |
|---|---|
| Header text format | `tokens=97,000 ● 97%` (or similar) — Unicode ring char + percentage. NOT the pre-R-014 `(N%)` parens. |
| Ring colour at 97% | Red |
| Ring colour at 90% | Dark orange |
| Ring colour at 75% | Yellow |
| Ring colour at 30% | Green |
| Tooltip on header hover | By-tier breakdown: `tier1 30,000 (30.9%)`, `tier2 45,000 (46.4%)`, `tier3 22,000 (22.7%)` |
| Modal at 97% | Within ~0.5s of the file write that pushes usage to 97%, modal pops with title **"⚠ Quota at 95%"** + body explaining current pct + two buttons |
| Modal *Acknowledge* button | Dismisses; does NOT re-show on subsequent 30s ticks (acknowledged-this-episode flag) |
| Modal *Abort* button | Dismisses + emits a notify toast. Toast text references R-209 for full signal-to-PID wiring (still placeholder until R-209 ships). |
| Modal re-fire | If you remove a record so usage drops below 95%, then add it back to push above 95% again, modal fires again (new episode). |
| `q` key | Quits cleanly; no orphan PIDs |

### Iterate

While the TUI is running, append/remove ledger lines in another shell —
the ring and tooltip update on the next 30s tick (or the next 0.5s
tick for the line text). The modal trigger lives on the 0.5s tick, so
crossing 95% is caught promptly.

### Cleanup

```sh
rm .agentic/journal/token-ledger.jsonl   # or keep, agnostic
```

---

## R-015 — `ag hooks register` / `unregister` in a fresh project

**What this verifies:** the register flow installs canonical Tier 0
shims, refreshes the integrity baseline, backs up divergent existing
hooks, is idempotent on re-run, unregisters cleanly with or without a
backup, and `ag init` stays silent on the no-op fast path.

**Surfaces under test:** `.agentic/lib/tools/commands/hooks.sh`,
`.agentic/lib/tools/commands/operations.sh::cmd_init`.

### Preconditions

```sh
git checkout main   # where R-015 has shipped
```

### Step 1 — sandbox

Use a throwaway tmp repo so you don't tangle the framework's own
hooks. The framework lib is mirrored into the sandbox so `ag.sh`
resolves correctly:

```sh
SANDBOX=$(mktemp -d)
cd "$SANDBOX"
git init -b main
git config user.email "smoke@example.com"
git config user.name "smoke"

# Adjust the path below to wherever the framework lives on this machine.
cp -r ~/code/agentic-framework/.agentic .
echo "init" > README.md
git add README.md
git commit -m "init"
```

### Smoke 1 — register on a fresh repo

```sh
bash .agentic/lib/tools/ag.sh hooks register
ls -la .git/hooks/pre-commit .git/hooks/pre-push
python3 -c "import json; d=json.load(open('.agentic/integrity.json')); print(sorted(k for k in d['files'] if 'hooks' in k))"
```

| Observation | Expected |
|---|---|
| `pre-commit` and `pre-push` exist | Yes, both executable |
| Shim text | First lines reference R-001 / R-002 + `exec python3` of the gates |
| `integrity.json` `files` | Contains both `.git/hooks/pre-commit` and `.git/hooks/pre-push` |
| stdout | Includes `✓ Registered Tier 0 hook shims` + `✓ Integrity baseline updated (R-004)` |

### Smoke 2 — idempotent re-run

```sh
bash .agentic/lib/tools/ag.sh hooks register
ls -1d .git/hooks/.backup-* 2>/dev/null | wc -l
```

| Observation | Expected |
|---|---|
| stdout | `✓ Hooks already registered (no changes needed).` + dim hint about canonical R-001/R-002 launchers |
| Backup directories | **0** — no second backup created on the no-op path |

### Smoke 3 — register over a divergent existing hook

```sh
echo -e '#!/bin/sh\necho "user-original"' > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
bash .agentic/lib/tools/ag.sh hooks register
ls -1d .git/hooks/.backup-* | head -1
cat .git/hooks/.backup-*/pre-commit
```

| Observation | Expected |
|---|---|
| Backup directory | One `.backup-<ts>-<pid>-<seq>/` directory created |
| `.backup-.../pre-commit` | Contains the original `user-original` script (preserved) |
| `.git/hooks/pre-commit` | Replaced with the canonical R-001 shim |
| stdout | Mentions "prior hooks moved to .git/hooks/.backup-…" |

### Smoke 4 — unregister restores

```sh
bash .agentic/lib/tools/ag.sh hooks unregister
cat .git/hooks/pre-commit
ls .git/hooks/pre-push 2>&1
```

| Observation | Expected |
|---|---|
| `pre-commit` | Contains `user-original` (restored from backup) |
| `pre-push` | Missing (no original existed; cleanly removed since there was nothing to restore) |
| stdout | `✓ Restored from .git/hooks/.backup-…` with restored/removed counts |

### Smoke 5 — `ag init` silent on the no-op path

This one verifies the UX fix from PR #246 review issue #7 — `ag init`
should NOT print the "Tier 0 hooks (R-015):" header when shims are
already canonical.

```sh
bash .agentic/lib/tools/ag.sh hooks register   # arm
bash .agentic/lib/tools/ag.sh init 2>&1 | grep "Tier 0 hooks"
```

| Observation | Expected |
|---|---|
| `grep` output | **Empty** — the header is suppressed because shims already match |
| `bash ... init` exit | 0 (init still ran to completion; we just skipped the hooks section) |

### Cleanup

```sh
cd /tmp && rm -rf "$SANDBOX"
```

---

## What to do with results

If everything passes:
- Tick the two manual-smoke checkboxes in PR #246 (now historical — the
  PR will already be merged, so this is for the record).
- Note the smoke run in `.agentic/journal/JOURNAL.md`:

```sh
ag journal "Phase 0 manual smokes ran clean (R-014 + R-015)" \
  "All checks per tests/smoke/phase-0-manual-smoke.md passed against vX.Y.Z" \
  "—" "—" --why "Deferred at merge time; ran post-V5 per the in-doc trigger"
```

If anything fails:
- File against the framework as a Phase-0-late-bug. Both R-014 and
  R-015 are shipped, so use the migration path appropriate at the time
  (likely a contract migration or a regression fix on the relevant
  feature). Do **not** re-open R-014/R-015 — they're closed by their
  ACs which the deterministic tests still cover.
