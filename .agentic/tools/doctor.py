#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

# Import shared settings library
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "lib"))
from settings import get_setting

# NFR content validation (extracted to nfr_validator.py for complexity limits)
from nfr_validator import validate_nfr_content

# Optional YAML support (graceful fallback if not installed)
try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False


# === Verification State Tracking ===

# State lives at project root, NOT inside .agentic (survives framework upgrades)
VERIFICATION_STATE_FILE = ".agentic-state/.verification-state"


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


def checks_for_profile(profile: str, root: Path | None = None) -> list[Check]:
    # Determine JOURNAL.md location with fallback
    from pathlib import Path
    repo_root = root or Path.cwd()
    journal_path = repo_root / ".agentic-journal" / "JOURNAL.md"
    if not journal_path.exists():
        journal_path = repo_root / "JOURNAL.md"
    journal_relative = str(journal_path.relative_to(repo_root))

    core = [
        Check("AGENTS.md", "file", "agent entrypoint (rules + read-first)"),
        Check("CONTEXT_PACK.md", "file", "durable starting context"),
        Check("STATUS.md", "file", "current focus + next steps"),
        Check("STACK.md", "file", "how to run/test + constraints"),
        Check(journal_relative, "file", "session-by-session progress log"),
        Check("HUMAN_NEEDED.md", "file", "escalation protocol"),
        Check("docs", "dir", "system docs (long-lived)"),
    ]
    ft = get_setting(repo_root, "feature_tracking", "no")
    if ft != "yes":
        return core

    # feature tracking enabled: also check spec files
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


# === Acceptance File Frontmatter Parsing ===

def parse_acceptance_frontmatter(acceptance_path: Path) -> dict:
    """
    Extract structured frontmatter from acceptance file.

    Expected format:
    ---
    feature: F-0120
    status: shipped
    validation:
      - command: "pytest tests/test_feature.py -v"
        description: "Unit tests pass"
    ---
    """
    try:
        content = acceptance_path.read_text(encoding="utf-8")
    except Exception:
        return {}

    # Check for YAML frontmatter
    if not content.startswith('---'):
        return {}

    try:
        # Find end of frontmatter
        end = content.index('---', 3)
        frontmatter = content[3:end]

        if HAS_YAML:
            return yaml.safe_load(frontmatter) or {}
        else:
            # Fallback: regex-based parsing for critical fields
            result = {}
            feature_match = re.search(r'feature:\s*(\S+)', frontmatter)
            if feature_match:
                result['feature'] = feature_match.group(1)
            status_match = re.search(r'status:\s*(\S+)', frontmatter)
            if status_match:
                result['status'] = status_match.group(1)
            # Extract validation commands (simplified)
            if 'validation:' in frontmatter:
                commands = re.findall(r'command:\s*["\'](.+?)["\']', frontmatter)
                result['validation'] = [{'command': c} for c in commands]
            return result
    except (ValueError, Exception):
        return {}


