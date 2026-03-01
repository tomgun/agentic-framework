#!/usr/bin/env bash
# check-spec-health.sh: Validate spec health for a single feature or all features
#
# Usage:
#   bash .agentic/tools/check-spec-health.sh F-XXXX    # Single feature
#   bash .agentic/tools/check-spec-health.sh --all      # All features
#
# Checks:
#   - Feature exists in FEATURES.md
#   - Acceptance file has required sections (Tests, Acceptance Criteria, Out of Scope)
#   - Related NFRs listed if applicable
#   - Migration exists for feature
#   - For shipped features: all criteria checked, test files exist
#   - Calls consistency.py and nfr_validator.py for deep checks (if available)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0
INFO=0

check_feature() {
    local FID="$1"
    local local_errors=0
    local local_warnings=0

    echo -e "${BLUE}─── $FID ───${NC}"

    # 1. Feature exists in FEATURES.md
    if ! grep -q "^## ${FID}:" spec/FEATURES.md 2>/dev/null; then
        echo -e "  ${RED}✗${NC} Not found in spec/FEATURES.md"
        local_errors=$((local_errors + 1))
        ERRORS=$((ERRORS + local_errors))
        return
    fi
    echo -e "  ${GREEN}✓${NC} Found in FEATURES.md"

    # Determine status
    local STATUS
    STATUS=$(grep -A5 "^## ${FID}:" spec/FEATURES.md | grep -i "status" | head -1 | sed 's/.*: *//' | tr -d '* ' || echo "unknown")
    echo -e "  ${BLUE}ℹ${NC} Status: $STATUS"

    # 2. Acceptance file exists and has required sections
    local ACCEPT_FILE="spec/acceptance/${FID}.md"
    if [[ -f "$ACCEPT_FILE" ]]; then
        echo -e "  ${GREEN}✓${NC} Acceptance file exists"

        # Check required sections
        for section in "## Tests" "## Acceptance Criteria" "## Out of Scope"; do
            if grep -q "$section" "$ACCEPT_FILE" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} Has '$section' section"
            else
                echo -e "  ${YELLOW}⚠${NC} Missing '$section' section"
                local_warnings=$((local_warnings + 1))
            fi
        done

        # Check NFR Compliance section (info for old features, warning for new)
        if grep -q "### NFR Compliance" "$ACCEPT_FILE" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Has NFR Compliance section"
        else
            echo -e "  ${BLUE}ℹ${NC} No NFR Compliance section (optional for legacy specs)"
            INFO=$((INFO + 1))
        fi

        # For shipped features: check criteria completion and test file existence
        if echo "$STATUS" | grep -qi "shipped"; then
            # Check if all criteria are checked
            local UNCHECKED
            UNCHECKED=$(grep -c "^- \[ \]" "$ACCEPT_FILE" 2>/dev/null || echo "0")
            UNCHECKED=$(echo "$UNCHECKED" | tr -d '[:space:]')
            local CHECKED
            CHECKED=$(grep -c "^- \[x\]" "$ACCEPT_FILE" 2>/dev/null || echo "0")
            CHECKED=$(echo "$CHECKED" | tr -d '[:space:]')

            if [[ "$UNCHECKED" -gt 0 ]]; then
                echo -e "  ${YELLOW}⚠${NC} Shipped but $UNCHECKED unchecked criteria remain ($CHECKED checked)"
                local_warnings=$((local_warnings + 1))
            else
                echo -e "  ${GREEN}✓${NC} All criteria checked ($CHECKED items)"
            fi

            # Check test files referenced in ## Tests section exist
            local TEST_FILES
            TEST_FILES=$(sed -n '/^## Tests/,/^## /p' "$ACCEPT_FILE" | grep -oE '`[^`]+\.(test|spec|_test)\.[a-z]+`|`tests/[^`]+`' | tr -d '`' || true)
            if [[ -n "$TEST_FILES" ]]; then
                while IFS= read -r test_ref; do
                    if [[ -f "$test_ref" ]]; then
                        echo -e "  ${GREEN}✓${NC} Test file exists: $test_ref"
                    else
                        echo -e "  ${YELLOW}⚠${NC} Test file missing: $test_ref"
                        local_warnings=$((local_warnings + 1))
                    fi
                done <<< "$TEST_FILES"
            fi
        fi
    else
        if echo "$STATUS" | grep -qi "shipped\|in.progress"; then
            echo -e "  ${RED}✗${NC} Missing acceptance file (required for $STATUS features)"
            local_errors=$((local_errors + 1))
        else
            echo -e "  ${YELLOW}⚠${NC} No acceptance file yet (status: $STATUS)"
            local_warnings=$((local_warnings + 1))
        fi
    fi

    # 3. Migration exists for feature
    local HAS_MIGRATION
    HAS_MIGRATION=$(grep -rl "$FID" spec/migrations/*.md 2>/dev/null || true)
    if [[ -n "$HAS_MIGRATION" ]]; then
        echo -e "  ${GREEN}✓${NC} Migration found: $(echo "$HAS_MIGRATION" | head -1 | xargs basename)"
    else
        echo -e "  ${BLUE}ℹ${NC} No migration found (info for legacy, required for new features)"
        INFO=$((INFO + 1))
    fi

    ERRORS=$((ERRORS + local_errors))
    WARNINGS=$((WARNINGS + local_warnings))
    echo ""
}

# ── Main ──────────────────────────────────────────────────

if [[ "${1:-}" == "--all" ]]; then
    echo -e "${BLUE}=== Spec Health Check (All Features) ===${NC}"
    echo ""

    if [[ ! -f "spec/FEATURES.md" ]]; then
        echo -e "${RED}No spec/FEATURES.md found${NC}"
        exit 1
    fi

    FEATURES=$(grep -E "^## F-[0-9]+:" spec/FEATURES.md | sed 's/^## //' | cut -d: -f1)
    TOTAL=0
    while IFS= read -r fid; do
        [[ -z "$fid" ]] && continue
        check_feature "$fid"
        TOTAL=$((TOTAL + 1))
    done <<< "$FEATURES"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "Checked: $TOTAL features"
    echo -e "Errors: $ERRORS | Warnings: $WARNINGS | Info: $INFO"

    # Run deep validators if available
    if [[ -f "spec/tools/consistency.py" ]] && command -v python3 >/dev/null 2>&1; then
        echo ""
        echo -e "${BLUE}Running consistency check...${NC}"
        python3 spec/tools/consistency.py 2>/dev/null || echo -e "${YELLOW}⚠ consistency.py had issues${NC}"
    fi

    if [[ -f "spec/tools/nfr_validator.py" ]] && command -v python3 >/dev/null 2>&1; then
        echo ""
        echo -e "${BLUE}Running NFR validation...${NC}"
        python3 spec/tools/nfr_validator.py 2>/dev/null || echo -e "${YELLOW}⚠ nfr_validator.py had issues${NC}"
    fi

    if [[ $ERRORS -gt 0 ]]; then
        exit 1
    fi

elif [[ -n "${1:-}" ]]; then
    FID="$1"
    echo -e "${BLUE}=== Spec Health Check: $FID ===${NC}"
    echo ""
    check_feature "$FID"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "Errors: $ERRORS | Warnings: $WARNINGS | Info: $INFO"

    if [[ $ERRORS -gt 0 ]]; then
        exit 1
    fi
else
    echo "Usage: bash .agentic/tools/check-spec-health.sh <F-XXXX|--all>"
    echo ""
    echo "  F-XXXX    Check a single feature"
    echo "  --all     Check all features in FEATURES.md"
    exit 1
fi
