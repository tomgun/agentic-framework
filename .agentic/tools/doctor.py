#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import subprocess
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


# === Verification State Tracking ===

VERIFICATION_STATE_FILE = ".agentic/.verification-state"


def get_git_state(root: Path) -> dict:
    """Get current git state for comparison."""
    try:
        # Get current commit hash
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            capture_output=True, text=True, cwd=root
        )
        commit = result.stdout.strip()[:8] if result.returncode == 0 else None

        # Count modified/untracked files
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            capture_output=True, text=True, cwd=root
        )
        lines = result.stdout.strip().splitlines() if result.returncode == 0 else []
        modified = len([l for l in lines if l.startswith((" M", "M ", "MM"))])
        untracked = len([l for l in lines if l.startswith("??")])

        return {"commit": commit, "modified": modified, "untracked": untracked}
    except Exception:
        return {"commit": None, "modified": 0, "untracked": 0}


def write_verification_state(root: Path, result: str, issues: int, suggestions: int, phase: str = None, detected_stack: str = None):
    """Write verification state after a run."""
    state_path = root / VERIFICATION_STATE_FILE
    state_path.parent.mkdir(parents=True, exist_ok=True)

    git_state = get_git_state(root)

    state = {
        "last_run": datetime.now().isoformat(),
        "result": result,  # "pass", "issues", "fail"
        "issues_count": issues,
        "suggestions_count": suggestions,
        "phase": phase,
        "detected_stack": detected_stack,
        "git_commit": git_state["commit"],
        "git_modified": git_state["modified"],
        "git_untracked": git_state["untracked"],
    }

    try:
        state_path.write_text(json.dumps(state, indent=2))
    except Exception:
        pass  # Don't fail verification if we can't write state


def read_verification_state(root: Path) -> dict | None:
    """Read previous verification state."""
    state_path = root / VERIFICATION_STATE_FILE
    if not state_path.exists():
        return None

    try:
        return json.loads(state_path.read_text())
    except Exception:
        return None


# === Tech Stack Detection and Profile Matching ===

# Stack profiles for detection - agents are suggested dynamically, not hardcoded
STACK_PROFILES = {
    "webapp_fullstack": {
        "keywords": ["react", "vue", "svelte", "next", "nuxt", "angular", "express", "fastapi", "django", "rails", "laravel"],
        "languages": ["javascript", "typescript", "python", "ruby", "php"],
        "has_ui": True,
        "hooks": ["PostToolUse (lint on save)", "PreCompact (preserve state)"],
    },
    "ml_python": {
        "keywords": ["pytorch", "tensorflow", "keras", "scikit", "pandas", "numpy", "jupyter", "mlflow", "wandb", "huggingface"],
        "languages": ["python"],
        "has_ui": False,
        "hooks": ["PostToolUse (notebook checkpoints)", "PreCompact (save experiment state)"],
    },
    "mobile_ios": {
        "keywords": ["swift", "swiftui", "uikit", "xcode", "cocoapods", "spm"],
        "languages": ["swift"],
        "has_ui": True,
        "hooks": ["PostToolUse (build check)"],
    },
    "mobile_react_native": {
        "keywords": ["react native", "expo", "react-native"],
        "languages": ["javascript", "typescript"],
        "has_ui": True,
        "hooks": ["PostToolUse (Metro bundler check)"],
    },
    "backend_api": {
        "keywords": ["gin", "echo", "fiber", "chi", "grpc", "api", "rest", "graphql", "microservice"],
        "languages": ["go", "golang", "python", "java", "kotlin"],
        "has_ui": False,
        "hooks": ["PostToolUse (build/lint check)"],
    },
    "cloud_infra": {
        "keywords": ["aws", "gcp", "azure", "terraform", "pulumi", "kubernetes", "k8s", "docker", "helm", "devops"],
        "languages": ["hcl", "yaml", "python", "go"],
        "has_ui": False,
        "hooks": ["PostToolUse (terraform validate/plan)"],
    },
    "data_engineering": {
        "keywords": ["spark", "airflow", "dbt", "snowflake", "bigquery", "redshift", "kafka", "etl", "data pipeline"],
        "languages": ["python", "sql", "scala"],
        "has_ui": False,
        "hooks": ["PostToolUse (dbt compile/test)"],
    },
    "cli_tool": {
        "keywords": ["cli", "command line", "terminal", "argparse", "clap", "cobra", "click"],
        "languages": ["python", "go", "rust", "bash"],
        "has_ui": False,
        "hooks": ["PostToolUse (build check)"],
    },
    "systems_rust": {
        "keywords": ["tokio", "actix", "axum", "cargo", "embedded", "systems"],
        "languages": ["rust"],
        "has_ui": False,
        "hooks": ["PostToolUse (cargo check)"],
    },
    "audio_dsp": {
        "keywords": ["juce", "vst", "au", "audio", "dsp", "plugin", "synthesizer"],
        "languages": ["c++", "cpp", "rust"],
        "has_ui": True,
        "hooks": ["PostToolUse (build check)"],
    },
    "game": {
        "keywords": ["godot", "unity", "unreal", "gamedev", "game", "bevy"],
        "languages": ["gdscript", "c#", "c++", "cpp", "rust"],
        "has_ui": True,
        "hooks": ["PostToolUse (build check)"],
    },
}


