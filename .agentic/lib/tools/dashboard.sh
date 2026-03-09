#!/usr/bin/env bash
# dashboard.sh — Consolidated session scanner for session-start workflow
#
# Outputs a ready-to-display dashboard. The agent outputs this verbatim as its
# first text response — no parsing, no reformatting needed.
#
# With --raw flag, outputs structured ===SECTION=== markers instead (for scripts).
#
# Usage: bash .agentic/lib/tools/dashboard.sh [--raw]
#
set -uo pipefail  # no -e: we want to keep going if individual checks fail

RAW_MODE=false
[[ "${1:-}" == "--raw" ]] && RAW_MODE=true

# ---------------------------------------------------------------------------
# Bootstrap paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
cd "$PROJECT_ROOT"

# Source framework paths (provides all *_FILE variables)
source "$PROJECT_ROOT/.agentic/lib/paths.sh" 2>/dev/null || true

TOOLS_DIR="${TOOLS_DIR:-$PROJECT_ROOT/.agentic/lib/tools}"

# Safe python3 caller
_py() { command -v python3 >/dev/null 2>&1 && python3 "$@"; }

# ---------------------------------------------------------------------------
# Collect all data into variables
# ---------------------------------------------------------------------------

# VERSION
if [[ -f "${VERSION_FILE:-}" ]]; then
    D_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
elif [[ -f "$PROJECT_ROOT/.agentic/lib/VERSION" ]]; then
    D_VERSION=$(cat "$PROJECT_ROOT/.agentic/lib/VERSION" | tr -d '[:space:]')
else
    D_VERSION="unknown"
fi

# WIP (interrupted work)
D_WIP="clean"
D_WIP_FEATURE=""
D_WIP_CHANGED=0
if ! bash "$TOOLS_DIR/wip.sh" check >/dev/null 2>&1; then
    D_WIP="interrupted"
    D_WIP_FEATURE=$(_py "$TOOLS_DIR/agents_helpers.py" --project-root "${MAIN_PROJECT_ROOT:-$PROJECT_ROOT}" get-current-feature "$PROJECT_ROOT" 2>/dev/null || echo "")
    D_WIP_CHANGED=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
fi

# STATUS (current focus)
if [[ -f "${STATUS_FILE:-}" ]]; then
    D_STATUS=$(grep -A5 "^## Current focus" "$STATUS_FILE" 2>/dev/null | grep "^-" | head -1 | sed 's/^- //' || echo "No focus set")
else
    D_STATUS="No focus set"
fi

# JOURNAL (last entry summary)
D_JOURNAL_DATE=""
D_JOURNAL_SUMMARY=""
if [[ -f "${JOURNAL_FILE:-}" ]]; then
    D_JOURNAL_DATE=$(grep "^### Session:" "$JOURNAL_FILE" 2>/dev/null | tail -1 | sed 's/^### Session: //')
    D_JOURNAL_SUMMARY=$(awk '/^### Session:/{block=""} /\*\*What changed\*\*:/{found=1; next} found && /^-/{print; found=0}' "$JOURNAL_FILE" 2>/dev/null | tail -1 | sed 's/^- //')
fi

# BACKLOG
D_BACKLOG_TOTAL=0
D_BACKLOG_CUR_ID=""
D_BACKLOG_CUR_DESC=""
D_BACKLOG_CUR_REF=""
D_BACKLOG_CUR_SINCE=""
D_BACKLOG_NEXT_ID=""
D_BACKLOG_NEXT_DESC=""
D_BACKLOG_REMAINING=0
if command -v python3 >/dev/null 2>&1 && [[ -f "$TOOLS_DIR/backlog_helpers.py" ]]; then
    _tmpf=$(mktemp)
    _py "$TOOLS_DIR/backlog_helpers.py" --project-root "$PROJECT_ROOT" json-all >"$_tmpf" 2>/dev/null || echo "[]" >"$_tmpf"
    eval "$(_py -c "
import json, sys
with open('$_tmpf') as f:
    items = json.load(f)
total = len(items)
print(f'D_BACKLOG_TOTAL={total}')
if total > 0:
    c = items[0]
    fid = c.get('id', c.get('feature_id', c.get('task', '?')))
    desc = c.get('description', c.get('task', ''))
    ref = (c.get('refs', ['']) or [''])[0]
    since = c.get('became_current_at', '')
    print(f'D_BACKLOG_CUR_ID=\"{fid}\"')
    print(f'D_BACKLOG_CUR_DESC=\"{desc}\"')
    if ref: print(f'D_BACKLOG_CUR_REF=\"{ref}\"')
    if since: print(f'D_BACKLOG_CUR_SINCE=\"{since}\"')
if total > 1:
    n = items[1]
    nid = n.get('id', n.get('feature_id', n.get('task', '?')))
    ndesc = n.get('description', n.get('task', ''))
    print(f'D_BACKLOG_NEXT_ID=\"{nid}\"')
    print(f'D_BACKLOG_NEXT_DESC=\"{ndesc}\"')
