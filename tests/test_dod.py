"""Tests for Definition of Done configuration (F-0210)."""
import sys
from pathlib import Path

import pytest

# Add lib to path
_LIB = Path(__file__).resolve().parent.parent / ".agentic" / "lib"
sys.path.insert(0, str(_LIB))

from dod import (
    TYPE_ALIASES,
    clear_cache,
    format_checklist,
    get_dod_items,
    get_skipped_gates,
    parse_dod_conf,
    resolve_task_type,
)


@pytest.fixture
def project_root():
    return Path(__file__).resolve().parent.parent


class TestParseDodConf:
    """Test dod.conf parsing."""

    def test_returns_dict_of_types(self, project_root):
        conf = parse_dod_conf(project_root)
        assert isinstance(conf, dict)
        assert len(conf) >= 4  # implementation, spike, bugfix, docs

    def test_has_expected_types(self, project_root):
        conf = parse_dod_conf(project_root)
        assert "implementation" in conf
        assert "spike" in conf
        assert "bugfix" in conf
        assert "docs" in conf

    def test_each_type_has_check_keys(self, project_root):
        conf = parse_dod_conf(project_root)
        expected_keys = {
            "ac_met", "tests_exist", "tests_pass", "docs_updated",
            "code_reviewed", "smoke_tested", "journal_updated", "features_updated",
        }
        for task_type, checks in conf.items():
            assert expected_keys.issubset(checks.keys()), (
                f"Type '{task_type}' missing keys: {expected_keys - checks.keys()}"
            )

    def test_enforcement_values_are_valid(self, project_root):
        conf = parse_dod_conf(project_root)
        valid = {"required", "skip", "advisory"}
        for task_type, checks in conf.items():
            for key, value in checks.items():
                assert value in valid, (
                    f"{task_type}.{key}={value} — expected one of {valid}"
                )

    def test_implementation_all_required(self, project_root):
        """Implementation type must have all checks as 'required' to match current behavior."""
        conf = parse_dod_conf(project_root)
        impl = conf["implementation"]
        for key, value in impl.items():
            assert value == "required", (
                f"implementation.{key}={value} — must be 'required' for backward compat"
            )


class TestResolveTaskType:
    """Test task type resolution cascade."""

    def test_default_is_implementation(self, project_root):
        result = resolve_task_type("F-9999", project_root)
        assert result == "implementation"

    def test_explicit_type_wins(self, project_root):
        result = resolve_task_type("F-9999", project_root, explicit_type="spike")
        assert result == "spike"

    def test_explicit_type_normalized(self, project_root):
        result = resolve_task_type("F-9999", project_root, explicit_type="SPIKE")
        assert result == "spike"

    def test_unknown_explicit_type_falls_to_implementation(self, project_root):
        result = resolve_task_type("F-9999", project_root, explicit_type="foobar")
        assert result == "implementation"

    def test_alias_research_to_spike(self, project_root):
        assert TYPE_ALIASES["research"] == "spike"

    def test_alias_capability_to_implementation(self, project_root):
        assert TYPE_ALIASES["capability"] == "implementation"

    def test_alias_meta_to_implementation(self, project_root):
        assert TYPE_ALIASES["meta"] == "implementation"

    def test_alias_infrastructure_to_implementation(self, project_root):
        assert TYPE_ALIASES["infrastructure"] == "implementation"

    def test_empty_feature_id_returns_default(self, project_root):
        result = resolve_task_type("", project_root)
        assert result == "implementation"


class TestGetDodItems:
    """Test DoD checklist item retrieval."""

    def test_implementation_items_all_required(self, project_root):
        items = get_dod_items("implementation", project_root)
        for check_key, label, enforcement in items:
            assert enforcement == "required", (
                f"implementation {check_key} should be required, got {enforcement}"
            )

    def test_spike_skips_tests(self, project_root):
        items = get_dod_items("spike", project_root)
        items_dict = {k: e for k, _, e in items}
        assert items_dict["tests_exist"] == "skip"

    def test_spike_has_advisory_ac(self, project_root):
        items = get_dod_items("spike", project_root)
        items_dict = {k: e for k, _, e in items}
        assert items_dict["ac_met"] == "advisory"

    def test_docs_skips_tests_and_smoke(self, project_root):
        items = get_dod_items("docs", project_root)
        items_dict = {k: e for k, _, e in items}
        assert items_dict["tests_exist"] == "skip"
        assert items_dict["smoke_tested"] == "skip"

    def test_bugfix_all_required_except_docs(self, project_root):
        items = get_dod_items("bugfix", project_root)
        items_dict = {k: e for k, _, e in items}
        assert items_dict["tests_exist"] == "required"
        assert items_dict["docs_updated"] == "advisory"

    def test_unknown_type_falls_to_implementation(self, project_root):
        items = get_dod_items("nonexistent", project_root)
        for check_key, label, enforcement in items:
            assert enforcement == "required"


class TestGetSkippedGates:
    """Test gate skipping per task type."""

    def test_implementation_skips_nothing(self, project_root):
        skipped = get_skipped_gates("implementation", project_root)
        assert len(skipped) == 0

    def test_spike_skips_test_and_verification_gates(self, project_root):
        skipped = get_skipped_gates("spike", project_root)
        assert "criteria_set_to_tests_written" in skipped
        assert "implementing_to_verified" in skipped

    def test_spike_skips_doc_gate(self, project_root):
        skipped = get_skipped_gates("spike", project_root)
        assert "verified_to_documented" in skipped

    def test_docs_skips_test_gates(self, project_root):
        skipped = get_skipped_gates("docs", project_root)
        assert "criteria_set_to_tests_written" in skipped
        assert "implementing_to_verified" in skipped

    def test_bugfix_skips_nothing(self, project_root):
        skipped = get_skipped_gates("bugfix", project_root)
        assert len(skipped) == 0


class TestFormatChecklist:
    """Test checklist formatting."""

    def test_implementation_has_no_skip_markers(self, project_root):
        output = format_checklist("implementation", project_root)
        assert "[skip]" not in output
        assert "(advisory)" not in output

    def test_spike_has_skip_markers(self, project_root):
        output = format_checklist("spike", project_root)
        assert "[skip]" in output
        assert "(advisory)" in output

    def test_output_is_multiline(self, project_root):
        output = format_checklist("implementation", project_root)
        lines = output.strip().split("\n")
        assert len(lines) >= 5
