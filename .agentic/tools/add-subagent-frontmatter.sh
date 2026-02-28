#!/usr/bin/env bash
# add-subagent-frontmatter.sh: Add YAML frontmatter to subagent definition files
# Standardizes metadata for role selection and future tooling.
#
# Usage: bash .agentic/tools/add-subagent-frontmatter.sh [--dry-run]
#
# Idempotent: skips files that already have frontmatter (start with ---)

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTIC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBAGENTS_DIR="$AGENTIC_DIR/agents/claude/subagents"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ADDED=0
SKIPPED=0

add_frontmatter() {
    local file="$1"
    local role="$2"
    local model_tier="$3"
    local summary="$4"
    local use_when="$5"
    local tokens="$6"

    # Skip if already has frontmatter
    if head -1 "$file" | grep -q "^---"; then
        echo -e "  ${YELLOW}⊘${NC} $(basename "$file") (already has frontmatter)"
        SKIPPED=$((SKIPPED + 1))
        return
    fi

    if $DRY_RUN; then
        echo -e "  ${BLUE}○${NC} $(basename "$file") → role: $role, tier: $model_tier"
        ADDED=$((ADDED + 1))
        return
    fi

    local tmpfile
    tmpfile=$(mktemp)

    {
        echo "---"
        echo "role: $role"
        echo "model_tier: $model_tier"
        echo "summary: \"$summary\""
        echo "use_when: \"$use_when\""
        echo "tokens: ~$tokens"
        echo "---"
        echo ""
        cat "$file"
    } > "$tmpfile"

    mv "$tmpfile" "$file"
    echo -e "  ${GREEN}✓${NC} $(basename "$file")"
    ADDED=$((ADDED + 1))
}

echo -e "${BLUE}=== Adding frontmatter to subagent definitions ===${NC}"
echo ""

# ── Core Development Agents ─────────────────────────────────
echo -e "${BLUE}Core Development:${NC}"

add_frontmatter "$SUBAGENTS_DIR/implementation-agent.md" \
    "implementation" "mid-tier" \
    "Write production code, implement features, fix bugs" \
    "Features >20 lines, complex bugs, refactoring, multi-file changes" \
    "600"

add_frontmatter "$SUBAGENTS_DIR/review-agent.md" \
    "review" "mid-tier" \
    "Code review, quality checks, refactoring suggestions" \
    "PR reviews, code quality audits, pre-commit review" \
    "700"

add_frontmatter "$SUBAGENTS_DIR/test-agent.md" \
    "testing" "mid-tier" \
    "Write and run tests for implemented features" \
    "New features need tests, TDD cycles, test coverage gaps" \
    "700"

add_frontmatter "$SUBAGENTS_DIR/planning-agent.md" \
    "planning" "mid-tier" \
    "Define features and write acceptance criteria" \
    "New feature requests, acceptance criteria drafting, scope definition" \
    "500"

add_frontmatter "$SUBAGENTS_DIR/documentation-agent.md" \
    "documentation" "cheap" \
    "Update documentation and README files after feature completion" \
    "Post-feature doc updates, README refresh, API docs" \
    "600"

add_frontmatter "$SUBAGENTS_DIR/explore-agent.md" \
    "exploration" "cheap" \
    "Quick codebase exploration, finding files, understanding structure" \
    "Finding files, understanding architecture, codebase navigation" \
    "500"

add_frontmatter "$SUBAGENTS_DIR/git-agent.md" \
    "git" "cheap" \
    "Handle git operations: commits, branches, PRs" \
    "Committing, branching, PR creation, merge operations" \
    "500"

add_frontmatter "$SUBAGENTS_DIR/refactor-agent.md" \
    "refactoring" "mid-tier" \
    "Improve code structure without changing behavior" \
    "Code smell cleanup, pattern extraction, architecture improvement" \
    "700"

# ── Planning & Strategy Agents ───────────────────────────────
echo -e "${BLUE}Planning & Strategy:${NC}"

add_frontmatter "$SUBAGENTS_DIR/orchestrator-agent.md" \
    "orchestration" "mid-tier" \
    "Coordinate specialized agents, ensure framework compliance, manage feature pipeline" \
    "Complex multi-agent tasks, feature pipeline management, compliance enforcement" \
    "900"

add_frontmatter "$SUBAGENTS_DIR/plan-creator-agent.md" \
    "planning" "high-tier" \
    "Create detailed implementation plans for features before coding begins" \
    "Complex features requiring architectural planning, multi-file changes" \
    "1000"

add_frontmatter "$SUBAGENTS_DIR/plan-reviewer-agent.md" \
    "review" "high-tier" \
    "Critically review implementation plans before coding begins" \
    "Plan quality assurance, risk identification, approach validation" \
    "1200"