remaining = max(0, total - 2) if total > 2 else 0
print(f'D_BACKLOG_REMAINING={remaining}')
" 2>/dev/null)" 2>/dev/null || true
    rm -f "$_tmpf"
fi

# BLOCKERS
D_BLOCKERS=0
if [[ -f "${HUMAN_NEEDED_FILE:-}" ]]; then
    if grep -q "^_No active items_" "$HUMAN_NEEDED_FILE" 2>/dev/null; then
        D_BLOCKERS=0
    else
        D_BLOCKERS=$(awk '/^## Active items/,/^## Resolved/' "$HUMAN_NEEDED_FILE" 2>/dev/null | grep -c "^### HN-" || echo "0")
    fi
fi

# TODO count
D_TODO_COUNT=0
if [[ -f "${TODO_FILE:-}" ]]; then
    D_TODO_COUNT=$(grep -c "^### T-" "$TODO_FILE" 2>/dev/null || echo "0")
fi

# AGENTS
D_AGENTS="none"
if command -v python3 >/dev/null 2>&1 && [[ -f "$TOOLS_DIR/agents_helpers.py" ]]; then
    agents_out=$(_py "$TOOLS_DIR/agents_helpers.py" --project-root "${MAIN_PROJECT_ROOT:-$PROJECT_ROOT}" list 2>&1) || agents_out=""
    if [[ -n "$agents_out" ]] && ! echo "$agents_out" | grep -q "No active agents"; then
        D_AGENTS="$agents_out"
    fi
fi

# HEALTH
D_HEALTH="ok"
if [[ -f "$TOOLS_DIR/doctor.sh" ]]; then
    health_out=$(bash "$TOOLS_DIR/doctor.sh" --summary 2>/dev/null) || true
    if [[ -n "$health_out" ]]; then
        D_HEALTH="$health_out"
    fi
fi

# UPGRADE
D_UPGRADE="none"
[[ -f "$PROJECT_ROOT/.agentic/.upgrade_pending" ]] && D_UPGRADE="pending"

# TIP
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
D_TIP="${tips[$((RANDOM % ${#tips[@]}))]}"

# STALE
D_STALE="no"
if command -v python3 >/dev/null 2>&1 && [[ -f "$TOOLS_DIR/backlog_helpers.py" ]]; then
    _py "$TOOLS_DIR/backlog_helpers.py" --project-root "$PROJECT_ROOT" check-staleness 7 >/dev/null 2>&1 && D_STALE="yes"
fi

# ---------------------------------------------------------------------------
# Output: --raw mode (for scripts) or rendered dashboard (for agents)
# ---------------------------------------------------------------------------
if $RAW_MODE; then
    echo "===VERSION==="
    echo "$D_VERSION"
    echo "===WIP==="
    echo "$D_WIP"
    if [[ "$D_WIP" == "interrupted" ]]; then
        echo "===WIP_DETAIL==="
        [[ -n "$D_WIP_FEATURE" ]] && echo "feature=$D_WIP_FEATURE"
        echo "changed_files=$D_WIP_CHANGED"
    fi
    echo "===STATUS==="
    echo "$D_STATUS"
    echo "===JOURNAL_LAST==="
    [[ -n "$D_JOURNAL_DATE" ]] && echo "date=$D_JOURNAL_DATE"
    [[ -n "$D_JOURNAL_SUMMARY" ]] && echo "summary=$D_JOURNAL_SUMMARY"
    echo "===BACKLOG==="
    echo "total=$D_BACKLOG_TOTAL"
    [[ -n "$D_BACKLOG_CUR_ID" ]] && echo "current_id=$D_BACKLOG_CUR_ID"
    [[ -n "$D_BACKLOG_CUR_DESC" ]] && echo "current_desc=$D_BACKLOG_CUR_DESC"
    [[ -n "$D_BACKLOG_CUR_REF" ]] && echo "current_ref=$D_BACKLOG_CUR_REF"
    [[ -n "$D_BACKLOG_CUR_SINCE" ]] && echo "current_since=$D_BACKLOG_CUR_SINCE"
    [[ -n "$D_BACKLOG_NEXT_ID" ]] && echo "next_id=$D_BACKLOG_NEXT_ID"
    [[ -n "$D_BACKLOG_NEXT_DESC" ]] && echo "next_desc=$D_BACKLOG_NEXT_DESC"
    echo "remaining=$D_BACKLOG_REMAINING"
    echo "===BLOCKERS==="
    echo "$D_BLOCKERS"
    echo "===TODO_COUNT==="
    echo "$D_TODO_COUNT"
    echo "===AGENTS==="
    echo "$D_AGENTS"
    echo "===HEALTH==="
    echo "$D_HEALTH"
    echo "===UPGRADE==="
    echo "$D_UPGRADE"
    echo "===TIP==="
    echo "$D_TIP"
    echo "===STALE==="
    echo "$D_STALE"
    exit 0
