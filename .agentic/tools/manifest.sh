#!/usr/bin/env bash
# manifest.sh - Generate feature change manifest from git history
#
# Usage:
#   manifest.sh F-XXXX                    # Generate from feature ID (searches commits)
#   manifest.sh --branch feature/foo      # Generate from branch
#   manifest.sh --since 2026-02-01        # Generate from date range
#   manifest.sh --commits abc123,def456   # Generate from explicit commits
#   manifest.sh F-XXXX --migration 116    # Generate and embed into migration file
#
# Output: .manifests/ directory at project root (persists across .agentic upgrades)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# State lives at project root, NOT inside .agentic (survives framework upgrades)
STATE_DIR="$PROJECT_ROOT/.agentic-state"
MANIFEST_DIR="$STATE_DIR/manifests"

# Error handling
error() { echo "❌ Error: $1" >&2; exit 1; }
warn() { echo "⚠️ Warning: $1" >&2; }

# Check we're in a git repo
git rev-parse --git-dir >/dev/null 2>&1 || error "Not a git repository"

# Parse arguments
MODE=""
VALUE=""
MIGRATION_ID=""
OUTPUT_FILE=""

show_help() {
    cat << 'EOF'
manifest.sh - Generate feature change manifest from git history

USAGE:
    manifest.sh F-XXXX                    Generate from feature ID (searches commits)
    manifest.sh --branch NAME             Generate from branch (vs main)
    manifest.sh --since DATE              Generate from date range
    manifest.sh --commits HASH,HASH       Generate from explicit commits
    manifest.sh F-XXXX --migration 116    Embed manifest into migration file

OPTIONS:
    --output FILE     Override output file path
    --migration ID    Append manifest to spec/migrations/ID_*.md
    -h, --help        Show this help

EXAMPLES:
    manifest.sh F-0116                    # Feature commits
    manifest.sh --branch feature/auth     # All commits on branch
    manifest.sh --since "2026-02-01"      # Recent commits
    manifest.sh F-0116 --migration 116    # Embed in migration

OUTPUT:
    Creates .agentic-state/manifests/<name>.manifest.md at project root.
    This location persists across .agentic framework upgrades.
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
        --migration)
            MIGRATION_ID="$2"
            shift 2
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

# Determine output file
if [[ -z "$OUTPUT_FILE" ]]; then
    case "$MODE" in
        feature)
            OUTPUT_FILE="$MANIFEST_DIR/${VALUE}.manifest.md"
            ;;
        branch)
            OUTPUT_FILE="$MANIFEST_DIR/branch-$(echo "$VALUE" | tr '/' '-').manifest.md"
            ;;
        since)
            OUTPUT_FILE="$MANIFEST_DIR/since-$(echo "$VALUE" | tr ' :' '-').manifest.md"
            ;;
        commits)
            OUTPUT_FILE="$MANIFEST_DIR/commits-$(date +%Y%m%d-%H%M%S).manifest.md"
            ;;
    esac
fi

