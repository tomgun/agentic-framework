---
name: completing-work
description: >
  Feature completion workflow: verify contract assertions, mark done, update
  specs, cleanup WIP. Use when user says "done", "complete", "finished",
  "merged", "PR merged", "shipped", "landed", "wrapped up", "ag done",
  "mark as done", "it's in", or indicates work is finished. Also triggered
  automatically after merging a PR. Do NOT use for: committing code (use
  committing-changes), starting new features (use implementing-features).
compatibility: "Requires Cursor Agent mode with shell access and ag commands."
allowed-tools: [Read, Edit, Bash, Glob, Grep]
metadata:
  author: agentic-framework
  version: "${VERSION}"
---
# Completing Work

Run `ag done F-XXXX` — it verifies contracts, bumps VERSION, updates FEATURES.md, and flushes state.

## Before running `ag done`
1. Check phase completion: `ag phase list F-XXXX` — if phases exist, all must be complete/dropped (or use `--force-phases`)
2. Verify contract assertions: `ag contract check F-XXXX` (all assertions must pass)
3. Complete WIP: `bash .agentic/lib/tools/wip.sh complete`
4. Update feature status: `bash .agentic/lib/tools/feature.sh F-XXXX status shipped`
5. Update journal: `bash .agentic/lib/tools/journal.sh "F-XXXX Complete" "Capability" "Next" "None" --why "Reason"`
6. Update status: `bash .agentic/lib/tools/status.sh focus "F-XXXX shipped"`
7. Check doc freshness: `bash .agentic/lib/tools/docs.sh --check-freshness --trigger feature_done`
8. If design choices were made, update OVERVIEW.md (current state) and log with `journal.sh --decision` (include reasoning and alternatives in the outcome text)

## Rules
- All contract assertions in `spec/contracts/F-XXXX.yaml` must pass before shipping.
- If assertions not met, list what remains and ask user how to proceed.
- `ag done` auto-bumps VERSION (patch) and flushes state on main.