fi

# ---------------------------------------------------------------------------
# Rendered dashboard
# ---------------------------------------------------------------------------

# Project name from OVERVIEW.md or directory name
proj_name=""
if [[ -f "$PROJECT_ROOT/.agentic/OVERVIEW.md" ]]; then
    proj_name=$(head -5 "$PROJECT_ROOT/.agentic/OVERVIEW.md" 2>/dev/null | grep "^# " | head -1 | sed 's/^# //')
fi
# Fallback: skip generic "OVERVIEW.md" title
if [[ -z "$proj_name" ]] || [[ "$proj_name" == "OVERVIEW.md" ]] || [[ "$proj_name" == "OVERVIEW" ]]; then
    proj_name=$(basename "$PROJECT_ROOT")
fi

# Journal summary (short)
journal_line="First session"
if [[ -n "$D_JOURNAL_SUMMARY" ]]; then
    journal_line="$D_JOURNAL_SUMMARY"
elif [[ -n "$D_JOURNAL_DATE" ]]; then
    journal_line="$D_JOURNAL_DATE"
fi
# Truncate to 60 chars
[[ ${#journal_line} -gt 60 ]] && journal_line="${journal_line:0:57}..."

# Health summary (first line only — doctor.sh can be multiline)
health_line="Clean"
if [[ "$D_HEALTH" != "ok" ]]; then
    health_line=$(echo "$D_HEALTH" | head -1)
fi
if [[ "$D_BLOCKERS" -gt 0 ]]; then
    health_line="$health_line · $D_BLOCKERS blocker(s)"
else
    health_line="$health_line · No blockers"
fi

BAR="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "$proj_name · v$D_VERSION"
echo "$BAR"
echo ""
echo "📋 Last session   $journal_line"
echo "🎯 Focus          $D_STATUS"

# Conditional: interrupted work
if [[ "$D_WIP" == "interrupted" ]]; then
    wip_label="${D_WIP_FEATURE:-unknown feature}"
    echo "⚠️  Interrupted   $wip_label — $D_WIP_CHANGED uncommitted files"
    echo "                  Options: continue, review (\`git diff\`), or clear (\`wip.sh complete\`)"
fi

# Conditional: blockers
if [[ "$D_BLOCKERS" -gt 0 ]]; then
    echo "🚫 Blockers      $D_BLOCKERS items need human input — check HUMAN_NEEDED.md"
fi

# Conditional: active agents
if [[ "$D_AGENTS" != "none" ]]; then
    echo "👥 Agents        $D_AGENTS"
fi

# Conditional: stale
if [[ "$D_STALE" == "yes" ]]; then
    echo "⏰ Stale          Current backlog item is >7 days old — review priority"
fi

# Conditional: upgrade
if [[ "$D_UPGRADE" == "pending" ]]; then
    echo "🔄 Upgrade        Pending — read \`.agentic/.upgrade_pending\`"
fi

echo "✅ Health         $health_line"
echo ""

# Backlog
echo "📌 Backlog"
if [[ "$D_BACKLOG_TOTAL" -gt 0 ]]; then
    echo "   Current → $D_BACKLOG_CUR_ID  $D_BACKLOG_CUR_DESC"
    if [[ -n "$D_BACKLOG_NEXT_ID" ]]; then
        echo "   Next    → $D_BACKLOG_NEXT_ID  $D_BACKLOG_NEXT_DESC"
    fi
    echo "   Queue     $D_BACKLOG_REMAINING remaining"
else
    echo "   Empty — no queued work items"
fi
echo ""

# Next steps
echo "⚡ Next steps"
step=1
if [[ "$D_WIP" == "interrupted" ]]; then
    echo "   $step. Resume interrupted work on ${D_WIP_FEATURE:-current feature}"
    step=$((step + 1))
fi
if [[ "$D_BLOCKERS" -gt 0 ]]; then
    echo "   $step. Address $D_BLOCKERS blocker(s) in HUMAN_NEEDED.md"
    step=$((step + 1))
fi
if [[ "$D_BACKLOG_TOTAL" -gt 0 ]] && [[ "$D_WIP" == "clean" ]]; then
    echo "   $step. Start building — \`ag implement $D_BACKLOG_CUR_ID\`"
    step=$((step + 1))
    if [[ $step -le 3 ]]; then
        echo "   $step. Plan first — \`ag plan $D_BACKLOG_CUR_ID\`"
        step=$((step + 1))
    fi
fi
if [[ $step -le 3 ]]; then
    if [[ "$D_BACKLOG_TOTAL" -gt 0 ]]; then
        echo "   $step. View queue — \`ag backlog list\`"
    else
        echo "   $step. Seed backlog — \`ag backlog add\`"
    fi
fi
echo ""
echo "💡 Tip: $D_TIP"
echo "$BAR"
