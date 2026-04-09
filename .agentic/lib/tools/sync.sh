#!/usr/bin/env bash
# sync.sh — Unified framework sync: detect drift across ALL artifacts, auto-fix safe errors
#
# Usage:
#   bash .agentic/tools/sync.sh              # Full sync: all phases, auto-fix safe things
#   bash .agentic/tools/sync.sh --check      # Dry run: detect only, no auto-fixes
#   bash .agentic/tools/sync.sh --quiet      # One-line summary (for ag start probe)
#
# Ten check phases:
#   1. Memory seed integrity
#   2. State freshness (journal, STATUS, CHANGELOG)
#   3. Feature reconciliation (Formal only)
#   3b. Unregistered shipped code detection (feature_tracking only)
#   4. Spec/doc drift (skipped in --quiet)
#   5. Tool parity (instruction files + trigger tables)
#   6. Git hook configuration
#   7. Periodic checks (orphaned plans, retro, agent freshness)
#   8. PR cleanup (auto-resolve merged/closed PRs in HUMAN_NEEDED.md)
#   9. Plan durability (scan ephemeral plan dirs, copy unsaved plans)
#  9b. Plan-to-phases drift (plan revised after tasks.yaml created)
#  10. Intent reconciliation (adopt orphans, resume pending)
#
# Exit code: always 0 (advisory tool).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Colors (disabled if not TTY)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' DIM='' NC=''
fi

# --- Parse flags ---
MODE="full"
for arg in "$@"; do
    case "$arg" in
        --check) MODE="check" ;;
        --quiet) MODE="quiet" ;;
        -h|--help)
            echo "Usage: bash .agentic/tools/sync.sh [--check|--quiet]"
            echo ""
            echo "  (no flags)  Full sync: detect issues, auto-fix safe ones"
            echo "  --check     Dry run: detect only, no auto-fixes"
            echo "  --quiet     One-line summary (for ag start probe)"
            exit 0
            ;;
    esac
done

# --- Source shared settings ---
source "$SCRIPT_DIR/../paths.sh"
source "$SCRIPT_DIR/../settings.sh"
PROFILE="$(get_setting "profile" "discovery")"

# --- Counters ---
OK_COUNT=0
FIXED_COUNT=0
ISSUE_COUNT=0
ISSUE_SUMMARY=()

record_ok() {
    ((OK_COUNT++))
}

record_fixed() {
    ((FIXED_COUNT++))
}

record_issue() {
    local desc="$1"
    ((ISSUE_COUNT++))
    ISSUE_SUMMARY+=("$desc")
}

