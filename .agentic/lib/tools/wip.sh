#!/usr/bin/env bash
# wip.sh - Work-In-Progress tracking to prevent loss of work
#
# Now writes to AGENTS.json via agents_helpers.py (F-0194).
# Falls back to WIP.md if python3 is unavailable.
#
# Usage:
#   bash .agentic/tools/wip.sh start <feature_id> "<description>" "<files>"
#   bash .agentic/tools/wip.sh start <feature_id> --auto
#   bash .agentic/tools/wip.sh checkpoint "<progress_note>"
#   bash .agentic/tools/wip.sh checkpoint --phase RED|GREEN|REFACTOR "<progress_note>"
#   bash .agentic/tools/wip.sh complete
#   bash .agentic/tools/wip.sh check
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../paths.sh"
source "$SCRIPT_DIR/../settings.sh"
cd "${PROJECT_ROOT}"

# SESSION_DIR, WIP_FILE, AGENTS_JSON provided by paths.sh
STATE_DIR="$SESSION_DIR"
SESSION_LOG="SESSION_LOG.md"

# Ensure state directory exists
mkdir -p "$STATE_DIR"

COMMAND="${1:-}"

# ---------------------------------------------------------------------------
# Python helper (prefers AGENTS.json; falls back to WIP.md if unavailable)
# ---------------------------------------------------------------------------
_has_python() {
  command -v python3 >/dev/null 2>&1
}

_agents_py() {
  python3 "$SCRIPT_DIR/agents_helpers.py" --project-root "$MAIN_PROJECT_ROOT" "$@"
}

# Check if AGENTS.json has an entry for this worktree or feature
_has_agents_entry() {
  _has_python && _agents_py check-worktree "$PROJECT_ROOT" >/dev/null 2>&1
}

# Get current feature from AGENTS.json
_get_agents_feature() {
  _has_python && _agents_py get-current-feature "$PROJECT_ROOT" 2>/dev/null || echo ""
}

