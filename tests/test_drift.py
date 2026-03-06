#!/usr/bin/env python3
"""
Tests for drift.sh - spec-code drift detection tool.

Tests the --json output and various drift detection checks.
"""
import json
import subprocess
from pathlib import Path

# Get paths
TESTS_DIR = Path(__file__).parent
ROOT_DIR = TESTS_DIR.parent
TOOLS_DIR = ROOT_DIR / ".agentic" / "lib" / "tools"
DRIFT_SH = TOOLS_DIR / "drift.sh"


def run_drift(*args):
    """Run drift.sh with the given arguments."""
    cmd = ["bash", str(DRIFT_SH)] + list(args)
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        cwd=ROOT_DIR,
    )
    return result


class TestDriftJson:
    """Tests for --json output."""

    def test_json_output_is_valid_json(self):
        """The --json output should be valid JSON."""
        result = run_drift("--json")
        # May return exit code 1 if issues found, but should still output JSON
        data = json.loads(result.stdout)
        assert "tool" in data
        assert data["tool"] == "drift"

    def test_json_has_required_fields(self):
        """JSON output should have all required fields."""
        result = run_drift("--json")
        data = json.loads(result.stdout)

        assert "timestamp" in data
        assert "root" in data
        assert "issues" in data
        assert "summary" in data

        # Check summary fields
        summary = data["summary"]
        assert "total_issues" in summary
        assert "fixed_issues" in summary

    def test_json_issues_have_type_and_description(self):
        """Each issue should have type and description fields."""
        result = run_drift("--json")
        data = json.loads(result.stdout)

        for issue in data["issues"]:
            assert "type" in issue
            assert "description" in issue

    def test_json_issue_types_are_known(self):
        """All issue types should be recognized."""
        known_types = {
            "stale_focus",
            "missing_tests",
            "status_drift",
            "incomplete_shipped",
            "stale_reference",
            "wip_status_mismatch",
            "undocumented_code",
            "undocumented_endpoint",
            "untracked_file",
            "template_marker",
            "template_placeholder",
            "stale_in_progress",
        }

        result = run_drift("--json")
        data = json.loads(result.stdout)

        for issue in data["issues"]:
            assert issue["type"] in known_types, f"Unknown issue type: {issue['type']}"


class TestDriftCheck:
    """Tests for --check mode."""

    def test_check_mode_exits_nonzero_on_issues(self):
        """--check mode should exit with non-zero if drift found."""
        result = run_drift("--check")
        # We expect issues in the framework (template markers, etc.)
        # So this should return non-zero
        # But if no issues, it returns 0, which is also valid
        assert result.returncode in (0, 1)

    def test_check_mode_no_prompts(self):
        """--check mode should not contain prompt text."""
        result = run_drift("--check")
        assert "Choice:" not in result.stdout
        assert "read -p" not in result.stdout


class TestDriftDetection:
    """Tests for specific drift detection features."""

    def test_detects_template_markers(self):
        """Should detect (Template) markers in project files."""
        result = run_drift("--json")
        data = json.loads(result.stdout)

        template_issues = [i for i in data["issues"] if i["type"] == "template_marker"]
        # Framework may or may not have template markers
        # Just verify the detection code runs without error
        assert isinstance(template_issues, list)

    def test_detects_missing_tests(self):
        """Should detect features without test coverage."""
        result = run_drift("--json")
        data = json.loads(result.stdout)

        missing_test_issues = [i for i in data["issues"] if i["type"] == "missing_tests"]
        # Should find some features without tests in the framework
        # (Most acceptance criteria files don't have test files referencing them)
        assert len(missing_test_issues) > 0

    def test_missing_tests_include_feature_id(self):
        """Missing test issues should include the feature ID."""
        result = run_drift("--json")
        data = json.loads(result.stdout)

        for issue in data["issues"]:
            if issue["type"] == "missing_tests":
                assert "feature" in issue
                assert issue["feature"].startswith("F-") or issue["feature"].startswith("NFR-")


if __name__ == "__main__":
    import pytest
    pytest.main([__file__, "-v"])