def validate_acceptance_tests(root: Path, feature_id: str) -> list[str]:
    """Verify acceptance file has runnable validation commands."""
    issues = []
    acc_path = root / "spec" / "acceptance" / f"{feature_id}.md"

    if not acc_path.exists():
        return [f"No acceptance file for {feature_id}"]

    meta = parse_acceptance_frontmatter(acc_path)
    validations = meta.get('validation', [])

    if not validations:
        # Fallback: check for legacy ## Validation Commands section
        try:
            content = acc_path.read_text(encoding="utf-8")
            if '## Validation' not in content and '## Test' not in content:
                # Just a suggestion, not an error
                pass
        except Exception:
            pass
    else:
        for v in validations:
            cmd = v.get('command', '')
            # Check referenced files exist
            if 'tests/' in cmd:
                # Extract test file path from command
                test_match = re.search(r'tests/[\w/.-]+', cmd)
                if test_match:
                    test_file = test_match.group(0)
                    # Handle glob patterns gracefully
                    if '*' not in test_file and not (root / test_file).exists():
                        issues.append(f"{feature_id}: Test file not found: {test_file}")

    return issues


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
        if (root / ".agentic-state" / "WIP.md").exists():
            issues.append(".agentic-state/WIP.md exists - previous work was interrupted. Review or complete it.")

        # Check for stale verification
        state = read_verification_state(root)
        if state:
            try:
                last_run = datetime.fromisoformat(state["last_run"])
                hours_ago = (datetime.now() - last_run).total_seconds() / 3600
                if hours_ago > 24:
                    issues.append(f"Last verification was {hours_ago:.0f}h ago. Consider running: ag verify")
            except Exception:
                pass

        # Check for unresolved blockers
        blockers_file = root / "HUMAN_NEEDED.md"
        if blockers_file.exists():
            try:
                content = blockers_file.read_text()
                unresolved = len(re.findall(r"^## HN-\d+:.*(?!\[RESOLVED\])", content, re.MULTILINE))
                if unresolved > 0:
                    issues.append(f"{unresolved} unresolved blocker(s) in HUMAN_NEEDED.md")
            except Exception:
                pass

    elif phase == "planning":
        # Must have acceptance criteria before implementing
        if feature_id:
            acc_file = root / "spec" / "acceptance" / f"{feature_id}.md"
            if not acc_file.exists():
                issues.append(f"BLOCKED: No acceptance criteria at spec/acceptance/{feature_id}.md")
                issues.append("  Create acceptance criteria FIRST, then implement.")

            # Check if feature exists in FEATURES.md
            features_path = root / "spec" / "FEATURES.md"
            if features_path.exists():
                try:
                    content = features_path.read_text()
                    if f"## {feature_id}:" not in content:
                        issues.append(f"Feature {feature_id} not found in spec/FEATURES.md")
                except Exception:
                    pass
        else:
            issues.append("No feature ID provided. Use: doctor.sh --phase planning F-0001")

    elif phase == "implement":
        # Should have acceptance + WIP tracking
        if feature_id:
            acc_file = root / "spec" / "acceptance" / f"{feature_id}.md"
            if not acc_file.exists():
                issues.append(f"BLOCKED: Missing acceptance criteria for {feature_id}")
            if not (root / ".agentic-state" / "WIP.md").exists():
                issues.append("No WIP tracking. Start with: bash .agentic/tools/wip.sh start " + feature_id)

            # Check feature status
            features_path = root / "spec" / "FEATURES.md"
            if features_path.exists():
                try:
                    content = features_path.read_text()
                    if f"## {feature_id}:" in content:
                        feature_section = content[content.find(f"## {feature_id}:"):]
                        if "- Status: shipped" in feature_section[:500]:
                            issues.append(f"{feature_id} already marked 'shipped' - is this intentional?")
                except Exception:
                    pass

    elif phase == "complete":
        # Tests should pass, FEATURES.md updated
        ft = get_setting(root, "feature_tracking", "no")
        if feature_id and ft == "yes":
            features_path = root / "spec" / "FEATURES.md"
            if features_path.exists():
                try:
                    content = features_path.read_text()
                    if f"## {feature_id}:" in content:
                        feature_section = content[content.find(f"## {feature_id}:"):]
                        section_end = feature_section.find("\n## ", 10)
                        if section_end > 0:
                            feature_section = feature_section[:section_end]

                        # Check status
                        if "- Status: planned" in feature_section:
                            issues.append(f"{feature_id}: Status still 'planned' - update to 'shipped'")

                        # Check implementation state
                        if "State: none" in feature_section or "State: partial" in feature_section:
                            issues.append(f"{feature_id}: Implementation state not 'complete'")

                        # Check tests
                        if "Unit: todo" in feature_section.lower():
                            issues.append(f"{feature_id}: Unit tests still marked 'todo'")

                        # Check acceptance file
                        acc_file = root / "spec" / "acceptance" / f"{feature_id}.md"
                        if not acc_file.exists():
                            issues.append(f"{feature_id}: Missing acceptance criteria file")
                except Exception:
                    pass

        # Check WIP is complete
        if (root / ".agentic" / "WIP.md").exists():
            issues.append("WIP still active. Complete with: bash .agentic/tools/wip.sh complete")

    elif phase == "commit":
        # Delegate to pre-commit checks
        return run_pre_commit_checks(root, profile)

    return issues


def run_pre_commit_checks(root: Path, profile: str) -> list[str]:
    """Fast checks for pre-commit hook."""
    issues = []

    # 1. .agentic-state/WIP.md must not exist (work should be complete before commit)
    if (root / ".agentic-state" / "WIP.md").exists():
        issues.append(".agentic-state/WIP.md exists - complete or remove work-in-progress before committing")

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

    # 3. For feature tracking: shipped features need acceptance
    ft = get_setting(root, "feature_tracking", "no")
    if ft == "yes":
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


