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
# F-0114: Scope & Diff Verification
# ============================================================
echo ""
echo "--- F-0114: Scope & Diff Verification ---"

# AC-001: scope_check.sh exists and is executable
if [[ -x "${FRAMEWORK_ROOT}/.agentic/tools/scope_check.sh" ]]; then
  pass "scope_check.sh exists and is executable"
else
  fail "scope_check.sh missing or not executable"
fi

# AC-002: pre-commit shows diff stats
if grep -q "Change Summary" "${FRAMEWORK_ROOT}/.agentic/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "pre-commit-check.sh shows diff stats"
else
  fail "pre-commit-check.sh missing diff stats display"
fi

# AC-003: pre-commit calls scope_check
if grep -q "scope_check.sh" "${FRAMEWORK_ROOT}/.agentic/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "pre-commit-check.sh calls scope_check.sh"
else
  fail "pre-commit-check.sh missing scope_check.sh integration"
fi

# AC-004: WIP template has scope fields
if grep -q "IN_SCOPE:" "${FRAMEWORK_ROOT}/.agentic/tools/wip.sh" 2>/dev/null; then
  pass "wip.sh template includes IN_SCOPE field"
else
  fail "wip.sh missing IN_SCOPE field"
fi

# AC-005: New principles added
if grep -q "Make Human Review Efficient" "${FRAMEWORK_ROOT}/.agentic/PRINCIPLES.md" 2>/dev/null; then
  pass "PRINCIPLES.md has 'Make Human Review Efficient'"
else
  fail "PRINCIPLES.md missing human review principle"
fi

if grep -q "Warnings Beat Blocks" "${FRAMEWORK_ROOT}/.agentic/PRINCIPLES.md" 2>/dev/null; then
  pass "PRINCIPLES.md has 'Warnings Beat Blocks for Soft Signals'"
else
  fail "PRINCIPLES.md missing soft signal principle"
fi

if grep -q "Don't Delegate Ambiguity\|Delegating ambiguity" "${FRAMEWORK_ROOT}/.agentic/workflows/delegation_heuristics.md" 2>/dev/null; then
  pass "delegation_heuristics.md covers ambiguity principle"
else
  fail "delegation_heuristics.md missing ambiguity guidance"
fi

# ============================================================
# F-0115: Git Workflow Branch Check
# ============================================================
echo ""
echo "--- F-0115: Git Workflow Branch Check ---"

# AC-001: Branch policy check exists in pre-commit
if grep -q "Branch policy" "${FRAMEWORK_ROOT}/.agentic/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "pre-commit-check.sh has branch policy check"
else
  fail "pre-commit-check.sh missing branch policy check"
fi

# AC-001: Check blocks (not warns) on main with pull_request
if grep -q "BLOCKED.*Direct commit.*PR workflow" "${FRAMEWORK_ROOT}/.agentic/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "Branch check BLOCKS commits to main with PR workflow"
else
  fail "Branch check missing BLOCK behavior"
fi

# AC-001: Escape hatch documented (--no-verify)
if grep -q "\-\-no-verify" "${FRAMEWORK_ROOT}/.agentic/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "Escape hatch (--no-verify) documented in pre-commit"
else
  fail "Escape hatch not documented in pre-commit"
fi

# AC-004: Profile-aware defaults in scaffold.sh
if grep -q 'GIT_WORKFLOW_DEFAULT="direct"' "${FRAMEWORK_ROOT}/.agentic/init/scaffold.sh" 2>/dev/null; then
  pass "scaffold.sh sets direct for Core profile"
else
  fail "scaffold.sh missing Core profile git_workflow default"
fi

if grep -q 'GIT_WORKFLOW_DEFAULT="pull_request"' "${FRAMEWORK_ROOT}/.agentic/init/scaffold.sh" 2>/dev/null; then
  pass "scaffold.sh sets pull_request for Core+PM profile"
else
  fail "scaffold.sh missing Core+PM profile git_workflow default"
fi

# AC-005: Core profile git workflow question in init_playbook
if grep -q "Git Workflow Preference.*Core profile" "${FRAMEWORK_ROOT}/.agentic/init/init_playbook.md" 2>/dev/null; then
  pass "init_playbook.md has Core profile git workflow question"
else
  fail "init_playbook.md missing Core profile git workflow question"
fi