def parse_stack_info(root: Path) -> dict:
    """Parse STACK.md for tech stack information."""
    stack_path = root / "STACK.md"
    if not stack_path.exists():
        return {}

    try:
        content = stack_path.read_text(encoding="utf-8").lower()
    except Exception:
        return {}

    info = {
        "language": None,
        "framework": None,
        "platform": None,
        "keywords_found": [],
    }

    # Look for explicit declarations
    import re

    lang_match = re.search(r"(?:language|lang):\s*(\w+)", content)
    if lang_match:
        info["language"] = lang_match.group(1)

    framework_match = re.search(r"framework:\s*(\w+)", content)
    if framework_match:
        info["framework"] = framework_match.group(1)

    platform_match = re.search(r"platform:\s*(\w+)", content)
    if platform_match:
        info["platform"] = platform_match.group(1)

    # Find keywords from all profiles
    for profile_name, profile_data in STACK_PROFILES.items():
        for keyword in profile_data["keywords"]:
            if keyword.lower() in content:
                info["keywords_found"].append(keyword)

    return info


def match_stack_profile(stack_info: dict) -> str | None:
    """Match stack info to a profile."""
    if not stack_info:
        return None

    keywords = set(k.lower() for k in stack_info.get("keywords_found", []))
    language = (stack_info.get("language") or "").lower()

    best_match = None
    best_score = 0

    for profile_name, profile_data in STACK_PROFILES.items():
        score = 0

        # Check language match
        for lang in profile_data["languages"]:
            if lang in language:
                score += 2

        # Check keyword matches
        for keyword in profile_data["keywords"]:
            if keyword.lower() in keywords:
                score += 1

        if score > best_score:
            best_score = score
            best_match = profile_name

    return best_match if best_score >= 1 else None


def check_agent_analysis_done(root: Path) -> bool:
    """Check if agent analysis has been run for this project."""
    analysis_file = root / ".agentic" / "project-agents.md"
    return analysis_file.exists()


def get_stack_suggestions(root: Path) -> tuple[str | None, list[str]]:
    """Get tech-stack-specific suggestions."""
    stack_info = parse_stack_info(root)
    profile_name = match_stack_profile(stack_info)

    if not profile_name:
        return None, []

    profile = STACK_PROFILES.get(profile_name, {})
    suggestions = []

    # Check if hooks are enabled
    hooks_path = root / ".claude" / "hooks.json"
    if not hooks_path.exists():
        hook_suggestions = profile.get("hooks", [])
        if hook_suggestions:
            suggestions.append(f"Stack '{profile_name}': Enable Claude hooks for: {', '.join(hook_suggestions)}")
            suggestions.append("  → Run: mkdir -p .claude && cp .agentic/claude-hooks/hooks.json .claude/")

    # Suggest agent analysis (dynamic, not hardcoded)
    if not check_agent_analysis_done(root):
        suggestions.append(f"Stack '{profile_name}': Run agent analysis to discover useful domain experts")
        suggestions.append("  → Tell agent: 'Analyze this project and suggest specialized subagents'")
        suggestions.append("  → See .agentic/agents/roles/ for examples (scientific-research, architecture, cloud-expert)")

    return profile_name, suggestions


