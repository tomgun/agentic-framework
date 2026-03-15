"""
framework_verify.py -- Autonomous Framework Verification Loop.

Implements F-0215: spawns agents to build example projects from scratch
using the framework's ag commands, verifying the full lifecycle end-to-end.
Self-healing: when the agent hits a framework bug, the system classifies
the failure, spawns a fix agent in a verification worktree, validates the
fix, and restarts from scratch. Accumulated fixes delivered as a single PR.

@feature F-0215

Usage:
    # CLI
    ag auto verify-framework --project todo-app
    ag auto verify-framework --all
    ag auto verify-framework --all --json
"""
from __future__ import annotations

import argparse
import atexit
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
sys.path.insert(0, str(_LIB_DIR / "tools"))

from auto import SpawnResult, spawn_claude  # noqa: E402

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
MAX_RETRIES_PER_SCENARIO = 3
MAX_TOTAL_FIXES = 20
MAX_REPAIR_ATTEMPTS = 3
REPAIR_TIMEOUT = 300  # seconds per repair agent
SCENARIOS_DIR = Path(__file__).resolve().parent / "scenarios"
PROMPTS_DIR = Path(__file__).resolve().parent / "prompts"


# ---------------------------------------------------------------------------
# Data types
# ---------------------------------------------------------------------------

@dataclass
class MilestoneResult:
    name: str
    passed: bool
    detail: str = ""


@dataclass
class ScenarioRun:
    scenario_name: str
    settings_label: str
    success: bool = False
    milestones: list[MilestoneResult] = field(default_factory=list)
    retries: int = 0
    fixes: list[str] = field(default_factory=list)
    repairs: list[str] = field(default_factory=list)
    escalations: list[str] = field(default_factory=list)
    error: str = ""
    skipped: bool = False


@dataclass
class VerifyResult:
    """Result of a full verification run."""
    success: bool
    runs: list[ScenarioRun] = field(default_factory=list)
    total_fixes: int = 0
    fix_commits: list[str] = field(default_factory=list)
    pr_url: str = ""
    stopped_at_max_fixes: bool = False
    messages: list[str] = field(default_factory=list)
    log_dir: str = ""

    def to_dict(self) -> dict:
        return {
            "success": self.success,
            "total_fixes": self.total_fixes,
            "log_dir": self.log_dir,
            "fix_commits": self.fix_commits,
            "pr_url": self.pr_url,
            "stopped_at_max_fixes": self.stopped_at_max_fixes,
            "runs": [
                {
                    "scenario": r.scenario_name,
                    "settings": r.settings_label,
                    "success": r.success,
                    "retries": r.retries,
                    "fixes": r.fixes,
                    "repairs": r.repairs,
                    "escalations": r.escalations,
                    "milestones": [
                        {"name": m.name, "passed": m.passed, "detail": m.detail}
                        for m in r.milestones
                    ],
                    "error": r.error,
                    "skipped": r.skipped,
                }
                for r in self.runs
            ],
            "messages": self.messages,
        }


# ---------------------------------------------------------------------------
# Scenario loading
# ---------------------------------------------------------------------------

def _load_yaml(text: str) -> dict[str, Any]:
    """Load YAML text, importing PyYAML lazily."""
    try:
        import yaml
    except ImportError:
        raise ImportError(
            "PyYAML is required for framework verification. "
            "Install with: pip install pyyaml"
        )
    return yaml.safe_load(text)


def load_scenario(name: str) -> dict[str, Any]:
    """Load a scenario YAML by slug name (e.g. 'todo_app')."""
    path = SCENARIOS_DIR / f"{name}.yaml"
    if not path.exists():
        raise FileNotFoundError(f"Scenario not found: {path}")
    return _load_yaml(path.read_text())


def list_scenarios() -> list[str]:
    """Return available scenario slugs."""
    return sorted(
        p.stem for p in SCENARIOS_DIR.glob("*.yaml")
    )


# ---------------------------------------------------------------------------
# Milestone checking
# ---------------------------------------------------------------------------

class MilestoneChecker:
    """Check required milestones against a project directory."""

    def __init__(self, project_root: Path, spawn_result: SpawnResult):
        self.root = project_root
        self.result = spawn_result

    def check(self, milestone: str) -> MilestoneResult:
        method = getattr(self, f"_check_{milestone}", None)
        if method is None:
            return MilestoneResult(milestone, False, f"Unknown milestone: {milestone}")
        return method()

    def _check_kickoff_complete(self) -> MilestoneResult:
        features = self.root / ".agentic" / "spec" / "FEATURES.md"
        if not features.exists():
            return MilestoneResult("kickoff_complete", False, "FEATURES.md not found")
        content = features.read_text()
        if not re.search(r"F-\d{4}", content):
            return MilestoneResult("kickoff_complete", False, "No F-XXXX entries in FEATURES.md")
        return MilestoneResult("kickoff_complete", True)

    def _check_features_specced(self) -> MilestoneResult:
        ac_dir = self.root / ".agentic" / "spec" / "acceptance"
        if not ac_dir.exists():
            return MilestoneResult("features_specced", False, "acceptance/ directory not found")
        ac_files = list(ac_dir.glob("F-*.md"))
        if not ac_files:
            return MilestoneResult("features_specced", False, "No F-*.md files in acceptance/")
        return MilestoneResult("features_specced", True, f"{len(ac_files)} AC files")

    def _check_component_features_scoped(self) -> MilestoneResult:
        features = self.root / ".agentic" / "spec" / "FEATURES.md"
        if not features.exists():
            return MilestoneResult("component_features_scoped", False, "FEATURES.md not found")
        content = features.read_text()
        if "**Component**:" not in content:
            return MilestoneResult(
                "component_features_scoped", False,
                "No features with **Component**: field"
            )
        return MilestoneResult("component_features_scoped", True)

    def _check_contracts_defined(self) -> MilestoneResult:
        stack = self.root / "STACK.md"
        if not stack.exists():
            return MilestoneResult("contracts_defined", False, "STACK.md not found")
        content = stack.read_text()
        if "## Contracts" not in content:
            return MilestoneResult("contracts_defined", False, "No ## Contracts section")
        return MilestoneResult("contracts_defined", True)

    def _check_implementation_done(self) -> MilestoneResult:
        try:
            result = subprocess.run(
                ["git", "log", "--oneline", "-20"],
                capture_output=True, text=True, cwd=str(self.root),
            )
            lines = [l for l in result.stdout.strip().split("\n") if l.strip()]
            # Need at least 2 commits (init + at least one implementation commit)
            if len(lines) >= 2:
                return MilestoneResult("implementation_done", True, f"{len(lines)} commits")
            return MilestoneResult("implementation_done", False, "Only init commit found")
        except Exception as e:
            return MilestoneResult("implementation_done", False, str(e))

    def _check_contracts_validated(self) -> MilestoneResult:
        """Call validate_contracts() directly on the project."""
        try:
            from auto.components import load_registry
            from auto.umbrella import validate_contracts
            registry = load_registry(self.root)
            results = validate_contracts(self.root, registry)
            if len(results) > 0 and all(not r.warnings for r in results):
                return MilestoneResult("contracts_validated", True)
            if len(results) == 0:
                return MilestoneResult("contracts_validated", False, "No contracts found")
            warnings = []
            for r in results:
                warnings.extend(r.warnings)
            return MilestoneResult(
                "contracts_validated", False,
                f"{len(warnings)} contract warnings"
            )
        except ImportError:
            return MilestoneResult("contracts_validated", False, "umbrella module not available")
        except Exception as e:
            return MilestoneResult("contracts_validated", False, str(e))

    def _check_integration_verified(self) -> MilestoneResult:
        journal = self.root / ".agentic" / "journal"
        if not journal.exists():
            return MilestoneResult("integration_verified", False, "journal/ not found")
        verify_files = list(journal.glob("verify-epic-*.md"))
        if verify_files:
            return MilestoneResult("integration_verified", True)
        return MilestoneResult("integration_verified", False, "No verify-epic-*.md files")

    def _check_verification_green(self) -> MilestoneResult:
        if self.result.timed_out:
            return MilestoneResult("verification_green", False, "Build agent timed out")
        if self.result.returncode != 0:
            return MilestoneResult(
                "verification_green", False,
                f"Build agent exited with code {self.result.returncode}"
            )
        return MilestoneResult("verification_green", True)