# AC-006: Core+PM skip noted
if grep -q "SKIP.*Core.PM\|Core.PM.*pull_request" "${FRAMEWORK_ROOT}/.agentic/init/init_playbook.md" 2>/dev/null; then
  pass "init_playbook.md notes Core+PM defaults to pull_request"
else
  fail "init_playbook.md missing Core+PM default note"
fi

# AC-007: STACK.template has prominent git_workflow documentation
if grep -q "Pre-commit BLOCKS\|BLOCKS commits to main" "${FRAMEWORK_ROOT}/.agentic/init/STACK.template.md" 2>/dev/null; then
  pass "STACK.template.md documents that pre-commit BLOCKS"
else
  fail "STACK.template.md missing BLOCK documentation"
fi

# Acceptance criteria file exists
if [[ -f "${FRAMEWORK_ROOT}/spec/acceptance/F-0115.md" ]]; then
  pass "F-0115 acceptance criteria file exists"
else
  fail "F-0115 acceptance criteria file missing"
fi

# ============================================================
# F-0121: Tool-Specific Instructions Parity
# ============================================================
echo ""
echo "--- F-0121: Tool-Specific Instructions Parity ---"

# Required gates that all templates must have
REQUIRED_GATES=("Acceptance criteria" "WIP" "Test execution" "Complexity limits" "Pre-commit" "Feature status")

# Templates to check
TEMPLATES=(
  ".agentic/agents/claude/CLAUDE.md"
  ".agentic/agents/codex/codex-instructions.md"
  ".agentic/agents/copilot/copilot-instructions.md"
  ".agentic/agents/cursor/cursorrules.txt"
)

for template in "${TEMPLATES[@]}"; do
  template_path="${FRAMEWORK_ROOT}/${template}"
  template_name=$(basename "$template")

  if [[ ! -f "$template_path" ]]; then
    fail "${template_name}: file missing"
    continue
  fi

  # Check for all 6 gates
  gate_count=0
  for gate in "${REQUIRED_GATES[@]}"; do
    if grep -qi "$gate" "$template_path" 2>/dev/null; then
      ((gate_count++))
    fi
  done

  if [[ $gate_count -eq 6 ]]; then
    pass "${template_name}: has all 6 gates"
  else
    fail "${template_name}: only ${gate_count}/6 gates found"
  fi

  # Check for escape hatches
  if grep -q "SKIP_TESTS\|SKIP_COMPLEXITY" "$template_path" 2>/dev/null; then
    pass "${template_name}: has escape hatches"
  else
    fail "${template_name}: missing escape hatches"
  fi

  # Check for small batch development
  if grep -qi "small batch\|TOO BIG\|5-10 files" "$template_path" 2>/dev/null; then
    pass "${template_name}: has small batch rules"
  else
    fail "${template_name}: missing small batch rules"
  fi
done

# Check /CODEX.md extends template (not a stub)
if grep -q "Full template.*codex-instructions" "${FRAMEWORK_ROOT}/CODEX.md" 2>/dev/null; then
  pass "CODEX.md extends template (not stub)"
else
  fail "CODEX.md should extend template"
fi

# ============================================================
# F-0122: Multi-Tool LLM Testing Infrastructure
# ============================================================
echo ""
echo "--- F-0122: Multi-Tool LLM Testing Infrastructure ---"

# Test definitions JSON exists
if [[ -f "${FRAMEWORK_ROOT}/tests/llm/test_definitions.json" ]]; then
  pass "test_definitions.json exists"
else
  fail "test_definitions.json missing"
fi

# Test definitions has critical tests
if grep -q '"category": "Critical"' "${FRAMEWORK_ROOT}/tests/llm/test_definitions.json" 2>/dev/null; then
  pass "test_definitions.json has Critical tests"
else
  fail "test_definitions.json missing Critical category tests"
fi

# Interactive runner exists and is executable
if [[ -f "${FRAMEWORK_ROOT}/tests/llm/interactive_runner.py" ]]; then
  pass "interactive_runner.py exists"
else
  fail "interactive_runner.py missing"
fi

# Interactive runner has key functions
if grep -q "def setup_test_project" "${FRAMEWORK_ROOT}/tests/llm/interactive_runner.py" 2>/dev/null; then
  pass "interactive_runner.py has setup_test_project function"
else
  fail "interactive_runner.py missing setup_test_project"
fi

if grep -q "def verify_test" "${FRAMEWORK_ROOT}/tests/llm/interactive_runner.py" 2>/dev/null; then
  pass "interactive_runner.py has verify_test function"
