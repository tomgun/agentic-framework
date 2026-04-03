#!/usr/bin/env bash
# Stop.sh: Enforcement hook — blocks session stop until verification passes
#
# This is an ENFORCEMENT hook. It calls `ag gate stop` and returns:
#   exit 0 = allow (session can end)
#   exit 2 = deny (session must not end — verification failed)
#
# Triggered by: Claude Code Stop hook
# Timeout: 5 seconds

# Bootstrap: ensure lib/ is extracted (inline check avoids fork when lib exists)
[[ -d "${CLAUDE_PROJECT_DIR:-.}/.agentic/lib/tools" ]] || bash "${CLAUDE_PROJECT_DIR:-.}/.agentic/bootstrap.sh" 2>/dev/null || true

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_ROOT"
source "$PROJECT_ROOT/.agentic/lib/paths.sh" 2>/dev/null || true
source "$PROJECT_ROOT/.agentic/lib/tools/fwlog.sh" 2>/dev/null || true
source "$PROJECT_ROOT/.agentic/lib/tools/btrace.sh" 2>/dev/null || true
flog "hook:stop" "fire" "" "start" 2>/dev/null || true

# Skip if not an agentic project
if [[ ! -d ".agentic" ]]; then
  exit 0
fi

# btrace: enter
btrace "Stop" "enter" "{}" 2>/dev/null || true

# --- Enforcement: call ag gate stop ---
GATE_OUTPUT=""
GATE_RC=0
_BT_STOP_START=$SECONDS
GATE_OUTPUT=$(PYTHONPATH="$PROJECT_ROOT/.agentic/lib" python3 -m gate stop --project-root "$PROJECT_ROOT" 2>&1) || GATE_RC=$?
_BT_STOP_MS=$(( (SECONDS - _BT_STOP_START) * 1000 ))

# Parse JSON response
DECISION="allow"
if command -v jq >/dev/null 2>&1 && echo "$GATE_OUTPUT" | jq -e . >/dev/null 2>&1; then
  DECISION=$(echo "$GATE_OUTPUT" | jq -r '.decision // "allow"')
  REASONS=$(echo "$GATE_OUTPUT" | jq -r '.reasons // [] | join("; ")' 2>/dev/null || echo "")
  WARNINGS=$(echo "$GATE_OUTPUT" | jq -r '.warnings // [] | join("; ")' 2>/dev/null || echo "")
else
  # jq not available or invalid JSON — parse manually
  if echo "$GATE_OUTPUT" | grep -q '"decision".*"deny"'; then
    DECISION="deny"
  fi
  REASONS=$(echo "$GATE_OUTPUT" | grep -o '"reasons":\s*\[.*\]' | head -1 || echo "")
  WARNINGS=""
fi

# btrace: gate result
btrace "Stop" "gate_result" "{\"decision\":\"${DECISION}\",\"exit_code\":${GATE_RC},\"duration_ms\":${_BT_STOP_MS:-0}}" 2>/dev/null || true

# --- Capability catalog check (F-042: Universal Capability Catalog) ---
# Advisory: warn if implementation code was written but design doc not updated.
# FEATURES.md when feature_tracking=yes; OVERVIEW.md otherwise.
# Must run BEFORE token finalizer cleans up token-events.log.
if [[ ! -f ".agentic/session/.cap_updated" && -f ".agentic/session/token-events.log" ]]; then
  _CAP_IMPL_WRITES=$(grep '^W|' ".agentic/session/token-events.log" 2>/dev/null \
    | grep -cE '\|(src/|lib/|app/|cmd/|\.agentic/lib/tools/|\.agentic/lib/auto/)' 2>/dev/null || true)
  _CAP_IMPL_WRITES="${_CAP_IMPL_WRITES## }"; _CAP_IMPL_WRITES="${_CAP_IMPL_WRITES%%[!0-9]*}"; _CAP_IMPL_WRITES="${_CAP_IMPL_WRITES:-0}"
  if [[ "${_CAP_IMPL_WRITES:-0}" -ge 3 ]]; then
    # Determine which doc to suggest based on settings
    _CAP_DOC="OVERVIEW.md"
    if [[ -f ".agentic/spec/FEATURES.md" ]]; then
      _CAP_DOC=".agentic/spec/FEATURES.md"
    fi
    echo "📦 Design doc not updated: ${_CAP_IMPL_WRITES} impl files written but ${_CAP_DOC} not touched." >&2
    echo "   Next session: update ${_CAP_DOC} with what you built." >&2
  fi