# ---------------------------------------------------------------------------
# Behavioral expectations
# ---------------------------------------------------------------------------

class ExpectationChecker:
    """Run BDD-style expectations against a built project.

    Expectations are declared in scenario YAML under an `expectations` key:

        expectations:
          files_exist:            # glob patterns — at least one match required
            - "app/**/*.py"
            - "tests/test_*.py"
          commands_pass:          # shell commands that must exit 0
            - "pytest"
          source_contains:       # regex patterns in source files
            - pattern: "FastAPI"
              glob: "app/**/*.py"
    """

    def __init__(self, project_root: Path):
        self.root = project_root

    def check_all(self, expectations: dict[str, Any]) -> list[MilestoneResult]:
        """Run all expectations and return results."""
        results: list[MilestoneResult] = []

        for pattern in expectations.get("files_exist", []):
            results.append(self._check_files_exist(pattern))

        for cmd in expectations.get("commands_pass", []):
            results.append(self._check_command_passes(cmd))

        for entry in expectations.get("source_contains", []):
            results.append(self._check_source_contains(
                entry["pattern"], entry.get("glob", "**/*"),
            ))

        # Workflow expectations — verify the framework process was followed
        for check in expectations.get("workflow", []):
            results.append(self._check_workflow(check))

        return results

    def _check_files_exist(self, pattern: str) -> MilestoneResult:
        matches = list(self.root.glob(pattern))
        # Filter out .git and .agentic matches
        matches = [
            m for m in matches if m.is_file()
            and ".git" not in m.parts and ".agentic" not in m.parts
        ]
        if matches:
            return MilestoneResult(
                f"files_exist({pattern})", True,
                f"{len(matches)} file(s)",
            )
        return MilestoneResult(
            f"files_exist({pattern})", False,
            "no matching files",
        )

    def _check_command_passes(self, cmd: str) -> MilestoneResult:
        try:
            result = subprocess.run(
                ["bash", "-c", cmd],
                cwd=str(self.root),
                capture_output=True, text=True,
                timeout=120,
            )
            if result.returncode == 0:
                return MilestoneResult(
                    f"command_passes({cmd})", True,
                )
            # Include last few lines of output for diagnosis
            output = (result.stdout + result.stderr).strip().split("\n")
            tail = "\n".join(output[-5:]) if len(output) > 5 else "\n".join(output)
            return MilestoneResult(
                f"command_passes({cmd})", False,
                f"exit {result.returncode}: {tail[:200]}",
            )
        except subprocess.TimeoutExpired:
            return MilestoneResult(
                f"command_passes({cmd})", False, "timed out (120s)",
            )
        except Exception as e:
            return MilestoneResult(
                f"command_passes({cmd})", False, str(e),
            )

    def _check_source_contains(self, pattern: str, glob: str) -> MilestoneResult:
        matches = [
            f for f in self.root.glob(glob)
            if f.is_file() and ".git" not in f.parts and ".agentic" not in f.parts
        ]
        if not matches:
            return MilestoneResult(
                f"source_contains({pattern})", False,
                f"no files matching {glob}",
            )
        regex = re.compile(pattern)
        matched_files = []
        for f in matches:
            try:
                if regex.search(f.read_text(errors="ignore")):
                    matched_files.append(f.name)
            except Exception:
                continue
        if matched_files:
            return MilestoneResult(
                f"source_contains({pattern})", True,
                f"found in {len(matched_files)} file(s)",
            )
        return MilestoneResult(
            f"source_contains({pattern})", False,
            f"pattern not found in {len(matches)} file(s)",
        )

    # -- Workflow expectations ------------------------------------------------

    def _check_workflow(self, check: dict[str, Any]) -> MilestoneResult:
        """Dispatch a workflow expectation by type."""
        check_type = check.get("type", "")
        method = getattr(self, f"_wf_{check_type}", None)
        if method is None:
            return MilestoneResult(
                f"workflow({check_type})", False,
                f"Unknown workflow check: {check_type}",
            )
        return method(check)

    def _wf_features_have_status(self, check: dict) -> MilestoneResult:
        """At least N features reached the given status."""
        status = check.get("status", "shipped")
        min_count = check.get("min", 1)
        features_path = self.root / ".agentic" / "spec" / "FEATURES.md"
        if not features_path.exists():
            return MilestoneResult(
                f"features_have_status({status})", False,
                "FEATURES.md not found",
            )
        content = features_path.read_text()
        count = len(re.findall(
            rf"\*\*Status\*\*:\s*{re.escape(status)}", content,
        ))
        if count >= min_count:
            return MilestoneResult(
                f"features_have_status({status})", True,
                f"{count} feature(s) with status '{status}'",
            )
        return MilestoneResult(
            f"features_have_status({status})", False,
            f"only {count} feature(s) with status '{status}' (need {min_count})",
        )

    def _wf_acceptance_criteria_checked(self, check: dict) -> MilestoneResult:
        """At least N AC files have all items checked off [x]."""
        min_count = check.get("min", 1)
        ac_dir = self.root / ".agentic" / "spec" / "acceptance"
        if not ac_dir.exists():
            return MilestoneResult(
                "acceptance_criteria_checked", False,
                "acceptance/ directory not found",
            )
        fully_checked = 0
        for ac_file in ac_dir.glob("F-*.md"):
            content = ac_file.read_text()
            unchecked = re.findall(r"- \[ \]", content)
            checked = re.findall(r"- \[x\]", content)
            if checked and not unchecked:
                fully_checked += 1
        if fully_checked >= min_count:
            return MilestoneResult(
                "acceptance_criteria_checked", True,
                f"{fully_checked} AC file(s) fully checked",
            )
        return MilestoneResult(
            "acceptance_criteria_checked", False,
            f"only {fully_checked} AC file(s) fully checked (need {min_count})",
        )

    def _wf_plans_exist(self, check: dict) -> MilestoneResult:
        """Plans directory has at least N plan files."""
        min_count = check.get("min", 1)
        plans_dir = self.root / ".agentic" / "journal" / "plans"
        if not plans_dir.exists():
            return MilestoneResult(
                "plans_exist", False, "plans/ directory not found",
            )
        plan_files = list(plans_dir.glob("F-*-plan.md"))
        if len(plan_files) >= min_count:
            return MilestoneResult(
                "plans_exist", True,
                f"{len(plan_files)} plan file(s)",
            )
        return MilestoneResult(
            "plans_exist", False,
            f"only {len(plan_files)} plan file(s) (need {min_count})",
        )

    def _wf_plans_approved(self, check: dict) -> MilestoneResult:
        """At least N plans have APPROVED status."""
        min_count = check.get("min", 1)
        plans_dir = self.root / ".agentic" / "journal" / "plans"
        if not plans_dir.exists():
            return MilestoneResult(
                "plans_approved", False, "plans/ directory not found",
            )
        approved = 0
        for plan in plans_dir.glob("F-*-plan.md"):
            content = plan.read_text()
            if re.search(r"\*\*Status\*\*:\s*APPROVED", content):
                approved += 1
        if approved >= min_count:
            return MilestoneResult(
                "plans_approved", True,
                f"{approved} plan(s) approved",
            )
        return MilestoneResult(
            "plans_approved", False,
            f"only {approved} approved plan(s) (need {min_count})",
        )

    def _wf_journal_updated(self, _check: dict) -> MilestoneResult:
        """JOURNAL.md has at least one entry beyond the template."""
        journal = self.root / ".agentic" / "journal" / "JOURNAL.md"
        if not journal.exists():
            return MilestoneResult(
                "journal_updated", False, "JOURNAL.md not found",
            )
        content = journal.read_text()
        # Count entries (each starts with ##)
        entries = re.findall(r"^## ", content, re.MULTILINE)
        if len(entries) >= 1:
            return MilestoneResult(
                "journal_updated", True,
                f"{len(entries)} journal entry/entries",
            )
        return MilestoneResult(
            "journal_updated", False, "no journal entries found",
        )

    def _wf_commits_follow_convention(self, check: dict) -> MilestoneResult:
        """Git commits follow conventional format with feature IDs."""
        min_count = check.get("min", 1)
        pattern = check.get("pattern", r"^(feat|fix|test|chore|docs)\(?.*\)?:")
        try:
            result = subprocess.run(
                ["git", "log", "--oneline", "-20"],
                capture_output=True, text=True, cwd=str(self.root),
                timeout=10,
            )
            lines = [
                l.split(" ", 1)[1] for l in result.stdout.strip().split("\n")
                if l.strip() and " " in l
            ]
            regex = re.compile(pattern)
            matching = [l for l in lines if regex.search(l)]
            # Exclude the init commit
            non_init = [l for l in lines if not l.startswith("init:")]
            if len(matching) >= min_count:
                return MilestoneResult(
                    "commits_follow_convention", True,
                    f"{len(matching)}/{len(non_init)} commits match",
                )
            return MilestoneResult(
                "commits_follow_convention", False,
                f"only {len(matching)}/{len(non_init)} commits match pattern",
            )
        except Exception as e:
            return MilestoneResult(
                "commits_follow_convention", False, str(e),
            )

    def _wf_no_wip_at_end(self, _check: dict) -> MilestoneResult:
        """No WIP.md or active AGENTS.json entries at project completion."""
        wip = self.root / ".agentic" / "session" / "WIP.md"
        if wip.exists():
            return MilestoneResult(
                "no_wip_at_end", False, "WIP.md still exists",
            )
        agents = self.root / ".agentic" / "session" / "AGENTS.json"
        if agents.exists():
            try:
                data = json.loads(agents.read_text())
                if data:  # Non-empty list = active agents
                    return MilestoneResult(
                        "no_wip_at_end", False,
                        f"{len(data)} active agent(s) in AGENTS.json",
                    )
            except (json.JSONDecodeError, OSError):
                pass
        return MilestoneResult("no_wip_at_end", True)


