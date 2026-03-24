"""Tests for tier_experiment.py (DEV-0243) — Complexity Tier Experiments."""
from __future__ import annotations

import io
import json
import sys
import time
from dataclasses import asdict
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

_LIB = Path(__file__).resolve().parent.parent / ".agentic" / "lib"
sys.path.insert(0, str(_LIB))
sys.path.insert(0, str(_LIB / "auto"))
sys.path.insert(0, str(_LIB / "tools"))

from auto.tier_experiment import (  # noqa: E402
    ExperimentResult,
    TierMetrics,
    _print_comparison,
    _print_dry_run,
    collect_metrics,
    load_experiment_config,
)
from auto import SpawnResult  # noqa: E402


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_metrics(tier: str = "discovery", run_number: int = 1, **kwargs) -> TierMetrics:
    return TierMetrics(tier=tier, scenario="todo_app", run_number=run_number, **kwargs)


def _make_spawn_result(exit_code: int = 0, timed_out: bool = False) -> SpawnResult:
    return SpawnResult("", returncode=exit_code, timed_out=timed_out)


# ---------------------------------------------------------------------------
# TierMetrics dataclass
# ---------------------------------------------------------------------------

class TestTierMetricsDataclass:
    def test_defaults(self):
        m = TierMetrics(tier="discovery", scenario="todo_app", run_number=1)
        assert m.app_runs is False
        assert m.tests_pass is False
        assert m.test_count == 0
        assert m.code_quality_errors == 0
        assert m.wall_time_seconds == 0.0
        assert m.total_commits == 0
        assert m.code_files_count == 0
        assert m.spec_created is False
        assert m.plan_created is False
        assert m.plan_reviewed is False
        assert m.journal_updated is False
        assert m.conventional_commits_pct == 0.0
        assert m.features_shipped == 0
        assert m.ac_completeness_pct == 0.0
        assert m.framework_log_events == 0
        assert m.violations == []
        assert m.timed_out is False
        assert m.agent_exit_code == 0
        assert m.error == ""

    def test_asdict_json_serializable(self):
        m = TierMetrics(tier="formal", scenario="todo_app", run_number=2)
        d = asdict(m)
        # Must not raise
        serialized = json.dumps(d)
        assert "formal" in serialized

    def test_violations_default_empty_list(self):
        m1 = TierMetrics(tier="t", scenario="s", run_number=1)
        m2 = TierMetrics(tier="t", scenario="s", run_number=2)
        # Each instance has its own list (not shared mutable default)
        m1.violations.append({"type": "test"})
        assert m2.violations == []


# ---------------------------------------------------------------------------
# ExperimentResult
# ---------------------------------------------------------------------------

class TestExperimentResult:
    def test_by_tier_groups_correctly(self):
        result = ExperimentResult(experiment_name="test")
        for i in range(1, 4):
            result.runs.append(_make_metrics("discovery", i))
            result.runs.append(_make_metrics("formal", i))
            result.runs.append(_make_metrics("autonomous_formal", i))

        by_tier = result.by_tier()
        assert set(by_tier.keys()) == {"discovery", "formal", "autonomous_formal"}
        assert len(by_tier["discovery"]) == 3
        assert len(by_tier["formal"]) == 3

    def test_by_tier_empty(self):
        result = ExperimentResult(experiment_name="test")
        assert result.by_tier() == {}

    def test_to_dict_serializable(self):
        result = ExperimentResult(experiment_name="test-exp")
        result.runs.append(_make_metrics("discovery", 1))
        d = result.to_dict()
        # Must serialize without error
        serialized = json.dumps(d)
        assert "test-exp" in serialized

    def test_to_dict_includes_all_runs(self):
        result = ExperimentResult(experiment_name="x")
        for i in range(5):
            result.runs.append(_make_metrics("discovery", i + 1))
        assert len(result.to_dict()["runs"]) == 5


# ---------------------------------------------------------------------------
# collect_metrics — individual metric collectors
# ---------------------------------------------------------------------------

