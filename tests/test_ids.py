#!/usr/bin/env python3
"""
Tests for ids.py — centralized ID patterns and formatting.

@feature F-0004 (consolidated from F-0193)
@feature F-0184
"""
import sys
import textwrap
from pathlib import Path

import pytest

# Add paths for imports
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))

from ids import (
    FEATURE_ID_RE,
    FEATURE_HEADER_RE,
    FEATURE_ID_STRICT_RE,
    MAX_DEPTH,
    is_valid_feature_id,
    format_feature_id,
    get_next_feature_id,
    get_parent_id,
    get_depth,
    get_root_id,
    get_next_child_id,
)


# ---------------------------------------------------------------------------
# format_feature_id
# ---------------------------------------------------------------------------

class TestFormatFeatureId:
    def test_single_digit(self):
        assert format_feature_id(1) == "F-0001"

    def test_typical_id(self):
        assert format_feature_id(233) == "F-0233"

    def test_four_digit_boundary(self):
        assert format_feature_id(9999) == "F-9999"

    def test_five_digit(self):
        assert format_feature_id(10000) == "F-10000"

    def test_large_id(self):
        assert format_feature_id(99999) == "F-99999"

    def test_dev_prefix(self):
        assert format_feature_id(1, prefix="DEV") == "DEV-0001"
        assert format_feature_id(243, prefix="DEV") == "DEV-0243"

    def test_epic_prefix(self):
        assert format_feature_id(1, prefix="E") == "E-0001"

    def test_width_3(self):
        assert format_feature_id(1, width=3) == "F-001"
        assert format_feature_id(42, width=3) == "F-042"
        assert format_feature_id(999, width=3) == "F-999"
        assert format_feature_id(1000, width=3) == "F-1000"

    def test_default_width_is_4(self):
        assert format_feature_id(3) == "F-0003"


# ---------------------------------------------------------------------------
# is_valid_feature_id
# ---------------------------------------------------------------------------

class TestIsValidFeatureId:
    def test_standard_id(self):
        assert is_valid_feature_id("F-0001")
        assert is_valid_feature_id("F-0233")
        assert is_valid_feature_id("F-9999")

    def test_three_digit_id(self):
        assert is_valid_feature_id("F-001")
        assert is_valid_feature_id("F-042")
        assert is_valid_feature_id("F-999")

    def test_five_digit_id(self):
        assert is_valid_feature_id("F-10000")
        assert is_valid_feature_id("F-99999")

    def test_dev_prefix(self):
        assert is_valid_feature_id("DEV-0001")
        assert is_valid_feature_id("DEV-0243")
        assert is_valid_feature_id("DEV-10000")
        assert is_valid_feature_id("DEV-001")

    def test_epic_prefix(self):
        assert is_valid_feature_id("E-0001")
        assert is_valid_feature_id("E-9999")
        assert is_valid_feature_id("E-001")

    def test_dotted_child(self):
        assert is_valid_feature_id("F-003.1")
        assert is_valid_feature_id("F-003.12")
        assert is_valid_feature_id("F-0003.1")
        assert is_valid_feature_id("DEV-001.1")

    def test_dotted_grandchild(self):
        assert is_valid_feature_id("F-003.1.2")
        assert is_valid_feature_id("F-003.1.12")
        assert is_valid_feature_id("F-0003.1.2")

    def test_dotted_zero_rejected(self):
        assert not is_valid_feature_id("F-003.0")
        assert not is_valid_feature_id("F-003.1.0")
        assert not is_valid_feature_id("F-003.0.1")

    def test_too_short(self):
        assert not is_valid_feature_id("F-01")
        assert not is_valid_feature_id("F-1")
        assert not is_valid_feature_id("DEV-01")

    def test_not_numeric(self):
        assert not is_valid_feature_id("F-abcd")
        assert not is_valid_feature_id("F-00ab")

    def test_wrong_prefix(self):
        assert not is_valid_feature_id("G-0001")
        assert not is_valid_feature_id("NFR-0001")

    def test_no_prefix(self):
        assert not is_valid_feature_id("0001")
        assert not is_valid_feature_id("")

    def test_extra_content(self):
        assert not is_valid_feature_id("F-0001 extra")
        assert not is_valid_feature_id(" F-0001")

    def test_trailing_dot_rejected(self):
        assert not is_valid_feature_id("F-003.")
        assert not is_valid_feature_id("F-003.1.")


