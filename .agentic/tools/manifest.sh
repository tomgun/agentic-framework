#!/usr/bin/env bash
# manifest.sh - Generate feature change manifest from git history (JSON format)
#
# Usage:
#   manifest.sh F-XXXX                    # Generate from feature ID (searches commits)
#   manifest.sh --branch feature/foo      # Generate from branch
#   manifest.sh --since 2026-02-01        # Generate from date range
#   manifest.sh --commits abc123,def456   # Generate from explicit commits
#   manifest.sh F-XXXX --markdown         # Output Markdown instead of JSON
#
# Output: .agentic-journal/manifests/<name>.json (JSON format for drift.sh integration)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Manifests live in .agentic-journal/ (persistent history, always committed)
# Separate from .agentic-state/ (transient state, mostly gitignored)
JOURNAL_DIR="$PROJECT_ROOT/.agentic-journal"
MANIFEST_DIR="$JOURNAL_DIR/manifests"

# Error handling
error() { echo "❌ Error: $1" >&2; exit 1; }
warn() { echo "⚠️ Warning: $1" >&2; }

# Check we're in a git repo
git rev-parse --git-dir >/dev/null 2>&1 || error "Not a git repository"

# Parse arguments
MODE=""
VALUE=""
OUTPUT_FILE=""
FORMAT="json"  # Default to JSON for drift.sh compatibility

show_help() {
    cat << 'EOF'
manifest.sh - Generate feature change manifest from git history

USAGE:
    manifest.sh F-XXXX                    Generate from feature ID (searches commits)
    manifest.sh --branch NAME             Generate from branch (vs main)
    manifest.sh --since DATE              Generate from date range
    manifest.sh --commits HASH,HASH       Generate from explicit commits

OPTIONS:
    --output FILE     Override output file path
    --markdown        Output Markdown format instead of JSON
    -h, --help        Show this help

EXAMPLES:
    manifest.sh F-0116                    # Feature commits (JSON)
    manifest.sh --branch feature/auth     # All commits on branch
    manifest.sh --since "2026-02-01"      # Recent commits
    manifest.sh F-0116 --markdown         # Human-readable Markdown

OUTPUT:
    Creates .agentic-journal/manifests/<name>.json at project root.
    Use --markdown for .manifest.md human-readable format.
    Part of persistent history (always committed).
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --branch)
            MODE="branch"
            VALUE="$2"
            shift 2
            ;;
        --since)
            MODE="since"
            VALUE="$2"
            shift 2
            ;;
        --commits)
            MODE="commits"
            VALUE="$2"
            shift 2
            ;;
        --markdown)
            FORMAT="markdown"
            shift
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        F-[0-9]*)
            MODE="feature"
            VALUE="$1"
            shift
            ;;
        *)
            error "Unknown argument: $1. Use --help for usage."
            ;;
    esac
done

[[ -z "$MODE" ]] && error "Must specify F-XXXX, --branch, --since, or --commits"

# Find commits based on mode
find_commits() {
    case "$MODE" in
        feature)
            # Search for feature ID in commit messages
            git log --all --oneline --grep="$VALUE" --format="%H" | head -100
            ;;
        branch)
            # Get all commits on this branch not in main/master
            local base_branch
            if git show-ref --verify --quiet refs/heads/main; then
                base_branch="main"
            elif git show-ref --verify --quiet refs/heads/master; then
                base_branch="master"
            else
                # No main/master, just get all commits on branch
                git log "$VALUE" --format="%H" 2>/dev/null
                return
            fi
            git log "$VALUE" --not "$base_branch" --format="%H" 2>/dev/null
            ;;
        since)
            git log --since="$VALUE" --format="%H"
            ;;
        commits)
            echo "$VALUE" | tr ',' '\n'
            ;;
    esac
}

COMMITS=$(find_commits)

if [[ -z "$COMMITS" ]]; then
    warn "No commits found for $MODE=$VALUE"
    exit 0
fi

mkdir -p "$MANIFEST_DIR"

