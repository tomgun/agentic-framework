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
source "$PROJECT_ROOT/.agentic/lib/settings.sh" 2>/dev/null || true

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

# GIT MODE (F-0250)
D_GIT_MODE="active"  # Default for backwards compat
source "$PROJECT_ROOT/.agentic/lib/settings.sh" 2>/dev/null || true
if type get_setting &>/dev/null; then
    D_GIT_MODE=$(get_setting "git_mode" "active" 2>/dev/null || echo "active")
fi
# Auto-detect: if no .git directory exists, treat as deferred regardless of setting
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    [[ "$D_GIT_MODE" == "active" ]] && D_GIT_MODE="deferred"
fi

# WIP (interrupted work) — skip git checks when git not active
D_WIP="clean"
D_WIP_FEATURE=""
D_WIP_CHANGED=0
if ! bash "$TOOLS_DIR/wip.sh" check >/dev/null 2>&1; then
    D_WIP="interrupted"
    D_WIP_FEATURE=$(_py "$TOOLS_DIR/agents_helpers.py" --project-root "${MAIN_PROJECT_ROOT:-$PROJECT_ROOT}" get-current-feature "$PROJECT_ROOT" 2>/dev/null || echo "")
    if [[ "$D_GIT_MODE" == "active" ]]; then
        D_WIP_CHANGED=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
    fi
fi