# ---------------------------------------------------------------------------
# Project setup
# ---------------------------------------------------------------------------

def setup_project(
    scenario: dict[str, Any],
    vw_path: Path,
    project_dir: Path,
    settings: dict[str, str],
) -> None:
    """Set up an example project directory from the VW framework source."""
    project_dir.mkdir(parents=True, exist_ok=True)

    # Copy framework
    shutil.copytree(vw_path / ".agentic", project_dir / ".agentic")

    # Create tier-1 settings for non-interactive execution
    claude_dir = project_dir / ".claude"
    claude_dir.mkdir(exist_ok=True)
    (claude_dir / "settings.json").write_text('{"_tier": 1}')

    # Write STACK.md
    _write_stack_md(project_dir, scenario, settings)

    # Create component dirs for monorepo
    if scenario.get("type") == "monorepo":
        for comp in scenario.get("components", []):
            comp_path = project_dir / comp["path"]
            comp_path.mkdir(parents=True, exist_ok=True)

    # Git init
    subprocess.run(["git", "init"], cwd=str(project_dir), check=True,
                    capture_output=True, text=True)
    subprocess.run(["git", "add", "."], cwd=str(project_dir), check=True,
                    capture_output=True, text=True)
    subprocess.run(
        ["git", "commit", "-m", "init: project scaffold"],
        cwd=str(project_dir), check=True, capture_output=True, text=True,
    )


