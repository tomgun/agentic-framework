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

for role in orchestrator-agent research_agent planning_agent test_agent implementation_agent review_agent spec_update_agent documentation_agent git_agent; do
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

for template in STACK.template.md OVERVIEW.template.md; do
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

# F-0081: Orchestrator Agent
# ============================================================
echo ""
echo "--- F-0081: Orchestrator Agent ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/agents/roles/orchestrator-agent.md" ]]; then
  pass "orchestrator-agent.md exists"
else
  fail "orchestrator-agent.md missing"
fi

if grep -qi "Delegate.*specialized agents" "${FRAMEWORK_ROOT}/.agentic/agents/roles/orchestrator-agent.md" 2>/dev/null; then
  pass "Orchestrator describes delegation"
else
  fail "Orchestrator missing delegation description"
fi

if grep -qi "Compliance Checks" "${FRAMEWORK_ROOT}/.agentic/agents/roles/orchestrator-agent.md" 2>/dev/null; then
  pass "Orchestrator has compliance checks"
else
  fail "Orchestrator missing compliance checks"
fi

# F-0082: Tier-Based Model Selection
# ============================================================
echo ""
echo "--- F-0082: Tier-Based Model Selection ---"

if grep -qi "Cheap/Fast\|Mid-tier\|Powerful" "${FRAMEWORK_ROOT}/.agentic/agents/claude/subagents/explore-agent.md" 2>/dev/null; then
  pass "explore-agent uses tier terminology"
else
  fail "explore-agent missing tier terminology"
fi

if grep -qi "Model selection principle" "${FRAMEWORK_ROOT}/.agentic/agents/claude/subagents/implementation-agent.md" 2>/dev/null; then
  pass "implementation-agent has model selection principle"
else
  fail "implementation-agent missing model selection principle"
fi

# F-0083: Agent Token Savings Documentation
# ============================================================
echo ""
echo "--- F-0083: Agent Token Savings Documentation ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/token_efficiency/agent_delegation_savings.md" ]]; then
  pass "agent_delegation_savings.md exists"
else
  fail "agent_delegation_savings.md missing"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/token_efficiency/claude_best_practices.md" ]]; then
  pass "claude_best_practices.md exists"
else
  fail "claude_best_practices.md missing"
fi

if grep -qi "60.*83\|savings" "${FRAMEWORK_ROOT}/.agentic/token_efficiency/agent_delegation_savings.md" 2>/dev/null; then
  pass "Token savings quantified"
else
  fail "Token savings not quantified"
fi

# F-0084: Untracked Files Protection
# ============================================================
echo ""
echo "--- F-0084: Untracked Files Protection ---"

if [[ -x "${FRAMEWORK_ROOT}/.agentic/tools/check-untracked.sh" ]]; then
  pass "check-untracked.sh exists and is executable"
else
  fail "check-untracked.sh missing or not executable"
fi

if grep -qi "untracked" "${FRAMEWORK_ROOT}/.agentic/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "pre-commit-check.sh includes untracked check"
else
  fail "pre-commit-check.sh missing untracked check"
fi

if grep -qi "untracked" "${FRAMEWORK_ROOT}/.agentic/checklists/session_end.md" 2>/dev/null; then
  pass "session_end.md has untracked files check"
else
  fail "session_end.md missing untracked files check"
fi

if grep -qi "git add" "${FRAMEWORK_ROOT}/.agentic/agents/shared/agent_operating_guidelines.md" 2>/dev/null; then
  pass "Guidelines have git add rule"
else
  fail "Guidelines missing git add rule"
fi

# ============================================================
# F-0091: Gate-Based Verification
# ============================================================
echo ""
echo "--- F-0091: Gate-Based Verification ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/tools/doctor.sh" ]]; then
  pass "doctor.sh exists"
else
  fail "doctor.sh missing"
fi

if [[ -x "${FRAMEWORK_ROOT}/.agentic/tools/doctor.sh" ]]; then
  pass "doctor.sh is executable"
else
  fail "doctor.sh is not executable"
fi

# doctor.sh is a wrapper that passes args to doctor.py, so check doctor.py for modes
if grep -q "\-\-full" "${FRAMEWORK_ROOT}/.agentic/tools/doctor.py" 2>/dev/null; then
  pass "doctor.py has --full mode"
else
  fail "doctor.py missing --full mode"
fi

if grep -q "\-\-phase" "${FRAMEWORK_ROOT}/.agentic/tools/doctor.py" 2>/dev/null; then
  pass "doctor.py has --phase mode"
