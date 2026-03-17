#!/usr/bin/env python3
"""
Tests for ids.py — centralized ID patterns and formatting.

@feature F-0193
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
    is_valid_feature_id,
    format_feature_id,
    get_next_feature_id,
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


# ---------------------------------------------------------------------------
# is_valid_feature_id
# ---------------------------------------------------------------------------

class TestIsValidFeatureId:
    def test_standard_id(self):
        assert is_valid_feature_id("F-0001")
        assert is_valid_feature_id("F-0233")
        assert is_valid_feature_id("F-9999")

    def test_five_digit_id(self):
        assert is_valid_feature_id("F-10000")
        assert is_valid_feature_id("F-99999")

    def test_too_short(self):
        assert not is_valid_feature_id("F-01")
        assert not is_valid_feature_id("F-1")
        assert not is_valid_feature_id("F-123")

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

    def test_no_partial_match(self):
        # Should not match F-01 (too short)
        matches = FEATURE_ID_RE.findall("Not F-01 or F-12")
        assert matches == []


# ---------------------------------------------------------------------------
# FEATURE_HEADER_RE (markdown header pattern)
# ---------------------------------------------------------------------------

class TestFeatureHeaderRe:
    def test_standard_header(self):
        m = FEATURE_HEADER_RE.match("## F-0042: Some Feature Name")
        assert m is not None
        assert m.group(1) == "F-0042"
        assert m.group(2) == "Some Feature Name"

    def test_five_digit_header(self):
        m = FEATURE_HEADER_RE.match("## F-10000: Future Feature")
        assert m is not None
        assert m.group(1) == "F-10000"
        assert m.group(2) == "Future Feature"

    def test_no_match_wrong_level(self):
        # Must be ## (h2), not # or ###
        assert FEATURE_HEADER_RE.match("# F-0042: Title") is None
        assert FEATURE_HEADER_RE.match("### F-0042: Title") is None


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
        # Extract IDs using the old 4-digit pattern
        legacy_ids = re.findall(r"\bF-\d{4}\b", content)
        assert len(legacy_ids) > 0, "Expected some feature IDs in FEATURES.md"

        # Verify each matches the new pattern
        for fid in legacy_ids:
            assert is_valid_feature_id(fid), f"{fid} should be valid"
            assert FEATURE_ID_RE.search(fid), f"{fid} should match inline pattern"