def check_verification_needed(root: Path) -> list[str]:
    """Check if verification should be run again."""
    suggestions = []
    state = read_verification_state(root)

    if state is None:
        suggestions.append("No verification record found. Run doctor.sh --full to establish baseline.")
        return suggestions

    # Check time since last verification
    try:
        last_run = datetime.fromisoformat(state["last_run"])
        hours_ago = (datetime.now() - last_run).total_seconds() / 3600

        if hours_ago > 4:
            suggestions.append(f"Last verification was {hours_ago:.1f} hours ago. Consider running /verify.")
        elif hours_ago > 2:
            # Only suggest if there are also file changes
            pass
    except Exception:
        pass

    # Check if files changed since last verification
    current_git = get_git_state(root)

    if state.get("git_commit") and current_git.get("commit"):
        if state["git_commit"] != current_git["commit"]:
            suggestions.append("Commits made since last verification. Consider running /verify.")

    files_changed = current_git.get("modified", 0) - state.get("git_modified", 0)
    if files_changed > 5:
        suggestions.append(f"{files_changed} more files modified since last verification.")

    # Check if last run had issues
    if state.get("result") == "issues" and state.get("issues_count", 0) > 0:
        suggestions.append(f"Last verification had {state['issues_count']} issue(s). Were they fixed?")

    return suggestions


@dataclass
class Check:
    path: str
    kind: str  # "file" | "dir"
    purpose: str


def read_profile(root: Path) -> str:
    """
    Determine profile.

    - Prefer explicit `Profile:` in STACK.md.
    - If not present, infer:
      - If spec/ exists -> core+product
      - else -> core
    """
    stack = root / "STACK.md"
    if stack.exists():
        try:
            md = stack.read_text(encoding="utf-8")
            m = re.search(r"(?m)^\s*-\s*Profile:\s*([a-z+_-]+)\s*$", md)
            if m:
                val = m.group(1).strip()
                if val in {"core", "core+product"}:
                    return val
        except Exception:
            pass

    if (root / "spec").is_dir():
        return "core+product"
    return "core"


def checks_for_profile(profile: str) -> list[Check]:
    core = [
        Check("AGENTS.md", "file", "agent entrypoint (rules + read-first)"),
        Check("CONTEXT_PACK.md", "file", "durable starting context"),
        Check("STATUS.md", "file", "current focus + next steps"),
        Check("STACK.md", "file", "how to run/test + constraints"),
        Check("JOURNAL.md", "file", "session-by-session progress log"),
        Check("HUMAN_NEEDED.md", "file", "escalation protocol"),
        Check("docs", "dir", "system docs (long-lived)"),
    ]
    if profile == "core":
        return core

    # core+product
    return core + [
        Check("spec", "dir", "project truth folder"),
        Check("spec/OVERVIEW.md", "file", "vision + current state + pointers"),
        Check("spec/FEATURES.md", "file", "feature registry + acceptance + tests"),
        Check("spec/NFR.md", "file", "non-functional constraints"),
        Check("spec/acceptance", "dir", "per-feature acceptance criteria"),
        Check("spec/LESSONS.md", "file", "lessons/caveats"),
        Check("spec/adr", "dir", "architecture decisions"),
    ]

FEATURE_ID_RE = re.compile(r"\b(F-\d{4})\b")
NFR_ID_RE = re.compile(r"\b(NFR-\d{4})\b")
FEATURE_HEADER_RE = re.compile(r"^##\s+(F-\d{4}):\s*(.+?)\s*$", re.MULTILINE)
STATUS_VALUES = {"planned", "in_progress", "shipped", "deprecated"}


def looks_like_template(text: str) -> bool:
    first_lines = "\n".join(text.splitlines()[:3]).lower()
    return "(template)" in first_lines or first_lines.strip().endswith("template")