fi

# --- Finalize token ledger (Phase 2: F-041 Intelligence Engine) ---
_TK_EVENTS=".agentic/session/token-events.log"
_TK_SUMMARY=".agentic/intel/token-summary.json"
_TK_LEDGER=".agentic/session/token-ledger.json"

if [[ -f "$_TK_EVENTS" ]]; then
  _TK_READS=$(grep -c '^R|' "$_TK_EVENTS" 2>/dev/null || true)
  _TK_READS="${_TK_READS## }"; _TK_READS="${_TK_READS%%[!0-9]*}"; _TK_READS="${_TK_READS:-0}"
  _TK_WRITES=$(grep -c '^W|' "$_TK_EVENTS" 2>/dev/null || true)
  _TK_WRITES="${_TK_WRITES## }"; _TK_WRITES="${_TK_WRITES%%[!0-9]*}"; _TK_WRITES="${_TK_WRITES:-0}"
  _TK_UNIQUE=$(grep '^R|' "$_TK_EVENTS" 2>/dev/null | cut -d'|' -f2 | sort -u | wc -l 2>/dev/null || true)
  _TK_UNIQUE="${_TK_UNIQUE## }"; _TK_UNIQUE="${_TK_UNIQUE%%[!0-9]*}"; _TK_UNIQUE="${_TK_UNIQUE:-0}"
  _TK_REPEATED=$(( _TK_READS - _TK_UNIQUE ))
  [[ $_TK_REPEATED -lt 0 ]] && _TK_REPEATED=0
  _TK_COST=$(awk -F'|' '{sum += $3} END {print sum+0}' "$_TK_EVENTS" 2>/dev/null || echo 0)
  _TK_NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Write session ledger JSON
  cat > "$_TK_LEDGER" <<TKEOF
{
  "finalized": "$_TK_NOW",
  "reads": $_TK_READS,
  "writes": $_TK_WRITES,
  "unique_files_read": $_TK_UNIQUE,
  "repeated_reads": $_TK_REPEATED,
  "estimated_context_cost": $_TK_COST
}
TKEOF

  # Merge into lifetime summary
  # NOTE: JSON parsing duplicated from intel.sh _intel_json_int — Stop.sh can't source intel.sh
  # (different execution context). Keep both in sync if schema changes.
  # Safe integer extraction: strip non-digits to prevent "0\n0" arithmetic errors
  _tk_safe_int() { local v; v=$("$@" 2>/dev/null || true); v="${v##*[!0-9]}"; v="${v## }"; v="${v%% }"; v="${v%%[!0-9]*}"; echo "${v:-0}"; }
  _TK_P_SESS=0 _TK_P_RD=0 _TK_P_WR=0 _TK_P_REP=0 _TK_P_COST=0
  if [[ -f "$_TK_SUMMARY" ]]; then
    _TK_P_SESS=$(_tk_safe_int grep -o '"total_sessions"[[:space:]]*:[[:space:]]*[0-9]*' "$_TK_SUMMARY")
    _TK_P_RD=$(_tk_safe_int grep -o '"total_reads"[[:space:]]*:[[:space:]]*[0-9]*' "$_TK_SUMMARY")
    _TK_P_WR=$(_tk_safe_int grep -o '"total_writes"[[:space:]]*:[[:space:]]*[0-9]*' "$_TK_SUMMARY")
    _TK_P_REP=$(_tk_safe_int grep -o '"total_repeated_reads"[[:space:]]*:[[:space:]]*[0-9]*' "$_TK_SUMMARY")
    _TK_P_COST=$(_tk_safe_int grep -o '"total_estimated_cost"[[:space:]]*:[[:space:]]*[0-9]*' "$_TK_SUMMARY")
  fi

  mkdir -p ".agentic/intel" 2>/dev/null || true
  cat > "$_TK_SUMMARY" <<TKEOF
{
  "total_sessions": $(( _TK_P_SESS + 1 )),
  "total_reads": $(( _TK_P_RD + _TK_READS )),
  "total_writes": $(( _TK_P_WR + _TK_WRITES )),
  "total_repeated_reads": $(( _TK_P_REP + _TK_REPEATED )),
  "total_estimated_cost": $(( _TK_P_COST + _TK_COST )),
  "last_updated": "$_TK_NOW"
}
TKEOF

  btrace "Stop" "token_finalize" "{\"reads\":$_TK_READS,\"writes\":$_TK_WRITES,\"repeated\":$_TK_REPEATED,\"est_cost\":$_TK_COST}" 2>/dev/null || true
  echo "📊 Session: ${_TK_READS} reads (${_TK_REPEATED} repeated), ${_TK_WRITES} writes, ~${_TK_COST} est. tokens" >&2

  # Clean up events log
  rm -f "$_TK_EVENTS"