# Generate manifest
{
    echo "# Change Manifest: $VALUE"
    echo ""
    echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "Mode: $MODE"
    echo ""

    echo "## Commits"
    echo ""
    echo "| Hash | Date | Message | Files | +/- |"
    echo "|------|------|---------|-------|-----|"

    TOTAL_ADDED=0
    TOTAL_REMOVED=0
    ALL_FILES=""

    while IFS= read -r commit; do
        [[ -z "$commit" ]] && continue

        # Use git log for consistent output (handles merge commits)
        SHORT=$(git log -1 --format="%h" "$commit" 2>/dev/null) || continue
        DATE=$(git log -1 --format="%cs" "$commit")
        MSG=$(git log -1 --format="%s" "$commit" | head -c 50)

        # Get file stats
        STATS=$(git log -1 --numstat --format="" "$commit")
        FILE_COUNT=$(echo "$STATS" | grep -c '.' 2>/dev/null || echo "0")
        ADDED=$(echo "$STATS" | awk '{sum += $1} END {print sum+0}')
        REMOVED=$(echo "$STATS" | awk '{sum += $2} END {print sum+0}')

        echo "| $SHORT | $DATE | $MSG | $FILE_COUNT | +$ADDED/-$REMOVED |"

        TOTAL_ADDED=$((TOTAL_ADDED + ADDED))
        TOTAL_REMOVED=$((TOTAL_REMOVED + REMOVED))

        # Collect files
        FILES=$(git log -1 --name-only --format="" "$commit")
        ALL_FILES="$ALL_FILES"$'\n'"$FILES"

    done <<< "$COMMITS"

    echo ""
    echo "## Summary"
    echo ""
    COMMIT_COUNT=$(echo "$COMMITS" | grep -c '.' 2>/dev/null || echo "0")
    echo "- **Total commits**: $COMMIT_COUNT"
    echo "- **Lines added**: $TOTAL_ADDED"
    echo "- **Lines removed**: $TOTAL_REMOVED"
    echo ""

    # Deduplicate and categorize files
    UNIQUE_FILES=$(echo "$ALL_FILES" | grep -v '^$' | sort -u)

    echo "## Files Changed"
    echo ""

    # Code files
    echo "### Code"
    CODE_FILES=$(echo "$UNIQUE_FILES" | grep -E '\.(py|js|ts|tsx|jsx|go|rs|rb|sh|java|swift|kt|scala)$' | grep -v -iE '(test|spec)' || true)
    if [[ -n "$CODE_FILES" ]]; then
        echo "$CODE_FILES" | while read -r f; do
            [[ -n "$f" ]] && echo "- \`$f\`"
        done
    else
        echo "_None_"
    fi

    echo ""
    echo "### Tests"
    TEST_FILES=$(echo "$UNIQUE_FILES" | grep -iE '(test|spec)\.(py|js|ts|tsx|jsx|go|rs|rb|java)$|tests?/|spec/' || true)
    if [[ -n "$TEST_FILES" ]]; then
        echo "$TEST_FILES" | while read -r f; do
            [[ -n "$f" ]] && echo "- \`$f\`"
        done
    else
        echo "_None_"
    fi

    echo ""
    echo "### Documentation"
    DOC_FILES=$(echo "$UNIQUE_FILES" | grep -E '\.(md|txt|rst)$' | grep -v -iE 'test' || true)
    if [[ -n "$DOC_FILES" ]]; then
        echo "$DOC_FILES" | while read -r f; do
            [[ -n "$f" ]] && echo "- \`$f\`"
        done
    else
        echo "_None_"
    fi

    echo ""
    echo "### Configuration"
    CONFIG_FILES=$(echo "$UNIQUE_FILES" | grep -E '\.(json|yaml|yml|toml|ini|cfg)$' || true)
    if [[ -n "$CONFIG_FILES" ]]; then
        echo "$CONFIG_FILES" | while read -r f; do
            [[ -n "$f" ]] && echo "- \`$f\`"
        done
    else
        echo "_None_"
    fi

} > "$OUTPUT_FILE"

echo "✅ Generated $OUTPUT_FILE"

# If --migration specified, append to migration file
if [[ -n "$MIGRATION_ID" ]]; then
    MIGRATION_PATTERN="$PROJECT_ROOT/spec/migrations/${MIGRATION_ID}_*.md"
    MIGRATION_FILE=$(ls $MIGRATION_PATTERN 2>/dev/null | head -1)

    if [[ -f "$MIGRATION_FILE" ]]; then
        # Check if manifest section already exists
        if ! grep -q "## Generated Manifest" "$MIGRATION_FILE"; then
            {
                echo ""
                echo "---"
                echo ""
                echo "## Generated Manifest"
                echo ""
                cat "$OUTPUT_FILE"
            } >> "$MIGRATION_FILE"
            echo "✅ Appended manifest to $MIGRATION_FILE"
        else
            echo "⚠️ Migration already has manifest section (skipped)"
        fi
    else
        warn "Migration file not found for ID $MIGRATION_ID"
    fi
fi