def validate_stack_config(root: Path) -> tuple[list[str], list[str]]:
    """
    Validate STACK.md has essential configuration.
    Returns (issues, suggestions) - issues are problems, suggestions are recommendations.
    """
    issues = []
    suggestions = []
    stack_path = root / "STACK.md"

    if not stack_path.exists():
        return issues, suggestions

    try:
        content = stack_path.read_text(encoding="utf-8").lower()
    except Exception:
        return issues, suggestions

    # Check for test command (strongly suggested)
    test_patterns = ["test:", "test command:", "run tests:", "- test:"]
    has_test = any(p in content for p in test_patterns)
    if not has_test:
        suggestions.append("STACK.md: No test command found. Add '- Test: <command>' for test-driven development")

    # Check for build command (suggested)
    build_patterns = ["build:", "build command:", "- build:"]
    has_build = any(p in content for p in build_patterns)
    if not has_build:
        suggestions.append("STACK.md: No build command found. Add '- Build: <command>' if applicable")

    # Check for development mode (suggested for clarity)
    if "development_mode:" not in content:
        suggestions.append("STACK.md: Consider adding '- development_mode: tdd' or '- development_mode: standard'")

    return issues, suggestions


def validate_quality_setup(root: Path) -> list[str]:
    """Check if quality checks are configured."""
    suggestions = []

    # Check for quality_checks.sh
    quality_script = root / "quality_checks.sh"
    if not quality_script.exists():
        suggestions.append("No quality_checks.sh found. Consider creating stack-specific quality checks")

    return suggestions


def validate_optional_enhancements(root: Path, profile: str) -> list[str]:
    """
    Check for optional but recommended files.
    These are suggestions, not requirements.
    """
    suggestions = []

    # STATUS.md is required for both profiles (v0.12.0+)
    status_path = root / "STATUS.md"
    if status_path.exists():
        try:
            content = status_path.read_text(encoding="utf-8")
            if len(content.strip()) == 0:
                suggestions.append("STATUS.md exists but is empty. Fill in current focus and project phase")
        except Exception:
            pass
    else:
        suggestions.append("STATUS.md is missing. Run: cp .agentic/init/STATUS.template.md STATUS.md")

    return suggestions


def parse_features(md: str) -> dict[str, dict]:
    """Parse FEATURES.md and return dict of feature_id -> metadata."""
    features = {}
    current = None
    
    for line in md.splitlines():
        m = FEATURE_HEADER_RE.match(line)
        if m:
            if current:
                features[current["id"]] = current
            current = {
                "id": m.group(1),
                "name": m.group(2),
                "status": None,
                "acceptance": None,
                "state": None,
                "accepted": None,
                "nfrs": [],
            }
            continue
        
        if not current:
            continue
        
        # Parse key-value lines
        if line.strip().startswith("- Status:"):
            val = line.split(":", 1)[1].strip()
            current["status"] = val
        elif line.strip().startswith("- Acceptance:"):
            val = line.split(":", 1)[1].strip()
            current["acceptance"] = val
        elif line.strip().startswith("- State:"):
            val = line.split(":", 1)[1].strip()
            current["state"] = val
        elif line.strip().startswith("- Accepted:"):
            val = line.split(":", 1)[1].strip()
            current["accepted"] = val
        elif line.strip().startswith("- NFRs:"):
            val = line.split(":", 1)[1].strip()
            if val and val.lower() not in {"none", "n/a"}:
                current["nfrs"] = NFR_ID_RE.findall(val)
    
    if current:
        features[current["id"]] = current
    
    return features


def parse_nfr_ids(md: str) -> set[str]:
    """Parse NFR.md and return set of NFR IDs."""
    nfr_header_re = re.compile(r"^##\s+(NFR-\d{4}):", re.MULTILINE)
    return set(nfr_header_re.findall(md))


