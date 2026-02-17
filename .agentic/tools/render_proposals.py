#!/usr/bin/env python3
"""
render_proposals.py - Render discovery results into proposal-enhanced state files.

Takes discovery_report.json + template paths, and renders populated state files
to .agentic-state/proposals/ with PROPOSAL markers for human review.
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

# Import shared settings library
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "lib"))
from settings import get_setting

PROPOSAL_HEADER = (
    "<!-- PROPOSAL: Auto-discovered by ag init on {date}. "
    "Review and approve with: ag approve-onboarding -->"
)


def confidence_marker(level: str) -> str:
    return f"<!-- confidence: {level} -->"


def render_stack_md(report: dict, template_path: Path) -> str:
    """Render STACK.md with discovered stack info."""
    stack = report.get("stack", {})
    test_patterns = report.get("test_patterns", {})
    date = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    language = stack.get("language", "<!-- fill -->")
    framework = stack.get("framework", "")
    runtime = stack.get("runtime", "<!-- fill -->")
    pm = stack.get("package_manager", "<!-- fill -->")
    test_fw = stack.get("test_framework", "<!-- fill -->")
    test_cmd = test_patterns.get("test_command", "<!-- fill -->")
    readme_desc = report.get("readme_description", "<!-- 1-2 sentences -->")
    confidence = stack.get("confidence", {})

    lines = [
        PROPOSAL_HEADER.format(date=date),
        "",
        "# STACK.md",
        "",
        "<!-- format: stack-v0.1.0 -->",
        "",
        "Purpose: a single source of truth for \"how we build and run software here\".",
        "",
        "## Agentic framework",
        "- Version: 0.23.0",
        f"- Profile: {report.get('profile', 'discovery')}",
        f"- Installed: {date}",
        "- Source: https://github.com/tomgun/agentic-framework",
        "",
        "## Summary",
        f"- What are we building: {readme_desc} {confidence_marker(confidence.get('language', 'medium'))}",
        "- Primary platform: <!-- web/service/mobile/desktop/cli -->",
        "",
        "## Languages & runtimes",
        f"- Language(s): {language} {confidence_marker(confidence.get('language', 'medium'))}",
        f"- Runtime(s): {runtime}",
        "",
        "## Frameworks & libraries",
    ]

    if framework:
        lines.append(f"- App framework: {framework} {confidence_marker(confidence.get('framework', 'medium'))}")
    else:
        lines.append("- App framework: <!-- fill -->")

    lines.extend([
        "",
        "## Tooling",
        f"- Package manager: {pm} {confidence_marker(confidence.get('package_manager', 'medium'))}",
        "- Formatting/linting: <!-- fill -->",
        "",
        "## License",
        "- **Project License**: <!-- fill -->",
        "",
        "---",
        "",
        "## Testing (required)",
        f"- Unit test framework: {test_fw}",
        "- Test commands:",
    ])

    if test_cmd and test_cmd != "<!-- fill -->":
        lines.append(f"  - Unit: `{test_cmd}`")
    else:
        lines.append("  - Unit: `<!-- fill -->`")

    lines.extend([
        "  - Integration: `<!-- fill or N/A -->`",
        "",
        "## Development approach (optional)",
        "- development_mode: standard",
        "",
        "## Agent mode (quality vs cost tradeoff)",
        "- agent_mode: balanced",
        "",
        "## Git workflow (required)",
        "- git_workflow: pull_request",
        "",
        "## Data & integrations",
        "- Primary datastore: <!-- fill -->",
        "",
        "## Deployment",
        "- Target environment: <!-- fill -->",
        "",
        "## Constraints & non-negotiables",
        "- Security/compliance: <!-- fill -->",
        "",
    ])

    return "\n".join(lines)


def render_context_pack_md(report: dict) -> str:
    """Render CONTEXT_PACK.md with architecture snapshot."""
    date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    architecture = report.get("architecture", {})
    entry_points = report.get("entry_points", [])
    readme_desc = report.get("readme_description", "<!-- 1-2 sentences -->")
    components = architecture.get("components", [])

    lines = [
        PROPOSAL_HEADER.format(date=date),
        "",
        "# CONTEXT_PACK.md",
        "",
        "Purpose: a compact, durable starting point for any agent/human so they don't need to reread the whole repo.",
        "",
        "## One-minute overview",
        f"- What this repo is: {readme_desc}",
        "- Main user workflow: <!-- 1-3 bullets -->",
        "- Current top priorities: <!-- 1-5 bullets -->",
        "",
        "## Where to look first (map)",
    ]

    # Entry points
    if entry_points:
        ep_paths = [ep["path"] for ep in entry_points[:5]]
        lines.append(f"- Entry points: {', '.join(ep_paths)}")
    else:
        lines.append("- Entry points: <!-- fill -->")

    # Core modules
    if components:
        lines.append("- Core modules:")
        for comp in components[:8]:
            lines.append(f"  - `{comp['path']}` - {comp['label']} {confidence_marker(comp.get('confidence', 'medium'))}")
    else:
        lines.append("- Core modules: <!-- fill -->")

    lines.extend([
        "",
        "## How to run",
        "- Setup: `<!-- fill -->`",
        "- Run: `<!-- fill -->`",
        "- Test: `<!-- fill -->`",
        "",
        "## Architecture snapshot",
    ])

    # Top-level directory structure
    top_dirs = architecture.get("top_level_dirs", [])
    if top_dirs:
        lines.append("- Directory structure:")
        for d in top_dirs[:10]:
            lines.append(f"  - `{d['name']}/` ({d['file_count']} files)")
    if architecture.get("is_monorepo"):
        lines.append("- **Monorepo** detected:")
        for pkg in architecture.get("monorepo_packages", [])[:8]:
            lines.append(f"  - `{pkg['path']}/`")

    lines.extend([
        "",
        "## Known risks / sharp edges",
        "- <!-- fill -->",
        "",
    ])

    return "\n".join(lines)


def render_overview_md(report: dict) -> str:
    """Render OVERVIEW.md with project description."""
    date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    readme_desc = report.get("readme_description")

    lines = [
        PROPOSAL_HEADER.format(date=date),
        "",
        "# OVERVIEW.md",
        "",
        "## What We're Building",
        "",
    ]

    if readme_desc:
        lines.append(f"{readme_desc}")
    else:
        lines.append("<!-- Fill in: 1-3 paragraphs describing the product/project vision -->")

    lines.extend([
        "",
        "## Why It Matters",
        "",
        "<!-- Problem we're solving, who it's for, what pain point we address -->",
        "",
        "## Core Capabilities",
        "",
        "<!-- Use checkboxes for high-level capability tracking -->",
        "- [ ] ...",
        "",
        "## In Scope / Out of Scope",
        "",
        "**In scope:**",
        "-",
        "",
        "**Out of scope (for now):**",
        "-",
        "",
        "## Success Looks Like",
        "",
        "<!-- What 'done' means - outcomes, not tasks -->",
        "",
        "## Guiding Principles",
        "",
        "<!-- Key decisions/constraints that shape implementation -->",
        "-",
        "",
    ])

    return "\n".join(lines)


def _build_cluster_domain_map(report: dict) -> dict[str, str]:
    """Build a mapping from cluster name to domain type."""
    domain_map: dict[str, str] = {}
    for domain in report.get("domains", []):
        for cluster_name in domain.get("clusters", []):
            domain_map[cluster_name] = domain.get("type", "shared")
    return domain_map


def render_features_md(report: dict) -> str:
    """Render FEATURES.md with discovered features (Formal only)."""
    date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    feature_clusters = report.get("feature_clusters", [])
    features = report.get("features", [])
    domains = report.get("domains", [])
    cluster_domain_map = _build_cluster_domain_map(report)

    # For flat features, derive domain from the first domain's type
    default_domain = domains[0]["type"] if domains else None

    lines = [
        PROPOSAL_HEADER.format(date=date),
        "",
        "# FEATURES.md",
        "",
        "<!-- format: features-v0.1.0 -->",
        "",
        "Feature registry. Each feature has a unique ID (F-####), status, and acceptance criteria.",
        "",
        "---",
        "",
    ]

    if feature_clusters:
        # Use clusters for richer output with file evidence
        for i, cluster in enumerate(feature_clusters, start=1):
            fid = f"F-{i:04d}"
            name = cluster["name"].replace("_", " ").title()
            domain_type = cluster_domain_map.get(cluster["name"])
            lines.extend([
                f"## {fid}: {name}",
                f"- Status: shipped {confidence_marker(cluster.get('confidence', 'medium'))}",
            ])
            if domain_type:
                lines.append(f"- Domain: {domain_type}")
            lines.extend([
                f"- Acceptance: spec/acceptance/{fid}.md",
                f"- State: complete",
                f"- Accepted: no  <!-- Needs human verification -->",
                f"- Type: {cluster.get('type_hint', 'user-facing')}",
            ])
            if cluster.get("frontend"):
                lines.append(f"- Frontend: {', '.join(cluster['frontend'])}")
            if cluster.get("backend"):
                lines.append(f"- Backend: {', '.join(cluster['backend'])}")
            if cluster.get("mobile"):
                lines.append(f"- Mobile: {', '.join(cluster['mobile'])}")
            lines.append(f"- Tests: {'yes' if cluster.get('has_tests') else 'none detected'}")
            lines.append("")
    elif features:
        # Fallback to flat features list
        for i, feat in enumerate(features, start=1):
            fid = f"F-{i:04d}"
            lines.extend([
                f"## {fid}: {feat['name']}",
                f"- Status: shipped {confidence_marker(feat.get('confidence', 'medium'))}",
            ])
            if default_domain:
                lines.append(f"- Domain: {default_domain}")
            lines.extend([
                f"- Acceptance: spec/acceptance/{fid}.md",
                f"- State: complete",
                f"- Accepted: no  <!-- Needs human verification -->",
                f"- Evidence: {feat.get('evidence', feat.get('description', ''))}",
                "",
            ])
    else:
        lines.extend([
            "## F-0001: <!-- First Feature -->",
            "- Status: planned",
            "- Acceptance: spec/acceptance/F-0001.md",
            "",
        ])

    return "\n".join(lines)


def render_acceptance_criteria(report: dict, output_dir: Path):
    """Render individual acceptance criteria files (Formal only)."""
    feature_clusters = report.get("feature_clusters", [])
    features = report.get("features", [])
    acc_dir = output_dir / "acceptance"
    acc_dir.mkdir(parents=True, exist_ok=True)
    date = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    if feature_clusters:
        for i, cluster in enumerate(feature_clusters, start=1):
            fid = f"F-{i:04d}"
            name = cluster["name"].replace("_", " ").title()
            lines = [
                PROPOSAL_HEADER.format(date=date),
                "",
                f"# {fid}: {name} - Acceptance Criteria",
                "",
            ]
            if cluster.get("frontend"):
                lines.append(f"**Frontend**: {', '.join(cluster['frontend'])}")
            if cluster.get("backend"):
                lines.append(f"**Backend**: {', '.join(cluster['backend'])}")
            if cluster.get("mobile"):
                lines.append(f"**Mobile**: {', '.join(cluster['mobile'])}")
            lines.append(f"**Tests**: {'detected' if cluster.get('has_tests') else 'none detected'}")
            lines.append(f"**Type**: {cluster.get('type_hint', 'user-facing')}")
            lines.extend([
                "",
                "## Acceptance Criteria",
                "",
                "> **TODO (agent)**: Read the source files listed above and generate 3-5 Given/When/Then",
                "> criteria based on what the UI shows, what API calls it makes, and what states exist",
                "> (loading, error, empty, data).",
                "",
                "- [ ] ...",
                "",
            ])
            (acc_dir / f"{fid}.md").write_text("\n".join(lines))
    else:
        for i, feat in enumerate(features, start=1):
            fid = f"F-{i:04d}"
            content = "\n".join([
                PROPOSAL_HEADER.format(date=date),
                "",
                f"# {fid}: {feat['name']} - Acceptance Criteria",
                "",
                f"**Feature**: {feat.get('description', feat['name'])}",
                f"**Status**: shipped (auto-discovered)",
                f"**Confidence**: {feat.get('confidence', 'medium')}",
                f"**Evidence**: {feat.get('evidence', 'code analysis')}",
                "",
                "---",
                "",
                "## Acceptance Criteria",
                "",
                "> **TODO (agent)**: Read the source files listed above and generate 3-5 Given/When/Then",
                "> criteria based on what the UI shows, what API calls it makes, and what states exist",
                "> (loading, error, empty, data).",
                "",
                f"- [ ] {feat['name']} is functional",
                "- [ ] ...",
                "",
            ])
            (acc_dir / f"{fid}.md").write_text(content)


def main():
    parser = argparse.ArgumentParser(description="Render discovery proposals")
    parser.add_argument("--report", type=str, required=True, help="Path to discovery_report.json")
    parser.add_argument("--templates", type=str, required=True, help="Path to template directory")
    parser.add_argument("--output", type=str, required=True, help="Output directory for proposals")
    parser.add_argument("--profile", type=str, default="discovery",
                        choices=["discovery", "formal"])
    args = parser.parse_args()

    report_path = Path(args.report)
    if not report_path.exists():
        print(f"ERROR: Report not found: {report_path}")
        raise SystemExit(1)

    report = json.loads(report_path.read_text())

    # Version check
    report_version = report.get("version", "1.0.0")
    if report_version != "2.0.0":
        print(f"  WARNING: Report version {report_version} doesn't match expected 2.0.0")
        print(f"  Some features may not render correctly. Re-run discover.py to update.")

    template_dir = Path(args.templates)
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Render core proposals
    stack_content = render_stack_md(report, template_dir / "STACK.template.md")
    (output_dir / "STACK.md").write_text(stack_content)
    print(f"  Rendered: STACK.md")

    context_content = render_context_pack_md(report)
    (output_dir / "CONTEXT_PACK.md").write_text(context_content)
    print(f"  Rendered: CONTEXT_PACK.md")

    overview_content = render_overview_md(report)
    (output_dir / "OVERVIEW.md").write_text(overview_content)
    print(f"  Rendered: OVERVIEW.md")

    profile = args.profile

    # Determine feature_tracking from settings (respects overrides)
    feature_tracking = get_setting(Path.cwd(), "feature_tracking", "no") == "yes"

    if feature_tracking:
        features_content = render_features_md(report)
        (output_dir / "FEATURES.md").write_text(features_content)
        cluster_count = len(report.get("feature_clusters", []))
        feature_count = len(report.get("features", []))
        count = cluster_count or feature_count
        print(f"  Rendered: FEATURES.md ({count} features)")

        if report.get("feature_clusters") or report.get("features"):
            render_acceptance_criteria(report, output_dir)
            print(f"  Rendered: {count} acceptance criteria files")


if __name__ == "__main__":
    main()
