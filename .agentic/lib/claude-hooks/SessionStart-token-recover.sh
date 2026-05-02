#!/usr/bin/env bash
# SessionStart-token-recover.sh: R-101 token-ledger emitter (SessionStart recovery).
#
# Stop fires on natural turn end and graceful stops, but NOT on Ctrl+C,
# terminal close, parent-shell crash, or OOM kill — long sessions terminated
# abruptly leak the entire session's token data.
#
# This shim runs at SessionStart, walks watermarks for known sessionIds whose
# transcripts still exist, and appends any backlog via events.append_token_ledger().
# Bounded by the 30d watermark prune (R7 mitigation in the v3 plan).
#
# This is a TELEMETRY hook: exit 0 always.
#
# Triggered by: Claude Code SessionStart hook (separate from existing SessionStart.sh)
# Timeout: 5 seconds

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
[[ ! -d "$PROJECT_ROOT/.agentic" ]] && exit 0

PYTHONPATH="$PROJECT_ROOT/.agentic/lib${PYTHONPATH:+:$PYTHONPATH}" \
    python3 -m hooks.token_emit recover || true

exit 0