# ---------------------------------------------------------------------------
# FEATURE_ID_RE (inline reference pattern)
# ---------------------------------------------------------------------------

class TestFeatureIdRe:
    def test_inline_match(self):
        matches = FEATURE_ID_RE.findall("Depends on F-0042 and F-0193")
        assert matches == ["F-0042", "F-0193"]

    def test_five_digit_inline(self):
        matches = FEATURE_ID_RE.findall("See F-10000 for details")
        assert matches == ["F-10000"]

    def test_three_digit_inline(self):
        matches = FEATURE_ID_RE.findall("See F-003 and F-042 for details")
        assert matches == ["F-003", "F-042"]

    def test_dev_inline_match(self):
        matches = FEATURE_ID_RE.findall("See DEV-0001 and DEV-0243 for infra")
        assert matches == ["DEV-0001", "DEV-0243"]

    def test_epic_inline_match(self):
        matches = FEATURE_ID_RE.findall("Epic E-0001 tracks this")
        assert matches == ["E-0001"]

    def test_mixed_prefixes(self):
        matches = FEATURE_ID_RE.findall("F-0042 depends on DEV-0122 and E-0001")
        assert matches == ["F-0042", "DEV-0122", "E-0001"]

    def test_dotted_inline_match(self):
        matches = FEATURE_ID_RE.findall("See F-003.1 and F-003.1.2 for hierarchy")
        assert matches == ["F-003.1", "F-003.1.2"]

    def test_no_partial_match(self):
        matches = FEATURE_ID_RE.findall("Not F-01 or F-12")
        assert matches == []

    def test_dotted_zero_not_matched(self):
        matches = FEATURE_ID_RE.findall("Bad F-003.0 id")
        assert matches == ["F-003"]


# ---------------------------------------------------------------------------
# FEATURE_HEADER_RE (markdown header pattern)
# ---------------------------------------------------------------------------

class TestFeatureHeaderRe:
    def test_standard_header(self):
        m = FEATURE_HEADER_RE.match("## F-0042: Some Feature Name")
        assert m is not None
        assert m.group(1) == "F-0042"
        assert m.group(2) == "Some Feature Name"

    def test_three_digit_header(self):
        m = FEATURE_HEADER_RE.match("## F-003: Some Feature")
        assert m is not None
        assert m.group(1) == "F-003"

    def test_five_digit_header(self):
        m = FEATURE_HEADER_RE.match("## F-10000: Future Feature")
        assert m is not None
        assert m.group(1) == "F-10000"
        assert m.group(2) == "Future Feature"

    def test_dev_header(self):
        m = FEATURE_HEADER_RE.match("## DEV-0001: Framework Dev Infrastructure")
        assert m is not None
        assert m.group(1) == "DEV-0001"
        assert m.group(2) == "Framework Dev Infrastructure"

    def test_epic_header(self):
        m = FEATURE_HEADER_RE.match("## E-0001: Some Epic")
        assert m is not None
        assert m.group(1) == "E-0001"

    def test_dotted_header(self):
        m = FEATURE_HEADER_RE.match("## F-003.1: Child Feature")
        assert m is not None
        assert m.group(1) == "F-003.1"
        assert m.group(2) == "Child Feature"

    def test_dotted_grandchild_header(self):
        m = FEATURE_HEADER_RE.match("## F-003.1.2: Grandchild Feature")
        assert m is not None
        assert m.group(1) == "F-003.1.2"

    def test_no_match_wrong_level(self):
        assert FEATURE_HEADER_RE.match("# F-0042: Title") is None
        assert FEATURE_HEADER_RE.match("### F-0042: Title") is None