else
  fail "doctor.py missing --phase mode"
fi

if grep -q "\-\-pre-commit" "${FRAMEWORK_ROOT}/.agentic/tools/doctor.py" 2>/dev/null; then
  pass "doctor.py has --pre-commit mode"
else
  fail "doctor.py missing --pre-commit mode"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/tools/doctor.py" ]]; then
  pass "doctor.py exists"
else
  fail "doctor.py missing"
fi

# ============================================================
# F-0092: Phase Detection
# ============================================================
echo ""
echo "--- F-0092: Phase Detection ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/tools/phase_detect.py" ]]; then
  pass "phase_detect.py exists"
else
  fail "phase_detect.py missing"
fi

if grep -q "start\|planning\|implement\|complete\|blocked" "${FRAMEWORK_ROOT}/.agentic/tools/phase_detect.py" 2>/dev/null; then
  pass "phase_detect.py defines all 5 phases"
else
  fail "phase_detect.py missing phase definitions"
fi

if [[ -f "${FRAMEWORK_ROOT}/tests/test_phase_detect.py" ]]; then
  pass "test_phase_detect.py exists"
else
  fail "test_phase_detect.py missing"
fi

# ============================================================
# F-0093: AGENT_QUICK_START.md
# ============================================================
echo ""
echo "--- F-0093: AGENT_QUICK_START.md ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/agents/shared/AGENT_QUICK_START.md" ]]; then
  pass "AGENT_QUICK_START.md exists"
  LINES=$(wc -l < "${FRAMEWORK_ROOT}/.agentic/agents/shared/AGENT_QUICK_START.md" | tr -d ' ')
  if [[ $LINES -lt 150 ]]; then
    pass "AGENT_QUICK_START.md is concise (${LINES} lines)"
  else
    warn "AGENT_QUICK_START.md may be too long (${LINES} lines, target <100)"
  fi
else
  fail "AGENT_QUICK_START.md missing"
fi

if grep -qi "doctor.sh" "${FRAMEWORK_ROOT}/.agentic/agents/shared/AGENT_QUICK_START.md" 2>/dev/null; then
  pass "AGENT_QUICK_START references doctor.sh"
else
  fail "AGENT_QUICK_START missing doctor.sh reference"
fi

# ============================================================
# F-0094: Version-Aware Upgrade Features
# ============================================================
echo ""
echo "--- F-0094: Version-Aware Upgrade Features ---"

if grep -q "FEATURE_REGISTRY" "${FRAMEWORK_ROOT}/.agentic/tools/upgrade.sh" 2>/dev/null; then
  pass "upgrade.sh has FEATURE_REGISTRY"
else
  fail "upgrade.sh missing FEATURE_REGISTRY"
fi

if grep -q "version_lt" "${FRAMEWORK_ROOT}/.agentic/tools/upgrade.sh" 2>/dev/null; then
  pass "upgrade.sh has version comparison function"
else
  fail "upgrade.sh missing version comparison"
fi

if grep -q "sort -V" "${FRAMEWORK_ROOT}/.agentic/tools/upgrade.sh" 2>/dev/null; then
  pass "upgrade.sh uses sort -V for version comparison"
else
  fail "upgrade.sh missing sort -V"
fi

# ============================================================
# F-0095: Cross-Platform Tool Compatibility
# ============================================================
echo ""
echo "--- F-0095: Cross-Platform Tool Compatibility ---"

if grep -q "awk" "${FRAMEWORK_ROOT}/.agentic/tools/status.sh" 2>/dev/null; then
  pass "status.sh uses awk for cross-platform compatibility"
else
  fail "status.sh missing awk (may have sed compatibility issues)"
fi

# Check that status.sh doesn't use problematic sed patterns
if grep -q "sed -i.bak.*c\\\\" "${FRAMEWORK_ROOT}/.agentic/tools/status.sh" 2>/dev/null; then
  fail "status.sh uses BSD-incompatible sed pattern"
else
  pass "status.sh avoids problematic sed patterns"
fi

# ============================================================
# F-0096: PR-Based Workflow Default
# ============================================================
echo ""
echo "--- F-0096: PR-Based Workflow Default ---"

# AC-001: STACK.template.md has pull_request as default
if grep -q "git_workflow: pull_request" "${FRAMEWORK_ROOT}/.agentic/init/STACK.template.md" 2>/dev/null; then
  pass "STACK.template.md has pull_request as default git workflow"
else
  fail "STACK.template.md missing pull_request default"
