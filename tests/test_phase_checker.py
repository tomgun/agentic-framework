"""Tests for PhaseChecker (F-0242) — intermediate workflow phase verification."""

import sys
from pathlib import Path

import pytest

# Framework lib paths
_LIB = Path(__file__).resolve().parent.parent / ".agentic" / "lib"
sys.path.insert(0, str(_LIB))
sys.path.insert(0, str(_LIB / "tools"))

from auto.framework_verify import PhaseChecker, MilestoneResult  # noqa: E402


# ---------------------------------------------------------------------------
# Framework.log parsing
# ---------------------------------------------------------------------------

class TestParseLog:
    def test_parse_valid_entries(self, tmp_path):
        log = tmp_path / ".agentic" / "session" / "framework.log"
        log.parent.mkdir(parents=True)
        log.write_text(
            "2026-03-20T10:45:23Z|ag.sh|kickoff|todo-app|start\n"
            "2026-03-20T10:45:24Z|ag.sh|kickoff|todo-app|end:0\n"
            "2026-03-20T10:46:00Z|ag.sh|implement|F-0001|start\n"
        )
        checker = PhaseChecker(tmp_path)
        entries = checker._parse_log()
        assert len(entries) == 3
        assert entries[0]["script"] == "ag.sh"
        assert entries[0]["verb"] == "kickoff"
        assert entries[0]["args"] == "todo-app"
        assert entries[0]["result"] == "start"

    def test_parse_empty_file(self, tmp_path):
        log = tmp_path / ".agentic" / "session" / "framework.log"
        log.parent.mkdir(parents=True)
        log.write_text("")
        checker = PhaseChecker(tmp_path)
        assert checker._parse_log() == []

    def test_parse_missing_file(self, tmp_path):
        checker = PhaseChecker(tmp_path)
        assert checker._parse_log() == []

    def test_parse_malformed_lines(self, tmp_path):
        log = tmp_path / ".agentic" / "session" / "framework.log"
        log.parent.mkdir(parents=True)
        log.write_text(
            "bad line\n"
            "\n"
            "ok|only-two\n"
            "2026-03-20T10:00:00Z|ag.sh|kickoff|args|result\n"
        )
        checker = PhaseChecker(tmp_path)
        entries = checker._parse_log()
        assert len(entries) == 1  # Only the valid 5-field line
        assert entries[0]["verb"] == "kickoff"

    def test_parse_entries_with_empty_fields(self, tmp_path):
        log = tmp_path / ".agentic" / "session" / "framework.log"
        log.parent.mkdir(parents=True)
        log.write_text("2026-03-20T10:00:00Z|ag.sh|kickoff||\n")
        checker = PhaseChecker(tmp_path)
        entries = checker._parse_log()
        assert len(entries) == 1
        assert entries[0]["args"] == ""
        assert entries[0]["result"] == ""

    def test_parse_caches_result(self, tmp_path):
        log = tmp_path / ".agentic" / "session" / "framework.log"
        log.parent.mkdir(parents=True)
        log.write_text("2026-03-20T10:00:00Z|ag.sh|kickoff|x|start\n")
        checker = PhaseChecker(tmp_path)
        result1 = checker._parse_log()
        result2 = checker._parse_log()
        assert result1 is result2  # Same object — cached


# ---------------------------------------------------------------------------
# Phase detection
# ---------------------------------------------------------------------------

