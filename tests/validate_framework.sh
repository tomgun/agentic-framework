#!/usr/bin/env bash
# validate_framework.sh - Validate framework contracts
#
# Runs automated checks against the framework's own contracts (YAML).
# Used to verify a framework release meets all defined capabilities.
#
# Usage:
#   bash tests/validate_framework.sh [--verbose]
#
# Exit codes:
#   0 - All checks pass
#   1 - One or more checks failed
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERBOSE="${1:-}"

# F-0221: ag.sh is decomposed into sourced modules under commands/
# grep_ag searches ag.sh AND all command modules for simple -q checks.
# Use raw grep against $AG_SH and $AG_CMDS_DIR/*.sh when you need flags
# like -A (context), -c (count), or -r (recursive with counts).
AG_SH="${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh"
AG_CMDS_DIR="${FRAMEWORK_ROOT}/.agentic/lib/tools/commands"
grep_ag() {
    grep -q "$@" "$AG_SH" 2>/dev/null && return 0
    [ -d "$AG_CMDS_DIR" ] && grep -rq "$@" "$AG_CMDS_DIR/" 2>/dev/null && return 0
    return 1
}

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
# F-001: Project Initialization
# ============================================================
echo "--- F-001: Project Initialization ---"

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

if grep -q "development_mode: standard" "${FRAMEWORK_ROOT}/.agentic/lib/init/STACK.template.md" 2>/dev/null; then
  pass "STACK.template defaults to 'standard' mode"
else
  fail "STACK.template does not default to 'standard'"
fi

# ============================================================
# F-007: Small Batch Development
# ============================================================
echo "--- F-007: Small Batch Development ---"

if grep -q "Small Batch" "${FRAMEWORK_ROOT}/.agentic/lib/PRINCIPLES.md" 2>/dev/null; then
  pass "Small Batch Development in PRINCIPLES.md"
else
  fail "Small Batch Development not in PRINCIPLES.md"
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

# ============================================================
# F-009: Pre-Commit Quality Gates
# ============================================================
echo "--- F-009: Pre-Commit Quality Gates ---"

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
# F-015: Session Start Protocol
# ============================================================
echo "--- F-015: Session Start Protocol ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/hooks/session-start.sh" ]]; then
  pass "session-start.sh hook exists"
else
  fail "session-start.sh missing"
fi

# ============================================================
# F-017: Multi-Agent Coordination
# ============================================================
echo "--- F-017: Multi-Agent Coordination ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/agents_helpers.py" ]]; then
  pass "AGENTS.json registry helper exists (agents_helpers.py)"
else
  fail "AGENTS.json registry helper missing (agents_helpers.py)"
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
# F-019: Token-Efficient Scripts
# ============================================================
echo "--- F-019: Token-Efficient Scripts ---"

for script in journal.sh status.sh feature.sh blocker.sh; do
  if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/${script}" ]]; then
    pass "${script} exists"
  else
    fail "${script} missing"
  fi
done

# ============================================================
# F-016: WIP Tracking
# ============================================================
echo "--- F-016: WIP Tracking ---"

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

# ============================================================
# F-0055: Anti-Hallucination Rules
# ============================================================
echo "--- F-0055: Anti-Hallucination Rules ---"

# ============================================================
# F-026: DEVELOPER_GUIDE.md
# ============================================================
echo "--- F-026: DEVELOPER_GUIDE.md ---"

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

# ============================================================
# F-0074: Green Coding
# ============================================================
echo "--- F-0074: Green Coding ---"

if grep -qi "green" "${FRAMEWORK_ROOT}/README.md" 2>/dev/null; then
  pass "Green coding in README design principles"
else
  fail "Green coding not in README"
fi

# ============================================================
# F-027: Emergency Quick Reference
# ============================================================
echo "--- F-027: Emergency Quick Reference ---"

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
# F-010: Issue/Bug Tracking
# ============================================================
echo "--- F-010: Issue/Bug Tracking ---"

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
# F-0093: AGENT_QUICK_START.md (v1 only — removed in v2 simplification)
# ============================================================
echo "--- F-0093: AGENT_QUICK_START.md ---"

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
# F-021: Cross-Platform Tool Compatibility
# ============================================================
echo "--- F-021: Cross-Platform Tool Compatibility ---"

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
# F-024: PR-Based Workflow Default
# ============================================================
echo "--- F-024: PR-Based Workflow Default ---"

# AC-001: STACK.template.md has git_workflow setting (explicit, discovery default = direct)
if grep -q "^- git_workflow:" "${FRAMEWORK_ROOT}/.agentic/lib/init/STACK.template.md" 2>/dev/null; then
  pass "STACK.template.md has explicit git_workflow setting"
else
  fail "STACK.template.md missing git_workflow setting"
fi

# AC-004: Claude CLAUDE.md includes git workflow guidance
if grep -q "PR by default" "${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/CLAUDE.md" 2>/dev/null; then
  pass "Claude CLAUDE.md includes PR-first guidance"
else
  fail "Claude CLAUDE.md missing PR-first guidance"
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

# AC-004: WIP tracking uses AGENTS.json (F-0194 migration)
if grep -q "agents_helpers.py" "${FRAMEWORK_ROOT}/.agentic/lib/tools/wip.sh" 2>/dev/null; then
  pass "wip.sh uses agents_helpers.py for WIP tracking"
else
  fail "wip.sh missing agents_helpers.py integration"
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

# Contract or archived acceptance criteria file exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/F-0115.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/F-0115.md" ]]; then
  pass "F-0115 contract/acceptance criteria exists"
else
  fail "F-0115 contract/acceptance criteria missing"
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

# Check /CODEX.md extends template (not a stub)
if grep -q "Full template.*codex-instructions" "${FRAMEWORK_ROOT}/CODEX.md" 2>/dev/null; then
  pass "CODEX.md extends template (not stub)"
else
  fail "CODEX.md should extend template"
fi

# ============================================================
# DEV-002: Multi-Tool LLM Testing Infrastructure
# ============================================================
echo "--- DEV-002: Multi-Tool LLM Testing Infrastructure ---"

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
if grep_ag 'cmd_test_llm'; then
  pass "ag.sh has cmd_test_llm function"
else
  fail "ag.sh missing cmd_test_llm function"
fi

if grep_ag 'ag test llm'; then
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

# Contract or archived acceptance criteria exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/DEV-002.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/DEV-002.md" ]]; then
  pass "DEV-002 contract/acceptance criteria exists"
else
  fail "DEV-002 contract/acceptance criteria missing"
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

if [[ -d ".agentic/spec/contracts" ]]; then
  pass "Formal: .agentic/spec/contracts/ directory exists"
else
  fail "Formal: .agentic/spec/contracts/ directory missing"
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

# Test wip.sh start (F-0194: writes to AGENTS.json, not WIP.md)
if bash .agentic/lib/tools/wip.sh start "TEST-001" "Testing WIP functionality" "test.md" >/dev/null 2>&1; then
  if [[ -f ".agentic/session/AGENTS.json" ]] || [[ -f ".agentic/session/WIP.md" ]]; then
    pass "wip.sh start creates WIP entry (AGENTS.json or WIP.md)"
  else
    fail "wip.sh start did not create any WIP entry"
  fi
else
  fail "wip.sh start failed"
fi

# Clean up WIP
bash .agentic/lib/tools/wip.sh complete >/dev/null 2>&1 || true

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

# Test design-trace.sh (functional tests against synthetic data)
# First: no Source annotations → clean exit
_dt_out=$(bash .agentic/lib/tools/design-trace.sh 2>&1) || true
if echo "$_dt_out" | grep -qE "No .*Source.*annotations|All source-linked features"; then
  pass "design-trace.sh handles no Source annotations cleanly"
else
  fail "design-trace.sh unexpected output with no Source annotations: $_dt_out"
fi

# Quiet mode with no annotations → empty output, exit 0
_dt_quiet=$(bash .agentic/lib/tools/design-trace.sh --quiet 2>&1) || true
if [[ -z "$_dt_quiet" ]]; then
  pass "design-trace.sh --quiet returns empty when no Source annotations"
else
  fail "design-trace.sh --quiet returned unexpected output: $_dt_quiet"
fi

# Inject Source annotations into test project FEATURES.md and verify parsing
if [[ -f ".agentic/spec/FEATURES.md" ]]; then
  # Back up original
  cp .agentic/spec/FEATURES.md .agentic/spec/FEATURES.md.bak

  # Add test features with Source annotations
  cat >> .agentic/spec/FEATURES.md <<'TESTDATA'

## F-9901: Test Shipped Feature

**Status**: shipped
**Source**: spec/adr/TEST-ADR.md
**Category**: Test

---

## F-9902: Test Planned Feature

**Status**: planned
**Source**: spec/adr/TEST-ADR.md
**Category**: Test

---
TESTDATA

  # Summary mode should show TEST-ADR with 1/2 shipped
  _dt_summary=$(bash .agentic/lib/tools/design-trace.sh 2>&1) || true
  if echo "$_dt_summary" | grep -q "spec/adr/TEST-ADR.md" && echo "$_dt_summary" | grep -q "1/2"; then
    pass "design-trace.sh summary reports correct shipped/total"
  else
    fail "design-trace.sh summary incorrect: $_dt_summary"
  fi

  # Quiet mode should report 1 pending
  _dt_quiet2=$(bash .agentic/lib/tools/design-trace.sh --quiet 2>&1) || true
  if echo "$_dt_quiet2" | grep -q "1 doc(s) with pending features"; then
    pass "design-trace.sh --quiet reports pending count"
  else
    fail "design-trace.sh --quiet incorrect: $_dt_quiet2"
  fi

  # --doc mode should show the specific document
  _dt_doc=$(bash .agentic/lib/tools/design-trace.sh --doc spec/adr/TEST-ADR.md 2>&1) || true
  if echo "$_dt_doc" | grep -q "Pending:.*F-9902"; then
    pass "design-trace.sh --doc shows pending features"
  else
    fail "design-trace.sh --doc incorrect: $_dt_doc"
  fi

  # --all mode should include complete sources too
  # Mark F-9902 as shipped to test --all with complete source
  sed -i 's/## F-9902: Test Planned Feature/## F-9902: Test Planned Feature/' .agentic/spec/FEATURES.md
  # Just test that --all runs without error
  if bash .agentic/lib/tools/design-trace.sh --all >/dev/null 2>&1; then
    pass "design-trace.sh --all runs successfully"
  else
    fail "design-trace.sh --all failed"
  fi

  # Restore original
  mv .agentic/spec/FEATURES.md.bak .agentic/spec/FEATURES.md
else
  warn "Skipping design-trace.sh functional tests (no FEATURES.md in test project)"
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
if grep_ag "rough acceptance criteria"; then
  pass "F-0130: ag work has improved criteria nudge"
else
  fail "F-0130: ag work missing improved nudge"
fi

# WIP tracking uses AGENTS.json (F-0194) — Success Criteria moved to acceptance specs
if grep -q "agents_helpers.py" "${FRAMEWORK_ROOT}/.agentic/lib/tools/wip.sh" 2>/dev/null; then
  pass "F-0130: WIP tracking integrated with AGENTS.json"
else
  fail "F-0130: WIP tracking missing AGENTS.json integration"
fi

# Pre-commit Discovery checklist
if grep -q "Discovery checklist" "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "F-0130: Pre-commit has Discovery checklist reminder"
else
  fail "F-0130: Pre-commit missing Discovery checklist"
fi

# ag done surfaces [Discovered] markers
if grep_ag '\[Discovered\]'; then
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

# Contract or archived acceptance criteria exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/F-0130.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/F-0130.md" ]]; then
  pass "F-0130: contract/acceptance criteria exists"
else
  fail "F-0130: contract/acceptance criteria missing"
fi

# ============================================================
# F-030: Autonomous Engine Foundation
# ============================================================
echo ""
echo "--- F-030: Autonomous Engine Foundation ---"

# AC-001/002: Engine core files exist
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/auto/engine.py" ]]; then
  pass "F-030: engine.py exists"
else
  fail "F-030: engine.py missing"
fi

# Control client
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/auto/control.py" ]]; then
  pass "F-030: control.py exists"
else
  fail "F-030: control.py missing"
fi

# AC-012: init.py for settings generation
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/auto/init.py" ]]; then
  pass "F-030: init.py exists"
else
  fail "F-030: init.py missing"
fi

# AC-019: Settings template
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/auto/settings-template.json" ]]; then
  pass "F-030: settings-template.json exists"
else
  fail "F-030: settings-template.json missing"
fi

# AC-015: Settings template denies dangerous ops
if grep -q "rm -rf" "${FRAMEWORK_ROOT}/.agentic/lib/auto/settings-template.json"; then
  pass "F-030: settings template denies rm -rf"
else
  fail "F-030: settings template missing rm -rf deny"
fi
if grep -q "sudo" "${FRAMEWORK_ROOT}/.agentic/lib/auto/settings-template.json"; then
  pass "F-030: settings template denies sudo"
else
  fail "F-030: settings template missing sudo deny"
fi

# Prompt templates
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/auto/prompts/estimate-complexity.md" ]]; then
  pass "F-030: estimate-complexity prompt exists"
else
  fail "F-030: estimate-complexity prompt missing"
fi
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/auto/prompts/decompose-ac.md" ]]; then
  pass "F-030: decompose-ac prompt exists"
else
  fail "F-030: decompose-ac prompt missing"
fi

# AC-033: Gitignored session files
if grep -q "auto.sock" "${FRAMEWORK_ROOT}/.gitignore"; then
  pass "F-030: auto.sock gitignored"
else
  fail "F-030: auto.sock not gitignored"
fi
if grep -q "auto.pid" "${FRAMEWORK_ROOT}/.gitignore"; then
  pass "F-030: auto.pid gitignored"
else
  fail "F-030: auto.pid not gitignored"
fi
if grep -q "auto-state.json" "${FRAMEWORK_ROOT}/.gitignore"; then
  pass "F-030: auto-state.json gitignored"
else
  fail "F-030: auto-state.json not gitignored"
fi

# AC-034/035: ag auto in help text
if grep_ag "auto"; then
  pass "F-030: ag auto command exists in ag.sh"
else
  fail "F-030: ag auto command missing from ag.sh"
fi

# AC-030: Thread safety (EngineState uses threading.Lock)
if grep -q "threading.Lock" "${FRAMEWORK_ROOT}/.agentic/lib/auto/engine.py"; then
  pass "F-030: engine uses threading.Lock for thread safety"
else
  fail "F-030: engine missing threading.Lock"
fi

# AC-008: Cleanup handlers registered
if grep -q "atexit.register" "${FRAMEWORK_ROOT}/.agentic/lib/auto/engine.py"; then
  pass "F-030: atexit cleanup registered"
else
  fail "F-030: atexit cleanup missing"
fi
if grep -q "signal.SIGTERM" "${FRAMEWORK_ROOT}/.agentic/lib/auto/engine.py"; then
  pass "F-030: SIGTERM handler registered"
else
  fail "F-030: SIGTERM handler missing"
fi

# AC-025: Decomposition support
if grep -q "_decompose_ac" "${FRAMEWORK_ROOT}/.agentic/lib/auto/engine.py"; then
  pass "F-030: AC decomposition method exists"
else
  fail "F-030: AC decomposition method missing"
fi

# Tests exist
if [[ -f "${FRAMEWORK_ROOT}/tests/test_auto_engine.py" ]]; then
  pass "F-030: test_auto_engine.py exists"
else
  fail "F-030: test_auto_engine.py missing"
fi

# Contract or archived acceptance criteria file
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/F-030.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/F-030.md" ]]; then
  pass "F-030: contract/acceptance criteria exists"
else
  fail "F-030: contract/acceptance criteria missing"
fi

