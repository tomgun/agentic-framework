#!/usr/bin/env bash
# design-trace.sh — Track completion of features spawned from design documents
#
# Reads **Source**: annotations from FEATURES.md and builds a reverse index:
# design doc → features → statuses → completion %.
#
# Usage:
#   bash design-trace.sh              # Summary: each source doc with completion %
#   bash design-trace.sh --doc <path> # Single document's features and statuses
#   bash design-trace.sh --quiet      # One-line for dashboard integration
#   bash design-trace.sh --all        # Include fully-shipped sources too
#
# Exit codes:
#   0 — success (or no Source annotations found)
#   1 — error (missing FEATURES.md, bad args)
#
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../paths.sh"

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
MODE="summary"
DOC_FILTER=""
SHOW_ALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --doc)
            MODE="single"
            DOC_FILTER="${2:-}"
            if [[ -z "$DOC_FILTER" ]]; then
                echo "Error: --doc requires a path argument" >&2
                exit 1
            fi
            shift 2
            ;;
        --quiet)
            MODE="quiet"
            shift
            ;;
        --all)
            SHOW_ALL=true
            shift
            ;;
        *)
            echo "Usage: design-trace.sh [--doc <path>] [--quiet] [--all]" >&2
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Check FEATURES.md
# ---------------------------------------------------------------------------
if [[ ! -f "${FEATURES_FILE}" ]]; then
    if [[ "$MODE" == "quiet" ]]; then
        exit 0
    fi
    echo "No FEATURES.md found." >&2
    exit 0
fi

# ---------------------------------------------------------------------------
# Parse: build associative arrays of source → features and feature → status
# ---------------------------------------------------------------------------
# We read FEATURES.md and track current feature ID, its status, and its source.
declare -A FEATURE_STATUS
declare -A FEATURE_SOURCE
declare -A SOURCE_FEATURES  # source_path → space-separated feature IDs
SOURCE_COUNT=0

CURRENT_FID=""
while IFS= read -r line; do
    # Feature header: ## F-XXXX: Name
    if [[ "$line" =~ ^##[[:space:]]+(F-[0-9]{4,}): ]]; then
        CURRENT_FID="${BASH_REMATCH[1]}"
        continue
    fi

    [[ -z "$CURRENT_FID" ]] && continue

    # Status line: **Status**: value
    if [[ "$line" =~ ^\*\*Status\*\*:[[:space:]]*([^[:space:]]+) ]]; then
        FEATURE_STATUS["$CURRENT_FID"]="${BASH_REMATCH[1]}"
        continue
    fi

    # Source line: **Source**: path
    if [[ "$line" =~ ^\*\*Source\*\*:[[:space:]]*(.+)$ ]]; then
        src="${BASH_REMATCH[1]}"
        # Trim whitespace
        src="${src#"${src%%[![:space:]]*}"}"
        src="${src%"${src##*[![:space:]]}"}"
        FEATURE_SOURCE["$CURRENT_FID"]="$src"
        # Append to source → features map
        if [[ -n "${SOURCE_FEATURES[$src]:-}" ]]; then
            SOURCE_FEATURES["$src"]="${SOURCE_FEATURES[$src]} $CURRENT_FID"
        else
            SOURCE_FEATURES["$src"]="$CURRENT_FID"
            SOURCE_COUNT=$((SOURCE_COUNT + 1))
        fi
        continue
    fi
done < "$FEATURES_FILE"

# ---------------------------------------------------------------------------
# No sources found
# ---------------------------------------------------------------------------
if [[ "$SOURCE_COUNT" -eq 0 ]]; then
    if [[ "$MODE" == "quiet" ]]; then
        exit 0
    fi
    echo "No **Source**: annotations found in FEATURES.md."
    exit 0
fi

# ---------------------------------------------------------------------------
# Compute per-source stats
# ---------------------------------------------------------------------------
declare -A SRC_TOTAL
declare -A SRC_SHIPPED
declare -A SRC_PENDING_LIST

for src in "${!SOURCE_FEATURES[@]}"; do
    total=0
    shipped=0
    pending=""
    for fid in ${SOURCE_FEATURES[$src]}; do
        total=$((total + 1))
        status="${FEATURE_STATUS[$fid]:-planned}"
        if [[ "$status" == "shipped" ]]; then
            shipped=$((shipped + 1))
        else
            if [[ -n "$pending" ]]; then
                pending="$pending, $fid ($status)"
            else
                pending="$fid ($status)"
            fi
        fi
    done
    SRC_TOTAL["$src"]=$total
    SRC_SHIPPED["$src"]=$shipped
    SRC_PENDING_LIST["$src"]="$pending"
done

# ---------------------------------------------------------------------------
# Output: --quiet mode
# ---------------------------------------------------------------------------
if [[ "$MODE" == "quiet" ]]; then
    incomplete=0
    for src in "${!SOURCE_FEATURES[@]}"; do
        if [[ "${SRC_SHIPPED[$src]}" -lt "${SRC_TOTAL[$src]}" ]]; then
            incomplete=$((incomplete + 1))
        fi
    done
    if [[ "$incomplete" -gt 0 ]]; then
        echo "$incomplete doc(s) with pending features"
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# Output: --doc <path> mode
# ---------------------------------------------------------------------------
if [[ "$MODE" == "single" ]]; then
    if [[ -z "${SOURCE_FEATURES[$DOC_FILTER]:-}" ]]; then
        echo "No features linked to: $DOC_FILTER"
        exit 0
    fi
    src="$DOC_FILTER"
    total="${SRC_TOTAL[$src]}"
    shipped="${SRC_SHIPPED[$src]}"
    if [[ "$total" -gt 0 ]]; then
        pct=$((shipped * 100 / total))
    else
        pct=0
    fi

    echo "$src"
    echo "  Features: $total linked"
    echo "  Shipped:  $shipped/$total ($pct%)"
    if [[ -n "${SRC_PENDING_LIST[$src]}" ]]; then
        echo "  Pending:  ${SRC_PENDING_LIST[$src]}"
    else
        echo "  Complete  ✓"
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# Output: summary mode (default)
# ---------------------------------------------------------------------------
echo "Design Traceability Report"
echo ""

# Sort source keys safely (handles paths with spaces)
SORTED_SOURCES=()
while IFS= read -r s; do
    [[ -n "$s" ]] && SORTED_SOURCES+=("$s")
done < <(printf '%s\n' "${!SOURCE_FEATURES[@]}" | sort)

incomplete=0
for src in "${SORTED_SOURCES[@]}"; do
    total="${SRC_TOTAL[$src]}"
    shipped="${SRC_SHIPPED[$src]}"
    if [[ "$total" -gt 0 ]]; then
        pct=$((shipped * 100 / total))
    else
        pct=0
    fi

    is_complete=false
    [[ "$shipped" -eq "$total" ]] && is_complete=true

    # Skip complete sources unless --all
    if $is_complete && ! $SHOW_ALL; then
        continue
    fi

    if ! $is_complete; then
        incomplete=$((incomplete + 1))
    fi

    echo "  $src"
    echo "    Features: $total linked"
    if $is_complete; then
        echo "    Shipped:  $shipped/$total ($pct%) ✓"
    else
        echo "    Shipped:  $shipped/$total ($pct%)"
        echo "    Pending:  ${SRC_PENDING_LIST[$src]}"
    fi
    echo ""
done

if [[ "$incomplete" -eq 0 ]] && ! $SHOW_ALL; then
    echo "  All source-linked features are shipped. Use --all to see complete sources."
    echo ""
fi

echo "Summary: $incomplete source doc(s) with pending features"
