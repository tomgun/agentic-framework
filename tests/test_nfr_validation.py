#!/usr/bin/env python3
"""Tests for NFR content validation in doctor.py."""
import sys
from pathlib import Path

import pytest

# Add .agentic/tools to path
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "tools"))
# Add .agentic/lib to path (for settings import)
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))

from nfr_validator import (
    parse_nfr_entries,
    validate_nfr_content,
    _is_placeholder,
    _strip_trailing_comment,
)


# --- Helper tests ---


def test_is_placeholder_pure_comment():
    assert _is_placeholder("<!-- benchmark/test/tool -->")
    assert _is_placeholder("  <!-- perf tests -->  ")


def test_is_placeholder_mixed_content():
    assert not _is_placeholder("wc -l on instruction files")
    assert not _is_placeholder("wc -l <!-- see L-0002 -->")
    assert not _is_placeholder("")


def test_strip_trailing_comment():
    assert _strip_trailing_comment("unknown  <!-- unknown | partial | met | violated -->") == "unknown"
    assert _strip_trailing_comment("met") == "met"
    assert _strip_trailing_comment("partial  ") == "partial"


# --- Parser tests ---


VALID_NFR_MD = """\
# NFR (Non-Functional Requirements)

## NFR-0001: Instruction file size limit
- Category: maintainability
- Statement: Files must be under 100 lines
- Applies to: all instruction files
- How to measure: `wc -l` on instruction files
- Where enforced:
  - Tests: tests/infrastructure/structural/S08_claude_md_under_100_lines.sh
  - CI: pre-commit-check.sh staleness detection
- Current status: met
- Notes: See L-0002

## NFR-0002: Token budget compliance
- Category: performance
- Statement: Subagent context must stay within budget
- Applies to: all context manifests
- How to measure: context-for-role.sh token counting output
- Where enforced:
  - Tests: tests/test_nfr_validation.py
  - CI: none
- Current status: met
- Notes:
"""


def test_parse_nfr_entries_count():
    entries = parse_nfr_entries(VALID_NFR_MD)
    assert len(entries) == 2


def test_parse_nfr_entries_fields():
    entries = parse_nfr_entries(VALID_NFR_MD)
    e = entries[0]
    assert e["id"] == "NFR-0001"
    assert e["category"] == "maintainability"
    assert "wc -l" in e["how_to_measure"]
    assert "S08" in e["tests"]
    assert e["current_status"] == "met"


def test_parse_nfr_entries_nested_where_enforced():
    entries = parse_nfr_entries(VALID_NFR_MD)
    assert entries[0]["tests"] == "tests/infrastructure/structural/S08_claude_md_under_100_lines.sh"
    assert entries[0]["ci"] == "pre-commit-check.sh staleness detection"
    assert entries[1]["ci"] == "none"


def test_parse_nfr_entries_strips_status_comment():
    md = """\
## NFR-0099: Test
- Category: security
- Statement: test
- How to measure: something
- Where enforced:
  - Tests: none
  - CI: none
- Current status: unknown  <!-- unknown | partial | met | violated -->
"""
    entries = parse_nfr_entries(md)
    assert entries[0]["current_status"] == "unknown"


# --- Validation tests ---


def test_validate_catches_placeholder_how_to_measure(tmp_path):
    nfr_md = """\
# NFR

## NFR-0001: Placeholder test
- Category: performance
- Statement: something
- How to measure: <!-- benchmark/test/tool -->
- Where enforced:
  - Tests: <!-- perf tests -->
  - CI: <!-- checks -->
- Current status: unknown
"""
    spec_dir = tmp_path / "spec"
    spec_dir.mkdir()
    (spec_dir / "NFR.md").write_text(nfr_md)

    issues = validate_nfr_content(tmp_path)
    assert any("placeholder" in i.lower() for i in issues)


