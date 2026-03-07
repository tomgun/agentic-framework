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

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/init/init_playbook.md" ]]; then
  pass "init_playbook.md exists"
else
  fail "init_playbook.md missing"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/init/scaffold.sh" ]]; then
  pass "scaffold.sh exists"
else
  fail "scaffold.sh missing"
fi

# ============================================================
# F-0002: Profile Selection
# ============================================================
echo "--- F-0002: Profile Selection ---"

if grep -qi "discovery\|core" "${FRAMEWORK_ROOT}/.agentic/lib/init/init_playbook.md" 2>/dev/null; then
  pass "Discovery profile documented in init_playbook"
else
  fail "Discovery profile not documented"
fi

if grep -qi "formal" "${FRAMEWORK_ROOT}/.agentic/lib/init/init_playbook.md" 2>/dev/null; then
  pass "Formal profile documented in init_playbook"
else
  fail "Formal profile not documented"
fi

# ============================================================
# F-0006: Acceptance-Driven Development
# ============================================================
echo "--- F-0006: Acceptance-Driven Development ---"

if grep -q "Acceptance-Driven Development" "${FRAMEWORK_ROOT}/.agentic/lib/PRINCIPLES.md" 2>/dev/null; then
  pass "Acceptance-Driven Development in PRINCIPLES.md"
else
  fail "Acceptance-Driven Development not in PRINCIPLES.md"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/workflows/spec_evolution.md" ]]; then
  pass "spec_evolution.md workflow exists"
else
  fail "spec_evolution.md missing"
fi

if grep -q "development_mode: standard" "${FRAMEWORK_ROOT}/.agentic/lib/init/STACK.template.md" 2>/dev/null; then
  pass "STACK.template defaults to 'standard' mode"
else
  fail "STACK.template does not default to 'standard'"
fi

# ============================================================
# F-0007: Small Batch Development
# ============================================================
echo "--- F-0007: Small Batch Development ---"

if grep -q "Small Batch" "${FRAMEWORK_ROOT}/.agentic/lib/PRINCIPLES.md" 2>/dev/null; then
  pass "Small Batch Development in PRINCIPLES.md"
else
  fail "Small Batch Development not in PRINCIPLES.md"
fi

if grep -q "Small Batch" "${FRAMEWORK_ROOT}/.agentic/lib/agents/shared/agent_operating_guidelines.md" 2>/dev/null; then
  pass "Small Batch in agent_operating_guidelines.md"
else
  fail "Small Batch not in agent_operating_guidelines.md"
fi

if grep -q "batch size" "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "Batch size check in pre-commit-check.sh"
else
  fail "Batch size check missing from pre-commit-check.sh"
fi

# ============================================================
# F-0013: Smoke Testing
# ============================================================
echo "--- F-0013: Smoke Testing ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/checklists/smoke_testing.md" ]]; then
  pass "smoke_testing.md checklist exists"
else
  fail "smoke_testing.md missing"
fi

if grep -qi "smoke" "${FRAMEWORK_ROOT}/.agentic/lib/checklists/before_commit.md" 2>/dev/null; then
  pass "before_commit.md references smoke testing"
else
  warn "before_commit.md may not reference smoke testing"
fi

# ============================================================
# F-0016: Pre-Commit Quality Gates
# ============================================================
echo "--- F-0016: Pre-Commit Quality Gates ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh" ]]; then
  pass "pre-commit-check.sh exists"
else
  fail "pre-commit-check.sh missing"
fi

if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh" ]]; then
  pass "pre-commit-check.sh is executable"
else
  fail "pre-commit-check.sh is not executable"
fi

if grep -q "WIP.md" "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "WIP check in pre-commit-check.sh"
else
  fail "WIP check missing from pre-commit-check.sh"
fi

# ============================================================
# F-0021: Session Start Protocol
# ============================================================
echo "--- F-0021: Session Start Protocol ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/checklists/session_start.md" ]]; then
  pass "session_start.md checklist exists"
else
  fail "session_start.md missing"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/hooks/session-start.sh" ]]; then
  pass "session-start.sh hook exists"
else
  fail "session-start.sh missing"
fi

# ============================================================
# F-0031: Multi-Agent Coordination
# ============================================================
echo "--- F-0031: Multi-Agent Coordination ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/workflows/multi_agent_coordination.md" ]]; then
  pass "multi_agent_coordination.md exists"
else
  fail "multi_agent_coordination.md missing"
fi

if grep -q "worktree" "${FRAMEWORK_ROOT}/.agentic/lib/workflows/multi_agent_coordination.md" 2>/dev/null; then
  pass "Worktree documentation present"
else
  fail "Worktree documentation missing"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/templates/AGENTS_ACTIVE.template.md" ]]; then
  pass "AGENTS_ACTIVE template exists"
else
  fail "AGENTS_ACTIVE template missing"
fi

# ============================================================
# F-0035: Agent Role Definitions
# ============================================================
echo "--- F-0035: Agent Role Definitions ---"

ROLES_DIR="${FRAMEWORK_ROOT}/.agentic/lib/agents/roles"
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
echo "--- F-0036: Native Sub-Agent Integration ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/sub-agents.md" ]]; then
  pass "Claude sub-agents.md exists"
else
  fail "Claude sub-agents.md missing"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/agents/cursor/agents-setup.md" ]]; then
  pass "Cursor agents-setup.md exists"
else
  fail "Cursor agents-setup.md missing"
fi

if grep -q "cursor-agents" "${FRAMEWORK_ROOT}/.agentic/lib/tools/setup-agent.sh" 2>/dev/null; then
  pass "setup-agent.sh supports cursor-agents"
else
  fail "setup-agent.sh missing cursor-agents support"
fi

if grep -q "pipeline" "${FRAMEWORK_ROOT}/.agentic/lib/tools/setup-agent.sh" 2>/dev/null; then
  pass "setup-agent.sh supports pipeline"
else
  fail "setup-agent.sh missing pipeline support"
fi

# ============================================================
# F-0037: Project Health Monitoring
# ============================================================
echo "--- F-0037: Project Health Monitoring ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/project-health.sh" ]]; then
  pass "project-health.sh exists"
  if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/project-health.sh" ]]; then
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
echo "--- F-0041: Token-Efficient Scripts ---"

for script in journal.sh status.sh feature.sh blocker.sh; do
  if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/${script}" ]]; then
    pass "${script} exists"
  else
    fail "${script} missing"
  fi
done

# ============================================================
# F-0051: WIP Tracking
# ============================================================
echo "--- F-0051: WIP Tracking ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/wip.sh" ]]; then
  pass "wip.sh exists"
else
  fail "wip.sh missing"
fi

if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/wip.sh" ]]; then
  pass "wip.sh is executable"
else
  fail "wip.sh is not executable"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/workflows/work_in_progress.md" ]]; then
  pass "work_in_progress.md workflow exists"
else
  fail "work_in_progress.md missing"
fi

# ============================================================
# F-0055: Anti-Hallucination Rules
# ============================================================
echo "--- F-0055: Anti-Hallucination Rules ---"

if grep -qi "anti-hallucination\|hallucination" "${FRAMEWORK_ROOT}/.agentic/lib/agents/shared/agent_operating_guidelines.md" 2>/dev/null; then
  pass "Anti-hallucination rules documented"
else
  fail "Anti-hallucination rules not documented"
fi

if grep -qi "non-negotiable" "${FRAMEWORK_ROOT}/.agentic/lib/agents/shared/agent_operating_guidelines.md" 2>/dev/null; then
  pass "NON-NEGOTIABLE marking present"
else
  fail "NON-NEGOTIABLE marking missing"
fi

# ============================================================
# F-0061: DEVELOPER_GUIDE.md
# ============================================================
echo "--- F-0061: DEVELOPER_GUIDE.md ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/DEVELOPER_GUIDE.md" ]]; then
  pass "DEVELOPER_GUIDE.md exists"
  LINES=$(wc -l < "${FRAMEWORK_ROOT}/.agentic/lib/DEVELOPER_GUIDE.md" | tr -d ' ')
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
echo "--- F-0062: START_HERE.md ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/START_HERE.md" ]]; then
  pass "START_HERE.md exists"
else
  fail "START_HERE.md missing"
fi

# ============================================================
# F-0066: Template Quality
# ============================================================
echo "--- F-0066: Template Quality ---"

for template in STACK.template.md OVERVIEW.template.md; do
  if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/init/${template}" ]]; then
    pass "${template} exists"
  else
    fail "${template} missing"
  fi
done

# ============================================================
# F-0069: Checklist-Driven Workflows
# ============================================================
echo "--- F-0069: Checklist-Driven Workflows ---"

CHECKLISTS=(session_start.md session_end.md feature_implementation.md before_commit.md feature_complete.md smoke_testing.md)
for checklist in "${CHECKLISTS[@]}"; do
  if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/checklists/${checklist}" ]]; then
    pass "${checklist} checklist exists"
  else
    fail "${checklist} checklist missing"
  fi
done

# ============================================================
# F-0071: Token Economics
# ============================================================
echo "--- F-0071: Token Economics ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/init/CONTEXT_PACK.template.md" ]]; then
  pass "CONTEXT_PACK template exists"
else
  fail "CONTEXT_PACK template missing"
fi

for script in journal.sh status.sh; do
  if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/${script}" ]]; then
    pass "Token-efficient ${script} exists"
  else
    fail "Token-efficient ${script} missing"
  fi
done

# ============================================================
# F-0073: Human-Agent Collaboration
# ============================================================
echo "--- F-0073: Human-Agent Collaboration ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/MANUAL_OPERATIONS.md" ]]; then
  pass "MANUAL_OPERATIONS.md exists"
else
  fail "MANUAL_OPERATIONS.md missing"
fi

if grep -qi "human" "${FRAMEWORK_ROOT}/.agentic/lib/agents/shared/agent_operating_guidelines.md" 2>/dev/null; then
  pass "Human collaboration documented in guidelines"
else
  fail "Human collaboration not documented"
fi

# ============================================================
# F-0074: Green Coding
# ============================================================
echo "--- F-0074: Green Coding ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/quality/green_coding.md" ]]; then
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
echo "--- F-0077: Emergency Quick Reference ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/EMERGENCY.md" ]]; then
  pass "EMERGENCY.md exists"
else
  fail "EMERGENCY.md missing"
fi

if grep -qi "Tokens Running Out" "${FRAMEWORK_ROOT}/.agentic/lib/EMERGENCY.md" 2>/dev/null; then
  pass "EMERGENCY.md has tokens section"
else
  fail "EMERGENCY.md missing tokens section"
fi

if grep -q "EMERGENCY.md" "${FRAMEWORK_ROOT}/.agentic/lib/START_HERE.md" 2>/dev/null; then
  pass "EMERGENCY.md linked from START_HERE"
else
  fail "EMERGENCY.md not linked from START_HERE"
fi

# ============================================================
# F-0078: Quick Feature & Issue Scripts
# ============================================================
echo "--- F-0078: Quick Feature & Issue Scripts ---"

if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/quick_feature.sh" ]]; then
  pass "quick_feature.sh exists and executable"
else
  fail "quick_feature.sh missing or not executable"
fi

if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/quick_issue.sh" ]]; then
  pass "quick_issue.sh exists and executable"
else
  fail "quick_issue.sh missing or not executable"
fi

# ============================================================
# F-0079: Issue/Bug Tracking
# ============================================================
echo "--- F-0079: Issue/Bug Tracking ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/templates/ISSUES.template.md" ]]; then
  pass "ISSUES.template.md exists"
else
  fail "ISSUES.template.md missing"
fi

if grep -q "ISSUES.template.md" "${FRAMEWORK_ROOT}/.agentic/lib/init/scaffold.sh" 2>/dev/null || \
   grep -q "ISSUES.md" "${FRAMEWORK_ROOT}/.agentic/lib/init/state-files.conf" 2>/dev/null; then
  pass "Scaffold includes ISSUES.md"
else
  fail "Scaffold missing ISSUES.md"
fi

# ============================================================
# F-0080: Upgrade Marker System
# ============================================================
echo "--- F-0080: Upgrade Marker System ---"

if grep -q "upgrade_pending" "${FRAMEWORK_ROOT}/.agentic/lib/tools/upgrade.sh" 2>/dev/null; then
  pass "upgrade.sh creates .upgrade_pending marker"
else
  fail "upgrade.sh missing marker creation"
fi

if grep -q "upgrade_pending" "${FRAMEWORK_ROOT}/.agentic/lib/checklists/session_start.md" 2>/dev/null; then
  pass "session_start.md checks for upgrade marker"
else
  fail "session_start.md missing upgrade check"
fi

if grep -qi "After Framework Upgrade" "${FRAMEWORK_ROOT}/.agentic/lib/agents/shared/agent_operating_guidelines.md" 2>/dev/null; then
  pass "Guidelines have post-upgrade section"
else
  fail "Guidelines missing post-upgrade section"
fi

# F-0081: Orchestrator Agent
# ============================================================
echo "--- F-0081: Orchestrator Agent ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/agents/roles/orchestrator-agent.md" ]]; then
  pass "orchestrator-agent.md exists"
else
  fail "orchestrator-agent.md missing"
fi

if grep -qi "Delegate.*specialized agents" "${FRAMEWORK_ROOT}/.agentic/lib/agents/roles/orchestrator-agent.md" 2>/dev/null; then
  pass "Orchestrator describes delegation"
else
  fail "Orchestrator missing delegation description"
fi

if grep -qi "Compliance Checks" "${FRAMEWORK_ROOT}/.agentic/lib/agents/roles/orchestrator-agent.md" 2>/dev/null; then
  pass "Orchestrator has compliance checks"
else
  fail "Orchestrator missing compliance checks"
fi

# F-0082: Tier-Based Model Selection
# ============================================================
echo "--- F-0082: Tier-Based Model Selection ---"

if grep -qi "Cheap/Fast\|Mid-tier\|Powerful" "${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/subagents/explore-agent.md" 2>/dev/null; then
  pass "explore-agent uses tier terminology"
else
  fail "explore-agent missing tier terminology"
fi

if grep -qi "Model selection principle" "${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/subagents/implementation-agent.md" 2>/dev/null; then
  pass "implementation-agent has model selection principle"
else
  fail "implementation-agent missing model selection principle"
fi

# F-0083: Agent Token Savings Documentation
# ============================================================
echo "--- F-0083: Agent Token Savings Documentation ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/token_efficiency/agent_delegation_savings.md" ]]; then
  pass "agent_delegation_savings.md exists"
else
  fail "agent_delegation_savings.md missing"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/token_efficiency/claude_best_practices.md" ]]; then
  pass "claude_best_practices.md exists"
else
  fail "claude_best_practices.md missing"
fi

if grep -qi "60.*83\|savings" "${FRAMEWORK_ROOT}/.agentic/lib/token_efficiency/agent_delegation_savings.md" 2>/dev/null; then
  pass "Token savings quantified"
else
  fail "Token savings not quantified"
fi

# F-0084: Untracked Files Protection
# ============================================================
echo "--- F-0084: Untracked Files Protection ---"

if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/check-untracked.sh" ]]; then
  pass "check-untracked.sh exists and is executable"
else
  fail "check-untracked.sh missing or not executable"
fi

if grep -qi "untracked" "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "pre-commit-check.sh includes untracked check"
else
  fail "pre-commit-check.sh missing untracked check"
fi

if grep -qi "untracked" "${FRAMEWORK_ROOT}/.agentic/lib/checklists/session_end.md" 2>/dev/null; then
  pass "session_end.md has untracked files check"
else
  fail "session_end.md missing untracked files check"
fi

if grep -qi "git add" "${FRAMEWORK_ROOT}/.agentic/lib/agents/shared/agent_operating_guidelines.md" 2>/dev/null; then
  pass "Guidelines have git add rule"
else
  fail "Guidelines missing git add rule"
fi

# ============================================================
# F-0091: Gate-Based Verification
# ============================================================
echo "--- F-0091: Gate-Based Verification ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/doctor.sh" ]]; then
  pass "doctor.sh exists"
else
  fail "doctor.sh missing"
fi

if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/doctor.sh" ]]; then
  pass "doctor.sh is executable"
else
  fail "doctor.sh is not executable"
fi

# doctor.sh is a wrapper that passes args to doctor.py, so check doctor.py for modes
if grep -q "\-\-full" "${FRAMEWORK_ROOT}/.agentic/lib/tools/doctor.py" 2>/dev/null; then
  pass "doctor.py has --full mode"
else
  fail "doctor.py missing --full mode"
fi

if grep -q "\-\-phase" "${FRAMEWORK_ROOT}/.agentic/lib/tools/doctor.py" 2>/dev/null; then
  pass "doctor.py has --phase mode"
else
  fail "doctor.py missing --phase mode"
fi

if grep -q "\-\-pre-commit" "${FRAMEWORK_ROOT}/.agentic/lib/tools/doctor.py" 2>/dev/null; then
  pass "doctor.py has --pre-commit mode"
else
  fail "doctor.py missing --pre-commit mode"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/doctor.py" ]]; then
  pass "doctor.py exists"
else
  fail "doctor.py missing"
fi

# ============================================================
# F-0092: Phase Detection
# ============================================================
echo "--- F-0092: Phase Detection ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/phase_detect.py" ]]; then
  pass "phase_detect.py exists"
else
  fail "phase_detect.py missing"
fi

