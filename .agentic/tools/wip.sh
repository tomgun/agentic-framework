#!/usr/bin/env bash
# wip.sh - Work-In-Progress tracking to prevent loss of work
#
# Prevents work loss when:
# - Token limits reached mid-edit
# - Tool crashes or closes unexpectedly
# - Context compaction happens
# - Switching environments mid-task
# - Computer crashes
#
# Usage:
#   bash .agentic/tools/wip.sh start <feature_id> "<description>" "<files>"
#   bash .agentic/tools/wip.sh start <feature_id> --auto             # Auto-create minimal WIP
#   bash .agentic/tools/wip.sh checkpoint "<progress_note>"
#   bash .agentic/tools/wip.sh complete
#   bash .agentic/tools/wip.sh check
#
# Examples:
#   bash .agentic/tools/wip.sh start F-0005 "User authentication" "src/auth/*.ts,tests/auth/*.test.ts"
#   bash .agentic/tools/wip.sh start exploration --auto              # Auto-created on first edit
#   bash .agentic/tools/wip.sh checkpoint "Login endpoint done, starting JWT"
#   bash .agentic/tools/wip.sh complete
#   bash .agentic/tools/wip.sh check
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${PROJECT_ROOT}"

# State lives at project root, NOT inside .agentic (survives framework upgrades)
STATE_DIR=".agentic-state"
WIP_FILE="${STATE_DIR}/WIP.md"
SESSION_LOG="SESSION_LOG.md"

# Ensure state directory exists
mkdir -p "$STATE_DIR"

COMMAND="${1:-}"

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
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

    # Check if WIP already exists
    if [[ -f "$WIP_FILE" ]]; then
      if [[ "$AUTO_MODE" == "yes" ]]; then
        # Silent exit for auto-mode - WIP already exists
        exit 0
      fi
      echo "⚠️  WIP.md already exists!"
      echo "   Another task may be in progress."
      echo "   Complete it first: bash .agentic/tools/wip.sh complete"
      exit 1
    fi

    # Create minimal WIP.md for auto mode
    if [[ "$AUTO_MODE" == "yes" ]]; then
      cat > "$WIP_FILE" <<EOF
# Work In Progress (Auto-created)

**⚠️ This file tracks active work. If it exists when you return, work was interrupted.**

---

## Current Task

- **Feature**: ${FEATURE_ID}
- **Agent**: ${AGENT}
- **Started**: ${TIMESTAMP}
- **Last checkpoint**: ${TIMESTAMP}

## Success Criteria
<!-- What does "done" look like? Even 2-3 rough bullet points help. -->
-

## Status