class TestCollectMetrics:
    """Tests for collect_metrics() using controlled tmp_path project directories."""

    def _make_project(self, tmp_path: Path) -> Path:
        """Create minimal project skeleton."""
        (tmp_path / ".agentic" / "session").mkdir(parents=True)
        (tmp_path / ".agentic" / "spec").mkdir(parents=True)
        (tmp_path / ".agentic" / "journal").mkdir(parents=True)
        (tmp_path / "tests").mkdir()
        return tmp_path

    def test_test_count_counts_functions(self, tmp_path):
        p = self._make_project(tmp_path)
        test_file = p / "tests" / "test_app.py"
        test_file.write_text(
            "def test_one(): pass\n"
            "def test_two(): pass\n"
            "def not_a_test(): pass\n"
            "def test_three(): pass\n"
        )
        m = collect_metrics(
            project_root=p,
            run_start_time=time.time() - 1,
            jsonl_log_path=None,
            tier_name="discovery",
            scenario_name="todo_app",
            run_number=1,
            spawn_result=_make_spawn_result(),
        )
        assert m.test_count == 3

    def test_test_count_zero_no_tests(self, tmp_path):
        p = self._make_project(tmp_path)
        m = collect_metrics(
            project_root=p,
            run_start_time=time.time() - 1,
            jsonl_log_path=None,
            tier_name="discovery",
            scenario_name="todo_app",
            run_number=1,
            spawn_result=_make_spawn_result(),
        )
        assert m.test_count == 0

    def test_spec_created_true_with_acceptance_file(self, tmp_path):
        p = self._make_project(tmp_path)
        ac_dir = p / ".agentic" / "spec" / "acceptance"
        ac_dir.mkdir(parents=True)
        (ac_dir / "F-0001.md").write_text("# AC")
        m = collect_metrics(
            project_root=p,
            run_start_time=time.time() - 1,
            jsonl_log_path=None,
            tier_name="discovery",
            scenario_name="todo_app",
            run_number=1,
            spawn_result=_make_spawn_result(),
        )
        assert m.spec_created is True

    def test_spec_created_false_when_empty(self, tmp_path):
        p = self._make_project(tmp_path)
        m = collect_metrics(
            project_root=p,
            run_start_time=time.time() - 1,
            jsonl_log_path=None,
            tier_name="discovery",
            scenario_name="todo_app",
            run_number=1,
            spawn_result=_make_spawn_result(),
        )
        assert m.spec_created is False

    def test_spec_created_true_with_contract_file(self, tmp_path):
        p = self._make_project(tmp_path)
        contracts_dir = p / ".agentic" / "spec" / "contracts"
        contracts_dir.mkdir(parents=True)
        (contracts_dir / "F-0001.yaml").write_text("id: F-0001")
        m = collect_metrics(
            project_root=p,
            run_start_time=time.time() - 1,
            jsonl_log_path=None,
            tier_name="formal",
            scenario_name="todo_app",
            run_number=1,
            spawn_result=_make_spawn_result(),
        )
        assert m.spec_created is True

    def test_plan_created_and_reviewed(self, tmp_path):
        p = self._make_project(tmp_path)
        plans_dir = p / ".agentic" / "journal" / "plans"
        plans_dir.mkdir(parents=True)
        plan_file = plans_dir / "2026-01-01-F-0001-plan.md"
        plan_file.write_text("**Status**: APPROVED\n\n# Plan\nSome content")
        m = collect_metrics(
            project_root=p,
            run_start_time=time.time() - 1,
            jsonl_log_path=None,
            tier_name="formal",
            scenario_name="todo_app",
            run_number=1,
            spawn_result=_make_spawn_result(),
        )
        assert m.plan_created is True
        assert m.plan_reviewed is True

    def test_plan_created_not_reviewed_when_draft(self, tmp_path):
        p = self._make_project(tmp_path)
        plans_dir = p / ".agentic" / "journal" / "plans"
        plans_dir.mkdir(parents=True)
        (plans_dir / "2026-01-01-F-0001-plan.md").write_text("**Status**: DRAFT")
        m = collect_metrics(
            project_root=p,
            run_start_time=time.time() - 1,
            jsonl_log_path=None,
            tier_name="formal",
            scenario_name="todo_app",
            run_number=1,
            spawn_result=_make_spawn_result(),
        )
        assert m.plan_created is True
        assert m.plan_reviewed is False

    def test_journal_updated_with_session_entry(self, tmp_path):
        p = self._make_project(tmp_path)
        journal = p / ".agentic" / "journal" / "JOURNAL.md"
        journal.write_text("# Journal\n\n### Session: 2026-01-01\nSome notes\n")
        m = collect_metrics(
            project_root=p,
            run_start_time=time.time() - 1,
            jsonl_log_path=None,
            tier_name="discovery",
            scenario_name="todo_app",
            run_number=1,
            spawn_result=_make_spawn_result(),
        )
        assert m.journal_updated is True

    def test_journal_updated_false_when_no_session(self, tmp_path):
        p = self._make_project(tmp_path)
        journal = p / ".agentic" / "journal" / "JOURNAL.md"
        journal.write_text("# Journal\n\nNo sessions yet.\n")
        m = collect_metrics(
            project_root=p,
            run_start_time=time.time() - 1,
            jsonl_log_path=None,
            tier_name="discovery",
            scenario_name="todo_app",
            run_number=1,
            spawn_result=_make_spawn_result(),
        )
        assert m.journal_updated is False

    def test_features_shipped_count(self, tmp_path):
        p = self._make_project(tmp_path)
        features_md = p / ".agentic" / "spec" / "FEATURES.md"
        features_md.write_text(
            "## F-0001\n**Status**: shipped\n\n"
            "## F-0002\n**Status**: shipped\n\n"
            "## F-0003\n**Status**: planned\n\n"
        )
        m = collect_metrics(
            project_root=p,
            run_start_time=time.time() - 1,
            jsonl_log_path=None,
            tier_name="formal",
            scenario_name="todo_app",
            run_number=1,
            spawn_result=_make_spawn_result(),
        )
        assert m.features_shipped == 2

    def test_framework_log_events_count(self, tmp_path):
        p = self._make_project(tmp_path)
        log = p / ".agentic" / "session" / "framework.log"
        log.write_text(
            "2026-01-01T00:00:01Z|ag.sh|kickoff|todo-app|start\n"
            "2026-01-01T00:00:02Z|ag.sh|implement|F-0001|start\n"
            "2026-01-01T00:00:03Z|pre-commit|check|6|pass\n"
            "malformed line without pipes\n"
            "a|b\n"  # only 2 fields — not counted
        )
        m = collect_metrics(
            project_root=p,
            run_start_time=time.time() - 1,
            jsonl_log_path=None,
            tier_name="discovery",
            scenario_name="todo_app",
            run_number=1,
            spawn_result=_make_spawn_result(),
        )
        assert m.framework_log_events == 3

    def test_framework_log_missing_is_zero(self, tmp_path):
        p = self._make_project(tmp_path)
        m = collect_metrics(
            project_root=p,
            run_start_time=time.time() - 1,
            jsonl_log_path=None,
            tier_name="discovery",
            scenario_name="todo_app",
            run_number=1,
            spawn_result=_make_spawn_result(),
        )
        assert m.framework_log_events == 0

    def test_wall_time_positive(self, tmp_path):
        p = self._make_project(tmp_path)
        start = time.time() - 5
        m = collect_metrics(
            project_root=p,
            run_start_time=start,
            jsonl_log_path=None,
            tier_name="discovery",
            scenario_name="todo_app",
            run_number=1,
            spawn_result=_make_spawn_result(),
        )
        assert m.wall_time_seconds >= 5.0

    def test_timed_out_propagated(self, tmp_path):
        p = self._make_project(tmp_path)
        m = collect_metrics(
            project_root=p,
            run_start_time=time.time() - 1,
            jsonl_log_path=None,
            tier_name="discovery",
            scenario_name="todo_app",
            run_number=1,
            spawn_result=_make_spawn_result(exit_code=-1, timed_out=True),
        )
        assert m.timed_out is True
        assert m.agent_exit_code == -1

    def test_violations_empty_when_no_jsonl(self, tmp_path):
        p = self._make_project(tmp_path)
        m = collect_metrics(
            project_root=p,
            run_start_time=time.time() - 1,
            jsonl_log_path=None,
            tier_name="discovery",
            scenario_name="todo_app",
            run_number=1,
            spawn_result=_make_spawn_result(),
        )
        assert m.violations == []

    def test_conventional_commits_pct_with_mock(self, tmp_path):
        p = self._make_project(tmp_path)
        # Mock git log to return known commit messages (skipping init commit via --skip=1)
        git_output = "feat: add todo endpoint\nfix: handle empty input\nchore: bump deps\n"
        with patch("subprocess.run") as mock_run:
            def side_effect(cmd, **kwargs):
                result = MagicMock()
                result.returncode = 0
                if "log" in cmd and "--skip=1" in cmd:
                    result.stdout = git_output
                elif "rev-list" in cmd:
                    result.stdout = "4\n"  # 4 total, 3 agent commits
                else:
                    result.stdout = ""
                return result
            mock_run.side_effect = side_effect

            m = collect_metrics(
                project_root=p,
                run_start_time=time.time() - 1,
                jsonl_log_path=None,
                tier_name="discovery",
                scenario_name="todo_app",
                run_number=1,
                spawn_result=_make_spawn_result(),
            )
        assert m.conventional_commits_pct == pytest.approx(100.0)
        assert m.total_commits == 3  # 4 - 1 (init)

    def test_ac_completeness_zero_features(self, tmp_path):
        p = self._make_project(tmp_path)
        features_md = p / ".agentic" / "spec" / "FEATURES.md"
        features_md.write_text("# Features\n\nNo features yet.\n")
        m = collect_metrics(
            project_root=p,
            run_start_time=time.time() - 1,
            jsonl_log_path=None,
            tier_name="discovery",
            scenario_name="todo_app",
            run_number=1,
            spawn_result=_make_spawn_result(),
        )
        # Should not divide by zero
        assert m.ac_completeness_pct == 0.0