def validate_features(root: Path) -> list[str]:
    """Validate FEATURES.md structure and cross-references."""
    issues = []
    features_path = root / "spec" / "FEATURES.md"
    
    if not features_path.exists():
        return ["spec/FEATURES.md does not exist"]
    
    try:
        features_md = features_path.read_text(encoding="utf-8")
    except Exception as e:
        return [f"Could not read spec/FEATURES.md: {e}"]
    
    features = parse_features(features_md)
    
    if not features:
        issues.append("No features found in spec/FEATURES.md")
        return issues
    
    # Check acceptance files
    acceptance_dir = root / "spec" / "acceptance"
    for fid, meta in features.items():
        if meta["status"] in {"deprecated"}:
            continue
        
        # Check acceptance file exists
        acceptance_file = acceptance_dir / f"{fid}.md"
        acc_val = (meta.get("acceptance") or "").strip()
        if acc_val and not acc_val.lower() in {"todo", "tbd", "none", "n/a"}:
            if not acceptance_file.exists():
                issues.append(f"{fid}: acceptance file spec/acceptance/{fid}.md not found")
        
        # Check status validity
        status = (meta.get("status") or "").strip().lower()
        if status and status not in STATUS_VALUES:
            issues.append(f"{fid}: invalid status '{status}' (expected: {', '.join(STATUS_VALUES)})")

        # Check for inconsistencies
        if status == "shipped" and meta.get("accepted") != "yes":
            issues.append(f"{fid}: status is 'shipped' but Accepted is not 'yes'")

        state = (meta.get("state") or "").strip().lower()
        if state == "complete" and "todo" in str(meta).lower():
            # Check if any test fields say "todo"
            if "Tests:" in features_md:
                # Simple heuristic check
                issues.append(f"{fid}: state is 'complete' but some tests may be marked 'todo'")
    
    return issues


def validate_status_refs(root: Path, features: set[str]) -> list[str]:
    """Validate that STATUS.md references valid feature IDs."""
    issues = []
    status_path = root / "STATUS.md"
    
    if not status_path.exists():
        return []
    
    try:
        status_md = status_path.read_text(encoding="utf-8")
    except Exception:
        return []
    
    referenced_features = set(FEATURE_ID_RE.findall(status_md))
    
    for fid in referenced_features:
        if fid not in features:
            issues.append(f"STATUS.md references {fid} but it doesn't exist in spec/FEATURES.md")
    
    return issues


def validate_nfr_refs(root: Path) -> list[str]:
    """Validate NFR cross-references."""
    issues = []
    
    nfr_path = root / "spec" / "NFR.md"
    if not nfr_path.exists():
        return []
    
    try:
        nfr_md = nfr_path.read_text(encoding="utf-8")
    except Exception:
        return []
    
    nfr_ids = parse_nfr_ids(nfr_md)
    
    # Check if FEATURES.md references non-existent NFRs
    features_path = root / "spec" / "FEATURES.md"
    if features_path.exists():
        try:
            features_md = features_path.read_text(encoding="utf-8")
            features = parse_features(features_md)
            
            for fid, meta in features.items():
                for nfr_id in meta.get("nfrs", []):
                    if nfr_id not in nfr_ids:
                        issues.append(f"{fid} references {nfr_id} but it doesn't exist in spec/NFR.md")
        except Exception:
            pass
    
    return issues


def run_phase_checks(root: Path, profile: str, phase: str, feature_id: str = None) -> list[str]:
    """Run phase-specific checks."""
    issues = []

    if phase == "start":
        # Check WIP exists (interrupted work?)
        if (root / ".agentic" / "WIP.md").exists():
            issues.append(".agentic/WIP.md exists - previous work was interrupted. Review or complete it.")
        # Context files checked by main doctor flow

    elif phase == "planning":
        # Must have acceptance criteria before implementing
        if feature_id:
            acc_file = root / "spec" / "acceptance" / f"{feature_id}.md"
            if not acc_file.exists():
                issues.append(f"No acceptance criteria: spec/acceptance/{feature_id}.md required before implementing")
        else:
            issues.append("No feature ID provided. Use: doctor.sh --phase planning F-0001")

    elif phase == "implement":
        # Should have acceptance + WIP tracking
        if feature_id:
            acc_file = root / "spec" / "acceptance" / f"{feature_id}.md"
            if not acc_file.exists():
                issues.append(f"Missing acceptance criteria for {feature_id}")
            if not (root / ".agentic" / "WIP.md").exists():
                issues.append("No .agentic/WIP.md - start tracking with: wip.sh start " + (feature_id or "FEATURE"))

    elif phase == "complete":
        # Tests should pass, FEATURES.md updated
        if feature_id and profile == "core+product":
            features_path = root / "spec" / "FEATURES.md"
            if features_path.exists():
                content = features_path.read_text()
                if f"## {feature_id}:" in content:
                    # Check status is shipped or being shipped
                    if f"- Status: planned" in content[content.find(f"## {feature_id}:"):]:
                        issues.append(f"{feature_id} still marked 'planned' - update to 'shipped'")

    elif phase == "commit":
        # Delegate to pre-commit checks
        return run_pre_commit_checks(root, profile)

    return issues


