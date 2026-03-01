#!/usr/bin/env bash
# add-remaining-frontmatter.sh: Add YAML frontmatter to remaining .agentic/ files
# Completes frontmatter coverage started by add-frontmatter.sh and add-subagent-frontmatter.sh
#
# Usage: bash .agentic/tools/add-remaining-frontmatter.sh [--dry-run] [--batch N]
#
# Batches:
#   1 - Agent roles (13) + agent shared (4)
#   2 - Root docs (8) + token efficiency (5) + init operational (3)
#   3 - Cursor prompts (13) + spec operational (2) + analyze-agents (1)
#   4 - Support docs (19)
#   5 - Misc stragglers (3)
#   all - All batches (default)
#
# Idempotent: skips files that already have frontmatter (start with ---)

set -euo pipefail

DRY_RUN=false
BATCH="all"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --batch) BATCH="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTIC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ADDED=0
SKIPPED=0

# Calculate tokens from word count: tokens ≈ words × 4/3
calc_tokens() {
    local file="$1"
    local words
    words=$(wc -w < "$file" | tr -d ' ')
    echo $(( (words * 4 + 2) / 3 ))
}

# Schema: minimal (summary + tokens) — for reference/support docs
add_minimal_frontmatter() {
    local file="$1"
    local summary="$2"

    if head -1 "$file" | grep -q "^---"; then
        echo -e "  ${YELLOW}⊘${NC} $(basename "$file") (already has frontmatter)"
        SKIPPED=$((SKIPPED + 1))
        return
    fi

    local tokens
    tokens=$(calc_tokens "$file")

    if $DRY_RUN; then
        echo -e "  ${BLUE}○${NC} $(basename "$file") → ~${tokens} tokens: ${summary:0:60}..."
        ADDED=$((ADDED + 1))
        return
    fi

    local tmpfile
    tmpfile=$(mktemp)

    {
        echo "---"
        echo "summary: \"$summary\""
        echo "tokens: ~$tokens"
        echo "---"
        echo ""
        cat "$file"
    } > "$tmpfile"

    mv "$tmpfile" "$file"
    echo -e "  ${GREEN}✓${NC} $(basename "$file") (~${tokens} tokens)"
    ADDED=$((ADDED + 1))
}

# Schema: prompt (command + description) — for cursor prompts
add_prompt_frontmatter() {
    local file="$1"
    local command="$2"
    local description="$3"

    if head -1 "$file" | grep -q "^---"; then
        echo -e "  ${YELLOW}⊘${NC} $(basename "$file") (already has frontmatter)"
        SKIPPED=$((SKIPPED + 1))
        return
    fi

    if $DRY_RUN; then
        echo -e "  ${BLUE}○${NC} $(basename "$file") → ${command}: ${description:0:50}..."
        ADDED=$((ADDED + 1))
        return
    fi

    local tmpfile
    tmpfile=$(mktemp)

    {
        echo "---"
        echo "command: $command"
        echo "description: $description"
        echo "---"
        echo ""
        cat "$file"
    } > "$tmpfile"

    mv "$tmpfile" "$file"
    echo -e "  ${GREEN}✓${NC} $(basename "$file")"
    ADDED=$((ADDED + 1))
}

echo -e "${BLUE}=== Adding remaining frontmatter (batch: $BATCH) ===${NC}"
echo ""

# ── Batch 1: Agent Roles + Shared ─────────────────────────
if [[ "$BATCH" == "all" || "$BATCH" == "1" ]]; then
echo -e "${BLUE}Agent Roles:${NC}"

add_minimal_frontmatter "$AGENTIC_DIR/agents/roles/architecture_agent.md" \
    "Design system architecture, evaluate patterns, ensure scalability"

add_minimal_frontmatter "$AGENTIC_DIR/agents/roles/cloud_expert_agent.md" \
    "Cloud-platform expertise for AWS, GCP, Azure deployments"

add_minimal_frontmatter "$AGENTIC_DIR/agents/roles/documentation_agent.md" \
    "Update user-facing and developer documentation after changes"

add_minimal_frontmatter "$AGENTIC_DIR/agents/roles/git_agent.md" \
    "Handle version control operations: commits, branches, PRs"