def test_validate_catches_invalid_status(tmp_path):
    nfr_md = """\
# NFR

## NFR-0001: Bad status
- Category: performance
- Statement: something
- How to measure: run tests
- Where enforced:
  - Tests: none
  - CI: none
- Current status: excellent
"""
    spec_dir = tmp_path / "spec"
    spec_dir.mkdir()
    (spec_dir / "NFR.md").write_text(nfr_md)

    issues = validate_nfr_content(tmp_path)
    assert any("invalid status" in i.lower() for i in issues)


def test_validate_catches_invalid_category(tmp_path):
    nfr_md = """\
# NFR

## NFR-0001: Bad category
- Category: speed
- Statement: something
- How to measure: run tests
- Where enforced:
  - Tests: none
  - CI: none
- Current status: met
"""
    spec_dir = tmp_path / "spec"
    spec_dir.mkdir()
    (spec_dir / "NFR.md").write_text(nfr_md)

    issues = validate_nfr_content(tmp_path)
    assert any("invalid category" in i.lower() for i in issues)


def test_validate_catches_missing_test_file(tmp_path):
    nfr_md = """\
# NFR

## NFR-0001: Missing test
- Category: performance
- Statement: something
- How to measure: run tests
- Where enforced:
  - Tests: tests/nonexistent_test.py
  - CI: none
- Current status: met
"""
    spec_dir = tmp_path / "spec"
    spec_dir.mkdir()
    (spec_dir / "NFR.md").write_text(nfr_md)

    issues = validate_nfr_content(tmp_path)
    assert any("does not exist" in i for i in issues)


def test_validate_accepts_valid_entries(tmp_path):
    nfr_md = """\
# NFR

## NFR-0001: Valid entry
- Category: maintainability
- Statement: Files under 100 lines
- How to measure: wc -l on files
- Where enforced:
  - Tests: none
  - CI: none
- Current status: met
"""
    spec_dir = tmp_path / "spec"
    spec_dir.mkdir()
    (spec_dir / "NFR.md").write_text(nfr_md)

    issues = validate_nfr_content(tmp_path)
    assert issues == []


def test_validate_skips_when_no_nfr_file(tmp_path):
    issues = validate_nfr_content(tmp_path)
    assert issues == []


def test_validate_accepts_test_path_with_none(tmp_path):
    """Tests: none should not trigger file-not-found."""
    nfr_md = """\
# NFR

## NFR-0001: No tests
- Category: performance
- Statement: something
- How to measure: manual check
- Where enforced:
  - Tests: none
  - CI: none
- Current status: unknown
"""
    spec_dir = tmp_path / "spec"
    spec_dir.mkdir()
    (spec_dir / "NFR.md").write_text(nfr_md)

    issues = validate_nfr_content(tmp_path)
    assert issues == []


def test_validate_handles_backtick_wrapped_paths(tmp_path):
    """Backtick-wrapped test paths like `tests/foo.py` should be resolved."""
    # Create the referenced test file
    tests_dir = tmp_path / "tests"
    tests_dir.mkdir()
    (tests_dir / "real_test.py").write_text("# test")

    nfr_md = """\
# NFR

## NFR-0001: Backtick paths
- Category: performance
- Statement: something
- How to measure: run tests
- Where enforced:
  - Tests: `tests/real_test.py`
  - CI: none
- Current status: met
"""
    spec_dir = tmp_path / "spec"
    spec_dir.mkdir()
    (spec_dir / "NFR.md").write_text(nfr_md)

    issues = validate_nfr_content(tmp_path)
    assert issues == [], f"Backtick-wrapped path should resolve: {issues}"


# --- Framework dogfooding test ---


def test_framework_nfr_passes_validation():
    """The framework's own spec/NFR.md must pass content validation."""
    root = Path(__file__).parent.parent
    nfr_path = root / "spec" / "NFR.md"
    if not nfr_path.exists():
        pytest.skip("No spec/NFR.md — not running in framework repo")

    issues = validate_nfr_content(root)
    assert issues == [], f"Framework NFR.md has validation issues: {issues}"
