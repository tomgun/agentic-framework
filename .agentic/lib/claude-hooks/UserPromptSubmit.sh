#!/usr/bin/env bash
# UserPromptSubmit.sh: Phase-aware verification hook
#
# This hook runs before Claude processes each user prompt.
# It checks for implementation triggers and validates acceptance criteria exist.
#
# Triggered by: Claude Code UserPromptSubmit hook
# Timeout: 3 seconds

# Bootstrap: ensure lib/ is extracted (inline check avoids fork when lib exists)
[[ -d "${CLAUDE_PROJECT_DIR:-.}/.agentic/lib/tools" ]] || bash "${CLAUDE_PROJECT_DIR:-.}/.agentic/bootstrap.sh" 2>/dev/null || true

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_ROOT"
source "$PROJECT_ROOT/.agentic/lib/paths.sh" 2>/dev/null || true
source "$PROJECT_ROOT/.agentic/lib/tools/fwlog.sh" 2>/dev/null || true
flog "hook:user-prompt-submit" "fire" "" "start"

# --- Stale artifact reminder (commit-relative) ---
# When uncommitted changes exist and JOURNAL/STATUS haven't been updated since
# the last commit, remind the agent. Works correctly in git worktrees.
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  UNCOMMITTED=$(git status --porcelain 2>/dev/null | head -1)
  if [[ -n "$UNCOMMITTED" ]]; then
    LAST_COMMIT_TIME=$(git log -1 --format=%ct 2>/dev/null || echo "")
    if [[ -n "$LAST_COMMIT_TIME" ]] && command -v stat >/dev/null 2>&1; then
      STALE_ARTIFACTS=""

      # Check JOURNAL.md
      JOURNAL_PATH=""
      if [[ -f ".agentic/journal/JOURNAL.md" ]]; then
        JOURNAL_PATH=".agentic/journal/JOURNAL.md"
      elif [[ -f "JOURNAL.md" ]]; then
        JOURNAL_PATH="JOURNAL.md"
      fi
      if [[ -n "$JOURNAL_PATH" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
          JOURNAL_MTIME=$(stat -f %m "$JOURNAL_PATH")
        else
          JOURNAL_MTIME=$(stat -c %Y "$JOURNAL_PATH")
        fi
        if [[ $JOURNAL_MTIME -le $LAST_COMMIT_TIME ]]; then
          STALE_ARTIFACTS="${STALE_ARTIFACTS}JOURNAL.md "
        fi
      fi

      # Check STATUS.md
      if [[ -f "STATUS.md" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
          STATUS_MTIME=$(stat -f %m STATUS.md)
        else
          STATUS_MTIME=$(stat -c %Y STATUS.md)
        fi
        if [[ $STATUS_MTIME -le $LAST_COMMIT_TIME ]]; then
          STALE_ARTIFACTS="${STALE_ARTIFACTS}STATUS.md "
        fi
      fi

      if [[ -n "$STALE_ARTIFACTS" ]]; then
        echo ""
        echo "📋 REMINDER: You have uncommitted changes but ${STALE_ARTIFACTS}not updated since last commit."
        echo "   Update before your next commit:"
        if [[ "$STALE_ARTIFACTS" == *"JOURNAL"* ]]; then
          echo "   bash .agentic/lib/tools/journal.sh \"Topic\" \"Done\" \"Next\" \"Blockers\""
        fi
        if [[ "$STALE_ARTIFACTS" == *"STATUS"* ]]; then
          echo "   bash .agentic/lib/tools/status.sh focus \"Current task\""
        fi
        echo ""
      fi
    fi
  fi
fi

# --- Batch work detection (F-0300 R3) ---
# Warn when user prompt contains batch-work triggers that should use ag auto crunch
# USER_PROMPT is set once here and reused by all subsequent checks
USER_PROMPT="${CLAUDE_USER_PROMPT:-}"
if echo "$USER_PROMPT" | grep -qiE '(churn|batch)\s+(all\s+)?(tasks|features)|build everything|implement (all|everything)|do all (features|tasks)|implement everything|work autonomously.*(game|app|project|system|working)|come back with.*(working|finished|complete|done)|build.*(whole|entire|full)\s+(game|app|project|system)|finish everything|do it all|complete the (project|app|game)|implement the (whole|entire|full)|ship (it all|everything)|create.*(entire|whole|full).*(app|game|project)'; then
  echo ""
  echo "⚠️  BATCH WORK DETECTED: Use \`ag auto crunch\` to process the backlog."
  echo "   The ag auto pipeline ensures each feature gets specs, plans, tests, and docs."
  echo "   NEVER write code for multiple features via direct Write/Edit calls."
  echo ""
fi

# --- Idea/todo capture nudge (Change 10) ---
# When user prompt contains idea/todo keywords, suggest ag todo for capture.
if echo "$USER_PROMPT" | grep -qiE '^(idea|remember|todo|note|we should|later we|maybe we)\b'; then
  echo ""
  _SAFE_PROMPT=$(printf '%s' "${USER_PROMPT:0:60}" | tr '`$"' "...")
  echo "💡 Quick capture: \`ag todo \"${_SAFE_PROMPT}...\"\`"
  echo ""
fi

# --- Kickoff suggestion for whole-project requests (Change 13) ---
# When user wants to build an entire app/system AND no features exist yet
if echo "$USER_PROMPT" | grep -qiE '(build|create|make).*(entire|whole|full|complete)\s+(app|game|project|system|platform)'; then
  if [[ -f ".agentic/spec/FEATURES.md" ]]; then
    _FEAT_EXISTS=$(grep -c "^## F-" ".agentic/spec/FEATURES.md" 2>/dev/null || echo 0)
    _FEAT_EXISTS="${_FEAT_EXISTS## }"
  else
    _FEAT_EXISTS=0
  fi
  if [[ "${_FEAT_EXISTS:-0}" -eq 0 ]]; then
    echo ""
    _SAFE_VISION=$(printf '%s' "${USER_PROMPT:0:50}" | tr '`$"' "...")
    echo "🚀 NEW PROJECT: Use \`ag kickoff \"${_SAFE_VISION}...\"\` to generate"
    echo "   features, specs, and backlog from your vision. Then \`ag auto crunch\` to build."
    echo ""
  fi
fi

# --- Autonomous work pattern detection (F-0300 R2) ---
# Warn when prompt mentions implementing multiple features directly
MULTI_FEATURE_COUNT=$(echo "$USER_PROMPT" | grep -oE "$FEATURE_ID_ERE" | sort -u | wc -l | tr -d ' ')
if [[ "$MULTI_FEATURE_COUNT" -gt 1 ]] && echo "$USER_PROMPT" | grep -qiE '(implement|build|write|code|create)'; then
  echo ""
  echo "⚠️  Multiple features referenced ($MULTI_FEATURE_COUNT). Implement one at a time."
  echo "   Use \`ag auto crunch\` for batch processing with full enforcement."
  echo ""
fi

# --- Phase-aware verification (v0.11.0) ---
# Check if user prompt contains "implement" trigger and warn if no acceptance
if [[ "$USER_PROMPT" =~ [Ii]mplement.*($FEATURE_ID_ERE) ]]; then
  FEATURE_ID="${BASH_REMATCH[1]}"
  if [[ ! -f ".agentic/spec/contracts/${FEATURE_ID}.yaml" ]] && [[ ! -f ".agentic/spec/acceptance/${FEATURE_ID}.md" ]]; then
    echo ""
    echo "⚠️  GATE WARNING: No contract/acceptance criteria for ${FEATURE_ID}"
    echo "   Create .agentic/spec/contracts/${FEATURE_ID}.yaml before implementing"
    echo "   Run: doctor.sh --phase planning ${FEATURE_ID}"
    echo ""
  fi
fi

# --- Multi-session collision warning (F-0195) ---
# Advisory: injects warning into model context when other sessions are active.
# Uses prompt-check (combined count-others + heartbeat) for single Python startup.
# $PPID is stable across hook invocations (wrappers use exec bash).
AGENTIC_LIB="$PROJECT_ROOT/.agentic/lib"
if [[ -f "$AGENTIC_LIB/tools/agents_helpers.py" ]]; then
  OTHERS=$(python3 "$AGENTIC_LIB/tools/agents_helpers.py" \
    --project-root "$PROJECT_ROOT" prompt-check "$PROJECT_ROOT" --pid "$PPID" 2>/dev/null || echo "0")
  if [[ "$OTHERS" -gt 0 ]]; then
    echo ""
    echo "⚠️ COLLISION RISK: $OTHERS other session(s) active on this checkout."
    echo "FORBIDDEN: git stash, git checkout ., git restore ., git reset --hard, git clean -f"
    echo "SAFE alternatives: commit first, use a worktree (ag worktree), or ask human."
    echo ""
  fi
fi

# --- Detection #5: Merged but not done (F-0239) ---
# On main/master, extract F-XXXX IDs from last 5 commits. If any are in FEATURES.md
# but not shipped, warn. Catches bypassed `ag merge` (e.g. raw `gh pr merge`).
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
  if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]]; then
    FEATURES_FILE=""
    if [[ -f ".agentic/spec/FEATURES.md" ]]; then
      FEATURES_FILE=".agentic/spec/FEATURES.md"
    fi
    if [[ -n "$FEATURES_FILE" ]]; then
      # Extract F-XXXX from last 5 commit messages (catches squash merges)
      RECENT_FIDS=$(git log -5 --format=%s 2>/dev/null | grep -oE "$FEATURE_ID_ERE" | sort -u || true)
      if [[ -n "$RECENT_FIDS" ]]; then
        UNSHIPPED=""
        for fid in $RECENT_FIDS; do
          # Check if feature exists in FEATURES.md but is NOT shipped
          if grep -q "$fid" "$FEATURES_FILE" 2>/dev/null; then
            if ! grep "$fid" "$FEATURES_FILE" 2>/dev/null | grep -qi 'shipped'; then
              UNSHIPPED="${UNSHIPPED}${fid} "
            fi
          fi
        done
        if [[ -n "$UNSHIPPED" ]]; then
          echo ""
          echo "⚠️  MERGED BUT NOT DONE: ${UNSHIPPED}"
          echo "   These features appear in recent commits but aren't marked shipped."
          echo "   Run: ag done F-XXXX — handles dogfood, VERSION, backlog, flush."
          echo ""
        fi
      fi
    fi
  fi
fi

# --- Verification reminder (F-0300 R6) ---
# When user says "done/finished/complete" with a feature reference, check for verification
if echo "$USER_PROMPT" | grep -qiE '(done|finished|complete|ship)\b'; then
  # Try to extract feature ID from prompt
  DONE_FEATURE=$(echo "$USER_PROMPT" | grep -oE "$FEATURE_ID_ERE" | head -1) || true
  if [[ -n "$DONE_FEATURE" ]]; then
    if [[ ! -f ".agentic/work/$DONE_FEATURE/verification.json" ]]; then
      echo ""
      echo "⚠️  No verification record for $DONE_FEATURE."
      echo "   Run \`ag verify $DONE_FEATURE\` before marking as done."
      echo ""
    fi
  fi
fi

# --- Consolidated prompt context (Change 3: single Python call) ---
# Replaces separate gate resolve + check-artifacts calls. Saves ~600ms of Python cold starts.
# Returns JSON: {"feature": "F-XXXX", "issues": [...], "cerebrum": [...]}
PROMPT_CTX=$(PYTHONPATH="$PROJECT_ROOT/.agentic/lib" python3 -m gate prompt-context --project-root "$PROJECT_ROOT" 2>/dev/null || true)

ACTIVE_FEATURE=""
if [[ -n "$PROMPT_CTX" ]]; then
  if command -v jq >/dev/null 2>&1; then
    ACTIVE_FEATURE=$(echo "$PROMPT_CTX" | jq -r '.feature // ""' 2>/dev/null)
    MISSING=$(echo "$PROMPT_CTX" | jq -r '.issues // [] | join("; ")' 2>/dev/null)
  else
    ACTIVE_FEATURE=$(echo "$PROMPT_CTX" | python3 -c "import sys,json; print(json.load(sys.stdin).get('feature',''))" 2>/dev/null || true)
    MISSING=$(echo "$PROMPT_CTX" | python3 -c "import sys,json; print('; '.join(json.load(sys.stdin).get('issues',[])))" 2>/dev/null || true)
  fi
  if [[ -n "$MISSING" && -n "$ACTIVE_FEATURE" ]]; then
    echo ""
    echo "📋 Active feature $ACTIVE_FEATURE — missing artifacts:"
    echo "   $MISSING"
    echo ""
  fi
fi

# --- Change 12: Review checkpoint visibility ---
# When active feature has been in implementing state for a while, nudge about
# committing progress. One-time nudge tracked via token-events write count.
if [[ -n "$ACTIVE_FEATURE" && -f ".agentic/session/token-events.log" ]]; then
  _IMPL_WRITE_COUNT=$(grep -c '^W|' ".agentic/session/token-events.log" 2>/dev/null || echo 0)
  _IMPL_WRITE_COUNT="${_IMPL_WRITE_COUNT%%[!0-9]*}"; _IMPL_WRITE_COUNT="${_IMPL_WRITE_COUNT:-0}"
  if [[ "$_IMPL_WRITE_COUNT" -ge 15 && ! -f ".agentic/session/.commit_nudge_fired" ]]; then
    echo ""
    echo "💾 You've made ${_IMPL_WRITE_COUNT}+ edits. Consider saving progress:"
    echo "   \`ag commit\` — pre-commit gates, diff review, PR creation"
    echo "   \`ag verify $ACTIVE_FEATURE\` — run contract assertions"
    echo ""
    touch ".agentic/session/.commit_nudge_fired" 2>/dev/null || true
  fi
fi

# --- DRAFT plan detection (Layer 2 enforcement) ---
# If plan_review_enabled and any DRAFT plan exists in journal/plans/, warn on every prompt.
# Independent of WIP state — detects "any DRAFT plan" not "active feature."
if [[ -d ".agentic/journal/plans" ]]; then
  source "$PROJECT_ROOT/.agentic/lib/settings.sh" 2>/dev/null || true
  PLAN_REVIEW=$(get_setting "plan_review_enabled" "no" 2>/dev/null || echo "no")
  if [[ "$PLAN_REVIEW" == "yes" ]]; then
    DRAFT_PLANS=""
    for plan_file in .agentic/journal/plans/*-plan.md; do
      [[ -f "$plan_file" ]] || continue
      if grep -q '^\*\*Status\*\*.*DRAFT' "$plan_file" 2>/dev/null || \
         grep -q '^Status:.*DRAFT' "$plan_file" 2>/dev/null; then
        PLAN_FID=$(basename "$plan_file" | grep -oE "$FEATURE_ID_ERE" | head -1) || true
        DRAFT_PLANS="${DRAFT_PLANS}${PLAN_FID:-unknown} "
      fi
    done
    if [[ -n "$DRAFT_PLANS" ]]; then
      echo ""
      echo "⚠️  DRAFT PLAN EXISTS: ${DRAFT_PLANS}"
      echo "   Run convergence loop before writing ANY code:"
      echo "   Spawn Critic + Advocate → synthesize → revise if needed → loop until converged."
      echo "   Do NOT start implementing until plan status is APPROVED."
      echo ""
    fi
  fi
fi

# --- Doc freshness nudge (enhanced from F-042 capability catalog) ---
# Broader check: tracks impl writes vs doc writes. Fires once at 3+ impl writes.
# Mentions ALL relevant docs (not just FEATURES.md/OVERVIEW.md).
if [[ ! -f ".agentic/session/.cap_nudged" && ! -f ".agentic/session/.cap_updated" ]]; then
  _TK_EVENTS=".agentic/session/token-events.log"
  if [[ -f "$_TK_EVENTS" ]]; then
    _IMPL_WRITES=$(grep '^W|' "$_TK_EVENTS" 2>/dev/null \
      | grep -cE '\|(src/|lib/|app/|cmd/|\.agentic/lib/tools/|\.agentic/lib/auto/)' 2>/dev/null || echo 0)
    _IMPL_WRITES="${_IMPL_WRITES## }"
    _DOC_WRITES=$(grep '^W|' "$_TK_EVENTS" 2>/dev/null \
      | grep -cE '\|.*\.(md|rst)' 2>/dev/null || echo 0)
    _DOC_WRITES="${_DOC_WRITES## }"
    if [[ "${_IMPL_WRITES:-0}" -ge 3 && "${_DOC_WRITES:-0}" -eq 0 ]]; then
      _CAP_DOC="OVERVIEW.md"
      [[ -f ".agentic/spec/FEATURES.md" ]] && _CAP_DOC=".agentic/spec/FEATURES.md"
      echo ""
      echo "📦 DOC FRESHNESS: ${_IMPL_WRITES} implementation files written, 0 docs updated."
      echo "   Update relevant docs (${_CAP_DOC}, README, API docs) before committing."
      echo "   Run: bash .agentic/lib/tools/docs.sh --check-freshness"
      echo ""
      touch ".agentic/session/.cap_nudged" 2>/dev/null || true
    fi
  fi
fi

exit 0
