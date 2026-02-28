#!/usr/bin/env bash
# add-frontmatter.sh: Add YAML frontmatter to playbook/quality/guideline files
# Enables progressive disclosure — Claude scans summaries instead of loading full files
#
# Usage: bash .agentic/tools/add-frontmatter.sh [--dry-run]
#
# Idempotent: skips files that already have frontmatter (start with ---)

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTIC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ADDED=0
SKIPPED=0

add_frontmatter() {
    local file="$1"
    local summary="$2"
    local trigger="$3"
    local tokens="$4"
    local phase="$5"
    local requires="${6:-}"

    # Skip if already has frontmatter
    if head -1 "$file" | grep -q "^---"; then
        echo -e "  ${YELLOW}⊘${NC} $(basename "$file") (already has frontmatter)"
        SKIPPED=$((SKIPPED + 1))
        return
    fi

    if $DRY_RUN; then
        echo -e "  ${BLUE}○${NC} $(basename "$file") → summary: ${summary:0:60}..."
        ADDED=$((ADDED + 1))
        return
    fi

    local tmpfile
    tmpfile=$(mktemp)

    {
        echo "---"
        echo "summary: \"$summary\""
        echo "trigger: \"$trigger\""
        echo "tokens: ~$tokens"
        if [[ -n "$requires" ]]; then
            echo "requires: [$requires]"
        fi
        echo "phase: $phase"
        echo "---"
        echo ""
        cat "$file"
    } > "$tmpfile"

    mv "$tmpfile" "$file"
    echo -e "  ${GREEN}✓${NC} $(basename "$file")"
    ADDED=$((ADDED + 1))
}

# ── Checklists ──────────────────────────────────────────────
echo -e "${BLUE}Checklists:${NC}"

add_frontmatter "$AGENTIC_DIR/checklists/session_start.md" \
    "Initialize session: check WIP, read state files, greet user with dashboard" \
    "session start, first message, where were we, ag start" \
    "3500" "session" ""

add_frontmatter "$AGENTIC_DIR/checklists/feature_start.md" \
    "Pre-feature gates: acceptance criteria, scope check, delegation decision" \
    "build, implement, add feature, create, ag implement" \
    "1000" "planning" ""

add_frontmatter "$AGENTIC_DIR/checklists/feature_implementation.md" \
    "Implementation workflow: code, test, iterate, handle edge cases" \
    "implementing, coding, writing code, building" \
    "3300" "implementation" "feature_start.md"

add_frontmatter "$AGENTIC_DIR/checklists/before_commit.md" \
    "Pre-commit quality gates and human approval" \
    "commit, push, ship, finalize, ag commit" \
    "2700" "commit" "feature_implementation.md"

add_frontmatter "$AGENTIC_DIR/checklists/feature_complete.md" \
    "Feature completion: mark done, update specs, cleanup WIP" \
    "done, complete, finished, ag done" \
    "3300" "completion" "before_commit.md"

add_frontmatter "$AGENTIC_DIR/checklists/session_end.md" \
    "Session wrap-up: update journal, status, capture next steps" \
    "ending session, wrapping up, goodbye, signing off" \
    "2800" "session" ""

add_frontmatter "$AGENTIC_DIR/checklists/smoke_testing.md" \
    "Smoke test checklist: verify feature works end-to-end before committing" \
    "smoke test, verify, does it work, quick test" \
    "3300" "testing" "feature_implementation.md"

add_frontmatter "$AGENTIC_DIR/checklists/retrospective.md" \
    "Project retrospective: what worked, what didn't, lessons learned" \
    "retrospective, retro, what went well, lessons" \
    "3400" "review" ""

add_frontmatter "$AGENTIC_DIR/checklists/agent_behavior_verification.md" \
    "Verify agent follows framework rules: triggers, gates, artifacts" \
    "verify behavior, agent test, compliance check" \
    "1500" "testing" ""

# ── Workflows ───────────────────────────────────────────────
echo -e "${BLUE}Workflows:${NC}"

add_frontmatter "$AGENTIC_DIR/workflows/dev_loop.md" \
    "Core development cycle: plan, implement, test, commit" \
    "development loop, workflow, how to develop" \
    "500" "implementation" ""

add_frontmatter "$AGENTIC_DIR/workflows/tdd_mode.md" \
    "Test-driven development: red-green-refactor cycle" \
    "tdd, test first, red green refactor" \
    "5500" "implementation" ""

add_frontmatter "$AGENTIC_DIR/workflows/plan_review_loop.md" \
    "Plan-review iteration: create plan, review, refine, approve" \
    "plan, design, ag plan, review plan" \
    "2800" "planning" ""

add_frontmatter "$AGENTIC_DIR/workflows/git_workflow.md" \
    "Git practices: branching, PRs, commit messages, merge strategy" \
    "git, branch, PR, pull request, merge" \
    "5000" "commit" ""