# ---------------------------------------------------------------------------
# get_parent_id
# ---------------------------------------------------------------------------

class TestGetParentId:
    def test_root_has_no_parent(self):
        assert get_parent_id("F-003") is None
        assert get_parent_id("F-0001") is None
        assert get_parent_id("DEV-001") is None

    def test_child_parent(self):
        assert get_parent_id("F-003.1") == "F-003"
        assert get_parent_id("F-003.12") == "F-003"
        assert get_parent_id("DEV-001.3") == "DEV-001"

    def test_grandchild_parent(self):
        assert get_parent_id("F-003.1.2") == "F-003.1"
        assert get_parent_id("F-003.1.12") == "F-003.1"


# ---------------------------------------------------------------------------
# get_depth
# ---------------------------------------------------------------------------

class TestGetDepth:
    def test_root_depth(self):
        assert get_depth("F-003") == 0
        assert get_depth("F-0001") == 0
        assert get_depth("DEV-001") == 0

    def test_child_depth(self):
        assert get_depth("F-003.1") == 1
        assert get_depth("F-003.12") == 1

    def test_grandchild_depth(self):
        assert get_depth("F-003.1.2") == 2
        assert get_depth("F-003.1.12") == 2


# ---------------------------------------------------------------------------
# get_root_id
# ---------------------------------------------------------------------------

class TestGetRootId:
    def test_root_returns_self(self):
        assert get_root_id("F-003") == "F-003"
        assert get_root_id("F-0001") == "F-0001"
        assert get_root_id("DEV-001") == "DEV-001"

    def test_child_returns_parent(self):
        assert get_root_id("F-003.1") == "F-003"
        assert get_root_id("F-003.12") == "F-003"
        assert get_root_id("DEV-001.3") == "DEV-001"

    def test_grandchild_returns_root(self):
        assert get_root_id("F-003.1.2") == "F-003"
        assert get_root_id("F-003.1.12") == "F-003"


# ---------------------------------------------------------------------------
# get_next_child_id
# ---------------------------------------------------------------------------

class TestGetNextChildId:
    def test_no_existing_children(self):
        assert get_next_child_id("F-003", []) == "F-003.1"
        assert get_next_child_id("F-003.1", []) == "F-003.1.1"

    def test_with_existing_children(self):
        assert get_next_child_id("F-003", ["F-003.1", "F-003.2"]) == "F-003.3"
        assert get_next_child_id("F-003", ["F-003.1"]) == "F-003.2"

    def test_with_grandchildren_ignored(self):
        assert get_next_child_id("F-003", ["F-003.1", "F-003.1.1", "F-003.2"]) == "F-003.3"

    def test_non_contiguous_children(self):
        assert get_next_child_id("F-003", ["F-003.1", "F-003.5"]) == "F-003.6"


# ---------------------------------------------------------------------------
# get_next_feature_id
# ---------------------------------------------------------------------------

class TestGetNextFeatureId:
    def test_empty_file(self, tmp_path):
        f = tmp_path / "FEATURES.md"
        f.write_text("# Features\n\n")
        assert get_next_feature_id(f) == 1

    def test_nonexistent_file(self, tmp_path):
        assert get_next_feature_id(tmp_path / "nonexistent.md") == 1

    def test_existing_ids(self, tmp_path):
        f = tmp_path / "FEATURES.md"
        f.write_text(textwrap.dedent("""\
            # Features

            ## F-0001: First
            - Status: shipped

            ## F-0005: Fifth
            - Status: planned
        """))
        assert get_next_feature_id(f) == 6

    def test_mixed_digit_widths(self, tmp_path):
        f = tmp_path / "FEATURES.md"
        f.write_text(textwrap.dedent("""\
            # Features

            ## F-0001: First
            - Status: shipped

            ## F-10000: Big Feature
            - Status: planned
        """))
        assert get_next_feature_id(f) == 10001

    def test_three_digit_ids(self, tmp_path):
        f = tmp_path / "FEATURES.md"
        f.write_text(textwrap.dedent("""\
            # Features

            ## F-001: First
            - Status: shipped

            ## F-003: Third
            - Status: shipped
        """))
        assert get_next_feature_id(f) == 4

    def test_ignores_dotted_children(self, tmp_path):
        f = tmp_path / "FEATURES.md"
        f.write_text(textwrap.dedent("""\
            # Features

            ## F-003: Parent
            - Status: shipped

            ## F-003.1: Child
            - Status: shipped

            ## F-005: Another
            - Status: shipped
        """))
        assert get_next_feature_id(f) == 6