# ============================================================================
# Phase 1: Memory seed integrity
# ============================================================================
phase_memory() {
    local output
    output=$(bash "$SCRIPT_DIR/memory-check.sh" --quiet 2>&1 || true)

    if [ -z "$output" ]; then
        # --quiet mode: no output means OK
        record_ok
        if [ "$MODE" != "quiet" ]; then
            echo -e "Memory:     ${GREEN}OK${NC}"
        fi
    elif echo "$output" | grep -q "OK"; then
        record_ok
        if [ "$MODE" != "quiet" ]; then
            echo -e "Memory:     ${GREEN}$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^Memory: //')${NC}"
        fi
    elif echo "$output" | grep -q "skipped"; then
        record_ok
        if [ "$MODE" != "quiet" ]; then
            echo -e "Memory:     ${DIM}skipped (non-Claude environment)${NC}"
        fi
    else
        record_issue "memory stale"
        if [ "$MODE" != "quiet" ]; then
            # Strip ANSI codes and reformat
            local clean
            clean=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
            local version_info
            version_info=$(echo "$clean" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+ vs seed v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            if [ -z "$version_info" ]; then
                version_info=$(echo "$clean" | grep -oE '(not seeded|partially overwritten)[^)]*' | head -1)
            fi
            version_info="${version_info:-needs attention}"
            echo -e "Memory:     ${YELLOW}STALE ($version_info)${NC}"
            echo -e "            Re-read .agentic/init/memory-seed.md and write patterns to memory"
        fi
    fi
}

# ============================================================================
# Phase 2: State freshness (Journal, STATUS, CHANGELOG)
# ============================================================================
phase_state_freshness() {
    # --- JOURNAL.md ---
    local journal_file=""
    if [ -f "$ROOT_DIR/.agentic/journal/JOURNAL.md" ]; then
        journal_file="$ROOT_DIR/.agentic/journal/JOURNAL.md"
    elif [ -f "$ROOT_DIR/JOURNAL.md" ]; then
        journal_file="$ROOT_DIR/JOURNAL.md"
    fi

    if [ -n "$journal_file" ]; then
        local last_date
        last_date=$(grep -oE '### Session: [0-9]{4}-[0-9]{2}-[0-9]{2}' "$journal_file" 2>/dev/null | tail -1 | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' || echo "")

        if [ -n "$last_date" ]; then
            local commits_since
            commits_since=$(git log --oneline --since="$last_date" 2>/dev/null | wc -l | tr -d ' ')

            if [ "$commits_since" -ge 3 ]; then
                record_issue "journal stale"
                if [ "$MODE" != "quiet" ]; then
                    echo -e "Journal:    ${YELLOW}STALE (last entry $last_date, $commits_since commits since)${NC}"
                    echo -e "            Fix: bash .agentic/tools/journal.sh \"Topic\" \"Done\" \"Next\" \"Blockers\""
                fi
            else
                record_ok
                if [ "$MODE" != "quiet" ]; then
                    echo -e "Journal:    ${GREEN}OK (last entry $last_date)${NC}"
                fi
            fi
        else
            record_issue "journal empty"
            if [ "$MODE" != "quiet" ]; then
                echo -e "Journal:    ${YELLOW}EMPTY (no session entries found)${NC}"
            fi
        fi
    else
        record_ok
        if [ "$MODE" != "quiet" ]; then
            echo -e "Journal:    ${DIM}skipped (no JOURNAL.md)${NC}"
        fi
    fi

    # --- STATUS.md ---
    if [ -f "$ROOT_DIR/STATUS.md" ]; then
        local status_updated
        status_updated=$(grep -oE '\(Updated: [0-9]{4}-[0-9]{2}-[0-9]{2}' "$ROOT_DIR/STATUS.md" 2>/dev/null | tail -1 | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' || echo "")

        local commits_since_status=0
        if [ -n "$status_updated" ]; then
            commits_since_status=$(git log --oneline --since="$status_updated" 2>/dev/null | wc -l | tr -d ' ')
        else
            # No updated timestamp — count from file mtime
            local since_date=""
            if [ "$(uname)" = "Darwin" ]; then
                local mtime
                mtime=$(stat -f %m "$ROOT_DIR/STATUS.md" 2>/dev/null || echo "0")
                if [ "$mtime" != "0" ]; then
                    since_date=$(date -r "$mtime" "+%Y-%m-%d" 2>/dev/null || echo "")
                fi
            else
                since_date=$(date -d "$(stat -c %Y "$ROOT_DIR/STATUS.md" 2>/dev/null || echo 0)" "+%Y-%m-%d" 2>/dev/null || echo "")
            fi
            if [ -n "$since_date" ]; then
                commits_since_status=$(git log --oneline --since="$since_date" 2>/dev/null | wc -l | tr -d ' ')
            fi
        fi

        if [ "$commits_since_status" -ge 5 ]; then
            if [ "$MODE" = "full" ]; then
                # Auto-fix: run status.sh infer --apply
                bash "$SCRIPT_DIR/status.sh" infer --apply >/dev/null 2>&1 || true
                record_fixed
                if [ "$MODE" != "quiet" ]; then
                    echo -e "STATUS.md:  ${GREEN}FIXED (auto-applied inferred state)${NC}"
                fi
            else
                record_issue "STATUS.md stale"
                if [ "$MODE" != "quiet" ]; then
                    echo -e "STATUS.md:  ${YELLOW}STALE ($commits_since_status commits since last update)${NC}"
                    echo -e "            Fix: bash .agentic/tools/status.sh infer --apply"
                fi
            fi
        else
            record_ok
            if [ "$MODE" != "quiet" ]; then
                echo -e "STATUS.md:  ${GREEN}OK${NC}"
            fi
        fi
    else
        record_issue "STATUS.md missing"
        if [ "$MODE" != "quiet" ]; then
            echo -e "STATUS.md:  ${YELLOW}MISSING${NC}"
        fi
    fi

    # --- CHANGELOG.md vs VERSION ---
    if [ -f "$ROOT_DIR/CHANGELOG.md" ] && [ -f "$ROOT_DIR/VERSION" ]; then
        local version_file
        version_file=$(head -1 "$ROOT_DIR/VERSION" | tr -d '[:space:]')
        local changelog_version
        changelog_version=$(grep -oE '## \[[0-9]+\.[0-9]+\.[0-9]+\]' "$ROOT_DIR/CHANGELOG.md" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "")

        if [ -n "$version_file" ] && [ -n "$changelog_version" ]; then
            if [ "$version_file" = "$changelog_version" ]; then
                record_ok
                if [ "$MODE" != "quiet" ]; then
                    echo -e "CHANGELOG:  ${GREEN}OK (v$changelog_version matches VERSION)${NC}"
                fi
            else
                record_issue "CHANGELOG version mismatch"
                if [ "$MODE" != "quiet" ]; then
                    echo -e "CHANGELOG:  ${YELLOW}MISMATCH (CHANGELOG v$changelog_version vs VERSION v$version_file)${NC}"
                    echo -e "            Fix: Update CHANGELOG.md with v$version_file entry"
                fi
            fi
        else
            record_ok
            if [ "$MODE" != "quiet" ]; then
                echo -e "CHANGELOG:  ${GREEN}OK${NC}"
            fi
        fi
    else
        record_ok
        if [ "$MODE" != "quiet" ]; then
            echo -e "CHANGELOG:  ${DIM}skipped (no CHANGELOG.md or VERSION)${NC}"
        fi
    fi

    # --- CONTEXT_PACK.md placeholder detection + staleness ---
    local ctx_pack="$ROOT_DIR/CONTEXT_PACK.md"
    if [ -f "$ctx_pack" ]; then
        local placeholder_count
        placeholder_count=$(grep -cE '<!-- (1|fill|bullets|e\.g\.|path )' "$ctx_pack" 2>/dev/null || true)
        placeholder_count="${placeholder_count:-0}"

        if [ "$placeholder_count" -ge 3 ]; then
            record_issue "CONTEXT_PACK.md has template placeholders"
            if [ "$MODE" != "quiet" ]; then
                echo -e "CONTEXT_PACK: ${YELLOW}STALE ($placeholder_count template placeholders still present)${NC}"
                echo -e "            Fix: Replace <!-- fill ... --> placeholders with real project content"
            fi
        else
            # Check commit-age staleness (advisory, every 15 commits)
            local ctx_commits_since=0
            local ctx_last_date
            ctx_last_date=$(git log -1 --format="%ci" -- "$ctx_pack" 2>/dev/null | cut -d' ' -f1 || echo "")
            if [ -n "$ctx_last_date" ]; then
                ctx_commits_since=$(git log --oneline --since="$ctx_last_date" 2>/dev/null | wc -l | tr -d ' ')
            fi
            if [ "$ctx_commits_since" -ge 15 ]; then
                record_issue "CONTEXT_PACK.md stale"
                if [ "$MODE" != "quiet" ]; then
                    echo -e "CONTEXT_PACK: ${YELLOW}STALE ($ctx_commits_since commits since last update)${NC}"
                    echo -e "            Review and update if architecture has changed"
                fi
            else
                record_ok
                if [ "$MODE" != "quiet" ]; then
                    echo -e "CONTEXT_PACK: ${GREEN}OK${NC}"
                fi
            fi
        fi
    else
        record_ok
        if [ "$MODE" != "quiet" ]; then
            echo -e "CONTEXT_PACK: ${DIM}skipped (no CONTEXT_PACK.md)${NC}"
        fi
    fi

    # --- OVERVIEW.md placeholder + staleness detection ---
    local overview_file=""
    if [ -f "$ROOT_DIR/spec/OVERVIEW.md" ]; then
        overview_file="$ROOT_DIR/spec/OVERVIEW.md"
    elif [ -f "$ROOT_DIR/OVERVIEW.md" ]; then
        overview_file="$ROOT_DIR/OVERVIEW.md"
    fi

    if [ -n "$overview_file" ]; then
        local overview_placeholders
        overview_placeholders=$(grep -cE '<!-- (fill|1-2|e\.g\.)' "$overview_file" 2>/dev/null || true)
        overview_placeholders="${overview_placeholders:-0}"

        if [ "$overview_placeholders" -ge 3 ]; then
            record_issue "OVERVIEW.md has template placeholders"
            if [ "$MODE" != "quiet" ]; then
                echo -e "OVERVIEW:   ${YELLOW}STALE ($overview_placeholders template placeholders — never filled in)${NC}"
                echo -e "            Fix: Replace placeholders with real project vision and goals"
            fi
        else
            # Check commit-age staleness (advisory, every 15 commits)
            local ov_commits_since=0
            local ov_last_date
            ov_last_date=$(git log -1 --format="%ci" -- "$overview_file" 2>/dev/null | cut -d' ' -f1 || echo "")
            if [ -n "$ov_last_date" ]; then
                ov_commits_since=$(git log --oneline --since="$ov_last_date" 2>/dev/null | wc -l | tr -d ' ')
            fi
            if [ "$ov_commits_since" -ge 15 ]; then
                record_issue "OVERVIEW.md stale"
                if [ "$MODE" != "quiet" ]; then
                    echo -e "OVERVIEW:   ${YELLOW}STALE ($ov_commits_since commits since last update)${NC}"
                    echo -e "            Review and update if project vision has evolved"
                fi
            else
                record_ok
                if [ "$MODE" != "quiet" ]; then
                    echo -e "OVERVIEW:   ${GREEN}OK${NC}"
                fi
            fi
        fi
    else
        record_ok
        if [ "$MODE" != "quiet" ]; then
            echo -e "OVERVIEW:   ${DIM}skipped (no OVERVIEW.md)${NC}"
        fi
    fi

    # --- Advisory doc staleness (ported from stale.sh) ---
    # Checks spec docs not covered above. Advisory only, 15-commit threshold.
    # Note: counts all commits (including state-file updates), not just code commits.
    local advisory_docs=(".agentic/spec/FEATURES.md" "spec/TECH_SPEC.md" ".agentic/spec/NFR.md")
    local advisory_stale=0

    for i in "${!advisory_docs[@]}"; do
        local adoc="$ROOT_DIR/${advisory_docs[$i]}"
        if [ -f "$adoc" ]; then
            local adoc_commits=0
            local adoc_date
            adoc_date=$(git log -1 --format="%ci" -- "$adoc" 2>/dev/null | cut -d' ' -f1 || echo "")
            if [ -n "$adoc_date" ]; then
                adoc_commits=$(git log --oneline --since="$adoc_date" 2>/dev/null | wc -l | tr -d ' ')
            fi
            if [ "$adoc_commits" -ge 15 ]; then
                ((advisory_stale++))
                if [ "$MODE" != "quiet" ]; then
                    if [ "$advisory_stale" -eq 1 ]; then
                        echo -e "Spec docs:  ${YELLOW}some stale${NC}"
                    fi
                    echo -e "            ${advisory_docs[$i]}: $adoc_commits commits since last update"
                fi
            fi
        fi
    done

    if [ "$advisory_stale" -gt 0 ]; then
        record_issue "$advisory_stale spec doc(s) stale"
    elif [ "$MODE" != "quiet" ]; then
        # Only show OK if any spec docs exist
        local any_spec_doc=false
        for adoc_path in "${advisory_docs[@]}"; do
            [ -f "$ROOT_DIR/$adoc_path" ] && any_spec_doc=true && break
        done
        if [ "$any_spec_doc" = true ]; then
            record_ok
            echo -e "Spec docs:  ${GREEN}OK${NC}"
        fi
    fi
}

# ============================================================================
# Phase 3: Feature reconciliation (Formal only)
# ============================================================================
phase_features() {
    local ft
    ft="$(get_setting "feature_tracking" "no")"
    if [ "$ft" != "yes" ]; then
        return 0
    fi

    local features_file="$ROOT_DIR/.agentic/spec/FEATURES.md"
    if [ ! -f "$features_file" ]; then
        return 0
    fi

    local feature_issues=0

    # Check in_progress features with no recent commits
    local in_progress_features
    in_progress_features=$(grep -B1 -i "status:.*in_progress" "$features_file" 2>/dev/null | grep -oE "F-[0-9]+" || true)

    for fid in $in_progress_features; do
        local days_since_commit
        days_since_commit=$(git log --oneline --since="14 days ago" --grep="$fid" 2>/dev/null | wc -l | tr -d ' ')

        # Also check WIP.md
        local in_wip=false
        if [ -f "$ROOT_DIR/.agentic/session/WIP.md" ] && grep -q "$fid" "$ROOT_DIR/.agentic/session/WIP.md" 2>/dev/null; then
            in_wip=true
        fi

        if [ "$days_since_commit" -eq 0 ] && [ "$in_wip" = false ]; then
            record_issue "$fid stale"
            ((feature_issues++))
            if [ "$MODE" != "quiet" ]; then
                if [ "$feature_issues" -eq 1 ]; then
                    echo -e "Features:   ${YELLOW}issues found${NC}"
                fi
                echo -e "            $fid: in_progress, no commits in 14 days"
                echo -e "            Fix: bash .agentic/tools/feature.sh $fid status shipped"
            fi
        fi
    done

    # Check in_progress features have acceptance criteria
    for fid in $in_progress_features; do
        if [ ! -f "$CONTRACTS_DIR/${fid}.yaml" ] && [ ! -f "$ACCEPTANCE_DIR/${fid}.md" ]; then
            record_issue "$fid no-acceptance"
            ((feature_issues++))
            if [ "$MODE" != "quiet" ]; then
                echo -e "            $fid: in_progress but no contract/acceptance criteria"
                echo -e "            Create: $CONTRACTS_DIR/${fid}.yaml (even rough 2-3 bullet points)"
            fi
        fi
    done

    # Check planned features that have commits (should be in_progress)
    local planned_features
    planned_features=$(grep -B1 -iE "status:.*(planned|pending)" "$features_file" 2>/dev/null | grep -oE "F-[0-9]+" || true)

    local recent_commits
    recent_commits=$(git log --oneline -20 2>/dev/null || true)

    for fid in $planned_features; do
        if echo "$recent_commits" | grep -q "$fid"; then
            record_issue "$fid should be in_progress"
            ((feature_issues++))
            if [ "$MODE" != "quiet" ]; then
                if [ "$feature_issues" -eq 1 ]; then
                    echo -e "Features:   ${YELLOW}issues found${NC}"
                fi
                echo -e "            $fid: planned but has commits → suggest in_progress"
                echo -e "            Fix: bash .agentic/tools/feature.sh $fid status in_progress"
            fi
        fi
    done

    # Check for contract/acceptance files without FEATURES.md entries
    for _sync_dir in "$CONTRACTS_DIR" "$ACCEPTANCE_DIR"; do
    if [ -d "$_sync_dir" ]; then
        for criteria_file in "$_sync_dir"/F-*; do
            [ -f "$criteria_file" ] || continue
            local fid
            fid=$(basename "$criteria_file" | sed 's/\.\(md\|yaml\)$//')
            if ! grep -q "$fid" "$features_file" 2>/dev/null; then
                record_issue "$fid orphaned contract/acceptance"
                ((feature_issues++))
                if [ "$MODE" != "quiet" ]; then
                    if [ "$feature_issues" -eq 1 ]; then
                        echo -e "Features:   ${YELLOW}issues found${NC}"
                    fi
                    echo -e "            $fid: has contract/acceptance file but no FEATURES.md entry"
                fi
            fi
        done
    fi
    done  # end _sync_dir loop

    if [ "$feature_issues" -eq 0 ]; then
        record_ok
        if [ "$MODE" != "quiet" ]; then
            echo -e "Features:   ${GREEN}OK${NC}"
        fi
    fi
}

# ============================================================================
# Phase 3a+: AC drift check (F-0197)
# ============================================================================
phase_drift_check() {
    local ft
    ft="$(get_setting "feature_tracking" "no")"
    if [ "$ft" != "yes" ]; then
        return 0
    fi

    local drift_output
    drift_output=$(bash "$SCRIPT_DIR/drift-check.sh" --quiet 2>/dev/null || true)

    if [ -n "$drift_output" ]; then
        record_issue "ac-drift"
        if [ "$MODE" != "quiet" ]; then
            echo "$drift_output"
        fi
    else
        record_ok
        if [ "$MODE" != "quiet" ]; then
            echo -e "AC Drift:   ${GREEN}OK${NC}"
        fi
    fi
}

# ============================================================================
# Phase 3b: Unregistered shipped code detection
# ============================================================================
phase_unregistered_code() {
    local ft
    ft="$(get_setting "feature_tracking" "no")"
    if [ "$ft" != "yes" ]; then
        return 0
    fi

    # Use last sync date as window (from sync-state.conf)
    local state_file="$ROOT_DIR/.agentic/session/sync-state.conf"
    local since_date=""
    if [ -f "$state_file" ]; then
        since_date=$(grep "^last_sync=" "$state_file" 2>/dev/null | sed 's/^last_sync=//' || echo "")
    fi
    # Fallback: 14 days ago
    if [ -z "$since_date" ]; then
        since_date=$(date -v-14d "+%Y-%m-%d" 2>/dev/null || date -d "14 days ago" "+%Y-%m-%d" 2>/dev/null || echo "")
    fi
    [ -z "$since_date" ] && return 0

    local CODE_EXT_PATTERN='\.(py|js|ts|tsx|jsx|go|rs|rb|java|c|cpp|h|sh|swift|kt)$'
    local SKIP_DIRS='^(tests?/|spec/|docs/|\.agentic/|\.github/|node_modules/)'
    local suspects=()

    while IFS= read -r commit_line; do
        [ -z "$commit_line" ] && continue
        local hash msg
        hash=$(echo "$commit_line" | cut -d' ' -f1)
        msg=$(echo "$commit_line" | cut -d' ' -f2-)

        # Skip if references F-####
        echo "$msg" | grep -qE "$FEATURE_ID_ERE" && continue

        # Skip merge commits
        local parent_count
        parent_count=$(git cat-file -p "$hash" 2>/dev/null | grep -c "^parent " || echo "0")
        [ "$parent_count" -gt 1 ] && continue

        # Count source files (excluding test/doc/config dirs)
        local src_files new_files src_count new_count
        src_files=$(git diff-tree --no-commit-id -r --name-only "$hash" 2>/dev/null | grep -E "$CODE_EXT_PATTERN" | grep -vE "$SKIP_DIRS" || true)
        [ -z "$src_files" ] && continue
        src_count=$(echo "$src_files" | wc -l | tr -d ' ')

        new_files=$(git diff-tree --no-commit-id -r --diff-filter=A --name-only "$hash" 2>/dev/null | grep -E "$CODE_EXT_PATTERN" | grep -vE "$SKIP_DIRS" || true)
        new_count=0
        [ -n "$new_files" ] && new_count=$(echo "$new_files" | wc -l | tr -d ' ')

        # Threshold: 3+ source files AND 1+ new
        if [ "$src_count" -ge 3 ] && [ "$new_count" -ge 1 ]; then
            suspects+=("${hash:0:7} (${src_count} files, ${new_count} new): $msg")
        fi
    done < <(git log --oneline --since="$since_date" --no-merges 2>/dev/null | head -30)

    if [ ${#suspects[@]} -gt 0 ]; then
        local show_count=${#suspects[@]}
        [ "$show_count" -gt 3 ] && show_count=3
        record_issue "${#suspects[@]} possible unregistered feature(s)"
        if [ "$MODE" != "quiet" ]; then
            echo -e "Unregistered: ${YELLOW}${#suspects[@]} commit(s) may be unregistered features${NC}"
            for i in $(seq 0 $((show_count - 1))); do
                echo -e "            ${suspects[$i]}"
            done
            [ "${#suspects[@]}" -gt 3 ] && echo -e "            ... and $((${#suspects[@]} - 3)) more"
            echo -e "            ${DIM}Register with: bash .agentic/tools/feature.sh F-#### ...${NC}"
            echo -e "            ${DIM}If maintenance, ignore this advisory.${NC}"
        fi
    else
        record_ok
        if [ "$MODE" != "quiet" ]; then
            echo -e "Unregistered: ${GREEN}OK (all recent work references features)${NC}"
        fi
    fi
}

# ============================================================================
# Phase 4: Spec/doc drift (skipped in --quiet mode)
# ============================================================================
phase_spec_drift() {
    if [ "$MODE" = "quiet" ]; then
        return 0
    fi

    # Spec drift via drift.sh --check
    local drift_exit=0
    local drift_output
    drift_output=$(bash "$SCRIPT_DIR/drift.sh" --check 2>&1) || drift_exit=$?

    if [ "$drift_exit" -eq 0 ]; then
        record_ok
        echo -e "Spec drift: ${GREEN}OK${NC}"
    else
        local drift_count
        drift_count=$(echo "$drift_output" | grep -oE "Found [0-9]+ drift" | grep -oE "[0-9]+" || echo "?")
        record_issue "spec drift ($drift_count issues)"
        echo -e "Spec drift: ${YELLOW}$drift_count issue(s) detected${NC}"
        echo -e "            Run: bash .agentic/tools/drift.sh for details"
    fi

    # Doc coverage via doc-check.sh
    local doc_exit=0
    local doc_output
    doc_output=$(bash "$SCRIPT_DIR/doc-check.sh" 2>&1) || doc_exit=$?

    if [ "$doc_exit" -eq 0 ]; then
        record_ok
        echo -e "Docs:       ${GREEN}OK${NC}"
    else
        local doc_count
        doc_count=$(echo "$doc_output" | grep -oE "Found [0-9]+ documentation" | grep -oE "[0-9]+" || echo "?")
        record_issue "doc issues"
        echo -e "Docs:       ${YELLOW}issues detected${NC}"
        echo -e "            Run: bash .agentic/tools/doc-check.sh for details"
    fi
}

# ============================================================================
# Phase 4b: Assertion status drift (unshipped assertions in shipped contracts)
# ============================================================================
phase_assertion_status() {
    local contracts_dir
    contracts_dir="${CONTRACTS_DIR:-$SPEC_DIR/contracts}"

    if [[ ! -d "$contracts_dir" ]]; then
        return 0
    fi

    local _assertion_drift
    # stderr suppressed: PyYAML may be absent; phase silently skips.
    _assertion_drift=$(_AG_CONTRACTS_DIR="$contracts_dir" \
        PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
import os
from pathlib import Path
from contracts import load_all_contracts

contracts_dir = Path(os.environ['_AG_CONTRACTS_DIR'])
contracts = load_all_contracts(contracts_dir)

for c in contracts:
    if c.lifecycle not in ('shipped', 'shipping', 'ongoing'):
        continue
    unshipped = c.unshipped_assertions
    if unshipped:
        ids = ', '.join(a.id for a in unshipped)
        print(f'{c.id}: {len(unshipped)} unshipped ({ids})')
" 2>/dev/null)

    if [ -n "$_assertion_drift" ]; then
        local drift_count
        drift_count=$(echo "$_assertion_drift" | wc -l | tr -d ' ')
        record_issue "assertion status drift ($drift_count contracts)"
        if [ "$MODE" != "quiet" ]; then
            echo -e "AC status:  ${YELLOW}$drift_count contract(s) have unshipped assertions${NC}"
            echo "$_assertion_drift" | while IFS= read -r line; do
                echo -e "            ${YELLOW}$line${NC}"
            done
            echo -e "            Run: ${BOLD}ag contract promote <feature-id>${NC}"
        fi
    else
        record_ok
        if [ "$MODE" != "quiet" ]; then
            echo -e "AC status:  ${GREEN}OK${NC}"
        fi
    fi
}

# ============================================================================
# Phase 5: Tool parity (instruction files + trigger tables)
# ============================================================================
phase_tool_parity() {
    # Run check-environment.sh to detect tools
    local env_exit=0
    local env_output
    env_output=$(bash "$SCRIPT_DIR/check-environment.sh" 2>&1) || env_exit=$?

    if [ "$env_exit" -ne 0 ]; then
        # Missing instruction files
        # In the framework repo, root files are manually maintained with
        # framework-dev-specific content. setup-agent.sh would overwrite them
        # with generic templates, so skip auto-fix here.
        local is_framework_repo=false
        [[ -f "$ROOT_DIR/FRAMEWORK_DEVELOPMENT.md" ]] && is_framework_repo=true

        if [ "$MODE" = "full" ] && ! $is_framework_repo; then
            # Auto-fix: create missing files
            bash "$SCRIPT_DIR/check-environment.sh" --fix >/dev/null 2>&1 || true
            record_fixed
            if [ "$MODE" != "quiet" ]; then
                echo -e "Tool files: ${GREEN}FIXED (created missing instruction files)${NC}"
            fi
        else
            record_issue "missing tool files"
            if [ "$MODE" != "quiet" ]; then
                echo -e "Tool files: ${YELLOW}MISSING instruction files${NC}"
                echo -e "            Fix: bash .agentic/tools/check-environment.sh --fix"
            fi
        fi
    else
        # Files exist — check for trigger table content
        local trigger_missing=0
        local instruction_files=("$ROOT_DIR/CLAUDE.md" "$ROOT_DIR/.cursorrules" "$ROOT_DIR/.github/copilot-instructions.md" "$ROOT_DIR/.codex/instructions.md")

        for ifile in "${instruction_files[@]}"; do
            if [ -f "$ifile" ] && ! grep -q "User intent" "$ifile" 2>/dev/null; then
                ((trigger_missing++))
                if [ "$MODE" != "quiet" ]; then
                    local basename
                    basename=$(basename "$ifile")
                    echo -e "            ${YELLOW}$basename: missing trigger table${NC}"
                    echo -e "            Fix: bash .agentic/tools/setup-agent.sh $(echo "$basename" | sed 's/CLAUDE\.md/claude/; s/\.cursorrules/cursor/; s/copilot-instructions\.md/copilot/; s/instructions\.md/codex/')"
                fi
            fi
        done

        # Check Cursor v0.47+ artifacts (.cursor/rules/, hooks.json, skills/) if Cursor is set up
        if [[ -f "$ROOT_DIR/.cursorrules" ]]; then
            local cursor_artifacts_missing=0
            [[ ! -d "$ROOT_DIR/.cursor/rules" ]] && ((cursor_artifacts_missing++))
            [[ ! -f "$ROOT_DIR/.cursor/hooks.json" ]] && ((cursor_artifacts_missing++))
            [[ ! -d "$ROOT_DIR/.cursor/skills" ]] && ((cursor_artifacts_missing++))
            if [[ $cursor_artifacts_missing -gt 0 ]]; then
                ((trigger_missing++))
                if [ "$MODE" != "quiet" ]; then
                    echo -e "            ${YELLOW}.cursor/ artifacts incomplete (rules/hooks/skills missing)${NC}"
                    echo -e "            Fix: bash .agentic/tools/setup-agent.sh cursor"
                fi
            fi
        fi

        if [ "$trigger_missing" -gt 0 ]; then
            record_issue "$trigger_missing tool files missing trigger tables"
        else
            record_ok
            if [ "$MODE" != "quiet" ]; then
                echo -e "Tool files: ${GREEN}OK${NC}"
            fi
        fi
    fi
}

# ============================================================================
# Phase 5b: Instruction sync (framework-dev advisory)
# ============================================================================
phase_instruction_sync() {
    # Only run in framework-dev context (instruction-sync.sh exists)
    local sync_script="$SCRIPT_DIR/instruction-sync.sh"
    if [ ! -f "$sync_script" ]; then
        return 0
    fi

    if bash "$sync_script" --quiet 2>/dev/null; then
        record_ok
        if [ "$MODE" != "quiet" ]; then
            echo -e "Instr sync: ${GREEN}OK (all ag commands in instruction files)${NC}"
        fi
    else
        record_issue "instruction file drift"
        if [ "$MODE" != "quiet" ]; then
            echo -e "Instr sync: ${YELLOW}DRIFT (ag commands missing from instruction files)${NC}"
            echo -e "            Run: bash .agentic/lib/tools/instruction-sync.sh"
        fi
    fi
}

# ============================================================================
# Phase 6: Git hook configuration
# ============================================================================
phase_hooks() {
    if ! command -v git >/dev/null 2>&1 || ! git rev-parse --git-dir >/dev/null 2>&1; then
        return 0
    fi

    local hooks_path
    hooks_path=$(git config core.hooksPath 2>/dev/null || echo "")

    if [ "$hooks_path" = ".agentic/hooks" ]; then
        record_ok
        if [ "$MODE" != "quiet" ]; then
            echo -e "Git hooks:  ${GREEN}OK (core.hooksPath = .agentic/hooks)${NC}"
        fi
    elif [ "$MODE" = "full" ]; then
        git config core.hooksPath .agentic/hooks
        record_fixed
        echo -e "Git hooks:  ${GREEN}FIXED (set core.hooksPath to .agentic/hooks)${NC}"
    else
        record_issue "git hooks not configured"
        if [ "$MODE" != "quiet" ]; then
            echo -e "Git hooks:  ${YELLOW}NOT CONFIGURED${NC}"
            echo -e "            Fix: ag hooks install"
        fi
    fi
}

# ============================================================================
# Phase 7: Periodic checks (orphaned plans, retro, agent freshness)
# ============================================================================
phase_periodic() {
    local periodic_script="$SCRIPT_DIR/periodic-checks.sh"
    if [ ! -f "$periodic_script" ]; then
        return 0
    fi

    # Increment session counter once (separate from checks to avoid double-counting)
    bash "$periodic_script" --increment > /dev/null 2>&1 || true

    if [ "$MODE" = "quiet" ]; then
        local periodic_output
        periodic_output=$(bash "$periodic_script" --check 2>&1 || true)
        if [ -n "$periodic_output" ]; then
            record_issue "periodic checks"
        else
            record_ok
        fi
    else
        # Run checks with visible output (periodic-checks.sh prints its own lines)
        local periodic_output
        periodic_output=$(bash "$periodic_script" --check 2>&1 || true)
        if [ -n "$periodic_output" ]; then
            echo "$periodic_output"
            record_issue "periodic checks"
        else
            record_ok
        fi
    fi
}

# ============================================================================
# Phase 8: PR cleanup (auto-resolve merged/closed PRs in HUMAN_NEEDED.md)
# ============================================================================
phase_pr_cleanup() {
    local hn_file="$HUMAN_NEEDED_FILE"

    # Early returns: no file or no gh CLI
    if [ ! -f "$hn_file" ]; then
        return 0
    fi
    if ! command -v gh >/dev/null 2>&1; then
        return 0
    fi

    # Extract active section only
    local active_section
    active_section=$(awk '/^## Active items/,/^---$/' "$hn_file" 2>/dev/null || true)

    if [ -z "$active_section" ]; then
        record_ok
        if [ "$MODE" != "quiet" ]; then
            echo -e "PR cleanup: ${GREEN}OK${NC}"
        fi
        return 0
    fi

    local resolved_count=0
    local checked_count=0

    # Loop through active HN entries that mention PR numbers
    while IFS= read -r line; do
        if [[ "$line" =~ ^###[[:space:]]+(HN-[0-9]{4}):.+PR[[:space:]]*#([0-9]+) ]]; then
            local hn_id="${BASH_REMATCH[1]}"
            local pr_num="${BASH_REMATCH[2]}"
            ((checked_count++))

            # Check PR state via gh CLI
            local pr_state
            pr_state=$(gh pr view "$pr_num" --json state -q .state 2>/dev/null || echo "")
            pr_state=$(echo "$pr_state" | tr '[:upper:]' '[:lower:]')

            if [ "$pr_state" = "merged" ] || [ "$pr_state" = "closed" ]; then
                ((resolved_count++))
                if [ "$MODE" = "full" ]; then
                    bash "$SCRIPT_DIR/blocker.sh" resolve "$hn_id" "PR #$pr_num $pr_state (auto-detected by sync)" || true
                    record_fixed
                else
                    record_issue "$hn_id: PR #$pr_num $pr_state"
                fi
            fi
        fi
    done <<< "$active_section"

    if [ "$resolved_count" -gt 0 ]; then
        if [ "$MODE" != "quiet" ]; then
            if [ "$MODE" = "full" ]; then
                echo -e "PR cleanup: ${GREEN}FIXED ($resolved_count merged/closed PR(s) resolved)${NC}"
            else
                echo -e "PR cleanup: ${YELLOW}$resolved_count merged/closed PR(s) still in Active${NC}"
                echo -e "            Fix: bash .agentic/tools/sync.sh (full mode auto-resolves)"
            fi
        fi
    elif [ "$checked_count" -gt 0 ]; then
        record_ok
        if [ "$MODE" != "quiet" ]; then
            echo -e "PR cleanup: ${GREEN}OK ($checked_count open PR(s))${NC}"
        fi
    else
        record_ok
        if [ "$MODE" != "quiet" ]; then
            echo -e "PR cleanup: ${GREEN}OK (no PR entries in active)${NC}"
        fi
    fi
}

# ============================================================================
# Phase 9: Plan durability (scan ephemeral plan dirs for unsaved plans)
# ============================================================================
phase_plan_scan() {
    local plan_scan_script="$SCRIPT_DIR/plan-scan.sh"
    if [ ! -f "$plan_scan_script" ]; then
        return 0
    fi

    if [ "$MODE" = "quiet" ]; then
        local output
        output=$(bash "$plan_scan_script" --quiet 2>&1 || true)
        if [ -n "$output" ]; then
            record_issue "unsaved plans"
        else
            record_ok
        fi
    elif [ "$MODE" = "check" ]; then
        local output
        output=$(bash "$plan_scan_script" --check 2>&1 || true)
        if echo "$output" | grep -q "unsaved\|detected"; then
            record_issue "unsaved plans"
            echo -e "Plans:      ${YELLOW}$(echo "$output" | head -1)${NC}"
            echo "$output" | tail -n +2
        else
            record_ok
            echo -e "Plans:      ${GREEN}OK${NC}"
        fi
    else
        # Full mode: actually copy plans
        local output
        output=$(bash "$plan_scan_script" 2>&1 || true)
        if echo "$output" | grep -q "saved to"; then
            record_fixed
            echo -e "Plans:      ${GREEN}FIXED ($(echo "$output" | head -1))${NC}"
            echo "$output" | tail -n +2
        elif echo "$output" | grep -q "already saved"; then
            record_ok
            echo -e "Plans:      ${GREEN}OK (ephemeral plans already saved)${NC}"
        else
            record_ok
            if [ "$MODE" != "quiet" ]; then
                echo -e "Plans:      ${GREEN}OK${NC}"
            fi
        fi
    fi
}

# ============================================================================
# Phase 9b: Plan-to-phases drift (F-032)
# Detect when a plan file has been revised after its tasks.yaml was created
# ============================================================================
phase_plan_phase_drift() {
    local work_dir="$ROOT_DIR/.agentic/work"
    [ -d "$work_dir" ] || return 0

    local plans_dir="$ROOT_DIR/.agentic/journal/plans"
    [ -d "$plans_dir" ] || return 0

    local drifted=0
    for tasks_file in "$work_dir"/*/tasks.yaml; do
        [ -f "$tasks_file" ] || continue
        local fid
        fid=$(basename "$(dirname "$tasks_file")")

        # Find corresponding plan (most recently modified match with feature ID)
        # Uses stat for mtime — portable across GNU/macOS (find -printf is GNU-only)
        local plan_file=""
        plan_file=$(find "$plans_dir" -name "*${fid}*" -type f 2>/dev/null | while read -r f; do
            echo "$(stat -c '%Y' "$f" 2>/dev/null || stat -f '%m' "$f" 2>/dev/null) $f"
        done | sort -rn | head -1 | cut -d' ' -f2-)
        [ -n "$plan_file" ] && [ -f "$plan_file" ] || continue

        # Check if plan is newer than tasks.yaml
        if [ "$plan_file" -nt "$tasks_file" ]; then
            drifted=$((drifted + 1))
            echo -e "  ${YELLOW}⚠ $fid: plan revised after tasks.yaml — run: ag phase sync $fid${NC}"
            record_issue "plan-phase-drift"
        fi
    done

    if [ "$drifted" -eq 0 ]; then
        record_ok
    fi
}

# ============================================================================
# Phase 10: Intent reconciliation (adopt orphans, resume pending)
# ============================================================================
phase_intents() {
    # Requires python3 and intents.py
    local intents_script="$SCRIPT_DIR/../auto/intents.py"
    if ! command -v python3 >/dev/null 2>&1 || [ ! -f "$intents_script" ]; then
        return 0
    fi

    # Resolve main project root (for worktree-aware session storage)
    local main_root="$ROOT_DIR"
    if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
        local git_common git_dir
        git_common=$(git rev-parse --git-common-dir 2>/dev/null) || true
        git_dir=$(git rev-parse --git-dir 2>/dev/null) || true
        if [ -n "$git_common" ] && [ -n "$git_dir" ] && [ "$git_common" != "$git_dir" ]; then
            main_root=$(cd "$(dirname "$git_common")" && pwd)
        fi
    fi

    local sid_file="$main_root/.agentic/session/.current-session-id"
    local session_id=""
    if [ -f "$sid_file" ]; then
        session_id=$(cat "$sid_file" 2>/dev/null | tr -d '[:space:]')
    fi

    # Phase 9a: Adopt orphaned intents (dead PID, different session)
    local orphans
    orphans=$(python3 "$intents_script" --project-root "$main_root" get-orphaned 2>/dev/null || true)

    if [ -n "$orphans" ]; then
        # Generate session ID if we don't have one
        if [ -z "$session_id" ]; then
            mkdir -p "$main_root/.agentic/session" 2>/dev/null
            if command -v uuidgen >/dev/null 2>&1; then
                session_id=$(uuidgen 2>/dev/null | tr '[:upper:]' '[:lower:]')
            elif [ -r /proc/sys/kernel/random/uuid ]; then
                session_id=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)
            else
                session_id=$(python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null)
            fi
            echo "$session_id" > "$sid_file" 2>/dev/null
        fi

        # Count orphans
        local orphan_count
        orphan_count=$(echo "$orphans" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo "?")
        local orphan_features
        orphan_features=$(echo "$orphans" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(', '.join(i.get('feature_id','?') for i in d))
" 2>/dev/null || echo "?")

        if [ "$MODE" != "quiet" ]; then
            echo -e "Intents:    ${YELLOW}$orphan_count orphaned intent(s) from crashed session ($orphan_features)${NC}"
        fi

        if [ "$MODE" = "full" ]; then
            # Auto-adopt into current session
            local adopted
            adopted=$(python3 "$intents_script" --project-root "$main_root" \
                adopt-orphans --session-id "$session_id" --pid "${PPID:-$$}" 2>/dev/null || true)
            if [ -n "$adopted" ]; then
                record_fixed
                if [ "$MODE" != "quiet" ]; then
                    echo -e "            ${GREEN}Adopted into current session. Run \`ag sync\` to resume.${NC}"
                fi
            fi
        else
            record_issue "$orphan_count orphaned intent(s)"
            if [ "$MODE" != "quiet" ]; then
                echo -e "            Fix: run \`ag sync\` (full mode) to adopt, or \`ag intent clear F-XXXX\` to discard"
            fi
        fi
    fi

    # Phase 9b: Check for pending intents in current session
    if [ -n "$session_id" ]; then
        local pending
        pending=$(python3 "$intents_script" --project-root "$main_root" \
            get-pending --session-id "$session_id" 2>/dev/null || true)

        if [ -n "$pending" ]; then
            local pending_count
            pending_count=$(echo "$pending" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo "?")
            local pending_features
            pending_features=$(echo "$pending" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for i in d:
    fid = i.get('feature_id', '?')
    cmd = i.get('command', '?')
    remaining = len(i.get('steps_remaining', []))
    completed = len(i.get('steps_completed', []))
    attempts = i.get('attempt_count', 1)
    print(f'  {fid}: ag {cmd} — {completed} done, {remaining} remaining (attempt {attempts})')
" 2>/dev/null || echo "  (parse error)")

            record_issue "$pending_count pending intent(s)"
            if [ "$MODE" != "quiet" ]; then
                echo -e "Intents:    ${YELLOW}$pending_count pending intent(s) from current session:${NC}"
                echo -e "$pending_features"
                echo -e "            Resume: re-run the original ag command, or \`ag intent clear F-XXXX\` to discard"
            fi
        elif [ -z "$orphans" ]; then
            record_ok
            if [ "$MODE" != "quiet" ]; then
                echo -e "Intents:    ${GREEN}OK (no pending work)${NC}"
            fi
        fi
    elif [ -z "$orphans" ]; then
        record_ok
        if [ "$MODE" != "quiet" ]; then
            echo -e "Intents:    ${GREEN}OK (no session)${NC}"
        fi
    fi
}

# ============================================================================
# Main
# ============================================================================
main() {
    if [ "$MODE" = "quiet" ]; then
        # Run phases silently, collect issues
        phase_memory
        phase_state_freshness
        phase_features
        phase_unregistered_code
        # Skip phase 4 (slow) but run 4b (fast)
        phase_assertion_status
        phase_tool_parity
        phase_instruction_sync
        phase_hooks
        phase_periodic
        phase_pr_cleanup
        phase_plan_scan
        phase_plan_phase_drift
        phase_intents

        # Output one-line summary only if issues exist
        if [ "$ISSUE_COUNT" -gt 0 ]; then
            local issue_list
            issue_list=$(printf '%s' "${ISSUE_SUMMARY[*]}" | sed 's/ /\n/g' | head -3 | tr '\n' ', ' | sed 's/,$//')
            # Build a readable summary
            local parts=()
            for item in "${ISSUE_SUMMARY[@]}"; do
                parts+=("$item")
            done
            local summary
            summary=$(IFS=', '; echo "${parts[*]}")
            echo "Sync: $ISSUE_COUNT issue(s) ($summary)"
        fi
        # Empty output = all clean
        exit 0
    fi

    echo -e "${BOLD}=== ag sync ===${NC}"
    echo ""

    phase_memory
    phase_state_freshness
    phase_features
    phase_drift_check
    phase_unregistered_code
    phase_spec_drift
    phase_assertion_status
    phase_tool_parity
    phase_instruction_sync
    phase_hooks
    phase_periodic
    phase_pr_cleanup
    phase_plan_scan
    phase_plan_phase_drift
    phase_intents

    # Summary
    echo ""
    local total=$((OK_COUNT + FIXED_COUNT + ISSUE_COUNT))
    echo -e "Summary: ${GREEN}$OK_COUNT OK${NC}"
    if [ "$FIXED_COUNT" -gt 0 ]; then
        echo -e "         ${GREEN}$FIXED_COUNT fixed${NC}"
    fi
    if [ "$ISSUE_COUNT" -gt 0 ]; then
        echo -e "         ${YELLOW}$ISSUE_COUNT need attention${NC}"
    fi

    exit 0
}

main