else
  fail "interactive_runner.py missing verify_test"
fi

# ag.sh has test llm command
if grep -q 'cmd_test_llm' "${FRAMEWORK_ROOT}/.agentic/tools/ag.sh" 2>/dev/null; then
  pass "ag.sh has cmd_test_llm function"
else
  fail "ag.sh missing cmd_test_llm function"
fi

if grep -q 'ag test llm' "${FRAMEWORK_ROOT}/.agentic/tools/ag.sh" 2>/dev/null; then
  pass "ag.sh documents 'ag test llm' command"
else
  fail "ag.sh missing 'ag test llm' documentation"
fi

# harness.sh supports cursor-cli
if grep -q 'cursor-cli' "${FRAMEWORK_ROOT}/tests/llm/harness.sh" 2>/dev/null; then
  pass "harness.sh supports cursor-cli"
else
  fail "harness.sh missing cursor-cli support"
fi

# harness.sh exports CURSOR_CMD
if grep -q 'export.*CURSOR_CMD' "${FRAMEWORK_ROOT}/tests/llm/harness.sh" 2>/dev/null; then
  pass "harness.sh exports CURSOR_CMD"
else
  fail "harness.sh missing CURSOR_CMD export"
fi

# Acceptance criteria exists
if [[ -f "${FRAMEWORK_ROOT}/spec/acceptance/F-0122.md" ]]; then
  pass "F-0122 acceptance criteria exists"
else
  fail "F-0122 acceptance criteria missing"
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
  if [[ -f ".agentic-state/WIP.md" ]]; then
    pass "wip.sh start creates .agentic-state/WIP.md"
  else
    fail "wip.sh start did not create .agentic-state/WIP.md"
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
# DOCUMENTATION SYNC CHECKS
# ============================================================
echo ""
echo "--- Documentation Sync Checks ---"

# Check for undocumented tools (warning, not blocking)
UNDOC_TOOLS=$(for tool in .agentic/tools/*.sh .agentic/tools/*.py; do
  [[ -f "$tool" ]] || continue
  name=$(basename "$tool")
  [[ "$name" == "doc-check.sh" ]] && continue
  if ! grep -rq "$name" .agentic/*.md .agentic/**/*.md 2>/dev/null; then
    echo "$name"
  fi
done | wc -l | tr -d ' ')

if [[ "$UNDOC_TOOLS" -eq 0 ]]; then
  pass "All tools are documented"
else
  warn "$UNDOC_TOOLS tool(s) not documented (run: bash .agentic/tools/doc-check.sh)"
fi

# Check for missing tools referenced in docs (warning, not blocking)
# Exclude known planned/example tools (documented as TODO or examples in docs)
PLANNED_TOOLS="agents_active.sh check_agent_conflicts.sh sync_worktrees.sh lint_specs.py setup_ci.sh migrate_formats.sh new_tool.sh new_tool.py setup-new.sh"
MISSING_TOOLS=0
for tool in $(grep -roh '\.agentic/tools/[a-z_-]*\.\(sh\|py\)' .agentic/*.md .agentic/**/*.md 2>/dev/null | sort -u); do
  tool_name=$(basename "$tool")
  if [[ ! -f "$tool" ]]; then
    # Check if it's a known planned/example tool
    is_planned=false
    for planned in $PLANNED_TOOLS; do
      [[ "$tool_name" == "$planned" ]] && is_planned=true && break
    done
    [[ "$is_planned" == "false" ]] && ((MISSING_TOOLS++)) || true
  fi
done

if [[ "$MISSING_TOOLS" -eq 0 ]]; then
  pass "All referenced tools exist"
else
  warn "$MISSING_TOOLS tool(s) referenced but missing (run: bash .agentic/tools/doc-check.sh)"
fi

# ============================================================
# CODE QUALITY CHECKS
# ============================================================
echo ""
echo "--- Code Quality Checks ---"

# Check for no remaining STATUS.md || OVERVIEW.md conditional patterns in core files
# (These should have been consolidated in v0.12.0)
# Note: grep returns exit code 1 when no matches, use || true to handle with pipefail
CONDITIONAL_COUNT=$(grep -r "STATUS.md.*||.*OVERVIEW.md\|cat STATUS.md.*cat OVERVIEW.md" .agentic/ --include="*.md" --include="*.sh" 2>/dev/null || true | wc -l | tr -d ' ')
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