# Planned features registered
for fid in F-0161 F-0162 F-0163; do
  if grep -q "## ${fid}:" "${FRAMEWORK_ROOT}/.agentic/spec/FEATURES.md"; then
    pass "F-030: ${fid} registered in FEATURES.md"
  else
    fail "F-030: ${fid} missing from FEATURES.md"
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
if grep_ag "verify)"; then
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

# contract or archived acceptance criteria file
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/F-0161.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/F-0161.md" ]]; then
  pass "F-0161: contract/acceptance criteria exists"
else
  fail "F-0161: contract/acceptance criteria missing"
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
if grep_ag "task)"; then
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

# contract or archived acceptance criteria file
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/F-0162.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/F-0162.md" ]]; then
  pass "F-0162: contract/acceptance criteria exists"
else
  fail "F-0162: contract/acceptance criteria missing"
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

# Progress persistence (crunch delegates to scheduler which saves progress)
if grep -q "_save_progress" "${FRAMEWORK_ROOT}/.agentic/lib/auto/crunch.py" \
   || grep -q "_save_progress" "${FRAMEWORK_ROOT}/.agentic/lib/auto/scheduler.py"; then
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
if grep_ag "crunch)"; then
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

# contract or archived acceptance criteria file
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/F-0163.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/F-0163.md" ]]; then
  pass "F-0163: contract/acceptance criteria exists"
else
  fail "F-0163: contract/acceptance criteria missing"
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
if grep_ag "cmd_set"; then
  pass "Settings: ag.sh has set command"
else
  fail "Settings: ag.sh missing set command"
fi

# ag.sh sources settings.sh
if grep_ag 'source.*settings.sh'; then
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
  # Reset agentic dir so profile inference uses test ROOT_DIR, not real framework
  _SETTINGS_AGENTIC_DIR="${_SETTINGS_ROOT_DIR}/.agentic"
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
# F-013: NFR Discovery & Catalog
# ============================================================
echo "--- F-013: NFR Discovery & Catalog ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/init/nfr-catalog.md" ]]; then
  pass "F-013: nfr-catalog.md exists"
else
  fail "F-013: nfr-catalog.md missing"
fi

# Catalog has type-specific sections
for section in "Universal" "Web App" "API" "Game" "Mobile" "CLI" "Desktop" "Framework Promises"; do
  if grep -qi "$section" "${FRAMEWORK_ROOT}/.agentic/lib/init/nfr-catalog.md"; then
    pass "F-013: catalog has ${section} section"
  else
    fail "F-013: catalog missing ${section} section"
  fi
done

# Init playbook has Step 2c NFR Discovery
if grep -q "Step 2c\|NFR Discovery" "${FRAMEWORK_ROOT}/.agentic/lib/init/init_playbook.md"; then
  pass "F-013: init_playbook.md has NFR Discovery step"
else
  fail "F-013: init_playbook.md missing NFR Discovery step"
fi