add_frontmatter "$AGENTIC_DIR/workflows/work_in_progress.md" \
    "WIP tracking: start, checkpoint, recover interrupted work" \
    "wip, interrupted, recovery, checkpoint" \
    "4400" "implementation" ""

add_frontmatter "$AGENTIC_DIR/workflows/recovery.md" \
    "Recovery from interruptions: detect, assess, resume or rollback" \
    "recovery, interrupted, crashed, resume, rollback" \
    "4200" "session" ""

add_frontmatter "$AGENTIC_DIR/workflows/spec_evolution.md" \
    "How specs evolve during implementation: amendments, scope changes" \
    "spec change, scope change, amend spec, evolve" \
    "2000" "implementation" ""

add_frontmatter "$AGENTIC_DIR/workflows/research_mode.md" \
    "Deep research: web search, docs lookup, technology evaluation" \
    "research, investigate, look up, find docs, evaluate" \
    "4500" "research" ""

add_frontmatter "$AGENTIC_DIR/workflows/multi_agent_coordination.md" \
    "Multi-agent coordination: registration, file locking, conflict avoidance" \
    "multi agent, coordination, parallel agents, conflict" \
    "6500" "implementation" ""

add_frontmatter "$AGENTIC_DIR/workflows/sequential_agent_specialization.md" \
    "Sequential agent pipeline: orchestrator dispatches specialized agents" \
    "pipeline, sequential agents, orchestrator, dispatch" \
    "10000" "implementation" ""

add_frontmatter "$AGENTIC_DIR/workflows/automatic_sequential_pipeline.md" \
    "Automated pipeline execution: trigger, sequence, handoff between agents" \
    "automatic pipeline, auto sequence, pipeline run" \
    "8000" "implementation" ""

add_frontmatter "$AGENTIC_DIR/workflows/automatic_journaling.md" \
    "Auto-logging checkpoints: when and what to journal" \
    "journal, log, checkpoint, auto journal" \
    "2800" "session" ""

add_frontmatter "$AGENTIC_DIR/workflows/delegation_heuristics.md" \
    "When to delegate to agents vs do it yourself" \
    "delegate, should I use agent, agent vs manual" \
    "1500" "planning" ""

add_frontmatter "$AGENTIC_DIR/workflows/scaling_guidance.md" \
    "Progressive complexity: when to add agents, pipelines, automation" \
    "scaling, growing, more agents, complexity" \
    "2900" "planning" ""

add_frontmatter "$AGENTIC_DIR/workflows/environment_switching.md" \
    "Switching between dev environments and tool configurations" \
    "environment, switch, different tool, cursor, copilot" \
    "3500" "session" ""

add_frontmatter "$AGENTIC_DIR/workflows/agent_mode.md" \
    "Agent mode selection: premium, balanced, economy trade-offs" \
    "agent mode, premium, economy, cost, quality" \
    "1400" "planning" ""

add_frontmatter "$AGENTIC_DIR/workflows/code_annotations.md" \
    "Spec-to-code linking: @feature, @decision annotations" \
    "annotations, traceability, @feature, link spec to code" \
    "2100" "implementation" ""

add_frontmatter "$AGENTIC_DIR/workflows/continuous_quality_validation.md" \
    "Continuous quality checks: automated validation during development" \
    "quality validation, continuous check, automated quality" \
    "9700" "testing" ""

add_frontmatter "$AGENTIC_DIR/workflows/debugging_playbook.md" \
    "Systematic debugging: reproduce, isolate, fix, verify" \
    "debug, bug, troubleshoot, fix error" \
    "250" "implementation" ""

add_frontmatter "$AGENTIC_DIR/workflows/definition_of_done.md" \
    "What 'done' means: code, tests, docs, review criteria" \
    "definition of done, what is done, DoD, acceptance" \
    "500" "completion" ""

add_frontmatter "$AGENTIC_DIR/workflows/document_format_specs.md" \
    "Format specifications for framework documents (STATUS, JOURNAL, etc.)" \
    "format, document format, file format, spec format" \
    "4400" "documentation" ""

add_frontmatter "$AGENTIC_DIR/workflows/documentation_verification.md" \
    "Verify documentation is current and accurate after changes" \
    "verify docs, documentation check, docs current" \
    "2000" "documentation" ""

add_frontmatter "$AGENTIC_DIR/workflows/format_validation.md" \
    "Validate file format compliance (frontmatter, sections, structure)" \
    "format validation, validate format, check format" \
    "2800" "testing" ""

add_frontmatter "$AGENTIC_DIR/workflows/spec_format_validation.md" \
    "Validate spec file format: required fields, sections, consistency" \
    "spec validation, validate spec, check spec format" \
    "5600" "testing" ""

add_frontmatter "$AGENTIC_DIR/workflows/spec_migrations.md" \
    "Migrate spec files between format versions" \
    "spec migration, upgrade spec, format change" \
    "3900" "maintenance" ""

add_frontmatter "$AGENTIC_DIR/workflows/game_development.md" \
    "Game development best practices: Theory of Fun, playtesting, iteration" \
    "game, game dev, gameplay, playtesting" \
    "6900" "domain" ""

