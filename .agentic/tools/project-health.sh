#!/usr/bin/env bash
# project-health.sh: Manager oversight checks for multi-agent development
#
# Checks:
# - Pipeline status and stalled agents
# - Feature completion and test coverage
# - Documentation currency
# - HUMAN_NEEDED items
#
# Usage:
#   bash .agentic/tools/project-health.sh
#   bash .agentic/tools/project-health.sh --verbose
#
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

VERBOSE="${1:-}"
ISSUES=0
WARNINGS=0

info() {
  if [[ "$VERBOSE" == "--verbose" ]]; then
    echo "  → $1"
  fi
}

warn() {
  echo -e "${YELLOW}⚠${NC} $1"
  WARNINGS=$((WARNINGS + 1))
}

fail() {
  echo -e "${RED}✗${NC} $1"
  ISSUES=$((ISSUES + 1))
}

pass() {
  echo -e "${GREEN}✓${NC} $1"
}

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "PROJECT HEALTH CHECK"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ============================================================
# Pipeline Status
# ============================================================
echo -e "${BLUE}Pipeline Status${NC}"
echo "───────────────────────────────────────────────────────────────"

if [[ -d ".agentic/pipeline" ]]; then
  PIPELINE_COUNT=$(find .agentic/pipeline -name "F-*.md" 2>/dev/null | wc -l | tr -d ' ')
  
  if [[ "$PIPELINE_COUNT" -gt 0 ]]; then
    echo "Active pipelines: $PIPELINE_COUNT"
    
    for pipeline in .agentic/pipeline/F-*.md; do
      if [[ -f "$pipeline" ]]; then
        FEATURE_ID=$(basename "$pipeline" .md | sed 's/-pipeline//')
        
        # Get current phase
        CURRENT=$(grep -E "^- Current agent:" "$pipeline" 2>/dev/null | head -1 | sed 's/.*: //' || echo "unknown")
        PHASE=$(grep -E "^- Phase:" "$pipeline" 2>/dev/null | head -1 | sed 's/.*: //' || echo "unknown")
        
        # Check if stalled (file not modified in 2+ hours)
        if [[ "$(uname)" == "Darwin" ]]; then
          MODIFIED=$(stat -f %m "$pipeline")
        else
          MODIFIED=$(stat -c %Y "$pipeline")
        fi
        NOW=$(date +%s)
        AGE_HOURS=$(( (NOW - MODIFIED) / 3600 ))
        
        if [[ "$AGE_HOURS" -ge 2 && "$PHASE" == "in_progress" ]]; then
          warn "$FEATURE_ID: $CURRENT ($AGE_HOURS hours) - STALLED?"
        elif [[ "$PHASE" == "blocked" ]]; then
          fail "$FEATURE_ID: BLOCKED at $CURRENT"
        elif [[ "$PHASE" == "complete" ]]; then
          pass "$FEATURE_ID: Complete"
        else
          echo "  $FEATURE_ID: $CURRENT ($PHASE)"
        fi
      fi
    done
  else
    echo "  No active pipelines"
  fi
else
  echo "  Pipeline directory not set up"
  echo "  Run: bash .agentic/tools/setup-agent.sh pipeline"
fi

echo ""

# ============================================================
# Feature Status
# ============================================================
echo -e "${BLUE}Feature Status${NC}"
echo "───────────────────────────────────────────────────────────────"

if [[ -f "spec/FEATURES.md" ]]; then
  SHIPPED=$(grep -c "Status: shipped" spec/FEATURES.md 2>/dev/null || echo "0")
  IN_PROGRESS=$(grep -c "Status: in_progress" spec/FEATURES.md 2>/dev/null || echo "0")
  PLANNED=$(grep -c "Status: planned" spec/FEATURES.md 2>/dev/null || echo "0")
  
  echo "  Shipped: $SHIPPED | In Progress: $IN_PROGRESS | Planned: $PLANNED"
  
  # Check for features without acceptance criteria
  FEATURES=$(grep -E "^## F-[0-9]{4}:" spec/FEATURES.md | sed 's/## //' | cut -d: -f1 || true)
  for f in $FEATURES; do
    if [[ ! -f "spec/acceptance/$f.md" ]]; then
      info "Missing acceptance criteria: $f"
    fi
  done
else
  echo "  No spec/FEATURES.md found"
fi

echo ""

# ============================================================
# Test Coverage
# ============================================================
echo -e "${BLUE}Test Coverage${NC}"
echo "───────────────────────────────────────────────────────────────"

