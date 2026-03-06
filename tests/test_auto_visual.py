#!/usr/bin/env python3
"""
Tests for visual verification (F-0168): screenshot collection, parsing,
AI visual review, and E2E framework detection.
"""
import json
import os
import sys
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "auto"))

from auto.verify import (
    TestTier,
    TierResult,
    VerifyLoop,
    VerifyResult,
    VisualReviewResult,
)
from auto.visual import _parse_concerns, _parse_summary, visual_review


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def project_dir():
    """Minimal project directory with STACK.md."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / ".agentic" / "lib").mkdir(parents=True)
        (root / ".agentic" / "session").mkdir(parents=True)
        lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
        for f in ["paths.py", "settings.py"]:
            src = lib_src / f
            if src.exists():
                (root / ".agentic" / "lib" / f).write_text(src.read_text())
        yield root


def _make_image(path: Path, size: int = 100) -> None:
    """Create a minimal fake image file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    # Write a minimal PNG header (enough for file detection, not valid image)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\x00" * size)


# ---------------------------------------------------------------------------
# TestScreenshotCollection
# ---------------------------------------------------------------------------

class TestScreenshotCollection:
    def test_collects_png_jpg_webp(self, project_dir):
        (project_dir / "STACK.md").write_text("## Settings\n")
        ss_dir = project_dir / "test-results"
        _make_image(ss_dir / "page1.png")
        _make_image(ss_dir / "page2.jpg")
        _make_image(ss_dir / "page3.webp")

        loop = VerifyLoop(project_dir, test_command="echo ok")
        tier = TestTier(name="E2E", command="echo ok", screenshot_dir="test-results")
        screenshots = loop._collect_screenshots(tier)

        assert len(screenshots) == 3
        # All should be in session screenshots dir
        for s in screenshots:
            assert ".agentic/session/screenshots/e2e/" in s

    def test_skips_non_images(self, project_dir):
        (project_dir / "STACK.md").write_text("## Settings\n")
        ss_dir = project_dir / "test-results"
        _make_image(ss_dir / "page1.png")
        (ss_dir / "log.txt").write_text("not an image")
        (ss_dir / "data.json").write_text("{}")

        loop = VerifyLoop(project_dir, test_command="echo ok")
        tier = TestTier(name="E2E", command="echo ok", screenshot_dir="test-results")
        screenshots = loop._collect_screenshots(tier)

        assert len(screenshots) == 1
        assert "page1.png" in screenshots[0]

    def test_empty_dir_returns_empty(self, project_dir):
        (project_dir / "STACK.md").write_text("## Settings\n")
        (project_dir / "test-results").mkdir()

        loop = VerifyLoop(project_dir, test_command="echo ok")
        tier = TestTier(name="E2E", command="echo ok", screenshot_dir="test-results")
        screenshots = loop._collect_screenshots(tier)

        assert screenshots == []

    def test_missing_dir_returns_empty(self, project_dir):
        (project_dir / "STACK.md").write_text("## Settings\n")

        loop = VerifyLoop(project_dir, test_command="echo ok")
        tier = TestTier(name="E2E", command="echo ok", screenshot_dir="nonexistent")
        screenshots = loop._collect_screenshots(tier)

        assert screenshots == []

    def test_no_screenshot_dir_returns_empty(self, project_dir):
        (project_dir / "STACK.md").write_text("## Settings\n")

        loop = VerifyLoop(project_dir, test_command="echo ok")
        tier = TestTier(name="E2E", command="echo ok", screenshot_dir="")
        screenshots = loop._collect_screenshots(tier)

        assert screenshots == []

    def test_caps_at_max(self, project_dir):
        (project_dir / "STACK.md").write_text("## Settings\n")
        ss_dir = project_dir / "test-results"
        for i in range(25):
            _make_image(ss_dir / f"page{i:03d}.png")

        loop = VerifyLoop(project_dir, test_command="echo ok")
        tier = TestTier(name="E2E", command="echo ok", screenshot_dir="test-results")
        screenshots = loop._collect_screenshots(tier)

        assert len(screenshots) == 20  # _MAX_SCREENSHOTS

    def test_collects_from_subdirs(self, project_dir):
        (project_dir / "STACK.md").write_text("## Settings\n")
        ss_dir = project_dir / "test-results"
        _make_image(ss_dir / "chromium" / "page1.png")
        _make_image(ss_dir / "firefox" / "page2.png")

        loop = VerifyLoop(project_dir, test_command="echo ok")
        tier = TestTier(name="E2E UI", command="echo ok", screenshot_dir="test-results")
        screenshots = loop._collect_screenshots(tier)

        assert len(screenshots) == 2