# Determine output file extension based on format
if [[ "$FORMAT" == "json" ]]; then
    EXT="json"
else
    EXT="manifest.md"
fi

# Determine output file
if [[ -z "$OUTPUT_FILE" ]]; then
    case "$MODE" in
        feature)
            OUTPUT_FILE="$MANIFEST_DIR/${VALUE}.${EXT}"
            ;;
        branch)
            OUTPUT_FILE="$MANIFEST_DIR/branch-$(echo "$VALUE" | tr '/' '-').${EXT}"
            ;;
        since)
            OUTPUT_FILE="$MANIFEST_DIR/since-$(echo "$VALUE" | tr ' :' '-').${EXT}"
            ;;
        commits)
            OUTPUT_FILE="$MANIFEST_DIR/commits-$(date +%Y%m%d-%H%M%S).${EXT}"
            ;;
    esac
fi

# Helper: escape JSON string
json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\t'/\\t}"
    printf '%s' "$str"
}

# Collect all data first
TOTAL_ADDED=0
TOTAL_REMOVED=0
ALL_FILES=""
COMMITS_DATA=""

while IFS= read -r commit; do
    [[ -z "$commit" ]] && continue

    # Use git log for consistent output (handles merge commits)
    SHORT=$(git log -1 --format="%h" "$commit" 2>/dev/null) || continue
    DATE=$(git log -1 --format="%cs" "$commit")
    MSG=$(git log -1 --format="%s" "$commit")

    # Get file stats
    STATS=$(git log -1 --numstat --format="" "$commit")
    ADDED=$(echo "$STATS" | awk '{sum += $1} END {print sum+0}')
    REMOVED=$(echo "$STATS" | awk '{sum += $2} END {print sum+0}')

    TOTAL_ADDED=$((TOTAL_ADDED + ADDED))
    TOTAL_REMOVED=$((TOTAL_REMOVED + REMOVED))

    # Collect files
    FILES=$(git log -1 --name-only --format="" "$commit")
    ALL_FILES="$ALL_FILES"$'\n'"$FILES"

    # Store commit data for later
    COMMITS_DATA="$COMMITS_DATA$SHORT|$DATE|$MSG|$ADDED|$REMOVED"$'\n'

done <<< "$COMMITS"

# Deduplicate and categorize files
UNIQUE_FILES=$(echo "$ALL_FILES" | grep -v '^$' | sort -u)

CODE_FILES=$(echo "$UNIQUE_FILES" | grep -E '\.(py|js|ts|tsx|jsx|go|rs|rb|sh|java|swift|kt|scala)$' | grep -v -iE '(test|spec)' || true)
TEST_FILES=$(echo "$UNIQUE_FILES" | grep -iE '(test|spec)\.(py|js|ts|tsx|jsx|go|rs|rb|java)$|tests?/|spec/' || true)
DOC_FILES=$(echo "$UNIQUE_FILES" | grep -E '\.(md|txt|rst)$' | grep -v -iE 'test' || true)
CONFIG_FILES=$(echo "$UNIQUE_FILES" | grep -E '\.(json|yaml|yml|toml|ini|cfg)$' || true)

COMMIT_COUNT=$(echo "$COMMITS" | grep -c '.' 2>/dev/null || echo "0")
TOTAL_FILES=$(echo "$UNIQUE_FILES" | grep -c '.' 2>/dev/null || echo "0")

