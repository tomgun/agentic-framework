#!/usr/bin/env bash
# backlog.sh — Manage the ordered work queue (BACKLOG.json)
#
# Usage:
#   bash .agentic/lib/tools/backlog.sh add F-XXXX [--desc "text"] [--position N] [--ref path] [--note "text"]
#   bash .agentic/lib/tools/backlog.sh add --task "Research X" [--position N]
#   bash .agentic/lib/tools/backlog.sh current
#   bash .agentic/lib/tools/backlog.sh next
#   bash .agentic/lib/tools/backlog.sh done
#   bash .agentic/lib/tools/backlog.sh list
#   bash .agentic/lib/tools/backlog.sh remove F-XXXX
#   bash .agentic/lib/tools/backlog.sh move F-XXXX N
#   bash .agentic/lib/tools/backlog.sh clear
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../paths.sh"

HELPERS="$SCRIPT_DIR/backlog_helpers.py"

if [ ! -f "$HELPERS" ]; then
    echo "Error: backlog_helpers.py not found at $HELPERS" >&2
    exit 1
fi

python3 "$HELPERS" --project-root "$PROJECT_ROOT" "$@"
