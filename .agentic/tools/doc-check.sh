#!/usr/bin/env bash
# doc-check.sh: Verify documentation is in sync with tools
#
# Checks:
# 1. All tools in .agentic/tools/ are documented
# 2. All tools referenced in docs actually exist
# 3. No deprecated features are referenced without deprecation notice
#
# Usage:
#   bash .agentic/tools/doc-check.sh          # Check and report
#   bash .agentic/tools/doc-check.sh --fix    # Show what needs fixing

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENTIC_DIR="$ROOT_DIR/.agentic"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ISSUES=0

echo "=== Documentation Sync Check ==="
echo ""

#-----------------------------------------------------------------------------
# Check 1: Tools that exist but aren't documented
#-----------------------------------------------------------------------------
echo -e "${YELLOW}Checking for undocumented tools...${NC}"

undoc_count=0
for tool in "$SCRIPT_DIR"/*.sh "$SCRIPT_DIR"/*.py; do
    [[ -f "$tool" ]] || continue
    name=$(basename "$tool")

    # Skip this script and internal tools
    [[ "$name" == "doc-check.sh" ]] && continue

    # Check if documented in any .md file
    if ! grep -rq "$name" "$AGENTIC_DIR"/*.md "$AGENTIC_DIR"/**/*.md 2>/dev/null; then
        if [[ $undoc_count -eq 0 ]]; then
            echo -e "${RED}Undocumented tools:${NC}"
        fi
        echo "  - $name"
        ((undoc_count++))
    fi
done

if [[ $undoc_count -eq 0 ]]; then
    echo -e "${GREEN}✓ All tools are documented${NC}"
else
    echo ""
    echo -e "${YELLOW}Tip: Add these to .agentic/DEVELOPER_GUIDE.md or relevant workflow docs${NC}"
    ((ISSUES += undoc_count))
fi
echo ""

#-----------------------------------------------------------------------------
# Check 2: Tools referenced in docs but don't exist
#-----------------------------------------------------------------------------
echo -e "${YELLOW}Checking for missing tools referenced in docs...${NC}"

# Known planned/example tools that are documented as TODO or examples
PLANNED_TOOLS=(
    "agents_active.sh"      # Marked as TODO in multi_agent_coordination.md
    "check_agent_conflicts.sh"  # Marked as TODO in multi_agent_coordination.md
    "sync_worktrees.sh"     # Marked as TODO in multi_agent_coordination.md
    "lint_specs.py"         # Example code in spec_format_validation.md
    "setup_ci.sh"           # Example in CI template
    "migrate_formats.sh"    # Hypothetical migration script
    "new_tool.sh"           # Placeholder name in docs
    "new_tool.py"           # Placeholder name in docs
    "setup-new.sh"          # Example entry in FEATURE_REGISTRY
)

is_planned_tool() {
    local tool_name="$1"
    for planned in "${PLANNED_TOOLS[@]}"; do
        [[ "$tool_name" == "$planned" ]] && return 0
    done
    return 1
}

missing_count=0
# Find all tool references in docs
grep -roh '\.agentic/tools/[a-z_-]*\.\(sh\|py\)' "$AGENTIC_DIR"/*.md "$AGENTIC_DIR"/**/*.md 2>/dev/null | sort -u | while read -r tool; do
    tool_name=$(basename "$tool")
    if [[ ! -f "$ROOT_DIR/$tool" ]] && ! is_planned_tool "$tool_name"; then
        if [[ $missing_count -eq 0 ]]; then
            echo -e "${RED}Missing tools (referenced but don't exist):${NC}"
        fi
        echo "  - $tool"
        ((missing_count++))
    fi
done

# Also check the count via a subshell since the while loop creates one
actual_missing=$(grep -roh '\.agentic/tools/[a-z_-]*\.\(sh\|py\)' "$AGENTIC_DIR"/*.md "$AGENTIC_DIR"/**/*.md 2>/dev/null | sort -u | while read -r tool; do
    tool_name=$(basename "$tool")
    if [[ ! -f "$ROOT_DIR/$tool" ]]; then
        # Check if it's a known planned/example tool
        is_planned=false
        for planned in "agents_active.sh" "check_agent_conflicts.sh" "sync_worktrees.sh" \
                       "lint_specs.py" "setup_ci.sh" "migrate_formats.sh" \
                       "new_tool.sh" "new_tool.py" "setup-new.sh"; do
            [[ "$tool_name" == "$planned" ]] && is_planned=true && break
        done
        [[ "$is_planned" == "false" ]] && echo "$tool"
    fi
done | wc -l | tr -d ' ')

if [[ "$actual_missing" -eq 0 ]]; then
    echo -e "${GREEN}✓ All referenced tools exist${NC}"
else
    echo ""
    echo -e "${YELLOW}Tip: Either create these tools or remove references from docs${NC}"
    ((ISSUES += actual_missing))
fi
echo ""

#-----------------------------------------------------------------------------
# Check 3: Deprecated content still referenced
#-----------------------------------------------------------------------------
echo -e "${YELLOW}Checking for deprecated references...${NC}"

# Note: PRD.md is NOT deprecated for Formal profiles (spec/PRD.md is valid)
# Only flag truly deprecated patterns
deprecated_patterns=(
    "continue_here\.py"    # Deprecated in v0.12.0 - use STATUS.md
    "PRODUCT\.md"          # Never existed, likely typo
    "VISION\.md"           # Deprecated - use OVERVIEW.md
)

deprecated_count=0
for pattern in "${deprecated_patterns[@]}"; do
    # Find references that aren't in deprecation notices
    matches=$(grep -rln "$pattern" "$AGENTIC_DIR"/*.md "$AGENTIC_DIR"/**/*.md 2>/dev/null | while read -r file; do
        # Check if file contains "deprecated" near the pattern
        if grep -q "$pattern" "$file" && ! grep -B2 -A2 "$pattern" "$file" | grep -qi "deprecat"; then
            echo "$file"
        fi
    done | sort -u)

    if [[ -n "$matches" ]]; then
        if [[ $deprecated_count -eq 0 ]]; then
            echo -e "${RED}Deprecated content still referenced:${NC}"
        fi
        echo "  Pattern '$pattern' in:"
        echo "$matches" | sed 's/^/    - /'
        ((deprecated_count++))
    fi
done

if [[ $deprecated_count -eq 0 ]]; then
    echo -e "${GREEN}✓ No deprecated content found${NC}"
else
    ((ISSUES += deprecated_count))
fi
echo ""

#-----------------------------------------------------------------------------
# Summary
#-----------------------------------------------------------------------------
echo "==================================="
if [[ $ISSUES -eq 0 ]]; then
    echo -e "${GREEN}Documentation is in sync!${NC}"
    exit 0
else
    echo -e "${RED}Found $ISSUES documentation issue(s)${NC}"
    echo ""
    echo "To fix:"
    echo "  1. Document new tools in .agentic/DEVELOPER_GUIDE.md"
    echo "  2. Remove or create missing tool references"
    echo "  3. Update deprecated references"
    exit 1
fi