fi

# --- Finalize intel event log (F-041: Intelligence sourcing audit) ---
_IL_EVENTS=".agentic/session/intel-events.log"
_IL_SUMMARY=".agentic/intel/intel-summary.json"

# Safe integer extraction — strips whitespace and non-digit prefixes from grep/awk output
_il_int() { local v; v=$("$@" 2>/dev/null || echo 0); v="${v##*[!0-9]}"; v="${v## }"; v="${v%% }"; v="${v%%[!0-9]*}"; echo "${v:-0}"; }

if [[ -f "$_IL_EVENTS" ]]; then
  _IL_QUERIES=$(_il_int grep -c '|query|' "$_IL_EVENTS")
  _IL_ENFORCES=$(_il_int grep -c '|enforce|' "$_IL_EVENTS")
  _IL_MUTATES=$(_il_int grep -c '|mutate|' "$_IL_EVENTS")
  _IL_SCANS=$(_il_int grep -c '|scan|' "$_IL_EVENTS")
  _IL_TOTAL_ITEMS=$(awk -F'|' '{sum += $4} END {print sum+0}' "$_IL_EVENTS" 2>/dev/null || echo 0)
  _IL_TOTAL_ITEMS="${_IL_TOTAL_ITEMS## }"; _IL_TOTAL_ITEMS="${_IL_TOTAL_ITEMS%% }"
  _IL_NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Merge into lifetime summary
  _IL_P_SESS=0 _IL_P_Q=0 _IL_P_E=0 _IL_P_M=0 _IL_P_S=0 _IL_P_I=0
  if [[ -f "$_IL_SUMMARY" ]]; then
    _IL_P_SESS=$(_il_int grep -o '"total_sessions"[[:space:]]*:[[:space:]]*[0-9]*' "$_IL_SUMMARY")
    _IL_P_Q=$(_il_int grep -o '"total_queries"[[:space:]]*:[[:space:]]*[0-9]*' "$_IL_SUMMARY")
    _IL_P_E=$(_il_int grep -o '"total_enforcements"[[:space:]]*:[[:space:]]*[0-9]*' "$_IL_SUMMARY")
    _IL_P_M=$(_il_int grep -o '"total_mutations"[[:space:]]*:[[:space:]]*[0-9]*' "$_IL_SUMMARY")
    _IL_P_S=$(_il_int grep -o '"total_scans"[[:space:]]*:[[:space:]]*[0-9]*' "$_IL_SUMMARY")
    _IL_P_I=$(_il_int grep -o '"total_items_surfaced"[[:space:]]*:[[:space:]]*[0-9]*' "$_IL_SUMMARY")
  fi

  mkdir -p ".agentic/intel" 2>/dev/null || true
  cat > "$_IL_SUMMARY" <<ILEOF
{
  "total_sessions": $(( _IL_P_SESS + 1 )),
  "total_queries": $(( _IL_P_Q + _IL_QUERIES )),
  "total_enforcements": $(( _IL_P_E + _IL_ENFORCES )),
  "total_mutations": $(( _IL_P_M + _IL_MUTATES )),
  "total_scans": $(( _IL_P_S + _IL_SCANS )),
  "total_items_surfaced": $(( _IL_P_I + _IL_TOTAL_ITEMS )),
  "last_updated": "$_IL_NOW"
}
ILEOF

  echo "🧠 Intel: ${_IL_QUERIES} queries, ${_IL_ENFORCES} enforcements, ${_IL_MUTATES} mutations, ${_IL_SCANS} scans (${_IL_TOTAL_ITEMS} items sourced)" >&2

  # Clean up events log
  rm -f "$_IL_EVENTS"
