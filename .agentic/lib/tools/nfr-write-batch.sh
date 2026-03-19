#!/usr/bin/env bash
# nfr-write-batch.sh — Batch write NFRs from pipe-delimited stdin to NFR.md
#
# Accepts pipe-delimited entries from stdin (one per line):
#   ID|category|statement|measure|enforced|priority|section
#
# Usage:
#   nfr-generate.sh --machine --limit 8 | nfr-write-batch.sh
#   echo "W-01|Performance|LCP < 2.5s|Lighthouse|Tests|P1|Web App" | nfr-write-batch.sh
#
# Output format matches nfr-capture.sh exactly (no Priority field).
# Multi-agent safe: checks for other active agents before writing.
#
# Exit codes:
#   0 = NFRs written successfully
#   1 = error (empty stdin, write failure)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../paths.sh"
cd "$PROJECT_ROOT"

if [ -t 1 ]; then
    BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
    BOLD='' GREEN='' YELLOW='' NC=''
fi

# Use PROJECT_ROOT-relative path (paths.sh NFR_FILE may resolve to framework's own path)
NFR_FILE="$PROJECT_ROOT/.agentic/spec/NFR.md"
TODO_FILE="${PROJECT_ROOT}/.agentic/TODO.md"

# --- Read ALL stdin atomically (prevents partial writes on pipe errors) ---
INPUT=""
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    INPUT="${INPUT}${line}"$'\n'
done

if [[ -z "$INPUT" ]]; then
    echo "Error: No input received on stdin" >&2
    echo "Usage: nfr-generate.sh --machine --limit 8 | nfr-write-batch.sh" >&2
    exit 1
fi

# --- Multi-agent safety check ---
if command -v python3 >/dev/null 2>&1 && [[ -f "$SCRIPT_DIR/agents_helpers.py" ]]; then
    others=$(python3 "$SCRIPT_DIR/agents_helpers.py" --project-root "$PROJECT_ROOT" count-others "$(pwd)" --pid $PPID 2>/dev/null || echo "0")
    if [[ "$others" -gt 0 ]]; then
        echo -e "${YELLOW}Another agent is active — logging to TODO.md instead of NFR.md${NC}"
        while IFS='|' read -r catalog_id category statement measure enforced priority section; do
            [[ -z "$catalog_id" ]] && continue
            echo "- [ ] NFR candidate: ${statement} (${catalog_id}, ${priority})" >> "$TODO_FILE"
        done <<< "$INPUT"
        echo -e "${GREEN}✓${NC} Logged NFR candidates to TODO.md for human resolution"
        exit 0
    fi
fi

# --- Create NFR.md from template if doesn't exist ---
if [[ ! -f "$NFR_FILE" ]]; then
    if [[ -f "$SCRIPT_DIR/../templates/NFR.template.md" ]]; then
        cp "$SCRIPT_DIR/../templates/NFR.template.md" "$NFR_FILE"
        sed -i '/^## NFR-####:/,$d' "$NFR_FILE" 2>/dev/null || \
            sed -i '' '/^## NFR-####:/,$d' "$NFR_FILE" 2>/dev/null || true
    else
        mkdir -p "$(dirname "$NFR_FILE")"
        echo "# NFR (Non-Functional Requirements)" > "$NFR_FILE"
        echo "" >> "$NFR_FILE"
    fi
fi

# --- Find max NFR-XXXX ID in existing NFR.md ---
max_id=$(grep -oE 'NFR-[0-9]+' "$NFR_FILE" 2>/dev/null | sed 's/NFR-//' | sort -n | tail -1)
next_num=$((${max_id:-0} + 1))

# --- Write each entry ---
written=0
while IFS='|' read -r catalog_id category statement measure enforced priority section; do
    [[ -z "$catalog_id" ]] && continue

    NFR_ID=$(printf "NFR-%04d" "$next_num")

    # Parse enforced field (case-insensitive)
    local_tests="none"
    local_ci="none"
    if echo "$enforced" | grep -qi "test"; then
        local_tests="yes"
    fi
    if echo "$enforced" | grep -qi "ci"; then
        local_ci="yes"
    fi

    {
        printf '\n## %s: %s\n' "$NFR_ID" "$statement"
        printf -- '- Category: %s\n' "$category"
        printf -- '- Statement: %s\n' "$statement"
        printf -- '- Applies to: %s projects\n' "$section"
        printf -- '- How to measure: %s\n' "$measure"
        printf -- '- Where enforced:\n'
        printf -- '  - Tests: %s\n' "$local_tests"
        printf -- '  - CI: %s\n' "$local_ci"
        printf -- '- Current status: proposed\n'
        printf -- '- Notes: Auto-generated from NFR catalog (%s, %s)\n' "$catalog_id" "$priority"
    } >> "$NFR_FILE"

    echo -e "${GREEN}✓${NC} Created ${BOLD}${NFR_ID}${NC}: ${statement}"
    next_num=$((next_num + 1))
    written=$((written + 1))
done <<< "$INPUT"

echo ""
echo -e "${BOLD}Written ${written} NFR(s) to ${NFR_FILE}${NC}"