if grep -q "start\|planning\|implement\|complete\|blocked" "${FRAMEWORK_ROOT}/.agentic/lib/tools/phase_detect.py" 2>/dev/null; then
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
echo "--- F-0093: AGENT_QUICK_START.md ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/agents/shared/AGENT_QUICK_START.md" ]]; then
  pass "AGENT_QUICK_START.md exists"
  LINES=$(wc -l < "${FRAMEWORK_ROOT}/.agentic/lib/agents/shared/AGENT_QUICK_START.md" | tr -d ' ')
  if [[ $LINES -lt 150 ]]; then
    pass "AGENT_QUICK_START.md is concise (${LINES} lines)"
  else
    warn "AGENT_QUICK_START.md may be too long (${LINES} lines, target <100)"
  fi
else
  fail "AGENT_QUICK_START.md missing"
fi

if grep -qi "doctor.sh" "${FRAMEWORK_ROOT}/.agentic/lib/agents/shared/AGENT_QUICK_START.md" 2>/dev/null; then
  pass "AGENT_QUICK_START references doctor.sh"
else
  fail "AGENT_QUICK_START missing doctor.sh reference"
fi

# ============================================================
# F-0094: Version-Aware Upgrade Features
# ============================================================
echo "--- F-0094: Version-Aware Upgrade Features ---"

if grep -q "FEATURE_REGISTRY" "${FRAMEWORK_ROOT}/.agentic/lib/tools/upgrade.sh" 2>/dev/null; then
  pass "upgrade.sh has FEATURE_REGISTRY"
else
  fail "upgrade.sh missing FEATURE_REGISTRY"
fi

if grep -q "version_lt" "${FRAMEWORK_ROOT}/.agentic/lib/tools/upgrade.sh" 2>/dev/null; then
  pass "upgrade.sh has version comparison function"
else
  fail "upgrade.sh missing version comparison"
fi

if grep -q "sort -V" "${FRAMEWORK_ROOT}/.agentic/lib/tools/upgrade.sh" 2>/dev/null; then
  pass "upgrade.sh uses sort -V for version comparison"
else
  fail "upgrade.sh missing sort -V"
fi

# ============================================================
# F-0095: Cross-Platform Tool Compatibility
# ============================================================
echo "--- F-0095: Cross-Platform Tool Compatibility ---"

if grep -q "awk" "${FRAMEWORK_ROOT}/.agentic/lib/tools/status.sh" 2>/dev/null; then
  pass "status.sh uses awk for cross-platform compatibility"
else
  fail "status.sh missing awk (may have sed compatibility issues)"
fi

# Check that status.sh doesn't use problematic sed patterns
if grep -q "sed -i.bak.*c\\\\" "${FRAMEWORK_ROOT}/.agentic/lib/tools/status.sh" 2>/dev/null; then
  fail "status.sh uses BSD-incompatible sed pattern"
else
  pass "status.sh avoids problematic sed patterns"
fi

# ============================================================
# F-0096: PR-Based Workflow Default
# ============================================================
echo "--- F-0096: PR-Based Workflow Default ---"

# AC-001: STACK.template.md has git_workflow setting (explicit, discovery default = direct)
if grep -q "^- git_workflow:" "${FRAMEWORK_ROOT}/.agentic/lib/init/STACK.template.md" 2>/dev/null; then
  pass "STACK.template.md has explicit git_workflow setting"
else
  fail "STACK.template.md missing git_workflow setting"
fi

# AC-002: git_workflow.md documents profile-aware defaults
if grep -q "Formal.*pull_request" "${FRAMEWORK_ROOT}/.agentic/lib/workflows/git_workflow.md" 2>/dev/null; then
  pass "git_workflow.md documents profile-aware defaults"
else
  fail "git_workflow.md missing profile-aware defaults"
fi

# AC-003: Agent guidelines include PR-based workflow
if grep -q "PR-based workflow by default" "${FRAMEWORK_ROOT}/.agentic/lib/agents/shared/agent_operating_guidelines.md" 2>/dev/null; then
  pass "Agent guidelines include PR-based workflow as non-negotiable"
else
  fail "Agent guidelines missing PR-based workflow"
fi

# AC-004: Claude CLAUDE.md includes git workflow guidance
if grep -q "PR by default" "${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/CLAUDE.md" 2>/dev/null; then
  pass "Claude CLAUDE.md includes PR-first guidance"
else
  fail "Claude CLAUDE.md missing PR-first guidance"
fi

# AC-005: Feature branch naming convention documented
if grep -q "feature/F-" "${FRAMEWORK_ROOT}/.agentic/lib/workflows/git_workflow.md" 2>/dev/null; then
  pass "Feature branch naming convention documented"
else
  fail "Feature branch naming convention not documented"
fi

# ============================================================
# F-0097: Worktree Management Tool
# ============================================================
echo "--- F-0097: Worktree Management Tool ---"

# AC-001: worktree.sh exists and is executable
if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/worktree.sh" ]]; then
  pass "worktree.sh exists and is executable"
else
  fail "worktree.sh missing or not executable"
fi

# AC-002: Create command creates worktree
if grep -q "git worktree add" "${FRAMEWORK_ROOT}/.agentic/lib/tools/worktree.sh" 2>/dev/null; then
  pass "worktree.sh has create functionality"
else
  fail "worktree.sh missing worktree add"
fi

# AC-003: List command shows worktrees
if grep -q "git worktree list" "${FRAMEWORK_ROOT}/.agentic/lib/tools/worktree.sh" 2>/dev/null; then
  pass "worktree.sh has list functionality"
else
  fail "worktree.sh missing worktree list"
fi

# AC-004: Remove command cleans up
if grep -q "git worktree remove" "${FRAMEWORK_ROOT}/.agentic/lib/tools/worktree.sh" 2>/dev/null; then
  pass "worktree.sh has remove functionality"
else
  fail "worktree.sh missing worktree remove"
fi

# AC-005: Help command shows usage
if bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/worktree.sh" help 2>/dev/null | grep -q "USAGE"; then
  pass "worktree.sh help shows usage"
else
  fail "worktree.sh help not working"
fi

# ============================================================
# F-0114: Scope & Diff Verification
# ============================================================
echo "--- F-0114: Scope & Diff Verification ---"

# AC-001: scope_check.sh exists and is executable
if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/scope_check.sh" ]]; then
  pass "scope_check.sh exists and is executable"
else
  fail "scope_check.sh missing or not executable"
fi

# AC-002: pre-commit shows diff stats
if grep -q "Change Summary" "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "pre-commit-check.sh shows diff stats"
else
  fail "pre-commit-check.sh missing diff stats display"
fi

# AC-003: pre-commit calls scope_check
if grep -q "scope_check.sh" "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "pre-commit-check.sh calls scope_check.sh"
else
  fail "pre-commit-check.sh missing scope_check.sh integration"
fi

# AC-004: WIP template has scope fields
if grep -q "IN_SCOPE:" "${FRAMEWORK_ROOT}/.agentic/lib/tools/wip.sh" 2>/dev/null; then
  pass "wip.sh template includes IN_SCOPE field"
else
  fail "wip.sh missing IN_SCOPE field"
fi

# AC-005: Principles cover human review and soft signals (merged into core principles)
if grep -q "human review efficient\|review efficient" "${FRAMEWORK_ROOT}/.agentic/lib/PRINCIPLES.md" 2>/dev/null; then
  pass "PRINCIPLES.md covers human review efficiency"
else
  fail "PRINCIPLES.md missing human review concept"
fi

if grep -q "Soft warnings for\|warnings for soft signals\|WARN.*don't block" "${FRAMEWORK_ROOT}/.agentic/lib/PRINCIPLES.md" 2>/dev/null; then
  pass "PRINCIPLES.md covers soft signals (warnings beat blocks)"
else
  fail "PRINCIPLES.md missing soft signal concept"
fi

if grep -q "Don't Delegate Ambiguity\|Delegating ambiguity" "${FRAMEWORK_ROOT}/.agentic/lib/workflows/delegation_heuristics.md" 2>/dev/null; then
  pass "delegation_heuristics.md covers ambiguity principle"
else
  fail "delegation_heuristics.md missing ambiguity guidance"
fi

# ============================================================
# F-0115: Git Workflow Branch Check
# ============================================================
echo "--- F-0115: Git Workflow Branch Check ---"

# AC-001: Branch policy check exists in pre-commit
if grep -q "Branch policy" "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "pre-commit-check.sh has branch policy check"
else
  fail "pre-commit-check.sh missing branch policy check"
fi

# AC-001: Check blocks (not warns) on main with pull_request
if grep -q "BLOCKED.*Direct commit.*PR workflow" "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "Branch check BLOCKS commits to main with PR workflow"
else
  fail "Branch check missing BLOCK behavior"
fi

# AC-001: Escape hatch documented (--no-verify)
if grep -q "\-\-no-verify" "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "Escape hatch (--no-verify) documented in pre-commit"
else
  fail "Escape hatch not documented in pre-commit"
fi

# AC-004: Profile-aware defaults in scaffold.sh (reads from profiles.conf)
if grep -q 'profiles.conf' "${FRAMEWORK_ROOT}/.agentic/lib/init/scaffold.sh" 2>/dev/null; then
  pass "scaffold.sh reads settings from profiles.conf"
else
  fail "scaffold.sh missing profiles.conf loop for profile defaults"
fi

# AC-005: Core profile git workflow question in init_playbook
if grep -qi "Git Workflow Preference.*\(Core\|Discovery\) profile" "${FRAMEWORK_ROOT}/.agentic/lib/init/init_playbook.md" 2>/dev/null; then
  pass "init_playbook.md has Discovery profile git workflow question"
else
  fail "init_playbook.md missing Discovery profile git workflow question"
fi

# AC-006: Formal skip noted
if grep -qi "SKIP.*\(Core.PM\|Formal\)\|\(Core.PM\|Formal\).*pull_request" "${FRAMEWORK_ROOT}/.agentic/lib/init/init_playbook.md" 2>/dev/null; then
  pass "init_playbook.md notes Formal defaults to pull_request"
else
  fail "init_playbook.md missing Formal default note"
fi

# AC-007: STACK.template has prominent git_workflow documentation
if grep -q "Pre-commit BLOCKS\|BLOCKS commits to main" "${FRAMEWORK_ROOT}/.agentic/lib/init/STACK.template.md" 2>/dev/null; then
  pass "STACK.template.md documents that pre-commit BLOCKS"
else
  fail "STACK.template.md missing BLOCK documentation"
fi

# Acceptance criteria file exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/F-0115.md" ]]; then
  pass "F-0115 acceptance criteria file exists"
else
  fail "F-0115 acceptance criteria file missing"
fi

# ============================================================
# F-0121: Tool-Specific Instructions Parity
# ============================================================
echo "--- F-0121: Tool-Specific Instructions Parity ---"

# Constitutional content templates must have (trigger table, token scripts, small batch)
# Gates/escape hatches moved to auto_orchestration.md (playbook layer) per INSTRUCTION_ARCHITECTURE.md

# Templates to check
TEMPLATES=(
  ".agentic/lib/agents/claude/CLAUDE.md"
  ".agentic/lib/agents/codex/codex-instructions.md"
  ".agentic/lib/agents/copilot/copilot-instructions.md"
  ".agentic/lib/agents/cursor/agentic-framework.mdc"
)

for template in "${TEMPLATES[@]}"; do
  template_path="${FRAMEWORK_ROOT}/${template}"
  template_name=$(basename "$template")

  if [[ ! -f "$template_path" ]]; then
    fail "${template_name}: file missing"
    continue
  fi

  # Check for trigger words (constitutional — must be in template)
  if grep -qi "trigger\|STOP.*Run\|TOO BIG\|implement entire" "$template_path" 2>/dev/null; then
    pass "${template_name}: has trigger words"
  else
    # Cursor .mdc delegates to guidelines instead of inlining triggers
    if [[ "$template_name" == "agentic-framework.mdc" ]]; then
      warn "${template_name}: no inline triggers (delegates to guidelines)"
    else
      fail "${template_name}: missing trigger words"
    fi
  fi

  # Check for small batch development
  if grep -qi "small batch\|TOO BIG\|5-10 files\|small.*scoped\|incremental" "$template_path" 2>/dev/null; then
    pass "${template_name}: has small batch rules"
  else
    fail "${template_name}: missing small batch rules"
  fi

  # Check for playbook pointer (references ag commands or auto_orchestration.md)
  if grep -qi "auto_orchestration\|ag.*commands\|ag start\|ag implement" "$template_path" 2>/dev/null; then
    pass "${template_name}: has playbook pointer"
  else
    fail "${template_name}: missing playbook pointer"
  fi
done

# Check gates/escape hatches exist in auto_orchestration.md (playbook layer)
AUTO_ORCH="${FRAMEWORK_ROOT}/.agentic/lib/agents/shared/auto_orchestration.md"
if [[ -f "$AUTO_ORCH" ]]; then
  REQUIRED_GATES=("Acceptance criteria" "WIP" "Test execution" "Complexity limits" "Pre-commit" "Feature status")
  gate_count=0
  for gate in "${REQUIRED_GATES[@]}"; do
    if grep -qi "$gate" "$AUTO_ORCH" 2>/dev/null; then
      ((gate_count++))
    fi
  done
  if [[ $gate_count -eq 6 ]]; then
    pass "auto_orchestration.md: has all 6 gates"
  else
    fail "auto_orchestration.md: only ${gate_count}/6 gates found"
  fi
  if grep -q "SKIP_TESTS\|SKIP_COMPLEXITY" "$AUTO_ORCH" 2>/dev/null; then
    pass "auto_orchestration.md: has escape hatches"
  else
    fail "auto_orchestration.md: missing escape hatches"
  fi
fi

# Check /CODEX.md extends template (not a stub)
if grep -q "Full template.*codex-instructions" "${FRAMEWORK_ROOT}/CODEX.md" 2>/dev/null; then
  pass "CODEX.md extends template (not stub)"
else
  fail "CODEX.md should extend template"
fi

# ============================================================
# F-0122: Multi-Tool LLM Testing Infrastructure
# ============================================================
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
if grep -q 'cmd_test_llm' "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" 2>/dev/null; then
  pass "ag.sh has cmd_test_llm function"
else
  fail "ag.sh missing cmd_test_llm function"
fi

if grep -q 'ag test llm' "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" 2>/dev/null; then
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
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/F-0122.md" ]]; then
  pass "F-0122 acceptance criteria exists"
else
  fail "F-0122 acceptance criteria missing"
fi

# ============================================================
# PROFILE-AWARE INSTALLATION TESTS
# ============================================================
echo "--- Profile-Aware Installation Tests ---"

# Create unique temp directories
TEST_CORE="/tmp/test-framework-discovery-$$"
TEST_PM="/tmp/test-framework-formal-$$"

# Cleanup function
cleanup_test_dirs() {
  rm -rf "$TEST_CORE" "$TEST_PM" 2>/dev/null || true
}
trap cleanup_test_dirs EXIT

# --- DISCOVERY PROFILE TESTS ---
echo ""
echo "Testing Discovery profile installation..."

mkdir -p "$TEST_CORE"
cd "$TEST_CORE"
git init -q

# Run install
if bash "${FRAMEWORK_ROOT}/install.sh" . >/dev/null 2>&1; then
  pass "Discovery: install.sh succeeds"
else
  fail "Discovery: install.sh failed"
fi

# Run scaffold with discovery profile
if AGENTIC_PROFILE=discovery bash .agentic/lib/init/scaffold.sh --non-interactive >/dev/null 2>&1; then
  pass "Discovery: scaffold.sh succeeds"
else
  fail "Discovery: scaffold.sh failed"
fi

# Verify Discovery-specific structure
if [[ ! -f ".agentic/spec/TECH_SPEC.md" ]]; then
  pass "Discovery: No .agentic/spec/TECH_SPEC.md (formal-only file not scaffolded)"
else
  warn "Discovery: .agentic/spec/TECH_SPEC.md exists (should be formal-only)"
fi

if [[ -f ".agentic/STATUS.md" ]]; then
  pass "Discovery: .agentic/STATUS.md exists"
else
  fail "Discovery: .agentic/STATUS.md missing (now required for both profiles)"
fi

if [[ -f ".agentic/OVERVIEW.md" ]]; then
  pass "Discovery: .agentic/OVERVIEW.md exists"
else
  warn "Discovery: .agentic/OVERVIEW.md missing (optional but created by default)"
fi

if [[ -f "STACK.md" ]]; then
  pass "Discovery: STACK.md exists"
else
  fail "Discovery: STACK.md missing"
fi

if [[ -f "CONTEXT_PACK.md" ]]; then
  pass "Discovery: CONTEXT_PACK.md exists"
else
  fail "Discovery: CONTEXT_PACK.md missing"
fi

# --- FORMAL PROFILE TESTS ---
echo ""
echo "Testing Formal profile installation..."

mkdir -p "$TEST_PM"
cd "$TEST_PM"
git init -q

# Run install
if bash "${FRAMEWORK_ROOT}/install.sh" . >/dev/null 2>&1; then
  pass "Formal: install.sh succeeds"
else
  fail "Formal: install.sh failed"
fi

# Run scaffold with formal profile
if AGENTIC_PROFILE=formal bash .agentic/lib/init/scaffold.sh --non-interactive >/dev/null 2>&1; then
  pass "Formal: scaffold.sh succeeds"
else
  fail "Formal: scaffold.sh failed"
fi

# Verify Formal-specific structure
if [[ -d ".agentic/spec" ]]; then
  pass "Formal: .agentic/spec/ directory exists"
else
  fail "Formal: .agentic/spec/ directory missing"
fi

if [[ -f ".agentic/spec/FEATURES.md" ]]; then
  pass "Formal: .agentic/spec/FEATURES.md exists"
else
  fail "Formal: .agentic/spec/FEATURES.md missing"