# ---------------------------------------------------------------------------
# Load experiment config
# ---------------------------------------------------------------------------

class TestLoadExperimentConfig:
    def test_loads_complexity_tiers(self):
        config = load_experiment_config("complexity_tiers")
        assert isinstance(config, dict)
        tier_names = {t["name"] for t in config["tiers"]}
        assert tier_names == {"discovery", "formal", "autonomous_formal"}
        for tier in config["tiers"]:
            assert "profile" in tier["settings"]
        assert config["repetitions"] == 3
        assert config["scenarios"] == ["todo_app"]

    def test_formal_tier_has_blocking_overrides(self):
        """Formal tier must override review_plan/review_commit to avoid deadlock."""
        config = load_experiment_config("complexity_tiers")
        formal = next(t for t in config["tiers"] if t["name"] == "formal")
        assert formal["settings"].get("review_merge") == "skip"
        assert formal["settings"].get("review_plan") == "critical_agent"
        assert formal["settings"].get("review_commit") == "critical_agent"

    def test_all_tiers_have_timeout(self):
        config = load_experiment_config("complexity_tiers")
        for tier in config["tiers"]:
            assert "timeout" in tier, f"Tier {tier['name']} missing timeout"
            assert tier["timeout"] > 0

    def test_load_missing_raises_file_not_found(self):
        with pytest.raises(FileNotFoundError):
            load_experiment_config("nonexistent_experiment_xyz")

    def test_tier_settings_have_profile_key(self):
        config = load_experiment_config("complexity_tiers")
        for tier in config["tiers"]:
            assert "profile" in tier["settings"], \
                f"Tier {tier['name']} settings missing 'profile' key"


