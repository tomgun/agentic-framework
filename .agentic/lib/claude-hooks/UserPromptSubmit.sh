#!/usr/bin/env bash
# UserPromptSubmit.sh: Phase-aware verification hook
#
# This hook runs before Claude processes each user prompt.
# It checks for implementation triggers and validates acceptance criteria exist.
#
# Triggered by: Claude Code UserPromptSubmit hook
# Timeout: 3 seconds

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

# --- Phase-aware verification (v0.11.0) ---
# Check if user prompt contains "implement" trigger and warn if no acceptance
USER_PROMPT="${CLAUDE_USER_PROMPT:-}"
if [[ "$USER_PROMPT" =~ [Ii]mplement.*(F-[0-9]{4,}) ]]; then
  FEATURE_ID="${BASH_REMATCH[1]}"
  if [[ ! -f ".agentic/spec/acceptance/${FEATURE_ID}.md" ]]; then
    echo ""
    echo "⚠️  GATE WARNING: No acceptance criteria for ${FEATURE_ID}"
    echo "   Create .agentic/spec/acceptance/${FEATURE_ID}.md before implementing"
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
      RECENT_FIDS=$(git log -5 --format=%s 2>/dev/null | grep -oE 'F-[0-9]{4,}' | sort -u || true)
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

# --- Artifact status check (hooks-first: uses gate.py module calls) ---
# Inject artifact status for active feature into context on every prompt.
ACTIVE_FEATURE=$(PYTHONPATH="$PROJECT_ROOT/.agentic/lib" python3 -m gate resolve --project-root "$PROJECT_ROOT" 2>/dev/null || true)

if [[ -n "$ACTIVE_FEATURE" ]]; then
  # Quick check: does feature have spec + AC?
  ARTIFACT_JSON=$(PYTHONPATH="$PROJECT_ROOT/.agentic/lib" python3 -m gate check-artifacts --feature "$ACTIVE_FEATURE" --project-root "$PROJECT_ROOT" 2>/dev/null || true)
  if [[ -n "$ARTIFACT_JSON" ]]; then
    if command -v jq >/dev/null 2>&1; then
      MISSING=$(echo "$ARTIFACT_JSON" | jq -r '.issues // [] | join("; ")' 2>/dev/null)
    else
      MISSING=$(echo "$ARTIFACT_JSON" | python3 -c "import sys,json; print('; '.join(json.load(sys.stdin).get('issues',[])))" 2>/dev/null || true)
    fi
    if [[ -n "$MISSING" ]]; then
      echo ""
      echo "📋 Active feature $ACTIVE_FEATURE — missing artifacts:"
      echo "   $MISSING"
      echo ""
    fi
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
        PLAN_FID=$(basename "$plan_file" | grep -oE 'F-[0-9]{4,}' | head -1) || true
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

exit 0