def run_pre_commit_checks(root: Path, profile: str) -> list[str]:
    """Fast checks for pre-commit hook."""
    issues = []

    # 1. .agentic/WIP.md must not exist (work should be complete before commit)
    if (root / ".agentic" / "WIP.md").exists():
        issues.append(".agentic/WIP.md exists - complete or remove work-in-progress before committing")

    # 2. Check for untracked files in key directories
    import subprocess
    try:
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            capture_output=True, text=True, cwd=root
        )
        untracked = [l[3:] for l in result.stdout.splitlines() if l.startswith("??")]
        key_untracked = [f for f in untracked if f.startswith(("src/", "spec/", "tests/", "docs/"))]
        if key_untracked:
            issues.append(f"Untracked files in project dirs: {', '.join(key_untracked[:3])}...")
    except Exception:
        pass

    # 3. For core+product: shipped features need acceptance
    if profile == "core+product":
        features_path = root / "spec" / "FEATURES.md"
        if features_path.exists():
            try:
                content = features_path.read_text()
                # Quick check: any shipped without acceptance file?
                for match in FEATURE_HEADER_RE.finditer(content):
                    fid = match.group(1)
                    acc_file = root / "spec" / "acceptance" / f"{fid}.md"
                    if not acc_file.exists():
                        # Check if shipped
                        if f"- Status: shipped" in content[match.end():match.end()+200]:
                            issues.append(f"{fid} is shipped but missing acceptance file")
            except Exception:
                pass

    return issues