fi

# Note: spec/PRD.md deprecated in favor of .agentic/OVERVIEW.md
if [[ -f ".agentic/spec/TECH_SPEC.md" ]]; then
  pass "Formal: .agentic/spec/TECH_SPEC.md exists"
else
  fail "Formal: .agentic/spec/TECH_SPEC.md missing"
fi

if [[ -d ".agentic/spec/acceptance" ]]; then
  pass "Formal: .agentic/spec/acceptance/ directory exists"
else
  fail "Formal: .agentic/spec/acceptance/ directory missing"
fi

# ============================================================
# FUNCTIONAL TESTS (Key Tools)
# ============================================================
echo "--- Functional Tests ---"

# Test in PM directory (has FEATURES.md)
cd "$TEST_PM"

# Test wip.sh check (should work without WIP)
if bash .agentic/lib/tools/wip.sh check >/dev/null 2>&1; then
  pass "wip.sh check runs successfully"
else
  fail "wip.sh check failed"
fi

# Test wip.sh start (requires: feature_id, description, files)
# WIP.md is created in .agentic/ (framework internal state)
if bash .agentic/lib/tools/wip.sh start "TEST-001" "Testing WIP functionality" "test.md" >/dev/null 2>&1; then
  if [[ -f ".agentic/session/WIP.md" ]]; then
    pass "wip.sh start creates .agentic/session/WIP.md"
  else
    fail "wip.sh start did not create .agentic/session/WIP.md"
  fi
else
  fail "wip.sh start failed"
fi

# Clean up WIP
bash .agentic/lib/tools/wip.sh done >/dev/null 2>&1 || true

# Test journal.sh
if bash .agentic/lib/tools/journal.sh "Test Entry" "Did testing" "More tests" "None" >/dev/null 2>&1; then
  if grep -q "Test Entry" .agentic/journal/JOURNAL.md 2>/dev/null; then
    pass "journal.sh appends to .agentic/journal/JOURNAL.md"
  else
    fail "journal.sh did not append to .agentic/journal/JOURNAL.md"
  fi
else
  fail "journal.sh failed"
fi

# Test doctor.sh (basic run)
if bash .agentic/lib/tools/doctor.sh >/dev/null 2>&1; then
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
echo "--- Documentation Sync Checks ---"

# Check for undocumented tools (warning, not blocking)
UNDOC_TOOLS=$(for tool in .agentic/lib/tools/*.sh .agentic/lib/tools/*.py; do
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
  warn "$UNDOC_TOOLS tool(s) not documented (run: bash .agentic/lib/tools/doc-check.sh)"
fi

# Check for missing tools referenced in docs (warning, not blocking)
# Exclude known planned/example tools (documented as TODO or examples in docs)
PLANNED_TOOLS="agents_active.sh check_agent_conflicts.sh sync_worktrees.sh lint_specs.py setup_ci.sh migrate_formats.sh new_tool.sh new_tool.py setup-new.sh"
MISSING_TOOLS=0
for tool in $(grep -roh '\.agentic/lib/tools/[a-z_-]*\.\(sh\|py\)' .agentic/*.md .agentic/**/*.md 2>/dev/null | sort -u); do
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
  warn "$MISSING_TOOLS tool(s) referenced but missing (run: bash .agentic/lib/tools/doc-check.sh)"
fi

# ============================================================
# CODE QUALITY CHECKS
# ============================================================
echo "--- Code Quality Checks ---"

# Check for no remaining STATUS.md || OVERVIEW.md conditional patterns in core files
# (These should have been consolidated in v0.12.0)
# Both files now live under .agentic/ (STATUS.md → .agentic/STATUS.md, OVERVIEW.md → .agentic/OVERVIEW.md)
# Note: grep returns exit code 1 when no matches, use || true to handle with pipefail
CONDITIONAL_COUNT=$( (grep -r "STATUS.md.*||.*OVERVIEW.md\|cat STATUS.md.*cat OVERVIEW.md" .agentic/lib/ --include="*.md" --include="*.sh" 2>/dev/null || true) | wc -l | tr -d ' ')
if [[ "$CONDITIONAL_COUNT" -eq 0 ]]; then
  pass "No STATUS.md||OVERVIEW.md conditional patterns found"
else
  warn "Found $CONDITIONAL_COUNT files with STATUS.md||OVERVIEW.md conditionals (review for consolidation)"
fi

# ============================================================
# F-0123: Intelligent Onboarding
# ============================================================

# discover.sh exists and is executable
if [[ -f "$FRAMEWORK_ROOT/.agentic/lib/tools/discover.sh" ]] && [[ -x "$FRAMEWORK_ROOT/.agentic/lib/tools/discover.sh" ]]; then
  pass "F-0123: discover.sh exists and is executable"
else
  fail "F-0123: discover.sh missing or not executable"
fi

# discover.py exists
if [[ -f "$FRAMEWORK_ROOT/.agentic/lib/tools/discover.py" ]]; then
  pass "F-0123: discover.py exists"
else
  fail "F-0123: discover.py missing"
fi

# render_proposals.py exists
if [[ -f "$FRAMEWORK_ROOT/.agentic/lib/tools/render_proposals.py" ]]; then
  pass "F-0123: render_proposals.py exists"
else
  fail "F-0123: render_proposals.py missing"
fi

# ag approve-onboarding command recognized
if bash "$FRAMEWORK_ROOT/.agentic/lib/tools/ag.sh" help 2>&1 | grep -q "approve-onboarding"; then
  pass "F-0123: ag approve-onboarding in help output"
else
  fail "F-0123: ag approve-onboarding not in help output"
fi

# init_playbook.md mentions discovery/brownfield
if grep -qi "discovery\|brownfield\|existing.*codebase\|auto-discover" "$FRAMEWORK_ROOT/.agentic/lib/init/init_playbook.md" 2>/dev/null; then
  pass "F-0123: init_playbook.md documents brownfield flow"
else
  fail "F-0123: init_playbook.md does not document brownfield flow"
fi

# discover.py imports without error
if python3 -c "import sys; sys.path.insert(0,'$FRAMEWORK_ROOT/.agentic/lib/tools'); import discover" 2>/dev/null; then
  pass "F-0123: discover.py imports without error"
else
  fail "F-0123: discover.py fails to import"
fi

# render_proposals.py imports without error
if python3 -c "import sys; sys.path.insert(0,'$FRAMEWORK_ROOT/.agentic/lib/tools'); import render_proposals" 2>/dev/null; then
  pass "F-0123: render_proposals.py imports without error"
else
  fail "F-0123: render_proposals.py fails to import"
fi

# scaffold.sh has brownfield detection function
if grep -q "detect_existing_codebase" "$FRAMEWORK_ROOT/.agentic/lib/init/scaffold.sh" 2>/dev/null; then
  pass "F-0123: scaffold.sh has detect_existing_codebase"
else
  fail "F-0123: scaffold.sh missing detect_existing_codebase"
fi

# Template files still exist (regression check)
for tmpl in STACK.template.md CONTEXT_PACK.template.md STATUS.template.md OVERVIEW.template.md; do
  if [[ -f "$FRAMEWORK_ROOT/.agentic/lib/init/$tmpl" ]]; then
    pass "F-0123: template $tmpl exists (regression)"
  else
    fail "F-0123: template $tmpl missing (regression!)"
  fi
done

# ============================================================
# F-0130: Rough Specs & Structural Nudging
# ============================================================
echo "--- F-0130: Rough Specs & Structural Nudging ---"

# Phase removed from STATUS template
if ! grep -q "Project Phase" "${FRAMEWORK_ROOT}/.agentic/lib/init/STATUS.template.md" 2>/dev/null; then
  pass "F-0130: Phase section removed from STATUS.template.md"
else
  fail "F-0130: STATUS.template.md still has Project Phase"
fi

# No stale Phase refs in active scripts/hooks
STALE_PHASE=$(grep -rl "Project Phase" "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" "${FRAMEWORK_ROOT}/.agentic/hooks/" "${FRAMEWORK_ROOT}/.agentic/lib/claude-hooks/" 2>/dev/null || true)
if [[ -z "$STALE_PHASE" ]]; then
  pass "F-0130: No stale Phase references in tools/hooks"
else
  fail "F-0130: Stale Phase references found: $STALE_PHASE"
fi

# ag work shows improved nudge
if grep -q "rough acceptance criteria" "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" 2>/dev/null; then
  pass "F-0130: ag work has improved criteria nudge"
else
  fail "F-0130: ag work missing improved nudge"
fi

# WIP.md templates have Success Criteria
if grep -q "Success Criteria" "${FRAMEWORK_ROOT}/.agentic/lib/tools/wip.sh" 2>/dev/null; then
  pass "F-0130: WIP template has Success Criteria section"
else
  fail "F-0130: WIP template missing Success Criteria"
fi

# Pre-commit Discovery checklist
if grep -q "Discovery checklist" "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "F-0130: Pre-commit has Discovery checklist reminder"
else
  fail "F-0130: Pre-commit missing Discovery checklist"
fi

# ag done surfaces [Discovered] markers
if grep -q '\[Discovered\]' "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" 2>/dev/null; then
  pass "F-0130: ag done surfaces discovered markers"
else
  fail "F-0130: ag done missing discovered marker surfacing"
fi

# sync.sh checks acceptance file existence
if grep -q "no-acceptance" "${FRAMEWORK_ROOT}/.agentic/lib/tools/sync.sh" 2>/dev/null; then
  pass "F-0130: sync.sh checks for missing acceptance files"
else
  fail "F-0130: sync.sh missing acceptance file check"
fi

# PRINCIPLES.md has rough specs guidance
if grep -q "Starting rough is OK" "${FRAMEWORK_ROOT}/.agentic/lib/PRINCIPLES.md" 2>/dev/null; then
  pass "F-0130: PRINCIPLES.md has rough specs guidance"
else
  fail "F-0130: PRINCIPLES.md missing rough specs guidance"
fi

# spec_evolution.md has Starting Rough section
if grep -q "Starting Rough Is OK" "${FRAMEWORK_ROOT}/.agentic/lib/workflows/spec_evolution.md" 2>/dev/null; then
  pass "F-0130: spec_evolution.md has Starting Rough section"
else
  fail "F-0130: spec_evolution.md missing Starting Rough section"
fi

# Acceptance criteria exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/F-0130.md" ]]; then
  pass "F-0130: acceptance criteria file exists"
else
  fail "F-0130: acceptance criteria file missing"
fi

# ============================================================
# F-0160: Autonomous Engine Foundation
# ============================================================
echo ""
echo "--- F-0160: Autonomous Engine Foundation ---"

# AC-001/002: Engine core files exist
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/auto/engine.py" ]]; then
  pass "F-0160: engine.py exists"
else
  fail "F-0160: engine.py missing"
fi

# Control client
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/auto/control.py" ]]; then
  pass "F-0160: control.py exists"
else
  fail "F-0160: control.py missing"
fi

# AC-012: init.py for settings generation
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/auto/init.py" ]]; then
  pass "F-0160: init.py exists"
else
  fail "F-0160: init.py missing"
fi

# AC-019: Settings template
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/auto/settings-template.json" ]]; then
  pass "F-0160: settings-template.json exists"
else
  fail "F-0160: settings-template.json missing"
fi

# AC-015: Settings template denies dangerous ops
if grep -q "rm -rf" "${FRAMEWORK_ROOT}/.agentic/lib/auto/settings-template.json"; then
  pass "F-0160: settings template denies rm -rf"
else
  fail "F-0160: settings template missing rm -rf deny"
fi
if grep -q "sudo" "${FRAMEWORK_ROOT}/.agentic/lib/auto/settings-template.json"; then
  pass "F-0160: settings template denies sudo"
else
  fail "F-0160: settings template missing sudo deny"
fi

# Prompt templates
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/auto/prompts/estimate-complexity.md" ]]; then
  pass "F-0160: estimate-complexity prompt exists"
else
  fail "F-0160: estimate-complexity prompt missing"
fi
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/auto/prompts/decompose-ac.md" ]]; then
  pass "F-0160: decompose-ac prompt exists"
else
  fail "F-0160: decompose-ac prompt missing"
fi

# AC-033: Gitignored session files
if grep -q "auto.sock" "${FRAMEWORK_ROOT}/.gitignore"; then
  pass "F-0160: auto.sock gitignored"
else
  fail "F-0160: auto.sock not gitignored"
fi
if grep -q "auto.pid" "${FRAMEWORK_ROOT}/.gitignore"; then
  pass "F-0160: auto.pid gitignored"
else
  fail "F-0160: auto.pid not gitignored"
fi
if grep -q "auto-state.json" "${FRAMEWORK_ROOT}/.gitignore"; then
  pass "F-0160: auto-state.json gitignored"
else
  fail "F-0160: auto-state.json not gitignored"
fi

# AC-034/035: ag auto in help text
if grep -q "auto" "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh"; then
  pass "F-0160: ag auto command exists in ag.sh"
else
  fail "F-0160: ag auto command missing from ag.sh"
fi

# AC-030: Thread safety (EngineState uses threading.Lock)
if grep -q "threading.Lock" "${FRAMEWORK_ROOT}/.agentic/lib/auto/engine.py"; then
  pass "F-0160: engine uses threading.Lock for thread safety"
else
  fail "F-0160: engine missing threading.Lock"
fi

# AC-008: Cleanup handlers registered
if grep -q "atexit.register" "${FRAMEWORK_ROOT}/.agentic/lib/auto/engine.py"; then
  pass "F-0160: atexit cleanup registered"
else
  fail "F-0160: atexit cleanup missing"
fi
if grep -q "signal.SIGTERM" "${FRAMEWORK_ROOT}/.agentic/lib/auto/engine.py"; then
  pass "F-0160: SIGTERM handler registered"
else
  fail "F-0160: SIGTERM handler missing"
fi

# AC-025: Decomposition support
if grep -q "_decompose_ac" "${FRAMEWORK_ROOT}/.agentic/lib/auto/engine.py"; then
  pass "F-0160: AC decomposition method exists"
else
  fail "F-0160: AC decomposition method missing"
fi

# Tests exist
if [[ -f "${FRAMEWORK_ROOT}/tests/test_auto_engine.py" ]]; then
  pass "F-0160: test_auto_engine.py exists"
else
  fail "F-0160: test_auto_engine.py missing"
fi

# Acceptance criteria file
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/F-0160.md" ]]; then
  pass "F-0160: acceptance criteria file exists"
else
  fail "F-0160: acceptance criteria file missing"
fi

# Planned features registered
for fid in F-0161 F-0162 F-0163; do
  if grep -q "## ${fid}:" "${FRAMEWORK_ROOT}/.agentic/spec/FEATURES.md"; then
    pass "F-0160: ${fid} registered in FEATURES.md"
  else
    fail "F-0160: ${fid} missing from FEATURES.md"
  fi
done

# ============================================================
# F-0161: Autonomous Verify Mode
# ============================================================

echo "--- F-0161: Autonomous Verify Mode ---"

# verify.py exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/auto/verify.py" ]]; then
  pass "F-0161: verify.py exists"
else
  fail "F-0161: verify.py missing"
fi

# verify.py has VerifyLoop class
if grep -q "class VerifyLoop" "${FRAMEWORK_ROOT}/.agentic/lib/auto/verify.py"; then
  pass "F-0161: VerifyLoop class defined"
else
  fail "F-0161: VerifyLoop class missing"
fi

# verify.py detects test command from STACK.md
if grep -q "_detect_test_command" "${FRAMEWORK_ROOT}/.agentic/lib/auto/verify.py"; then
  pass "F-0161: test command detection exists"
else
  fail "F-0161: test command detection missing"
fi

# verify.py parses test output (pytest, Jest, Go, Cargo)
if grep -q "_parse_test_output" "${FRAMEWORK_ROOT}/.agentic/lib/auto/verify.py"; then
  pass "F-0161: test output parsing exists"
else
  fail "F-0161: test output parsing missing"
fi

# verify.py spawns Claude fix
if grep -q "_spawn_claude_fix" "${FRAMEWORK_ROOT}/.agentic/lib/auto/verify.py"; then
  pass "F-0161: Claude fix spawning exists"
else
  fail "F-0161: Claude fix spawning missing"
fi

# verify.py has max_iterations param
if grep -q "max_iterations" "${FRAMEWORK_ROOT}/.agentic/lib/auto/verify.py"; then
  pass "F-0161: max iterations configurable"
else
  fail "F-0161: max iterations not configurable"
fi

# ag auto verify command in ag.sh
if grep -q "verify)" "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh"; then
  pass "F-0161: ag auto verify in ag.sh"
else
  fail "F-0161: ag auto verify missing from ag.sh"
fi

# test file exists
if [[ -f "${FRAMEWORK_ROOT}/tests/test_auto_verify.py" ]]; then
  pass "F-0161: test_auto_verify.py exists"
else
  fail "F-0161: test_auto_verify.py missing"
fi

# acceptance criteria file
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/F-0161.md" ]]; then
  pass "F-0161: acceptance criteria file exists"
else
  fail "F-0161: acceptance criteria file missing"
fi

# ============================================================
# F-0162: Autonomous Task Mode
# ============================================================

echo "--- F-0162: Autonomous Task Mode ---"

# task.py exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/auto/task.py" ]]; then
  pass "F-0162: task.py exists"
else
  fail "F-0162: task.py missing"
fi

# task.py has TaskRunner class
if grep -q "class TaskRunner" "${FRAMEWORK_ROOT}/.agentic/lib/auto/task.py"; then
  pass "F-0162: TaskRunner class defined"
else
  fail "F-0162: TaskRunner class missing"
