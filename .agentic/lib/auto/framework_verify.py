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

import yaml

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
sys.path.insert(0, str(_LIB_DIR / "tools"))

from auto import SpawnResult, spawn_claude  # noqa: E402

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
MAX_RETRIES_PER_SCENARIO = 3
MAX_TOTAL_FIXES = 20
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
    success: bool
    milestones: list[MilestoneResult] = field(default_factory=list)
    retries: int = 0
    fixes: list[str] = field(default_factory=list)
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

    def to_dict(self) -> dict:
        return {
            "success": self.success,
            "total_fixes": self.total_fixes,
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

def load_scenario(name: str) -> dict[str, Any]:
    """Load a scenario YAML by slug name (e.g. 'todo_app')."""
    path = SCENARIOS_DIR / f"{name}.yaml"
    if not path.exists():
        raise FileNotFoundError(f"Scenario not found: {path}")
    return yaml.safe_load(path.read_text())


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

    # -- Pre-flight ----------------------------------------------------------

    def pre_flight(self) -> list[str]:
        """Run pre-flight checks. Returns list of blocking errors."""
        errors: list[str] = []

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

        for retry in range(MAX_RETRIES_PER_SCENARIO):
            if self.total_fixes >= MAX_TOTAL_FIXES:
                run.skipped = True
                run.error = "Max total fixes reached"
                return run

            run.retries = retry

            # Create fresh project
            project_dir = Path(tempfile.mkdtemp(
                prefix=f"ag-verify-{name.lower().replace(' ', '-')}-"
            ))

            try:
                # Set up project based on type
                if scenario.get("type") == "multirepo":
                    project_root = setup_multirepo_project(
                        scenario, self.vw_path, project_dir, settings
                    )
                else:
                    project_root = project_dir
                    setup_project(scenario, self.vw_path, project_dir, settings)

                # Spawn build agent
                prompt = build_prompt(scenario, settings)
                result = spawn_claude(
                    self.claude_command,
                    project_root,
                    prompt,
                    timeout=timeout,
                )

                # Check milestones
                checker = MilestoneChecker(project_root, result)
                milestones = [
                    checker.check(m) for m in scenario.get("required_milestones", [])
                ]
                run.milestones = milestones

                if all(m.passed for m in milestones):
                    run.success = True
                    return run

                # Classify failure
                from auto.self_heal import SelfHealEngine
                engine = SelfHealEngine(self.vw_path, self.claude_command)
                failure_type = engine.classify(result, milestones)

                if failure_type == "framework_bug":
                    fix_msg = engine.attempt_fix(result, milestones, name)
                    if fix_msg:
                        self.total_fixes += 1
                        self.fix_commits.append(fix_msg)
                        run.fixes.append(fix_msg)
                        # Restart from scratch (continue the retry loop)
                        continue
                    # Fix failed — fall through to retry as agent_error

                # agent_error or external — retry from scratch
                run.error = _summarize_failure(milestones, result)

            finally:
                # Clean up example project
                shutil.rmtree(project_dir, ignore_errors=True)

        return run

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

        if self.total_fixes > 0:
            pr_url = self.create_pr()
            result.pr_url = pr_url

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
    parser.add_argument("--all", action="store_true", help="Run all scenarios")
    parser.add_argument("--settings-index", type=int, default=None,
                        help="Run specific settings combo by index")
    parser.add_argument("--json", action="store_true", dest="json_output",
                        help="Machine-readable JSON output")
    parser.add_argument("--claude-command", default="claude",
                        help="Claude CLI command (default: claude)")
    args = parser.parse_args()

    project_root = Path(args.project_root).resolve()

    if not args.project and not args.all:
        parser.error("Specify --project <name> or --all")

    # Load scenarios
    if args.all:
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
    print()


if __name__ == "__main__":
    main()