# ---------------------------------------------------------------------------
# Dry-run output
# ---------------------------------------------------------------------------

class TestDryRun:
    def test_prints_9_runs_for_full_experiment(self, capsys):
        config = load_experiment_config("complexity_tiers")
        _print_dry_run(config, single_run=False)
        captured = capsys.readouterr()
        # 3 tiers × 1 scenario × 3 reps = 9 runs
        run_lines = [l for l in captured.out.splitlines() if l.strip().startswith("Run")]
        assert len(run_lines) == 9

    def test_prints_3_runs_for_single_run(self, capsys):
        config = load_experiment_config("complexity_tiers")
        _print_dry_run(config, single_run=True)
        captured = capsys.readouterr()
        # 3 tiers × 1 scenario × 1 rep = 3 runs
        run_lines = [l for l in captured.out.splitlines() if l.strip().startswith("Run")]
        assert len(run_lines) == 3

    def test_shows_all_tier_names(self, capsys):
        config = load_experiment_config("complexity_tiers")
        _print_dry_run(config, single_run=False)
        captured = capsys.readouterr()
        assert "discovery" in captured.out
        assert "formal" in captured.out
        assert "autonomous_formal" in captured.out

    def test_shows_dry_run_header(self, capsys):
        config = load_experiment_config("complexity_tiers")
        _print_dry_run(config, single_run=False)
        captured = capsys.readouterr()
        assert "DRY RUN" in captured.out


# ---------------------------------------------------------------------------
# Comparison report
# ---------------------------------------------------------------------------

class TestPrintComparison:
    def _make_result(self) -> ExperimentResult:
        result = ExperimentResult(experiment_name="test-exp")
        for tier in ("discovery", "formal", "autonomous_formal"):
            for i in range(1, 3):
                result.runs.append(_make_metrics(
                    tier=tier,
                    run_number=i,
                    tests_pass=True,
                    test_count=10 + i,
                    wall_time_seconds=float(100 + i),
                    total_commits=i + 2,
                    spec_created=(tier != "discovery"),
                    features_shipped=i,
                ))
        return result

    def test_prints_tier_names(self, capsys):
        result = self._make_result()
        _print_comparison(result)
        captured = capsys.readouterr()
        assert "discovery" in captured.out
        assert "formal" in captured.out
        assert "autonomous_formal" in captured.out

    def test_prints_avg_label(self, capsys):
        result = self._make_result()
        _print_comparison(result)
        captured = capsys.readouterr()
        assert "avg=" in captured.out

    def test_prints_statistical_caveat(self, capsys):
        result = self._make_result()
        _print_comparison(result)
        captured = capsys.readouterr()
        assert "directional" in captured.out or "n=" in captured.out

    def test_handles_empty_runs_gracefully(self, capsys):
        result = ExperimentResult(experiment_name="empty")
        _print_comparison(result)  # Should not raise
        captured = capsys.readouterr()
        assert "empty" in captured.out or "no runs" in captured.out.lower()
