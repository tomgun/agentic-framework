#!/usr/bin/env bash
# nfr-migrate.sh — Migrate old ## NFR Compliance section to inline ### NFR Constraints
#
# Moves NFR entries from the separate ## NFR Compliance section into
# ## Acceptance Criteria as a ### NFR Constraints (P1 — required) group.
#
# For shipped features: creates a migration entry via migration.sh first.
# For in-progress/planned features: modifies directly.
#
# Usage:
#   bash .agentic/lib/tools/nfr-migrate.sh F-XXXX [--dry-run]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../paths.sh"
cd "$PROJECT_ROOT"

FEATURE_ID="${1:-}"
DRY_RUN=0
[[ "${2:-}" == "--dry-run" ]] && DRY_RUN=1

if [[ -z "$FEATURE_ID" ]]; then
    echo "Usage: bash .agentic/lib/tools/nfr-migrate.sh <F-XXXX> [--dry-run]"
    exit 0
fi

ACC_FILE=".agentic/spec/acceptance/${FEATURE_ID}.md"
FEATURES_FILE=".agentic/spec/FEATURES.md"

if [[ ! -f "$ACC_FILE" ]]; then
    echo "Error: Acceptance file not found: $ACC_FILE"
    exit 1
fi

# Check if old ## NFR Compliance section exists
if ! grep -qE '^## NFR Compliance' "$ACC_FILE" 2>/dev/null; then
    echo "No ## NFR Compliance section found in $ACC_FILE — nothing to migrate."
    exit 0
fi

# Check if already has ### NFR Constraints
if grep -qE '^### NFR Constraints' "$ACC_FILE" 2>/dev/null; then
    echo "Warning: $ACC_FILE already has ### NFR Constraints section."
    echo "Manual review needed to avoid duplicate ACs."
    exit 1
fi

# Extract NFR entries from the old section
nfr_lines=$(sed -n '/^## NFR Compliance/,/^## /p' "$ACC_FILE" | grep -E '^\s*-\s' | head -20)

if [[ -z "$nfr_lines" ]]; then
    echo "## NFR Compliance section exists but has no entries. Removing empty section."
    if [[ "$DRY_RUN" -eq 0 ]]; then
        # Remove the empty section
        sed -i '/^## NFR Compliance/,/^## /{/^## NFR Compliance/d;/^## /!d;}' "$ACC_FILE"
        echo "Done. Empty section removed."
    else
        echo "[DRY RUN] Would remove empty ## NFR Compliance section."
    fi
    exit 0
fi

# For shipped features: create migration entry first
if [[ -f "$FEATURES_FILE" ]]; then
    feat_status=$(grep -A3 "^## ${FEATURE_ID}:" "$FEATURES_FILE" 2>/dev/null | grep -i "status" | head -1)
    if echo "$feat_status" | grep -qi "shipped"; then
        echo "Feature $FEATURE_ID is shipped — creating migration entry first."
        if [[ "$DRY_RUN" -eq 0 ]]; then
            bash "$SCRIPT_DIR/migration.sh" create \
                "nfr_migrate_${FEATURE_ID}" \
                "Migrate ## NFR Compliance to inline ### NFR Constraints for ${FEATURE_ID}" \
                2>/dev/null || {
                echo "Warning: migration.sh failed — proceeding anyway (migration is advisory)."
            }
        else
            echo "[DRY RUN] Would create migration entry."
        fi
    fi
fi

echo ""
echo "Migrating NFR entries to inline format:"
echo "$nfr_lines"
echo ""

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY RUN] Would:"
    echo "  1. Add ### NFR Constraints (P1 — required) before --- after last AC"
    echo "  2. Move NFR entries there as checkbox ACs"
    echo "  3. Remove old ## NFR Compliance section"
    exit 0
fi

# Build the new NFR Constraints section
nfr_section="\n### NFR Constraints (P1 — required)\n"
ac_num=10
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Convert "- [ ] NFR-XXXX: desc" or "- NFR-XXXX: desc" to "- [ ] **AC-0XX**: desc (NFR-XXXX)"
    nfr_id=$(echo "$line" | grep -oE 'NFR-[0-9]+' | head -1)
    desc=$(echo "$line" | sed "s/^[[:space:]]*-[[:space:]]*\(\[[ x]\][[:space:]]*\)\?//" | sed "s/${nfr_id}:[[:space:]]*//" | sed "s/^[[:space:]]*//")
    if [[ -n "$nfr_id" ]]; then
        nfr_section+="- [ ] **AC-0${ac_num}**: ${desc} (${nfr_id})\n"
        ac_num=$((ac_num + 1))
    fi
done <<< "$nfr_lines"

# Find the line before the first --- after ## Acceptance Criteria to insert
# Actually, insert before ## Verification or ## Out of Scope or the end of AC section
insert_before=$(grep -n '^## Verification\|^## Out of Scope\|^## NFR Compliance' "$ACC_FILE" | head -1 | cut -d: -f1)

if [[ -n "$insert_before" ]]; then
    # Insert NFR Constraints section before the found line
    sed -i "${insert_before}i\\${nfr_section}" "$ACC_FILE"
fi

# Remove old ## NFR Compliance section
sed -i '/^## NFR Compliance/,/^## /{/^## NFR Compliance/d;/^---$/d;/^## /!d;}' "$ACC_FILE"

echo "Migration complete. Review: $ACC_FILE"
