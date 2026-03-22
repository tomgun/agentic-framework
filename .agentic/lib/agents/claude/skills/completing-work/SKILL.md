---
name: completing-work
description: >
  Feature completion workflow: verify contract assertions, mark done, update
  specs, cleanup WIP. Use when user says "done", "complete", "finished",
  "merged", "PR merged", "shipped", "landed", "wrapped up", "ag done",
  "mark as done", "it's in", or indicates work is finished. Also triggered
  automatically after merging a PR. Do NOT use for: committing code (use
  committing-changes), starting new features (use implementing-features).
compatibility: "Requires Claude Code with shell access and ag commands."
allowed-tools: [Read, Edit, Bash, Glob, Grep]
metadata:
  author: agentic-framework
  version: "${VERSION}"
---
# Completing Work

Run `ag done F-XXXX` — it verifies contracts, bumps VERSION, updates FEATURES.md, and flushes state.

## Before running `ag done`
1. Verify contract assertions: `ag contract check F-XXXX` (all assertions must pass)
2. Complete WIP: `bash .agentic/lib/tools/wip.sh complete`
3. Update feature status: `bash .agentic/lib/tools/feature.sh F-XXXX status shipped`
4. Update journal: `bash .agentic/lib/tools/journal.sh "F-XXXX Complete" "Capability" "Next" "None" --why "Reason"`
5. Update status: `bash .agentic/lib/tools/status.sh focus "F-XXXX shipped"`
6. Check doc freshness: `bash .agentic/lib/tools/docs.sh --check-freshness --trigger feature_done`

## Rules
- All contract assertions in `spec/contracts/F-XXXX.yaml` must pass before shipping.
- If assertions not met, list what remains and ask user how to proceed.
- `ag done` auto-bumps VERSION (patch) and flushes state on main.
