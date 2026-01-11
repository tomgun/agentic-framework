#!/usr/bin/env bash
# validate_framework.sh - Validate framework acceptance criteria
#
# Runs automated checks against the framework's own acceptance criteria.
# Used to verify a framework release meets all defined capabilities.
#
# Usage:
#   bash tests/validate_framework.sh [--verbose]
#
# Exit codes:
#   0 - All checks pass
#   1 - One or more checks failed
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERBOSE="${1:-}"

PASSED=0
FAILED=0
WARNINGS=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
  echo -e "${GREEN}✓${NC} $1"
  PASSED=$((PASSED + 1))
}

fail() {
  echo -e "${RED}✗${NC} $1"
  FAILED=$((FAILED + 1))
}

warn() {
  echo -e "${YELLOW}⚠${NC} $1"
  WARNINGS=$((WARNINGS + 1))
}

info() {
  if [[ "$VERBOSE" == "--verbose" ]]; then
    echo "  → $1"
  fi
}

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "AGENTIC AI FRAMEWORK - ACCEPTANCE CRITERIA VALIDATION"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Framework root: ${FRAMEWORK_ROOT}"
echo "Version: $(cat ${FRAMEWORK_ROOT}/VERSION)"
echo ""

# ============================================================
# F-0001: Project Initialization
# ============================================================
echo "--- F-0001: Project Initialization ---"

if [[ -f "${FRAMEWORK_ROOT}/install.sh" ]]; then
  pass "install.sh exists"
else
  fail "install.sh missing"
fi

if [[ -x "${FRAMEWORK_ROOT}/install.sh" ]]; then
  pass "install.sh is executable"
else
  fail "install.sh is not executable"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/init/init_playbook.md" ]]; then
  pass "init_playbook.md exists"
else
  fail "init_playbook.md missing"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/init/scaffold.sh" ]]; then
  pass "scaffold.sh exists"
else
  fail "scaffold.sh missing"
fi

# ============================================================
# F-0002: Profile Selection
# ============================================================
echo ""
echo "--- F-0002: Profile Selection ---"

if grep -q "core" "${FRAMEWORK_ROOT}/.agentic/init/init_playbook.md" 2>/dev/null; then
  pass "Core profile documented in init_playbook"
else
  fail "Core profile not documented"
fi

if grep -qi "core\+pm\|core+product" "${FRAMEWORK_ROOT}/.agentic/init/init_playbook.md" 2>/dev/null; then
  pass "Core+PM profile documented in init_playbook"
else
  fail "Core+PM profile not documented"
fi

# ============================================================
# F-0006: Acceptance-Driven Development
# ============================================================
echo ""
echo "--- F-0006: Acceptance-Driven Development ---"

if grep -q "Acceptance-Driven Development" "${FRAMEWORK_ROOT}/.agentic/PRINCIPLES.md" 2>/dev/null; then
  pass "Acceptance-Driven Development in PRINCIPLES.md"
else
  fail "Acceptance-Driven Development not in PRINCIPLES.md"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/workflows/spec_evolution.md" ]]; then
  pass "spec_evolution.md workflow exists"
else
  fail "spec_evolution.md missing"
fi

if grep -q "development_mode: standard" "${FRAMEWORK_ROOT}/.agentic/init/STACK.template.md" 2>/dev/null; then
  pass "STACK.template defaults to 'standard' mode"
else
  fail "STACK.template does not default to 'standard'"
fi

# ============================================================
# F-0007: Small Batch Development
# ============================================================
echo ""
echo "--- F-0007: Small Batch Development ---"

if grep -q "Small Batch Development" "${FRAMEWORK_ROOT}/.agentic/PRINCIPLES.md" 2>/dev/null; then
  pass "Small Batch Development in PRINCIPLES.md"
else
  fail "Small Batch Development not in PRINCIPLES.md"
fi

if grep -q "Small Batch" "${FRAMEWORK_ROOT}/.agentic/agents/shared/agent_operating_guidelines.md" 2>/dev/null; then
  pass "Small Batch in agent_operating_guidelines.md"
else
  fail "Small Batch not in agent_operating_guidelines.md"
fi

if grep -q "batch size" "${FRAMEWORK_ROOT}/.agentic/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "Batch size check in pre-commit-check.sh"
else
  fail "Batch size check missing from pre-commit-check.sh"
fi