Auto-created on first edit. Update with:
\`\`\`bash
bash .agentic/tools/wip.sh checkpoint "Current progress"
\`\`\`

---

**Auto-generated**: \`.agentic/tools/wip.sh start --auto\`
**Remove when**: Task complete (\`wip.sh complete\`)
EOF
      echo "📝 WIP tracking auto-started for ${FEATURE_ID}"
      exit 0
    fi

    # Create full WIP.md for manual mode
    cat > "$WIP_FILE" <<EOF
# Work In Progress (DO NOT EDIT MANUALLY)

**⚠️ This file tracks active work. If it exists when you return, work was interrupted.**

---

## Current Task

- **Feature**: ${FEATURE_ID}: ${DESCRIPTION}
- **Agent**: ${AGENT}
- **Started**: ${TIMESTAMP}
- **Last checkpoint**: ${TIMESTAMP}

## Success Criteria
<!-- What does "done" look like? Even 2-3 rough bullet points help. -->
-

## Task Details

**What I'm doing**:
${DESCRIPTION}

**Files being edited**:
$(echo "$FILES" | tr ',' '\n' | sed 's/^/- /')

## Declared Scope (for scope drift detection)

IN_SCOPE: ${FILES}
OUT_OF_SCOPE: everything else

**Progress**:
- [ ] Task started

---

## If This File Still Exists When You Return

**This means work was interrupted** (token limit, crash, or abrupt close).

**Recovery steps:**
1. Check \`git status\` to see uncommitted changes
2. Check \`git diff\` to review what was changed
3. Check \`${SESSION_LOG}\` for last checkpoint details
4. Decide: **Continue** | **Review changes** | **Rollback** (git reset)

**To check:**
\`\`\`bash
bash .agentic/tools/wip.sh check
\`\`\`

---

**Auto-generated**: \`.agentic/tools/wip.sh\`  
**Remove when**: Task complete and changes committed (\`wip.sh complete\`)
EOF
    
    echo "✓ WIP tracking started for ${FEATURE_ID}"
    echo "  Update frequently: bash .agentic/tools/wip.sh checkpoint \"<progress>\""
    echo "  Complete when done: bash .agentic/tools/wip.sh complete"
    ;;
    
  checkpoint)
    if [[ $# -lt 2 ]]; then
      echo "Usage: wip.sh checkpoint \"<progress_note>\""
      exit 1
    fi
    
    if [[ ! -f "$WIP_FILE" ]]; then
      echo "⚠️  No WIP.md found. Start work first:"
      echo "   bash .agentic/tools/wip.sh start F-#### \"description\" \"files\""
      exit 1
    fi
    
    PROGRESS_NOTE="$2"
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Update last checkpoint timestamp
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s/^- \*\*Last checkpoint\*\*: .*$/- **Last checkpoint**: ${TIMESTAMP}/" "$WIP_FILE"
    else
      sed -i "s/^- \*\*Last checkpoint\*\*: .*$/- **Last checkpoint**: ${TIMESTAMP}/" "$WIP_FILE"
    fi
    
    # Append to progress section
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
    if [[ ! -f "$WIP_FILE" ]]; then
      echo "✓ No WIP.md found (nothing to complete)"
      exit 0
    fi
    
    rm "$WIP_FILE"
    echo "✓ WIP tracking completed and removed"
    echo "  Don't forget to commit your changes!"
    ;;
    
  check)
    if [[ ! -f "$WIP_FILE" ]]; then
      echo "✓ No interrupted work detected"
      exit 0
    fi
    
    echo ""
    echo "⚠️  ═══════════════════════════════════════════════════"
    echo "    INTERRUPTED WORK DETECTED"
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
    
    # Check if stale (>60 min since last checkpoint)
    LAST_CHECKPOINT_TIMESTAMP=$(date -d "$LAST_CHECKPOINT" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$LAST_CHECKPOINT" "+%s" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    MINUTES_SINCE_CHECKPOINT=$(( (NOW - LAST_CHECKPOINT_TIMESTAMP) / 60 ))
    
    if [[ $MINUTES_SINCE_CHECKPOINT -gt 60 ]]; then
      echo "⚠️  STALE WIP (>60 minutes since last checkpoint)"
      echo "   Previous agent may have crashed or stopped abruptly"
      echo ""
    elif [[ $MINUTES_SINCE_CHECKPOINT -lt 5 ]]; then
      echo "✓ Recent checkpoint (${CHECKPOINT_AGO})"
      echo "  This may be an active handoff or recent interruption"
      echo ""
    fi
    
    # Show git status
    if git rev-parse --git-dir > /dev/null 2>&1; then
      echo "Files changed (git status):"
      git status --short | head -10 || echo "  (no changes)"
      echo ""
      
      UNCOMMITTED=$(git status --short | wc -l | xargs)
      if [[ $UNCOMMITTED -gt 0 ]]; then
        echo "Uncommitted changes: ${UNCOMMITTED} files"
        echo ""
      fi
    fi
    
    # Show last checkpoint from SESSION_LOG if exists
    if [[ -f "$SESSION_LOG" ]]; then
      echo "Last checkpoint details (${SESSION_LOG}):"
      tail -20 "$SESSION_LOG" | grep -A2 "##" | tail -3 || echo "  (no recent checkpoints)"
      echo ""
    fi
    
    echo "═══════════════════════════════════════════════════"
    echo "RECOVERY OPTIONS"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "1. CONTINUE WORK (recommended if progress looks good)"
    echo "   - Resume from where previous agent left off"
    echo "   - Keep WIP.md active until complete"
    echo "   - bash .agentic/tools/wip.sh checkpoint \"continuing work\""
    echo ""
    echo "2. REVIEW CHANGES FIRST"
    echo "   - git diff          # Review all changes"
    echo "   - git diff <file>   # Review specific file"
    echo "   - Then decide: continue or rollback"
    echo ""
    echo "3. ROLLBACK TO LAST COMMIT (if changes incomplete/broken)"
    echo "   - git reset --hard  # Nuclear: discard all changes"
    echo "   - git checkout -- <file>  # Discard specific file"
    echo "   - bash .agentic/tools/wip.sh complete  # Remove WIP lock"
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo ""
    
    exit 1  # Non-zero to indicate interrupted work
    ;;
    
  *)
    echo "Usage: bash .agentic/tools/wip.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  start <feature_id> \"<description>\" \"<files>\""
    echo "    Start tracking work on a feature"
    echo "    Example: wip.sh start F-0005 \"User auth\" \"src/auth/*.ts\""
    echo ""
    echo "  checkpoint \"<progress_note>\""
    echo "    Update progress checkpoint (call frequently!)"
    echo "    Example: wip.sh checkpoint \"Login endpoint done\""
    echo ""
    echo "  complete"
    echo "    Mark work as complete and remove WIP lock"
    echo "    Example: wip.sh complete"
    echo ""
    echo "  check"
    echo "    Check for interrupted work at session start"
    echo "    Example: wip.sh check"
    echo ""
    exit 1
    ;;
esac