# ---------------------------------------------------------------------------
# TestScreenshotDirParsing
# ---------------------------------------------------------------------------

class TestScreenshotDirParsing:
    def test_backtick_format(self):
        content = "- E2E screenshots: `test-results/`\n"
        assert VerifyLoop._parse_screenshot_dir(content) == "test-results/"

    def test_plain_format(self):
        content = "- E2E screenshots: test-results/\n"
        assert VerifyLoop._parse_screenshot_dir(content) == "test-results/"

    def test_placeholder_skipped(self):
        content = "- E2E screenshots: `<!-- fill -->`\n"
        assert VerifyLoop._parse_screenshot_dir(content) == ""

    def test_na_skipped(self):
        content = "- E2E screenshots: N/A\n"
        assert VerifyLoop._parse_screenshot_dir(content) == ""

    def test_absent_returns_empty(self):
        content = "## Testing\n- Test commands:\n  - Unit: `pytest`\n"
        assert VerifyLoop._parse_screenshot_dir(content) == ""

    def test_case_insensitive(self):
        content = "- e2e Screenshots: `screenshots/`\n"
        assert VerifyLoop._parse_screenshot_dir(content) == "screenshots/"


# ---------------------------------------------------------------------------
# TestScreenshotDirAppliedToTiers
# ---------------------------------------------------------------------------

class TestScreenshotDirAppliedToTiers:
    def test_e2e_tiers_get_screenshot_dir(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n"
            "- Test commands:\n"
            "  - Unit: `pytest`\n"
            "  - E2E UI: `npx playwright test`\n"
            "- E2E screenshots: `test-results/`\n"
        )
        loop = VerifyLoop(project_dir)
        assert loop.tiers[0].screenshot_dir == ""  # unit
        assert loop.tiers[1].screenshot_dir == "test-results/"  # e2e

    def test_unit_tiers_dont_get_screenshot_dir(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n"
            "- Test commands:\n"
            "  - Unit: `pytest`\n"
            "  - Integration: `pytest tests/integration/`\n"
            "- E2E screenshots: `test-results/`\n"
        )
        loop = VerifyLoop(project_dir)
        assert loop.tiers[0].screenshot_dir == ""
        assert loop.tiers[1].screenshot_dir == ""

    def test_no_screenshot_config_leaves_empty(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n"
            "- Test commands:\n"
            "  - E2E: `npx playwright test`\n"
        )
        loop = VerifyLoop(project_dir)
        assert loop.tiers[0].screenshot_dir == ""


# ---------------------------------------------------------------------------
# TestVisualReviewResult
# ---------------------------------------------------------------------------

class TestVisualReviewResult:
    def test_to_dict_performed(self):
        vr = VisualReviewResult(
            performed=True,
            screenshots_reviewed=3,
            summary="All looks good",
            concerns=["Minor alignment issue"],
        )
        d = vr.to_dict()
        assert d["performed"] is True
        assert d["screenshots_reviewed"] == 3
        assert d["summary"] == "All looks good"
        assert d["concerns"] == ["Minor alignment issue"]

    def test_to_dict_not_performed(self):
        vr = VisualReviewResult(performed=False, error="No SDK")
        d = vr.to_dict()
        assert d["performed"] is False
        assert d["error"] == "No SDK"
        assert "screenshots_reviewed" not in d

    def test_to_dict_no_concerns(self):
        vr = VisualReviewResult(performed=True, screenshots_reviewed=2, summary="OK")
        d = vr.to_dict()
        assert "concerns" not in d