if [[ -d "tests" ]] || [[ -d "test" ]] || [[ -d "__tests__" ]]; then
  TEST_COUNT=$(find . -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | wc -l | tr -d ' ')
  echo "  Test files: $TEST_COUNT"
  
  # Check for features marked shipped without corresponding tests
  if [[ -f "spec/FEATURES.md" ]]; then
    SHIPPED_FEATURES=$(grep -B1 "Status: shipped" spec/FEATURES.md | grep "## F-" | sed 's/## //' | cut -d: -f1 || true)
    MISSING_TESTS=0
    for f in $SHIPPED_FEATURES; do
      if ! grep -rq "$f" tests/ test/ __tests__/ 2>/dev/null; then
        info "Shipped feature without tests: $f"
        MISSING_TESTS=$((MISSING_TESTS + 1))
      fi
    done
    if [[ "$MISSING_TESTS" -gt 0 ]]; then
      warn "$MISSING_TESTS shipped features may lack tests"
    fi
  fi
else
  warn "No tests directory found"
fi

echo ""

# ============================================================
# Documentation Currency
# ============================================================
echo -e "${BLUE}Documentation Currency${NC}"
echo "───────────────────────────────────────────────────────────────"

check_doc_age() {
  local file="$1"
  local name="$2"
  local max_days="$3"
  
  if [[ -f "$file" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
      MODIFIED=$(stat -f %m "$file")
    else
      MODIFIED=$(stat -c %Y "$file")
    fi
    NOW=$(date +%s)
    AGE_DAYS=$(( (NOW - MODIFIED) / 86400 ))
    
    if [[ "$AGE_DAYS" -gt "$max_days" ]]; then
      warn "$name not updated in $AGE_DAYS days"
    else
      pass "$name updated $AGE_DAYS days ago"
    fi
  else
    info "$name not found"
  fi
}

# Check JOURNAL.md (resolve location first)
if [[ -f ".agentic-journal/JOURNAL.md" ]]; then
  check_doc_age ".agentic-journal/JOURNAL.md" "JOURNAL.md" 3
elif [[ -f "JOURNAL.md" ]]; then
  check_doc_age "JOURNAL.md" "JOURNAL.md" 3
else
  info "JOURNAL.md not found"
fi
check_doc_age "STATUS.md" "STATUS.md" 7
check_doc_age "CONTEXT_PACK.md" "CONTEXT_PACK.md" 14

echo ""

# ============================================================
# HUMAN_NEEDED Items
# ============================================================
echo -e "${BLUE}Human Needed Items${NC}"
echo "───────────────────────────────────────────────────────────────"

if [[ -f "HUMAN_NEEDED.md" ]]; then
  # Count items (lines starting with - [ ] or ## )
  OPEN_ITEMS=$(grep -c "^\- \[ \]" HUMAN_NEEDED.md 2>/dev/null || echo "0")
  
  if [[ "$OPEN_ITEMS" -gt 0 ]]; then
    warn "$OPEN_ITEMS items need human attention"
    if [[ "$VERBOSE" == "--verbose" ]]; then
      grep "^\- \[ \]" HUMAN_NEEDED.md | head -5
    fi
  else
    pass "No pending human-needed items"
  fi
else
  pass "No HUMAN_NEEDED.md (no blockers)"
fi

echo ""

# ============================================================
# Active Agents
# ============================================================
echo -e "${BLUE}Active Agents${NC}"
echo "───────────────────────────────────────────────────────────────"

if [[ -f "AGENTS_ACTIVE.md" ]]; then
  # Count non-empty rows in the active table
  ACTIVE_AGENTS=$(grep -E "^\| [A-Za-z]" AGENTS_ACTIVE.md | grep -v "Agent" | grep -v "^\| -" | wc -l | tr -d ' ')
  
  if [[ "$ACTIVE_AGENTS" -gt 0 ]]; then
    echo "  $ACTIVE_AGENTS agent(s) registered as active"
    
    if [[ "$VERBOSE" == "--verbose" ]]; then
      grep -E "^\| [A-Za-z]" AGENTS_ACTIVE.md | grep -v "Agent" | grep -v "^\| -"
    fi
  else
    echo "  No agents currently active"
  fi
else
  echo "  AGENTS_ACTIVE.md not set up"
  echo "  Run: bash .agentic/tools/setup-agent.sh pipeline"
fi

echo ""

# ============================================================
# Summary
# ============================================================
echo "═══════════════════════════════════════════════════════════════"
echo "SUMMARY"
echo "═══════════════════════════════════════════════════════════════"
echo ""

if [[ "$ISSUES" -eq 0 && "$WARNINGS" -eq 0 ]]; then
  echo -e "${GREEN}✅ Project health: GOOD${NC}"
elif [[ "$ISSUES" -eq 0 ]]; then
  echo -e "${YELLOW}⚠️ Project health: $WARNINGS warnings${NC}"
else
  echo -e "${RED}❌ Project health: $ISSUES issues, $WARNINGS warnings${NC}"
fi

echo ""

# Add issues to HUMAN_NEEDED if any
if [[ "$ISSUES" -gt 0 ]]; then
  echo "Consider addressing critical issues:"
  echo "  - Check blocked pipelines"
  echo "  - Review stalled agents"
  echo "  - Run: bash .agentic/tools/project-health.sh --verbose"
fi

echo ""