class TestFindPhase:
    def _make_checker(self, tmp_path, log_content):
        log = tmp_path / ".agentic" / "session" / "framework.log"
        log.parent.mkdir(parents=True)
        log.write_text(log_content)
        return PhaseChecker(tmp_path)

    def test_find_phase_match(self, tmp_path):
        checker = self._make_checker(tmp_path,
            "2026-03-20T10:00:00Z|ag.sh|kickoff|todo|start\n"
            "2026-03-20T10:01:00Z|ag.sh|implement|F-0001|start\n"
        )
        result = checker._find_phase({"framework_log": "ag.sh|implement"})
        assert result is not None
        assert result["verb"] == "implement"
        assert result["args"] == "F-0001"

    def test_find_phase_no_match(self, tmp_path):
        checker = self._make_checker(tmp_path,
            "2026-03-20T10:00:00Z|ag.sh|kickoff|todo|start\n"
        )
        result = checker._find_phase({"framework_log": "ag.sh|implement"})
        assert result is None

    def test_find_phase_with_result_filter_pass(self, tmp_path):
        checker = self._make_checker(tmp_path,
            "2026-03-20T10:00:00Z|ag.sh|kickoff|todo|start\n"
            "2026-03-20T10:00:01Z|ag.sh|kickoff|todo|end:0\n"
        )
        # Should find the start entry
        result = checker._find_phase({"framework_log": "ag.sh|kickoff"}, require_result="start")
        assert result is not None
        assert result["result"] == "start"

    def test_find_phase_with_result_filter_skip(self, tmp_path):
        checker = self._make_checker(tmp_path,
            "2026-03-20T10:00:00Z|ag.sh|kickoff|todo|end:1\n"
        )
        # Require "start" but only "end:1" exists
        result = checker._find_phase({"framework_log": "ag.sh|kickoff"}, require_result="start")
        assert result is None

    def test_find_phase_substring_match(self, tmp_path):
        checker = self._make_checker(tmp_path,
            "2026-03-20T10:00:00Z|pre-commit-check.sh|run|full|start\n"
        )
        result = checker._find_phase({"framework_log": "pre-commit|run"})
        assert result is not None

    def test_find_phase_empty_pattern(self, tmp_path):
        checker = self._make_checker(tmp_path,
            "2026-03-20T10:00:00Z|ag.sh|kickoff|todo|start\n"
        )
        result = checker._find_phase({"framework_log": ""})
        assert result is None

    def test_find_phase_empty_log(self, tmp_path):
        checker = PhaseChecker(tmp_path)  # No log file
        result = checker._find_phase({"framework_log": "ag.sh|kickoff"})
        assert result is None


# ---------------------------------------------------------------------------
# State checking
# ---------------------------------------------------------------------------

class TestCheckState:
    def test_files_exist_pass(self, tmp_path):
        (tmp_path / ".agentic" / "spec").mkdir(parents=True)
        (tmp_path / ".agentic" / "spec" / "FEATURES.md").write_text("# Features\nF-0001")
        checker = PhaseChecker(tmp_path)
        passed, detail = checker._check_state({
            "files_exist": [".agentic/spec/FEATURES.md"],
        })
        assert passed

    def test_files_exist_fail(self, tmp_path):
        checker = PhaseChecker(tmp_path)
        passed, detail = checker._check_state({
            "files_exist": [".agentic/spec/FEATURES.md"],
        })
        assert not passed
        assert "no match" in detail

    def test_files_exist_glob(self, tmp_path):
        ac_dir = tmp_path / ".agentic" / "spec" / "acceptance"
        ac_dir.mkdir(parents=True)
        (ac_dir / "F-0001.md").write_text("# AC")
        checker = PhaseChecker(tmp_path)
        passed, detail = checker._check_state({
            "files_exist": [".agentic/spec/acceptance/F-*.md"],
        })
        assert passed

    def test_file_contains_pass(self, tmp_path):
        features = tmp_path / ".agentic" / "spec" / "FEATURES.md"
        features.parent.mkdir(parents=True)
        features.write_text("# Features\n## F-0001: Todo App\nStatus: planned\n")
        checker = PhaseChecker(tmp_path)
        passed, detail = checker._check_state({
            "file_contains": [
                {"path": ".agentic/spec/FEATURES.md", "pattern": r"F-\d{4}"},
            ],
        })
        assert passed

    def test_file_contains_fail(self, tmp_path):
        features = tmp_path / ".agentic" / "spec" / "FEATURES.md"
        features.parent.mkdir(parents=True)
        features.write_text("# Features\nNothing here\n")
        checker = PhaseChecker(tmp_path)
        passed, detail = checker._check_state({
            "file_contains": [
                {"path": ".agentic/spec/FEATURES.md", "pattern": r"F-\d{4}"},
            ],
        })
        assert not passed
        assert "not in" in detail

    def test_file_contains_missing_file(self, tmp_path):
        checker = PhaseChecker(tmp_path)
        passed, detail = checker._check_state({
            "file_contains": [
                {"path": "nonexistent.md", "pattern": "anything"},
            ],
        })
        assert not passed
        assert "not found" in detail

    def test_empty_state(self, tmp_path):
        checker = PhaseChecker(tmp_path)
        passed, detail = checker._check_state({})
        assert passed


