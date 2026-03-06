#!/usr/bin/env bash
# Description: Agent should suggest ag specs for large brownfield projects with multiple domains
# Section: brownfield
# Category: Important
# Tests: LLM-044

# Setup with Formal profile
setup_test_project "formal"

# Create a discovery report with multiple domains (generic e-commerce example)
mkdir -p "$TEST_PROJECT/.agentic-state"
cat > "$TEST_PROJECT/.agentic/session/discovery_report.json" << 'EOF'
{
  "version": "2.0.0",
  "profile": "formal",
  "stack": {"language": "TypeScript", "framework": "Multi (Next.js, Express)"},
  "sub_projects": [
    {"name": "web", "path": "web/", "language": "TypeScript", "framework": "Next.js", "has_tests": true},
    {"name": "api", "path": "api/", "language": "TypeScript", "framework": "Express", "has_tests": true},
    {"name": "admin", "path": "admin/", "language": "TypeScript", "framework": "React", "has_tests": false}
  ],
  "domains": [
    {"name": "web", "type": "frontend", "sub_projects": ["web"], "clusters": ["checkout", "catalog"], "infra_paths": [], "estimated_features": 10},
    {"name": "api", "type": "backend", "sub_projects": ["api"], "clusters": ["orders", "users"], "infra_paths": [], "estimated_features": 8},
    {"name": "admin", "type": "frontend", "sub_projects": ["admin"], "clusters": ["reports"], "infra_paths": [], "estimated_features": 5}
  ],
  "feature_clusters": [
    {"name": "checkout", "frontend": ["web/src/pages/checkout/"], "backend": ["api/src/routes/checkout/"], "mobile": [], "confidence": "high"},
    {"name": "catalog", "frontend": ["web/src/pages/catalog/"], "backend": ["api/src/routes/products/"], "mobile": [], "confidence": "medium"},
    {"name": "orders", "frontend": [], "backend": ["api/src/routes/orders/"], "mobile": [], "confidence": "low"},
    {"name": "users", "frontend": [], "backend": ["api/src/routes/users/"], "mobile": [], "confidence": "low"},
    {"name": "reports", "frontend": ["admin/src/pages/reports/"], "backend": [], "mobile": [], "confidence": "low"}
  ],
  "infra_patterns": [
    {"type": "ci_cd", "path": ".github/workflows", "detail": "GitHub Actions"},
    {"type": "container", "path": "Dockerfile", "detail": "Docker"}
  ],
  "features": [],
  "entry_points": [],
  "architecture": {"top_level_dirs": [], "components": [], "is_monorepo": false, "monorepo_packages": []}
}
EOF

git -C "$TEST_PROJECT" add .agentic/session/discovery_report.json
git -C "$TEST_PROJECT" commit -m "Add discovery report" --quiet

# Ask about generating specs for this brownfield project
send_prompt "This is an existing codebase with web frontend, API backend, and admin panel. I need to generate feature specs and acceptance criteria for all of it. How should we approach this?"

# Verify agent behavior
FAILURES=0

# Agent should mention ag specs or systematic domain-by-domain approach
check_output_contains "ag specs\|domain\|systematic\|brownfield\|per.domain\|domain.by.domain" \
    "Agent mentions ag specs or domain-by-domain approach" || ((FAILURES++))

# Agent should reference the multiple domains/sub-projects
check_output_contains "web\|api\|admin\|sub.project\|3.*domain\|multiple.*domain" \
    "Agent references the multiple domains" || ((FAILURES++))

# Agent should NOT try to generate all specs inline at once
check_output_not_contains "here are all.*features\|generating all.*specs\|all 23 features" \
    "Agent does NOT try to generate everything at once" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
