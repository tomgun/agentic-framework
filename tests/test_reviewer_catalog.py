#!/usr/bin/env python3
"""
Tests for reviewer role catalog (F-0236).
"""
import json
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "auto"))

from auto.reviewer_catalog import (
    ReviewerRole,
    load_catalog,
    get_setting_list,
    get_active_reviewers,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def project_dir():
    """Minimal project dir for catalog tests."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / ".agentic" / "lib" / "agents" / "shared").mkdir(parents=True)
        (root / ".agentic" / "presets").mkdir(parents=True)

        # Copy infrastructure
        lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
        for f in ["paths.py", "settings.py"]:
            src = lib_src / f
            if src.exists():
                (root / ".agentic" / "lib" / f).write_text(src.read_text())

        # Copy presets
        src_presets = lib_src / "presets" / "profiles.conf"
        if src_presets.exists():
            (root / ".agentic" / "presets" / "profiles.conf").write_text(
                src_presets.read_text()
            )

        # Write catalog
        catalog = {
            "roles": {
                "critic": {
                    "agent_file": "plan-critic-agent.md",
                    "mandate": "Find flaws",
                    "required": True,
                    "model_tier": "mid-tier",
                },
                "advocate": {
                    "agent_file": "plan-advocate-agent.md",
                    "mandate": "Defend decisions",
                    "required": True,
                    "model_tier": "mid-tier",
                },
                "security_expert": {
                    "agent_file": "plan-security-reviewer-agent.md",
                    "mandate": "Security review",
                    "required": False,
                    "model_tier": "mid-tier",
                },
            }
        }
        catalog_file = (
            root / ".agentic" / "lib" / "agents" / "shared"
            / "reviewer_roles.json"
        )
        catalog_file.write_text(json.dumps(catalog, indent=2))

        (root / "STACK.md").write_text(
            "## Settings\n- profile: formal\n"
            "- plan_review_reviewers: critic,advocate\n"
        )

        yield root


@pytest.fixture(autouse=True)
def clear_caches():
    yield
    try:
        from settings import _cache
        _cache.clear()
    except (ImportError, AttributeError):
        pass


# ---------------------------------------------------------------------------
# Tests: load_catalog
# ---------------------------------------------------------------------------

class TestLoadCatalog:
    def test_loads_roles(self, project_dir):
        catalog = load_catalog(project_dir)
        assert "critic" in catalog
        assert "advocate" in catalog
        assert "security_expert" in catalog
        assert catalog["critic"].required is True
        assert catalog["security_expert"].required is False

    def test_missing_project_catalog_falls_back_to_bundled(self):
        """When project catalog missing, falls back to bundled catalog."""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            # No catalog at project level, but bundled exists
            catalog = load_catalog(root)
            # Bundled catalog from the repo should be found
            assert len(catalog) > 0
            assert "critic" in catalog

    def test_malformed_json_returns_empty(self, project_dir):
        catalog_file = (
            project_dir / ".agentic" / "lib" / "agents" / "shared"
            / "reviewer_roles.json"
        )
        catalog_file.write_text("not json{{{")
        catalog = load_catalog(project_dir)
        assert catalog == {}


# ---------------------------------------------------------------------------
# Tests: get_setting_list
# ---------------------------------------------------------------------------

class TestGetSettingList:
    def test_comma_separated(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- plan_review_reviewers: critic,advocate\n"
        )
        result = get_setting_list(project_dir, "plan_review_reviewers")
        assert result == ["critic", "advocate"]

    def test_bracket_list(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n"
            "- plan_review_reviewers: [critic, advocate, security_expert]\n"
        )
        result = get_setting_list(project_dir, "plan_review_reviewers")
        assert result == ["critic", "advocate", "security_expert"]

    def test_empty_returns_empty_list(self, project_dir):
        result = get_setting_list(project_dir, "nonexistent_setting")
        assert result == []

    def test_whitespace_handling(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- plan_review_reviewers:  critic , advocate \n"
        )
        result = get_setting_list(project_dir, "plan_review_reviewers")
        assert result == ["critic", "advocate"]


# ---------------------------------------------------------------------------
# Tests: get_active_reviewers
# ---------------------------------------------------------------------------

class TestGetActiveReviewers:
    def test_default_returns_critic_advocate(self, project_dir):
        reviewers = get_active_reviewers(project_dir)
        names = [r.name for r in reviewers]
        assert "critic" in names
        assert "advocate" in names

    def test_required_roles_always_present(self, project_dir):
        """Even if only security_expert is listed, critic+advocate are added."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- plan_review_reviewers: security_expert\n"
        )
        reviewers = get_active_reviewers(project_dir)
        names = [r.name for r in reviewers]
        assert "critic" in names
        assert "advocate" in names
        assert "security_expert" in names

    def test_unknown_role_skipped_with_warning(self, project_dir, capsys):
        (project_dir / "STACK.md").write_text(
            "## Settings\n"
            "- plan_review_reviewers: critic,advocate,nonexistent_role\n"
        )
        reviewers = get_active_reviewers(project_dir)
        names = [r.name for r in reviewers]
        assert "nonexistent_role" not in names
        captured = capsys.readouterr()
        assert "unknown reviewer role" in captured.err

    def test_no_duplicates(self, project_dir):
        """Requesting critic explicitly doesn't duplicate it."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- plan_review_reviewers: critic,advocate,critic\n"
        )
        reviewers = get_active_reviewers(project_dir)
        names = [r.name for r in reviewers]
        assert names.count("critic") == 1