add_frontmatter "$SUBAGENTS_DIR/research-agent.md" \
    "research" "mid-tier" \
    "Web search, documentation lookup, technology research" \
    "Technology evaluation, docs lookup, best practices research" \
    "700"

add_frontmatter "$SUBAGENTS_DIR/spec-update-agent.md" \
    "spec-management" "cheap" \
    "Update FEATURES.md and other spec files after implementation" \
    "Post-implementation spec sync, feature status updates" \
    "400"

# ── Quality & Security Agents ────────────────────────────────
echo -e "${BLUE}Quality & Security:${NC}"

add_frontmatter "$SUBAGENTS_DIR/security-agent.md" \
    "security" "mid-tier" \
    "Security audits, vulnerability scanning, secure code review" \
    "Security-sensitive features, dependency audits, OWASP checks" \
    "800"

add_frontmatter "$SUBAGENTS_DIR/compliance-agent.md" \
    "compliance" "mid-tier" \
    "Verify framework compliance, check quality gates, ensure standards" \
    "Pre-release checks, framework compliance audits, gate verification" \
    "700"

add_frontmatter "$SUBAGENTS_DIR/perf-agent.md" \
    "performance" "mid-tier" \
    "Identify and resolve performance bottlenecks" \
    "Slow operations, memory issues, optimization needs, profiling" \
    "800"

add_frontmatter "$SUBAGENTS_DIR/ux-agent.md" \
    "ux" "mid-tier" \
    "Evaluate usability, accessibility, and user experience" \
    "UI/UX reviews, accessibility audits, usability testing" \
    "800"

# ── Infrastructure & DevOps Agents ───────────────────────────
echo -e "${BLUE}Infrastructure & DevOps:${NC}"

add_frontmatter "$SUBAGENTS_DIR/aws-agent.md" \
    "infrastructure" "mid-tier" \
    "AWS architecture, service selection, infrastructure setup" \
    "AWS deployments, service configuration, cloud architecture on AWS" \
    "1000"

add_frontmatter "$SUBAGENTS_DIR/azure-agent.md" \
    "infrastructure" "mid-tier" \
    "Azure architecture, service selection, infrastructure setup" \
    "Azure deployments, service configuration, cloud architecture on Azure" \
    "1000"

add_frontmatter "$SUBAGENTS_DIR/gcp-agent.md" \
    "infrastructure" "mid-tier" \
    "Google Cloud architecture, service selection, infrastructure setup" \
    "GCP deployments, service configuration, cloud architecture on GCP" \
    "1100"

add_frontmatter "$SUBAGENTS_DIR/devops-agent.md" \
    "devops" "mid-tier" \
    "CI/CD pipelines, infrastructure as code, deployment automation" \
    "Pipeline setup, IaC, Docker, Kubernetes, deployment workflows" \
    "1100"

add_frontmatter "$SUBAGENTS_DIR/migration-agent.md" \
    "migration" "mid-tier" \
    "Plan and execute data migrations, schema changes, system upgrades" \
    "Database migrations, system upgrades, data transformation" \
    "900"

add_frontmatter "$SUBAGENTS_DIR/db-agent.md" \
    "database" "mid-tier" \
    "Database design, query optimization, migrations" \
    "Schema design, query performance, database selection, indexing" \
    "800"

# ── Design & Specialized Agents ──────────────────────────────
echo -e "${BLUE}Design & Specialized:${NC}"

add_frontmatter "$SUBAGENTS_DIR/api-design-agent.md" \
    "api-design" "mid-tier" \
    "Design RESTful APIs, GraphQL schemas, API contracts" \
    "API design, endpoint planning, schema definition, versioning" \
    "900"

add_frontmatter "$SUBAGENTS_DIR/design-agent.md" \
    "design" "mid-tier" \
    "Create UI/UX designs, wireframes, design system components" \
    "UI mockups, design systems, component libraries, visual design" \
    "700"

add_frontmatter "$SUBAGENTS_DIR/appstore-agent.md" \
    "app-store" "mid-tier" \
    "App Store and Play Store submission, compliance, optimization" \
    "App submissions, store compliance, ASO, review guidelines" \
    "900"

add_frontmatter "$SUBAGENTS_DIR/domain-agent.md" \
    "domain" "mid-tier" \
    "Design and validate business logic, game rules, domain models" \
    "Complex business rules, domain modeling, game mechanics" \
    "600"

echo ""
if $DRY_RUN; then
    echo -e "${YELLOW}DRY RUN: Would add frontmatter to $ADDED files ($SKIPPED skipped)${NC}"
else
    echo -e "${GREEN}Added frontmatter to $ADDED files ($SKIPPED already had it)${NC}"
fi
