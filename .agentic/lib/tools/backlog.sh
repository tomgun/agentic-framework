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

# Sync STATUS.md focus to match backlog current item.
# Called after mutations that can change position 0.
_sync_focus() {
    local cur_json
    cur_json=$(python3 "$HELPERS" --project-root "$PROJECT_ROOT" json-current 2>/dev/null) || true
    if [ -n "$cur_json" ]; then
        local cur_id cur_desc focus_text
        cur_id=$(printf '%s' "$cur_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id', d.get('description','')))" 2>/dev/null) || cur_id=""
        cur_desc=$(printf '%s' "$cur_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('description',''))" 2>/dev/null) || cur_desc=""
        if [ -n "$cur_id" ]; then
            focus_text="ADR-001 roadmap execution: $cur_id ($cur_desc) is current backlog item"
            bash "$SCRIPT_DIR/status.sh" focus "$focus_text" >/dev/null 2>&1 || true
        fi
    else
        # Backlog empty — clear focus to reflect that
        bash "$SCRIPT_DIR/status.sh" focus "Backlog empty — pick next work item" >/dev/null 2>&1 || true
    fi
}

CMD="${1:-}"
python3 "$HELPERS" --project-root "$PROJECT_ROOT" "$@"
rc=$?

# After queue-mutating commands, keep STATUS.md focus in sync
case "$CMD" in
    done|remove|move|clear|add) _sync_focus ;;
esac

exit $rc