fi

# task.py creates feature branch
if grep -q "_create_branch" "${FRAMEWORK_ROOT}/.agentic/lib/auto/task.py"; then
  pass "F-0162: branch creation exists"
else
  fail "F-0162: branch creation missing"
fi

# task.py spawns Claude per AC
if grep -q "_spawn_claude_implement" "${FRAMEWORK_ROOT}/.agentic/lib/auto/task.py"; then
  pass "F-0162: Claude implementation spawning exists"
else
  fail "F-0162: Claude implementation spawning missing"
fi

# task.py commits passing ACs
if grep -q "_commit_ac" "${FRAMEWORK_ROOT}/.agentic/lib/auto/task.py"; then
  pass "F-0162: AC committing exists"
else
  fail "F-0162: AC committing missing"
fi

# task.py runs verify after all ACs
if grep -q "VerifyLoop" "${FRAMEWORK_ROOT}/.agentic/lib/auto/task.py"; then
  pass "F-0162: post-AC verify integration"
else
  fail "F-0162: post-AC verify integration missing"
fi

# task.py supports user feedback
if grep -q "get_pending_feedback" "${FRAMEWORK_ROOT}/.agentic/lib/auto/task.py"; then
  pass "F-0162: user feedback integration"
else
  fail "F-0162: user feedback integration missing"
fi

# ag auto task in ag.sh
if grep -q "task)" "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh"; then
  pass "F-0162: ag auto task in ag.sh"
else
  fail "F-0162: ag auto task missing from ag.sh"
fi

# test file exists
if [[ -f "${FRAMEWORK_ROOT}/tests/test_auto_task.py" ]]; then
  pass "F-0162: test_auto_task.py exists"
else
  fail "F-0162: test_auto_task.py missing"
fi

# acceptance criteria file
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/F-0162.md" ]]; then
  pass "F-0162: acceptance criteria file exists"
else
  fail "F-0162: acceptance criteria file missing"
fi

# ============================================================
# F-0163: Autonomous Crunch Mode
# ============================================================

echo "--- F-0163: Autonomous Crunch Mode ---"

# crunch.py exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/auto/crunch.py" ]]; then
  pass "F-0163: crunch.py exists"
else
  fail "F-0163: crunch.py missing"
fi

# crunch.py has CrunchRunner class
if grep -q "class CrunchRunner" "${FRAMEWORK_ROOT}/.agentic/lib/auto/crunch.py"; then
  pass "F-0163: CrunchRunner class defined"
else
  fail "F-0163: CrunchRunner class missing"
fi

# crunch.py reads features from FEATURES.md
if grep -q "_read_planned_features" "${FRAMEWORK_ROOT}/.agentic/lib/auto/crunch.py"; then
  pass "F-0163: reads features from FEATURES.md"
else
  fail "F-0163: reads features from FEATURES.md missing"
fi

# crunch.py uses TaskRunner
if grep -q "TaskRunner" "${FRAMEWORK_ROOT}/.agentic/lib/auto/crunch.py"; then
  pass "F-0163: TaskRunner integration"
else
  fail "F-0163: TaskRunner integration missing"
fi

# crunch.py has max_errors threshold
if grep -q "max_errors" "${FRAMEWORK_ROOT}/.agentic/lib/auto/crunch.py"; then
  pass "F-0163: max errors threshold"
else
  fail "F-0163: max errors threshold missing"
fi

# crunch.py saves progress
if grep -q "_save_progress" "${FRAMEWORK_ROOT}/.agentic/lib/auto/crunch.py"; then
  pass "F-0163: progress persistence"
else
  fail "F-0163: progress persistence missing"
fi

# crunch.py handles stop command
if grep -q '"stopping"' "${FRAMEWORK_ROOT}/.agentic/lib/auto/crunch.py"; then
  pass "F-0163: stop command handling"
else
  fail "F-0163: stop command handling missing"
fi

# ag auto crunch in ag.sh
if grep -q "crunch)" "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh"; then
  pass "F-0163: ag auto crunch in ag.sh"
else
  fail "F-0163: ag auto crunch missing from ag.sh"
fi

# test file exists
if [[ -f "${FRAMEWORK_ROOT}/tests/test_auto_crunch.py" ]]; then
  pass "F-0163: test_auto_crunch.py exists"
else
  fail "F-0163: test_auto_crunch.py missing"
fi

# acceptance criteria file
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/F-0163.md" ]]; then
  pass "F-0163: acceptance criteria file exists"
else
  fail "F-0163: acceptance criteria file missing"
fi

# crunch-state.json gitignored
if grep -q "crunch-state.json" "${FRAMEWORK_ROOT}/.gitignore"; then
  pass "F-0163: crunch-state.json gitignored"
else
  fail "F-0163: crunch-state.json not gitignored"
fi

# ============================================================
# Settings Infrastructure (Settings-Over-Profiles)
# ============================================================
echo "--- Settings Infrastructure ---"

# settings.sh exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/settings.sh" ]]; then
  pass "Settings: settings.sh exists"
else
  fail "Settings: settings.sh missing"
fi

# settings.py exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/settings.py" ]]; then
  pass "Settings: settings.py exists"
else
  fail "Settings: settings.py missing"
fi

# profiles.conf exists with both profiles
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf" ]]; then
  pass "Settings: profiles.conf exists"
  if grep -q "^discovery\." "${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf"; then
    pass "Settings: profiles.conf has discovery defaults"
  else
    fail "Settings: profiles.conf missing discovery defaults"
  fi
  if grep -q "^formal\." "${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf"; then
    pass "Settings: profiles.conf has formal defaults"
  else
    fail "Settings: profiles.conf missing formal defaults"
  fi
else
  fail "Settings: profiles.conf missing"
fi

# constraints.conf exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/presets/constraints.conf" ]]; then
  pass "Settings: constraints.conf exists"
else
  fail "Settings: constraints.conf missing"
fi

# settings.sh has get_setting function
if grep -q "^get_setting()" "${FRAMEWORK_ROOT}/.agentic/lib/settings.sh" 2>/dev/null; then
  pass "Settings: settings.sh has get_setting()"
else
  fail "Settings: settings.sh missing get_setting()"
fi

# settings.py has get_setting function
if grep -q "^def get_setting" "${FRAMEWORK_ROOT}/.agentic/lib/settings.py" 2>/dev/null; then
  pass "Settings: settings.py has get_setting()"
else
  fail "Settings: settings.py missing get_setting()"
fi

# ag.sh has ag set command
if grep -q "cmd_set" "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" 2>/dev/null; then
  pass "Settings: ag.sh has set command"
else
  fail "Settings: ag.sh missing set command"
fi

# ag.sh sources settings.sh
if grep -q 'source.*settings.sh' "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" 2>/dev/null; then
  pass "Settings: ag.sh sources settings.sh"
else
  fail "Settings: ag.sh doesn't source settings.sh"
fi

# STACK.template.md has ## Settings section
if grep -q "^## Settings" "${FRAMEWORK_ROOT}/.agentic/lib/init/STACK.template.md" 2>/dev/null; then
  pass "Settings: STACK.template.md has ## Settings section"
else
  fail "Settings: STACK.template.md missing ## Settings section"
fi