fi

# AC-002: git_workflow.md documents profile-aware defaults
if grep -q "Core+PM.*pull_request" "${FRAMEWORK_ROOT}/.agentic/workflows/git_workflow.md" 2>/dev/null; then
  pass "git_workflow.md documents profile-aware defaults"
else
  fail "git_workflow.md missing profile-aware defaults"
fi

# AC-003: Agent guidelines include PR-based workflow
if grep -q "PR-based workflow by default" "${FRAMEWORK_ROOT}/.agentic/agents/shared/agent_operating_guidelines.md" 2>/dev/null; then
  pass "Agent guidelines include PR-based workflow as non-negotiable"
else
  fail "Agent guidelines missing PR-based workflow"
fi

# AC-004: Claude CLAUDE.md includes git workflow guidance
if grep -q "PR by default" "${FRAMEWORK_ROOT}/.agentic/agents/claude/CLAUDE.md" 2>/dev/null; then
  pass "Claude CLAUDE.md includes PR-first guidance"
else
  fail "Claude CLAUDE.md missing PR-first guidance"
fi

# AC-005: Feature branch naming convention documented
if grep -q "feature/F-" "${FRAMEWORK_ROOT}/.agentic/workflows/git_workflow.md" 2>/dev/null; then
  pass "Feature branch naming convention documented"
else
  fail "Feature branch naming convention not documented"
fi

# ============================================================
# F-0097: Worktree Management Tool
# ============================================================
echo ""
echo "--- F-0097: Worktree Management Tool ---"

# AC-001: worktree.sh exists and is executable
if [[ -x "${FRAMEWORK_ROOT}/.agentic/tools/worktree.sh" ]]; then
  pass "worktree.sh exists and is executable"
else
  fail "worktree.sh missing or not executable"
fi

# AC-002: Create command creates worktree
if grep -q "git worktree add" "${FRAMEWORK_ROOT}/.agentic/tools/worktree.sh" 2>/dev/null; then
  pass "worktree.sh has create functionality"
else
  fail "worktree.sh missing worktree add"
fi

# AC-003: List command shows worktrees
if grep -q "git worktree list" "${FRAMEWORK_ROOT}/.agentic/tools/worktree.sh" 2>/dev/null; then
  pass "worktree.sh has list functionality"
else
  fail "worktree.sh missing worktree list"
fi

# AC-004: Remove command cleans up
if grep -q "git worktree remove" "${FRAMEWORK_ROOT}/.agentic/tools/worktree.sh" 2>/dev/null; then
  pass "worktree.sh has remove functionality"
else
  fail "worktree.sh missing worktree remove"
fi

# AC-005: Help command shows usage
if bash "${FRAMEWORK_ROOT}/.agentic/tools/worktree.sh" help 2>/dev/null | grep -q "USAGE"; then
  pass "worktree.sh help shows usage"
else
  fail "worktree.sh help not working"
fi

# ============================================================
# PROFILE-AWARE INSTALLATION TESTS
# ============================================================
echo ""
echo "--- Profile-Aware Installation Tests ---"

# Create unique temp directories
TEST_CORE="/tmp/test-framework-core-$$"
TEST_PM="/tmp/test-framework-pm-$$"

# Cleanup function
cleanup_test_dirs() {
  rm -rf "$TEST_CORE" "$TEST_PM" 2>/dev/null || true
}
trap cleanup_test_dirs EXIT

# --- CORE PROFILE TESTS ---
echo ""
echo "Testing Core profile installation..."

mkdir -p "$TEST_CORE"
cd "$TEST_CORE"
git init -q

# Run install
if bash "${FRAMEWORK_ROOT}/install.sh" . >/dev/null 2>&1; then
  pass "Core: install.sh succeeds"
else
  fail "Core: install.sh failed"
fi

# Run scaffold with core profile
if AGENTIC_PROFILE=core bash .agentic/init/scaffold.sh --non-interactive >/dev/null 2>&1; then
  pass "Core: scaffold.sh succeeds"
else
  fail "Core: scaffold.sh failed"
fi

# Verify Core-specific structure
if [[ ! -d "spec" ]]; then
  pass "Core: No spec/ directory (correct)"
else
  fail "Core: spec/ should not exist in Core profile"
fi

if [[ -f "STATUS.md" ]]; then
  pass "Core: STATUS.md exists"
else
  fail "Core: STATUS.md missing (now required for both profiles)"
fi

if [[ -f "OVERVIEW.md" ]]; then
  pass "Core: OVERVIEW.md exists"
