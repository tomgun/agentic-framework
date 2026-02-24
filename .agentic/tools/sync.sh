#!/usr/bin/env bash
# sync.sh — Unified framework sync: detect drift across ALL artifacts, auto-fix safe errors
#
# Usage:
#   bash .agentic/tools/sync.sh              # Full sync: all phases, auto-fix safe things
#   bash .agentic/tools/sync.sh --check      # Dry run: detect only, no auto-fixes
#   bash .agentic/tools/sync.sh --quiet      # One-line summary (for ag start probe)
#
# Six check phases:
#   1. Memory seed integrity
#   2. State freshness (journal, STATUS, CHANGELOG)
#   3. Feature reconciliation (Formal only)
#   4. Spec/doc drift (skipped in --quiet)
#   5. Tool parity (instruction files + trigger tables)
#   6. Git hook configuration
#
# Exit code: always 0 (advisory tool).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

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
source "$SCRIPT_DIR/../lib/settings.sh"
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
    if [ -f "$ROOT_DIR/.agentic-journal/JOURNAL.md" ]; then
        journal_file="$ROOT_DIR/.agentic-journal/JOURNAL.md"
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

    # --- CONTEXT_PACK.md placeholder detection ---
    local ctx_pack="$ROOT_DIR/CONTEXT_PACK.md"
    if [ -f "$ctx_pack" ]; then
        local placeholder_count
        placeholder_count=$(grep -cE '<!-- (1|fill|bullets|e\.g\.|path )' "$ctx_pack" 2>/dev/null || echo "0")

        if [ "$placeholder_count" -ge 3 ]; then
            record_issue "CONTEXT_PACK.md has template placeholders"
            if [ "$MODE" != "quiet" ]; then
                echo -e "CONTEXT_PACK: ${YELLOW}STALE ($placeholder_count template placeholders still present)${NC}"
                echo -e "            Fix: Replace <!-- fill ... --> placeholders with real project content"
            fi
        else
            record_ok
            if [ "$MODE" != "quiet" ]; then
                echo -e "CONTEXT_PACK: ${GREEN}OK${NC}"
            fi
        fi
    else
        record_ok
        if [ "$MODE" != "quiet" ]; then
            echo -e "CONTEXT_PACK: ${DIM}skipped (no CONTEXT_PACK.md)${NC}"
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

    local features_file="$ROOT_DIR/spec/FEATURES.md"
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
        if [ -f "$ROOT_DIR/.agentic-state/WIP.md" ] && grep -q "$fid" "$ROOT_DIR/.agentic-state/WIP.md" 2>/dev/null; then
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
        if [ ! -f "$ROOT_DIR/spec/acceptance/${fid}.md" ]; then
            record_issue "$fid no-acceptance"
            ((feature_issues++))
            if [ "$MODE" != "quiet" ]; then
                echo -e "            $fid: in_progress but no acceptance criteria"
                echo -e "            Create: spec/acceptance/${fid}.md (even rough 2-3 bullet points)"
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

    # Check for acceptance files without FEATURES.md entries
    if [ -d "$ROOT_DIR/spec/acceptance" ]; then
        for criteria_file in "$ROOT_DIR/spec/acceptance"/F-*.md; do
            [ -f "$criteria_file" ] || continue
            local fid
            fid=$(basename "$criteria_file" .md)
            if ! grep -q "$fid" "$features_file" 2>/dev/null; then
                record_issue "$fid orphaned acceptance"
                ((feature_issues++))
                if [ "$MODE" != "quiet" ]; then
                    if [ "$feature_issues" -eq 1 ]; then
                        echo -e "Features:   ${YELLOW}issues found${NC}"
                    fi
                    echo -e "            $fid: has acceptance file but no FEATURES.md entry"
                fi
            fi
        done
    fi

    if [ "$feature_issues" -eq 0 ]; then
        record_ok
        if [ "$MODE" != "quiet" ]; then
            echo -e "Features:   ${GREEN}OK${NC}"
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
# Phase 5: Tool parity (instruction files + trigger tables)
# ============================================================================
phase_tool_parity() {
    # Run check-environment.sh to detect tools
    local env_exit=0
    local env_output
    env_output=$(bash "$SCRIPT_DIR/check-environment.sh" 2>&1) || env_exit=$?

    if [ "$env_exit" -ne 0 ]; then
        # Missing instruction files
        if [ "$MODE" = "full" ]; then
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
# Main
# ============================================================================
main() {
    if [ "$MODE" = "quiet" ]; then
        # Run phases silently, collect issues
        phase_memory
        phase_state_freshness
        phase_features
        # Skip phase 4 (slow)
        phase_tool_parity
        phase_hooks

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
    phase_spec_drift
    phase_tool_parity
    phase_hooks

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