# Generate output based on format
if [[ "$FORMAT" == "json" ]]; then
    # JSON format for drift.sh integration
    {
        echo "{"
        echo "  \"feature\": \"$VALUE\","
        echo "  \"mode\": \"$MODE\","
        echo "  \"generated\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
        echo "  \"commits\": ["

        # Output commits
        FIRST=true
        while IFS='|' read -r hash date msg added removed; do
            [[ -z "$hash" ]] && continue
            if [[ "$FIRST" == "true" ]]; then
                FIRST=false
            else
                echo ","
            fi
            printf '    {"hash": "%s", "date": "%s", "message": "%s", "additions": %s, "deletions": %s}' \
                "$hash" "$date" "$(json_escape "$msg")" "$added" "$removed"
        done <<< "$COMMITS_DATA"
        echo ""
        echo "  ],"

        # Output files
        echo "  \"files\": {"

        # Code files
        echo -n "    \"code\": ["
        FIRST=true
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            if [[ "$FIRST" == "true" ]]; then
                FIRST=false
            else
                echo -n ", "
            fi
            printf '{"file": "%s"}' "$f"
        done <<< "$CODE_FILES"
        echo "],"

        # Test files
        echo -n "    \"tests\": ["
        FIRST=true
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            if [[ "$FIRST" == "true" ]]; then
                FIRST=false
            else
                echo -n ", "
            fi
            printf '{"file": "%s"}' "$f"
        done <<< "$TEST_FILES"
        echo "],"

        # Doc files
        echo -n "    \"docs\": ["
        FIRST=true
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            if [[ "$FIRST" == "true" ]]; then
                FIRST=false
            else
                echo -n ", "
            fi
            printf '{"file": "%s"}' "$f"
        done <<< "$DOC_FILES"
        echo "],"

        # Config files
        echo -n "    \"config\": ["
        FIRST=true
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            if [[ "$FIRST" == "true" ]]; then
                FIRST=false
            else
                echo -n ", "
            fi
            printf '{"file": "%s"}' "$f"
        done <<< "$CONFIG_FILES"
        echo "]"

        echo "  },"

        # Stats
        echo "  \"stats\": {"
        echo "    \"total_commits\": $COMMIT_COUNT,"
        echo "    \"total_files\": $TOTAL_FILES,"
        echo "    \"additions\": $TOTAL_ADDED,"
        echo "    \"deletions\": $TOTAL_REMOVED"
        echo "  }"
        echo "}"

    } > "$OUTPUT_FILE"

else
    # Markdown format for human readability
    {
        echo "# Change Manifest: $VALUE"
        echo ""
        echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "Mode: $MODE"
        echo ""

        echo "## Commits"
        echo ""
        echo "| Hash | Date | Message | +/- |"
        echo "|------|------|---------|-----|"

        while IFS='|' read -r hash date msg added removed; do
            [[ -z "$hash" ]] && continue
            # Truncate message for table display
            short_msg="${msg:0:50}"
            echo "| $hash | $date | $short_msg | +$added/-$removed |"
        done <<< "$COMMITS_DATA"

        echo ""
        echo "## Summary"
        echo ""
        echo "- **Total commits**: $COMMIT_COUNT"
        echo "- **Lines added**: $TOTAL_ADDED"
        echo "- **Lines removed**: $TOTAL_REMOVED"
        echo ""

        echo "## Files Changed"
        echo ""

        echo "### Code"
        if [[ -n "$CODE_FILES" ]]; then
            echo "$CODE_FILES" | while read -r f; do
                [[ -n "$f" ]] && echo "- \`$f\`"
            done
        else
            echo "_None_"
        fi

        echo ""
        echo "### Tests"
        if [[ -n "$TEST_FILES" ]]; then
            echo "$TEST_FILES" | while read -r f; do
                [[ -n "$f" ]] && echo "- \`$f\`"
            done
        else
            echo "_None_"
        fi

        echo ""
        echo "### Documentation"
        if [[ -n "$DOC_FILES" ]]; then
            echo "$DOC_FILES" | while read -r f; do
                [[ -n "$f" ]] && echo "- \`$f\`"
            done
        else
            echo "_None_"
        fi

        echo ""
        echo "### Configuration"
        if [[ -n "$CONFIG_FILES" ]]; then
            echo "$CONFIG_FILES" | while read -r f; do
                [[ -n "$f" ]] && echo "- \`$f\`"
            done
        else
            echo "_None_"
        fi

    } > "$OUTPUT_FILE"
fi

echo "✅ Generated $OUTPUT_FILE"