# Detect current agent/environment
detect_agent() {
  if [[ -n "${CLAUDE_SESSION:-}" ]] || [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    echo "claude-desktop"
  elif [[ -n "${CURSOR_SESSION:-}" ]] || [[ -d ".cursor" ]]; then
    echo "cursor"
  elif [[ -n "${COPILOT_SESSION:-}" ]] || [[ -d ".github" ]]; then
    echo "copilot"
  else
    echo "unknown"
  fi
}

# Calculate time ago in human-readable format
time_ago() {
  local timestamp="$1"
  local now=$(date +%s)
  local then=$(date -d "$timestamp" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$timestamp" "+%s" 2>/dev/null || echo "0")

  if [[ "$then" == "0" ]]; then
    echo "unknown"
    return
  fi

  local diff=$((now - then))
  local minutes=$((diff / 60))
  local hours=$((minutes / 60))
  local days=$((hours / 24))

  if [[ $minutes -lt 1 ]]; then
    echo "just now"
  elif [[ $minutes -lt 60 ]]; then
    echo "${minutes} minutes ago"
  elif [[ $hours -lt 24 ]]; then
    echo "${hours} hours ago"
  else
    echo "${days} days ago"
  fi
}

case "$COMMAND" in
  start)
    FEATURE_ID="${2:-}"
    AUTO_MODE="no"
    DESCRIPTION=""
    FILES=""

    # Check for --auto flag
    if [[ "${3:-}" == "--auto" ]] || [[ "${2:-}" == "--auto" ]]; then
      AUTO_MODE="yes"
      if [[ "${2:-}" == "--auto" ]]; then
        FEATURE_ID="exploration"
      fi
    elif [[ $# -lt 4 ]]; then
      echo "Usage: wip.sh start <feature_id> \"<description>\" \"<files>\""
      echo "       wip.sh start <feature_id> --auto  # Minimal auto-created WIP"
      exit 1
    else
      DESCRIPTION="$3"
      FILES="$4"
    fi

    AGENT=$(detect_agent)

    # Try AGENTS.json first
    if _has_python; then
      # Check if already active
      if _has_agents_entry; then
        if [[ "$AUTO_MODE" == "yes" ]]; then
          exit 0
        fi
        echo "⚠️  WIP already active!"
        echo "   Another task may be in progress."
        echo "   Complete it first: bash .agentic/lib/tools/wip.sh complete"
        exit 1
      fi

      _agents_py activate "$FEATURE_ID" "${DESCRIPTION:-$FEATURE_ID}" "$FILES" "$AGENT"
      echo "✓ WIP tracking started for ${FEATURE_ID}"
      echo "  Update frequently: bash .agentic/lib/tools/wip.sh checkpoint \"<progress>\""
      echo "  Complete when done: bash .agentic/lib/tools/wip.sh complete"
      exit 0
    fi

    # Fallback: WIP.md (python3 unavailable)
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

    if [[ -f "$WIP_FILE" ]]; then
      if [[ "$AUTO_MODE" == "yes" ]]; then
        exit 0
      fi
      echo "⚠️  WIP.md already exists!"
      echo "   Complete it first: bash .agentic/lib/tools/wip.sh complete"
      exit 1
    fi

    cat > "$WIP_FILE" <<EOF
# Work In Progress

- **Feature**: ${FEATURE_ID}: ${DESCRIPTION}
- **Agent**: ${AGENT}
- **Started**: ${TIMESTAMP}
- **Last checkpoint**: ${TIMESTAMP}

**Progress**:
- [ ] Task started
EOF
    echo "✓ WIP tracking started for ${FEATURE_ID} (WIP.md fallback)"
    ;;

  checkpoint)
    if [[ $# -lt 2 ]]; then
      echo "Usage: wip.sh checkpoint [--phase RED|GREEN|REFACTOR] \"<progress_note>\""
      exit 1
    fi

    PROGRESS_NOTE=""

    # Parse --phase flag (F-0209: TDD phase tracking)
    if [[ "${2:-}" == "--phase" ]]; then
      if [[ $# -lt 4 ]]; then
        echo "Usage: wip.sh checkpoint --phase RED|GREEN|REFACTOR \"<progress_note>\""
        exit 1
      fi
      PHASE=$(echo "$3" | tr '[:lower:]' '[:upper:]')
      case "$PHASE" in
        RED|GREEN|REFACTOR)
          PROGRESS_NOTE="${PHASE}: $4"
          ;;
        *)
          echo "❌ Invalid phase: $3"
          echo "   Valid phases: RED, GREEN, REFACTOR"
          echo "   Usage: wip.sh checkpoint --phase RED|GREEN|REFACTOR \"<progress_note>\""
          exit 1
          ;;
      esac
    else
      PROGRESS_NOTE="$2"
    fi

    # Try AGENTS.json first
    if _has_python; then
      local_feature=$(_get_agents_feature)
      if [[ -n "$local_feature" ]]; then
        _agents_py checkpoint "$local_feature" "$PROGRESS_NOTE"
        echo "✓ WIP checkpoint updated: ${PROGRESS_NOTE}"
        exit 0
      fi
    fi

    # Fallback: WIP.md
    if [[ ! -f "$WIP_FILE" ]]; then
      echo "⚠️  No WIP found. Start work first."
      exit 1
    fi

    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s/^- \*\*Last checkpoint\*\*: .*$/- **Last checkpoint**: ${TIMESTAMP}/" "$WIP_FILE"
    else
      sed -i "s/^- \*\*Last checkpoint\*\*: .*$/- **Last checkpoint**: ${TIMESTAMP}/" "$WIP_FILE"
    fi
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "/^\*\*Progress\*\*:/a\\
- [x] ${PROGRESS_NOTE} (${TIMESTAMP})
" "$WIP_FILE"
    else
      sed -i "/^\*\*Progress\*\*:/a - [x] ${PROGRESS_NOTE} (${TIMESTAMP})" "$WIP_FILE"
    fi
    echo "✓ WIP checkpoint updated: ${PROGRESS_NOTE}"
    ;;

  complete)
    # Try AGENTS.json first
    if _has_python; then
      local_feature=$(_get_agents_feature)
      if [[ -n "$local_feature" ]]; then
        # F-0209: TDD phase gate — validate before deleting entry
        DEV_MODE=$(get_setting "development_mode" "standard")
        if [[ "$DEV_MODE" == "tdd" ]]; then
          # Check SKIP_TDD escape hatch (blocked on main/master)
          if [[ -n "${SKIP_TDD:-}" ]]; then
            BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
            WIP_TRUNK="${AG_TRUNK_BRANCH:-}"
            if [[ -n "$WIP_TRUNK" && "$BRANCH" == "$WIP_TRUNK" ]] \
               || [[ -z "$WIP_TRUNK" && ("$BRANCH" == "main" || "$BRANCH" == "master") ]]; then
              echo "❌ BLOCKED: Cannot use SKIP_TDD on $BRANCH"
              exit 1
            fi
            echo "⚠️  SKIP_TDD set — bypassing TDD phase validation"
          else
            TDD_EXIT=0
            TDD_OUTPUT=$(_agents_py check-tdd-phases 2>&1) || TDD_EXIT=$?
            if [[ $TDD_EXIT -eq 2 ]]; then
              echo "❌ BLOCKED: TDD phase ordering violated"
              echo "   $TDD_OUTPUT"
              echo "   Every GREEN must be preceded by a RED. Use: wip.sh checkpoint --phase RED|GREEN|REFACTOR"
              exit 1
            elif [[ $TDD_EXIT -eq 3 ]]; then
              echo "❌ BLOCKED: TDD mode active but no phase checkpoints recorded"
              echo "   Use: wip.sh checkpoint --phase RED \"test for [behavior] fails\""
              echo "   Then: wip.sh checkpoint --phase GREEN \"[behavior] passes\""
              exit 1
            elif [[ $TDD_EXIT -eq 1 ]]; then
              echo "⚠️  TDD phase check error (proceeding): $TDD_OUTPUT"
            fi
          fi
        fi

        _agents_py complete "$local_feature"
        echo "✓ WIP tracking completed"
        # Also clean up legacy WIP.md if it exists
        [[ -f "$WIP_FILE" ]] && rm "$WIP_FILE"
        exit 0
      fi
    fi

    # Fallback: WIP.md
    if [[ ! -f "$WIP_FILE" ]]; then
      echo "✓ No WIP found (nothing to complete)"
      exit 0
    fi

    rm "$WIP_FILE"
    echo "✓ WIP tracking completed and removed"
    echo "  Don't forget to commit your changes!"
    ;;

  check)
    # Check AGENTS.json first
    if _has_python; then
      local_feature=$(_get_agents_feature)
      if [[ -n "$local_feature" ]]; then
        echo ""
        echo "⚠️  ═══════════════════════════════════════════════════"
        echo "    INTERRUPTED WORK DETECTED"
        echo "    ═══════════════════════════════════════════════════"
        echo ""
        _agents_py list
        echo ""

        # Show git status
        if git rev-parse --git-dir > /dev/null 2>&1; then
          echo "Files changed (git status):"
          git status --short | head -10 || echo "  (no changes)"
          echo ""
        fi

        echo "═══════════════════════════════════════════════════"
        echo "RECOVERY OPTIONS"
        echo "═══════════════════════════════════════════════════"
        echo ""
        echo "1. CONTINUE WORK"
        echo "   - Resume from where previous agent left off"
        echo "   - bash .agentic/lib/tools/wip.sh checkpoint \"continuing work\""
        echo ""
        echo "2. REVIEW CHANGES FIRST"
        echo "   - git diff          # Review all changes"
        echo "   - Then decide: continue or rollback"
        echo ""
        echo "3. CLEAR WIP"
        echo "   - bash .agentic/lib/tools/wip.sh complete"
        echo ""
        echo "═══════════════════════════════════════════════════"
        echo ""
        exit 1
      fi
    fi

    # Fallback: check WIP.md
    if [[ ! -f "$WIP_FILE" ]]; then
      echo "✓ No interrupted work detected"
      exit 0
    fi

    echo ""
    echo "⚠️  ═══════════════════════════════════════════════════"
    echo "    INTERRUPTED WORK DETECTED (legacy WIP.md)"
    echo "    ═══════════════════════════════════════════════════"
    echo ""

    # Extract info from WIP.md
    FEATURE=$(grep "^- \*\*Feature\*\*:" "$WIP_FILE" | cut -d: -f2- | xargs || echo "Unknown")
    AGENT=$(grep "^- \*\*Agent\*\*:" "$WIP_FILE" | cut -d: -f2 | xargs || echo "unknown")
    STARTED=$(grep "^- \*\*Started\*\*:" "$WIP_FILE" | cut -d: -f2- | xargs || echo "unknown")
    LAST_CHECKPOINT=$(grep "^- \*\*Last checkpoint\*\*:" "$WIP_FILE" | cut -d: -f2- | xargs || echo "unknown")

    STARTED_AGO=$(time_ago "$STARTED")
    CHECKPOINT_AGO=$(time_ago "$LAST_CHECKPOINT")

    echo "Feature: ${FEATURE}"
    echo "Started: ${STARTED} (${STARTED_AGO})"
    echo "Last checkpoint: ${LAST_CHECKPOINT} (${CHECKPOINT_AGO})"
    echo "Agent: ${AGENT}"
    echo ""

    # Show git status
    if git rev-parse --git-dir > /dev/null 2>&1; then
      echo "Files changed (git status):"
      git status --short | head -10 || echo "  (no changes)"
      echo ""
    fi

    echo "═══════════════════════════════════════════════════"
    echo "RECOVERY OPTIONS"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "1. CONTINUE WORK"
    echo "   - bash .agentic/lib/tools/wip.sh checkpoint \"continuing work\""
    echo ""
    echo "2. REVIEW CHANGES FIRST"
    echo "   - git diff"
    echo ""
    echo "3. CLEAR WIP"
    echo "   - bash .agentic/lib/tools/wip.sh complete"
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo ""

    exit 1  # Non-zero to indicate interrupted work
    ;;

  *)
    echo "Usage: bash .agentic/lib/tools/wip.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  start <feature_id> \"<description>\" \"<files>\""
    echo "  checkpoint \"<progress_note>\""
    echo "  checkpoint --phase RED|GREEN|REFACTOR \"<progress_note>\""
    echo "  complete"
    echo "  check"
    echo ""
    exit 1
    ;;
esac