def get_verification_summary(root: Path) -> str:
    """Get a one-line verification status summary for session greeting."""
    state = read_verification_state(root)
    if state is None:
        return "No verification record. Run: ag verify"

    try:
        last_run = datetime.fromisoformat(state["last_run"])
        hours_ago = (datetime.now() - last_run).total_seconds() / 3600
        issues = state.get("issues_count", 0)
        result = state.get("result", "unknown")

        time_str = f"{hours_ago:.1f}h ago" if hours_ago < 24 else f"{hours_ago/24:.1f}d ago"

        if result == "pass":
            return f"Last verified: {time_str}, 0 issues"
        else:
            return f"Last verified: {time_str}, {issues} issue(s)"
    except Exception:
        return "Verification state unreadable"


def run_summary_check(root: Path) -> dict:
    """Run a quick summary check for session start context."""
    summary = {
        "verification": get_verification_summary(root),
        "wip_active": (root / ".agentic" / "WIP.md").exists(),
        "agents_active": 0,
        "blockers": 0,
        "current_focus": None,
    }

    # Check for active agents
    agents_file = root / ".agentic" / "AGENTS_ACTIVE.md"
    if agents_file.exists():
        try:
            content = agents_file.read_text()
            summary["agents_active"] = content.count("## ")
        except Exception:
            pass

    # Check for blockers
    blockers_file = root / "HUMAN_NEEDED.md"
    if blockers_file.exists():
        try:
            content = blockers_file.read_text()
            summary["blockers"] = len(re.findall(r"^## HN-", content, re.MULTILINE))
        except Exception:
            pass

    # Get current focus from STATUS.md
    status_file = root / "STATUS.md"
    if status_file.exists():
        try:
            content = status_file.read_text()
            # Try to find current focus
            focus_match = re.search(r"(?:Current [Ff]ocus|## Current Focus)[:\s]*(.+?)(?:\n|$)", content)
            if focus_match:
                summary["current_focus"] = focus_match.group(1).strip()[:100]
        except Exception:
            pass

    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description="Agentic Framework health check")
    parser.add_argument('--full', action='store_true', help='Run full verification (includes verify.py checks)')
    parser.add_argument('--phase', type=str, choices=['start', 'planning', 'implement', 'complete', 'commit'],
                        help='Run phase-specific checks')
    parser.add_argument('--pre-commit', action='store_true', help='Run pre-commit checks')
    parser.add_argument('--quick', action='store_true', help='Quick health check (default)')
    parser.add_argument('--summary', action='store_true', help='One-line summary for session greeting')
    parser.add_argument('feature_id', nargs='?', help='Feature ID (e.g., F-0001) for phase checks')
    args = parser.parse_args()

    root = Path.cwd()
    profile = get_setting(root, "profile", "discovery")
    detected_stack = None  # Will be set if stack detection runs

    # Handle --summary mode (for session greeting)
    if args.summary:
        summary = run_summary_check(root)
        print(summary["verification"])
        if summary["wip_active"]:
            print("WIP: Active (previous work interrupted)")
        if summary["agents_active"] > 0:
            print(f"Multi-agent: {summary['agents_active']} agent(s) active")
        if summary["blockers"] > 0:
            print(f"Blockers: {summary['blockers']} item(s) need human input")
        if summary["current_focus"]:
            print(f"Focus: {summary['current_focus']}")
        return 0

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

    checks = checks_for_profile(profile, root)
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

    # === Check for unapproved onboarding proposals ===
    proposal_files = []
    for fname in ["STACK.md", "CONTEXT_PACK.md", "OVERVIEW.md"]:
        fpath = root / fname
        if fpath.exists():
            try:
                if "<!-- PROPOSAL" in fpath.read_text(encoding="utf-8")[:200]:
                    proposal_files.append(fname)
            except Exception:
                pass
    if (root / "spec" / "FEATURES.md").exists():
        try:
            if "<!-- PROPOSAL" in (root / "spec" / "FEATURES.md").read_text(encoding="utf-8")[:200]:
                proposal_files.append("spec/FEATURES.md")
        except Exception:
            pass

    if proposal_files:
        print(f"\nOnboarding proposals ({len(proposal_files)} file(s) pending review):")
        for pf in proposal_files:
            print(f"  - {pf}")
        print("  Run: ag approve-onboarding")

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

    # === Feature-tracking validations ===
    ft = get_setting(root, "feature_tracking", "no")
    if ft == "yes":
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

        nfr_content_issues = validate_nfr_content(root)
        validation_issues.extend(nfr_content_issues)
    else:
        print("\nNote: Feature tracking off — formal validations (spec/FEATURES.md, acceptance files) skipped.")

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
        if ft == "yes":
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