fi

# --- Clean up advisory nudge sentinels (safe on deny — they're just dedup flags) ---
rm -f .agentic/session/.impl_intel_pushed 2>/dev/null || true
rm -f .agentic/session/.token_budget_warned 2>/dev/null || true
rm -f .agentic/session/.tdd_nudge_fired 2>/dev/null || true
rm -f .agentic/session/.correction_hint_shown 2>/dev/null || true
rm -f .agentic/session/.commit_nudge_fired 2>/dev/null || true
rm -f .agentic/session/.sync_suggested 2>/dev/null || true
# NOTE: Enforcement sentinels (review-pending-*, .phase_implementing, .impl-brief.md,
# .contract-surface.txt, .nfr-brief.txt) are cleaned up ONLY on allow — see below.

# --- Deregister session (F-0195: multi-session collision prevention) ---
AGENTIC_LIB="$PROJECT_ROOT/.agentic/lib"
if [[ -f "$AGENTIC_LIB/tools/agents_helpers.py" ]]; then
  python3 "$AGENTIC_LIB/tools/agents_helpers.py" \
    --project-root "$PROJECT_ROOT" session-deregister "$PROJECT_ROOT" --pid "$PPID" 2>/dev/null || true
fi

# --- Output and exit ---
if [[ "$DECISION" == "deny" ]]; then
  btrace "Stop" "exit" "{\"decision\":\"deny\",\"exit_code\":2}" 2>/dev/null || true
  echo ""
  echo "🚫 Session stop BLOCKED — verification not passed"
  echo ""
  if [[ -n "$REASONS" ]]; then
    echo "Reasons:"
    echo "  $REASONS"
  fi
  echo ""
  echo "Fix the issues above, then try stopping again."
  echo "Or run: ag verify <feature-id>"
  echo ""
  exit 2
fi

# Allowed — show advisory warnings if any
if [[ -n "${WARNINGS:-}" && "$WARNINGS" != "" ]]; then
  echo ""
  echo "👋 Session ending — advisory reminders:"
  echo "  $WARNINGS"
  echo ""
fi

# --- Clean up enforcement sentinels (ONLY on allow — must persist across denied stops) ---
rm -f .agentic/session/review-pending-* 2>/dev/null || true
rm -f .agentic/session/.phase_implementing 2>/dev/null || true
rm -f .agentic/session/.impl-brief.md 2>/dev/null || true
rm -f .agentic/session/.contract-surface.txt 2>/dev/null || true
rm -f .agentic/session/.nfr-brief.txt 2>/dev/null || true

btrace "Stop" "exit" "{\"decision\":\"allow\",\"exit_code\":0}" 2>/dev/null || true

echo ""
echo "✓ All checks passed. Session ending."
echo ""
exit 0