# ============================================================
# F-0013: Smoke Testing
# ============================================================
echo ""
echo "--- F-0013: Smoke Testing ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/checklists/smoke_testing.md" ]]; then
  pass "smoke_testing.md checklist exists"
else
  fail "smoke_testing.md missing"
fi

if grep -qi "smoke" "${FRAMEWORK_ROOT}/.agentic/checklists/before_commit.md" 2>/dev/null; then
  pass "before_commit.md references smoke testing"
else
  warn "before_commit.md may not reference smoke testing"
fi

# ============================================================
# F-0016: Pre-Commit Quality Gates
# ============================================================
echo ""
echo "--- F-0016: Pre-Commit Quality Gates ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/hooks/pre-commit-check.sh" ]]; then
  pass "pre-commit-check.sh exists"
else
  fail "pre-commit-check.sh missing"
fi

if [[ -x "${FRAMEWORK_ROOT}/.agentic/hooks/pre-commit-check.sh" ]]; then
  pass "pre-commit-check.sh is executable"
else
  fail "pre-commit-check.sh is not executable"
fi

if grep -q "WIP.md" "${FRAMEWORK_ROOT}/.agentic/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "WIP check in pre-commit-check.sh"
else
  fail "WIP check missing from pre-commit-check.sh"
fi

# ============================================================
# F-0021: Session Start Protocol
# ============================================================
echo ""
echo "--- F-0021: Session Start Protocol ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/checklists/session_start.md" ]]; then
  pass "session_start.md checklist exists"
else
  fail "session_start.md missing"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/hooks/session-start.sh" ]]; then
  pass "session-start.sh hook exists"
else
  fail "session-start.sh missing"
fi

# ============================================================
# F-0031: Multi-Agent Coordination
# ============================================================
echo ""
echo "--- F-0031: Multi-Agent Coordination ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/workflows/multi_agent_coordination.md" ]]; then
  pass "multi_agent_coordination.md exists"
else
  fail "multi_agent_coordination.md missing"
fi

if grep -q "worktree" "${FRAMEWORK_ROOT}/.agentic/workflows/multi_agent_coordination.md" 2>/dev/null; then
  pass "Worktree documentation present"
else
  fail "Worktree documentation missing"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/AGENTS_ACTIVE.template.md" ]]; then
  pass "AGENTS_ACTIVE template exists"
else
  fail "AGENTS_ACTIVE template missing"
fi

# ============================================================
# F-0035: Agent Role Definitions
# ============================================================
echo ""
echo "--- F-0035: Agent Role Definitions ---"

ROLES_DIR="${FRAMEWORK_ROOT}/.agentic/agents/roles"
if [[ -d "$ROLES_DIR" ]]; then
  pass "roles directory exists"
else
  fail "roles directory missing"
fi

for role in research_agent planning_agent test_agent implementation_agent review_agent spec_update_agent documentation_agent git_agent; do
  if [[ -f "${ROLES_DIR}/${role}.md" ]]; then
    pass "${role}.md exists"
  else
    fail "${role}.md missing"
  fi
done

# ============================================================
# F-0036: Native Sub-Agent Integration
# ============================================================
echo ""
echo "--- F-0036: Native Sub-Agent Integration ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/agents/claude/sub-agents.md" ]]; then
  pass "Claude sub-agents.md exists"
else
  fail "Claude sub-agents.md missing"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/agents/cursor/agents-setup.md" ]]; then
  pass "Cursor agents-setup.md exists"
else
  fail "Cursor agents-setup.md missing"
fi

if grep -q "cursor-agents" "${FRAMEWORK_ROOT}/.agentic/tools/setup-agent.sh" 2>/dev/null; then
  pass "setup-agent.sh supports cursor-agents"
else
  fail "setup-agent.sh missing cursor-agents support"
fi

if grep -q "pipeline" "${FRAMEWORK_ROOT}/.agentic/tools/setup-agent.sh" 2>/dev/null; then
  pass "setup-agent.sh supports pipeline"
else
  fail "setup-agent.sh missing pipeline support"
fi

# ============================================================
# F-0037: Project Health Monitoring
# ============================================================
echo ""
echo "--- F-0037: Project Health Monitoring ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/tools/project-health.sh" ]]; then
  pass "project-health.sh exists"
  if [[ -x "${FRAMEWORK_ROOT}/.agentic/tools/project-health.sh" ]]; then
    pass "project-health.sh is executable"
  else
    warn "project-health.sh not executable"
  fi