def main() -> int:
    parser = argparse.ArgumentParser(description="Agentic Framework health check")
    parser.add_argument('--full', action='store_true', help='Run full verification (includes verify.py checks)')
    parser.add_argument('--phase', type=str, choices=['start', 'planning', 'implement', 'complete', 'commit'],
                        help='Run phase-specific checks')
    parser.add_argument('--pre-commit', action='store_true', help='Run pre-commit checks')
    parser.add_argument('--quick', action='store_true', help='Quick health check (default)')
    parser.add_argument('feature_id', nargs='?', help='Feature ID (e.g., F-0001) for phase checks')
    args = parser.parse_args()

    root = Path.cwd()
    profile = read_profile(root)
    detected_stack = None  # Will be set if stack detection runs

    # Handle --phase mode (context-aware checks)
    if args.phase:
        print(f"=== Phase: {args.phase} ===")
        issues = run_phase_checks(root, profile, args.phase, args.feature_id)
        if issues:
            print("Issues:")
            for issue in issues:
                print(f"  - {issue}")
            return 1
        print(f"✓ Phase '{args.phase}' checks passed")
        return 0

    # Handle --pre-commit mode (fast, for git hooks)
    if args.pre_commit:
        print("=== Pre-commit checks ===")
        issues = run_pre_commit_checks(root, profile)
        if issues:
            print("BLOCKED:")
            for issue in issues:
                print(f"  - {issue}")
            return 1
        print("✓ Pre-commit checks passed")
        return 0

    missing: list[Check] = []
    empty_files: list[Check] = []
    template_like: list[Check] = []

    checks = checks_for_profile(profile)
    for c in checks:
        p = root / c.path
        if c.kind == "dir":
            if not p.is_dir():
                missing.append(c)
            continue

        # file
        if not p.is_file():
            missing.append(c)
            continue

        try:
            data = p.read_text(encoding="utf-8")
        except Exception:
            data = ""

        if len(data.strip()) == 0:
            empty_files.append(c)
        elif looks_like_template(data) and p.name not in {"FEATURES.md"}:
            template_like.append(c)

    print("=== agentic doctor ===")
    print(f"\nProfile: {profile}")

    # Check if re-verification is needed (based on previous state)
    reverify_suggestions = check_verification_needed(root)
    if reverify_suggestions and not args.full:
        print("\nVerification status:")
        for s in reverify_suggestions:
            print(f"  - {s}")

    if missing:
        print("\nMissing (run scaffold):")
        for c in missing:
            print(f"- {c.path} ({c.purpose})")

    if empty_files:
        print("\nEmpty (fill in):")
        for c in empty_files:
            print(f"- {c.path} ({c.purpose})")

    if template_like:
        print("\nLooks like template content (consider filling/renaming):")
        for c in template_like:
            print(f"- {c.path} ({c.purpose})")

    # === Validations for BOTH profiles ===
    validation_issues = []
    suggestions = []

    # STACK.md configuration validation
    stack_issues, stack_suggestions = validate_stack_config(root)
    validation_issues.extend(stack_issues)
    suggestions.extend(stack_suggestions)

    # Quality setup check
    quality_suggestions = validate_quality_setup(root)
    suggestions.extend(quality_suggestions)

    # Optional enhancements
    optional_suggestions = validate_optional_enhancements(root, profile)
    suggestions.extend(optional_suggestions)

    # Tech-stack-specific suggestions (hooks, subagents, quality)
    detected_stack, stack_suggestions = get_stack_suggestions(root)
    if detected_stack:
        print(f"\nDetected stack: {detected_stack}")
    if stack_suggestions:
        suggestions.extend(stack_suggestions)

    # === Profile-specific validations ===
    if profile == "core+product":
        features_issues = validate_features(root)
        validation_issues.extend(features_issues)

        # Get feature IDs for cross-reference checks
        features_path = root / "spec" / "FEATURES.md"
        if features_path.exists():
            try:
                features_md = features_path.read_text(encoding="utf-8")
                features = parse_features(features_md)
                feature_ids = set(features.keys())

                status_issues = validate_status_refs(root, feature_ids)
                validation_issues.extend(status_issues)
            except Exception:
                pass

        nfr_issues = validate_nfr_refs(root)
        validation_issues.extend(nfr_issues)
    else:
        print("\nNote: Core profile — formal PM validations (spec/FEATURES.md, acceptance files) skipped.")

    if validation_issues:
        print("\nValidation issues:")
        for issue in validation_issues:
            print(f"- {issue}")

    if suggestions:
        print("\nSuggestions:")
        for suggestion in suggestions:
            print(f"- {suggestion}")

    has_issues = missing or empty_files or template_like or validation_issues
    has_suggestions = bool(suggestions)

    if not has_issues and not has_suggestions:
        print("\n✓ All checks passed - project artifacts present and valid")
    elif not has_issues and has_suggestions:
        print("\n✓ Core checks passed (suggestions above are optional improvements)")

    # Mode-specific output
    if args.full:
        print("\n=== Full Verification Mode ===")
        if not has_issues:
            print("✓ All required checks passed")
            if has_suggestions:
                print(f"  ({len(suggestions)} optional suggestion(s) above)")
        else:
            issue_count = len(missing) + len(empty_files) + len(template_like) + len(validation_issues)
            print(f"Found {issue_count} issue(s) to fix")
    else:
        print("\nNext commands:")
        print("- bash .agentic/tools/brief.sh")
        if profile == "core+product":
            print("- bash .agentic/tools/report.sh")
        print("- bash .agentic/tools/doctor.sh --full  # comprehensive check")

    # Write verification state for tracking
    issue_count = len(missing) + len(empty_files) + len(template_like) + len(validation_issues)
    result = "pass" if issue_count == 0 else "issues"
    write_verification_state(root, result, issue_count, len(suggestions), phase=args.phase, detected_stack=detected_stack)

    # Return non-zero only for actual issues (not suggestions)
    if missing or validation_issues:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