def setup_multirepo_project(
    scenario: dict[str, Any],
    vw_path: Path,
    base_dir: Path,
    settings: dict[str, str],
) -> Path:
    """Set up a multi-repo project with umbrella + component repos.

    Returns the umbrella project directory (the primary project_root).
    """
    umbrella_dir = base_dir / "umbrella"
    umbrella_dir.mkdir(parents=True, exist_ok=True)

    # Create component repos FIRST (umbrella.py checks .git existence)
    component_paths: dict[str, Path] = {}
    for comp in scenario.get("components", []):
        comp_name = comp["name"]
        # Resolve path relative to umbrella
        comp_dir = (umbrella_dir / comp["path"]).resolve()
        comp_dir.mkdir(parents=True, exist_ok=True)
        component_paths[comp_name] = comp_dir

        # Git init each component repo
        subprocess.run(["git", "init"], cwd=str(comp_dir), check=True,
                        capture_output=True, text=True)
        # Create a minimal file so we can commit
        (comp_dir / "README.md").write_text(f"# {comp_name}\n")
        subprocess.run(["git", "add", "."], cwd=str(comp_dir), check=True,
                        capture_output=True, text=True)
        subprocess.run(
            ["git", "commit", "-m", f"init: {comp_name} component"],
            cwd=str(comp_dir), check=True, capture_output=True, text=True,
        )

    # Now set up umbrella with resolved paths
    shutil.copytree(vw_path / ".agentic", umbrella_dir / ".agentic")
    claude_dir = umbrella_dir / ".claude"
    claude_dir.mkdir(exist_ok=True)
    (claude_dir / "settings.json").write_text('{"_tier": 1}')

    # Write STACK.md with resolved absolute paths (not 'repo: local')
    _write_multirepo_stack_md(umbrella_dir, scenario, settings, component_paths)

    # Git init umbrella
    subprocess.run(["git", "init"], cwd=str(umbrella_dir), check=True,
                    capture_output=True, text=True)
    subprocess.run(["git", "add", "."], cwd=str(umbrella_dir), check=True,
                    capture_output=True, text=True)
    subprocess.run(
        ["git", "commit", "-m", "init: umbrella scaffold"],
        cwd=str(umbrella_dir), check=True, capture_output=True, text=True,
    )

    return umbrella_dir


def _write_stack_md(
    project_dir: Path,
    scenario: dict[str, Any],
    settings: dict[str, str],
) -> None:
    """Write STACK.md for a single or monorepo project."""
    stack = scenario.get("stack", {})
    lines = [
        "# STACK.md",
        "",
        f"Purpose: {scenario.get('description', 'Example project')}",
        "",
        "## Settings",
        f"- profile: {settings.get('profile', 'discovery')}",
        f"- git_workflow: {settings.get('git_workflow', 'direct')}",
    ]
    if "docs_mode" in settings:
        lines.append(f"- docs_mode: {settings['docs_mode']}")
    if "review_merge" in settings:
        lines.append(f"- review_merge: {settings['review_merge']}")
    # Formal profiles need these for the full workflow to exercise
    profile = settings.get("profile", "discovery")
    if profile in ("formal", "autonomous_formal"):
        lines.append("- plan_review_enabled: no")
        lines.append("- acceptance_criteria: blocking")
        lines.append("- review_commit: skip")

    lines.extend([
        "",
        "## Stack",
        f"- Language: {stack.get('language', 'python')}",
    ])
    if "framework" in stack:
        lines.append(f"- Framework: {stack['framework']}")
    if "test_runner" in stack:
        lines.append(f"- Test runner: {stack['test_runner']}")

    # Components table for monorepo
    if scenario.get("type") == "monorepo" and scenario.get("components"):
        lines.extend(["", "## Components", "", "| Name | Path | Type | Test Command |",
                       "|------|------|------|-------------|"])
        for comp in scenario["components"]:
            lines.append(
                f"| {comp['name']} | {comp['path']} | {comp.get('type', '')} "
                f"| {comp.get('test_command', '')} |"
            )

    lines.append("")
    (project_dir / "STACK.md").write_text("\n".join(lines))


def _write_multirepo_stack_md(
    umbrella_dir: Path,
    scenario: dict[str, Any],
    settings: dict[str, str],
    component_paths: dict[str, Path],
) -> None:
    """Write STACK.md for a multi-repo umbrella project with resolved paths."""
    lines = [
        "# STACK.md",
        "",
        f"Purpose: {scenario.get('description', 'Multi-repo project')}",
        "",
        "## Settings",
        f"- profile: {settings.get('profile', 'autonomous_formal')}",
        f"- git_workflow: {settings.get('git_workflow', 'pull_request')}",
    ]
    if "review_merge" in settings:
        lines.append(f"- review_merge: {settings['review_merge']}")

    # Components with resolved paths and Repo column
    lines.extend(["", "## Components", "",
                   "| Name | Path | Repo | Type | Test Command |",
                   "|------|------|------|------|-------------|"])
    for comp in scenario.get("components", []):
        resolved = str(component_paths.get(comp["name"], comp["path"]))
        lines.append(
            f"| {comp['name']} | {comp['path']} | {resolved} "
            f"| {comp.get('type', '')} | {comp.get('test_command', '')} |"
        )

    # Contracts
    if scenario.get("contracts"):
        lines.extend(["", "## Contracts", "",
                       "| Name | Format | Path | Producer | Consumers |",
                       "|------|--------|------|----------|-----------|"])
        for contract in scenario["contracts"]:
            consumers = ", ".join(contract.get("consumers", []))
            lines.append(
                f"| {contract['name']} | {contract.get('format', '')} "
                f"| {contract.get('path', '')} | {contract.get('producer', '')} "
                f"| {consumers} |"
            )

    lines.append("")
    (umbrella_dir / "STACK.md").write_text("\n".join(lines))