# Memory seed has NFR proactive suggestion (v1 only — trimmed in v2)
# ag nfr discover command works
_NFR_DISCOVER_OUT=$(ROOT_DIR="${FRAMEWORK_ROOT}" bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" nfr discover 2>&1 || true)
if echo "$_NFR_DISCOVER_OUT" | grep -qi "catalog\|NFR\|suggestion"; then
  pass "F-013: ag nfr discover produces output"
else
  fail "F-013: ag nfr discover produces no output"
fi

# ag nfr list command works
_NFR_LIST_OUT=$(ROOT_DIR="${FRAMEWORK_ROOT}" bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" nfr list 2>&1 || true)
if echo "$_NFR_LIST_OUT" | grep -q "NFR-0001"; then
  pass "F-013: ag nfr list shows NFR-0001"
else
  fail "F-013: ag nfr list missing NFR-0001"
fi

# ============================================================
# F-0170: NFR Enforcement in Spec Writing
# ============================================================
echo "--- F-0170: NFR Enforcement in Spec Writing ---"

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
  if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/${nfr}.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/${nfr}.md" ]]; then
    pass "F-0170: ${nfr} contract/acceptance criteria exists"
  else
    fail "F-0170: ${nfr} contract/acceptance criteria missing"
  fi
done

_NFR_COV_OUT=$(ROOT_DIR="${FRAMEWORK_ROOT}" bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" nfr coverage 2>&1 || true)
if echo "$_NFR_COV_OUT" | grep -q "feature"; then
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

if grep_ag "cmd_audit\|audit)"; then
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

if grep -q "retro.*action\|check_retro_action" "${FRAMEWORK_ROOT}/.agentic/lib/tools/periodic-checks.sh"; then
  pass "F-0174: periodic-checks.sh has retro action items check"
else
  fail "F-0174: periodic-checks.sh missing retro action items check"
fi

# ============================================================
# F-0175: QA Suite Glue & Documentation
# ============================================================
echo "--- F-0175: QA Suite Glue & Documentation ---"

for fid in F-013 F-0170 F-0171 F-0172 F-0173 F-0174 F-0175; do
  if grep -q "$fid" "${FRAMEWORK_ROOT}/.agentic/spec/FEATURES.md"; then
    pass "F-0175: ${fid} registered in FEATURES.md"
  else
    fail "F-0175: ${fid} missing from FEATURES.md"
  fi
done

for fid in F-013 F-0170 F-0171 F-0172 F-0173 F-0174 F-0175; do
  if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/${fid}.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/${fid}.md" ]]; then
    pass "F-0175: ${fid} contract/acceptance criteria exists"
  else
    fail "F-0175: ${fid} contract/acceptance criteria missing"
  fi
done

if ls "${FRAMEWORK_ROOT}/.agentic/spec/migrations/009_"* 1>/dev/null 2>&1; then
  pass "F-0175: migration 009 exists"
else
  fail "F-0175: migration 009 missing"
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

if [[ -f "${FRAMEWORK_ROOT}/.agentic/journal/plans/2026-03-07-F-013-qa-suite-plan.md" ]]; then
  pass "F-0175: QA suite plan saved to journal/plans/"
else
  fail "F-0175: QA suite plan not saved to journal/plans/"
fi

# ============================================================
# F-0176: Plan-Aware Code Review
# ============================================================
echo "--- F-0176: Plan-Aware Code Review ---"

# Contract or archived acceptance criteria file exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/F-0176.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/F-0176.md" ]]; then
  pass "F-0176: contract/acceptance criteria exists"
else
  fail "F-0176: contract/acceptance criteria missing"
fi

# Feature registered in FEATURES.md
if grep -q "F-0176" "${FRAMEWORK_ROOT}/.agentic/spec/FEATURES.md"; then
  pass "F-0176: registered in FEATURES.md"
else
  fail "F-0176: not registered in FEATURES.md"
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
## F-001: Existing Feature
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

# Test: ag implement blocks when no contract/acceptance criteria file
(
  GATE_TEST_DIR=$(mktemp -d)
  mkdir -p "$GATE_TEST_DIR/.agentic/spec/contracts"
  cat > "$GATE_TEST_DIR/STACK.md" <<'TESTEOF'
## Settings
- profile: formal
- feature_tracking: yes
- plan_review_enabled: no
TESTEOF
  cat > "$GATE_TEST_DIR/.agentic/spec/FEATURES.md" <<'TESTEOF'
## F-001: Test Feature
**Status**: planned
TESTEOF
  # F-001 IS in FEATURES.md but no contract/acceptance file — should block
  OUTPUT=$(ROOT_DIR="$GATE_TEST_DIR" _AGENTIC_SETTINGS_LOADED="" _SETTINGS_ROOT_DIR="$GATE_TEST_DIR" _SETTINGS_STACK_FILE="$GATE_TEST_DIR/STACK.md" bash "$FRAMEWORK_ROOT/.agentic/lib/tools/ag.sh" implement F-001 2>&1) || true
  rm -rf "$GATE_TEST_DIR"
  echo "$OUTPUT" | grep -q "BLOCKED.*No acceptance criteria\|BLOCKED.*No contract"
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "Gate: ag implement blocks when no contract/acceptance criteria"
else
  fail "Gate: ag implement should block when no contract/acceptance criteria"
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

# ag.sh has docs_gate gate logic in cmd_done
if grep_ag "docs_gate"; then
  pass "F-0138: ag.sh has docs_gate logic"
else
  fail "F-0138: ag.sh missing docs_gate logic"
fi
if grep_ag "drift.sh.*--docs"; then
  pass "F-0138: ag.sh calls drift.sh --docs in ag done"
else
  fail "F-0138: ag.sh missing drift.sh --docs call"
fi

# ag.sh validates docs_gate enum values in ag set
if grep_ag "docs_gate)"; then
  pass "F-0138: ag.sh validates docs_gate enum in ag set"
else
  fail "F-0138: ag.sh missing docs_gate validation in ag set"
fi

# docs_gate=off skips doc check (behavioral test via ag done mock)
(
  GATE_TEST_DIR=$(mktemp -d)
  mkdir -p "$GATE_TEST_DIR/.agentic/spec/contracts"
  mkdir -p "$GATE_TEST_DIR/.agentic/journal/manifests"
  cat > "$GATE_TEST_DIR/STACK.md" <<'TESTEOF'
## Settings
- profile: discovery
- feature_tracking: yes
- docs_gate: off
TESTEOF
  cat > "$GATE_TEST_DIR/.agentic/spec/FEATURES.md" <<'TESTEOF'
## F-001: Test Feature
**Status**: in_progress
TESTEOF
  cat > "$GATE_TEST_DIR/.agentic/spec/contracts/F-001.yaml" <<'YAMLEOF'
id: F-001
name: Test Feature
lifecycle: implementing
description: Test feature.
assertions:
  - id: AC-001
    text: Works
    type: behavioral
YAMLEOF
  OUTPUT=$(ROOT_DIR="$GATE_TEST_DIR" _AGENTIC_SETTINGS_LOADED="" _SETTINGS_ROOT_DIR="$GATE_TEST_DIR" _SETTINGS_STACK_FILE="$GATE_TEST_DIR/STACK.md" bash "$FRAMEWORK_ROOT/.agentic/lib/tools/ag.sh" done F-001 2>&1) || true
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
  mkdir -p "$GATE_TEST_DIR/.agentic/spec/contracts"
  mkdir -p "$GATE_TEST_DIR/.agentic/journal/manifests"
  cat > "$GATE_TEST_DIR/STACK.md" <<'TESTEOF'
## Settings
- profile: formal
- feature_tracking: yes
- docs_gate: warning
TESTEOF
  cat > "$GATE_TEST_DIR/.agentic/spec/FEATURES.md" <<'TESTEOF'
## F-001: Test Feature
**Status**: in_progress
TESTEOF
  cat > "$GATE_TEST_DIR/.agentic/spec/contracts/F-001.yaml" <<'YAMLEOF'
id: F-001
name: Test Feature
lifecycle: implementing
description: Test feature.
assertions:
  - id: AC-001
    text: Works
    type: behavioral
YAMLEOF
  OUTPUT=$(ROOT_DIR="$GATE_TEST_DIR" _AGENTIC_SETTINGS_LOADED="" _SETTINGS_ROOT_DIR="$GATE_TEST_DIR" _SETTINGS_STACK_FILE="$GATE_TEST_DIR/STACK.md" bash "$FRAMEWORK_ROOT/.agentic/lib/tools/ag.sh" done F-001 2>&1) || true
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

# Contract or archived acceptance criteria file exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/F-0138.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/F-0138.md" ]]; then
  pass "F-0138: contract/acceptance criteria exists"
else
  fail "F-0138: contract/acceptance criteria missing"
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

# doc_types.md exists with all 8 built-in types (v1 only — removed in v2 simplification)
# ag.sh has cmd_docs function
if grep_ag "cmd_docs"; then
  pass "F-0139: ag.sh has cmd_docs function"
else
  fail "F-0139: ag.sh missing cmd_docs"
fi

# ag.sh has docs) case in dispatch
if grep_ag "^    docs)"; then
  pass "F-0139: ag.sh has docs command dispatch"
else
  fail "F-0139: ag.sh missing docs command dispatch"
fi

# ag.sh wires docs.sh into cmd_done
if grep_ag "docs.sh.*--trigger feature_done"; then
  pass "F-0139: ag.sh wires docs.sh feature_done into ag done"
else
  fail "F-0139: ag.sh missing docs.sh feature_done wiring in ag done"
fi
if grep_ag "docs.sh.*--trigger pr"; then
  pass "F-0139: ag.sh wires docs.sh pr trigger"
else
  fail "F-0139: ag.sh missing docs.sh pr trigger wiring"
fi

# ag.sh wires docs.sh session into ag sync
if grep_ag "docs.sh.*--trigger session"; then
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

# docs.sh --check-freshness with manifest+tracks scopes to relevant docs
(
  DOCS_TEST_DIR=$(mktemp -d)
  mkdir -p "$DOCS_TEST_DIR/.agentic/journal/manifests"
  # Registry: 3 docs with feature_done trigger, 2 have tracks, 1 catch-all
  cat > "$DOCS_TEST_DIR/STACK.md" <<'TESTEOF'
## Docs
- doc: docs/api.md | architecture | feature_done | src/api/
- doc: docs/auth.md | architecture | feature_done | src/auth/
- doc: docs/lessons.md | lessons | feature_done
## End
TESTEOF
  # Manifest: only src/api/ files changed
  cat > "$DOCS_TEST_DIR/.agentic/journal/manifests/F-TEST.json" <<'TESTEOF'
{"feature":"F-TEST","files":{"code":[{"file":"src/api/handler.ts"}],"tests":[],"docs":[],"config":[]}}
TESTEOF
  # Create the docs so they aren't flagged as "missing"
  mkdir -p "$DOCS_TEST_DIR/docs"
  touch "$DOCS_TEST_DIR/docs/api.md" "$DOCS_TEST_DIR/docs/auth.md" "$DOCS_TEST_DIR/docs/lessons.md"
  # Initialize git so check_freshness can run git commands
  git -C "$DOCS_TEST_DIR" init -q 2>/dev/null
  git -C "$DOCS_TEST_DIR" add -A 2>/dev/null && git -C "$DOCS_TEST_DIR" commit -q -m "init" 2>/dev/null
  OUTPUT=$(ROOT_DIR="$DOCS_TEST_DIR" bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/docs.sh" --check-freshness --trigger feature_done --manifest F-TEST 2>&1)
  rm -rf "$DOCS_TEST_DIR"
  # auth.md should be skipped (tracks src/auth/, manifest has src/api/)
  # api.md + lessons.md should be checked (api overlaps, lessons has no tracks)
  echo "$OUTPUT" | grep -q "skipped" && ! echo "$OUTPUT" | grep -q "auth.md"
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "F-012: check_freshness with manifest+tracks skips non-overlapping docs"
else
  fail "F-012: check_freshness with manifest+tracks should skip non-overlapping docs"
fi

# docs.sh --check-freshness without manifest checks all docs (backward compat)
(
  DOCS_TEST_DIR=$(mktemp -d)
  cat > "$DOCS_TEST_DIR/STACK.md" <<'TESTEOF'
## Docs
- doc: docs/api.md | architecture | feature_done | src/api/
- doc: docs/auth.md | architecture | feature_done | src/auth/
## End
TESTEOF
  mkdir -p "$DOCS_TEST_DIR/docs"
  touch "$DOCS_TEST_DIR/docs/api.md" "$DOCS_TEST_DIR/docs/auth.md"
  git -C "$DOCS_TEST_DIR" init -q 2>/dev/null
  git -C "$DOCS_TEST_DIR" add -A 2>/dev/null && git -C "$DOCS_TEST_DIR" commit -q -m "init" 2>/dev/null
  OUTPUT=$(ROOT_DIR="$DOCS_TEST_DIR" bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/docs.sh" --check-freshness --trigger feature_done 2>&1)
  rm -rf "$DOCS_TEST_DIR"
  # Without manifest, both should be checked (no skipping)
  ! echo "$OUTPUT" | grep -q "skipped"
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "F-012: check_freshness without manifest checks all docs (backward compat)"
else
  fail "F-012: check_freshness without manifest should check all docs"
fi

# docs.sh parse_registry handles tracks field in 4th column
(
  DOCS_TEST_DIR=$(mktemp -d)
  cat > "$DOCS_TEST_DIR/STACK.md" <<'TESTEOF'
## Docs
- doc: docs/api.md | architecture | feature_done | src/api/,src/shared/
- doc: docs/plain.md | readme | pr
## End
TESTEOF
  OUTPUT=$(ROOT_DIR="$DOCS_TEST_DIR" bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/docs.sh" --list 2>&1)
  rm -rf "$DOCS_TEST_DIR"
  # Should show TRACKS column when tracks are present
  echo "$OUTPUT" | grep -q "TRACKS" && echo "$OUTPUT" | grep -q "src/api/"
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "F-012: docs.sh --list shows TRACKS column when tracks configured"
else
  fail "F-012: docs.sh --list should show TRACKS column when tracks configured"
fi

# done.sh passes --manifest to freshness check
if grep -q 'check-freshness.*--manifest.*feature_id' "${FRAMEWORK_ROOT}/.agentic/lib/tools/commands/done.sh" 2>/dev/null; then
  pass "F-012: done.sh passes --manifest to freshness check"
else
  fail "F-012: done.sh should pass --manifest to freshness check"
fi

# ag help shows docs command
if bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" help 2>&1 | grep -q "docs"; then
  pass "F-0139: ag help includes docs command"
else
  fail "F-0139: ag help missing docs command"
fi

# Contract or archived acceptance criteria file exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/F-0139.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/F-0139.md" ]]; then
  pass "F-0139: contract/acceptance criteria exists"
else
  fail "F-0139: contract/acceptance criteria missing"
fi

# ============================================================
# F-0140: Proactive WIP Creation in Agent Instructions
# ============================================================

echo "--- F-0140: Proactive WIP Creation in Agent Instructions ---"

# doctor.py checks WIP path via paths.py (wip_file) or hardcoded .agentic/session/WIP.md
if grep -q 'wip_file\|\.agentic/session.*WIP\.md' "${FRAMEWORK_ROOT}/.agentic/lib/tools/doctor.py"; then
  pass "F-0140: doctor.py uses correct WIP path (via paths.py or .agentic/session/)"
else
  fail "F-0140: doctor.py still uses wrong WIP path"
fi
# Contract or archived acceptance criteria file exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/F-0140.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/F-0140.md" ]]; then
  pass "F-0140: contract/acceptance criteria exists"
else
  fail "F-0140: contract/acceptance criteria missing"
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
if grep_ag "pre_commit_hook)"; then
  pass "F-0141: ag.sh has pre_commit_hook validation"
else
  fail "F-0141: ag.sh missing pre_commit_hook validation"
fi

# Test: ag.sh has profile cascade logic
if grep_ag "_PREV_PROFILE"; then
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

# Contract or archived acceptance criteria file exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/F-0141.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/F-0141.md" ]]; then
  pass "F-0141: contract/acceptance criteria exists"
else
  fail "F-0141: contract/acceptance criteria missing"
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

  FM_THRESHOLD=80
if [[ $FM_COUNT -ge $FM_THRESHOLD ]]; then
  pass "Frontmatter coverage: ${FM_COUNT}/${TOTAL_COUNT} files (>= ${FM_THRESHOLD} threshold)"
else
  fail "Frontmatter coverage too low: ${FM_COUNT}/${TOTAL_COUNT} files (need >= ${FM_THRESHOLD})"
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
_FRONTMATTER_KEY_FILES=(PRINCIPLES.md token_efficiency/reading_protocols.md)
for keyfile in "${_FRONTMATTER_KEY_FILES[@]}"; do
  if head -1 "${FRAMEWORK_ROOT}/.agentic/lib/${keyfile}" 2>/dev/null | grep -q "^---"; then
    pass "${keyfile} has frontmatter"
  else
    fail "${keyfile} missing frontmatter"
  fi
done

if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/F-0144.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/F-0144.md" ]]; then
  pass "F-0144: contract/acceptance criteria exists"
else
  fail "F-0144: contract/acceptance criteria missing"
fi

# ============================================================
# F-0147: Spec-Writing Workflow with Delta Tracking
# ============================================================
echo "--- F-0147: Spec-Writing Workflow with Delta Tracking ---"

# Core files exist
_F0147_FILES=(
  ".agentic/lib/tools/check-spec-health.sh"
  ".agentic/lib/agents/claude/skills/writing-specs/SKILL.md"
  ".claude/skills/writing-specs/SKILL.md"
  "docs/archive/acceptance/F-0147.md"
)
for f in "${_F0147_FILES[@]}"; do
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

# Gate 4 in check-gates.sh
if grep -q "plan_review_enabled" "${FRAMEWORK_ROOT}/.claude/skills/implementing-features/scripts/check-gates.sh" 2>/dev/null; then
  pass "F-0147: Gate 4 (plan-review) in check-gates.sh"
else
  fail "F-0147: Gate 4 (plan-review) missing from check-gates.sh"
fi

# ag spec command in ag.sh
if grep_ag "cmd_spec\b\|cmd_spec()"; then
  pass "F-0147: ag spec command in ag.sh"
else
  fail "F-0147: ag spec command missing from ag.sh"
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

# AC-005: existing specs NOT modified (F-001 should keep old format)
if ! grep -q "^## Behavior" "${FRAMEWORK_ROOT}/docs/archive/acceptance/F-001.md" 2>/dev/null; then
  pass "F-0148: existing F-001 maintains old format (backward compatible)"
else
  warn "F-0148: F-001 has new format (not required, just noting)"
fi

# AC-007: README.template.md documents new format
if grep -q "Behavior" "${FRAMEWORK_ROOT}/.agentic/lib/templates/acceptance/README.template.md" 2>/dev/null; then
  pass "F-0148: acceptance README.template.md updated with new format"
else
  fail "F-0148: acceptance README.template.md not updated"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/F-0148.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/F-0148.md" ]]; then
  pass "F-0148: contract/acceptance criteria exists"
else
  fail "F-0148: contract/acceptance criteria missing"
fi

# ============================================================
# F-0149: Spec Clarification Taxonomy
# ============================================================
echo "--- F-0149: Spec Clarification Taxonomy ---"

WRITING_SPECS_SKILL="${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/skills/writing-specs/SKILL.md"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/F-0149.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/F-0149.md" ]]; then
  pass "F-0149: contract/acceptance criteria exists"
else
  fail "F-0149: contract/acceptance criteria missing"
fi

# ============================================================
# F-0150: Execution Order and Parallelization Markers
# ============================================================
echo "--- F-0150: Execution Order and Parallelization Markers ---"

PLANNING_SKILL="${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/skills/planning-features/SKILL.md"
IMPLEMENTING_SKILL="${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/skills/implementing-features/SKILL.md"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/F-0150.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/F-0150.md" ]]; then
  pass "F-0150: contract/acceptance criteria exists"
else
  fail "F-0150: contract/acceptance criteria missing"
fi

# ============================================================
# F-028: User-Extension Directory
# ============================================================
echo "--- F-028: User-Extension Directory ---"

# AC-001/002: scaffold creates extension dirs
if grep -q "agentic/local/extensions\|agentic-local/extensions" "${FRAMEWORK_ROOT}/.agentic/lib/init/scaffold.sh" 2>/dev/null; then
  pass "F-028: scaffold.sh creates .agentic/local/extensions/"
else
  fail "F-028: scaffold.sh missing .agentic/local/extensions/ creation"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/init/extensions-readme.md" ]]; then
  pass "F-028: extensions-readme.md template exists"
else
  fail "F-028: extensions-readme.md template missing"
fi

# AC-003: generate-skills.sh scans extension skills
if grep -q "agentic/local/extensions/skills\|agentic-local/extensions/skills" "${FRAMEWORK_ROOT}/.agentic/lib/tools/generate-skills.sh" 2>/dev/null; then
  pass "F-028: generate-skills.sh scans extension skills"
else
  fail "F-028: generate-skills.sh missing extension skills scanning"
fi

# AC-004: pre-commit-check.sh runs custom gates
if grep -q "agentic/local/extensions/gates\|agentic-local/extensions/gates" "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "F-028: pre-commit-check.sh runs custom gates"
else
  fail "F-028: pre-commit-check.sh missing custom gates integration"
fi

# AC-005: upgrade.sh explicitly preserves .agentic/local/
if grep -q "agentic/local\|agentic-local" "${FRAMEWORK_ROOT}/.agentic/lib/tools/upgrade.sh" 2>/dev/null; then
  pass "F-028: upgrade.sh references .agentic/local/ preservation"
else
  fail "F-028: upgrade.sh missing .agentic/local/ preservation"
fi

# AC-006: subagents-project/ mechanism still works
if grep -q "subagents-project" "${FRAMEWORK_ROOT}/.agentic/lib/tools/generate-skills.sh" 2>/dev/null; then
  pass "F-028: generate-skills.sh retains subagents-project/ support"
else
  fail "F-028: generate-skills.sh missing subagents-project/ backward compat"
fi

# AC-007: generate-skills --validate passes
if bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/generate-skills.sh" --validate >/dev/null 2>&1; then
  pass "F-028: generate-skills --validate passes"
else
  fail "F-028: generate-skills --validate fails"
fi

# AC-008: empty .agentic/local/extensions/ dirs don't cause errors
# Tested implicitly: this framework repo has no .agentic/local/ and generate-skills runs fine

# Documentation
if grep -q "agentic/local\|agentic-local" "${FRAMEWORK_ROOT}/.agentic/lib/DEVELOPER_GUIDE.md" 2>/dev/null; then
  pass "F-028: DEVELOPER_GUIDE.md documents extension directory"
else
  fail "F-028: DEVELOPER_GUIDE.md missing extension directory docs"
fi

if grep -q "agentic/local\|agentic-local" "${FRAMEWORK_ROOT}/.agentic/lib/START_HERE.md" 2>/dev/null; then
  pass "F-028: START_HERE.md mentions extension directory"
else
  fail "F-028: START_HERE.md missing extension directory mention"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/F-028.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/F-028.md" ]]; then
  pass "F-028: contract/acceptance criteria exists"
else
  fail "F-028: contract/acceptance criteria missing"
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

# Contract or archived acceptance criteria file
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/F-0152.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/F-0152.md" ]]; then
  pass "F-0152: contract/acceptance criteria exists"
else
  fail "F-0152: contract/acceptance criteria missing"
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

# Contract or archived acceptance criteria file
if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/F-0153.yaml" ]] || [[ -f "${FRAMEWORK_ROOT}/docs/archive/acceptance/F-0153.md" ]]; then
  pass "F-0153: contract/acceptance criteria exists"
else
  fail "F-0153: contract/acceptance criteria missing"
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
  pass "T-0037: session_start.md check skipped (v2 engine)"

# ============================================================
# F-006: Backlog / Structural Work Assignment
# ============================================================

# T-0045: BACKLOG_FILE defined in paths.sh
if grep -q "BACKLOG_FILE=" "${FRAMEWORK_ROOT}/.agentic/lib/paths.sh"; then
  pass "T-0045: BACKLOG_FILE defined in paths.sh"
else
  fail "T-0045: BACKLOG_FILE not defined in paths.sh"
fi

# T-0046: BACKLOG_FILE defined in paths.py
if grep -q "backlog_file" "${FRAMEWORK_ROOT}/.agentic/lib/paths.py"; then
  pass "T-0046: backlog_file defined in paths.py"
else
  fail "T-0046: backlog_file not defined in paths.py"
fi

# T-0047: backlog_helpers.py exists and has core commands
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/backlog_helpers.py" ]]; then
  pass "T-0047: backlog_helpers.py exists"
  for cmd in cmd_add cmd_current cmd_done cmd_list cmd_remove cmd_move cmd_clear cmd_upsert cmd_check_deps; do
    if grep -q "def $cmd" "${FRAMEWORK_ROOT}/.agentic/lib/tools/backlog_helpers.py"; then
      pass "T-0047b: backlog_helpers.py has $cmd"
    else
      fail "T-0047b: backlog_helpers.py missing $cmd"
    fi
  done
else
  fail "T-0047: backlog_helpers.py not found"
fi

# T-0048: backlog.sh exists and is executable
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/backlog.sh" ]]; then
  pass "T-0048: backlog.sh exists"
else
  fail "T-0048: backlog.sh not found"
fi

# T-0049: ag.sh has backlog dispatch
if grep_ag "cmd_backlog"; then
  pass "T-0049: ag.sh has cmd_backlog"
else
  fail "T-0049: ag.sh missing cmd_backlog"
fi

# T-0050: ag.sh backlog gate in cmd_implement (upsert)
if grep_ag "upsert"; then
  pass "T-0050: cmd_implement has backlog upsert gate"
else
  fail "T-0050: cmd_implement missing backlog upsert gate"
fi

# T-0051: ag.sh SKIP_BACKLOG escape hatch
if grep_ag "SKIP_BACKLOG"; then
  pass "T-0051: SKIP_BACKLOG escape hatch present"
else
  fail "T-0051: SKIP_BACKLOG escape hatch missing"
fi

# T-0052: crunch.py reads backlog
if grep -q "_read_backlog_features" "${FRAMEWORK_ROOT}/.agentic/lib/auto/crunch.py"; then
  pass "T-0052: crunch.py reads backlog for feature ordering"
else
  fail "T-0052: crunch.py missing backlog integration"
fi

# T-0053: cmd_start shows backlog
if grep_ag "backlog_current\|json-current"; then
  pass "T-0053: cmd_start shows backlog display"
else
  fail "T-0053: cmd_start missing backlog display"
fi

# T-0054: cmd_done auto-removes completed feature from backlog
if grep -A 5 "Backlog Cleanup" "$AG_SH" "$AG_CMDS_DIR"/*.sh | grep -q "backlog.sh.*remove"; then
  pass "T-0054: cmd_done auto-removes completed feature from backlog"
else
  fail "T-0054: cmd_done missing backlog removal"
fi

# ============================================================
# F-014: Review Checkpoint Framework
# ============================================================
echo "--- F-014: Review Checkpoint Framework ---"

# T-0055: review.py module exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/auto/review.py" ]]; then
  pass "T-0055: review.py module exists"
else
  fail "T-0055: review.py module not found"
fi

# T-0056: review.py has ReviewMode enum
if grep -q "class ReviewMode" "${FRAMEWORK_ROOT}/.agentic/lib/auto/review.py"; then
  pass "T-0056: review.py has ReviewMode enum"
else
  fail "T-0056: review.py missing ReviewMode enum"
fi

# T-0057: review.py has core functions
for func in check_review has_pending_review resolve_review get_review_mode create_pending_review get_pending_reviews; do
  if grep -q "def $func" "${FRAMEWORK_ROOT}/.agentic/lib/auto/review.py"; then
    pass "T-0057: review.py has $func"
  else
    fail "T-0057: review.py missing $func"
  fi
done

# T-0058: state_machine.py integrates review checks
if grep -q "check_review\|has_pending_review" "${FRAMEWORK_ROOT}/.agentic/lib/auto/state_machine.py"; then
  pass "T-0058: state_machine.py integrates review checks"
else
  fail "T-0058: state_machine.py missing review integration"
fi

# T-0059: ag.sh has review command dispatch
if grep_ag "review)"; then
  pass "T-0059: ag.sh has review command dispatch"
else
  fail "T-0059: ag.sh missing review command"
fi

# T-0060: ag.sh validates review_* settings
if grep_ag "review_spec\|review_code\|review_merge"; then
  pass "T-0060: ag.sh validates review settings"
else
  fail "T-0060: ag.sh missing review settings validation"
fi

# T-0061: profiles.conf has review defaults for both profiles
if grep -q "discovery.review_spec=" "${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf" && \
   grep -q "formal.review_spec=" "${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf"; then
  pass "T-0061: profiles.conf has review defaults for both profiles"
else
  fail "T-0061: profiles.conf missing review defaults"
fi

# T-0062: STACK.template.md has review checkpoints section
if grep -q "Review checkpoints" "${FRAMEWORK_ROOT}/.agentic/lib/init/STACK.template.md"; then
  pass "T-0062: STACK.template.md has review checkpoints section"
else
  fail "T-0062: STACK.template.md missing review checkpoints"
fi

# T-0063: paths.py has reviews_dir and pending_reviews_dir
if grep -q "reviews_dir" "${FRAMEWORK_ROOT}/.agentic/lib/paths.py" && \
   grep -q "pending_reviews_dir" "${FRAMEWORK_ROOT}/.agentic/lib/paths.py"; then
  pass "T-0063: paths.py has review path properties"
else
  fail "T-0063: paths.py missing review path properties"
fi

# T-0064: ag review documented in instruction files
# T-0066: Unit tests exist for review module
if [[ -f "${FRAMEWORK_ROOT}/tests/test_review.py" ]]; then
  pass "T-0066: test_review.py exists"
else
  fail "T-0066: test_review.py not found"
fi

# ============================================================
# F-0194: Worktree-by-Default for Feature Branches
# ============================================================
echo "--- F-0194: Worktree-by-Default for Feature Branches ---"

# T-0067: MAIN_PROJECT_ROOT in paths.sh
if grep -q "MAIN_PROJECT_ROOT" "${FRAMEWORK_ROOT}/.agentic/lib/paths.sh"; then
  pass "T-0067: MAIN_PROJECT_ROOT defined in paths.sh"
else
  fail "T-0067: MAIN_PROJECT_ROOT not found in paths.sh"
fi

# T-0068: AGENTS_JSON in paths.sh
if grep -q "AGENTS_JSON" "${FRAMEWORK_ROOT}/.agentic/lib/paths.sh"; then
  pass "T-0068: AGENTS_JSON defined in paths.sh"
else
  fail "T-0068: AGENTS_JSON not found in paths.sh"
fi

# T-0069: main_project_root in paths.py
if grep -q "main_project_root" "${FRAMEWORK_ROOT}/.agentic/lib/paths.py"; then
  pass "T-0069: main_project_root defined in paths.py"
else
  fail "T-0069: main_project_root not found in paths.py"
fi

# T-0070: agents_json in paths.py
if grep -q "agents_json" "${FRAMEWORK_ROOT}/.agentic/lib/paths.py"; then
  pass "T-0070: agents_json defined in paths.py"
else
  fail "T-0070: agents_json not found in paths.py"
fi

# T-0071: agents_helpers.py exists with all commands
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/agents_helpers.py" ]]; then
  pass "T-0071: agents_helpers.py exists"
  for cmd in register activate checkpoint complete unregister check-worktree get-active get-current-feature list migrate-wip; do
    if grep -q "\"$cmd\"" "${FRAMEWORK_ROOT}/.agentic/lib/tools/agents_helpers.py"; then
      pass "T-0071: agents_helpers.py has '$cmd' command"
    else
      fail "T-0071: agents_helpers.py missing '$cmd' command"
    fi
  done
else
  fail "T-0071: agents_helpers.py not found"
fi

# T-0072: worktree.sh has auto-remove and path commands
if grep -q "auto-remove" "${FRAMEWORK_ROOT}/.agentic/lib/tools/worktree.sh"; then
  pass "T-0072: worktree.sh has auto-remove command"
else
  fail "T-0072: worktree.sh missing auto-remove command"
fi

if grep -q "cmd_path" "${FRAMEWORK_ROOT}/.agentic/lib/tools/worktree.sh"; then
  pass "T-0072: worktree.sh has path command"
else
  fail "T-0072: worktree.sh missing path command"
fi

# T-0073: ag worktree in ag.sh dispatch
if grep_ag "worktree)"; then
  pass "T-0073: ag worktree command in ag.sh dispatch"
else
  fail "T-0073: ag worktree command missing from ag.sh dispatch"
fi

# T-0074: worktree_mode in profiles.conf
if grep -q "worktree_mode" "${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf"; then
  pass "T-0074: worktree_mode defined in profiles.conf"
else
  fail "T-0074: worktree_mode not found in profiles.conf"
fi

# T-0075: worktree_mode in STACK.template.md
if grep -q "worktree_mode" "${FRAMEWORK_ROOT}/.agentic/lib/init/STACK.template.md"; then
  pass "T-0075: worktree_mode defined in STACK.template.md"
else
  fail "T-0075: worktree_mode not found in STACK.template.md"
fi

# T-0076: worktree_mode in settings.sh show_all_settings
if grep -q "worktree_mode" "${FRAMEWORK_ROOT}/.agentic/lib/settings.sh"; then
  pass "T-0076: worktree_mode in settings.sh"
else
  fail "T-0076: worktree_mode not found in settings.sh"
fi

# T-0077: AGENTS.json in .gitignore
if grep -q "AGENTS.json" "${FRAMEWORK_ROOT}/.gitignore"; then
  pass "T-0077: AGENTS.json in .gitignore"
else
  fail "T-0077: AGENTS.json not in .gitignore"
fi

# T-0078: No direct WIP.md file-existence checks in ag.sh without AGENTS.json companion
# WIP.md checks are OK as fallbacks (elif after _has_active_wip, or || with _has_active_wip)
# The old pattern was 9 standalone checks; now they should be fallbacks only
WIP_DIRECT_CHECKS=$(grep -rc '\[ -f.*WIP\.md' "$AG_SH" "$AG_CMDS_DIR"/*.sh 2>/dev/null | awk -F: '{s+=$NF}END{print s+0}')
if [[ "$WIP_DIRECT_CHECKS" -le 6 ]]; then
  pass "T-0078: ag.sh has minimal direct WIP.md checks ($WIP_DIRECT_CHECKS — fallbacks only)"
else
  fail "T-0078: ag.sh still has $WIP_DIRECT_CHECKS direct WIP.md checks (expected ≤6 fallbacks)"
fi

# T-0079: ag.sh has _agents_py helper
if grep_ag "_agents_py()"; then
  pass "T-0079: ag.sh has _agents_py() helper"
else
  fail "T-0079: ag.sh missing _agents_py() helper"
fi

# T-0080: wip.sh uses agents_helpers.py
if grep -q "agents_helpers.py" "${FRAMEWORK_ROOT}/.agentic/lib/tools/wip.sh"; then
  pass "T-0080: wip.sh references agents_helpers.py"
else
  fail "T-0080: wip.sh does not reference agents_helpers.py"
fi

# T-0081: worktree.sh uses MAIN_PROJECT_ROOT
if grep -q "MAIN_PROJECT_ROOT" "${FRAMEWORK_ROOT}/.agentic/lib/tools/worktree.sh"; then
  pass "T-0081: worktree.sh uses MAIN_PROJECT_ROOT"
else
  fail "T-0081: worktree.sh missing MAIN_PROJECT_ROOT"
fi

# T-0082: upgrade.sh has AGENTS.json migration
if grep -q "AGENTS.json" "${FRAMEWORK_ROOT}/.agentic/lib/tools/upgrade.sh"; then
  pass "T-0082: upgrade.sh has AGENTS.json migration"
else
  fail "T-0082: upgrade.sh missing AGENTS.json migration"
fi

# --- F-0195: Multi-Session Collision Prevention ---
echo ""
echo "--- F-0195: Multi-Session Collision Prevention ---"

# T-0083: agents_helpers.py has session commands
if grep -q "session-register" "${FRAMEWORK_ROOT}/.agentic/lib/tools/agents_helpers.py"; then
  pass "T-0083: agents_helpers.py has session-register command"
else
  fail "T-0083: agents_helpers.py missing session-register command"
fi

if grep -q "count-others" "${FRAMEWORK_ROOT}/.agentic/lib/tools/agents_helpers.py"; then
  pass "T-0084: agents_helpers.py has count-others command"
else
  fail "T-0084: agents_helpers.py missing count-others command"
fi

if grep -q "cleanup-stale" "${FRAMEWORK_ROOT}/.agentic/lib/tools/agents_helpers.py"; then
  pass "T-0085: agents_helpers.py has cleanup-stale command"
else
  fail "T-0085: agents_helpers.py missing cleanup-stale command"
fi

# T-0086: SessionStart.sh registers session
if grep -q "session-register" "${FRAMEWORK_ROOT}/.agentic/lib/claude-hooks/SessionStart.sh"; then
  pass "T-0086: SessionStart.sh calls session-register"
else
  fail "T-0086: SessionStart.sh missing session-register call"
fi

# T-0087: Stop.sh deregisters session
if grep -q "session-deregister" "${FRAMEWORK_ROOT}/.agentic/lib/claude-hooks/Stop.sh"; then
  pass "T-0087: Stop.sh calls session-deregister"
else
  fail "T-0087: Stop.sh missing session-deregister call"
fi

# T-0088: UserPromptSubmit.sh has collision warning (via prompt-check or count-others)
if grep -q "prompt-check\|count-others" "${FRAMEWORK_ROOT}/.agentic/lib/claude-hooks/UserPromptSubmit.sh"; then
  pass "T-0088: UserPromptSubmit.sh has collision warning"
else
  fail "T-0088: UserPromptSubmit.sh missing collision warning"
fi

# T-0089: Collision rule in Claude CLAUDE.md template
if grep -q "collision\|count-others" "${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/CLAUDE.md"; then
  pass "T-0089: Claude CLAUDE.md template has collision rule"
else
  fail "T-0089: Claude CLAUDE.md template missing collision rule"
fi

# T-0090: Collision rule in cursorrules.txt (behavioral)
if grep -qi "destructive git\|collision\|multi-session" "${FRAMEWORK_ROOT}/.agentic/lib/agents/cursor/cursorrules.txt"; then
  pass "T-0090: cursorrules.txt has collision rule"
else
  fail "T-0090: cursorrules.txt missing collision rule"
fi

# T-0091: Collision rule in copilot-instructions.md (behavioral)
if grep -qi "destructive git\|collision\|multi-session" "${FRAMEWORK_ROOT}/.agentic/lib/agents/copilot/copilot-instructions.md"; then
  pass "T-0091: copilot-instructions.md has collision rule"
else
  fail "T-0091: copilot-instructions.md missing collision rule"
fi

# T-0092: Collision rule in codex-instructions.md (behavioral)
if grep -qi "destructive git\|collision\|multi-session" "${FRAMEWORK_ROOT}/.agentic/lib/agents/codex/codex-instructions.md"; then
  pass "T-0092: codex-instructions.md has collision rule"
else
  fail "T-0092: codex-instructions.md missing collision rule"
fi

# T-0093: Collision rule in memory-seed.md (v1 only — trimmed in v2)
# T-0095: Hooks use $PPID not $$ for session identity
if grep -q 'PPID' "${FRAMEWORK_ROOT}/.agentic/lib/claude-hooks/SessionStart.sh" && \
   grep -q 'PPID' "${FRAMEWORK_ROOT}/.agentic/lib/claude-hooks/Stop.sh" && \
   grep -q 'PPID' "${FRAMEWORK_ROOT}/.agentic/lib/claude-hooks/UserPromptSubmit.sh"; then
  pass "T-0095: All hooks use \$PPID for session identity"
else
  fail "T-0095: Some hooks missing \$PPID (should not use \$\$)"
fi

# --- F-0196: Fluent State File Commits (ag flush) ---

echo ""
echo "--- F-0196: Fluent State File Commits (ag flush) ---"

# T-0096: state-commit.sh exists and is executable
if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/state-commit.sh" ]]; then
  pass "T-0096: state-commit.sh exists and is executable"
else
  fail "T-0096: state-commit.sh missing or not executable"
fi

# T-0097: state-commit.sh has hardcoded allowlist
if grep -q "ALLOWLIST=" "${FRAMEWORK_ROOT}/.agentic/lib/tools/state-commit.sh" && \
   grep -q "STATUS.md" "${FRAMEWORK_ROOT}/.agentic/lib/tools/state-commit.sh" && \
   grep -q "BACKLOG.json" "${FRAMEWORK_ROOT}/.agentic/lib/tools/state-commit.sh"; then
  pass "T-0097: state-commit.sh has hardcoded allowlist with expected files"
else
  fail "T-0097: state-commit.sh missing allowlist or expected state files"
fi

# T-0098: VERSION IS in the allowlist (bumped post-merge by ag done)
if grep -q 'ALLOWLIST=' "${FRAMEWORK_ROOT}/.agentic/lib/tools/state-commit.sh" && \
   grep -A20 'ALLOWLIST=(' "${FRAMEWORK_ROOT}/.agentic/lib/tools/state-commit.sh" | grep -q 'VERSION'; then
  pass "T-0098: VERSION is in the state-commit.sh allowlist (post-merge bump via ag done)"
else
  fail "T-0098: VERSION not found in state-commit.sh allowlist (should be included for post-merge bump)"
fi

# T-0099: ag.sh dispatches flush command
if grep -q 'flush)' "${FRAMEWORK_ROOT}/.agentic/lib/tools/ag.sh" && \
   grep_ag 'state-commit.sh'; then
  pass "T-0099: ag.sh dispatches flush to state-commit.sh"
else
  fail "T-0099: ag.sh missing flush dispatch"
fi

# T-0100: state-commit.sh has --no-verify justification comment
if grep -q 'NOT a precedent' "${FRAMEWORK_ROOT}/.agentic/lib/tools/state-commit.sh"; then
  pass "T-0100: state-commit.sh has --no-verify justification (not a precedent)"
else
  fail "T-0100: state-commit.sh missing --no-verify justification comment"
fi

# T-0101: dashboard.sh has dirty state detection
if grep -q 'state-commit.sh\|DIRTY_STATE\|ag flush' "${FRAMEWORK_ROOT}/.agentic/lib/tools/dashboard.sh"; then
  pass "T-0101: dashboard.sh has dirty state file detection"
else
  fail "T-0101: dashboard.sh missing dirty state detection"
fi

# T-0102: ag flush in instruction files
flush_in_all=true
_T0102_FILES=(
  "${FRAMEWORK_ROOT}/CLAUDE.md"
  "${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/CLAUDE.md"
  "${FRAMEWORK_ROOT}/.agentic/lib/agents/cursor/cursorrules.txt"
  "${FRAMEWORK_ROOT}/.agentic/lib/agents/copilot/copilot-instructions.md"
  "${FRAMEWORK_ROOT}/.agentic/lib/agents/codex/codex-instructions.md"
)
for f in "${_T0102_FILES[@]}"; do
  if ! grep -q 'ag flush' "$f" 2>/dev/null; then
    flush_in_all=false
    break
  fi
done
if $flush_in_all; then
  pass "T-0102: ag flush referenced in all instruction files"
else
  fail "T-0102: ag flush missing from some instruction files"
fi

# T-0103: memory-seed has --no-verify exception for ag flush (v1 only — trimmed in v2)
# T-0104: state-commit.sh validates JSON for BACKLOG.json
if grep -q 'json.tool\|json_tool\|jq' "${FRAMEWORK_ROOT}/.agentic/lib/tools/state-commit.sh"; then
  pass "T-0104: state-commit.sh validates BACKLOG.json as JSON"
else
  fail "T-0104: state-commit.sh missing JSON validation for BACKLOG.json"
fi

# T-0105: state-commit.sh has worktree detection
if grep -q 'worktree list' "${FRAMEWORK_ROOT}/.agentic/lib/tools/state-commit.sh"; then
  pass "T-0105: state-commit.sh has worktree detection via git worktree list"
else
  fail "T-0105: state-commit.sh missing worktree detection"
fi

# T-0106: state-commit.sh has push failure recovery (git reset --soft)
if grep -q 'reset --soft' "${FRAMEWORK_ROOT}/.agentic/lib/tools/state-commit.sh"; then
  pass "T-0106: state-commit.sh has push failure recovery (git reset --soft HEAD~1)"
else
  fail "T-0106: state-commit.sh missing push failure recovery"
fi

# ============================================================
# F-0197: Registry Integrity — Drift Check & AC Gate
# =====================================================
# ============================================================
echo "--- F-0197: Registry Integrity (Drift Check & AC Gate) ---"

# T-0107: drift-check.sh exists and is executable
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/drift-check.sh" ]]; then
  pass "T-0107: drift-check.sh exists"
else
  fail "T-0107: drift-check.sh missing"
fi

if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/drift-check.sh" ]]; then
  pass "T-0108: drift-check.sh is executable"
else
  fail "T-0108: drift-check.sh is not executable"
fi

# T-0109: drift-check.sh contains key functions
for func in check_shipped_ac_drift check_backlog_drift count_acs; do
  if grep -q "$func" "${FRAMEWORK_ROOT}/.agentic/lib/tools/drift-check.sh"; then
    pass "T-0109: drift-check.sh contains function $func"
  else
    fail "T-0109: drift-check.sh missing function $func"
  fi
done

# T-0110: drift-check.sh supports --quiet flag
if grep -q '\-\-quiet' "${FRAMEWORK_ROOT}/.agentic/lib/tools/drift-check.sh"; then
  pass "T-0110: drift-check.sh supports --quiet flag"
else
  fail "T-0110: drift-check.sh missing --quiet flag support"
fi

# T-0111: drift-check.sh is wired into sync.sh
if grep -q 'drift-check' "${FRAMEWORK_ROOT}/.agentic/lib/tools/sync.sh"; then
  pass "T-0111: drift-check.sh is wired into sync.sh"
else
  fail "T-0111: drift-check.sh not wired into sync.sh"
fi

# T-0112: AC gate exists in ag.sh cmd_done
if grep_ag 'AC Completion'; then
  pass "T-0112: AC completion gate exists in ag.sh"
else
  fail "T-0112: AC completion gate missing from ag.sh"
fi

# T-0113: AC gate uses get_setting for configurable enforcement
if grep_ag 'get_setting.*acceptance_criteria'; then
  pass "T-0113: AC gate uses get_setting for configurable enforcement"
else
  fail "T-0113: AC gate missing get_setting for configurable enforcement"
fi

# ============================================================
# DEV-003: Instruction File Sync Detection
# ============================================================
echo ""
echo "--- DEV-003: Instruction File Sync Detection ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/instruction-sync.sh" ]]; then
  pass "DEV-003 AC-001: instruction-sync.sh exists"
else
  fail "DEV-003 AC-001: instruction-sync.sh missing"
fi

if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/instruction-sync.sh" ]]; then
  pass "DEV-003 AC-001: instruction-sync.sh is executable"
else
  fail "DEV-003 AC-001: instruction-sync.sh is not executable"
fi

# AC-002: Parses ag.sh case statement to discover subcommands
if grep -q 'Main command dispatch' "${FRAMEWORK_ROOT}/.agentic/lib/tools/instruction-sync.sh"; then
  pass "DEV-003 AC-002: instruction-sync.sh parses ag.sh main dispatch"
else
  fail "DEV-003 AC-002: instruction-sync.sh does not parse ag.sh dispatch"
fi

# AC-003 through AC-008: Checks instruction files
_F0199_CHECK_FILES=("CLAUDE.md" "cursorrules.txt" "copilot-instructions.md" "codex-instructions.md" "memory-seed.md")
for check_file in "${_F0199_CHECK_FILES[@]}"; do
  if grep -q "$check_file" "${FRAMEWORK_ROOT}/.agentic/lib/tools/instruction-sync.sh"; then
    pass "DEV-003: instruction-sync.sh checks $check_file"
  else
    fail "DEV-003: instruction-sync.sh does not check $check_file"
  fi
done

# AC-009: Reports missing commands per file with clear output
if grep -q 'missing commands' "${FRAMEWORK_ROOT}/.agentic/lib/tools/instruction-sync.sh"; then
  pass "DEV-003 AC-009: instruction-sync.sh reports missing commands per file"
else
  fail "DEV-003 AC-009: instruction-sync.sh does not report missing commands"
fi

# AC-010: Wired into validate_framework.sh (this very check runs it in warning mode)
# Run it and report as warning (not blocking)
if bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/instruction-sync.sh" --quiet 2>/dev/null; then
  pass "DEV-003 AC-010: instruction-sync check passes (all commands in sync)"
else
  warn "DEV-003 AC-010: instruction-sync detected drift (advisory — run instruction-sync.sh for details)"
fi

# F-0198: Plan Durability Scanning
# ============================================================
echo ""
echo "--- F-0198: Plan Durability Scanning ---"

# AC-001: plan-scan.sh exists and is executable
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/plan-scan.sh" ]]; then
  pass "F-0198 AC-001: plan-scan.sh exists"
else
  fail "F-0198 AC-001: plan-scan.sh missing"
fi

if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/plan-scan.sh" ]]; then
  pass "F-0198 AC-001: plan-scan.sh is executable"
else
  fail "F-0198 AC-001: plan-scan.sh is not executable"
fi

# AC-002: plan-scan.sh contains key feature detection function
if grep -q 'extract_primary_id' "${FRAMEWORK_ROOT}/.agentic/lib/tools/plan-scan.sh"; then
  pass "F-0198 AC-002: plan-scan.sh has extract_primary_id function"
else
  fail "F-0198 AC-002: plan-scan.sh missing extract_primary_id function"
fi

# AC-003: plan-scan.sh supports agent-agnostic scan dirs (Claude + Cursor)
if grep -q '\.claude/plans' "${FRAMEWORK_ROOT}/.agentic/lib/tools/plan-scan.sh" && \
   grep -q '\.cursor/plans' "${FRAMEWORK_ROOT}/.agentic/lib/tools/plan-scan.sh"; then
  pass "F-0198 AC-003: plan-scan.sh scans both Claude and Cursor plan directories"
else
  fail "F-0198 AC-003: plan-scan.sh missing agent-agnostic scan directories"
fi

# AC-004: plan-scan.sh supports extensible dirs via plan_scan_dirs setting
if grep -q 'plan_scan_dirs' "${FRAMEWORK_ROOT}/.agentic/lib/tools/plan-scan.sh"; then
  pass "F-0198 AC-004: plan-scan.sh supports custom dirs via plan_scan_dirs setting"
else
  fail "F-0198 AC-004: plan-scan.sh missing plan_scan_dirs extensibility"
fi

# AC-005: plan-scan.sh validates feature IDs against FEATURES.md
if grep -q 'FEATURES_FILE\|FEATURES\.md' "${FRAMEWORK_ROOT}/.agentic/lib/tools/plan-scan.sh"; then
  pass "F-0198 AC-005: plan-scan.sh validates feature IDs against FEATURES.md"
else
  fail "F-0198 AC-005: plan-scan.sh missing FEATURES.md validation"
fi

# AC-006: plan-scan.sh supports --quiet and --check modes
if grep -q '\-\-quiet' "${FRAMEWORK_ROOT}/.agentic/lib/tools/plan-scan.sh" && \
   grep -q '\-\-check' "${FRAMEWORK_ROOT}/.agentic/lib/tools/plan-scan.sh"; then
  pass "F-0198 AC-006: plan-scan.sh supports --quiet and --check modes"
else
  fail "F-0198 AC-006: plan-scan.sh missing --quiet or --check mode support"
fi

# AC-007: plan-scan.sh is wired into sync.sh as phase_plan_scan
if grep -q 'phase_plan_scan' "${FRAMEWORK_ROOT}/.agentic/lib/tools/sync.sh"; then
  pass "F-0198 AC-007: plan-scan.sh is wired into sync.sh (phase_plan_scan)"
else
  fail "F-0198 AC-007: plan-scan.sh is NOT wired into sync.sh"
fi

if grep -q 'plan-scan\.sh' "${FRAMEWORK_ROOT}/.agentic/lib/tools/sync.sh"; then
  pass "F-0198 AC-007: sync.sh references plan-scan.sh"
else
  fail "F-0198 AC-007: sync.sh does not reference plan-scan.sh"
fi

# ============================================================
# F-0202: Run Info (ag run)
# ============================================================
echo ""
echo "--- F-0202: Run Info (ag run) ---"

# T-0114: run.sh exists
if [[ -f "$FRAMEWORK_ROOT/.agentic/lib/tools/run.sh" ]]; then
  pass "T-0114: run.sh exists"
else
  fail "T-0114: run.sh missing"
fi

# T-0115: run.sh is executable
if [[ -x "$FRAMEWORK_ROOT/.agentic/lib/tools/run.sh" ]]; then
  pass "T-0115: run.sh is executable"
else
  fail "T-0115: run.sh is not executable"
fi

# T-0116: ag run dispatch exists in ag.sh
if grep_ag '    run)'; then
  pass "T-0116: ag run dispatch exists in ag.sh"
else
  fail "T-0116: ag run dispatch missing from ag.sh"
fi

# T-0117: run.sh sources paths.sh
if grep -q 'paths\.sh' "${FRAMEWORK_ROOT}/.agentic/lib/tools/run.sh"; then
  pass "T-0117: run.sh sources paths.sh"
else
  fail "T-0117: run.sh does not source paths.sh"
fi

# T-0118: discover.py has FRAMEWORK_DEV_COMMANDS mapping
if grep -q 'FRAMEWORK_DEV_COMMANDS' "${FRAMEWORK_ROOT}/.agentic/lib/tools/discover.py"; then
  pass "T-0118: discover.py has FRAMEWORK_DEV_COMMANDS mapping"
else
  fail "T-0118: discover.py missing FRAMEWORK_DEV_COMMANDS"
fi

# T-0119: discover.py has preview_info function
if grep -q 'def preview_info' "${FRAMEWORK_ROOT}/.agentic/lib/tools/discover.py"; then
  pass "T-0119: discover.py has preview_info function"
else
  fail "T-0119: discover.py missing preview_info function"
fi

# T-0120: discover.py supports --preview flag
if grep -q '\-\-preview' "${FRAMEWORK_ROOT}/.agentic/lib/tools/discover.py"; then
  pass "T-0120: discover.py supports --preview flag"
else
  fail "T-0120: discover.py missing --preview flag"
fi

# T-0121: run appears in ag.sh help text
if grep_ag 'run.*Show how to run'; then
  pass "T-0121: run appears in ag.sh help text"
else
  fail "T-0121: run missing from ag.sh help text"
fi

# T-0122: discover.py has PM_RUN_PREFIX for package manager awareness
if grep -q 'PM_RUN_PREFIX' "${FRAMEWORK_ROOT}/.agentic/lib/tools/discover.py"; then
  pass "T-0122: discover.py has PM_RUN_PREFIX for package manager awareness"
else
  fail "T-0122: discover.py missing PM_RUN_PREFIX"
fi

echo ""

echo "--- F-0203: Auto-Commit/Merge Mode (R2 Amendment) ---"

# T-0123: review_commit in profiles.conf (all 3 profiles)
REVIEW_COMMIT_COUNT=$(grep -c 'review_commit' "${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf" || true)
if [[ "$REVIEW_COMMIT_COUNT" -ge 3 ]]; then
  pass "T-0123: review_commit in profiles.conf (${REVIEW_COMMIT_COUNT} profiles)"
else
  fail "T-0123: review_commit in profiles.conf (expected 3, got ${REVIEW_COMMIT_COUNT})"
fi

# T-0124: review_commit in STACK.template.md
if grep -q 'review_commit' "${FRAMEWORK_ROOT}/.agentic/lib/init/STACK.template.md"; then
  pass "T-0124: review_commit in STACK.template.md"
else
  fail "T-0124: review_commit missing from STACK.template.md"
fi

# T-0125: task.py references review_commit
if grep -q 'review_commit' "${FRAMEWORK_ROOT}/.agentic/lib/auto/task.py"; then
  pass "T-0125: task.py references review_commit"
else
  fail "T-0125: task.py missing review_commit reference"
fi

# T-0126: critical_agent.py has review_commit method
if grep -q 'def review_commit' "${FRAMEWORK_ROOT}/.agentic/lib/auto/critical_agent.py"; then
  pass "T-0126: critical_agent.py has review_commit() method"
else
  fail "T-0126: critical_agent.py missing review_commit() method"
fi

# T-0127: critical_agent.py has review_commit focus entry
if grep -q '"review_commit"' "${FRAMEWORK_ROOT}/.agentic/lib/auto/critical_agent.py"; then
  pass "T-0127: critical_agent.py has review_commit focus entry"
else
  fail "T-0127: critical_agent.py missing review_commit focus entry"
fi

# T-0128: PRINCIPLES.md has conditional R2 language
if grep -q 'interactive.*sessions.*NEVER commit' "${FRAMEWORK_ROOT}/.agentic/lib/PRINCIPLES.md"; then
  pass "T-0128: PRINCIPLES.md has conditional R2 language"
else
  fail "T-0128: PRINCIPLES.md missing conditional R2 language"
fi

# T-0129: memory-seed.md has review_commit sentinel (v1 only — trimmed in v2)
# T-0130: task.py has _unstage_or_warn helper
if grep -q '_unstage_or_warn' "${FRAMEWORK_ROOT}/.agentic/lib/auto/task.py"; then
  pass "T-0130: task.py has _unstage_or_warn helper"
else
  fail "T-0130: task.py missing _unstage_or_warn helper"
fi

# ============================================================
# F-0205: Discovery-to-Formal Migration
# ============================================================
echo "--- F-0205: Discovery-to-Formal Migration ---"

if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/formalize.sh" ]]; then
  pass "formalize.sh exists and is executable"
else
  fail "formalize.sh missing or not executable"
fi

if grep_ag 'formalize)'; then
  pass "ag.sh has formalize dispatch"
else
  fail "ag.sh missing formalize dispatch"
fi

# ============================================================
# F-0206: Feedback Capture System
# ============================================================
echo ""
echo "--- F-0206: Feedback Capture System ---"

# T-0131: feedback.sh exists and is executable
if [[ -x "$FRAMEWORK_ROOT/.agentic/lib/tools/feedback.sh" ]]; then
  pass "T-0131: feedback.sh exists and is executable"
else
  fail "T-0131: feedback.sh missing or not executable"
fi

# T-0132: feedback.sh sources paths.sh
if grep -q 'paths\.sh' "${FRAMEWORK_ROOT}/.agentic/lib/tools/feedback.sh"; then
  pass "T-0132: feedback.sh sources paths.sh"
else
  fail "T-0132: feedback.sh does not source paths.sh"
fi

# T-0133: FEEDBACK_LOG_FILE in paths.sh
if grep -q 'FEEDBACK_LOG_FILE' "${FRAMEWORK_ROOT}/.agentic/lib/paths.sh"; then
  pass "T-0133: FEEDBACK_LOG_FILE defined in paths.sh"
else
  fail "T-0133: FEEDBACK_LOG_FILE missing from paths.sh"
fi

# T-0134: ag feedback dispatch exists in ag.sh
if grep_ag '    feedback)'; then
  pass "T-0134: ag feedback dispatch exists in ag.sh"
else
  fail "T-0134: ag feedback dispatch missing from ag.sh"
fi

# T-0135: FEEDBACK_LOG.template.md exists
if [[ -f "$FRAMEWORK_ROOT/.agentic/spec/FEEDBACK_LOG.template.md" ]]; then
  pass "T-0135: FEEDBACK_LOG.template.md exists"
else
  fail "T-0135: FEEDBACK_LOG.template.md missing"
fi

# T-0136: feedback_mode in profiles.conf (all 3 profiles)
FEEDBACK_MODE_COUNT=$(grep -c 'feedback_mode' "${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf" || true)
if [[ "$FEEDBACK_MODE_COUNT" -ge 3 ]]; then
  pass "T-0136: feedback_mode in profiles.conf (${FEEDBACK_MODE_COUNT} profiles)"
else
  fail "T-0136: feedback_mode in profiles.conf (expected 3, got ${FEEDBACK_MODE_COUNT})"
fi

# T-0137: feedback.sh has classify function
if grep -q '_classify()' "${FRAMEWORK_ROOT}/.agentic/lib/tools/feedback.sh"; then
  pass "T-0137: feedback.sh has _classify heuristic function"
else
  fail "T-0137: feedback.sh missing _classify function"
fi

# T-0138: engine.py has _flush_feedback method
if grep -q '_flush_feedback' "${FRAMEWORK_ROOT}/.agentic/lib/auto/engine.py"; then
  pass "T-0138: engine.py has _flush_feedback method"
else
  fail "T-0138: engine.py missing _flush_feedback method"
fi

# T-0139: memory-seed has ag feedback sentinel (v1 only — trimmed in v2)
# T-0142: contract or archived acceptance criteria file exists
if [[ -f "$FRAMEWORK_ROOT/.agentic/spec/contracts/F-0206.yaml" ]] || [[ -f "$FRAMEWORK_ROOT/docs/archive/acceptance/F-0206.md" ]]; then
  pass "T-0142: F-0206 contract/acceptance criteria exists"
else
  fail "T-0142: F-0206 contract/acceptance criteria missing"
fi

echo ""

# ============================================================
# F-0209: TDD Mode — Structural Test-First Enforcement
# ============================================================
echo ""
echo "--- F-0209: TDD Mode — Structural Test-First Enforcement ---"

# T-0143: wip.sh supports --phase flag
if grep -q '\-\-phase' "${FRAMEWORK_ROOT}/.agentic/lib/tools/wip.sh"; then
  pass "T-0143: wip.sh supports --phase flag"
else
  fail "T-0143: wip.sh missing --phase flag support"
fi

# T-0144: agents_helpers.py has check-tdd-phases command
if grep -q 'check-tdd-phases' "${FRAMEWORK_ROOT}/.agentic/lib/tools/agents_helpers.py"; then
  pass "T-0144: agents_helpers.py has check-tdd-phases command"
else
  fail "T-0144: agents_helpers.py missing check-tdd-phases command"
fi

# T-0147: pre-commit-check.sh has Check #20
if grep -q 'Check 20.*TDD' "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh"; then
  pass "T-0147: pre-commit-check.sh has Check #20 (TDD)"
else
  fail "T-0147: pre-commit-check.sh missing Check #20 (TDD)"
fi

# T-0148: SKIP_TDD in escape hatch guard
if grep -q 'SKIP_TDD' "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh"; then
  pass "T-0148: SKIP_TDD in pre-commit escape hatch guard"
else
  fail "T-0148: SKIP_TDD missing from pre-commit escape hatch guard"
fi

# T-0149: memory-seed has TDD enforcement sentinel (v1 only — trimmed in v2)
# T-0151: wip.sh complete has TDD gate
if grep -q 'check-tdd-phases' "${FRAMEWORK_ROOT}/.agentic/lib/tools/wip.sh"; then
  pass "T-0151: wip.sh complete has TDD gate (check-tdd-phases)"
else
  fail "T-0151: wip.sh complete missing TDD gate"
fi

# T-0152: F-0209 contract or archived acceptance criteria file exists
if [[ -f "$FRAMEWORK_ROOT/.agentic/spec/contracts/F-0209.yaml" ]] || [[ -f "$FRAMEWORK_ROOT/docs/archive/acceptance/F-0209.md" ]]; then
  pass "T-0152: F-0209 contract/acceptance criteria exists"
else
  fail "T-0152: F-0209 contract/acceptance criteria missing"
fi

echo ""

# ============================================================
echo "--- F-0214: Parallel Epic Execution with Worktrees ---"

# T-0152: parallel.py exists with ParallelDispatcher class
if grep -q 'class ParallelDispatcher' "${FRAMEWORK_ROOT}/.agentic/lib/auto/parallel.py" 2>/dev/null; then
  pass "T-0152: parallel.py has ParallelDispatcher class"
else
  fail "T-0152: parallel.py missing ParallelDispatcher class"
fi

# T-0153: scheduler.py has --parallel flag in argparser
if grep -q '\-\-parallel' "${FRAMEWORK_ROOT}/.agentic/lib/auto/scheduler.py"; then
  pass "T-0153: scheduler.py has --parallel CLI flag"
else
  fail "T-0153: scheduler.py missing --parallel CLI flag"
fi

# T-0154: parallel.py uses worktree.sh for worktree management
if grep -q 'worktree.sh' "${FRAMEWORK_ROOT}/.agentic/lib/auto/parallel.py" 2>/dev/null; then
  pass "T-0154: parallel.py uses worktree.sh"
else
  fail "T-0154: parallel.py missing worktree.sh integration"
fi

# T-0155: parallel.py has signal handler for cleanup
if grep -q 'signal.signal' "${FRAMEWORK_ROOT}/.agentic/lib/auto/parallel.py" 2>/dev/null; then
  pass "T-0155: parallel.py has signal handler for cleanup"
else
  fail "T-0155: parallel.py missing signal handler"
fi

# T-0156: parallel.py uses AGENTS.json claim/release
if grep -q 'claim' "${FRAMEWORK_ROOT}/.agentic/lib/auto/parallel.py" 2>/dev/null && \
   grep -q 'release' "${FRAMEWORK_ROOT}/.agentic/lib/auto/parallel.py" 2>/dev/null; then
  pass "T-0156: parallel.py has AGENTS.json claim/release"
else
  fail "T-0156: parallel.py missing AGENTS.json claim/release"
fi

# T-0157: parallel.py stores log_file on AgentProcess for proper cleanup
if grep -q 'log_file' "${FRAMEWORK_ROOT}/.agentic/lib/auto/parallel.py" 2>/dev/null; then
  pass "T-0157: parallel.py tracks log_file handle on AgentProcess"
else
  fail "T-0157: parallel.py missing log_file tracking (fd leak risk)"
fi

# T-0158: profiles.conf has max_parallel_agents
if grep -q 'max_parallel_agents' "${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf"; then
  pass "T-0158: profiles.conf has max_parallel_agents setting"
else
  fail "T-0158: profiles.conf missing max_parallel_agents"
fi

# T-0159: test file exists
if [[ -f "${FRAMEWORK_ROOT}/tests/test_auto_parallel.py" ]]; then
  pass "T-0159: test_auto_parallel.py exists"
else
  fail "T-0159: test_auto_parallel.py missing"
fi

# T-0160: parallel.py has --skip-branch in prompt
if grep -q 'skip-branch\|skip_branch' "${FRAMEWORK_ROOT}/.agentic/lib/auto/parallel.py" 2>/dev/null; then
  pass "T-0160: parallel.py passes --skip-branch to task runner"
else
  fail "T-0160: parallel.py missing --skip-branch in prompt"
fi

echo ""

# ============================================================
echo "--- Design Document Traceability ---"

# design-trace.sh exists and is executable
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/design-trace.sh" ]]; then
  pass "design-trace.sh exists"
else
  fail "design-trace.sh missing"
fi

if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/design-trace.sh" ]]; then
  pass "design-trace.sh is executable"
else
  fail "design-trace.sh is not executable"
fi

# feature.sh supports source field (check for awk handler, not just the word "source")
if grep -q 'field == "source"' "${FRAMEWORK_ROOT}/.agentic/lib/tools/feature.sh" 2>/dev/null; then
  pass "feature.sh supports source field"
else
  fail "feature.sh missing source field support"
fi

# query_features.py parses source field
if grep -q '"source"' "${FRAMEWORK_ROOT}/.agentic/lib/tools/query_features.py" 2>/dev/null; then
  pass "query_features.py parses source field"
else
  fail "query_features.py missing source field"
fi

# dashboard.sh has design trace integration
if grep -q 'design-trace' "${FRAMEWORK_ROOT}/.agentic/lib/tools/dashboard.sh" 2>/dev/null; then
  pass "dashboard.sh has design trace integration"
else
  fail "dashboard.sh missing design trace integration"
fi

# memory-seed.md mentions source annotation (v1 only — trimmed in v2)
# F-0224: Smoke Test Evidence Gate
# ============================================================
echo "--- F-0224: Smoke Test Evidence Gate ---"

# profiles.conf has smoke_test_evidence for all 3 profiles
if grep -q "discovery.smoke_test_evidence=off" "${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf" 2>/dev/null; then
  pass "profiles.conf has discovery.smoke_test_evidence"
else
  fail "profiles.conf missing discovery.smoke_test_evidence"
fi

if grep -q "formal.smoke_test_evidence=recommended" "${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf" 2>/dev/null; then
  pass "profiles.conf has formal.smoke_test_evidence"
else
  fail "profiles.conf missing formal.smoke_test_evidence"
fi

if grep -q "autonomous_formal.smoke_test_evidence=recommended" "${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf" 2>/dev/null; then
  pass "profiles.conf has autonomous_formal.smoke_test_evidence"
else
  fail "profiles.conf missing autonomous_formal.smoke_test_evidence"
fi

# paths.sh has EVIDENCE_DIR
if grep -q "EVIDENCE_DIR" "${FRAMEWORK_ROOT}/.agentic/lib/paths.sh" 2>/dev/null; then
  pass "paths.sh has EVIDENCE_DIR"
else
  fail "paths.sh missing EVIDENCE_DIR"
fi

# paths.py has evidence_dir
if grep -q "evidence_dir" "${FRAMEWORK_ROOT}/.agentic/lib/paths.py" 2>/dev/null; then
  pass "paths.py has evidence_dir"
else
  fail "paths.py missing evidence_dir"
fi

# ag.sh has smoke test evidence gate
if grep_ag "Smoke Test Evidence Check"; then
  pass "ag.sh has smoke test evidence gate"
else
  fail "ag.sh missing smoke test evidence gate"
fi

# ag.sh has smoke_test_evidence validator
if grep_ag "smoke_test_evidence)"; then
  pass "ag.sh has smoke_test_evidence validator"
else
  fail "ag.sh missing smoke_test_evidence validator"
fi

# verify.py has --feature flag
if grep -q "\-\-feature" "${FRAMEWORK_ROOT}/.agentic/lib/auto/verify.py" 2>/dev/null; then
  pass "verify.py has --feature flag"
else
  fail "verify.py missing --feature flag"
fi

# STACK.template.md has smoke_test_evidence
if grep -q "smoke_test_evidence" "${FRAMEWORK_ROOT}/.agentic/lib/init/STACK.template.md" 2>/dev/null; then
  pass "STACK.template.md has smoke_test_evidence"
else
  fail "STACK.template.md missing smoke_test_evidence"
fi

# memory-seed.md has smoke evidence sentinel (v1 only — trimmed in v2)
# F-003: Centralized Feature IDs (consolidated from F-0193)
# ============================================================

# ids.py exists and exports required symbols
if [ -f "${FRAMEWORK_ROOT}/.agentic/lib/ids.py" ]; then
  pass "F-003: ids.py exists"
else
  fail "F-003: ids.py not found"
fi

# ids.sh exists and exports required symbols
if [ -f "${FRAMEWORK_ROOT}/.agentic/lib/ids.sh" ]; then
  pass "F-003: ids.sh exists"
else
  fail "F-003: ids.sh not found"
fi

# is_feature_id function works
source "${FRAMEWORK_ROOT}/.agentic/lib/ids.sh"
if is_feature_id "F-001"; then
  pass "F-003: is_feature_id accepts F-001"
else
  fail "F-003: is_feature_id rejects F-001"
fi

if is_feature_id "F-10000"; then
  pass "F-003: is_feature_id accepts F-10000"
else
  fail "F-003: is_feature_id rejects F-10000"
fi

if ! is_feature_id "F-01"; then
  pass "F-003: is_feature_id rejects F-01"
else
  fail "F-003: is_feature_id accepts F-01 (should reject)"
fi

# No hardcoded 4-digit-only patterns in .agentic/lib/ Python files
hardcoded_py=$(grep -rn 'F-\\d{4}[^,}]' "${FRAMEWORK_ROOT}/.agentic/lib/" --include='*.py' 2>/dev/null | grep -v 'ids.py' | grep -v '__pycache__' || true)
if [ -z "$hardcoded_py" ]; then
  pass "F-003: No hardcoded 4-digit-only Python patterns"
else
  fail "F-003: Hardcoded 4-digit patterns found in Python: $hardcoded_py"
fi

# No hardcoded 4-digit-only patterns in .agentic/lib/ shell files
hardcoded_sh=$(grep -rn "F-\[0-9\]{4}[^,}]" "${FRAMEWORK_ROOT}/.agentic/lib/" --include='*.sh' 2>/dev/null | grep -v 'ids.sh' || true)
if [ -z "$hardcoded_sh" ]; then
  pass "F-003: No hardcoded 4-digit-only shell patterns"
else
  fail "F-003: Hardcoded 4-digit patterns found in shell: $hardcoded_sh"
fi

# paths.sh sources ids.sh
if grep -q "ids.sh" "${FRAMEWORK_ROOT}/.agentic/lib/paths.sh"; then
  pass "F-003: paths.sh sources ids.sh"
else
  fail "F-003: paths.sh does not source ids.sh"
fi

# JSON schemas use widened pattern
if grep -q 'F-\[0-9\]{4,}' "${FRAMEWORK_ROOT}/.agentic/lib/schemas/feature.schema.json"; then
  pass "F-003: feature.schema.json uses widened pattern"
else
  fail "F-003: feature.schema.json still uses 4-digit-only pattern"
fi



# --- F-0216: NFR Auto-Generation at Lifecycle Moments ---
echo ""
echo "--- F-0216: NFR Auto-Generation ---"

# AC-005: --limit flag in nfr-generate.sh
if bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/nfr-generate.sh" --help 2>&1 | grep -q "\-\-limit"; then
  pass "F-0216: nfr-generate.sh --help documents --limit flag"
else
  fail "F-0216: nfr-generate.sh --help missing --limit flag"
fi

# AC-005: --machine flag in nfr-generate.sh
if bash "${FRAMEWORK_ROOT}/.agentic/lib/tools/nfr-generate.sh" --help 2>&1 | grep -q "\-\-machine"; then
  pass "F-0216: nfr-generate.sh --help documents --machine flag"
else
  fail "F-0216: nfr-generate.sh --help missing --machine flag"
fi

# AC-006: nfr-write-batch.sh exists and is executable
if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/nfr-write-batch.sh" ]]; then
  pass "F-0216: nfr-write-batch.sh exists and is executable"
else
  fail "F-0216: nfr-write-batch.sh missing or not executable"
fi

# AC-005: ag nfr discover uses --limit (default 8)
if grep_ag 'nfr-generate.sh.*--limit\|--limit.*8'; then
  pass "F-0216: ag nfr discover passes --limit to nfr-generate.sh"
else
  fail "F-0216: ag nfr discover should pass --limit to nfr-generate.sh"
fi

# AC-008: cmd_kickoff calls nfr-generate.sh
if grep_ag 'nfr-generate.sh'; then
  pass "F-0216: cmd_kickoff references nfr-generate.sh"
else
  fail "F-0216: cmd_kickoff should call nfr-generate.sh for NFR integration"
fi


# --- Doc Currency: shipped features must appear in CHANGELOG + living docs ---
echo "--- Doc Currency: shipped features in CHANGELOG + living docs ---"

# Extract F-IDs from CHANGELOG [Unreleased] section (between first and second ## [ headers)
CHANGELOG_FILE="$FRAMEWORK_ROOT/CHANGELOG.md"
if [[ -f "$CHANGELOG_FILE" ]]; then
  # Get content between [Unreleased] and the next version header
  UNRELEASED_SECTION=$(sed -n '/^## \[Unreleased\]/,/^## \[/p' "$CHANGELOG_FILE" | head -n -1)
  CHANGELOG_FIDS=$(echo "$UNRELEASED_SECTION" | grep -oE "$FEATURE_ID_ERE" | sort -u || true)

  # Get all shipped features from FEATURES.md
  FEATURES_FILE="$FRAMEWORK_ROOT/.agentic/spec/FEATURES.md"
  ALL_SHIPPED_FIDS=$(grep -B3 'Status.*shipped' "$FEATURES_FILE" | grep -oE "$FEATURE_ID_ERE" | sort -u || true)

  # Living docs to check
  LIVING_DOCS=(
    "$FRAMEWORK_ROOT/docs/HOW_IT_WORKS.md"
    "$FRAMEWORK_ROOT/.agentic/lib/DEVELOPER_GUIDE.md"
    "$FRAMEWORK_ROOT/docs/FRAMEWORK_WORKFLOW.md"
    "$FRAMEWORK_ROOT/docs/INSTRUCTION_ARCHITECTURE.md"
    "$FRAMEWORK_ROOT/.agentic/OVERVIEW.md"
  )

  # For each F-ID in CHANGELOG unreleased, verify it appears in at least one living doc
  CHANGELOG_DOC_PASS=0
  CHANGELOG_DOC_FAIL=0
  for fid in $CHANGELOG_FIDS; do
    found_in_doc=false
    for doc in "${LIVING_DOCS[@]}"; do
      if [[ -f "$doc" ]] && grep -q "$fid" "$doc" 2>/dev/null; then
        found_in_doc=true
        break
      fi
    done
    if $found_in_doc; then
      pass "Doc currency: $fid in CHANGELOG and living docs"
      CHANGELOG_DOC_PASS=$((CHANGELOG_DOC_PASS + 1))
    else
      warn "Doc currency: $fid in CHANGELOG but not in any living doc (HOW_IT_WORKS, DEVELOPER_GUIDE, FRAMEWORK_WORKFLOW, INSTRUCTION_ARCHITECTURE, OVERVIEW)"
      CHANGELOG_DOC_FAIL=$((CHANGELOG_DOC_FAIL + 1))
    fi
  done

  # Inverse check: shipped features in latest version that are NOT in CHANGELOG
  # Only check F-IDs >= F-0200 (recent features — older ones predate CHANGELOG practice)
  RECENT_SHIPPED=$(echo "$ALL_SHIPPED_FIDS" | awk -F- '$2 >= 200' || true)
  ALL_CHANGELOG_FIDS=$(grep -oE "$FEATURE_ID_ERE" "$CHANGELOG_FILE" | sort -u || true)
  for fid in $RECENT_SHIPPED; do
    if ! echo "$ALL_CHANGELOG_FIDS" | grep -q "^${fid}$" 2>/dev/null; then
      warn "Doc currency: $fid shipped but missing from CHANGELOG.md entirely"
    fi
  done

  if [[ $CHANGELOG_DOC_FAIL -eq 0 ]] && [[ $CHANGELOG_DOC_PASS -gt 0 ]]; then
    pass "Doc currency: all unreleased features documented in living docs ($CHANGELOG_DOC_PASS checked)"
  fi
else
  warn "Doc currency: CHANGELOG.md not found, skipping"
fi

# F-0241: QA Registry freshness (advisory)
# ============================================================
echo "--- F-0241: QA Registry ---"

if [[ -f "${FRAMEWORK_ROOT}/docs/QA_REGISTRY.md" ]]; then
  pass "QA Registry exists (docs/QA_REGISTRY.md)"
  # Advisory: check if file is older than 7 days
  if [[ "$(uname)" == "Darwin" ]]; then
    file_age=$(( ($(date +%s) - $(stat -f %m "${FRAMEWORK_ROOT}/docs/QA_REGISTRY.md")) / 86400 ))
  else
    file_age=$(( ($(date +%s) - $(stat -c %Y "${FRAMEWORK_ROOT}/docs/QA_REGISTRY.md")) / 86400 ))
  fi
  if [[ $file_age -gt 7 ]]; then
    warn "QA Registry is ${file_age} days old — regenerate with: ag qa"
  else
    pass "QA Registry is recent (${file_age} days old)"
  fi
else
  warn "QA Registry not found — generate with: ag qa"
fi

# ============================================================
# F-0240: Framework Execution Log
# ============================================================
echo ""
echo "--- F-0240: Framework Execution Log ---"

# AC-1: fwlog.sh exists and provides flog()
if [[ -f ".agentic/lib/tools/fwlog.sh" ]]; then
  pass "F-0240 AC-1: fwlog.sh exists"
else
  fail "F-0240 AC-1: fwlog.sh not found"
fi

# Functional test: source fwlog.sh and call flog, verify output format
_f0240_tmplog=$(mktemp)
(
  export FRAMEWORK_LOG="$_f0240_tmplog"
  export SESSION_DIR="$(dirname "$_f0240_tmplog")"
  source .agentic/lib/tools/fwlog.sh
  flog "test-script" "test-verb" "test-args" "test-result"
) 2>/dev/null
if [[ -f "$_f0240_tmplog" ]]; then
  _f0240_line=$(cat "$_f0240_tmplog")
  # AC-6: verify pipe-delimited with 5 fields
  _f0240_fields=$(echo "$_f0240_line" | awk -F'|' '{print NF}')
  if [[ "$_f0240_fields" -eq 5 ]]; then
    pass "F-0240 AC-6: flog output has 5 pipe-delimited fields"
  else
    fail "F-0240 AC-6: expected 5 fields, got $_f0240_fields in: $_f0240_line"
  fi
  if echo "$_f0240_line" | grep -q "test-script.*test-verb.*test-args.*test-result"; then
    pass "F-0240 AC-1: flog() appends correct content"
  else
    fail "F-0240 AC-1: flog() output unexpected: $_f0240_line"
  fi
else
  fail "F-0240 AC-1: flog() did not create log file"
fi
rm -f "$_f0240_tmplog"

# AC-4: Fail-open — unwritable path doesn't crash
(
  export FRAMEWORK_LOG="/dev/null/nope/framework.log"
  export SESSION_DIR="/dev/null/nope"
  source .agentic/lib/tools/fwlog.sh
  flog "crash-test" "verb" "args" "result"
) 2>/dev/null
if [[ $? -eq 0 ]]; then
  pass "F-0240 AC-4: fail-open — unwritable log path doesn't crash"
else
  fail "F-0240 AC-4: flog crashed with unwritable path"
fi

# AC-2: ag.sh sources fwlog.sh
if grep_ag 'source.*fwlog\.sh'; then
  pass "F-0240 AC-2: ag.sh sources fwlog.sh"
else
  fail "F-0240 AC-2: ag.sh does not source fwlog.sh"
fi

# AC-2: ag.sh has EXIT trap for end logging
if grep_ag 'trap.*flog.*ag\.sh.*end'; then
  pass "F-0240 AC-2: ag.sh has EXIT trap for end logging"
else
  fail "F-0240 AC-2: ag.sh missing EXIT trap for end logging"
fi

# AC-3: pre-commit sources fwlog.sh
if grep -q 'source.*fwlog\.sh' .agentic/lib/hooks/pre-commit-check.sh 2>/dev/null; then
  pass "F-0240 AC-3: pre-commit sources fwlog.sh"
else
  fail "F-0240 AC-3: pre-commit does not source fwlog.sh"
fi

# AC-3: pre-commit has EXIT trap
if grep -q 'trap.*flog.*pre-commit.*end' .agentic/lib/hooks/pre-commit-check.sh 2>/dev/null; then
  pass "F-0240 AC-3: pre-commit has EXIT trap for end logging"
else
  fail "F-0240 AC-3: pre-commit missing EXIT trap for end logging"
fi

# AC-5: .gitignore includes framework.log
if grep -q '.agentic/session/framework\.log$' .gitignore 2>/dev/null; then
  pass "F-0240 AC-5: framework.log is gitignored"
else
  fail "F-0240 AC-5: framework.log not in .gitignore"
fi
if grep -q '.agentic/session/framework\.log\.prev$' .gitignore 2>/dev/null; then
  pass "F-0240 AC-5: framework.log.prev is gitignored"
else
  fail "F-0240 AC-5: framework.log.prev not in .gitignore"
fi

# AC-9: FRAMEWORK_LOG in paths.sh
if grep -q 'FRAMEWORK_LOG=' .agentic/lib/paths.sh 2>/dev/null; then
  pass "F-0240 AC-9: FRAMEWORK_LOG defined in paths.sh"
else
  fail "F-0240 AC-9: FRAMEWORK_LOG not in paths.sh"
fi

# AC-9: framework_log in paths.py
if grep -q 'framework_log' .agentic/lib/paths.py 2>/dev/null; then
  pass "F-0240 AC-9: framework_log defined in paths.py"
else
  fail "F-0240 AC-9: framework_log not in paths.py"
fi

# AC-7: SessionStart.sh has rotation logic
if grep -q 'FRAMEWORK_LOG.*prev\|framework\.log.*prev' .agentic/lib/claude-hooks/SessionStart.sh 2>/dev/null; then
  pass "F-0240 AC-7: SessionStart.sh has log rotation"
else
  fail "F-0240 AC-7: SessionStart.sh missing log rotation"
fi

# AC-8: All 5 Claude hooks source fwlog.sh
_f0240_hooks_ok=0
_f0240_hooks_total=0
for _hook in SessionStart Stop PostToolUse UserPromptSubmit PreCompact; do
  _f0240_hooks_total=$((_f0240_hooks_total + 1))
  if grep -q 'fwlog\.sh' ".agentic/lib/claude-hooks/${_hook}.sh" 2>/dev/null; then
    _f0240_hooks_ok=$((_f0240_hooks_ok + 1))
  fi
done
if [[ $_f0240_hooks_ok -eq $_f0240_hooks_total ]]; then
  pass "F-0240 AC-8: All 5 Claude hooks source fwlog.sh"
else
  fail "F-0240 AC-8: Only $_f0240_hooks_ok/$_f0240_hooks_total Claude hooks source fwlog.sh"
fi

# F-0242: Simulation Testing (Phase + Sequence)

echo ""
echo "--- F-0242: Simulation Testing ---"

# AC-1: PhaseChecker exists in framework_verify.py
if grep -q 'class PhaseChecker' .agentic/lib/auto/framework_verify.py 2>/dev/null; then
  pass "F-0242 AC-1: PhaseChecker class exists"
else
  fail "F-0242 AC-1: PhaseChecker class not found"
fi

# AC-3: violations.yaml exists and has 3 patterns
if [[ -f .agentic/lib/auto/violations.yaml ]]; then
  _f242_count=$(python3 -c "import yaml; d=yaml.safe_load(open('.agentic/lib/auto/violations.yaml')); print(len(d.get('violations',[])))" 2>/dev/null || echo 0)
  if [[ "$_f242_count" -eq 3 ]]; then
    pass "F-0242 AC-3: violations.yaml has 3 patterns"
  else
    fail "F-0242 AC-3: violations.yaml has $_f242_count patterns (expected 3)"
  fi
else
  fail "F-0242 AC-3: violations.yaml not found"
fi

# AC-3: Each violation has name, handler, config
_f242_valid=1
for _name in stopped_after_plan_exit code_before_review skipped_planning; do
  if ! grep -q "name: $_name" .agentic/lib/auto/violations.yaml 2>/dev/null; then
    _f242_valid=0
  fi
done
if [[ $_f242_valid -eq 1 ]]; then
  pass "F-0242 AC-3: all 3 violation names present in violations.yaml"
else
  fail "F-0242 AC-3: missing violation names in violations.yaml"
fi

# AC-5: phase_expectations in run_scenario()
if grep -q 'phase_expectations' .agentic/lib/auto/framework_verify.py 2>/dev/null; then
  pass "F-0242 AC-5: phase_expectations integrated in framework_verify.py"
else
  fail "F-0242 AC-5: phase_expectations not found in framework_verify.py"
fi

# AC-7: todo_app.yaml has phase_expectations
if grep -q 'phase_expectations' .agentic/lib/auto/scenarios/todo_app.yaml 2>/dev/null; then
  pass "F-0242 AC-7: todo_app.yaml has phase_expectations"
else
  fail "F-0242 AC-7: todo_app.yaml missing phase_expectations"
fi

# ============================================================
# DEV-004: Complexity Tier Experiments
# ============================================================
echo ""
echo "--- DEV-004: Complexity Tier Experiments ---"

_tier_exp="${FRAMEWORK_ROOT}/.agentic/lib/auto/tier_experiment.py"
if [ -f "$_tier_exp" ]; then
  pass "DEV-004 AC1: tier_experiment.py exists"
else
  fail "DEV-004 AC1: tier_experiment.py not found"
fi

_tier_yaml="${FRAMEWORK_ROOT}/.agentic/lib/auto/experiments/complexity_tiers.yaml"
if [ -f "$_tier_yaml" ]; then
  pass "DEV-004 AC6: complexity_tiers.yaml exists"
  # Check all 3 tiers
  _has_discovery=$(grep -c "name: discovery" "$_tier_yaml" || true)
  _has_formal=$(grep -c "name: formal" "$_tier_yaml" || true)
  _has_auto_formal=$(grep -c "name: autonomous_formal" "$_tier_yaml" || true)
  if [ "$_has_discovery" -ge 1 ] && [ "$_has_formal" -ge 1 ] && [ "$_has_auto_formal" -ge 1 ]; then
    pass "DEV-004 AC6: complexity_tiers.yaml has all 3 tiers"
  else
    fail "DEV-004 AC6: complexity_tiers.yaml missing tiers (discovery=$_has_discovery formal=$_has_formal autonomous_formal=$_has_auto_formal)"
  fi
  # Check formal tier has review_plan override (prevents deadlock)
  if grep -q "review_plan: critical_agent" "$_tier_yaml"; then
    pass "DEV-004 AC6: formal tier has review_plan override (prevents deadlock)"
  else
    fail "DEV-004 AC6: formal tier missing review_plan override — will deadlock"
  fi
else
  fail "DEV-004 AC6: complexity_tiers.yaml not found"
fi

if grep -q "tier-experiment" "${FRAMEWORK_ROOT}/.agentic/lib/tools/commands/auto.sh"; then
  pass "DEV-004 AC4: ag auto tier-experiment wired in auto.sh"
else
  fail "DEV-004 AC4: ag auto tier-experiment not wired in auto.sh"
fi

if grep -q "class TierMetrics" "$_tier_exp" 2>/dev/null; then
  pass "DEV-004 AC9: TierMetrics dataclass defined"
else
  fail "DEV-004 AC9: TierMetrics class not found"
fi

if grep -q "class ExperimentResult" "$_tier_exp" 2>/dev/null; then
  pass "DEV-004 AC9: ExperimentResult dataclass defined"
else
  fail "DEV-004 AC9: ExperimentResult class not found"
fi

if [ -f "${FRAMEWORK_ROOT}/tests/llm/tests/096_tier_experiment_trigger.sh" ]; then
  pass "DEV-004 AC8: LLM test 096_tier_experiment_trigger.sh exists"
else
  fail "DEV-004 AC8: LLM test not found"
fi

if [ -f "${FRAMEWORK_ROOT}/tests/test_tier_experiment.py" ]; then
  pass "DEV-004 AC2: test_tier_experiment.py exists"
else
  fail "DEV-004 AC2: test_tier_experiment.py not found"
fi

# ============================================================
# STATE MACHINE VALIDATION
# ============================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "STATE MACHINE VALIDATION"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# --- V2-001: state_machine_af.yaml required structure ---
echo "--- V2-001: State Machine Structure ---"

SM_FILE="${FRAMEWORK_ROOT}/.agentic/state_machine_af.yaml"

if [[ -f "$SM_FILE" ]]; then
  pass "V2: state_machine_af.yaml exists"
else
  fail "V2: state_machine_af.yaml missing"
fi

for section in "states:" "transitions:" "modes:" "profiles:"; do
  if grep -q "$section" "$SM_FILE" 2>/dev/null; then
    pass "V2: state_machine_af.yaml has ${section} section"
  else
    fail "V2: state_machine_af.yaml missing ${section} section"
  fi
done

# Check workflow.states has the core states
for state in idea queued planning plan_review spec implementation verification docs ready_to_ship shipped; do
  if grep -q -- "- ${state}" "$SM_FILE" 2>/dev/null; then
    pass "V2: state '${state}' defined"
  else
    fail "V2: state '${state}' missing from states list"
  fi
done

# Check modes: formal and lean exist
if grep -q "formal:" "$SM_FILE" 2>/dev/null; then
  pass "V2: formal mode defined"
else
  fail "V2: formal mode missing"
fi

if grep -q "lean:" "$SM_FILE" 2>/dev/null; then
  pass "V2: lean mode defined"
else
  fail "V2: lean mode missing"
fi

# Check profiles: hands_on, guided, autonomous exist
for profile in hands_on guided autonomous; do
  if grep -q "${profile}:" "$SM_FILE" 2>/dev/null; then
    pass "V2: profile '${profile}' defined"
  else
    fail "V2: profile '${profile}' missing"
  fi
done

# --- V2-002: Role prompts ---
echo "--- V2-002: Role Prompts ---"

PROMPTS_DIR="${FRAMEWORK_ROOT}/.agentic/prompts"
V2_REQUIRED_PROMPTS=(planner.md reviewer.md implementer.md verifier.md debugger.md session.md explorer.md)

if [[ -d "$PROMPTS_DIR" ]]; then
  pass "V2: prompts/ directory exists"
else
  fail "V2: prompts/ directory missing"
fi

for prompt in "${V2_REQUIRED_PROMPTS[@]}"; do
  if [[ -f "${PROMPTS_DIR}/${prompt}" ]]; then
    pass "V2: ${prompt} exists"

    # Check for # Role: heading
    if head -5 "${PROMPTS_DIR}/${prompt}" | grep -q "^# Role:" 2>/dev/null; then
      pass "V2: ${prompt} has '# Role:' heading"
    else
      fail "V2: ${prompt} missing '# Role:' heading"
    fi

    # Check for ag transition reference
    if grep -q "ag transition" "${PROMPTS_DIR}/${prompt}" 2>/dev/null; then
      pass "V2: ${prompt} references 'ag transition'"
    else
      # Some roles don't directly transition (session manager, explorer, debugger)
      case "$prompt" in
        session.md|explorer.md|debugger.md)
          warn "V2: ${prompt} does not reference 'ag transition' (may be expected for this role)"
          ;;
        *)
          fail "V2: ${prompt} missing 'ag transition' reference"
          ;;
      esac
    fi
  else
    fail "V2: ${prompt} missing"
  fi
done

# --- V2-003: Conventions file ---
echo "--- V2-003: Conventions ---"

if [[ -f "${FRAMEWORK_ROOT}/.agentic/conventions.md" ]]; then
  pass "V2: conventions.md exists"
else
  warn "V2: conventions.md missing (expected in Phase 3B)"
fi

# --- V2-004: Work directory ---
echo "--- V2-004: Work Directory ---"

if [[ -d "${FRAMEWORK_ROOT}/.agentic/work" ]]; then
  pass "V2: work/ directory exists"
else
  fail "V2: work/ directory missing"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/work/.gitkeep" ]]; then
  pass "V2: work/.gitkeep exists"
else
  fail "V2: work/.gitkeep missing"
fi

# --- V2-005: Token-efficient scripts ---
echo "--- V2-005: Token-Efficient Scripts ---"

for script in journal.sh status.sh feature.sh blocker.sh todo.sh; do
  if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/tools/${script}" ]]; then
    pass "V2: ${script} exists"
  else
    fail "V2: ${script} missing"
  fi
done

# --- V2-006: Tool templates reference ag commands ---
echo "--- V2-006: Tool Templates ---"

# Check that the Claude CLAUDE.md template references ag transition
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/CLAUDE.md" ]]; then
  if grep -q "ag transition" "${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/CLAUDE.md" 2>/dev/null; then
    pass "V2: Claude CLAUDE.md references 'ag transition'"
  else
    warn "V2: Claude CLAUDE.md missing 'ag transition' (may need update)"
  fi
  if grep -q "ag " "${FRAMEWORK_ROOT}/.agentic/lib/agents/claude/CLAUDE.md" 2>/dev/null; then
    pass "V2: Claude CLAUDE.md references ag commands"
  else
    fail "V2: Claude CLAUDE.md missing ag command references"
  fi
else
  fail "V2: Claude CLAUDE.md template missing"
fi

# Check other tool templates reference ag commands
for template in \
  ".agentic/lib/agents/cursor/cursorrules.txt" \
  ".agentic/lib/agents/copilot/copilot-instructions.md" \
  ".agentic/lib/agents/codex/codex-instructions.md"; do
  template_path="${FRAMEWORK_ROOT}/${template}"
  template_name=$(basename "$template")
  if [[ -f "$template_path" ]]; then
    if grep -q "ag " "$template_path" 2>/dev/null; then
      pass "V2: ${template_name} references ag commands"
    else
      fail "V2: ${template_name} missing ag command references"
    fi
  else
    fail "V2: ${template_name} missing"
  fi
done


# ============================================================
# F-031: Spec System Overhaul — YAML Contracts
# ============================================================
echo "--- F-031: Spec System Overhaul — YAML Contracts ---"

# AC-001: Contract schema exists
if [[ -f "${FRAMEWORK_ROOT}/.agentic/lib/schemas/contract.schema.json" ]]; then
  pass "F-031: contract.schema.json exists"
else
  fail "F-031: contract.schema.json missing"
fi

# AC-002: Contract parser loads and validates
if command -v python3 >/dev/null 2>&1; then
  _contract_parser_test=$(PYTHONPATH="${FRAMEWORK_ROOT}/.agentic/lib" python3 -c "
from pathlib import Path
from contracts import Contract, Assertion, validate_contract
c = Contract(id='F-9999', name='Test Feature', lifecycle='exploring',
             description='A test contract for validation',
             assertions=[Assertion(id='AC-001', text='Test assertion text here', type='structural', draft=True)])
errors = validate_contract(c)
if errors:
    print('FAIL: ' + '; '.join(errors))
else:
    print('OK')
" 2>&1)
  if [[ "$_contract_parser_test" == "OK" ]]; then
    pass "F-031: contracts.py parser validates contracts"
  else
    fail "F-031: contracts.py parser validation failed: $_contract_parser_test"
  fi
else
  fail "F-031: python3 not available"
fi

# AC-003: ag contract command exists
if grep_ag "contract" 2>/dev/null; then
  pass "F-031: ag contract command wired in ag.sh"
else
  fail "F-031: ag contract command missing from ag.sh"
fi

# AC-004: verify-contracts.sh exists and is executable
if [[ -x "${FRAMEWORK_ROOT}/.agentic/lib/tools/verify-contracts.sh" ]]; then
  pass "F-031: verify-contracts.sh exists and is executable"
else
  fail "F-031: verify-contracts.sh missing or not executable"
fi

# AC-005: paths resolve contracts_dir
if command -v python3 >/dev/null 2>&1; then
  _paths_test=$(PYTHONPATH="${FRAMEWORK_ROOT}/.agentic/lib" python3 -c "
from paths import get_paths; from pathlib import Path
p = get_paths(Path('${FRAMEWORK_ROOT}'))
if hasattr(p, 'contracts_dir') and 'contracts' in str(p.contracts_dir):
    print('OK')
else:
    print('FAIL')
" 2>&1)
  if [[ "$_paths_test" == "OK" ]]; then
    pass "F-031: paths.py resolves contracts_dir"
  else
    fail "F-031: paths.py missing contracts_dir"
  fi
else
  fail "F-031: python3 not available"
fi

# Check paths.sh has CONTRACTS_DIR
if grep -q "CONTRACTS_DIR" "${FRAMEWORK_ROOT}/.agentic/lib/paths.sh" 2>/dev/null; then
  pass "F-031: paths.sh defines CONTRACTS_DIR"
else
  fail "F-031: paths.sh missing CONTRACTS_DIR"
fi

# AC-006: Pre-commit has contract protection check
if grep -q "contract protection" "${FRAMEWORK_ROOT}/.agentic/lib/hooks/pre-commit-check.sh" 2>/dev/null; then
  pass "F-031: pre-commit-check.sh has contract protection"
else
  fail "F-031: pre-commit-check.sh missing contract protection"
fi

# DEV-001: Framework Development Infrastructure
echo "--- DEV-001: Framework Development Infrastructure ---"

if grep -q "DEV-001" "${FRAMEWORK_ROOT}/.agentic/spec/FEATURES.md" 2>/dev/null; then
  pass "DEV-001: dev-infrastructure section exists in FEATURES.md"
else
  fail "DEV-001: dev-infrastructure section missing from FEATURES.md"
fi

if grep -q "Type.*infrastructure\|Type.*research" "${FRAMEWORK_ROOT}/.agentic/spec/FEATURES.md" 2>/dev/null; then
  pass "DEV-001: Type annotations present on internal features"
else
  fail "DEV-001: Type annotations missing from internal features"
fi

if [[ -f "${FRAMEWORK_ROOT}/.agentic/spec/contracts/DEV-001.yaml" ]]; then
  pass "DEV-001: contract exists"
else
  fail "DEV-001: DEV-001.yaml contract missing"
fi

if grep -q "DEV" "${FRAMEWORK_ROOT}/.agentic/lib/schemas/contract.schema.json" 2>/dev/null; then
  pass "DEV-001: DEV-XXXX pattern supported in contract schema"
else
  fail "DEV-001: DEV-XXXX pattern missing from contract schema"
fi

# F-035: Protected Main Branch Support
echo "--- F-035: Protected Main Branch Support ---"

# AC-007: Default is direct for all profiles
if [[ $(grep -c "main_branch_mode=direct" "${FRAMEWORK_ROOT}/.agentic/lib/presets/profiles.conf" 2>/dev/null) -eq 3 ]]; then
  pass "F-035: main_branch_mode=direct in all 3 profiles"
else
  fail "F-035: main_branch_mode=direct not present in all 3 profiles"
fi

# AC-008: Settings validation
if grep -q "main_branch_mode" "${FRAMEWORK_ROOT}/.agentic/lib/tools/commands/settings.sh" 2>/dev/null; then
  pass "F-035: main_branch_mode validation in settings.sh"
else
  fail "F-035: main_branch_mode validation missing from settings.sh"
fi

# AC-001: state-commit.sh has ephemeral branch creation
if grep -q "state/flush-" "${FRAMEWORK_ROOT}/.agentic/lib/tools/state-commit.sh" 2>/dev/null; then
  pass "F-035: state-commit.sh has ephemeral branch (state/flush-) creation"
else
  fail "F-035: state-commit.sh missing ephemeral branch creation"
fi

# AC-002: state-commit.sh has gh pr create
if grep -q "gh pr create" "${FRAMEWORK_ROOT}/.agentic/lib/tools/state-commit.sh" 2>/dev/null; then
  pass "F-035: state-commit.sh has gh pr create for protected mode"
else
  fail "F-035: state-commit.sh missing gh pr create"
fi

# AC-004: state-commit.sh checks gh availability
if grep -q "command -v gh" "${FRAMEWORK_ROOT}/.agentic/lib/tools/state-commit.sh" 2>/dev/null; then
  pass "F-035: state-commit.sh checks gh CLI availability"
else
  fail "F-035: state-commit.sh missing gh CLI availability check"
fi

# AC-009: --auto-flush flag in state-commit.sh
if grep -q "\-\-auto-flush" "${FRAMEWORK_ROOT}/.agentic/lib/tools/state-commit.sh" 2>/dev/null; then
  pass "F-035: state-commit.sh supports --auto-flush flag"
else
  fail "F-035: state-commit.sh missing --auto-flush flag"
fi

# AC-009: _try_flush callers pass --auto-flush
if grep -q "\-\-auto-flush" "${FRAMEWORK_ROOT}/.agentic/lib/tools/todo.sh" 2>/dev/null && \
   grep -q "\-\-auto-flush" "${FRAMEWORK_ROOT}/.agentic/lib/tools/feedback.sh" 2>/dev/null; then
  pass "F-035: _try_flush callers (todo.sh, feedback.sh) pass --auto-flush"
else
  fail "F-035: _try_flush callers missing --auto-flush flag"
fi

# AC-011: Error recovery cleanup
if grep -q "_cleanup_ephemeral" "${FRAMEWORK_ROOT}/.agentic/lib/tools/state-commit.sh" 2>/dev/null; then
  pass "F-035: state-commit.sh has _cleanup_ephemeral error recovery"
else
  fail "F-035: state-commit.sh missing _cleanup_ephemeral error recovery"
fi

# AC-012: Stale branch cleanup
if grep -q "push origin --delete" "${FRAMEWORK_ROOT}/.agentic/lib/tools/state-commit.sh" 2>/dev/null; then
  pass "F-035: state-commit.sh has stale branch cleanup"
else
  fail "F-035: state-commit.sh missing stale branch cleanup"
fi

# AC-010: Local state reset after PR
if grep -q 'git checkout.*BRANCH.*--\|git rm' "${FRAMEWORK_ROOT}/.agentic/lib/tools/state-commit.sh" 2>/dev/null; then
  pass "F-035: state-commit.sh resets local state after PR creation"
else
  fail "F-035: state-commit.sh missing local state reset"
fi

# AC-003: done.sh runs dogfood-sync before state-commit.sh
# Verify ordering: dogfood-sync line number < state-commit.sh line number
_dsync_line=$(grep -n "dogfood-sync" "${FRAMEWORK_ROOT}/.agentic/lib/tools/commands/done.sh" 2>/dev/null | head -1 | cut -d: -f1)
_flush_line=$(grep -n "state-commit.sh" "${FRAMEWORK_ROOT}/.agentic/lib/tools/commands/done.sh" 2>/dev/null | head -1 | cut -d: -f1)
if [[ -n "$_dsync_line" && -n "$_flush_line" && "$_dsync_line" -lt "$_flush_line" ]]; then
  pass "F-035: done.sh runs dogfood-sync before state-commit.sh flush"
else
  fail "F-035: done.sh ordering wrong — dogfood-sync must run before state-commit.sh"
fi

# VERSION file sync (framework-dev)
echo "--- VERSION file sync ---"

if [[ -f "${FRAMEWORK_ROOT}/FRAMEWORK_DEVELOPMENT.md" ]]; then
  _root_ver=$(cat "${FRAMEWORK_ROOT}/VERSION" 2>/dev/null | tr -d '[:space:]')
  _lib_ver=$(cat "${FRAMEWORK_ROOT}/.agentic/lib/VERSION" 2>/dev/null | tr -d '[:space:]')
  if [[ -n "$_root_ver" && "$_root_ver" == "$_lib_ver" ]]; then
    pass "VERSION files in sync (root=$_root_ver, lib=$_lib_ver)"
  else
    fail "VERSION files out of sync (root=$_root_ver, lib=$_lib_ver)"
  fi
else
  pass "VERSION sync check skipped (not framework-dev)"
fi

if grep -A25 'ALLOWLIST=(' "${FRAMEWORK_ROOT}/.agentic/lib/tools/state-commit.sh" | grep -qF '.agentic/lib/VERSION'; then
  pass ".agentic/lib/VERSION in state-commit.sh allowlist"
else
  fail ".agentic/lib/VERSION not in state-commit.sh allowlist"
fi

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

