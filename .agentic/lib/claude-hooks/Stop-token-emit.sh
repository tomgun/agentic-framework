#!/usr/bin/env bash
# Stop-token-emit.sh: R-101 token-ledger emitter (Stop hook).
#
# Reads the Anthropic Stop hook stdin envelope (transcript_path + sessionId),
# parses unread turns of the active Claude Code transcript, and appends one
# token-ledger record per assistant turn via events.append_token_ledger().
#
# This is a TELEMETRY hook: exit 0 always. Errors are logged via
# token_emit_skipped events to events.jsonl and surfaced via `ag watch
# --filter type=token_emit_skipped`. Pre-commit gates handle real enforcement;
# token telemetry never gates work.
#
# Triggered by: Claude Code Stop hook (separate from existing Stop.sh)
# Timeout: 5 seconds

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
[[ ! -d "$PROJECT_ROOT/.agentic" ]] && exit 0

PYTHONPATH="$PROJECT_ROOT/.agentic/lib${PYTHONPATH:+:$PYTHONPATH}" \
    python3 -m hooks.token_emit stop || true

exit 0