# ---------------------------------------------------------------------------
# Build prompt generation
# ---------------------------------------------------------------------------

def build_prompt(scenario: dict[str, Any], settings: dict[str, str]) -> str:
    """Generate the build agent prompt from template + scenario data."""
    template_path = PROMPTS_DIR / "verify_build.md"
    template = template_path.read_text()

    stack = scenario.get("stack", {})
    stack_desc = ", ".join(f"{k}: {v}" for k, v in stack.items())

    return template.format(
        vision=scenario.get("vision", "").strip(),
        stack_description=stack_desc or "See STACK.md",
        profile=settings.get("profile", "discovery"),
        git_workflow=settings.get("git_workflow", "direct"),
    )


# ---------------------------------------------------------------------------
# Core verifier
# ---------------------------------------------------------------------------

class FrameworkVerifier:
    """Orchestrates framework verification runs."""

    def __init__(
        self,
        project_root: Path,
        *,
        claude_command: str = "claude",
        json_output: bool = False,
    ):
        self.project_root = project_root
        self.claude_command = claude_command
        self.json_output = json_output
        self.vw_path: Optional[Path] = None
        self.vw_branch: str = ""
        self.total_fixes = 0
        self.fix_commits: list[str] = []
        self._push_succeeded = False
        self._pr_created = False
        # Log directory for agent output — stored in workspace for visibility
        # across containers that share the same workspace mount.
        log_base = project_root / ".agentic" / "session" / "verify-logs"
        ts = time.strftime("%Y%m%d-%H%M%S")
        self.log_dir = log_base / f"run-{ts}"
        self.log_dir.mkdir(parents=True, exist_ok=True)

    def _log(self, msg: str) -> None:
        """Print a timestamped progress message to stderr.

        Uses stderr so progress is visible even with --json (which uses stdout).
        """
        ts = time.strftime("%H:%M:%S")
        print(f"[{ts}] {msg}", file=sys.stderr, flush=True)

    # -- Pre-flight ----------------------------------------------------------

    def pre_flight(self) -> list[str]:
        """Run pre-flight checks. Returns list of blocking errors."""
        errors: list[str] = []

        # 0. Framework-only guard: refuse to run in production projects.
        # verify-framework spawns agents with --dangerously-skip-permissions,
        # creates worktrees, and consumes significant tokens. It is meant
        # ONLY for the framework repo itself, not user projects.
        marker = self.project_root / "FRAMEWORK_DEVELOPMENT.md"
        if not marker.exists():
            errors.append(
                "verify-framework is only available in the framework repo itself. "
                "This project does not have FRAMEWORK_DEVELOPMENT.md. "
                "If you are developing the framework, ensure you are in the "
                "correct directory."
            )

        # 1. Claude availability
        try:
            subprocess.run(
                [self.claude_command, "--version"],
                capture_output=True, text=True, timeout=10,
            )
        except (FileNotFoundError, subprocess.TimeoutExpired):
            errors.append(f"Claude CLI not found: {self.claude_command}")

        # 2. Not on main
        branch = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True, text=True, cwd=str(self.project_root),
        ).stdout.strip()
        if branch in ("main", "master"):
            errors.append(f"Cannot run from {branch} branch")

        # 3. No concurrent verify runs
        branches = subprocess.run(
            ["git", "branch", "--list", "verify/run-*"],
            capture_output=True, text=True, cwd=str(self.project_root),
        ).stdout.strip()
        if branches:
            errors.append(
                f"Concurrent verify run detected: {branches.strip()}. "
                "Clean up first: git worktree remove + git branch -D"
            )

        # 4. No stale AG_TRUNK_BRANCH from a previous run
        if os.environ.get("AG_TRUNK_BRANCH"):
            errors.append(
                "AG_TRUNK_BRANCH env var is already set "
                f"({os.environ['AG_TRUNK_BRANCH']}). "
                "Another verify run may be active."
            )

        return errors

    # -- VW management -------------------------------------------------------

    def create_vw(self) -> None:
        """Create the verification worktree on an ephemeral branch."""
        ts = int(time.time())
        self.vw_branch = f"verify/run-{ts}"
        self.vw_path = Path(tempfile.mkdtemp(prefix="ag-vw-"))

        subprocess.run(
            ["git", "worktree", "add", "-b", self.vw_branch, str(self.vw_path)],
            check=True, capture_output=True, text=True,
            cwd=str(self.project_root),
        )

        # Create tier-1 settings in VW for fix agent
        claude_dir = self.vw_path / ".claude"
        claude_dir.mkdir(exist_ok=True)
        (claude_dir / "settings.json").write_text('{"_tier": 1}')

        # Set env var for all spawned subprocesses
        os.environ["AG_TRUNK_BRANCH"] = self.vw_branch

        # Register cleanup
        atexit.register(self._cleanup)

    def _cleanup(self) -> None:
        """Clean up VW and ephemeral branch."""
        try:
            if self.vw_path and self.vw_path.exists():
                subprocess.run(
                    ["git", "worktree", "remove", "--force", str(self.vw_path)],
                    capture_output=True, text=True,
                    cwd=str(self.project_root),
                )
        except Exception:
            pass

        # Only delete branch if push/PR didn't happen
        if not self._push_succeeded and self.vw_branch:
            try:
                subprocess.run(
                    ["git", "branch", "-D", self.vw_branch],
                    capture_output=True, text=True,
                    cwd=str(self.project_root),
                )
            except Exception:
                pass

        # Clean env
        os.environ.pop("AG_TRUNK_BRANCH", None)

    def _cleanup_agents_json(self, scenario_name: str) -> None:
        """Remove stale AGENTS.json entries from prior scenario attempts."""
        try:
            agents_helper = _LIB_DIR / "tools" / "agents_helpers.py"
            if agents_helper.exists():
                subprocess.run(
                    ["python3", str(agents_helper),
                     "--project-root", str(self.project_root), "cleanup-stale"],
                    capture_output=True, text=True, timeout=10,
                )
        except Exception:
            pass  # Best-effort cleanup

    # -- Run scenario --------------------------------------------------------

    def run_scenario(
        self,
        scenario: dict[str, Any],
        settings: dict[str, str],
    ) -> ScenarioRun:
        """Run a single scenario with a single settings combo."""
        name = scenario.get("name", "unknown")
        settings_label = settings.get("profile", "default")
        timeout = scenario.get("timeout", 600)

        run = ScenarioRun(scenario_name=name, settings_label=settings_label)

        slug = name.lower().replace(' ', '-')

        for retry in range(MAX_RETRIES_PER_SCENARIO):
            if self.total_fixes >= MAX_TOTAL_FIXES:
                run.skipped = True
                run.error = "Max total fixes reached"
                return run

            run.retries = retry
            attempt = retry + 1
            self._log(
                f"{'─' * 40}\n"
                f"         {name} [{settings_label}] — attempt {attempt}/{MAX_RETRIES_PER_SCENARIO}"
            )

            # Clean up stale AGENTS.json entries from prior attempts
            self._cleanup_agents_json(name)

            # Create fresh project
            project_dir = Path(tempfile.mkdtemp(
                prefix=f"ag-verify-{slug}-"
            ))

            # Log file for this attempt
            log_file = self.log_dir / f"{slug}_{settings_label}_attempt{attempt}.log"
            self._log(f"  Project: {project_dir}")
            self._log(f"  Log:     {log_file}")
            self._log(f"  Watch:   tail -f {log_file}")

            try:
                # Set up project based on type
                if scenario.get("type") == "multirepo":
                    project_root = setup_multirepo_project(
                        scenario, self.vw_path, project_dir, settings
                    )
                else:
                    project_root = project_dir
                    setup_project(scenario, self.vw_path, project_dir, settings)

                self._log(f"  Project scaffolded, spawning build agent (timeout={timeout}s)...")

                # Spawn build agent
                prompt = build_prompt(scenario, settings)
                result = spawn_claude(
                    self.claude_command,
                    project_root,
                    prompt,
                    timeout=timeout,
                    log_file=log_file,
                    monitor=True,
                    monitor_interval=30,
                )

                # Report agent exit
                if result.timed_out:
                    self._log(f"  Agent timed out after {timeout}s")
                elif result.returncode == 0:
                    self._log(f"  Agent finished (exit 0)")
                else:
                    self._log(f"  Agent exited with code {result.returncode}")

                # Check milestones
                checker = MilestoneChecker(project_root, result)
                milestones = [
                    checker.check(m) for m in scenario.get("required_milestones", [])
                ]
                run.milestones = milestones

                for m in milestones:
                    icon = "+" if m.passed else "✗"
                    detail = f" — {m.detail}" if m.detail else ""
                    self._log(f"    {icon} {m.name}{detail}")

                # Check behavioral expectations (if defined)
                # Merge scenario-level + settings-level expectations so
                # profile-specific checks (e.g. plans_approved for formal)
                # can be declared per settings_matrix entry.
                expectations = dict(scenario.get("expectations", {}))
                settings_exp = settings.get("expectations", {})
                for key, val in settings_exp.items():
                    if key in expectations and isinstance(expectations[key], list):
                        expectations[key] = expectations[key] + val
                    else:
                        expectations[key] = val
                if expectations:
                    self._log(f"  Running behavioral expectations...")
                    exp_checker = ExpectationChecker(project_root)
                    exp_results = exp_checker.check_all(expectations)
                    milestones.extend(exp_results)
                    run.milestones = milestones

                    for m in exp_results:
                        icon = "+" if m.passed else "✗"
                        detail = f" — {m.detail}" if m.detail else ""
                        self._log(f"    {icon} {m.name}{detail}")

                    # Repair loop: attempt to fix failed expectations
                    failed = [m for m in exp_results if not m.passed]
                    if failed and all(m.passed for m in milestones
                                      if m not in exp_results):
                        self._repair_expectations(
                            project_root, exp_checker, expectations,
                            failed, run, log_file,
                        )
                        # Refresh milestones after repairs
                        refreshed = exp_checker.check_all(expectations)
                        # Replace exp_results in milestones
                        milestone_base = [
                            m for m in run.milestones if m not in exp_results
                        ]
                        milestone_base.extend(refreshed)
                        run.milestones = milestone_base

                if all(m.passed for m in run.milestones):
                    run.success = True
                    self._log(f"  PASSED")
                    return run

                # Classify failure
                from auto.self_heal import SelfHealEngine
                engine = SelfHealEngine(self.vw_path, self.claude_command)
                failure_type = engine.classify(result, milestones)
                self._log(f"  Failure classified as: {failure_type}")

                if failure_type == "framework_bug":
                    fix_msg = engine.attempt_fix(result, milestones, name)
                    if fix_msg:
                        self.total_fixes += 1
                        self.fix_commits.append(fix_msg)
                        run.fixes.append(fix_msg)
                        self._log(f"  Fix applied: {fix_msg}")
                        # Restart from scratch (continue the retry loop)
                        continue
                    # Fix failed — fall through to retry as agent_error
                    self._log(f"  Fix attempt failed, retrying as agent_error")

                # agent_error or external — retry from scratch
                run.error = _summarize_failure(milestones, result)

            finally:
                # Clean up example project
                shutil.rmtree(project_dir, ignore_errors=True)

        return run

    # -- Delivery ------------------------------------------------------------

    # -- Repair loop ---------------------------------------------------------

    def _repair_expectations(
        self,
        project_root: Path,
        exp_checker: ExpectationChecker,
        expectations: dict[str, Any],
        failed: list[MilestoneResult],
        run: ScenarioRun,
        log_file: Path | None,
    ) -> None:
        """Iteratively repair failed expectations.

        For each failed expectation:
        1. Spawn a repair agent targeting that specific failure
        2. Re-check the expectation
        3. If still failing, retry with different instructions
        4. After MAX_REPAIR_ATTEMPTS, escalate and move on
        """
        self._log(f"  Entering repair loop: {len(failed)} failed expectation(s)")

        for fail in failed:
            repaired = False
            for attempt in range(1, MAX_REPAIR_ATTEMPTS + 1):
                self._log(
                    f"    Repairing: {fail.name} "
                    f"(attempt {attempt}/{MAX_REPAIR_ATTEMPTS})"
                )

                # Build repair prompt
                prompt = self._build_repair_prompt(
                    fail, attempt, project_root,
                )

                # Determine log file for repair agent
                repair_log = None
                if log_file:
                    base = log_file.stem
                    safe_name = re.sub(r'[^a-zA-Z0-9_-]', '_', fail.name)[:50]
                    repair_log = log_file.parent / (
                        f"{base}_repair_{safe_name}_attempt{attempt}.log"
                    )

                repair_result = spawn_claude(
                    self.claude_command,
                    project_root,
                    prompt,
                    timeout=REPAIR_TIMEOUT,
                    log_file=repair_log,
                    monitor=True,
                    monitor_interval=15,
                )

                if repair_result.timed_out:
                    self._log(f"      Repair agent timed out")
                    continue

                # Re-check this specific expectation
                refreshed = exp_checker.check_all(expectations)
                fixed = next(
                    (m for m in refreshed if m.name == fail.name), None,
                )
                if fixed and fixed.passed:
                    self._log(f"      + Repaired: {fail.name}")
                    run.repairs.append(f"{fail.name} (attempt {attempt})")
                    repaired = True
                    break
                else:
                    detail = fixed.detail if fixed else "check not found"
                    self._log(f"      Still failing: {detail}")

            if not repaired:
                self._log(f"    ESCALATED: {fail.name} — {fail.detail}")
                run.escalations.append(f"{fail.name}: {fail.detail}")

    def _build_repair_prompt(
        self,
        fail: MilestoneResult,
        attempt: int,
        project_root: Path,
    ) -> str:
        """Build a targeted repair prompt for a specific failed expectation."""
        template_path = PROMPTS_DIR / "verify_repair.md"
        template = template_path.read_text()

        # Count commits for context
        try:
            out = subprocess.run(
                ["git", "rev-list", "--count", "HEAD"],
                capture_output=True, text=True, cwd=str(project_root),
                timeout=5,
            ).stdout.strip()
            commit_count = out if out.isdigit() else "unknown"
        except Exception:
            commit_count = "unknown"

        # Build hints based on check type
        repair_hint = self._repair_hint(fail, attempt)

        # Describe what was expected
        expectation_desc = self._expectation_description(fail)

        return template.format(
            check_name=fail.name,
            check_detail=fail.detail or "no detail",
            attempt=attempt,
            max_attempts=MAX_REPAIR_ATTEMPTS,
            expectation_description=expectation_desc,
            commit_count=commit_count,
            repair_hint=repair_hint,
        )

    @staticmethod
    def _expectation_description(fail: MilestoneResult) -> str:
        """Human-readable description of what an expectation checks."""
        name = fail.name
        if name.startswith("files_exist"):
            return f"Source files matching the pattern should exist in the project."
        if name.startswith("command_passes"):
            return f"The command should exit with code 0 (tests pass, build succeeds)."
        if name.startswith("source_contains"):
            return f"Source files should contain the expected pattern (correct framework/library used)."
        if "features_have_status" in name:
            return "Features in FEATURES.md should have reached 'shipped' status. Run `ag done F-XXXX` for completed features."
        if "plans_exist" in name:
            return "Implementation plans should exist at .agentic/journal/plans/F-XXXX-plan.md. Run `ag plan F-XXXX` or `ag implement F-XXXX` which creates plans."
        if "plans_approved" in name:
            return "Plans should have **Status**: APPROVED. The plan review process must complete."
        if "acceptance_criteria_checked" in name:
            return "Acceptance criteria files should have all items checked [x]. Run `ag done` to mark features complete."
        if "journal_updated" in name:
            return "JOURNAL.md should have at least one entry. Use `bash .agentic/lib/tools/journal.sh` to add entries."
        if "commits_follow_convention" in name:
            return "Git commits should follow conventional format: feat(scope): description, fix: description, etc."
        if "no_wip_at_end" in name:
            return "No WIP.md or active AGENTS.json should remain. Run `ag done` for all features."
        return f"Expectation '{name}' should pass."

    @staticmethod
    def _repair_hint(fail: MilestoneResult, attempt: int) -> str:
        """Progressive hints — more specific guidance on later attempts."""
        name = fail.name
        hints = []

        if attempt >= 2:
            hints.append(
                "Previous repair attempt did not fix this. "
                "Try a different approach."
            )
        if attempt >= 3:
            hints.append(
                "This is the last attempt. Be thorough — check the actual "
                "file contents and state before making changes."
            )

        # Check-specific hints
        if "command_passes" in name:
            hints.append(
                "Run the command manually first to see the full error output. "
                "Common issues: missing dependencies, import errors, test failures."
            )
        elif "plans_approved" in name:
            if attempt == 1:
                hints.append(
                    "Check if plans exist but have DRAFT status. "
                    "Update the status to APPROVED in the plan file."
                )
            else:
                hints.append(
                    "Create the plan file directly at "
                    ".agentic/journal/plans/F-XXXX-plan.md with "
                    "**Status**: APPROVED if the plan review is not possible."
                )
        elif "acceptance_criteria_checked" in name:
            hints.append(
                "Open .agentic/spec/acceptance/F-*.md files and change "
                "[ ] to [x] for all completed criteria."
            )
        elif "journal_updated" in name:
            hints.append(
                "Run: bash .agentic/lib/tools/journal.sh "
                '"Topic" "What was done" "Next steps" "Blockers"'
            )
        elif "features_have_status" in name:
            hints.append(
                "Run `ag done F-XXXX` for each completed feature, or "
                "update FEATURES.md status directly."
            )

        return "\n".join(hints) if hints else ""

    # -- Delivery ------------------------------------------------------------

    def create_pr(self) -> str:
        """Push VW branch and create PR. Returns PR URL or empty string."""
        if self.total_fixes == 0:
            return ""

        # Push
        push_result = subprocess.run(
            ["git", "push", "-u", "origin", self.vw_branch],
            capture_output=True, text=True,
            cwd=str(self.project_root),
        )
        if push_result.returncode != 0:
            return f"PUSH_FAILED: {push_result.stderr.strip()}"

        self._push_succeeded = True

        # Build PR body
        body_lines = ["## Framework Verification Fixes", ""]
        for i, commit in enumerate(self.fix_commits, 1):
            body_lines.append(f"{i}. {commit}")
        body_lines.extend(["", f"Total fixes: {self.total_fixes}"])

        body = "\n".join(body_lines)

        # Create PR
        pr_result = subprocess.run(
            ["gh", "pr", "create",
             "--base", "main",
             "--head", self.vw_branch,
             "--title", f"fix: framework verification fixes ({self.total_fixes} fixes)",
             "--body", body],
            capture_output=True, text=True,
            cwd=str(self.project_root),
        )
        if pr_result.returncode != 0:
            return f"PR_FAILED: {pr_result.stderr.strip()}"

        self._pr_created = True
        return pr_result.stdout.strip()

    # -- Main entry ----------------------------------------------------------

    def run(
        self,
        scenarios: list[dict[str, Any]],
    ) -> VerifyResult:
        """Run all specified scenarios and return results."""
        result = VerifyResult(success=True)

        # Pre-flight
        errors = self.pre_flight()
        if errors:
            result.success = False
            result.messages = errors
            return result

        # Create VW
        self.create_vw()

        self._log(f"Verification started")
        self._log(f"  VW branch: {self.vw_branch}")
        self._log(f"  VW path:   {self.vw_path}")
        self._log(f"  Logs:      {self.log_dir}/")
        self._log(f"  Scenarios: {len(scenarios)}")

        # Run scenarios
        for scenario in scenarios:
            for i, settings in enumerate(scenario.get("settings_matrix", [{}])):
                if self.total_fixes >= MAX_TOTAL_FIXES:
                    result.stopped_at_max_fixes = True
                    result.messages.append(
                        f"Stopped at max fixes ({MAX_TOTAL_FIXES})"
                    )
                    break

                run = self.run_scenario(scenario, settings)
                result.runs.append(run)

                if not run.success:
                    result.success = False

            if result.stopped_at_max_fixes:
                break

        # Delivery
        result.total_fixes = self.total_fixes
        result.fix_commits = self.fix_commits
        result.log_dir = str(self.log_dir)

        if self.total_fixes > 0:
            self._log(f"Delivering {self.total_fixes} fix(es) as PR...")
            pr_url = self.create_pr()
            result.pr_url = pr_url
            self._log(f"  PR: {pr_url}")

        passed = sum(1 for r in result.runs if r.success)
        total = len(result.runs)
        self._log(f"Verification complete: {passed}/{total} passed, {self.total_fixes} fixes")
        self._log(f"Logs preserved at: {self.log_dir}/")

        return result


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _summarize_failure(
    milestones: list[MilestoneResult],
    result: SpawnResult,
) -> str:
    failed = [m for m in milestones if not m.passed]
    if failed:
        return "; ".join(f"{m.name}: {m.detail}" for m in failed)
    if result.timed_out:
        return "Build agent timed out"
    if result.returncode != 0:
        return f"Build agent exited with code {result.returncode}"
    return "Unknown failure"


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Autonomous Framework Verification Loop (F-0215)"
    )
    parser.add_argument("--project-root", required=True, help="Framework repo root")
    parser.add_argument("--project", help="Run single scenario by slug name")
    parser.add_argument("--all", action="store_true", dest="run_all",
                        help="Run all scenarios")
    parser.add_argument("--settings-index", type=int, default=None,
                        help="Run specific settings combo by index")
    parser.add_argument("--json", action="store_true", dest="json_output",
                        help="Machine-readable JSON output")
    parser.add_argument("--claude-command", default="claude",
                        help="Claude CLI command (default: claude)")
    args = parser.parse_args()

    project_root = Path(args.project_root).resolve()

    if not args.project and not args.run_all:
        parser.error("Specify --project <name> or --all")

    # Load scenarios
    if args.run_all:
        scenario_names = list_scenarios()
    elif args.project:
        scenario_names = [args.project]
    else:
        scenario_names = []

    scenarios = []
    for name in scenario_names:
        try:
            scenario = load_scenario(name)
        except FileNotFoundError:
            print(f"Error: Scenario '{name}' not found", file=sys.stderr)
            print(f"Available: {', '.join(list_scenarios())}", file=sys.stderr)
            sys.exit(1)
        # Filter settings matrix if index specified
        if args.settings_index is not None:
            matrix = scenario.get("settings_matrix", [{}])
            if args.settings_index >= len(matrix):
                print(
                    f"Error: --settings-index {args.settings_index} out of range "
                    f"(max {len(matrix) - 1})",
                    file=sys.stderr,
                )
                sys.exit(1)
            scenario["settings_matrix"] = [matrix[args.settings_index]]
        scenarios.append(scenario)

    # Run
    verifier = FrameworkVerifier(
        project_root,
        claude_command=args.claude_command,
        json_output=args.json_output,
    )
    result = verifier.run(scenarios)

    # Output
    if args.json_output:
        print(json.dumps(result.to_dict(), indent=2))
    else:
        _print_report(result)

    sys.exit(0 if result.success else 1)


