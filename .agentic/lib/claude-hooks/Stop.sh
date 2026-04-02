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
flog "hook:stop" "fire" "" "start" 2>/dev/null || true

# Skip if not an agentic project
if [[ ! -d ".agentic" ]]; then
  exit 0
fi

# --- Enforcement: call ag gate stop ---
GATE_OUTPUT=""
GATE_RC=0
GATE_OUTPUT=$(PYTHONPATH="$PROJECT_ROOT/.agentic/lib" python3 -m gate stop --project-root "$PROJECT_ROOT" 2>&1) || GATE_RC=$?

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

# --- Finalize token ledger (Phase 2: F-041 Intelligence Engine) ---
_TK_EVENTS=".agentic/session/token-events.log"
_TK_SUMMARY=".agentic/intel/token-summary.json"
_TK_LEDGER=".agentic/session/token-ledger.json"

if [[ -f "$_TK_EVENTS" ]]; then
  _TK_READS=$(grep -c '^R|' "$_TK_EVENTS" 2>/dev/null || echo 0)
  _TK_WRITES=$(grep -c '^W|' "$_TK_EVENTS" 2>/dev/null || echo 0)
  _TK_UNIQUE=$(grep '^R|' "$_TK_EVENTS" 2>/dev/null | cut -d'|' -f2 | sort -u | wc -l 2>/dev/null || echo 0)
  _TK_UNIQUE="${_TK_UNIQUE## }"
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
  _TK_P_SESS=0 _TK_P_RD=0 _TK_P_WR=0 _TK_P_REP=0 _TK_P_COST=0
  if [[ -f "$_TK_SUMMARY" ]]; then
    _TK_P_SESS=$(grep -o '"total_sessions"[[:space:]]*:[[:space:]]*[0-9]*' "$_TK_SUMMARY" 2>/dev/null | head -1 | grep -o '[0-9]*$' || echo 0)
    _TK_P_RD=$(grep -o '"total_reads"[[:space:]]*:[[:space:]]*[0-9]*' "$_TK_SUMMARY" 2>/dev/null | head -1 | grep -o '[0-9]*$' || echo 0)
    _TK_P_WR=$(grep -o '"total_writes"[[:space:]]*:[[:space:]]*[0-9]*' "$_TK_SUMMARY" 2>/dev/null | head -1 | grep -o '[0-9]*$' || echo 0)
    _TK_P_REP=$(grep -o '"total_repeated_reads"[[:space:]]*:[[:space:]]*[0-9]*' "$_TK_SUMMARY" 2>/dev/null | head -1 | grep -o '[0-9]*$' || echo 0)
    _TK_P_COST=$(grep -o '"total_estimated_cost"[[:space:]]*:[[:space:]]*[0-9]*' "$_TK_SUMMARY" 2>/dev/null | head -1 | grep -o '[0-9]*$' || echo 0)
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

  echo "📊 Session: ${_TK_READS} reads (${_TK_REPEATED} repeated), ${_TK_WRITES} writes, ~${_TK_COST} est. tokens" >&2

  # Clean up events log
  rm -f "$_TK_EVENTS"
fi

# --- Deregister session (F-0195: multi-session collision prevention) ---
AGENTIC_LIB="$PROJECT_ROOT/.agentic/lib"
if [[ -f "$AGENTIC_LIB/tools/agents_helpers.py" ]]; then
  python3 "$AGENTIC_LIB/tools/agents_helpers.py" \
    --project-root "$PROJECT_ROOT" session-deregister "$PROJECT_ROOT" --pid "$PPID" 2>/dev/null || true
fi

# --- Output and exit ---
if [[ "$DECISION" == "deny" ]]; then
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

echo ""
echo "✓ All checks passed. Session ending."
echo ""
exit 0