add_minimal_frontmatter "$AGENTIC_DIR/agents/roles/implementation_agent.md" \
    "Write code to make failing tests pass (TDD green phase)"

add_minimal_frontmatter "$AGENTIC_DIR/agents/roles/monetization_agent.md" \
    "Advise on pricing strategies, revenue models, payment flows"

add_minimal_frontmatter "$AGENTIC_DIR/agents/roles/orchestrator-agent.md" \
    "Coordinate specialized agents, enforce compliance, manage pipeline"

add_minimal_frontmatter "$AGENTIC_DIR/agents/roles/planning_agent.md" \
    "Define features, write acceptance criteria, create ADRs"

add_minimal_frontmatter "$AGENTIC_DIR/agents/roles/research_agent.md" \
    "Investigate technology choices, best practices, external dependencies"

add_minimal_frontmatter "$AGENTIC_DIR/agents/roles/review_agent.md" \
    "Review code quality, security, and adherence to standards"

add_minimal_frontmatter "$AGENTIC_DIR/agents/roles/scientific_research_agent.md" \
    "Gather peer-reviewed papers, benchmarks, and reference implementations"

add_minimal_frontmatter "$AGENTIC_DIR/agents/roles/spec_update_agent.md" \
    "Update spec documents to reflect completed work"

add_minimal_frontmatter "$AGENTIC_DIR/agents/roles/test_agent.md" \
    "Write tests based on acceptance criteria before implementation (TDD)"

echo ""
echo -e "${BLUE}Agent Shared:${NC}"

add_minimal_frontmatter "$AGENTIC_DIR/agents/shared/AGENT_QUICK_START.md" \
    "Concise onboarding for agents: gates, scripts, workflow in ~60 lines"

add_minimal_frontmatter "$AGENTIC_DIR/agents/shared/agent_operating_guidelines.md" \
    "Complete operating rules for all AI agents across all tools"

add_minimal_frontmatter "$AGENTIC_DIR/agents/shared/auto_orchestration.md" \
    "Workflow trigger rules for Cursor, Copilot, Codex (non-Claude tools)"

add_minimal_frontmatter "$AGENTIC_DIR/agents/shared/doc_types.md" \
    "Built-in document type definitions for the doc lifecycle system"

fi

# ── Batch 2: Root Docs + Token Efficiency + Init ──────────
if [[ "$BATCH" == "all" || "$BATCH" == "2" ]]; then
echo ""
echo -e "${BLUE}Root Docs:${NC}"

add_minimal_frontmatter "$AGENTIC_DIR/DEVELOPER_GUIDE.md" \
    "Complete guide for developers: manual workflow, tools, customization"

add_minimal_frontmatter "$AGENTIC_DIR/PRINCIPLES.md" \
    "Core values and principles guiding every framework design decision"

add_minimal_frontmatter "$AGENTIC_DIR/ROI.md" \
    "Business case: 50-80% cost reduction via token efficiency and automation"

add_minimal_frontmatter "$AGENTIC_DIR/START_HERE.md" \
    "Quick guide entry point for new users of the Agentic AI Framework"

add_minimal_frontmatter "$AGENTIC_DIR/FRAMEWORK_MAP.md" \
    "Visual guide showing how all framework components fit together"

add_minimal_frontmatter "$AGENTIC_DIR/DIRECT_EDITING.md" \
    "How to edit spec files directly without agent involvement"

add_minimal_frontmatter "$AGENTIC_DIR/EMERGENCY.md" \
    "Emergency quick reference for when tokens run out or agent unavailable"

add_minimal_frontmatter "$AGENTIC_DIR/MANUAL_OPERATIONS.md" \
    "Commands to check project state without consuming AI tokens"

echo ""
echo -e "${BLUE}Token Efficiency:${NC}"

add_minimal_frontmatter "$AGENTIC_DIR/token_efficiency/agent_delegation_savings.md" \
    "Why subagents work: fresh context is the primary benefit, not cheaper models"

add_minimal_frontmatter "$AGENTIC_DIR/token_efficiency/change_small.md" \
    "Small changes save tokens and reduce risk — batch size guidance"

add_minimal_frontmatter "$AGENTIC_DIR/token_efficiency/claude_best_practices.md" \
    "Claude-specific token optimization based on official usage guide"

