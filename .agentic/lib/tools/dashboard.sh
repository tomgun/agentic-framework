#!/usr/bin/env bash
# dashboard.sh — Consolidated session scanner for session-start workflow
#
# Outputs structured key-value sections delimited by ===SECTION=== markers.
# The agent parses this output to render a polished dashboard in one tool call.
#
# Usage: bash .agentic/lib/tools/dashboard.sh
#
set -uo pipefail  # no -e: we want to keep going if individual checks fail

# ---------------------------------------------------------------------------
# Bootstrap paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
cd "$PROJECT_ROOT"

# Source framework paths (provides all *_FILE variables)
source "$PROJECT_ROOT/.agentic/lib/paths.sh" 2>/dev/null || true

TOOLS_DIR="${TOOLS_DIR:-$PROJECT_ROOT/.agentic/lib/tools}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
section() { echo "===$1==="; }

# Safe python3 caller
_py() { command -v python3 >/dev/null 2>&1 && python3 "$@"; }

# ---------------------------------------------------------------------------
# VERSION
# ---------------------------------------------------------------------------
section "VERSION"
if [[ -f "${VERSION_FILE:-}" ]]; then
    cat "$VERSION_FILE" | tr -d '[:space:]'
    echo
elif [[ -f "$PROJECT_ROOT/.agentic/lib/VERSION" ]]; then
    cat "$PROJECT_ROOT/.agentic/lib/VERSION" | tr -d '[:space:]'
    echo
else
    echo "unknown"
fi

# ---------------------------------------------------------------------------
# WIP (interrupted work)
# ---------------------------------------------------------------------------
section "WIP"
wip_output=$(bash "$TOOLS_DIR/wip.sh" check 2>&1) && wip_status="clean" || wip_status="interrupted"
echo "$wip_status"
if [[ "$wip_status" == "interrupted" ]]; then
    section "WIP_DETAIL"
    # Extract feature ID from agents_helpers or WIP.md
    feature_id=$(_py "$TOOLS_DIR/agents_helpers.py" --project-root "${MAIN_PROJECT_ROOT:-$PROJECT_ROOT}" get-current-feature "$PROJECT_ROOT" 2>/dev/null || echo "")
    if [[ -n "$feature_id" ]]; then
        echo "feature=$feature_id"
    fi
    # Show changed files count
    changed=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
    echo "changed_files=$changed"
fi

# ---------------------------------------------------------------------------
# STATUS (current focus)
# ---------------------------------------------------------------------------
section "STATUS"
if [[ -f "${STATUS_FILE:-}" ]]; then
    # Extract the "Current focus" bullet(s)
    grep -A5 "^## Current focus" "$STATUS_FILE" 2>/dev/null | grep "^-" | head -2 | sed 's/^- //' || echo "No focus set"
else
    echo "No STATUS.md found"
fi

# ---------------------------------------------------------------------------
# JOURNAL (last entry summary)
# ---------------------------------------------------------------------------
section "JOURNAL_LAST"
if [[ -f "${JOURNAL_FILE:-}" ]]; then
    # Get last session header and its "What changed" line
    last_header=$(grep "^### Session:" "$JOURNAL_FILE" 2>/dev/null | tail -1 | sed 's/^### Session: //')
    last_why=""
    last_changed=""
    # Find the last "What changed" block
    last_changed=$(awk '/^### Session:/{block=""} /\*\*What changed\*\*:/{found=1; next} found && /^-/{print; found=0}' "$JOURNAL_FILE" 2>/dev/null | tail -1 | sed 's/^- //')
    if [[ -n "$last_header" ]]; then
        echo "date=$last_header"
    fi
    if [[ -n "$last_changed" ]]; then
        echo "summary=$last_changed"
    fi
else
    echo "No journal found"
fi

# ---------------------------------------------------------------------------
# BACKLOG (current, next, total)
# ---------------------------------------------------------------------------
section "BACKLOG"
if command -v python3 >/dev/null 2>&1 && [[ -f "$TOOLS_DIR/backlog_helpers.py" ]]; then
    # Use a temp file to avoid shell quoting issues with JSON
    _tmpf=$(mktemp)
    _py "$TOOLS_DIR/backlog_helpers.py" --project-root "$PROJECT_ROOT" json-all >"$_tmpf" 2>/dev/null || echo "[]" >"$_tmpf"
    _py -c "
import json, sys
with open('$_tmpf') as f:
    items = json.load(f)
total = len(items)
print(f'total={total}')
if total > 0:
    c = items[0]
    fid = c.get('id', c.get('feature_id', c.get('task', '?')))
    desc = c.get('description', c.get('task', ''))
    ref = c.get('refs', [''])[0] if c.get('refs') else ''
    became = c.get('became_current_at', '')
    print(f'current_id={fid}')
    print(f'current_desc={desc}')
    if ref: print(f'current_ref={ref}')
    if became: print(f'current_since={became}')