# STATUS (current focus)
if [[ -f "${STATUS_FILE:-}" ]]; then
    D_STATUS=$(grep -A5 "^## Current session state" "$STATUS_FILE" 2>/dev/null | grep "^-" | head -1 | sed 's/^- //' | sed 's/ (Updated:.*)$//' || echo "No focus set")
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
    # Parse backlog JSON safely via line-delimited output (no eval)
    _backlog_out=$(_py -c "
import json, sys, re
def safe(s):
    return re.sub(r'[^\w\s\-.,;:()/#&@!+=]', '', str(s))[:120]
with open('$_tmpf') as f:
    items = json.load(f)
total = len(items)
print(total)
if total > 0:
    c = items[0]
    print(safe(c.get('id', c.get('feature_id', c.get('task', '?')))))
    print(safe(c.get('description', c.get('task', ''))))
    print(safe((c.get('refs', ['']) or [''])[0]))
    print(safe(c.get('became_current_at', '')))
else:
    print(''); print(''); print(''); print('')
if total > 1:
    n = items[1]
    print(safe(n.get('id', n.get('feature_id', n.get('task', '?')))))
    print(safe(n.get('description', n.get('task', ''))))
else:
    print(''); print('')
print(max(0, total - 2) if total > 2 else 0)
" 2>/dev/null) || _backlog_out=""
    if [[ -n "$_backlog_out" ]]; then
        { read -r D_BACKLOG_TOTAL
          read -r D_BACKLOG_CUR_ID
          read -r D_BACKLOG_CUR_DESC
          read -r D_BACKLOG_CUR_REF
          read -r D_BACKLOG_CUR_SINCE
          read -r D_BACKLOG_NEXT_ID
          read -r D_BACKLOG_NEXT_DESC
          read -r D_BACKLOG_REMAINING
        } <<< "$_backlog_out"
    fi
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

# AC DRIFT (F-0197)
D_AC_DRIFT_COUNT=0
if { [[ -d "$CONTRACTS_DIR" ]] || [[ -d "$ACCEPTANCE_DIR" ]]; } && [[ -f "$PROJECT_ROOT/.agentic/spec/FEATURES.md" ]]; then
    while IFS= read -r fid; do
        [[ -z "$fid" ]] && continue
        # Check contracts first, then legacy acceptance
        acc_file=""
        if [[ -f "$CONTRACTS_DIR/${fid}.yaml" ]]; then
            acc_file="$CONTRACTS_DIR/${fid}.yaml"
        elif [[ -f "$ACCEPTANCE_DIR/${fid}.md" ]]; then
            acc_file="$ACCEPTANCE_DIR/${fid}.md"
        fi
        [[ -z "$acc_file" || ! -f "$acc_file" ]] && continue
        total=0; checked=0
        while IFS= read -r line; do
            if echo "$line" | grep -qE '^[[:space:]]*- \[[ x]\][[:space:]]*\*?\*?AC-'; then
                total=$((total + 1))
                echo "$line" | grep -qE '^[[:space:]]*- \[x\]' && checked=$((checked + 1))
            elif echo "$line" | grep -qE '^### AC-'; then
                total=$((total + 1))
            fi
        done < "$acc_file"
        if [[ "$total" -gt 0 ]]; then
            pct=$((checked * 100 / total))
            [[ "$pct" -lt 50 ]] && D_AC_DRIFT_COUNT=$((D_AC_DRIFT_COUNT + 1))
        fi
    done < <(grep -B2 -iE '\*\*Status\*\*:[[:space:]]*shipped' "$PROJECT_ROOT/.agentic/spec/FEATURES.md" 2>/dev/null \
        | grep -oE 'F-[0-9]+' || true)
fi

# USER INPUT (pending contract user_input)
D_USER_INPUT_COUNT=0
D_USER_INPUT_FEATURES=""
if [[ -d "$CONTRACTS_DIR" ]] && command -v python3 >/dev/null 2>&1; then
    _ui_out=$(PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
from pathlib import Path; from contracts import get_pending_user_input
p = get_pending_user_input(Path('$CONTRACTS_DIR'))
print(len(p)); print(','.join(c.id for c in p[:5]))
" 2>/dev/null) || _ui_out=""
    if [[ -n "$_ui_out" ]]; then
        D_USER_INPUT_COUNT=$(echo "$_ui_out" | head -1)
        D_USER_INPUT_FEATURES=$(echo "$_ui_out" | tail -1)
    fi
fi

# SPEC METRICS (F-0225)
D_SPEC_METRICS=""
if [[ -f "$TOOLS_DIR/spec-metrics.sh" ]]; then
    D_SPEC_METRICS=$(bash "$TOOLS_DIR/spec-metrics.sh" --summary-line 2>/dev/null) || D_SPEC_METRICS=""
fi

# TOKEN METRICS (F-041 Phase 4)
D_TOKEN_METRICS=""
TOKEN_SUMMARY="$PROJECT_ROOT/.agentic/intel/token-summary.json"
if [[ -f "$TOKEN_SUMMARY" ]]; then
    _ts_sessions=$(grep -o '"total_sessions"[[:space:]]*:[[:space:]]*[0-9]*' "$TOKEN_SUMMARY" 2>/dev/null | head -1 | grep -o '[0-9]*$' || echo 0)
    _ts_reads=$(grep -o '"total_reads"[[:space:]]*:[[:space:]]*[0-9]*' "$TOKEN_SUMMARY" 2>/dev/null | head -1 | grep -o '[0-9]*$' || echo 0)
    _ts_writes=$(grep -o '"total_writes"[[:space:]]*:[[:space:]]*[0-9]*' "$TOKEN_SUMMARY" 2>/dev/null | head -1 | grep -o '[0-9]*$' || echo 0)
    D_TOKEN_METRICS="${_ts_sessions} sessions, ${_ts_reads} reads, ${_ts_writes} writes"
fi

# INTEL METRICS (F-041: intelligence sourcing audit)
D_INTEL_METRICS=""
INTEL_SUMMARY="$PROJECT_ROOT/.agentic/intel/intel-summary.json"
if [[ -f "$INTEL_SUMMARY" ]]; then
    _il_queries=$(grep -o '"total_queries"[[:space:]]*:[[:space:]]*[0-9]*' "$INTEL_SUMMARY" 2>/dev/null | head -1 | grep -o '[0-9]*$' || echo 0)
    _il_enforces=$(grep -o '"total_enforcements"[[:space:]]*:[[:space:]]*[0-9]*' "$INTEL_SUMMARY" 2>/dev/null | head -1 | grep -o '[0-9]*$' || echo 0)
    _il_items=$(grep -o '"total_items_surfaced"[[:space:]]*:[[:space:]]*[0-9]*' "$INTEL_SUMMARY" 2>/dev/null | head -1 | grep -o '[0-9]*$' || echo 0)
    D_INTEL_METRICS="${_il_queries} queries, ${_il_enforces} enforcements, ${_il_items} items sourced"
fi

# CAPABILITY CATALOG (F-042: Universal Capability Catalog)
# FEATURES.md for formal feature tracking; OVERVIEW.md checkboxes for lightweight tracking
D_CAP_METRICS=""
FEATURES_FILE_DASH="$PROJECT_ROOT/.agentic/spec/FEATURES.md"
OVERVIEW_FILE_DASH="$PROJECT_ROOT/.agentic/OVERVIEW.md"
if [[ -f "$FEATURES_FILE_DASH" ]]; then
    # Formal: count by status values in FEATURES.md
    _cap_built=$(grep -ciE '^\*\*Status\*\*:\s*(built|shipped)' "$FEATURES_FILE_DASH" 2>/dev/null || echo 0)
    _cap_built="${_cap_built## }"
    _cap_progress=$(grep -ciE '^\*\*Status\*\*:\s*(in_progress|implementing)' "$FEATURES_FILE_DASH" 2>/dev/null || echo 0)
    _cap_progress="${_cap_progress## }"
    _cap_planned=$(grep -ciE '^\*\*Status\*\*:\s*(planned|specced|criteria_set)' "$FEATURES_FILE_DASH" 2>/dev/null || echo 0)
    _cap_planned="${_cap_planned## }"
    if [[ $(( _cap_built + _cap_progress + _cap_planned )) -gt 0 ]]; then
        D_CAP_METRICS="${_cap_built} built, ${_cap_progress} in progress, ${_cap_planned} planned"
    fi
elif [[ -f "$OVERVIEW_FILE_DASH" ]]; then
    # Lightweight: count checkboxes in OVERVIEW.md Core Capabilities section
    _cap_done=$(sed -n '/^## Core Capabilities/,/^## /p' "$OVERVIEW_FILE_DASH" 2>/dev/null | grep -c '^\- \[x\]' 2>/dev/null || echo 0)
    _cap_done="${_cap_done## }"
    _cap_todo=$(sed -n '/^## Core Capabilities/,/^## /p' "$OVERVIEW_FILE_DASH" 2>/dev/null | grep -c '^\- \[ \]' 2>/dev/null || echo 0)
    _cap_todo="${_cap_todo## }"
    if [[ $(( _cap_done + _cap_todo )) -gt 0 ]]; then
        D_CAP_METRICS="${_cap_done} done, ${_cap_todo} planned"
    fi
fi

# DESIGN TRACE (pending source docs)
D_DESIGN_TRACE=""
if [[ -f "$TOOLS_DIR/design-trace.sh" ]]; then
    D_DESIGN_TRACE=$(bash "$TOOLS_DIR/design-trace.sh" --quiet 2>/dev/null) || D_DESIGN_TRACE=""
fi

# FRAMEWORK WIRING (are hooks installed? without them the framework is inert)
# Git hooks: quality gates on commit (spec-first, test coverage, doc freshness)
# Claude hooks: intelligence injection (planning guidance, pattern enforcement, quality checklists)
# Skills: workflow automation (loaded on-demand from .claude/skills/ — checked separately)
D_FW_GIT="ok"
D_FW_CLAUDE="ok"
D_FW_SKILLS="ok"
D_FW_ISSUES=""

# Check 1: Git pre-commit hooks — core.hooksPath must point to .agentic/hooks
if [[ "$D_GIT_MODE" == "active" ]] && command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    _hooks_path=$(git config core.hooksPath 2>/dev/null || echo "")
    if [[ -z "$_hooks_path" ]]; then
        D_FW_GIT="disconnected"
        D_FW_ISSUES="${D_FW_ISSUES}git-hooks "
    elif [[ ! -f "$PROJECT_ROOT/$_hooks_path/pre-commit" ]] && [[ ! -f "$_hooks_path/pre-commit" ]]; then
        D_FW_GIT="broken"
        D_FW_ISSUES="${D_FW_ISSUES}git-hooks "
    fi
fi

# Check 2: Claude hooks — .claude/hooks.json must exist with framework hook types
# Detection: checks that hooks dict has at least one known event type key.
# If hooks.json format changes, update fw_types set below.
_claude_hooks_found=false
_hooks_file="$PROJECT_ROOT/.claude/hooks.json"
if [[ -f "$_hooks_file" ]] && command -v python3 >/dev/null 2>&1; then
    _has_hooks=$(_AG_HOOKS_FILE="$_hooks_file" _py -c "
import json, os
try:
    d = json.load(open(os.environ['_AG_HOOKS_FILE']))
    # hooks.json uses dict format: {'hooks': {'PreToolUse': [...], ...}}
    hooks = d.get('hooks', {})
    if isinstance(hooks, dict):
        fw_types = {'PreToolUse', 'PostToolUse', 'UserPromptSubmit', 'Stop', 'PreCompact', 'SessionStart'}
        print('yes' if fw_types & set(hooks.keys()) else 'no')
    else:
        print('no')
except: print('no')
" 2>/dev/null) || _has_hooks="no"
    [[ "$_has_hooks" == "yes" ]] && _claude_hooks_found=true
fi
if ! $_claude_hooks_found; then
    D_FW_CLAUDE="disconnected"
    D_FW_ISSUES="${D_FW_ISSUES}claude-hooks "
fi

# Check 3: Skills — .claude/skills/ should have workflow skills installed
_skills_dir="$PROJECT_ROOT/.claude/skills"
if [[ ! -d "$_skills_dir" ]]; then
    D_FW_SKILLS="missing"
    D_FW_ISSUES="${D_FW_ISSUES}skills "
else
    _skill_count=$(ls -d "$_skills_dir"/*/ 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$_skill_count" -eq 0 ]]; then
        D_FW_SKILLS="empty"
        D_FW_ISSUES="${D_FW_ISSUES}skills "
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
    "Use \`ag test\` to run your project's test suite."
    "Run \`ag sync --check\` for a dry run — see what's drifted."
    "Use \`ag trace --gaps\` to find shipped features with no code annotations."
    "Run \`ag verify --full\` for a comprehensive framework health check."
    "Use \`ag specs\` to generate specs for existing code, domain by domain."
    "Run \`ag tools\` to discover all available framework tools and scripts."
    "Use \`ag backlog\` to view and manage the ordered work queue."
    "Use \`ag flush\` to commit state files directly to main without a PR."
)
D_TIP="${tips[$((RANDOM % ${#tips[@]}))]}"

# DIRTY STATE FILES (ag flush) — skip when git not active (F-0250)
D_DIRTY_STATE=0
if [[ "$D_GIT_MODE" == "active" ]] && [[ -f "$TOOLS_DIR/state-commit.sh" ]]; then
    bash "$TOOLS_DIR/state-commit.sh" --check >/dev/null 2>&1 && D_DIRTY_STATE=1
fi

# STALE
D_STALE="no"
if command -v python3 >/dev/null 2>&1 && [[ -f "$TOOLS_DIR/backlog_helpers.py" ]]; then
    _py "$TOOLS_DIR/backlog_helpers.py" --project-root "$PROJECT_ROOT" check-staleness 7 >/dev/null 2>&1 && D_STALE="yes"
fi

# COMPLETION GATE (stale current item — has commits but not shipped)
D_COMPLETION_STALE=""
if [[ "$D_GIT_MODE" == "active" ]] && [[ -n "${D_BACKLOG_CUR_ID:-}" ]] && command -v python3 >/dev/null 2>&1; then
    _cg_out=$(_py "$TOOLS_DIR/backlog_helpers.py" --project-root "$PROJECT_ROOT" \
        check-completion-gate "${D_BACKLOG_CUR_ID}" 2>/dev/null) || _cg_out=""
    if [[ -n "$_cg_out" ]]; then
        _cg_blocked=$(echo "$_cg_out" | _py -c "import json,sys; print(json.load(sys.stdin).get('blocked',False))" 2>/dev/null) || _cg_blocked="False"
        if [[ "$_cg_blocked" == "True" ]]; then
            D_COMPLETION_STALE=$(echo "$_cg_out" | _py -c "import json,sys; print(json.load(sys.stdin).get('stale_feature',''))" 2>/dev/null) || D_COMPLETION_STALE=""
        fi
    fi
fi

# ORPHANED PLANS (unsaved session-scoped plans needing review)
# Note: This is distinct from periodic-checks.sh check_orphaned_plans() which uses
# fingerprint matching and a 2+ feature ID threshold. dashboard uses plan-scan.sh
# because it's the action tool (saves plans), while periodic-checks is advisory.
D_ORPHAN_PLANS=0
D_ORPHAN_PLAN_SUMMARY=""
if [[ -f "$TOOLS_DIR/plan-scan.sh" ]]; then
    _ps_out=$(bash "$TOOLS_DIR/plan-scan.sh" --check --quiet 2>/dev/null) || true
    if [[ -n "$_ps_out" ]]; then
        D_ORPHAN_PLANS=$(echo "$_ps_out" | grep -oE '[0-9]+' | head -1)
        D_ORPHAN_PLANS="${D_ORPHAN_PLANS:-0}"
        D_ORPHAN_PLAN_SUMMARY="$_ps_out"
    fi
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
    echo "===AGENTS==="
    echo "$D_AGENTS"
    echo "===HEALTH==="
    echo "$D_HEALTH"
    echo "===UPGRADE==="
    echo "$D_UPGRADE"
    echo "===SPEC_METRICS==="
    echo "$D_SPEC_METRICS"
    echo "===DESIGN_TRACE==="
    echo "$D_DESIGN_TRACE"
    echo "===TOKEN_METRICS==="
    echo "$D_TOKEN_METRICS"
    echo "===INTEL_METRICS==="
    echo "$D_INTEL_METRICS"
    echo "===CAP_METRICS==="
    echo "$D_CAP_METRICS"
    echo "===USER_INPUT==="
    echo "$D_USER_INPUT_COUNT"
    echo "$D_USER_INPUT_FEATURES"
    echo "===ORPHAN_PLANS==="
    echo "$D_ORPHAN_PLANS"
    echo "===TIP==="
    echo "$D_TIP"
    echo "===DIRTY_STATE==="
    echo "$D_DIRTY_STATE"
    echo "===STALE==="
    echo "$D_STALE"
    echo "===COMPLETION_STALE==="
    echo "$D_COMPLETION_STALE"
    echo "===FRAMEWORK==="
    echo "git=$D_FW_GIT"
    echo "claude=$D_FW_CLAUDE"
    echo "skills=$D_FW_SKILLS"
    echo "issues=$D_FW_ISSUES"
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
    # Try git remote name (useful when dir name is generic, e.g. /workspace in Docker)
    _remote_url=$(git -C "$PROJECT_ROOT" remote get-url origin 2>/dev/null)
    if [[ -n "$_remote_url" ]]; then
        proj_name=$(basename "$_remote_url" .git | sed 's/\.git$//')
    fi
fi
if [[ -z "$proj_name" ]]; then
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

# Conditional: dirty state files (only when git active)
if [[ "$D_DIRTY_STATE" -eq 1 ]]; then
    _flush_mode=$(get_setting "main_branch_mode" "direct" 2>/dev/null || echo "direct")
    if [[ "$_flush_mode" == "protected" ]]; then
        echo "📤 Dirty state    Uncommitted state files. Run: ag flush (creates PR)"
    else
        echo "📤 Dirty state    Uncommitted state files. Run: ag flush"
    fi
fi

# Conditional: git deferred mode (F-0250)
if [[ "$D_GIT_MODE" != "active" ]]; then
    echo "💡 Git            Deferred — run \`ag git-init\` when ready to track changes"
fi

# Conditional: stale
if [[ "$D_STALE" == "yes" ]]; then
    echo "⏰ Stale          Current backlog item is >7 days old — review priority"
fi

# Conditional: completion gate (stale prior feature)
if [[ -n "$D_COMPLETION_STALE" ]]; then
    echo "⚠️  Unfinished    $D_COMPLETION_STALE has merged code but isn't shipped — run: ag done $D_COMPLETION_STALE"
fi

# Conditional: upgrade
if [[ "$D_UPGRADE" == "pending" ]]; then
    echo "🔄 Upgrade        Pending — read \`.agentic/.upgrade_pending\`"
fi

if [[ "$D_USER_INPUT_COUNT" -gt 0 ]]; then
    echo "📥 User input     $D_USER_INPUT_COUNT pending${D_USER_INPUT_FEATURES:+ — $D_USER_INPUT_FEATURES}"
fi
if [[ "$D_AC_DRIFT_COUNT" -gt 0 ]]; then
    echo "⚠️  AC Drift       $D_AC_DRIFT_COUNT shipped feature(s) with <50% ACs checked"
fi
if [[ "$D_ORPHAN_PLANS" -gt 0 ]]; then
    echo "📝 Orphan plans   $D_ORPHAN_PLAN_SUMMARY"
fi
# Conditional: NFR health (only when NFR.md exists)
if [[ -f "$ROOT_DIR/.agentic/spec/NFR.md" ]] && grep -qE '^## NFR-[0-9]+' "$ROOT_DIR/.agentic/spec/NFR.md" 2>/dev/null; then
    nfr_summary=$(bash "$TOOLS_DIR/nfr-health.sh" --summary 2>/dev/null || echo "")
    if [[ -n "$nfr_summary" ]]; then
        echo "📊 NFRs           $nfr_summary"
    fi
fi
if [[ -n "$D_SPEC_METRICS" ]]; then
    echo "📊 Spec evolution  $D_SPEC_METRICS"
fi
if [[ -n "$D_TOKEN_METRICS" ]]; then
    echo "📊 Token usage     $D_TOKEN_METRICS"
fi
if [[ -n "$D_INTEL_METRICS" ]]; then
    echo "🧠 Intel sourcing  $D_INTEL_METRICS"
fi
if [[ -n "$D_CAP_METRICS" ]]; then
    echo "📦 Capabilities    $D_CAP_METRICS"
fi
if [[ -n "$D_DESIGN_TRACE" ]]; then
    echo "📐 Design trace   $D_DESIGN_TRACE — run: design-trace.sh"
fi
# Framework wiring — loud warning if disconnected
if [[ -n "$D_FW_ISSUES" ]]; then
    echo "🚨 FRAMEWORK DISCONNECTED — running as vanilla Claude. OFFER TO FIX before other work."
    if [[ "$D_FW_GIT" != "ok" ]]; then
        echo "   FIX (gates):        git config core.hooksPath .agentic/hooks"
    fi
    if [[ "$D_FW_CLAUDE" != "ok" ]]; then
        echo "   FIX (intelligence): cp .agentic/lib/claude-hooks/hooks.json .claude/"
    fi
    if [[ "$D_FW_SKILLS" != "ok" ]]; then
        echo "   FIX (skills):       ag export claude"
    fi
    echo "   ⚠ After fixing: RESTART Claude Code for hooks to take effect."
else
    echo "✅ Framework      Hooks + skills active"
fi
echo "✅ Health         $health_line"
echo ""

# Backlog
echo "📌 Backlog"
if [[ "$D_BACKLOG_TOTAL" -gt 0 ]]; then
    echo "   Current → $D_BACKLOG_CUR_ID  $D_BACKLOG_CUR_DESC"
    # Phase progress (F-032)
    if [[ -n "$D_BACKLOG_CUR_ID" ]] && command -v python3 >/dev/null 2>&1; then
        _phase_progress=$(PYTHONPATH="$ROOT_DIR/.agentic/lib" _py "$ROOT_DIR/.agentic/lib/auto/phases.py" \
            --project-root "$PROJECT_ROOT" progress "$D_BACKLOG_CUR_ID" 2>/dev/null) || _phase_progress=""
        if [[ -n "$_phase_progress" ]]; then
            _phase_next=$(PYTHONPATH="$ROOT_DIR/.agentic/lib" _py "$ROOT_DIR/.agentic/lib/auto/phases.py" \
                --project-root "$PROJECT_ROOT" next-phase "$D_BACKLOG_CUR_ID" 2>/dev/null) || _phase_next=""
            _phase_line="   Progress  $_phase_progress"
            [[ -n "$_phase_next" ]] && _phase_line="$_phase_line — $_phase_next next"
            echo "$_phase_line"
        fi
    fi
    if [[ -n "$D_BACKLOG_NEXT_ID" ]]; then
        echo "   Next    → $D_BACKLOG_NEXT_ID  $D_BACKLOG_NEXT_DESC"
    fi
    echo "   Queue     $D_BACKLOG_REMAINING remaining"
else
    echo "   Empty — no queued work items"
    # Change 10: Warn if features exist but backlog is empty
    if [[ -f "$ROOT_DIR/.agentic/spec/FEATURES.md" ]]; then
        _planned=$(grep -c '^\*\*Status\*\*:\s*planned' "$ROOT_DIR/.agentic/spec/FEATURES.md" 2>/dev/null || echo 0)
        _planned="${_planned## }"
        if [[ "${_planned:-0}" -gt 0 ]]; then
            echo "   ⚠️  ${_planned} planned feature(s) — run \`ag backlog add F-XXXX\` to queue work"
        fi
    fi
fi

# Change 14: Show orphaned intent count if any
_INTENTS_FILE="$ROOT_DIR/.agentic/session/intents.json"
if [[ -f "$_INTENTS_FILE" ]]; then
    _intent_count=$(_py -c "
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    intents = data if isinstance(data, list) else data.get('intents', [])
    print(sum(1 for i in intents if i.get('status') == 'active'))
except: print(0)
" "$_INTENTS_FILE" 2>/dev/null || echo 0)
    _intent_count="${_intent_count## }"
    if [[ "${_intent_count:-0}" -gt 0 ]]; then
        echo "⚠️  Intents   ${_intent_count} orphaned — run \`ag intent list\` or \`ag sync\`"
    fi
fi

echo ""

# Next steps
echo "⚡ Next steps"
step=1
if [[ "$D_ORPHAN_PLANS" -gt 0 ]]; then
    echo "   $step. Save orphaned plan(s) and run dialectical review before implementing"
    step=$((step + 1))
fi
if [[ "$D_WIP" == "interrupted" ]]; then
    echo "   $step. Resume interrupted work on ${D_WIP_FEATURE:-current feature}"
    step=$((step + 1))
fi
if [[ "$D_BLOCKERS" -gt 0 ]]; then
    echo "   $step. Address $D_BLOCKERS blocker(s) in HUMAN_NEEDED.md"
    step=$((step + 1))
fi
if [[ "$D_USER_INPUT_COUNT" -gt 0 ]]; then
    echo "   $step. Process pending user input — \`ag contract pending\`"
    step=$((step + 1))
fi
if [[ "$D_BACKLOG_TOTAL" -gt 0 ]] && [[ "$D_WIP" == "clean" ]]; then
    echo "   $step. Plan first — \`ag plan $D_BACKLOG_CUR_ID\`"
    step=$((step + 1))
    if [[ $step -le 3 ]]; then
        echo "   $step. Start building — \`ag implement $D_BACKLOG_CUR_ID\`"
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