add_minimal_frontmatter "$AGENTIC_DIR/token_efficiency/context_budgeting.md" \
    "Context budgeting principles: minimize token waste strategically"

add_minimal_frontmatter "$AGENTIC_DIR/token_efficiency/reading_protocols.md" \
    "Strategic reading patterns to maximize development efficiency per token"

echo ""
echo -e "${BLUE}Init Operational:${NC}"

add_minimal_frontmatter "$AGENTIC_DIR/init/init_playbook.md" \
    "Agent-guided repo initialization: produce durable artifacts in one session"

add_minimal_frontmatter "$AGENTIC_DIR/init/init_questions.md" \
    "Canonical questions for project initialization — ask only what's necessary"

add_minimal_frontmatter "$AGENTIC_DIR/init/memory-seed.md" \
    "Action rules agents write to persistent memory at session start"

fi

# ── Batch 3: Cursor Prompts + Spec + Analyze-Agents ───────
if [[ "$BATCH" == "all" || "$BATCH" == "3" ]]; then
echo ""
echo -e "${BLUE}Cursor Prompts:${NC}"

add_prompt_frontmatter "$AGENTIC_DIR/prompts/cursor/feature_complete.md" \
    "/feature-complete" "Mark feature as done, run completion checklist"

add_prompt_frontmatter "$AGENTIC_DIR/prompts/cursor/feature_start.md" \
    "/feature-start" "Start feature implementation with formal workflow"

add_prompt_frontmatter "$AGENTIC_DIR/prompts/cursor/feature_test.md" \
    "/feature-test" "Write tests for a feature using TDD approach"

add_prompt_frontmatter "$AGENTIC_DIR/prompts/cursor/fix_issues.md" \
    "/fix-issues" "Fix linter errors, test failures, or other issues"

add_prompt_frontmatter "$AGENTIC_DIR/prompts/cursor/migration_create.md" \
    "/migration-create" "Create database or system migration"

add_prompt_frontmatter "$AGENTIC_DIR/prompts/cursor/plan_feature.md" \
    "/plan-feature" "Plan a feature with acceptance criteria and ADR"

add_prompt_frontmatter "$AGENTIC_DIR/prompts/cursor/product_update.md" \
    "/product-update" "Write product update announcement for stakeholders"

add_prompt_frontmatter "$AGENTIC_DIR/prompts/cursor/quick_feature.md" \
    "/quick-feature" "Implement a small feature in discovery mode"

add_prompt_frontmatter "$AGENTIC_DIR/prompts/cursor/research.md" \
    "/research" "Research technology choices or best practices"

add_prompt_frontmatter "$AGENTIC_DIR/prompts/cursor/retrospective.md" \
    "/retrospective" "Run project retrospective and health check"

add_prompt_frontmatter "$AGENTIC_DIR/prompts/cursor/run_quality.md" \
    "/run-quality" "Run quality checks and validation suite"

add_prompt_frontmatter "$AGENTIC_DIR/prompts/cursor/session_end.md" \
    "/session-end" "Wrap up session, update journal and status"

add_prompt_frontmatter "$AGENTIC_DIR/prompts/cursor/session_start.md" \
    "/session-start" "Start new session with context loading"

echo ""
echo -e "${BLUE}Spec Operational:${NC}"

add_minimal_frontmatter "$AGENTIC_DIR/spec/SPEC_SCHEMA.md" \
    "Canonical schema defining structure, fields, and valid values for all specs"

add_minimal_frontmatter "$AGENTIC_DIR/spec/naming_and_lifecycle.md" \
    "Spec naming conventions and document lifecycle rules"

echo ""
echo -e "${BLUE}Claude Commands:${NC}"

add_minimal_frontmatter "$AGENTIC_DIR/prompts/analyze-agents.md" \
    "Analyze project to recommend specialized agents for its domain"

fi

# ── Batch 4: Support Docs ─────────────────────────────────
if [[ "$BATCH" == "all" || "$BATCH" == "4" ]]; then
echo ""
echo -e "${BLUE}Stack Profiles:${NC}"

add_minimal_frontmatter "$AGENTIC_DIR/support/stack_profiles/backend_go_service.md" \
    "Stack profile for Go backend services: structure, testing, deployment"