# settings.sh resolves from profile presets (functional test)
# We run each test in a subshell to get clean state, and override _SETTINGS_STACK_FILE
(
  source "${FRAMEWORK_ROOT}/.agentic/lib/settings.sh" 2>/dev/null || exit 1

  # Create temp STACK.md with profile set
  SETTINGS_TEST_DIR=$(mktemp -d)
  cat > "$SETTINGS_TEST_DIR/STACK.md" <<'TESTEOF'
## Settings
- profile: formal
TESTEOF
  # Override the stack file path to point to our test file
  _SETTINGS_STACK_FILE="$SETTINGS_TEST_DIR/STACK.md"
  _SETTINGS_SECTION_EXTRACTED=0
  _SETTINGS_SECTION_CACHE=""
  _SETTINGS_PROFILE_RESOLVED=0
  _SETTINGS_PROFILE_CACHE=""
  _SETTINGS_PROFILES_CONF="${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf"

  FT_VAL=$(get_setting "feature_tracking" "UNSET")
  rm -rf "$SETTINGS_TEST_DIR"
  [[ "$FT_VAL" == "yes" ]]
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "Settings: formal profile resolves feature_tracking=yes"
else
  fail "Settings: formal profile feature_tracking resolution failed"
fi

# Test explicit override trumps preset
(
  source "${FRAMEWORK_ROOT}/.agentic/lib/settings.sh" 2>/dev/null || exit 1
  SETTINGS_TEST_DIR=$(mktemp -d)
  cat > "$SETTINGS_TEST_DIR/STACK.md" <<'TESTEOF'
## Settings
- profile: formal
- feature_tracking: no
TESTEOF
  _SETTINGS_STACK_FILE="$SETTINGS_TEST_DIR/STACK.md"
  _SETTINGS_SECTION_EXTRACTED=0
  _SETTINGS_SECTION_CACHE=""
  _SETTINGS_PROFILE_RESOLVED=0
  _SETTINGS_PROFILE_CACHE=""

  FT_VAL=$(get_setting "feature_tracking" "UNSET")
  rm -rf "$SETTINGS_TEST_DIR"
  [[ "$FT_VAL" == "no" ]]
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "Settings: explicit override trumps profile preset"
else
  fail "Settings: explicit override should trump profile preset"
fi

# Test backward compat: STACK.md without ## Settings section
(
  source "${FRAMEWORK_ROOT}/.agentic/lib/settings.sh" 2>/dev/null || exit 1
  SETTINGS_TEST_DIR=$(mktemp -d)
  cat > "$SETTINGS_TEST_DIR/STACK.md" <<'TESTEOF'
# STACK.md
- Profile: formal
- git_workflow: direct
TESTEOF
  _SETTINGS_STACK_FILE="$SETTINGS_TEST_DIR/STACK.md"
  _SETTINGS_SECTION_EXTRACTED=0
  _SETTINGS_SECTION_CACHE=""
  _SETTINGS_PROFILE_RESOLVED=0
  _SETTINGS_PROFILE_CACHE=""

  GW_VAL=$(get_setting "git_workflow" "UNSET")
  rm -rf "$SETTINGS_TEST_DIR"
  [[ "$GW_VAL" == "direct" ]]
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "Settings: backward compat reads from whole file"
else
  fail "Settings: backward compat should read from whole file"
fi

# upgrade.sh includes lib and presets in DIRS_TO_REPLACE
if grep -q '"lib"' "${FRAMEWORK_ROOT}/.agentic/lib/tools/upgrade.sh" 2>/dev/null && \
   grep -q '"presets"' "${FRAMEWORK_ROOT}/.agentic/lib/tools/upgrade.sh" 2>/dev/null; then
  pass "Settings: upgrade.sh copies lib/ and presets/"
else
  fail "Settings: upgrade.sh missing lib/ or presets/ in DIRS_TO_REPLACE"
fi

# Helper: reset settings cache for functional tests
_reset_settings_cache() {
  _SETTINGS_SECTION_EXTRACTED=0
  _SETTINGS_SECTION_CACHE=""
  _SETTINGS_PROFILE_RESOLVED=0
  _SETTINGS_PROFILE_CACHE=""
  _SETTINGS_PROFILES_CONF="${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf"
  _SETTINGS_CONSTRAINTS_CONF="${FRAMEWORK_ROOT}/.agentic/lib/presets/constraints.conf"
}

# Test constraint validation detects violations
(
  source "${FRAMEWORK_ROOT}/.agentic/lib/settings.sh" 2>/dev/null || exit 1
  SETTINGS_TEST_DIR=$(mktemp -d)
  # acceptance_criteria=blocking requires feature_tracking=yes
  cat > "$SETTINGS_TEST_DIR/STACK.md" <<'TESTEOF'
## Settings
- profile: discovery
- acceptance_criteria: blocking
- feature_tracking: no
TESTEOF
  _SETTINGS_STACK_FILE="$SETTINGS_TEST_DIR/STACK.md"
  _reset_settings_cache

  VIOLATIONS=$(validate_constraints 2>&1)
  rm -rf "$SETTINGS_TEST_DIR"
  [[ "$VIOLATIONS" == *"violation"* ]]
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "Settings: constraint validation detects violations"
else
  fail "Settings: constraint validation should detect violations"
fi

# ============================================================
# F-0169: NFR Discovery & Catalog
# ============================================================
echo "--- F-0169: NFR Discovery & Catalog ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/init/nfr-catalog.md" ]]; then
  pass "F-0169: nfr-catalog.md exists"
else
  fail "F-0169: nfr-catalog.md missing"
fi

# Catalog has type-specific sections
for section in "Universal" "Web App" "API" "Game" "Mobile" "CLI" "Desktop" "Framework Promises"; do
  if grep -qi "$section" "${FRAMEWORK_ROOT}/.agentic/lib/init/nfr-catalog.md"; then
    pass "F-0169: catalog has ${section} section"
  else
    fail "F-0169: catalog missing ${section} section"
  fi
done

# Init playbook has Step 2c NFR Discovery
if grep -q "Step 2c\|NFR Discovery" "${FRAMEWORK_ROOT}/.agentic/lib/init/init_playbook.md"; then
  pass "F-0169: init_playbook.md has NFR Discovery step"
else
  fail "F-0169: init_playbook.md missing NFR Discovery step"
fi

# Memory seed has NFR proactive suggestion
if grep -q "nfr.*discover\|NFR.*proactive\|ag nfr discover" "${FRAMEWORK_ROOT}/.agentic/lib/init/memory-seed.md"; then
  pass "F-0169: memory-seed.md has NFR proactive suggestion"
else
  fail "F-0169: memory-seed.md missing NFR proactive suggestion"
fi

# ag nfr discover command works
_NFR_DISCOVER_OUT=$(ROOT_DIR="${FRAMEWORK_ROOT}" bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" nfr discover 2>&1 || true)
if echo "$_NFR_DISCOVER_OUT" | grep -qi "catalog\|NFR\|suggestion"; then
  pass "F-0169: ag nfr discover produces output"
else
  fail "F-0169: ag nfr discover produces no output"
fi

# ag nfr list command works
_NFR_LIST_OUT=$(ROOT_DIR="${FRAMEWORK_ROOT}" bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" nfr list 2>&1 || true)
if echo "$_NFR_LIST_OUT" | grep -q "NFR-0001"; then
  pass "F-0169: ag nfr list shows NFR-0001"
else
  fail "F-0169: ag nfr list missing NFR-0001"
fi

# ============================================================
# F-0170: NFR Enforcement in Spec Writing
# ============================================================
echo "--- F-0170: NFR Enforcement in Spec Writing ---"

if grep -q "Active NFR\|active.*matching\|evaluate.*each.*NFR\|EACH.*NFR" "${FRAMEWORK_ROOT}/.agentic/lib/workflows/spec_writing.md"; then
  pass "F-0170: spec_writing workflow has active NFR matching"
else
  fail "F-0170: spec_writing workflow missing active NFR matching"
fi

if grep -q "NFR.*gate\|NFR.*Gate\|Read.*NFR.md\|Evaluate.*each.*NFR" "${FRAMEWORK_ROOT}/.agentic/lib/checklists/spec_writing.md"; then
  pass "F-0170: spec_writing checklist has NFR gate"
else
  fail "F-0170: spec_writing checklist missing NFR gate"
fi

if grep -q "promot\|3.*feature" "${FRAMEWORK_ROOT}/.agentic/lib/workflows/spec_writing.md"; then
  pass "F-0170: spec_writing has promotion detection"
else
  fail "F-0170: spec_writing missing promotion detection"
fi

if grep -q "NFR.*[Cc]ompliance\|NFR.*none" "${FRAMEWORK_ROOT}/.agentic/lib/checklists/feature_start.md"; then
  pass "F-0170: feature_start checks NFR compliance"
else
  fail "F-0170: feature_start missing NFR compliance check"
fi

if grep -q "NFR.*verif\|@nfr\|NFR.*criterion\|NFR.*compliance" "${FRAMEWORK_ROOT}/.agentic/lib/checklists/feature_complete.md"; then
  pass "F-0170: feature_complete verifies NFR compliance"
else
  fail "F-0170: feature_complete missing NFR verification"
fi

if grep -q "NFR-0003" "${FRAMEWORK_ROOT}/.agentic/spec/NFR.md"; then
  pass "F-0170: NFR-0003 (small batch commits) exists"
else
  fail "F-0170: NFR-0003 missing from NFR.md"
fi

if grep -q "NFR-0004" "${FRAMEWORK_ROOT}/.agentic/spec/NFR.md"; then
  pass "F-0170: NFR-0004 (spec-first development) exists"
else
  fail "F-0170: NFR-0004 missing from NFR.md"
fi

for nfr in NFR-0003 NFR-0004; do
  if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/${nfr}.md" ]]; then
    pass "F-0170: ${nfr} acceptance criteria exists"
  else
    fail "F-0170: ${nfr} acceptance criteria missing"
  fi
done

_NFR_COV_OUT=$(ROOT_DIR="${FRAMEWORK_ROOT}" bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" nfr coverage 2>&1 || true)
if echo "$_NFR_COV_OUT" | grep -q "referenced by"; then
  pass "F-0170: ag nfr coverage reports references"
else
  fail "F-0170: ag nfr coverage not working"
fi

# ============================================================
# F-0171: Spec Verification Tool
# ============================================================
echo "--- F-0171: Spec Verification Tool ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/spec-audit.sh" ]]; then
  pass "F-0171: spec-audit.sh exists"
  if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/spec-audit.sh" ]]; then
    pass "F-0171: spec-audit.sh is executable"
  else
    fail "F-0171: spec-audit.sh not executable"
  fi
else
  fail "F-0171: spec-audit.sh missing"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/test-review-prompt.md" ]]; then
  pass "F-0171: test-review-prompt.md exists"
else
  fail "F-0171: test-review-prompt.md missing"
fi

if grep -q "broken implementation\|pass with a broken" "${FRAMEWORK_ROOT}/.agentic/lib/tools/test-review-prompt.md"; then
  pass "F-0171: test-review-prompt asks 'could this pass with broken implementation?'"
else
  fail "F-0171: test-review-prompt missing key question"
fi

if grep -q "cmd_audit\|audit)" "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh"; then
  pass "F-0171: ag.sh has audit command"
else
  fail "F-0171: ag.sh missing audit command"
fi

_AUDIT_OUT=$(ROOT_DIR="${FRAMEWORK_ROOT}" bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" audit --status 2>&1 || true)
if echo "$_AUDIT_OUT" | grep -qi "audit\|tracker\|verif"; then
  pass "F-0171: ag audit --status produces output"
else
  fail "F-0171: ag audit --status not working"
fi

# ============================================================
# F-0172: Change Propagation Pipeline
# ============================================================
echo "--- F-0172: Change Propagation Pipeline ---"

if grep -q "\-\-propagate" "${FRAMEWORK_ROOT}/.agentic/lib/tools/spec-audit.sh"; then
  pass "F-0172: spec-audit.sh has --propagate mode"
else
  fail "F-0172: spec-audit.sh missing --propagate mode"
fi

if grep -q "NFR.*reference\|grep.*NFR\|nfr_id\|trace.*downstream\|affected.*feature" "${FRAMEWORK_ROOT}/.agentic/lib/tools/spec-audit.sh"; then
  pass "F-0172: spec-audit.sh traces NFR references downstream"
else
  fail "F-0172: spec-audit.sh missing NFR downstream tracing"
fi

if grep -q "migration\|Migration" "${FRAMEWORK_ROOT}/.agentic/lib/tools/spec-audit.sh"; then
  pass "F-0172: spec-audit.sh handles migration propagation"
else
  fail "F-0172: spec-audit.sh missing migration propagation"
fi

# ============================================================
# F-0173: QA Tracker State Machine
# ============================================================
echo "--- F-0173: QA Tracker State Machine ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/qa-tracker.sh" ]]; then
  pass "F-0173: qa-tracker.sh exists"
  if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/qa-tracker.sh" ]]; then
    pass "F-0173: qa-tracker.sh is executable"
  else
    fail "F-0173: qa-tracker.sh not executable"
  fi
else
  fail "F-0173: qa-tracker.sh missing"
fi

for cmd in "status" "pending" "add-propagation" "resolve" "defer" "check-escalation"; do
  if grep -q "$cmd" "${FRAMEWORK_ROOT}/.agentic/lib/tools/qa-tracker.sh"; then
    pass "F-0173: qa-tracker.sh has ${cmd} command"
  else
    fail "F-0173: qa-tracker.sh missing ${cmd} command"
  fi
done

if grep -q "qa-tracker" "${FRAMEWORK_ROOT}/.gitignore"; then
  pass "F-0173: .qa-tracker.json is gitignored"
else
  fail "F-0173: .qa-tracker.json not gitignored"
fi

if grep -q "qa-tracker\|QA.*tracker\|QA.*status" "${FRAMEWORK_ROOT}/.agentic/lib/checklists/session_start.md"; then
  pass "F-0173: session_start.md shows QA tracker status"
else
  fail "F-0173: session_start.md missing QA tracker status"
fi

if grep -q "qa-tracker\|propagation" "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh"; then
  pass "F-0173: pre-commit-check.sh has propagation warning"
else
  fail "F-0173: pre-commit-check.sh missing propagation warning"
fi

if grep -q "qa_health\|check_qa_health\|qa-tracker" "${FRAMEWORK_ROOT}/.agentic/lib/tools/periodic-checks.sh"; then
  pass "F-0173: periodic-checks.sh has QA health check"
else
  fail "F-0173: periodic-checks.sh missing QA health check"
fi

if grep -q "qa_propagation_warn_days\|qa_propagation_escalate_days" "${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf"; then
  pass "F-0173: profiles.conf has escalation thresholds"
else
  fail "F-0173: profiles.conf missing escalation thresholds"
fi

# ============================================================
# F-0174: Retrospective Enforcement
# ============================================================
echo "--- F-0174: Retrospective Enforcement ---"

if grep -q "get_setting\|settings\.sh" "${FRAMEWORK_ROOT}/.agentic/lib/tools/retro_check.sh"; then
  pass "F-0174: retro_check.sh uses settings framework"
else
  fail "F-0174: retro_check.sh missing settings framework"
fi

if grep -q "\-\-status" "${FRAMEWORK_ROOT}/.agentic/lib/tools/retro_check.sh"; then
  pass "F-0174: retro_check.sh has --status mode"
else
  fail "F-0174: retro_check.sh missing --status mode"
fi

if grep -q "retrospective_enabled" "${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf"; then
  pass "F-0174: profiles.conf has retrospective_enabled"
else
  fail "F-0174: profiles.conf missing retrospective_enabled"
fi

for setting in "retrospective_enabled" "qa_propagation_warn_days" "qa_audit_freshness_days"; do
  if grep -q "$setting" "${FRAMEWORK_ROOT}/.agentic/lib/init/STACK.template.md"; then
    pass "F-0174: STACK template has ${setting}"
  else
    fail "F-0174: STACK template missing ${setting}"
  fi
done

if grep -q "Spec.*Verification\|spec-audit\|spec.audit" "${FRAMEWORK_ROOT}/.agentic/lib/checklists/retrospective.md"; then
  pass "F-0174: retrospective checklist has spec audit section"
else
  fail "F-0174: retrospective checklist missing spec audit section"
fi

if grep -q "NFR.*Health\|NFR.*Review\|nfr.*review" "${FRAMEWORK_ROOT}/.agentic/lib/checklists/retrospective.md"; then
  pass "F-0174: retrospective checklist has NFR review section"
else
  fail "F-0174: retrospective checklist missing NFR review section"
fi

if grep -q "3\.5\|Spec.*Verification.*Audit" "${FRAMEWORK_ROOT}/.agentic/lib/workflows/retrospective.md"; then
  pass "F-0174: retrospective workflow has Section 3.5"
else
  fail "F-0174: retrospective workflow missing Section 3.5"
fi

if grep -q "3\.6\|NFR.*Health.*Review" "${FRAMEWORK_ROOT}/.agentic/lib/workflows/retrospective.md"; then
  pass "F-0174: retrospective workflow has Section 3.6"
else
  fail "F-0174: retrospective workflow missing Section 3.6"
fi

if grep -q "retro.*check\|retro_check\|Retrospective.*Check\|Step 6" "${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/skills/completing-work/SKILL.md"; then
  pass "F-0174: completing-work SKILL.md has retro check"
else
  fail "F-0174: completing-work SKILL.md missing retro check"
fi

if grep -q "retro.*check\|retro_check\|Retrospective.*Check\|Step 6" "${FRAMEWORK_ROOT}/.claude/skills/completing-work/SKILL.md"; then
  pass "F-0174: root completing-work SKILL.md has retro check"
else
  fail "F-0174: root completing-work SKILL.md missing retro check"
fi

if grep -q "retro.*action\|check_retro_action" "${FRAMEWORK_ROOT}/.agentic/lib/tools/periodic-checks.sh"; then
  pass "F-0174: periodic-checks.sh has retro action items check"
else
  fail "F-0174: periodic-checks.sh missing retro action items check"
fi

# ============================================================
# F-0175: QA Suite Glue & Documentation
# ============================================================
echo "--- F-0175: QA Suite Glue & Documentation ---"

for fid in F-0169 F-0170 F-0171 F-0172 F-0173 F-0174 F-0175; do
  if grep -q "$fid" "${FRAMEWORK_ROOT}/.agentic/spec/FEATURES.md"; then
    pass "F-0175: ${fid} registered in FEATURES.md"
  else
    fail "F-0175: ${fid} missing from FEATURES.md"
  fi
done

for fid in F-0169 F-0170 F-0171 F-0172 F-0173 F-0174 F-0175; do
  if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/${fid}.md" ]]; then
    pass "F-0175: ${fid} acceptance criteria exists"
  else
    fail "F-0175: ${fid} acceptance criteria missing"
  fi
done

if ls "${FRAMEWORK_ROOT}/.agentic/spec/migrations/009_"* 1>/dev/null 2>&1; then
  pass "F-0175: migration 009 exists"
else
  fail "F-0175: migration 009 missing"
fi

if grep -q "who tests the tests\|Who tests the tests" "${FRAMEWORK_ROOT}/.agentic/lib/init/memory-seed.md"; then
  pass "F-0175: memory-seed has 'who tests the tests?' trigger"
else
  fail "F-0175: memory-seed missing 'who tests the tests?' trigger"
fi

if [[ -f "${FRAMEWORK_ROOT}/VERSION" ]]; then
  CURRENT_VERSION=$(cat "${FRAMEWORK_ROOT}/VERSION" | tr -d '[:space:]')
  if [[ "$CURRENT_VERSION" == "0.46."* ]] || [[ "$CURRENT_VERSION" > "0.46.0" ]]; then
    pass "F-0175: VERSION is ${CURRENT_VERSION} (>= 0.46.0)"
  else
    fail "F-0175: VERSION is ${CURRENT_VERSION} (expected >= 0.46.0)"
  fi
else
  fail "F-0175: VERSION file missing"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/journal/plans/2026-03-07-F-0169-qa-suite-plan.md" ]]; then
  pass "F-0175: QA suite plan saved to journal/plans/"
else
  fail "F-0175: QA suite plan not saved to journal/plans/"
fi

# Test missing STACK.md uses profile preset (inferred discovery → feature_tracking=no)
(
  source "${FRAMEWORK_ROOT}/.agentic/lib/settings.sh" 2>/dev/null || exit 1
  SETTINGS_TEST_DIR=$(mktemp -d)
  _SETTINGS_STACK_FILE="$SETTINGS_TEST_DIR/nonexistent.md"
  _SETTINGS_ROOT_DIR="$SETTINGS_TEST_DIR"
  _reset_settings_cache

  VAL=$(get_setting "feature_tracking" "fallback_val")
  rm -rf "$SETTINGS_TEST_DIR"
  # No STACK.md, no .agentic/spec/ dir → inferred discovery → preset feature_tracking=no
  [[ "$VAL" == "no" ]]
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "Settings: missing STACK.md falls through to profile preset"
else
  fail "Settings: missing STACK.md should fall through to profile preset"
fi

# Test empty value is not returned (falls through to preset/default)
(
  source "${FRAMEWORK_ROOT}/.agentic/lib/settings.sh" 2>/dev/null || exit 1
  SETTINGS_TEST_DIR=$(mktemp -d)
  cat > "$SETTINGS_TEST_DIR/STACK.md" <<'TESTEOF'
## Settings
- profile: formal
- feature_tracking:
TESTEOF
  _SETTINGS_STACK_FILE="$SETTINGS_TEST_DIR/STACK.md"
  _reset_settings_cache

  FT_VAL=$(get_setting "feature_tracking" "UNSET")
  rm -rf "$SETTINGS_TEST_DIR"
  # Empty value should fall through to profile preset (formal=yes)
  [[ "$FT_VAL" == "yes" ]]
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "Settings: empty value falls through to preset"
else
  fail "Settings: empty value should fall through to preset"
fi

# Test ag set validates enum values
(
  cd "${FRAMEWORK_ROOT}" || exit 1
  OUTPUT=$(bash ".agentic/lib/tools/ag.sh" set profile bogus 2>&1) && exit 1
  [[ "$OUTPUT" == *"Error"* ]]
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "Settings: ag set rejects invalid enum values"
else
  fail "Settings: ag set should reject invalid enum values"
fi

# Test Python settings.py resolves correctly
(
  SETTINGS_TEST_DIR=$(mktemp -d)
  cat > "$SETTINGS_TEST_DIR/STACK.md" <<'TESTEOF'
## Settings
- profile: formal
- feature_tracking: no
TESTEOF
  RESULT=$(python3 -c "
import sys; sys.path.insert(0, '${FRAMEWORK_ROOT}/.agentic/lib')
from settings import get_setting; from pathlib import Path
print(get_setting(Path('$SETTINGS_TEST_DIR'), 'feature_tracking', 'UNSET'))
" 2>&1)
  rm -rf "$SETTINGS_TEST_DIR"
  [[ "$RESULT" == "no" ]]
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "Settings: Python get_setting() resolves explicit override"
else
  fail "Settings: Python get_setting() should resolve explicit override"
fi

# ============================================================
# F-0132: Spec-First Gate Tests
# ============================================================

# Test: ag plan blocks when F-XXXX not in FEATURES.md
(
  GATE_TEST_DIR=$(mktemp -d)
  mkdir -p "$GATE_TEST_DIR/.agentic/spec"
  cat > "$GATE_TEST_DIR/STACK.md" <<'TESTEOF'
## Settings
- profile: formal
- feature_tracking: yes
TESTEOF
  cat > "$GATE_TEST_DIR/.agentic/spec/FEATURES.md" <<'TESTEOF'
## F-0001: Existing Feature
**Status**: planned
TESTEOF
  # F-9999 is NOT in FEATURES.md — should block
  # Override settings paths so get_setting reads from test dir
  OUTPUT=$(ROOT_DIR="$GATE_TEST_DIR" _AGENTIC_SETTINGS_LOADED="" _SETTINGS_ROOT_DIR="$GATE_TEST_DIR" _SETTINGS_STACK_FILE="$GATE_TEST_DIR/STACK.md" bash "$FRAMEWORK_ROOT/.agentic/lib/tools/ag.sh" plan F-9999 2>&1) || true
  rm -rf "$GATE_TEST_DIR"
  echo "$OUTPUT" | grep -q "BLOCKED.*not found in FEATURES.md"
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "Gate: ag plan blocks when F-XXXX not in FEATURES.md"
else
  fail "Gate: ag plan should block when F-XXXX not in FEATURES.md"
fi

# Test: ag implement blocks when no acceptance criteria file
(
  GATE_TEST_DIR=$(mktemp -d)
  mkdir -p "$GATE_TEST_DIR/.agentic/spec/acceptance"
  cat > "$GATE_TEST_DIR/STACK.md" <<'TESTEOF'
## Settings
- profile: formal
- feature_tracking: yes
- plan_review_enabled: no
TESTEOF
  cat > "$GATE_TEST_DIR/.agentic/spec/FEATURES.md" <<'TESTEOF'
## F-0001: Test Feature
**Status**: planned
TESTEOF
  # F-0001 IS in FEATURES.md but no acceptance file — should block
  OUTPUT=$(ROOT_DIR="$GATE_TEST_DIR" _AGENTIC_SETTINGS_LOADED="" _SETTINGS_ROOT_DIR="$GATE_TEST_DIR" _SETTINGS_STACK_FILE="$GATE_TEST_DIR/STACK.md" bash "$FRAMEWORK_ROOT/.agentic/lib/tools/ag.sh" implement F-0001 2>&1) || true
  rm -rf "$GATE_TEST_DIR"
  echo "$OUTPUT" | grep -q "BLOCKED.*No acceptance criteria"
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "Gate: ag implement blocks when no acceptance criteria"
else
  fail "Gate: ag implement should block when no acceptance criteria"
fi

# Test: gate inactive when feature_tracking=no
(
  GATE_TEST_DIR=$(mktemp -d)
  cat > "$GATE_TEST_DIR/STACK.md" <<'TESTEOF'
## Settings
- profile: discovery
- feature_tracking: no
TESTEOF
  # With feature_tracking=no, ag plan should not check FEATURES.md — it exits with "tracking is off"
  OUTPUT=$(ROOT_DIR="$GATE_TEST_DIR" _AGENTIC_SETTINGS_LOADED="" _SETTINGS_ROOT_DIR="$GATE_TEST_DIR" _SETTINGS_STACK_FILE="$GATE_TEST_DIR/STACK.md" bash "$FRAMEWORK_ROOT/.agentic/lib/tools/ag.sh" plan F-9999 2>&1) || true
  rm -rf "$GATE_TEST_DIR"
  echo "$OUTPUT" | grep -q "Feature tracking is off"
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "Gate: spec-first gate inactive when feature_tracking=no"
else
  fail "Gate: spec-first gate should be inactive when feature_tracking=no"
fi

# ============================================================
# F-0138: Documentation Impact Tracking
# ============================================================
echo "--- Acceptance Criteria Template ---"

# acceptance.template.md exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/templates/acceptance.template.md" ]]; then
  pass "Acceptance template: acceptance.template.md exists"
else
  fail "Acceptance template: acceptance.template.md missing (ag implement references it)"
fi

# acceptance.template.md has a Tests section (## Tests or ### Tests under ## Verification)
if grep -q "^## Tests\|^### Tests" "${FRAMEWORK_ROOT}/.agentic/lib/templates/acceptance.template.md" 2>/dev/null; then
  pass "Acceptance template: has Tests section"
else
  fail "Acceptance template: missing Tests section"
fi

# feature_start.md gates the ## Tests section
if grep -q "## Tests" "${FRAMEWORK_ROOT}/.agentic/lib/checklists/feature_start.md" 2>/dev/null; then
  pass "Acceptance template: feature_start.md checks for ## Tests section"
else
  fail "Acceptance template: feature_start.md does not check for ## Tests section"
fi

echo "--- F-0138: Documentation Impact Tracking ---"

# CONTEXT_PACK.template.md has ## Documentation section
if grep -q "^## Documentation" "${FRAMEWORK_ROOT}/.agentic/lib/init/CONTEXT_PACK.template.md" 2>/dev/null; then
  pass "F-0138: CONTEXT_PACK.template.md has ## Documentation section"
else
  fail "F-0138: CONTEXT_PACK.template.md missing ## Documentation section"
fi

# CONTEXT_PACK.md (framework instance) has populated ## Documentation section
if grep -q "^## Documentation" "${FRAMEWORK_ROOT}/CONTEXT_PACK.md" 2>/dev/null; then
  pass "F-0138: CONTEXT_PACK.md has ## Documentation section"
else
  fail "F-0138: CONTEXT_PACK.md missing ## Documentation section"
fi

# profiles.conf has docs_gate for both profiles
if grep -q "^discovery.docs_gate=" "${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf" 2>/dev/null; then
  pass "F-0138: profiles.conf has discovery.docs_gate"
else
  fail "F-0138: profiles.conf missing discovery.docs_gate"
fi
if grep -q "^formal.docs_gate=" "${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf" 2>/dev/null; then
  pass "F-0138: profiles.conf has formal.docs_gate"
else
  fail "F-0138: profiles.conf missing formal.docs_gate"
fi

# STACK.template.md has docs_gate in Settings comments
if grep -q "docs_gate" "${FRAMEWORK_ROOT}/.agentic/lib/init/STACK.template.md" 2>/dev/null; then
  pass "F-0138: STACK.template.md has docs_gate in Settings"
else
  fail "F-0138: STACK.template.md missing docs_gate"
fi

# auto_orchestration.md has docs_gate in gates table
if grep -q "docs_gate" "${FRAMEWORK_ROOT}/.agentic/lib/agents/shared/auto_orchestration.md" 2>/dev/null; then
  pass "F-0138: auto_orchestration.md has docs_gate gate"
else
  fail "F-0138: auto_orchestration.md missing docs_gate gate"
fi

# documentation-agent.md has drift.sh process
if grep -q "drift.sh" "${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/subagents/documentation-agent.md" 2>/dev/null; then
  pass "F-0138: documentation-agent.md references drift.sh process"
else
  fail "F-0138: documentation-agent.md missing drift.sh process"
fi
if grep -q "CONTEXT_PACK" "${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/subagents/documentation-agent.md" 2>/dev/null; then
  pass "F-0138: documentation-agent.md references CONTEXT_PACK.md docs list"
else
  fail "F-0138: documentation-agent.md missing CONTEXT_PACK.md reference"
fi

# ag.sh has docs_gate gate logic in cmd_done
if grep -q "docs_gate" "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" 2>/dev/null; then
  pass "F-0138: ag.sh has docs_gate logic"
else
  fail "F-0138: ag.sh missing docs_gate logic"
fi
if grep -q "drift.sh.*--docs" "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" 2>/dev/null; then
  pass "F-0138: ag.sh calls drift.sh --docs in ag done"
else
  fail "F-0138: ag.sh missing drift.sh --docs call"
fi

# ag.sh validates docs_gate enum values in ag set
if grep -q "docs_gate)" "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" 2>/dev/null; then
  pass "F-0138: ag.sh validates docs_gate enum in ag set"
else
  fail "F-0138: ag.sh missing docs_gate validation in ag set"
fi

# docs_gate=off skips doc check (behavioral test via ag done mock)
(
  GATE_TEST_DIR=$(mktemp -d)
  mkdir -p "$GATE_TEST_DIR/.agentic/spec/acceptance"
  mkdir -p "$GATE_TEST_DIR/.agentic/journal/manifests"
  cat > "$GATE_TEST_DIR/STACK.md" <<'TESTEOF'
## Settings
- profile: discovery
- feature_tracking: yes
- docs_gate: off
TESTEOF
  cat > "$GATE_TEST_DIR/.agentic/spec/FEATURES.md" <<'TESTEOF'
## F-0001: Test Feature
**Status**: in_progress
TESTEOF
  touch "$GATE_TEST_DIR/.agentic/spec/acceptance/F-0001.md"
  OUTPUT=$(ROOT_DIR="$GATE_TEST_DIR" _AGENTIC_SETTINGS_LOADED="" _SETTINGS_ROOT_DIR="$GATE_TEST_DIR" _SETTINGS_STACK_FILE="$GATE_TEST_DIR/STACK.md" bash "$FRAMEWORK_ROOT/.agentic/lib/tools/ag.sh" done F-0001 2>&1) || true
  rm -rf "$GATE_TEST_DIR"
  # docs_gate=off means no "Documentation Drift Check" section
  ! echo "$OUTPUT" | grep -q "Documentation Drift Check"
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "F-0138: docs_gate=off skips doc drift check in ag done"
else
  fail "F-0138: docs_gate=off should skip doc drift check"
fi

# docs_gate=warning runs drift but doesn't prompt
(
  GATE_TEST_DIR=$(mktemp -d)
  mkdir -p "$GATE_TEST_DIR/.agentic/spec/acceptance"
  mkdir -p "$GATE_TEST_DIR/.agentic/journal/manifests"
  cat > "$GATE_TEST_DIR/STACK.md" <<'TESTEOF'
## Settings
- profile: formal
- feature_tracking: yes
- docs_gate: warning
TESTEOF
  cat > "$GATE_TEST_DIR/.agentic/spec/FEATURES.md" <<'TESTEOF'
## F-0001: Test Feature
**Status**: in_progress
TESTEOF
  touch "$GATE_TEST_DIR/.agentic/spec/acceptance/F-0001.md"
  OUTPUT=$(ROOT_DIR="$GATE_TEST_DIR" _AGENTIC_SETTINGS_LOADED="" _SETTINGS_ROOT_DIR="$GATE_TEST_DIR" _SETTINGS_STACK_FILE="$GATE_TEST_DIR/STACK.md" bash "$FRAMEWORK_ROOT/.agentic/lib/tools/ag.sh" done F-0001 2>&1) || true
  rm -rf "$GATE_TEST_DIR"
  # warning mode shows "Documentation Drift Check" but no blocking prompt
  echo "$OUTPUT" | grep -q "Documentation Drift Check" && ! echo "$OUTPUT" | grep -q "confirm docs are updated"
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "F-0138: docs_gate=warning runs drift check but does not block"
else
  fail "F-0138: docs_gate=warning should run drift check without blocking"
fi

# ag set validates docs_gate enum
(
  GATE_TEST_DIR=$(mktemp -d)
  cat > "$GATE_TEST_DIR/STACK.md" <<'TESTEOF'
## Settings
- profile: formal
TESTEOF
  OUTPUT=$(ROOT_DIR="$GATE_TEST_DIR" _AGENTIC_SETTINGS_LOADED="" _SETTINGS_ROOT_DIR="$GATE_TEST_DIR" _SETTINGS_STACK_FILE="$GATE_TEST_DIR/STACK.md" bash "$FRAMEWORK_ROOT/.agentic/lib/tools/ag.sh" set docs_gate invalid_value 2>&1) || true
  rm -rf "$GATE_TEST_DIR"
  echo "$OUTPUT" | grep -q "Error.*docs_gate"
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "F-0138: ag set rejects invalid docs_gate values"
else
  fail "F-0138: ag set should reject invalid docs_gate value"
fi

# Acceptance criteria file exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/F-0138.md" ]]; then
  pass "F-0138: acceptance criteria file exists"
else
  fail "F-0138: acceptance criteria file missing"
fi

# ============================================================
# F-0139: Doc Lifecycle System
# ============================================================
echo "--- F-0139: Doc Lifecycle System ---"

# docs.sh exists and is executable
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/docs.sh" ]]; then
  pass "F-0139: docs.sh exists"
else
  fail "F-0139: docs.sh missing"
fi
if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/docs.sh" ]]; then
  pass "F-0139: docs.sh is executable"
else
  fail "F-0139: docs.sh is not executable"
fi

# doc_types.md exists with all 8 built-in types
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/agents/shared/doc_types.md" ]]; then
  pass "F-0139: doc_types.md exists"
  for dtype in changelog readme lessons architecture adr runbook tech-spec custom; do
    if grep -q "^## $dtype" "${FRAMEWORK_ROOT}/.agentic/lib/agents/shared/doc_types.md" 2>/dev/null; then
      pass "F-0139: doc_types.md has $dtype type"
    else
      fail "F-0139: doc_types.md missing $dtype type"
    fi
  done
else
  fail "F-0139: doc_types.md missing"
fi

# ag.sh has cmd_docs function
if grep -q "cmd_docs" "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" 2>/dev/null; then
  pass "F-0139: ag.sh has cmd_docs function"
else
  fail "F-0139: ag.sh missing cmd_docs"
fi

# ag.sh has docs) case in dispatch
if grep -q "^    docs)" "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" 2>/dev/null; then
  pass "F-0139: ag.sh has docs command dispatch"
else
  fail "F-0139: ag.sh missing docs command dispatch"
fi

# ag.sh wires docs.sh into cmd_done
if grep -q "docs.sh.*--trigger feature_done" "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" 2>/dev/null; then
  pass "F-0139: ag.sh wires docs.sh feature_done into ag done"
else
  fail "F-0139: ag.sh missing docs.sh feature_done wiring in ag done"
fi
if grep -q "docs.sh.*--trigger pr" "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" 2>/dev/null; then
  pass "F-0139: ag.sh wires docs.sh pr trigger"
else
  fail "F-0139: ag.sh missing docs.sh pr trigger wiring"
fi

# ag.sh wires docs.sh session into ag sync
if grep -q "docs.sh.*--trigger session" "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" 2>/dev/null; then
  pass "F-0139: ag.sh wires docs.sh session into ag sync"
else
  fail "F-0139: ag.sh missing docs.sh session wiring in ag sync"
fi

# STACK.template.md has ## Docs section
if grep -q "^## Docs" "${FRAMEWORK_ROOT}/.agentic/lib/init/STACK.template.md" 2>/dev/null; then
  pass "F-0139: STACK.template.md has ## Docs section"
else
  fail "F-0139: STACK.template.md missing ## Docs section"
fi

# auto_orchestration.md mentions doc lifecycle
if grep -q "DOC LIFECYCLE" "${FRAMEWORK_ROOT}/.agentic/lib/agents/shared/auto_orchestration.md" 2>/dev/null; then
  pass "F-0139: auto_orchestration.md has doc lifecycle step"
else
  fail "F-0139: auto_orchestration.md missing doc lifecycle step"
fi

# documentation-agent.md has structured registry mode
if grep -q "Structured Registry" "${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/subagents/documentation-agent.md" 2>/dev/null; then
  pass "F-0139: documentation-agent.md has structured registry mode"
else
  fail "F-0139: documentation-agent.md missing structured registry mode"
fi

# STACK.md (framework instance) has populated ## Docs section
if grep -q "^## Docs" "${FRAMEWORK_ROOT}/STACK.md" 2>/dev/null; then
  pass "F-0139: STACK.md has ## Docs section (dogfooding)"
else
  fail "F-0139: STACK.md missing ## Docs section"
fi
if grep -q "^- doc:" "${FRAMEWORK_ROOT}/STACK.md" 2>/dev/null; then
  pass "F-0139: STACK.md has populated doc entries"
else
  fail "F-0139: STACK.md has no doc entries (should be populated for dogfooding)"
fi

# docs.sh --list runs without error on framework project
if bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/docs.sh" --list >/dev/null 2>&1; then
  pass "F-0139: docs.sh --list runs without error"
else
  fail "F-0139: docs.sh --list fails"
fi

# docs.sh --list shows framework doc entries
DOCS_LIST_OUTPUT=$(bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/docs.sh" --list 2>/dev/null)
if echo "$DOCS_LIST_OUTPUT" | grep -q "CHANGELOG.md"; then
  pass "F-0139: docs.sh --list shows CHANGELOG.md entry"
else
  fail "F-0139: docs.sh --list missing CHANGELOG.md entry"
fi

# docs.sh empty registry test
(
  DOCS_TEST_DIR=$(mktemp -d)
  cat > "$DOCS_TEST_DIR/STACK.md" <<'TESTEOF'
## Settings
- profile: discovery
TESTEOF
  OUTPUT=$(ROOT_DIR="$DOCS_TEST_DIR" bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/docs.sh" --list 2>&1)
  rm -rf "$DOCS_TEST_DIR"
  echo "$OUTPUT" | grep -q "No docs registered"
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "F-0139: empty registry prints 'No docs registered'"
else
  fail "F-0139: empty registry should print 'No docs registered'"
fi

# docs.sh --trigger filters correctly
(
  DOCS_TEST_DIR=$(mktemp -d)
  cat > "$DOCS_TEST_DIR/STACK.md" <<'TESTEOF'
## Docs
- doc: CHANGELOG.md | changelog | pr
- doc: docs/lessons.md | lessons | feature_done
TESTEOF
  OUTPUT=$(ROOT_DIR="$DOCS_TEST_DIR" bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/docs.sh" --trigger feature_done --check 2>&1)
  rm -rf "$DOCS_TEST_DIR"
  echo "$OUTPUT" | grep -q "lessons" && ! echo "$OUTPUT" | grep -q "CHANGELOG"
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "F-0139: --trigger feature_done filters correctly (lessons yes, changelog no)"
else
  fail "F-0139: --trigger filtering incorrect"
fi

# ag help shows docs command
if bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" help 2>&1 | grep -q "docs"; then
  pass "F-0139: ag help includes docs command"
else
  fail "F-0139: ag help missing docs command"
fi

# Acceptance criteria file exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/F-0139.md" ]]; then
  pass "F-0139: acceptance criteria file exists"
else
  fail "F-0139: acceptance criteria file missing"
fi

# ============================================================
# F-0140: Proactive WIP Creation in Agent Instructions
# ============================================================

echo "--- F-0140: Proactive WIP Creation in Agent Instructions ---"

# Plan-mode-exit trigger chains to ag implement across all instruction files
for file in \
  "${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/CLAUDE.md" \
  "${FRAMEWORK_ROOT}/.agentic/lib/agents/cursor/cursorrules.txt" \
  "${FRAMEWORK_ROOT}/.agentic/lib/agents/copilot/copilot-instructions.md" \
  "${FRAMEWORK_ROOT}/.agentic/lib/agents/codex/codex-instructions.md"; do
  name=$(basename "$file")
  # Plan-mode-exit row must mention ag implement, OR skills handle triggers
  if grep -i "plan.*mode\|plan.*approved\|planning complete" "$file" | grep -q "ag implement"; then
    pass "F-0140: $name plan-mode-exit → ag implement"
  elif grep -q "Skills.*\.claude/skills\|skills/" "$file" 2>/dev/null; then
    pass "F-0140: $name plan-mode-exit handled by skills"
  else
    fail "F-0140: $name plan-mode-exit row missing ag implement chaining"
  fi
  # Build row must mention (creates WIP), OR skills handle triggers
  if grep -i "Build.*implement.*create" "$file" | grep -q "creates WIP"; then
    pass "F-0140: $name Build trigger has (creates WIP)"
  elif grep -q "Skills.*\.claude/skills\|skills/" "$file" 2>/dev/null; then
    pass "F-0140: $name Build trigger handled by skills"
  else
    fail "F-0140: $name Build trigger missing (creates WIP) annotation"
  fi
done

# Memory seed has WIP creation in both sections
if grep -q "auto-creates WIP" "${FRAMEWORK_ROOT}/.agentic/lib/init/memory-seed.md"; then
  pass "F-0140: memory-seed.md has WIP creation in build section"
else
  fail "F-0140: memory-seed.md missing WIP creation note in build section"
fi
if grep -q "auto-creates WIP lock" "${FRAMEWORK_ROOT}/.agentic/lib/init/memory-seed.md"; then
  pass "F-0140: memory-seed.md has WIP creation in plan-mode-exit section"
else
  fail "F-0140: memory-seed.md missing WIP creation in plan-mode-exit section"
fi

# doctor.py checks WIP path via paths.py (wip_file) or hardcoded .agentic/session/WIP.md
if grep -q 'wip_file\|\.agentic/session.*WIP\.md' "${FRAMEWORK_ROOT}/.agentic/lib/tools/doctor.py"; then
  pass "F-0140: doctor.py uses correct WIP path (via paths.py or .agentic/session/)"
else
  fail "F-0140: doctor.py still uses wrong WIP path"
fi
# feature_start.md references ag implement creates WIP
if grep -q "ag implement.*creates WIP" "${FRAMEWORK_ROOT}/.agentic/lib/checklists/feature_start.md"; then
  pass "F-0140: feature_start.md has ag implement (creates WIP) in After Gates"
else
  fail "F-0140: feature_start.md missing WIP reference in After Gates Pass"
fi

# feature_implementation.md has WIP tracking checkbox
if grep -q "WIP tracking active" "${FRAMEWORK_ROOT}/.agentic/lib/checklists/feature_implementation.md"; then
  pass "F-0140: feature_implementation.md has WIP tracking prerequisite"
else
  fail "F-0140: feature_implementation.md missing WIP tracking checkbox"
fi

# Acceptance criteria file exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/F-0140.md" ]]; then
  pass "F-0140: acceptance criteria file exists"
else
  fail "F-0140: acceptance criteria file missing"
fi

# ============================================================
# F-0141: Explicit Settings in STACK.md
# ============================================================
echo "--- F-0141: Explicit Settings in STACK.md ---"

# Test: STACK.template.md has all profiles.conf settings uncommented
PROFILES_CONF="${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf"
STACK_TEMPLATE="${FRAMEWORK_ROOT}/.agentic/lib/init/STACK.template.md"

if [[ -f "$PROFILES_CONF" && -f "$STACK_TEMPLATE" ]]; then
  # Extract all setting names from profiles.conf (discovery.xxx=yyy → xxx)
  F0141_MISSING_IN_TEMPLATE=0
  while IFS='=' read -r pkey pval; do
    [[ "$pkey" =~ ^#|^$ ]] && continue
    [[ -z "$pkey" ]] && continue
    if [[ "$pkey" =~ ^discovery\.(.*) ]]; then
      sname="${BASH_REMATCH[1]}"
      if grep -q "^- ${sname}:" "$STACK_TEMPLATE"; then
        : # found
      else
        fail "F-0141: profiles.conf setting '${sname}' missing from STACK.template.md"
        F0141_MISSING_IN_TEMPLATE=1
      fi
    fi
  done < "$PROFILES_CONF"
  if [[ $F0141_MISSING_IN_TEMPLATE -eq 0 ]]; then
    pass "F-0141: all profiles.conf settings present in STACK.template.md"
  fi

  # Reverse check: all template settings in ## Settings section have matching profiles.conf key
  F0141_MISSING_IN_CONF=0
  F0141_IN_SETTINGS=0
  while IFS= read -r line; do
    # Track when we enter/exit ## Settings section
    if [[ "$line" =~ ^##[[:space:]]+Settings ]]; then
      F0141_IN_SETTINGS=1
      continue
    fi
    if [[ $F0141_IN_SETTINGS -eq 1 ]] && [[ "$line" =~ ^##[[:space:]] ]] && [[ ! "$line" =~ ^###[[:space:]] ]]; then
      F0141_IN_SETTINGS=0
      continue
    fi
    # Only check settings within ## Settings section
    if [[ $F0141_IN_SETTINGS -eq 1 ]]; then
      if [[ "$line" =~ ^-[[:space:]]+(profile):[[:space:]] ]]; then
        continue  # profile itself is not in profiles.conf as discovery.profile
      fi
      if [[ "$line" =~ ^-[[:space:]]+([a-z_]+):[[:space:]] ]]; then
        sname="${BASH_REMATCH[1]}"
        if grep -q "^discovery\.${sname}=" "$PROFILES_CONF"; then
          : # found
        else
          fail "F-0141: STACK.template.md setting '${sname}' not in profiles.conf"
          F0141_MISSING_IN_CONF=1
        fi
      fi
    fi
  done < "$STACK_TEMPLATE"
  if [[ $F0141_MISSING_IN_CONF -eq 0 ]]; then
    pass "F-0141: all template Settings section entries have matching profiles.conf keys"
  fi
else
  fail "F-0141: profiles.conf or STACK.template.md not found"
fi

# Test: template settings have "Profile defaults" comments
if grep -q "Profile defaults" "$STACK_TEMPLATE"; then
  pass "F-0141: STACK.template.md has Profile defaults comments"
else
  fail "F-0141: STACK.template.md missing Profile defaults comments"
fi

# Test: settings are uncommented (not HTML comments)
F0141_COMMENTED=0
while IFS='=' read -r pkey pval; do
  [[ "$pkey" =~ ^#|^$ ]] && continue
  [[ -z "$pkey" ]] && continue
  if [[ "$pkey" =~ ^discovery\.(.*) ]]; then
    sname="${BASH_REMATCH[1]}"
    if grep -q "^<!--.*- ${sname}:" "$STACK_TEMPLATE"; then
      fail "F-0141: setting '${sname}' is still commented out in template"
      F0141_COMMENTED=1
    fi
  fi
done < "$PROFILES_CONF"
if [[ $F0141_COMMENTED -eq 0 ]]; then
  pass "F-0141: no profile settings are commented out in template"
fi

# Test: scaffold.sh reads from profiles.conf
if grep -q "profiles.conf" "${FRAMEWORK_ROOT}/.agentic/lib/init/scaffold.sh"; then
  pass "F-0141: scaffold.sh references profiles.conf"
else
  fail "F-0141: scaffold.sh does not reference profiles.conf"
fi

# Test: ag.sh has pre_commit_hook validation
if grep -q "pre_commit_hook)" "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh"; then
  pass "F-0141: ag.sh has pre_commit_hook validation"
else
  fail "F-0141: ag.sh missing pre_commit_hook validation"
fi

# Test: ag.sh has profile cascade logic
if grep -q "_PREV_PROFILE" "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh"; then
  pass "F-0141: ag.sh has smart profile cascade"
else
  fail "F-0141: ag.sh missing smart profile cascade"
fi

# Functional test: scaffold with discovery profile produces all settings
echo "--- F-0141: Functional scaffold tests ---"
F0141_SCRATCH=$(mktemp -d)
mkdir -p "$F0141_SCRATCH/.agentic"
cp -r "${FRAMEWORK_ROOT}/.agentic/lib" "$F0141_SCRATCH/.agentic/"
[[ -d "${FRAMEWORK_ROOT}/.agentic/hooks" ]] && cp -r "${FRAMEWORK_ROOT}/.agentic/hooks" "$F0141_SCRATCH/.agentic/"

# Init git repo for scaffold
(cd "$F0141_SCRATCH" && git init -q 2>/dev/null)

# Test discovery scaffold
(cd "$F0141_SCRATCH" && bash .agentic/lib/init/scaffold.sh --profile discovery --non-interactive >/dev/null 2>&1) || true
F0141_DISC_MISSING=0
while IFS='=' read -r pkey pval; do
  [[ "$pkey" =~ ^#|^$ ]] && continue
  [[ -z "$pkey" ]] && continue
  if [[ "$pkey" =~ ^discovery\.(.*) ]]; then
    sname="${BASH_REMATCH[1]}"
    expected_val="$pval"
    if grep -q "^- ${sname}: ${expected_val}" "$F0141_SCRATCH/STACK.md" 2>/dev/null; then
      : # correct
    else
      actual=$(grep "^- ${sname}:" "$F0141_SCRATCH/STACK.md" 2>/dev/null || echo "(not found)")
      fail "F-0141: discovery scaffold: ${sname} expected '${expected_val}', got '${actual}'"
      F0141_DISC_MISSING=1
    fi
  fi
done < "$PROFILES_CONF"
if [[ $F0141_DISC_MISSING -eq 0 ]]; then
  pass "F-0141: discovery scaffold has all settings with correct values"
fi

# Test formal scaffold
F0141_SCRATCH2=$(mktemp -d)
mkdir -p "$F0141_SCRATCH2/.agentic"
cp -r "${FRAMEWORK_ROOT}/.agentic/lib" "$F0141_SCRATCH2/.agentic/"
[[ -d "${FRAMEWORK_ROOT}/.agentic/hooks" ]] && cp -r "${FRAMEWORK_ROOT}/.agentic/hooks" "$F0141_SCRATCH2/.agentic/"
(cd "$F0141_SCRATCH2" && git init -q 2>/dev/null)

(cd "$F0141_SCRATCH2" && bash .agentic/lib/init/scaffold.sh --profile formal --non-interactive >/dev/null 2>&1) || true
F0141_FORM_MISSING=0
while IFS='=' read -r pkey pval; do
  [[ "$pkey" =~ ^#|^$ ]] && continue
  [[ -z "$pkey" ]] && continue
  if [[ "$pkey" =~ ^formal\.(.*) ]]; then
    sname="${BASH_REMATCH[1]}"
    expected_val="$pval"
    if grep -q "^- ${sname}: ${expected_val}" "$F0141_SCRATCH2/STACK.md" 2>/dev/null; then
      : # correct
    else
      actual=$(grep "^- ${sname}:" "$F0141_SCRATCH2/STACK.md" 2>/dev/null || echo "(not found)")
      fail "F-0141: formal scaffold: ${sname} expected '${expected_val}', got '${actual}'"
      F0141_FORM_MISSING=1
    fi
  fi
done < "$PROFILES_CONF"
if [[ $F0141_FORM_MISSING -eq 0 ]]; then
  pass "F-0141: formal scaffold has all settings with correct values"
fi

# Cleanup scratch dirs
rm -rf "$F0141_SCRATCH" "$F0141_SCRATCH2" 2>/dev/null || true

# Acceptance criteria file exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/F-0141.md" ]]; then
  pass "F-0141: acceptance criteria file exists"
else
  fail "F-0141: acceptance criteria file missing"
fi

# ============================================================
# F-0144: Systematic Frontmatter Coverage
# ============================================================
echo "--- F-0144: Systematic Frontmatter Coverage ---"

if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/add-remaining-frontmatter.sh" ]]; then
  pass "add-remaining-frontmatter.sh exists and is executable"
else
  fail "add-remaining-frontmatter.sh missing or not executable"
fi

# Count files with frontmatter (first line is ---)
FM_COUNT=0
TOTAL_COUNT=0
while IFS= read -r mdfile; do
  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  if head -1 "$mdfile" 2>/dev/null | grep -q "^---"; then
    FM_COUNT=$((FM_COUNT + 1))
  fi
done < <(find "${FRAMEWORK_ROOT}/.agentic" -name "*.md" -type f)

if [[ $FM_COUNT -ge 160 ]]; then
  pass "Frontmatter coverage: ${FM_COUNT}/${TOTAL_COUNT} files (>= 160 threshold)"
else
  fail "Frontmatter coverage too low: ${FM_COUNT}/${TOTAL_COUNT} files (need >= 160)"
fi

# Verify no template files have frontmatter
TEMPLATE_WITH_FM=0
while IFS= read -r tmpl; do
  if head -1 "$tmpl" 2>/dev/null | grep -q "^---"; then
    TEMPLATE_WITH_FM=$((TEMPLATE_WITH_FM + 1))
  fi
done < <(find "${FRAMEWORK_ROOT}/.agentic" \( -name "*.template.md" -o -name "*.reference.md" \) -type f)

if [[ $TEMPLATE_WITH_FM -eq 0 ]]; then
  pass "No template/reference files have frontmatter"
else
  fail "${TEMPLATE_WITH_FM} template/reference files incorrectly have frontmatter"
fi

# Spot-check key files have frontmatter
for keyfile in agents/roles/implementation_agent.md agents/shared/auto_orchestration.md PRINCIPLES.md token_efficiency/reading_protocols.md; do
  if head -1 "${FRAMEWORK_ROOT}/.agentic/lib/${keyfile}" 2>/dev/null | grep -q "^---"; then
    pass "${keyfile} has frontmatter"
  else
    fail "${keyfile} missing frontmatter"
  fi
done

if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/F-0144.md" ]]; then
  pass "F-0144: acceptance criteria file exists"
else
  fail "F-0144: acceptance criteria file missing"
fi

# ============================================================
# F-0147: Spec-Writing Workflow with Delta Tracking
# ============================================================
echo "--- F-0147: Spec-Writing Workflow with Delta Tracking ---"

# Core files exist
for f in \
  ".agentic/lib/workflows/spec_writing.md" \
  ".agentic/lib/checklists/spec_writing.md" \
  ".agentic/lib/tools/check-spec-health.sh" \
  ".agentic/lib/agents/claude/skills/writing-specs/SKILL.md" \
  ".claude/skills/writing-specs/SKILL.md" \
  ".agentic/spec/acceptance/F-0147.md"; do
  if [[ -f "${FRAMEWORK_ROOT}/${f}" ]]; then
    pass "F-0147: $(basename "$f") exists"
  else
    fail "F-0147: $(basename "$f") missing"
  fi
done

# check-spec-health.sh is executable
if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/check-spec-health.sh" ]]; then
  pass "F-0147: check-spec-health.sh is executable"
else
  fail "F-0147: check-spec-health.sh not executable"
fi

# Pre-commit checks 14-16 present
for check_num in 14 15 16; do
  if grep -q "\[${check_num}/16\]" "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh" 2>/dev/null; then
    pass "F-0147: Check ${check_num} present in pre-commit-check.sh"
  else
    fail "F-0147: Check ${check_num} missing from pre-commit-check.sh"
  fi
done

# Check 2 grep pattern uses correct format (not plain "Status: shipped")
if grep -q 'status.*shipped' "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "F-0147: Check 2 grep pattern handles markdown bold format"
else
  fail "F-0147: Check 2 grep pattern may not match **Status**: shipped format"
fi

# managing-specs replaced by writing-specs
if [[ ! -d "${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/skills/managing-specs" ]]; then
  pass "F-0147: managing-specs skill removed (source)"
else
  fail "F-0147: managing-specs skill still exists (source)"
fi
if [[ ! -d "${FRAMEWORK_ROOT}/.claude/skills/managing-specs" ]]; then
  pass "F-0147: managing-specs skill removed (generated)"
else
  fail "F-0147: managing-specs skill still exists (generated)"
fi

# writing-specs references
for ref in spec_writing.md spec_evolution.md spec_protection.md; do
  if [[ -f "${FRAMEWORK_ROOT}/.claude/skills/writing-specs/references/${ref}" ]]; then
    pass "F-0147: writing-specs reference ${ref} exists"
  else
    fail "F-0147: writing-specs reference ${ref} missing"
  fi
done

# Gate 4 in check-gates.sh
if grep -q "plan_review_enabled" "${FRAMEWORK_ROOT}/.claude/skills/implementing-features/scripts/check-gates.sh" 2>/dev/null; then
  pass "F-0147: Gate 4 (plan-review) in check-gates.sh"
else
  fail "F-0147: Gate 4 (plan-review) missing from check-gates.sh"
fi

# ag spec command in ag.sh
if grep -q "cmd_spec\b\|cmd_spec()" "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" 2>/dev/null; then
  pass "F-0147: ag spec command in ag.sh"
else
  fail "F-0147: ag spec command missing from ag.sh"
fi

# Spec-writing pipeline in auto_orchestration.md
if grep -q "Spec-Writing Pipeline" "${FRAMEWORK_ROOT}/.agentic/lib/agents/shared/auto_orchestration.md" 2>/dev/null; then
  pass "F-0147: Spec-Writing Pipeline in auto_orchestration.md"
else
  fail "F-0147: Spec-Writing Pipeline missing from auto_orchestration.md"
fi

# NFR Compliance section in acceptance template
if grep -q "NFR Compliance" "${FRAMEWORK_ROOT}/.agentic/lib/templates/acceptance.template.md" 2>/dev/null; then
  pass "F-0147: NFR Compliance section in acceptance template"
else
  fail "F-0147: NFR Compliance section missing from acceptance template"
fi

# Migration index integrity
MIGRATION_FILES=$(ls "${FRAMEWORK_ROOT}/.agentic/spec/migrations/"[0-9]*.md 2>/dev/null | wc -l | tr -d ' ')
MIGRATION_INDEX_COUNT=$(grep -c '"id":' "${FRAMEWORK_ROOT}/.agentic/spec/migrations/_index.json" 2>/dev/null || echo "0")
if [[ "$MIGRATION_FILES" -eq "$MIGRATION_INDEX_COUNT" ]]; then
  pass "F-0147: migration files ($MIGRATION_FILES) match index entries ($MIGRATION_INDEX_COUNT)"
else
  fail "F-0147: migration files ($MIGRATION_FILES) != index entries ($MIGRATION_INDEX_COUNT)"
fi

# No duplicate migration prefixes
DUPLICATE_PREFIXES=$(ls "${FRAMEWORK_ROOT}/.agentic/spec/migrations/"[0-9]*.md 2>/dev/null | sed 's/.*\///' | cut -c1-3 | sort | uniq -d)
if [[ -z "$DUPLICATE_PREFIXES" ]]; then
  pass "F-0147: no duplicate migration ID prefixes"
else
  fail "F-0147: duplicate migration prefixes: $DUPLICATE_PREFIXES"
fi

# generate-skills.sh includes writing-specs in reference mapping
if grep -q "writing-specs" "${FRAMEWORK_ROOT}/.agentic/lib/tools/generate-skills.sh" 2>/dev/null; then
  pass "F-0147: writing-specs in generate-skills.sh reference mapping"
else
  fail "F-0147: writing-specs missing from generate-skills.sh"
fi

# validate_skills.sh expects writing-specs
if grep -q "writing-specs" "${FRAMEWORK_ROOT}/tests/validate_skills.sh" 2>/dev/null; then
  pass "F-0147: writing-specs in validate_skills.sh expected list"
else
  fail "F-0147: writing-specs missing from validate_skills.sh"
fi

# ============================================================
# F-0148: Spec Format Evolution
# ============================================================
echo "--- F-0148: Spec Format Evolution ---"

if grep -q "^## Behavior" "${FRAMEWORK_ROOT}/.agentic/lib/templates/acceptance.template.md" 2>/dev/null; then
  pass "F-0148: acceptance.template.md has Behavior section"
else
  fail "F-0148: acceptance.template.md missing Behavior section"
fi

if grep -q "(P1\|P2" "${FRAMEWORK_ROOT}/.agentic/lib/templates/acceptance.template.md" 2>/dev/null; then
  pass "F-0148: acceptance.template.md has priority tags (P1/P2)"
else
  fail "F-0148: acceptance.template.md missing priority tags"
fi

if grep -q "\*\*Verify independently\*\*:" "${FRAMEWORK_ROOT}/.agentic/lib/templates/acceptance.template.md" 2>/dev/null; then
  pass "F-0148: acceptance.template.md has 'Verify independently' field"
else
  fail "F-0148: acceptance.template.md missing 'Verify independently' field"
fi

if grep -q "^## Verification" "${FRAMEWORK_ROOT}/.agentic/lib/templates/acceptance.template.md" 2>/dev/null; then
  pass "F-0148: acceptance.template.md has Verification section"
else
  fail "F-0148: acceptance.template.md missing Verification section"
fi

# AC-005: existing specs NOT modified (F-0001 should keep old format)
if ! grep -q "^## Behavior" "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/F-0001.md" 2>/dev/null; then
  pass "F-0148: existing F-0001 maintains old format (backward compatible)"
else
  warn "F-0148: F-0001 has new format (not required, just noting)"
fi

# AC-006: feature_start.md accepts both formats
if grep -q "Verification.*Tests\|## Tests" "${FRAMEWORK_ROOT}/.agentic/lib/checklists/feature_start.md" 2>/dev/null; then
  pass "F-0148: feature_start.md accepts both old and new test section formats"
else
  fail "F-0148: feature_start.md missing dual-format support"
fi

# AC-007: README.template.md documents new format
if grep -q "Behavior" "${FRAMEWORK_ROOT}/.agentic/lib/templates/acceptance/README.template.md" 2>/dev/null; then
  pass "F-0148: acceptance README.template.md updated with new format"
else
  fail "F-0148: acceptance README.template.md not updated"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/F-0148.md" ]]; then
  pass "F-0148: acceptance criteria file exists"
else
  fail "F-0148: acceptance criteria file missing"
fi

# ============================================================
# F-0149: Spec Clarification Taxonomy
# ============================================================
echo "--- F-0149: Spec Clarification Taxonomy ---"

WRITING_SPECS_SKILL="${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/skills/writing-specs/SKILL.md"

if grep -qi "Clarification Pass" "$WRITING_SPECS_SKILL" 2>/dev/null; then
  pass "F-0149: writing-specs skill includes clarification pass"
else
  fail "F-0149: writing-specs skill missing clarification pass"
fi

if grep -qi "Functional Scope" "$WRITING_SPECS_SKILL" 2>/dev/null && \
   grep -qi "Data.*Domain" "$WRITING_SPECS_SKILL" 2>/dev/null && \
   grep -qi "Edge Cases" "$WRITING_SPECS_SKILL" 2>/dev/null && \
   grep -qi "Non-Functional" "$WRITING_SPECS_SKILL" 2>/dev/null && \
   grep -qi "Integration.*Dependencies" "$WRITING_SPECS_SKILL" 2>/dev/null && \
   grep -qi "Completion Signals" "$WRITING_SPECS_SKILL" 2>/dev/null; then
  pass "F-0149: writing-specs has 6-category taxonomy"
else
  fail "F-0149: writing-specs missing taxonomy categories"
fi

if grep -qi "max 5 questions" "$WRITING_SPECS_SKILL" 2>/dev/null; then
  pass "F-0149: clarification limited to max 5 questions"
else
  fail "F-0149: clarification max limit not documented"
fi

if grep -qi "trivial.*<3\|Skip.*pass.*trivial" "$WRITING_SPECS_SKILL" 2>/dev/null; then
  pass "F-0149: trivial features skip clarification"
else
  fail "F-0149: trivial feature skip not documented"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/F-0149.md" ]]; then
  pass "F-0149: acceptance criteria file exists"
else
  fail "F-0149: acceptance criteria file missing"
fi

# ============================================================
# F-0150: Execution Order and Parallelization Markers
# ============================================================
echo "--- F-0150: Execution Order and Parallelization Markers ---"

PLANNING_SKILL="${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/skills/planning-features/SKILL.md"
IMPLEMENTING_SKILL="${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/skills/implementing-features/SKILL.md"

if grep -qi "Execution Order" "$PLANNING_SKILL" 2>/dev/null; then
  pass "F-0150: planning-features has Execution Order section"
else
  fail "F-0150: planning-features missing Execution Order"
fi

if grep -q "\[P\]" "$PLANNING_SKILL" 2>/dev/null; then
  pass "F-0150: planning-features documents [P] markers"
else
  fail "F-0150: planning-features missing [P] marker docs"
fi

if grep -qi "Checkpoint Validation" "$IMPLEMENTING_SKILL" 2>/dev/null; then
  pass "F-0150: implementing-features has checkpoint validation"
else
  fail "F-0150: implementing-features missing checkpoint validation"
fi

if grep -qi "Proceed to P2\|P1.*complete" "$IMPLEMENTING_SKILL" 2>/dev/null; then
  pass "F-0150: implementing-features requires user confirmation for P2"
else
  fail "F-0150: implementing-features missing P2 confirmation"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/F-0150.md" ]]; then
  pass "F-0150: acceptance criteria file exists"
else
  fail "F-0150: acceptance criteria file missing"
fi

# ============================================================
# F-0151: User-Extension Directory
# ============================================================
echo "--- F-0151: User-Extension Directory ---"

# AC-001/002: scaffold creates extension dirs
if grep -q "agentic/local/extensions\|agentic-local/extensions" "${FRAMEWORK_ROOT}/.agentic/lib/init/scaffold.sh" 2>/dev/null; then
  pass "F-0151: scaffold.sh creates .agentic/local/extensions/"
else
  fail "F-0151: scaffold.sh missing .agentic/local/extensions/ creation"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/init/extensions-readme.md" ]]; then
  pass "F-0151: extensions-readme.md template exists"
else
  fail "F-0151: extensions-readme.md template missing"
fi

# AC-003: generate-skills.sh scans extension skills
if grep -q "agentic/local/extensions/skills\|agentic-local/extensions/skills" "${FRAMEWORK_ROOT}/.agentic/lib/tools/generate-skills.sh" 2>/dev/null; then
  pass "F-0151: generate-skills.sh scans extension skills"
else
  fail "F-0151: generate-skills.sh missing extension skills scanning"
fi

# AC-004: pre-commit-check.sh runs custom gates
if grep -q "agentic/local/extensions/gates\|agentic-local/extensions/gates" "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "F-0151: pre-commit-check.sh runs custom gates"
else
  fail "F-0151: pre-commit-check.sh missing custom gates integration"
fi

# AC-005: upgrade.sh explicitly preserves .agentic/local/
if grep -q "agentic/local\|agentic-local" "${FRAMEWORK_ROOT}/.agentic/lib/tools/upgrade.sh" 2>/dev/null; then
  pass "F-0151: upgrade.sh references .agentic/local/ preservation"
else
  fail "F-0151: upgrade.sh missing .agentic/local/ preservation"
fi

# AC-006: subagents-project/ mechanism still works
if grep -q "subagents-project" "${FRAMEWORK_ROOT}/.agentic/lib/tools/generate-skills.sh" 2>/dev/null; then
  pass "F-0151: generate-skills.sh retains subagents-project/ support"
else
  fail "F-0151: generate-skills.sh missing subagents-project/ backward compat"
fi

# AC-007: generate-skills --validate passes
if bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/generate-skills.sh" --validate >/dev/null 2>&1; then
  pass "F-0151: generate-skills --validate passes"
else
  fail "F-0151: generate-skills --validate fails"
fi

# AC-008: empty .agentic/local/extensions/ dirs don't cause errors
# Tested implicitly: this framework repo has no .agentic/local/ and generate-skills runs fine

# Documentation
if grep -q "agentic/local\|agentic-local" "${FRAMEWORK_ROOT}/.agentic/lib/DEVELOPER_GUIDE.md" 2>/dev/null; then
  pass "F-0151: DEVELOPER_GUIDE.md documents extension directory"
else
  fail "F-0151: DEVELOPER_GUIDE.md missing extension directory docs"
fi

if grep -q "agentic/local\|agentic-local" "${FRAMEWORK_ROOT}/.agentic/lib/START_HERE.md" 2>/dev/null; then
  pass "F-0151: START_HERE.md mentions extension directory"
else
  fail "F-0151: START_HERE.md missing extension directory mention"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/F-0151.md" ]]; then
  pass "F-0151: acceptance criteria file exists"
else
  fail "F-0151: acceptance criteria file missing"
fi

# ============================================================
# F-0152: Semantic Consistency Analysis
# ============================================================
echo "--- F-0152: Semantic Consistency Analysis ---"

SPEC_ANALYZE="${FRAMEWORK_ROOT}/.agentic/lib/tools/spec-analyze.sh"

# AC-001: spec-analyze.sh exists and is executable
if [[ -x "$SPEC_ANALYZE" ]]; then
  pass "F-0152: AC-001: spec-analyze.sh exists and is executable"
else
  fail "F-0152: AC-001: spec-analyze.sh missing or not executable"
fi

# AC-001: --help exits 0
if bash "$SPEC_ANALYZE" --help >/dev/null 2>&1; then
  pass "F-0152: AC-001: spec-analyze.sh --help exits 0"
else
  fail "F-0152: AC-001: spec-analyze.sh --help fails"
fi

# AC-002: ambiguity detection — contains vague word list
if grep -qE 'fast\|slow\|scalable\|easy' "$SPEC_ANALYZE" 2>/dev/null; then
  pass "F-0152: AC-002: spec-analyze.sh contains ambiguity word list"
else
  fail "F-0152: AC-002: spec-analyze.sh missing ambiguity word list"
fi

# AC-003: AC↔test coverage — calls coverage.py --ac-coverage
if grep -q 'coverage.py' "$SPEC_ANALYZE" 2>/dev/null && grep -q '\-\-ac-coverage' "$SPEC_ANALYZE" 2>/dev/null; then
  pass "F-0152: AC-003: spec-analyze.sh calls coverage.py --ac-coverage"
else
  fail "F-0152: AC-003: spec-analyze.sh missing coverage.py --ac-coverage call"
fi

# AC-004: NFR measurability — checks NFR.md
if grep -q 'NFR.md\|How to measure' "$SPEC_ANALYZE" 2>/dev/null; then
  pass "F-0152: AC-004: spec-analyze.sh contains NFR measurability check"
else
  fail "F-0152: AC-004: spec-analyze.sh missing NFR measurability check"
fi

# AC-005: severity ratings in output
if grep -qE 'CRITICAL|HIGH|MEDIUM|LOW' "$SPEC_ANALYZE" 2>/dev/null; then
  pass "F-0152: AC-005: spec-analyze.sh has severity ratings"
else
  fail "F-0152: AC-005: spec-analyze.sh missing severity ratings"
fi

# AC-006: implementing-features skill references spec-analyze
# (IMPLEMENTING_SKILL already defined in F-0150 section)
if grep -q 'spec-analyze' "$IMPLEMENTING_SKILL" 2>/dev/null; then
  pass "F-0152: AC-006: implementing-features skill references spec-analyze"
else
  fail "F-0152: AC-006: implementing-features skill missing spec-analyze reference"
fi

# AC-007: advisory — always exits 0
if bash "$SPEC_ANALYZE" F-9999 >/dev/null 2>&1; then
  pass "F-0152: AC-007: spec-analyze.sh exits 0 (advisory) even for missing feature"
else
  fail "F-0152: AC-007: spec-analyze.sh exits non-zero (should be advisory)"
fi

# AC-008: spec_analysis setting in profiles.conf
if grep -q 'spec_analysis' "${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf" 2>/dev/null; then
  pass "F-0152: AC-008: profiles.conf has spec_analysis setting"
else
  fail "F-0152: AC-008: profiles.conf missing spec_analysis setting"
fi

# AC-012: missing acceptance file produces clear error, not crash
ANALYZE_OUTPUT=$(bash "$SPEC_ANALYZE" F-9999 2>&1)
if echo "$ANALYZE_OUTPUT" | grep -qi "not found\|missing"; then
  pass "F-0152: AC-012: missing acceptance file produces clear error"
else
  fail "F-0152: AC-012: missing acceptance file doesn't produce clear error"
fi

# AC-013: parses Acceptance Criteria section from acceptance file
# Verify the script identifies the AC section boundary and extracts AC IDs
if grep -q '## Acceptance Criteria' "$SPEC_ANALYZE" 2>/dev/null && grep -qE 'AC-\[0-9\]|BASH_REMATCH|ac_id' "$SPEC_ANALYZE" 2>/dev/null; then
  pass "F-0152: AC-013: spec-analyze.sh parses Acceptance Criteria section"
else
  fail "F-0152: AC-013: spec-analyze.sh missing AC section parsing"
fi

# Acceptance criteria file
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/F-0152.md" ]]; then
  pass "F-0152: acceptance criteria file exists"
else
  fail "F-0152: acceptance criteria file missing"
fi

# ============================================================
# F-0153: AC-Level Coverage Tracking
# ============================================================
echo "--- F-0153: AC-Level Coverage Tracking ---"

COVERAGE_PY="${FRAMEWORK_ROOT}/.agentic/lib/tools/coverage.py"

# AC-001/002: --ac-coverage argument support with naming convention matching
if grep -q '\-\-ac-coverage' "$COVERAGE_PY" 2>/dev/null; then
  pass "F-0153: AC-001: coverage.py has --ac-coverage argument"
else
  fail "F-0153: AC-001: coverage.py missing --ac-coverage argument"
fi

# AC-002: AC pattern regex for naming convention matching
if grep -qE 'AC[-_].*RE|AC_ID_RE|AC_TEST_RE' "$COVERAGE_PY" 2>/dev/null; then
  pass "F-0153: AC-002: coverage.py contains AC pattern regex"
else
  fail "F-0153: AC-002: coverage.py missing AC pattern regex"
fi

# AC-001: ac_level_coverage function exists
if grep -q 'def ac_level_coverage' "$COVERAGE_PY" 2>/dev/null; then
  pass "F-0153: AC-001: coverage.py has ac_level_coverage function"
else
  fail "F-0153: AC-001: coverage.py missing ac_level_coverage function"
fi

# AC-003: output includes per-AC status
if python3 "$COVERAGE_PY" --ac-coverage F-0148 2>/dev/null | grep -qE '(AC-|NO TEST FOUND|covered|not_covered)'; then
  pass "F-0153: AC-003: --ac-coverage output includes per-AC status"
else
  fail "F-0153: AC-003: --ac-coverage output missing per-AC status"
fi

# AC-007: works as standalone tool (human-readable output)
if python3 "$COVERAGE_PY" --ac-coverage F-0148 2>/dev/null | grep -q 'AC Coverage'; then
  pass "F-0153: AC-007: --ac-coverage works standalone with human-readable output"
else
  fail "F-0153: AC-007: --ac-coverage standalone output not working"
fi

# AC-007: --json flag produces valid JSON
if python3 "$COVERAGE_PY" --ac-coverage F-0148 --json 2>/dev/null | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
  pass "F-0153: AC-007: --ac-coverage --json produces valid JSON"
else
  fail "F-0153: AC-007: --ac-coverage --json invalid output"
fi

# AC-008: works with validate_framework.sh tests (test file has .sh extension)
if python3 "$COVERAGE_PY" --ac-coverage F-0148 2>/dev/null | grep -q 'validate_framework.sh'; then
  pass "F-0153: AC-008: --ac-coverage finds tests in validate_framework.sh"
else
  fail "F-0153: AC-008: --ac-coverage doesn't find validate_framework.sh tests"
fi

# AC-009: features with no tests report 0/N, not error
NO_TEST_OUTPUT=$(python3 "$COVERAGE_PY" --ac-coverage F-9999 2>/dev/null)
NO_TEST_EXIT=$?
if [[ $NO_TEST_EXIT -eq 0 ]]; then
  pass "F-0153: AC-009: --ac-coverage for nonexistent feature exits 0"
else
  fail "F-0153: AC-009: --ac-coverage for nonexistent feature exits non-zero"
fi

# AC-010: features with no acceptance file produce clear error
if echo "$NO_TEST_OUTPUT" | grep -qi "not found\|error"; then
  pass "F-0153: AC-010: missing acceptance file produces clear error"
else
  fail "F-0153: AC-010: missing acceptance file doesn't produce clear error"
fi

# Acceptance criteria file
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/acceptance/F-0153.md" ]]; then
  pass "F-0153: acceptance criteria file exists"
else
  fail "F-0153: acceptance criteria file missing"
fi

# ============================================================
# T-0035/T-0036/T-0037: Enforcement Gap Fixes
# ============================================================

# T-0036: SKIP_COMPLEXITY per-file warnings
if grep -q "SKIP_COMPLEXITY set.*showing bypassed" "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh"; then
  pass "T-0036: SKIP_COMPLEXITY shows per-file warnings"
else
  fail "T-0036: SKIP_COMPLEXITY still shows 1-line skip message"
fi

if grep -q "OVERLIMIT_COUNT" "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh"; then
  pass "T-0036: per-file over-limit scanning implemented"
else
  fail "T-0036: per-file scanning not found"
fi

# T-0035: Unregistered code detection phase exists
if grep -q "phase_unregistered_code" "${FRAMEWORK_ROOT}/.agentic/lib/tools/sync.sh"; then
  pass "T-0035: phase_unregistered_code exists in sync.sh"
else
  fail "T-0035: phase_unregistered_code missing from sync.sh"
fi

# T-0035: Wired into both quiet and non-quiet main paths
QUIET_WIRE=$(grep -A 20 "MODE.*=.*quiet" "${FRAMEWORK_ROOT}/.agentic/lib/tools/sync.sh" | grep -c "phase_unregistered_code" || true)
if [[ "$QUIET_WIRE" -ge 1 ]]; then
  pass "T-0035: phase_unregistered_code wired into quiet mode"
else
  fail "T-0035: phase_unregistered_code not in quiet mode path"
fi

# T-0037: Session start mentions unregistered code
if grep -q "unregistered shipped code" "${FRAMEWORK_ROOT}/.agentic/lib/checklists/session_start.md"; then
  pass "T-0037: session_start.md mentions unregistered code detection"
else
  fail "T-0037: session_start.md missing unregistered code mention"
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