# ---------------------------------------------------------------------------
# Full check_all integration
# ---------------------------------------------------------------------------

class TestCheckAll:
    def test_full_integration(self, tmp_path):
        # Set up framework.log
        log = tmp_path / ".agentic" / "session" / "framework.log"
        log.parent.mkdir(parents=True)
        log.write_text(
            "2026-03-20T10:00:00Z|ag.sh|kickoff|todo|start\n"
            "2026-03-20T10:01:00Z|ag.sh|implement|F-0001|start\n"
        )
        # Set up expected files
        features = tmp_path / ".agentic" / "spec" / "FEATURES.md"
        features.parent.mkdir(parents=True)
        features.write_text("# Features\n## F-0001: Todo\n")
        ac_dir = tmp_path / ".agentic" / "spec" / "acceptance"
        ac_dir.mkdir(parents=True)
        (ac_dir / "F-0001.md").write_text("# AC for F-0001\n- [x] Done\n")

        checker = PhaseChecker(tmp_path)
        results = checker.check_all([
            {
                "phase": "kickoff",
                "detect_via": {"framework_log": "ag.sh|kickoff"},
                "state": {
                    "files_exist": [".agentic/spec/FEATURES.md"],
                    "file_contains": [
                        {"path": ".agentic/spec/FEATURES.md", "pattern": r"F-\d{4}"},
                    ],
                },
            },
            {
                "phase": "implement",
                "detect_via": {"framework_log": "ag.sh|implement"},
                "state": {
                    "files_exist": [".agentic/spec/acceptance/F-*.md"],
                },
            },
        ])

        assert len(results) == 2
        assert all(isinstance(r, MilestoneResult) for r in results)
        assert results[0].name == "phase(kickoff)"
        assert results[0].passed
        assert results[1].name == "phase(implement)"
        assert results[1].passed

    def test_missing_phase_fails(self, tmp_path):
        log = tmp_path / ".agentic" / "session" / "framework.log"
        log.parent.mkdir(parents=True)
        log.write_text("2026-03-20T10:00:00Z|ag.sh|kickoff|todo|start\n")

        checker = PhaseChecker(tmp_path)
        results = checker.check_all([
            {
                "phase": "implement",
                "detect_via": {"framework_log": "ag.sh|implement"},
            },
        ])
        assert len(results) == 1
        assert not results[0].passed
        assert "not found" in results[0].detail

    def test_phase_found_but_state_fails(self, tmp_path):
        log = tmp_path / ".agentic" / "session" / "framework.log"
        log.parent.mkdir(parents=True)
        log.write_text("2026-03-20T10:00:00Z|ag.sh|kickoff|todo|start\n")

        checker = PhaseChecker(tmp_path)
        results = checker.check_all([
            {
                "phase": "kickoff",
                "detect_via": {"framework_log": "ag.sh|kickoff"},
                "state": {
                    "files_exist": [".agentic/spec/FEATURES.md"],
                },
            },
        ])
        assert len(results) == 1
        assert not results[0].passed
        assert "no match" in results[0].detail

    def test_empty_expectations_returns_empty(self, tmp_path):
        checker = PhaseChecker(tmp_path)
        results = checker.check_all([])
        assert results == []

    def test_phase_without_state_check(self, tmp_path):
        log = tmp_path / ".agentic" / "session" / "framework.log"
        log.parent.mkdir(parents=True)
        log.write_text("2026-03-20T10:00:00Z|ag.sh|kickoff|todo|start\n")

        checker = PhaseChecker(tmp_path)
        results = checker.check_all([
            {
                "phase": "kickoff",
                "detect_via": {"framework_log": "ag.sh|kickoff"},
            },
        ])
        assert len(results) == 1
        assert results[0].passed
        assert "detected" in results[0].detail