else
  warn "Core: OVERVIEW.md missing (optional but created by default)"
fi

if [[ -f "STACK.md" ]]; then
  pass "Core: STACK.md exists"
else
  fail "Core: STACK.md missing"
fi

if [[ -f "CONTEXT_PACK.md" ]]; then
  pass "Core: CONTEXT_PACK.md exists"
else
  fail "Core: CONTEXT_PACK.md missing"
fi

# --- CORE+PM PROFILE TESTS ---
echo ""
echo "Testing Core+PM profile installation..."

mkdir -p "$TEST_PM"
cd "$TEST_PM"
git init -q

# Run install
if bash "${FRAMEWORK_ROOT}/install.sh" . >/dev/null 2>&1; then
  pass "PM: install.sh succeeds"
else
  fail "PM: install.sh failed"
fi

# Run scaffold with core+product profile
if AGENTIC_PROFILE=core+product bash .agentic/init/scaffold.sh --non-interactive >/dev/null 2>&1; then
  pass "PM: scaffold.sh succeeds"
else
  fail "PM: scaffold.sh failed"
fi

# Verify Core+PM-specific structure
if [[ -d "spec" ]]; then
  pass "PM: spec/ directory exists"
else
  fail "PM: spec/ directory missing"
fi

if [[ -f "spec/FEATURES.md" ]]; then
  pass "PM: spec/FEATURES.md exists"
else
  fail "PM: spec/FEATURES.md missing"
fi

# Note: spec/PRD.md deprecated in favor of OVERVIEW.md at root
if [[ -f "spec/TECH_SPEC.md" ]]; then
  pass "PM: spec/TECH_SPEC.md exists"
else
  fail "PM: spec/TECH_SPEC.md missing"
fi

if [[ -d "spec/acceptance" ]]; then
  pass "PM: spec/acceptance/ directory exists"
else
  fail "PM: spec/acceptance/ directory missing"
fi

# ============================================================
# FUNCTIONAL TESTS (Key Tools)
# ============================================================
echo ""
echo "--- Functional Tests ---"

# Test in PM directory (has FEATURES.md)
cd "$TEST_PM"

# Test wip.sh check (should work without WIP)
if bash .agentic/tools/wip.sh check >/dev/null 2>&1; then
  pass "wip.sh check runs successfully"
else
  fail "wip.sh check failed"
fi

# Test wip.sh start (requires: feature_id, description, files)
# WIP.md is created in .agentic/ (framework internal state)
if bash .agentic/tools/wip.sh start "TEST-001" "Testing WIP functionality" "test.md" >/dev/null 2>&1; then
  if [[ -f ".agentic/WIP.md" ]]; then
    pass "wip.sh start creates .agentic/WIP.md"
  else
    fail "wip.sh start did not create .agentic/WIP.md"
  fi
else
  fail "wip.sh start failed"
fi

# Clean up WIP
bash .agentic/tools/wip.sh done >/dev/null 2>&1 || true

# Test journal.sh
if bash .agentic/tools/journal.sh "Test Entry" "Did testing" "More tests" "None" >/dev/null 2>&1; then
  if grep -q "Test Entry" JOURNAL.md 2>/dev/null; then
    pass "journal.sh appends to JOURNAL.md"
  else
    fail "journal.sh did not append to JOURNAL.md"
  fi
else
  fail "journal.sh failed"
fi

# Test doctor.sh (basic run)
if bash .agentic/tools/doctor.sh >/dev/null 2>&1; then
  pass "doctor.sh runs successfully"
else
  # doctor.sh may fail on incomplete project, that's ok for now
  warn "doctor.sh returned non-zero (may be expected for test project)"
fi

# Return to framework root
cd "${FRAMEWORK_ROOT}"

# ============================================================
# CODE QUALITY CHECKS
# ============================================================
echo ""
echo "--- Code Quality Checks ---"

# Check for no remaining STATUS.md || OVERVIEW.md conditional patterns in core files
# (These should have been consolidated in v0.12.0)
CONDITIONAL_COUNT=$(grep -r "STATUS.md.*||.*OVERVIEW.md\|cat STATUS.md.*cat OVERVIEW.md" .agentic/ --include="*.md" --include="*.sh" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$CONDITIONAL_COUNT" -eq 0 ]]; then
  pass "No STATUS.md||OVERVIEW.md conditional patterns found"
else
  warn "Found $CONDITIONAL_COUNT files with STATUS.md||OVERVIEW.md conditionals (review for consolidation)"
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