def _print_report(result: VerifyResult) -> None:
    """Human-readable report."""
    print("\n" + "=" * 60)
    print("FRAMEWORK VERIFICATION REPORT")
    print("=" * 60)

    for run in result.runs:
        status = "PASS" if run.success else ("SKIP" if run.skipped else "FAIL")
        print(f"\n  [{status}] {run.scenario_name} ({run.settings_label})")
        if run.milestones:
            for m in run.milestones:
                icon = "+" if m.passed else "-"
                detail = f" — {m.detail}" if m.detail else ""
                print(f"    {icon} {m.name}{detail}")
        if run.error:
            print(f"    Error: {run.error}")
        if run.fixes:
            print(f"    Fixes applied: {len(run.fixes)}")
        if run.repairs:
            print(f"    Repairs: {len(run.repairs)}")
            for r in run.repairs:
                print(f"      + {r}")
        if run.escalations:
            print(f"    Escalated: {len(run.escalations)}")
            for e in run.escalations:
                print(f"      ! {e}")
        if run.retries > 0:
            print(f"    Retries: {run.retries}")

    print(f"\n  Total fixes: {result.total_fixes}")
    if result.pr_url:
        print(f"  PR: {result.pr_url}")
    if result.stopped_at_max_fixes:
        print(f"  WARNING: Stopped at max fixes ({MAX_TOTAL_FIXES})")
    if result.messages:
        for msg in result.messages:
            print(f"  {msg}")
    if result.log_dir:
        print(f"  Logs: {result.log_dir}/")
    print()


if __name__ == "__main__":
    main()