# ---------------------------------------------------------------------------
# patterns_match_legacy — verify all existing IDs in FEATURES.md are matched
# ---------------------------------------------------------------------------

class TestPatternsMatchLegacy:
    def test_all_existing_ids_match(self):
        """Verify every ID in FEATURES.md matches the centralized pattern."""
        features_file = (
            Path(__file__).parent.parent / ".agentic" / "spec" / "FEATURES.md"
        )
        if not features_file.exists():
            pytest.skip("FEATURES.md not found")

        import re
        content = features_file.read_text()
        all_ids = re.findall(r"\b(?:F|DEV|E)-\d{3,}(?:\.[1-9]\d*)*\b", content)
        assert len(all_ids) > 0, "Expected some feature IDs in FEATURES.md"

        for fid in all_ids:
            assert is_valid_feature_id(fid), f"{fid} should be valid"
            assert FEATURE_ID_RE.search(fid), f"{fid} should match inline pattern"


# ---------------------------------------------------------------------------
# MAX_DEPTH constant
# ---------------------------------------------------------------------------

class TestMaxDepth:
    def test_constant_value(self):
        assert MAX_DEPTH == 2

    def test_depth_within_max(self):
        assert get_depth("F-003") <= MAX_DEPTH
        assert get_depth("F-003.1") <= MAX_DEPTH
        assert get_depth("F-003.1.2") <= MAX_DEPTH

    def test_depth_exceeds_max(self):
        # F-003.1.2.3 would be depth 3, exceeding MAX_DEPTH
        assert get_depth("F-003.1.2.3") > MAX_DEPTH


# ---------------------------------------------------------------------------
# Shell get_depth — verify bash implementation matches Python
# ---------------------------------------------------------------------------

class TestShellGetDepth:
    """Verify the ids.sh get_depth function produces correct results."""

    @pytest.fixture
    def ids_sh_path(self):
        return Path(__file__).parent.parent / ".agentic" / "lib" / "ids.sh"

    def _shell_get_depth(self, ids_sh_path, feature_id):
        import subprocess
        result = subprocess.run(
            ["bash", "-c", f'source "{ids_sh_path}" && get_depth "{feature_id}"'],
            capture_output=True, text=True, timeout=5,
        )
        return int(result.stdout.strip())

    def test_root_depth(self, ids_sh_path):
        assert self._shell_get_depth(ids_sh_path, "F-003") == 0
        assert self._shell_get_depth(ids_sh_path, "F-0001") == 0
        assert self._shell_get_depth(ids_sh_path, "DEV-001") == 0

    def test_child_depth(self, ids_sh_path):
        assert self._shell_get_depth(ids_sh_path, "F-003.1") == 1
        assert self._shell_get_depth(ids_sh_path, "F-003.12") == 1

    def test_grandchild_depth(self, ids_sh_path):
        assert self._shell_get_depth(ids_sh_path, "F-003.1.2") == 2

    def test_matches_python(self, ids_sh_path):
        """Shell and Python implementations must agree."""
        test_ids = ["F-003", "F-0001", "F-003.1", "F-003.12", "F-003.1.2", "DEV-001.3"]
        for fid in test_ids:
            shell_depth = self._shell_get_depth(ids_sh_path, fid)
            python_depth = get_depth(fid)
            assert shell_depth == python_depth, f"Mismatch for {fid}: shell={shell_depth}, python={python_depth}"