else
  fail "project-health.sh missing"
fi

# ============================================================
# F-0041: Token-Efficient Scripts
# ============================================================
echo ""
echo "--- F-0041: Token-Efficient Scripts ---"

for script in journal.sh status.sh feature.sh blocker.sh; do
  if [[ -f "${FRAMEWORK_ROOT}/.agentic/tools/${script}" ]]; then
    pass "${script} exists"
  else
    fail "${script} missing"
  fi
done

# ============================================================
# F-0051: WIP Tracking
# ============================================================
echo ""
echo "--- F-0051: WIP Tracking ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/tools/wip.sh" ]]; then
  pass "wip.sh exists"
else
  fail "wip.sh missing"
fi

if [[ -x "${FRAMEWORK_ROOT}/.agentic/tools/wip.sh" ]]; then
  pass "wip.sh is executable"
else
  fail "wip.sh is not executable"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/workflows/work_in_progress.md" ]]; then
  pass "work_in_progress.md workflow exists"
else
  fail "work_in_progress.md missing"
fi

# ============================================================
# F-0055: Anti-Hallucination Rules
# ============================================================
echo ""
echo "--- F-0055: Anti-Hallucination Rules ---"

if grep -qi "anti-hallucination\|hallucination" "${FRAMEWORK_ROOT}/.agentic/agents/shared/agent_operating_guidelines.md" 2>/dev/null; then
  pass "Anti-hallucination rules documented"
else
  fail "Anti-hallucination rules not documented"
fi

if grep -qi "non-negotiable" "${FRAMEWORK_ROOT}/.agentic/agents/shared/agent_operating_guidelines.md" 2>/dev/null; then
  pass "NON-NEGOTIABLE marking present"
else
  fail "NON-NEGOTIABLE marking missing"
fi

# ============================================================
# F-0061: DEVELOPER_GUIDE.md
# ============================================================
echo ""
echo "--- F-0061: DEVELOPER_GUIDE.md ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/DEVELOPER_GUIDE.md" ]]; then
  pass "DEVELOPER_GUIDE.md exists"
  LINES=$(wc -l < "${FRAMEWORK_ROOT}/.agentic/DEVELOPER_GUIDE.md" | tr -d ' ')
  if [[ $LINES -gt 500 ]]; then
    pass "DEVELOPER_GUIDE.md is comprehensive (${LINES} lines)"
  else
    warn "DEVELOPER_GUIDE.md may be too short (${LINES} lines)"
  fi
else
  fail "DEVELOPER_GUIDE.md missing"
fi

# ============================================================
# F-0062: START_HERE.md
# ============================================================
echo ""
echo "--- F-0062: START_HERE.md ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/START_HERE.md" ]]; then
  pass "START_HERE.md exists"
else
  fail "START_HERE.md missing"
fi

# ============================================================
# F-0066: Template Quality
# ============================================================
echo ""
echo "--- F-0066: Template Quality ---"

for template in STACK.template.md PRODUCT.template.md; do
  if [[ -f "${FRAMEWORK_ROOT}/.agentic/init/${template}" ]]; then
    pass "${template} exists"
  else
    fail "${template} missing"
  fi
done

# ============================================================
# F-0069: Checklist-Driven Workflows
# ============================================================
echo ""
echo "--- F-0069: Checklist-Driven Workflows ---"

CHECKLISTS=(session_start.md session_end.md feature_implementation.md before_commit.md feature_complete.md smoke_testing.md)
for checklist in "${CHECKLISTS[@]}"; do
  if [[ -f "${FRAMEWORK_ROOT}/.agentic/checklists/${checklist}" ]]; then
    pass "${checklist} checklist exists"
  else
    fail "${checklist} checklist missing"
  fi
done

# ============================================================
# F-0071: Token Economics
# ============================================================
echo ""
echo "--- F-0071: Token Economics ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/init/CONTEXT_PACK.template.md" ]]; then
  pass "CONTEXT_PACK template exists"
else
  fail "CONTEXT_PACK template missing"
fi

for script in journal.sh status.sh; do
  if [[ -f "${FRAMEWORK_ROOT}/.agentic/tools/${script}" ]]; then
    pass "Token-efficient ${script} exists"
  else
    fail "Token-efficient ${script} missing"
  fi
done