# ---------------------------------------------------------------------------
# TestVisualReview
# ---------------------------------------------------------------------------

class TestVisualReview:
    def test_no_screenshots_returns_error(self):
        result = visual_review([])
        assert result.performed is False
        assert "No screenshots" in result.error

    def test_no_sdk_returns_graceful_error(self):
        with patch.dict("sys.modules", {"anthropic": None}):
            # Force ImportError
            import importlib
            import auto.visual
            importlib.reload(auto.visual)
            result = auto.visual.visual_review(["/fake/path.png"])
            assert result.performed is False
            assert "anthropic" in result.error.lower() or "SDK" in result.error
            # Restore
            importlib.reload(auto.visual)

    def test_no_api_key_returns_graceful_error(self):
        mock_anthropic = MagicMock()
        with patch.dict("sys.modules", {"anthropic": mock_anthropic}):
            with patch.dict(os.environ, {}, clear=False):
                # Ensure no API key
                env = os.environ.copy()
                env.pop("ANTHROPIC_API_KEY", None)
                with patch.dict(os.environ, env, clear=True):
                    result = visual_review(["/fake/path.png"])
                    assert result.performed is False
                    assert "API_KEY" in result.error

    def test_successful_review_parses_response(self):
        mock_anthropic = MagicMock()
        mock_client = MagicMock()
        mock_anthropic.Anthropic.return_value = mock_client
        mock_response = MagicMock()
        mock_response.content = [MagicMock(
            text="SUMMARY: Page looks good overall\n\nCONCERNS:\n- Button slightly misaligned\n- Text truncated in header\n"
        )]
        mock_client.messages.create.return_value = mock_response

        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
            f.write(b"\x89PNG\r\n\x1a\n" + b"\x00" * 100)
            f.flush()
            img_path = f.name

        try:
            with patch.dict("sys.modules", {"anthropic": mock_anthropic}):
                with patch.dict(os.environ, {"ANTHROPIC_API_KEY": "test-key"}):
                    result = visual_review([img_path])
                    assert result.performed is True
                    assert result.screenshots_reviewed == 1
                    assert "Page looks good" in result.summary
                    assert len(result.concerns) == 2
                    assert "Button slightly misaligned" in result.concerns[0]
        finally:
            os.unlink(img_path)

    def test_api_error_returns_error_field(self):
        mock_anthropic = MagicMock()
        mock_client = MagicMock()
        mock_anthropic.Anthropic.return_value = mock_client
        mock_client.messages.create.side_effect = Exception("rate limited")

        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
            f.write(b"\x89PNG\r\n\x1a\n" + b"\x00" * 100)
            f.flush()
            img_path = f.name

        try:
            with patch.dict("sys.modules", {"anthropic": mock_anthropic}):
                with patch.dict(os.environ, {"ANTHROPIC_API_KEY": "test-key"}):
                    result = visual_review([img_path])
                    assert result.performed is False
                    assert "rate limited" in result.error
        finally:
            os.unlink(img_path)


# ---------------------------------------------------------------------------
# TestVisualReviewParsing
# ---------------------------------------------------------------------------

class TestVisualReviewParsing:
    def test_parse_summary(self):
        text = "SUMMARY: The page looks correct with proper layout\n\nCONCERNS:\n- None"
        assert _parse_summary(text) == "The page looks correct with proper layout"

    def test_parse_summary_missing(self):
        assert _parse_summary("no summary here") == ""

    def test_parse_concerns_multiple(self):
        text = "SUMMARY: Issues found\n\nCONCERNS:\n- Button overflow\n- Text cut off\n- Missing icon\n"
        concerns = _parse_concerns(text)
        assert len(concerns) == 3
        assert concerns[0] == "Button overflow"

    def test_parse_concerns_none(self):
        text = "SUMMARY: All good\n\nCONCERNS:\n- None\n"
        assert _parse_concerns(text) == []

    def test_parse_concerns_missing_section(self):
        text = "SUMMARY: All good\n"
        assert _parse_concerns(text) == []


