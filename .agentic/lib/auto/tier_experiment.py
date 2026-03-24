"""
tier_experiment.py — Complexity Tier Experiments (F-0243).

Runs the same scenario across three real configuration profiles
(discovery / formal / autonomous_formal) N times each and compares outcomes.
Produces a structured metrics report showing what each tier costs vs. buys.

Usage:
    python3 tier_experiment.py --project-root /path/to/framework \\
        --experiment complexity_tiers [--json] [--dry-run] [--single-run]

    ag auto tier-experiment --experiment complexity_tiers [--json]

Design: standalone module, NOT a subclass of FrameworkVerifier. FrameworkVerifier
has self-healing (repair agents, PR creation) that is wrong for measurement experiments.
This module imports lower-level helpers directly and focuses on observation, not repair.

VW worktree: NOT used. setup_project only needs project_root to copy .agentic/ from.
Passing project_root directly avoids AG_TRUNK_BRANCH env pollution that would confuse
spawned agents in temp project repos.

@feature F-0243
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Optional

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
sys.path.insert(0, str(_LIB_DIR / "tools"))

from auto import SpawnResult, discover_jsonl, spawn_claude  # noqa: E402
from auto.framework_verify import (  # noqa: E402
    SCENARIOS_DIR,
    build_prompt,
    load_scenario,
    setup_project,
)
from ids import FEATURE_ID_RE  # noqa: E402

EXPERIMENTS_DIR = Path(__file__).resolve().parent / "experiments"

# ---------------------------------------------------------------------------
# Lazy-loaded session-analyze (same pattern as framework_verify.py)
# ---------------------------------------------------------------------------

_session_analyze_mod = None


def _get_session_analyze() -> Any:
    """Load session-analyze.py via importlib (cached)."""
    global _session_analyze_mod
    if _session_analyze_mod is None:
        sa_path = _LIB_DIR / "tools" / "session-analyze.py"
        spec = importlib.util.spec_from_file_location("session_analyze", str(sa_path))
        _session_analyze_mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_session_analyze_mod)
    return _session_analyze_mod


# ---------------------------------------------------------------------------
# YAML loading (replicated inline — don't import private _load_yaml)
# ---------------------------------------------------------------------------

def _load_yaml(text: str) -> dict[str, Any]:
    try:
        import yaml
    except ImportError:
        raise ImportError("PyYAML is required: pip install pyyaml")
    return yaml.safe_load(text)


# ---------------------------------------------------------------------------
# Data types
# ---------------------------------------------------------------------------

@dataclass
class TierMetrics:
    """Metrics collected after a single tier experiment run.

    Universal metrics are cross-tier comparable (don't presuppose framework use).
    Framework-specific metrics capture what the framework adds at each tier.
    """

    # Identity
    tier: str
    scenario: str
    run_number: int

    # Universal (cross-tier comparison)
    app_runs: bool = False
    tests_pass: bool = False
    test_count: int = 0
    code_quality_errors: int = 0
    wall_time_seconds: float = 0.0
    total_commits: int = 0     # agent commits only (init scaffold excluded)
    code_files_count: int = 0

    # Framework-specific (what the framework adds at this tier)
    spec_created: bool = False
    plan_created: bool = False
    plan_reviewed: bool = False
    journal_updated: bool = False
    conventional_commits_pct: float = 0.0
    features_shipped: int = 0
    ac_completeness_pct: float = 0.0
    framework_log_events: int = 0
    violations: list = field(default_factory=list)  # list[dict] — 3.8-compatible annotation

    # Provenance
    timed_out: bool = False
    agent_exit_code: int = 0
    error: str = ""


@dataclass
class ExperimentResult:
    """All runs for a single experiment."""

    experiment_name: str
    runs: list = field(default_factory=list)  # list[TierMetrics]

    def by_tier(self) -> dict[str, list]:
        """Group runs by tier name."""
        result: dict[str, list] = {}
        for run in self.runs:
            result.setdefault(run.tier, []).append(run)
        return result

    def to_dict(self) -> dict:
        return {
            "experiment_name": self.experiment_name,
            "runs": [asdict(r) for r in self.runs],
        }


# ---------------------------------------------------------------------------
# Metric collection
# ---------------------------------------------------------------------------

def collect_metrics(
    project_root: Path,
    run_start_time: float,
    jsonl_log_path: Optional[Path],
    tier_name: str,
    scenario_name: str,
    run_number: int,
    spawn_result: "SpawnResult",
    test_command: Optional[str] = None,
) -> TierMetrics:
    """Collect structured metrics from a completed experiment project.

    All collectors are best-effort: missing tools/logs → default values, not errors.
    """
    m = TierMetrics(
        tier=tier_name,
        scenario=scenario_name,
        run_number=run_number,
        timed_out=spawn_result.timed_out,
        agent_exit_code=spawn_result.returncode,
    )

    m.wall_time_seconds = time.time() - run_start_time

    # app_runs + tests_pass — run pip install first, then tests separately
    if test_command:
        try:
            _collect_test_metrics(m, project_root, test_command)
        except Exception:
            pass

    # test_count — count def test_ functions
    try:
        count = 0
        for f in project_root.glob("tests/**/*.py"):
            try:
                count += len(re.findall(r"^def test_", f.read_text(), re.MULTILINE))
            except Exception:
                pass
        m.test_count = count
    except Exception:
        pass

    # code_quality_errors — ruff if available
    try:
        if shutil.which("ruff"):
            r = subprocess.run(
                ["ruff", "check", str(project_root)],
                capture_output=True, text=True, timeout=60,
            )
            m.code_quality_errors = len(r.stdout.strip().splitlines()) if r.stdout.strip() else 0
    except Exception:
        pass

    # total_commits — subtract 1 for init scaffold commit
    try:
        r = subprocess.run(
            ["git", "rev-list", "--count", "HEAD"],
            capture_output=True, text=True, cwd=str(project_root), timeout=10,
        )
        count = int(r.stdout.strip()) if r.stdout.strip().isdigit() else 0
        m.total_commits = max(0, count - 1)
    except Exception:
        pass

    # code_files_count — .py files outside .git/.agentic
    try:
        m.code_files_count = sum(
            1 for f in project_root.rglob("*.py")
            if ".git" not in f.parts and ".agentic" not in f.parts
        )
    except Exception:
        pass

    # spec_created — check for files created by the agent during this run.
    # The scaffolded project inherits existing contracts from project_root, so we
    # must only count files newer than run_start_time to avoid false positives.
    try:
        ac_dir = project_root / ".agentic" / "spec" / "acceptance"
        contracts_dir = project_root / ".agentic" / "spec" / "contracts"
        m.spec_created = any(
            f.stat().st_mtime > run_start_time
            for glob_path, pattern in [(ac_dir, "*.md"), (contracts_dir, "*.yaml")]
            if glob_path.exists()
            for f in glob_path.glob(pattern)
        )
    except Exception:
        pass

    # plan_created + plan_reviewed
    try:
        plans_dir = project_root / ".agentic" / "journal" / "plans"
        if plans_dir.exists():
            plan_files = list(plans_dir.glob("*-plan.md"))
            m.plan_created = len(plan_files) > 0
            m.plan_reviewed = any(
                re.search(r"\*\*Status\*\*:\s*APPROVED", f.read_text(), re.IGNORECASE)
                for f in plan_files
                if f.exists()
            )
    except Exception:
        pass

    # journal_updated
    try:
        journal = project_root / ".agentic" / "journal" / "JOURNAL.md"
        if journal.exists():
            m.journal_updated = "### Session:" in journal.read_text()
    except Exception:
        pass

    # conventional_commits_pct — skip init commit with --skip=1
    try:
        r = subprocess.run(
            ["git", "log", "--format=%s", "--skip=1"],
            capture_output=True, text=True, cwd=str(project_root), timeout=10,
        )
        lines = [l for l in r.stdout.strip().splitlines() if l.strip()]
        if lines:
            pattern = r"^(feat|fix|chore|docs|test|refactor|style|perf|ci|build)[\(:]"
            conventional = sum(1 for l in lines if re.match(pattern, l))
            m.conventional_commits_pct = (conventional / len(lines)) * 100.0
    except Exception:
        pass

    # features_shipped
    try:
        features_md = project_root / ".agentic" / "spec" / "FEATURES.md"
        if features_md.exists():
            text = features_md.read_text()
            m.features_shipped = len(re.findall(r"\*\*Status\*\*:\s*shipped", text, re.IGNORECASE))
    except Exception:
        pass

    # ac_completeness_pct
    try:
        features_md = project_root / ".agentic" / "spec" / "FEATURES.md"
        if features_md.exists():
            text = features_md.read_text()
            feature_ids = FEATURE_ID_RE.findall(text)
            feature_ids = list(dict.fromkeys(feature_ids))  # deduplicate, preserve order
            if feature_ids:
                ac_base = project_root / ".agentic" / "spec"
                has_ac = sum(
                    1 for fid in feature_ids
                    if (
                        (ac_base / "acceptance" / f"{fid}.md").exists() or
                        (ac_base / "contracts" / f"{fid}.yaml").exists()
                    )
                )
                m.ac_completeness_pct = (has_ac / max(len(feature_ids), 1)) * 100.0
    except Exception:
        pass

    # framework_log_events
    try:
        log_path = project_root / ".agentic" / "session" / "framework.log"
        if log_path.exists():
            count = 0
            for line in log_path.read_text().splitlines():
                parts = line.split("|")
                if len(parts) >= 3:
                    count += 1
            m.framework_log_events = count
    except Exception:
        pass

    # violations — via session-analyze
    try:
        if jsonl_log_path and jsonl_log_path.exists():
            sa = _get_session_analyze()
            events = sa.extract_events(sa.parse_jsonl(str(jsonl_log_path)))
            m.violations = sa.detect_violations(events)
    except Exception:
        m.violations = []

    return m


def _collect_test_metrics(m: TierMetrics, project_root: Path, test_command: str) -> None:
    """Run pip install and tests separately to distinguish pip vs test failures."""
    # Step 1: pip install
    pip_ok = False
    req_file = project_root / "requirements.txt"
    if req_file.exists():
        r = subprocess.run(
            [sys.executable, "-m", "pip", "install", "-q", "-r", str(req_file)],
            capture_output=True, text=True, cwd=str(project_root), timeout=120,
        )
        pip_ok = r.returncode == 0
    else:
        pip_ok = True  # No requirements file — treat as OK

    if not pip_ok:
        return  # deps failed — app_runs and tests_pass stay False

    # Step 2: app_runs — probe the entrypoint to verify a runnable app was produced.
    # Try standard entrypoint candidates with --help; accept any exit code that isn't
    # a Python traceback (import errors produce "Traceback" on stderr regardless of exit code).
    _entrypoints = ["app.py", "main.py", "src/app.py", "src/main.py"]
    entrypoint_found = False
    for candidate in _entrypoints:
        candidate_path = project_root / candidate
        if candidate_path.exists():
            entrypoint_found = True
            r2 = subprocess.run(
                [sys.executable, str(candidate_path), "--help"],
                capture_output=True, text=True,
                cwd=str(project_root), timeout=15,
            )
            # app_runs = False only if there's a traceback (import or runtime error)
            m.app_runs = "Traceback" not in r2.stderr
            break
    if not entrypoint_found:
        # No standard entrypoint found — pip install success is the best proxy
        m.app_runs = pip_ok

    # Step 3: derive pytest command from test_command (strip pip install part)
    pytest_cmd = test_command
    if "&&" in pytest_cmd:
        # Take the part after the last && (the actual test runner)
        pytest_cmd = pytest_cmd.split("&&")[-1].strip()

    r = subprocess.run(
        ["bash", "-c", pytest_cmd],
        capture_output=True, text=True, cwd=str(project_root), timeout=300,
    )
    m.tests_pass = r.returncode == 0


# ---------------------------------------------------------------------------
# Experiment loading
# ---------------------------------------------------------------------------

def load_experiment_config(name: str) -> dict[str, Any]:
    """Load an experiment config by name from the experiments/ directory."""
    path = EXPERIMENTS_DIR / f"{name}.yaml"
    if not path.exists():
        available = [p.stem for p in EXPERIMENTS_DIR.glob("*.yaml")]
        raise FileNotFoundError(
            f"Experiment config not found: {path}\n"
            f"Available: {', '.join(available) or 'none'}"
        )
    return _load_yaml(path.read_text())


# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------

def _pre_flight(project_root: Path, claude_command: str) -> list[str]:
    """Validate that we're in the right environment before running experiments."""
    errors = []

    # Framework-only guard
    if not (project_root / "FRAMEWORK_DEVELOPMENT.md").exists():
        errors.append(
            "tier-experiment is only available in the framework repo. "
            "FRAMEWORK_DEVELOPMENT.md not found. "
            "Run from the agentic-framework root directory."
        )

    # Claude CLI
    try:
        subprocess.run(
            [claude_command, "--version"],
            capture_output=True, text=True, timeout=10,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        errors.append(f"Claude CLI not found: {claude_command}")

    return errors


# ---------------------------------------------------------------------------
# Dry-run output
# ---------------------------------------------------------------------------

def _print_dry_run(experiment_config: dict[str, Any], single_run: bool) -> None:
    """Print what runs would be executed without spawning agents."""
    repetitions = 1 if single_run else experiment_config.get("repetitions", 3)
    tiers = experiment_config.get("tiers", [])
    scenarios = experiment_config.get("scenarios", [])

    total = len(tiers) * len(scenarios) * repetitions
    print(f"DRY RUN: {total} planned run(s)")
    print(f"  Experiment:   {experiment_config.get('name', 'unnamed')}")
    print(f"  Scenarios:    {scenarios}")
    print(f"  Tiers:        {[t['name'] for t in tiers]}")
    print(f"  Repetitions:  {repetitions} per tier{'  (--single-run mode)' if single_run else ''}")
    print()

    run_n = 0
    for scenario_name in scenarios:
        for tier_cfg in tiers:
            tier_name = tier_cfg["name"]
            timeout = tier_cfg.get("timeout", 3600)
            for rep in range(1, repetitions + 1):
                run_n += 1
                settings = tier_cfg.get("settings", {})
                profile = settings.get("profile", tier_name)
                print(
                    f"  Run {run_n:2d}: scenario={scenario_name} "
                    f"tier={tier_name} (profile={profile}) "
                    f"rep={rep}/{repetitions} timeout={timeout}s"
                )


# ---------------------------------------------------------------------------
# Comparison report
# ---------------------------------------------------------------------------

def _print_comparison(result: ExperimentResult) -> None:
    """Print a human-readable cross-tier comparison."""
    by_tier = result.by_tier()
    if not by_tier:
        print(f"Experiment '{result.experiment_name}': no runs recorded.")
        return

    sample_n = len(next(iter(by_tier.values())))

    print(f"\n{'='*60}")
    print(f"Experiment: {result.experiment_name}")
    print(f"Total runs: {len(result.runs)}")
    print(f"Note: n={sample_n} provides directional signal only; "
          f"per-run values shown alongside averages.")
    print(f"  total_commits excludes the init scaffold commit.")
    print()

    tier_names = list(by_tier.keys())
    # Column width: enough for the widest tier name + a typical value like "avg=1234.5 [1234,1235,1236]"
    col_w = max(28, max(len(n) for n in tier_names) + 16)

    # Universal metrics table
    universal_metrics = [
        "app_runs", "tests_pass", "test_count",
        "code_quality_errors", "wall_time_seconds",
        "total_commits", "code_files_count",
    ]

    print("UNIVERSAL METRICS (cross-tier comparison)")
    print(f"{'Metric':<30}" + "".join(f"{t:<{col_w}}" for t in tier_names))
    print("-" * (30 + col_w * len(tier_names)))

    for metric in universal_metrics:
        row = f"{metric:<30}"
        for tier in tier_names:
            runs = by_tier[tier]
            values = [getattr(r, metric) for r in runs]
            if all(isinstance(v, bool) for v in values):
                summary = f"{sum(1 for v in values if v)}/{len(values)} pass"
            elif values and all(isinstance(v, (int, float)) for v in values):
                avg = sum(values) / len(values)
                mn, mx = min(values), max(values)
                per_run = ",".join(f"{v:.0f}" if isinstance(v, float) else str(v) for v in values)
                summary = f"avg={avg:.1f} [{per_run}]"
            else:
                summary = str(values)
            row += f"{summary:<{col_w}}"
        print(row)

    # Framework-specific breakdown per tier
    fw_metrics = [
        "spec_created", "plan_created", "plan_reviewed", "journal_updated",
        "conventional_commits_pct", "features_shipped",
        "ac_completeness_pct", "framework_log_events",
    ]

    print()
    print("FRAMEWORK-SPECIFIC METRICS (per tier)")
    for tier in tier_names:
        runs = by_tier[tier]
        print(f"\n  [{tier}]")
        for metric in fw_metrics:
            values = [getattr(r, metric) for r in runs]
            if all(isinstance(v, bool) for v in values):
                per_run = f"{sum(1 for v in values if v)}/{len(values)} pass  " + \
                          "".join("✓" if v else "✗" for v in values)
            elif values and all(isinstance(v, float) for v in values):
                per_run = "  ".join(f"{v:.1f}" for v in values)
            else:
                per_run = "  ".join(str(v) for v in values)
            print(f"    {metric:<30} {per_run}")

        # Violations
        all_viols = [v for r in runs for v in (r.violations or [])]
        if all_viols:
            by_type: dict[str, int] = {}
            for v in all_viols:
                key = v.get("type", "unknown") if isinstance(v, dict) else str(v)
                by_type[key] = by_type.get(key, 0) + 1
            print(f"    {'violations':<30} {dict(by_type)}")
        else:
            print(f"    {'violations':<30} none")

    print()


# ---------------------------------------------------------------------------
# Main orchestration
# ---------------------------------------------------------------------------

def run_experiment(
    experiment_config: dict[str, Any],
    project_root: Path,
    claude_command: str = "claude",
    json_output: bool = False,
    single_run: bool = False,
) -> ExperimentResult:
    """Run the experiment: N reps per tier, collect metrics, return results."""
    experiment_name = experiment_config.get("name", "unnamed")
    result = ExperimentResult(experiment_name=experiment_name)

    repetitions = 1 if single_run else experiment_config.get("repetitions", 3)

    # Pre-flight
    errors = _pre_flight(project_root, claude_command)
    if errors:
        raise RuntimeError("Pre-flight checks failed:\n" + "\n".join(f"  - {e}" for e in errors))

    # Prepare log directory
    log_dir = project_root / ".agentic" / "session" / "tier-exp-logs"
    log_dir.mkdir(parents=True, exist_ok=True)

    ts = int(time.time())

    for scenario_name in experiment_config.get("scenarios", []):
        scenario = load_scenario(scenario_name)

        for tier_cfg in experiment_config.get("tiers", []):
            tier_name = tier_cfg["name"]
            settings = dict(tier_cfg.get("settings", {}))
            timeout = tier_cfg.get("timeout", 3600)

            for rep in range(1, repetitions + 1):
                label = f"{scenario_name}/{tier_name}/rep{rep}"
                if not json_output:
                    print(f"  → Running {label} (timeout={timeout}s)")

                project_dir = Path(tempfile.mkdtemp(prefix=f"ag-tier-{tier_name}-"))
                log_file = log_dir / f"{scenario_name}_{tier_name}_rep{rep}_{ts}.log"

                run_start = time.time()
                try:
                    # Set up project — pass project_root as vw_path (source for .agentic/ copy)
                    setup_project(scenario, project_root, project_dir, settings)

                    # Build prompt and spawn agent
                    prompt = build_prompt(scenario, settings)
                    spawn_result = spawn_claude(
                        claude_command,
                        project_dir,
                        prompt,
                        timeout=timeout,
                        log_file=log_file,
                        monitor=True,
                        monitor_interval=60,
                    )

                    # Discover JSONL log for violation analysis
                    jsonl_path = discover_jsonl(project_dir)

                    # Extract test command from scenario expectations
                    test_cmd = _extract_test_command(scenario)

                    # Collect metrics
                    metrics = collect_metrics(
                        project_root=project_dir,
                        run_start_time=run_start,
                        jsonl_log_path=jsonl_path,
                        tier_name=tier_name,
                        scenario_name=scenario_name,
                        run_number=rep,
                        spawn_result=spawn_result,
                        test_command=test_cmd,
                    )
                    result.runs.append(metrics)

                    if not json_output:
                        status = "PASS" if metrics.tests_pass else ("TIMEOUT" if metrics.timed_out else "FAIL")
                        print(f"    [{status}] {label} — {metrics.wall_time_seconds:.0f}s, "
                              f"commits={metrics.total_commits}, "
                              f"tests={metrics.test_count}")

                except Exception as exc:
                    # Record failure run rather than aborting experiment
                    m = TierMetrics(
                        tier=tier_name,
                        scenario=scenario_name,
                        run_number=rep,
                        wall_time_seconds=time.time() - run_start,
                        error=str(exc),
                    )
                    result.runs.append(m)
                    if not json_output:
                        print(f"    [ERROR] {label}: {exc}")

                finally:
                    shutil.rmtree(project_dir, ignore_errors=True)

    # Persist results to disk (recovery for long experiments)
    results_path = (
        project_root / ".agentic" / "session" / f"tier-exp-results-{ts}.json"
    )
    try:
        results_path.write_text(json.dumps(result.to_dict(), indent=2))
        if not json_output:
            print(f"\n  Results saved: {results_path}")
    except Exception:
        pass

    return result


def _extract_test_command(scenario: dict[str, Any]) -> Optional[str]:
    """Extract the primary test command from scenario expectations."""
    try:
        commands = scenario.get("expectations", {}).get("commands_pass", [])
        return commands[0] if commands else None
    except Exception:
        return None


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="F-0243: Complexity Tier Experiments — compare discovery/formal/autonomous_formal"
    )
    parser.add_argument(
        "--project-root", default=".", type=Path,
        help="Root of the framework repo (default: current directory)",
    )
    parser.add_argument(
        "--experiment", required=True,
        help="Experiment config name (e.g. complexity_tiers)",
    )
    parser.add_argument(
        "--json", action="store_true", dest="json_output",
        help="Output results as JSON",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Print planned runs without spawning agents",
    )
    parser.add_argument(
        "--single-run", action="store_true",
        help="Run 1 repetition per tier instead of full N (development mode)",
    )
    parser.add_argument(
        "--claude-command", default="claude",
        help="Claude CLI executable name (default: claude)",
    )
    args = parser.parse_args()

    experiment_config = load_experiment_config(args.experiment)

    if args.dry_run:
        _print_dry_run(experiment_config, args.single_run)
        return

    result = run_experiment(
        experiment_config,
        project_root=args.project_root.resolve(),
        claude_command=args.claude_command,
        json_output=args.json_output,
        single_run=args.single_run,
    )

    if args.json_output:
        print(json.dumps(result.to_dict(), indent=2))
    else:
        _print_comparison(result)


if __name__ == "__main__":
    main()