# ============================================================
# F-0073: Human-Agent Collaboration
# ============================================================
echo ""
echo "--- F-0073: Human-Agent Collaboration ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/MANUAL_OPERATIONS.md" ]]; then
  pass "MANUAL_OPERATIONS.md exists"
else
  fail "MANUAL_OPERATIONS.md missing"
fi

if grep -qi "human" "${FRAMEWORK_ROOT}/.agentic/agents/shared/agent_operating_guidelines.md" 2>/dev/null; then
  pass "Human collaboration documented in guidelines"
else
  fail "Human collaboration not documented"
fi

# ============================================================
# F-0074: Green Coding
# ============================================================
echo ""
echo "--- F-0074: Green Coding ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/quality/green_coding.md" ]]; then
  pass "green_coding.md exists"
else
  fail "green_coding.md missing"
fi

if grep -qi "green" "${FRAMEWORK_ROOT}/README.md" 2>/dev/null; then
  pass "Green coding in README design principles"
else
  fail "Green coding not in README"
fi

# ============================================================
# F-0077: Emergency Quick Reference
# ============================================================
echo ""
echo "--- F-0077: Emergency Quick Reference ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/EMERGENCY.md" ]]; then
  pass "EMERGENCY.md exists"
else
  fail "EMERGENCY.md missing"
fi

if grep -qi "Tokens Running Out" "${FRAMEWORK_ROOT}/.agentic/EMERGENCY.md" 2>/dev/null; then
  pass "EMERGENCY.md has tokens section"
else
  fail "EMERGENCY.md missing tokens section"
fi

if grep -q "EMERGENCY.md" "${FRAMEWORK_ROOT}/.agentic/START_HERE.md" 2>/dev/null; then
  pass "EMERGENCY.md linked from START_HERE"
else
  fail "EMERGENCY.md not linked from START_HERE"
fi

# ============================================================
# F-0078: Quick Feature & Issue Scripts
# ============================================================
echo ""
echo "--- F-0078: Quick Feature & Issue Scripts ---"

if [[ -x "${FRAMEWORK_ROOT}/.agentic/tools/quick_feature.sh" ]]; then
  pass "quick_feature.sh exists and executable"
else
  fail "quick_feature.sh missing or not executable"
fi

if [[ -x "${FRAMEWORK_ROOT}/.agentic/tools/quick_issue.sh" ]]; then
  pass "quick_issue.sh exists and executable"
else
  fail "quick_issue.sh missing or not executable"
fi

# ============================================================
# F-0079: Issue/Bug Tracking
# ============================================================
echo ""
echo "--- F-0079: Issue/Bug Tracking ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/ISSUES.template.md" ]]; then
  pass "ISSUES.template.md exists"
else
  fail "ISSUES.template.md missing"
fi

if grep -q "ISSUES.template.md" "${FRAMEWORK_ROOT}/.agentic/init/scaffold.sh" 2>/dev/null; then
  pass "Scaffold includes ISSUES.md"
else
  fail "Scaffold missing ISSUES.md"
fi

# ============================================================
# F-0080: Upgrade Marker System
# ============================================================
echo ""
echo "--- F-0080: Upgrade Marker System ---"

if grep -q "upgrade_pending" "${FRAMEWORK_ROOT}/.agentic/tools/upgrade.sh" 2>/dev/null; then
  pass "upgrade.sh creates .upgrade_pending marker"
else
  fail "upgrade.sh missing marker creation"
fi

if grep -q "upgrade_pending" "${FRAMEWORK_ROOT}/.agentic/checklists/session_start.md" 2>/dev/null; then
  pass "session_start.md checks for upgrade marker"
else
  fail "session_start.md missing upgrade check"
fi

if grep -qi "After Framework Upgrade" "${FRAMEWORK_ROOT}/.agentic/agents/shared/agent_operating_guidelines.md" 2>/dev/null; then
  pass "Guidelines have post-upgrade section"
else
  fail "Guidelines missing post-upgrade section"
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "VALIDATION SUMMARY"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo -e "Passed:   ${GREEN}${PASSED}${NC}"
echo -e "Failed:   ${RED}${FAILED}${NC}"
echo -e "Warnings: ${YELLOW}${WARNINGS}${NC}"
echo ""

if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}✅ ALL ACCEPTANCE CRITERIA VALIDATED${NC}"
  exit 0
else
  echo -e "${RED}❌ ${FAILED} ACCEPTANCE CRITERIA FAILED${NC}"
  exit 1
fi