# ---------------------------------------------------------------------------
# TestVerifyResultWithVisual
# ---------------------------------------------------------------------------

class TestVerifyResultWithVisual:
    def test_to_dict_includes_visual_review(self):
        result = VerifyResult(
            success=True,
            iterations_used=1,
            max_iterations=5,
            test_command="pytest",
            visual_review=VisualReviewResult(
                performed=True,
                screenshots_reviewed=3,
                summary="All good",
            ),
        )
        d = result.to_dict()
        assert "visual_review" in d
        assert d["visual_review"]["performed"] is True

    def test_to_dict_omits_visual_when_none(self):
        result = VerifyResult(
            success=True,
            iterations_used=1,
            max_iterations=5,
            test_command="pytest",
        )
        d = result.to_dict()
        assert "visual_review" not in d


# ---------------------------------------------------------------------------
# TestE2EDetection
# ---------------------------------------------------------------------------

class TestE2EDetection:
    """Tests for _detect_e2e_framework in discover.py."""

    def setup_method(self):
        sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "tools"))

    def test_detects_playwright_config_ts(self):
        from discover import _detect_e2e_framework
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "playwright.config.ts").write_text("export default {}")
            assert _detect_e2e_framework(root, "TypeScript") == "playwright"

    def test_detects_playwright_config_js(self):
        from discover import _detect_e2e_framework
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "playwright.config.js").write_text("module.exports = {}")
            assert _detect_e2e_framework(root, "JavaScript") == "playwright"

    def test_detects_cypress_config(self):
        from discover import _detect_e2e_framework
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "cypress.config.ts").write_text("export default {}")
            assert _detect_e2e_framework(root, "TypeScript") == "cypress"

    def test_detects_cypress_from_package_json(self):
        from discover import _detect_e2e_framework
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "package.json").write_text(json.dumps({
                "devDependencies": {"cypress": "^13.0.0"}
            }))
            assert _detect_e2e_framework(root, "JavaScript") == "cypress"

    def test_detects_playwright_from_package_json(self):
        from discover import _detect_e2e_framework
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "package.json").write_text(json.dumps({
                "devDependencies": {"@playwright/test": "^1.40.0"}
            }))
            assert _detect_e2e_framework(root, "TypeScript") == "playwright"

    def test_detects_detox(self):
        from discover import _detect_e2e_framework
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / ".detoxrc.js").write_text("module.exports = {}")
            assert _detect_e2e_framework(root, "JavaScript") == "detox"

    def test_detects_playwright_python(self):
        from discover import _detect_e2e_framework
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "requirements.txt").write_text("playwright==1.40.0\npytest\n")
            assert _detect_e2e_framework(root, "Python") == "playwright"

    def test_returns_none_when_no_e2e(self):
        from discover import _detect_e2e_framework
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "package.json").write_text(json.dumps({
                "devDependencies": {"jest": "^29.0.0"}
            }))
            assert _detect_e2e_framework(root, "JavaScript") is None

    def test_config_file_takes_priority(self):
        from discover import _detect_e2e_framework
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            # Both config file and package.json dep
            (root / "playwright.config.ts").write_text("export default {}")
            (root / "package.json").write_text(json.dumps({
                "devDependencies": {"cypress": "^13.0.0"}
            }))
            # Config file wins (checked first)
            assert _detect_e2e_framework(root, "TypeScript") == "playwright"


# ---------------------------------------------------------------------------
# TestTierDataclassDefault
# ---------------------------------------------------------------------------

class TestTierDataclassScreenshotDefault:
    def test_screenshot_dir_default(self):
        tier = TestTier(name="unit", command="pytest")
        assert tier.screenshot_dir == ""