add_minimal_frontmatter "$AGENTIC_DIR/support/stack_profiles/generic_default.md" \
    "Default stack profile for projects without a specific template"

add_minimal_frontmatter "$AGENTIC_DIR/support/stack_profiles/juce_vstplugin.md" \
    "Stack profile for JUCE audio plugins: VST/AU build, testing, DSP"

add_minimal_frontmatter "$AGENTIC_DIR/support/stack_profiles/ml_python_project.md" \
    "Stack profile for ML/Python projects: training, evaluation, deployment"

add_minimal_frontmatter "$AGENTIC_DIR/support/stack_profiles/mobile_ios.md" \
    "Stack profile for iOS apps: Swift, UIKit/SwiftUI, Xcode, TestFlight"

add_minimal_frontmatter "$AGENTIC_DIR/support/stack_profiles/mobile_react_native.md" \
    "Stack profile for React Native apps: cross-platform mobile development"

add_minimal_frontmatter "$AGENTIC_DIR/support/stack_profiles/systems_rust.md" \
    "Stack profile for Rust systems projects: safety, performance, testing"

add_minimal_frontmatter "$AGENTIC_DIR/support/stack_profiles/webapp_fullstack.md" \
    "Stack profile for full-stack web apps: frontend, backend, database"

echo ""
echo -e "${BLUE}Design Systems:${NC}"

add_minimal_frontmatter "$AGENTIC_DIR/support/design_systems/ios-human-interface.md" \
    "Apple Human Interface Guidelines reference for iOS design"

add_minimal_frontmatter "$AGENTIC_DIR/support/design_systems/material-design.md" \
    "Google Material Design system reference for UI components"

add_minimal_frontmatter "$AGENTIC_DIR/support/design_systems/modern-minimal.md" \
    "Modern minimal design system: clean typography, whitespace, restraint"

echo ""
echo -e "${BLUE}Docs Templates:${NC}"

add_minimal_frontmatter "$AGENTIC_DIR/support/docs_templates/architecture_ARCHITECTURE.md" \
    "Template for project architecture documentation"

add_minimal_frontmatter "$AGENTIC_DIR/support/docs_templates/architecture_diagram_COMPONENT.md" \
    "Template for component-level architecture diagrams"

add_minimal_frontmatter "$AGENTIC_DIR/support/docs_templates/debugging_TROUBLESHOOTING.md" \
    "Template for troubleshooting and debugging guides"

add_minimal_frontmatter "$AGENTIC_DIR/support/docs_templates/docs_README.md" \
    "Template for project README documentation"

add_minimal_frontmatter "$AGENTIC_DIR/support/docs_templates/operations_RUNBOOK.md" \
    "Template for operations runbook documentation"

add_minimal_frontmatter "$AGENTIC_DIR/support/docs_templates/research_RESEARCH_TOPIC.md" \
    "Template for research topic documentation"

echo ""
echo -e "${BLUE}CI + Environment:${NC}"

add_minimal_frontmatter "$AGENTIC_DIR/support/ci/spec_lint.md" \
    "CI lint rules validating durable context artifacts agents rely on"

add_minimal_frontmatter "$AGENTIC_DIR/support/environment_research.md" \
    "Capabilities and best practices for each AI coding environment"

fi

# ── Batch 5: Misc Stragglers ──────────────────────────────
if [[ "$BATCH" == "all" || "$BATCH" == "5" ]]; then
echo ""
echo -e "${BLUE}Misc Stragglers:${NC}"

add_minimal_frontmatter "$AGENTIC_DIR/agents/installation.md" \
    "Guide for installing agent tool integrations (AGENTS.md is reference-only)"

add_minimal_frontmatter "$AGENTIC_DIR/agents/claude/sub-agents.md" \
    "How to use Claude Code native sub-agent capabilities with the framework"

add_minimal_frontmatter "$AGENTIC_DIR/workflows/retrospective.md" \
    "Periodic agent-led project health review and improvement suggestions"

fi

# ── Summary ───────────────────────────────────────────────
echo ""
if $DRY_RUN; then
    echo -e "${YELLOW}DRY RUN: Would add frontmatter to $ADDED files ($SKIPPED already had it)${NC}"
else
    echo -e "${GREEN}Added frontmatter to $ADDED files ($SKIPPED already had it)${NC}"
fi