add_frontmatter "$AGENTIC_DIR/workflows/visual_design_workflow.md" \
    "Visual design process: mockups, assets, CSS, responsive" \
    "design, visual, UI, CSS, mockup, responsive" \
    "2700" "domain" ""

add_frontmatter "$AGENTIC_DIR/workflows/media_asset_workflow.md" \
    "Media asset sourcing: images, icons, fonts, audio" \
    "media, assets, images, icons, fonts, audio" \
    "7200" "domain" ""

add_frontmatter "$AGENTIC_DIR/workflows/project_licensing.md" \
    "Open source licensing guide: choosing, applying, compliance" \
    "license, licensing, open source, MIT, GPL" \
    "6300" "domain" ""

add_frontmatter "$AGENTIC_DIR/workflows/proactive_agent_loop.md" \
    "Proactive agent behavior: anticipate needs, suggest next steps" \
    "proactive, anticipate, suggest, autonomous" \
    "6200" "implementation" ""

# Skip README and USER_WORKFLOWS (index files, not playbooks)
echo -e "  ${YELLOW}⊘${NC} README.md (index file, skipping)"
echo -e "  ${YELLOW}⊘${NC} USER_WORKFLOWS.md (index file, skipping)"

# ── Guidelines ──────────────────────────────────────────────
echo -e "${BLUE}Guidelines:${NC}"

add_frontmatter "$AGENTIC_DIR/agents/shared/guidelines/core-rules.md" \
    "Constitutional minimum: no fabrication, no auto-commit, use token scripts" \
    "core rules, constitution, minimum rules" \
    "170" "always" ""

add_frontmatter "$AGENTIC_DIR/agents/shared/guidelines/anti-hallucination.md" \
    "Verification rules: check before creating, never fabricate paths or APIs" \
    "hallucination, fabrication, verify, check first" \
    "1200" "always" ""

add_frontmatter "$AGENTIC_DIR/agents/shared/guidelines/token-efficiency.md" \
    "Token optimization: use scripts, delegate, minimize context" \
    "token, efficiency, cost, optimize, save tokens" \
    "1000" "always" ""

add_frontmatter "$AGENTIC_DIR/agents/shared/guidelines/multi-agent.md" \
    "Multi-agent coordination: register, avoid conflicts, handoff" \
    "multi agent, coordination, parallel, conflict" \
    "1400" "implementation" ""

add_frontmatter "$AGENTIC_DIR/agents/shared/guidelines/small-batch.md" \
    "Small batch development: max 5-10 files, break large tasks" \
    "small batch, too big, break down, max files" \
    "830" "always" ""

add_frontmatter "$AGENTIC_DIR/agents/shared/guidelines/wip-tracking.md" \
    "WIP tracking: start, checkpoint, complete, recover" \
    "wip, work in progress, tracking, checkpoint" \
    "1280" "implementation" ""

# Skip README (index file)
echo -e "  ${YELLOW}⊘${NC} README.md (index file, skipping)"

# ── Quality ─────────────────────────────────────────────────
echo -e "${BLUE}Quality:${NC}"

add_frontmatter "$AGENTIC_DIR/quality/programming_standards.md" \
    "Code quality standards: naming, structure, error handling, style" \
    "code quality, standards, naming, style, conventions" \
    "12300" "implementation" ""

add_frontmatter "$AGENTIC_DIR/quality/test_strategy.md" \
    "Testing approach: unit, integration, e2e, coverage targets" \
    "test strategy, testing, coverage, unit test, e2e" \
    "3600" "testing" ""

add_frontmatter "$AGENTIC_DIR/quality/review_checklist.md" \
    "Code review checklist: correctness, security, performance, style" \
    "review, code review, checklist, PR review" \
    "320" "review" ""

add_frontmatter "$AGENTIC_DIR/quality/design_for_testability.md" \
    "Testability patterns: dependency injection, interfaces, seams" \
    "testability, DI, dependency injection, testable" \
    "220" "implementation" ""

add_frontmatter "$AGENTIC_DIR/quality/green_coding.md" \
    "Sustainable coding: performance, resource efficiency, battery-friendly" \
    "green coding, performance, sustainability, efficient" \
    "10200" "implementation" ""

add_frontmatter "$AGENTIC_DIR/quality/integration_testing.md" \
    "Integration test strategies: API, database, service boundaries" \
    "integration test, API test, database test, service test" \
    "3500" "testing" ""

add_frontmatter "$AGENTIC_DIR/quality/library_selection.md" \
    "When to use libraries vs custom code: evaluation criteria" \
    "library, dependency, package, npm, pip, custom vs library" \
    "4000" "planning" ""

echo ""
if $DRY_RUN; then
    echo -e "${YELLOW}DRY RUN: Would add frontmatter to $ADDED files ($SKIPPED skipped)${NC}"
else
    echo -e "${GREEN}Added frontmatter to $ADDED files ($SKIPPED already had it)${NC}"
fi