if total > 1:
    n = items[1]
    nid = n.get('id', n.get('feature_id', n.get('task', '?')))
    ndesc = n.get('description', n.get('task', ''))
    print(f'next_id={nid}')
    print(f'next_desc={ndesc}')
remaining = max(0, total - 2) if total > 2 else 0
print(f'remaining={remaining}')
" 2>/dev/null || echo "total=0"
    rm -f "$_tmpf"
else
    echo "total=0"
fi

# ---------------------------------------------------------------------------
# BLOCKERS (active HUMAN_NEEDED items)
# ---------------------------------------------------------------------------
section "BLOCKERS"
if [[ -f "${HUMAN_NEEDED_FILE:-}" ]]; then
    if grep -q "^_No active items_" "$HUMAN_NEEDED_FILE" 2>/dev/null; then
        echo "0"
    else
        # Count ### HN- entries in "Active items" section (before "## Resolved")
        active_count=$(awk '/^## Active items/,/^## Resolved/' "$HUMAN_NEEDED_FILE" 2>/dev/null | grep -c "^### HN-" || echo "0")
        echo "$active_count"
    fi
else
    echo "0"
fi

# ---------------------------------------------------------------------------
# TODO count
# ---------------------------------------------------------------------------
section "TODO_COUNT"
if [[ -f "${TODO_FILE:-}" ]]; then
    # Count T-XXXX items that are not done/dropped
    todo_count=$(grep -c "^### T-" "$TODO_FILE" 2>/dev/null || echo "0")
    echo "$todo_count"
else
    echo "0"
fi

# ---------------------------------------------------------------------------
# AGENTS (active multi-agent entries)
# ---------------------------------------------------------------------------
section "AGENTS"
if command -v python3 >/dev/null 2>&1 && [[ -f "$TOOLS_DIR/agents_helpers.py" ]]; then
    agents_out=$(_py "$TOOLS_DIR/agents_helpers.py" --project-root "${MAIN_PROJECT_ROOT:-$PROJECT_ROOT}" list 2>&1) || agents_out=""
    if [[ -z "$agents_out" ]] || echo "$agents_out" | grep -q "No active agents"; then
        echo "none"
    else
        echo "$agents_out"
    fi
else
    echo "none"
fi

# ---------------------------------------------------------------------------
# HEALTH (quick doctor check)
# ---------------------------------------------------------------------------
section "HEALTH"
if [[ -f "$TOOLS_DIR/doctor.sh" ]]; then
    health_out=$(bash "$TOOLS_DIR/doctor.sh" --summary 2>/dev/null) || true
    if [[ -z "$health_out" ]]; then
        echo "ok"
    else
        echo "$health_out"
    fi
else
    echo "ok"
fi

# ---------------------------------------------------------------------------
# UPGRADE pending
# ---------------------------------------------------------------------------
section "UPGRADE"
if [[ -f "$PROJECT_ROOT/.agentic/.upgrade_pending" ]]; then
    echo "pending"
else
    echo "none"
fi

# ---------------------------------------------------------------------------
# TIP (random from curated list)
# ---------------------------------------------------------------------------
section "TIP"
tips=(
    "Run \`ag sync\` to detect drift across memory, specs, and docs."
    "Use \`ag plan F-XXXX\` to start a plan-review loop before coding."
    "Run \`ag trace\` to see which code implements which features."
    "Use \`ag test llm\` to verify agents follow framework rules."
    "Run \`ag sync --check\` for a dry run — see what's drifted."
    "Use \`ag trace --gaps\` to find shipped features with no code annotations."
    "Run \`ag verify --full\` for a comprehensive framework health check."
    "Use \`ag specs\` to generate specs for existing code, domain by domain."
    "Run \`ag tools\` to discover all available framework tools and scripts."
    "Use \`ag backlog\` to view and manage the ordered work queue."
)
tip_index=$((RANDOM % ${#tips[@]}))
echo "${tips[$tip_index]}"

# ---------------------------------------------------------------------------
# STALE check (is current backlog item > 7 days old?)
# ---------------------------------------------------------------------------
section "STALE"
if command -v python3 >/dev/null 2>&1 && [[ -f "$TOOLS_DIR/backlog_helpers.py" ]]; then
    _py "$TOOLS_DIR/backlog_helpers.py" --project-root "$PROJECT_ROOT" check-staleness 7 >/dev/null 2>&1 && echo "yes" || echo "no"
else
    echo "no"
fi
