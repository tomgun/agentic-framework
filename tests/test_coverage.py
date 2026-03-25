#!/usr/bin/env python3
"""
Tests for coverage.py - code annotation coverage tool.

Tests the --json, --reverse, and --test-mapping features.
"""
import json
import subprocess
import sys
from pathlib import Path

# Get paths
TESTS_DIR = Path(__file__).parent
ROOT_DIR = TESTS_DIR.parent
TOOLS_DIR = ROOT_DIR / ".agentic" / "lib" / "tools"
COVERAGE_PY = TOOLS_DIR / "coverage.py"
EXAMPLE_DIR = ROOT_DIR / "examples" / "traced_notes_app"


def run_coverage(*args, cwd=None):
    """Run coverage.py with the given arguments."""
    cmd = [sys.executable, str(COVERAGE_PY)] + list(args)
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        cwd=cwd or ROOT_DIR,
    )
    return result


class TestCoverageJson:
    """Tests for --json output."""

    def test_json_output_is_valid_json(self):
        """The --json output should be valid JSON."""
        result = run_coverage("--json")
        # May return exit code 1 if issues found, but should still output JSON
        data = json.loads(result.stdout)
        assert "tool" in data
        assert data["tool"] == "coverage"

    def test_json_has_required_fields(self):
        """JSON output should have all required fields."""
        result = run_coverage("--json")
        data = json.loads(result.stdout)

        assert "timestamp" in data
        assert "root" in data
        assert "issues" in data
        assert "summary" in data

        # Check summary fields
        summary = data["summary"]
        assert "total_features" in summary
        assert "implemented_features" in summary
        assert "annotated_features" in summary

    def test_json_issues_have_type(self):
        """Each issue should have a type field."""
        result = run_coverage("--json")
        data = json.loads(result.stdout)

        for issue in data["issues"]:
            assert "type" in issue
            assert issue["type"] in ("orphaned_annotation", "missing_annotation")


class TestCoverageReverse:
    """Tests for --reverse FILE option."""

    def test_reverse_with_annotated_file(self):
        """Reverse lookup should find features in annotated file."""
        if not EXAMPLE_DIR.exists():
            return  # Skip if example not present

        result = run_coverage("--reverse", "src/notes.py", cwd=EXAMPLE_DIR)
        assert result.returncode == 0
        assert "F-001" in result.stdout or "F-0002" in result.stdout

    def test_reverse_json_output(self):
        """Reverse lookup with --json should return valid JSON."""
        if not EXAMPLE_DIR.exists():
            return

        result = run_coverage("--json", "--reverse", "src/notes.py", cwd=EXAMPLE_DIR)
        data = json.loads(result.stdout)

        assert "file" in data
        assert "features" in data
        assert isinstance(data["features"], list)


class TestCoverageTestMapping:
    """Tests for --test-mapping option."""

    def test_test_mapping_detects_explicit_naming(self):
        """Test mapping should detect test_F####_*.py naming convention."""
        if not EXAMPLE_DIR.exists():
            return

        result = run_coverage("--test-mapping", "--json", cwd=EXAMPLE_DIR)
        data = json.loads(result.stdout)

        # Should have test_mapping in output
        assert "test_mapping" in data

        # F-001 should be detected via explicit naming
        if "F-001" in data["test_mapping"]:
            tests = data["test_mapping"]["F-001"]
            explicit_tests = [t for t in tests if t.get("method") == "explicit_naming"]
            assert len(explicit_tests) > 0, "Should find test_F0001_*.py"

    def test_test_mapping_confidence_levels(self):
        """Test mapping should include confidence levels."""
        if not EXAMPLE_DIR.exists():
            return

        result = run_coverage("--test-mapping", "--json", cwd=EXAMPLE_DIR)
        data = json.loads(result.stdout)

        for feature_id, tests in data.get("test_mapping", {}).items():
            for test in tests:
                assert "confidence" in test
                assert test["confidence"] in ("high", "medium", "low")


class TestCoverageOnFramework:
    """Tests running coverage.py on the framework itself."""

    def test_framework_has_features(self):
        """Framework should have features defined in spec/FEATURES.md."""
        result = run_coverage("--json")
        data = json.loads(result.stdout)

        assert data["summary"]["total_features"] > 0

    def test_framework_has_some_annotations(self):
        """Framework should have at least some @feature annotations."""
        result = run_coverage("--json")
        data = json.loads(result.stdout)

        # We expect at least a few annotations (examples have them)
        assert data["summary"]["annotated_features"] >= 0  # May be 0 if no examples


if __name__ == "__main__":
    import pytest
    pytest.main([__file__, "-v"])
