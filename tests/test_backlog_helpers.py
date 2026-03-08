#!/usr/bin/env python3
"""
Tests for backlog_helpers.py (F-0190: Backlog/Roadmap — Structural Work Assignment).
"""
import json
import sys
import tempfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "tools"))

from tools.backlog_helpers import (
    _load,
    _save,
    _find_index,
    _auto_discover_refs,
    cmd_add,
    cmd_current,
    cmd_next,
    cmd_done,
    cmd_list,
    cmd_remove,
    cmd_move,
    cmd_clear,
    cmd_upsert,
    cmd_check_deps,
    cmd_check_staleness,
    cmd_json_current,
    cmd_json_all,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def project_dir():
    """Project dir with FEATURES.md."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / ".agentic" / "lib").mkdir(parents=True)
        (root / ".agentic" / "spec" / "acceptance").mkdir(parents=True)
        (root / ".agentic" / "journal" / "plans").mkdir(parents=True)
        (root / ".agentic" / "session").mkdir(parents=True)
        lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
        for f in ["paths.py", "settings.py"]:
            src = lib_src / f
            if src.exists():
                (root / ".agentic" / "lib" / f).write_text(src.read_text())
        # Write FEATURES.md with test features
        (root / ".agentic" / "spec" / "FEATURES.md").write_text(
            "# Features\n\n"
            "## F-0200: Phase 1\n\n**Status**: planned\n\n---\n\n"
            "## F-0201: Phase 2\n\n**Status**: planned\n\n---\n\n"
            "## F-0202: Phase 3\n\n**Status**: planned\n\n---\n\n"
            "## F-0300: Shipped Feature\n\n**Status**: shipped\n\n---\n\n"
        )
        (root / "STACK.md").write_text("## Settings\n- profile: formal\n")
        yield root


@pytest.fixture
def backlog_file(project_dir):
    return project_dir / ".agentic" / "BACKLOG.json"


# ---------------------------------------------------------------------------
# _load / _save
# ---------------------------------------------------------------------------

class TestLoadSave:
    def test_load_nonexistent(self, backlog_file):
        assert _load(backlog_file) == []

    def test_save_and_load(self, backlog_file):
        items = [{"type": "feature", "id": "F-0200", "description": "test"}]
        _save(backlog_file, items)
        assert _load(backlog_file) == items

    def test_load_invalid_json(self, backlog_file):
        backlog_file.write_text("not json")
        assert _load(backlog_file) == []

    def test_load_non_array(self, backlog_file):
        backlog_file.write_text('{"not": "array"}')
        assert _load(backlog_file) == []


# ---------------------------------------------------------------------------
# _find_index
# ---------------------------------------------------------------------------

class TestFindIndex:
    def test_found(self):
        items = [{"id": "F-0200"}, {"id": "F-0201"}]
        assert _find_index(items, "F-0200") == 0
        assert _find_index(items, "F-0201") == 1

    def test_not_found(self):
        assert _find_index([{"id": "F-0200"}], "F-0999") == -1

    def test_task_no_id(self):
        items = [{"type": "task", "description": "test"}]
        assert _find_index(items, "F-0200") == -1


# ---------------------------------------------------------------------------
# _auto_discover_refs
# ---------------------------------------------------------------------------

class TestAutoDiscoverRefs:
    def test_finds_acceptance(self, project_dir):
        (project_dir / ".agentic" / "spec" / "acceptance" / "F-0200.md").write_text("AC")
        refs = _auto_discover_refs(project_dir, "F-0200")
        assert any("F-0200.md" in r for r in refs)

    def test_finds_plan(self, project_dir):
        (project_dir / ".agentic" / "journal" / "plans" / "F-0200-plan.md").write_text("Plan")
        refs = _auto_discover_refs(project_dir, "F-0200")
        assert any("F-0200-plan.md" in r for r in refs)

    def test_no_files(self, project_dir):
        refs = _auto_discover_refs(project_dir, "F-0999")
        assert refs == []


# ---------------------------------------------------------------------------
# cmd_add
# ---------------------------------------------------------------------------

class TestCmdAdd:
    def test_add_feature(self, project_dir, backlog_file):
        result = cmd_add(project_dir, backlog_file, ["F-0200", "--desc", "Phase 1"])
        assert result == 0
        items = _load(backlog_file)
        assert len(items) == 1
        assert items[0]["id"] == "F-0200"
        assert items[0]["type"] == "feature"
        assert items[0]["description"] == "Phase 1"

    def test_add_feature_at_position_0(self, project_dir, backlog_file):
        cmd_add(project_dir, backlog_file, ["F-0200", "--desc", "Phase 1"])
        cmd_add(project_dir, backlog_file, ["F-0201", "--desc", "Phase 2", "-p", "0"])
        items = _load(backlog_file)
        assert items[0]["id"] == "F-0201"
        assert "became_current_at" in items[0]

    def test_add_task(self, project_dir, backlog_file):
        result = cmd_add(project_dir, backlog_file, [
            "--task", "Research caching", "--note", "Compare Redis vs memory"
        ])
        assert result == 0
        items = _load(backlog_file)
        assert len(items) == 1
        assert items[0]["type"] == "task"
        assert items[0]["description"] == "Research caching"
        assert items[0]["notes"] == "Compare Redis vs memory"

    def test_add_duplicate_blocked(self, project_dir, backlog_file):
        cmd_add(project_dir, backlog_file, ["F-0200"])
        result = cmd_add(project_dir, backlog_file, ["F-0200"])
        assert result == 1

    def test_add_unregistered_feature_blocked(self, project_dir, backlog_file):
        result = cmd_add(project_dir, backlog_file, ["F-9999"])
        assert result == 1

    def test_add_with_ref(self, project_dir, backlog_file):
        cmd_add(project_dir, backlog_file, [
            "F-0200", "--ref", "docs/design.md"
        ])
        items = _load(backlog_file)
        assert "docs/design.md" in items[0]["refs"]

    def test_add_with_dep(self, project_dir, backlog_file):
        cmd_add(project_dir, backlog_file, [
            "F-0201", "--dep", "F-0200"
        ])
        items = _load(backlog_file)
        assert items[0]["depends_on"] == ["F-0200"]

    def test_add_auto_discovers_refs(self, project_dir, backlog_file):
        (project_dir / ".agentic" / "spec" / "acceptance" / "F-0200.md").write_text("AC")
        cmd_add(project_dir, backlog_file, ["F-0200"])
        items = _load(backlog_file)
        assert any("F-0200.md" in r for r in items[0].get("refs", []))


# ---------------------------------------------------------------------------
# cmd_current / cmd_next
# ---------------------------------------------------------------------------

class TestCmdCurrentNext:
    def test_current_empty(self, backlog_file):
        assert cmd_current(backlog_file) == 1

    def test_current_with_items(self, project_dir, backlog_file, capsys):
        cmd_add(project_dir, backlog_file, ["F-0200", "--desc", "Phase 1", "-p", "0"])
        result = cmd_current(backlog_file)
        assert result == 0
        assert "F-0200" in capsys.readouterr().out

    def test_next_empty(self, backlog_file):
        assert cmd_next(backlog_file) == 1

    def test_next_with_items(self, project_dir, backlog_file, capsys):
        cmd_add(project_dir, backlog_file, ["F-0200", "--desc", "Phase 1"])
        cmd_add(project_dir, backlog_file, ["F-0201", "--desc", "Phase 2"])
        result = cmd_next(backlog_file)
        assert result == 0
        assert "F-0201" in capsys.readouterr().out


# ---------------------------------------------------------------------------
# cmd_done
# ---------------------------------------------------------------------------

class TestCmdDone:
    def test_done_empty(self, backlog_file):
        assert cmd_done(backlog_file) == 1

    def test_done_advances(self, project_dir, backlog_file, capsys):
        cmd_add(project_dir, backlog_file, ["F-0200", "--desc", "Phase 1", "-p", "0"])
        cmd_add(project_dir, backlog_file, ["F-0201", "--desc", "Phase 2"])
        result = cmd_done(backlog_file)
        assert result == 0
        items = _load(backlog_file)
        assert len(items) == 1
        assert items[0]["id"] == "F-0201"
        assert "became_current_at" in items[0]
        out = capsys.readouterr().out
        assert "F-0201" in out

    def test_done_empties(self, project_dir, backlog_file, capsys):
        cmd_add(project_dir, backlog_file, ["F-0200", "-p", "0"])
        result = cmd_done(backlog_file)
        assert result == 0
        assert _load(backlog_file) == []
        assert "empty" in capsys.readouterr().out

    def test_done_skips_items_with_unmet_deps(self, project_dir, backlog_file, capsys):
        cmd_add(project_dir, backlog_file, ["F-0200", "-p", "0"])
        cmd_add(project_dir, backlog_file, ["F-0201", "--dep", "F-0202"])
        cmd_add(project_dir, backlog_file, ["F-0202"])
        result = cmd_done(backlog_file)
        assert result == 0
        items = _load(backlog_file)
        # F-0202 should be at position 0 (F-0201 depends on F-0202)
        assert items[0]["id"] == "F-0202"


# ---------------------------------------------------------------------------
# cmd_list
# ---------------------------------------------------------------------------

class TestCmdList:
    def test_list_empty(self, backlog_file, capsys):
        cmd_list(backlog_file)
        assert "empty" in capsys.readouterr().out

    def test_list_with_items(self, project_dir, backlog_file, capsys):
        cmd_add(project_dir, backlog_file, ["F-0200", "--desc", "Phase 1", "-p", "0"])
        cmd_add(project_dir, backlog_file, ["--task", "Research"])
        cmd_list(backlog_file)
        out = capsys.readouterr().out
        assert "F-0200" in out
        assert "Research" in out
        assert "CURRENT" in out
        assert "2 item(s)" in out


# ---------------------------------------------------------------------------
# cmd_remove
# ---------------------------------------------------------------------------

class TestCmdRemove:
    def test_remove_existing(self, project_dir, backlog_file):
        cmd_add(project_dir, backlog_file, ["F-0200"])
        result = cmd_remove(backlog_file, "F-0200")
        assert result == 0
        assert _load(backlog_file) == []

    def test_remove_nonexistent(self, backlog_file):
        assert cmd_remove(backlog_file, "F-9999") == 1


# ---------------------------------------------------------------------------
# cmd_move
# ---------------------------------------------------------------------------

class TestCmdMove:
    def test_move_to_top(self, project_dir, backlog_file):
        cmd_add(project_dir, backlog_file, ["F-0200", "-p", "0"])
        cmd_add(project_dir, backlog_file, ["F-0201"])
        result = cmd_move(backlog_file, "F-0201", 0)
        assert result == 0
        items = _load(backlog_file)
        assert items[0]["id"] == "F-0201"
        assert "became_current_at" in items[0]

    def test_move_nonexistent(self, backlog_file):
        assert cmd_move(backlog_file, "F-9999", 0) == 1


# ---------------------------------------------------------------------------
# cmd_clear
# ---------------------------------------------------------------------------

class TestCmdClear:
    def test_clear(self, project_dir, backlog_file):
        cmd_add(project_dir, backlog_file, ["F-0200"])
        result = cmd_clear(backlog_file)
        assert result == 0
        assert _load(backlog_file) == []


# ---------------------------------------------------------------------------
# cmd_upsert
# ---------------------------------------------------------------------------

class TestCmdUpsert:
    def test_upsert_new(self, project_dir, backlog_file, capsys):
        result = cmd_upsert(project_dir, backlog_file, "F-0200")
        assert result == 0
        items = _load(backlog_file)
        assert len(items) == 1
        assert items[0]["id"] == "F-0200"
        assert items[0]["added_by"] == "auto"
        assert "became_current_at" in items[0]
        assert capsys.readouterr().out.strip() == "0"

    def test_upsert_existing_returns_position(self, project_dir, backlog_file, capsys):
        cmd_add(project_dir, backlog_file, ["F-0200", "-p", "0"])
        cmd_add(project_dir, backlog_file, ["F-0201"])
        capsys.readouterr()  # clear output
        result = cmd_upsert(project_dir, backlog_file, "F-0201")
        assert result == 0
        assert capsys.readouterr().out.strip() == "1"


# ---------------------------------------------------------------------------
# cmd_check_deps
# ---------------------------------------------------------------------------

class TestCmdCheckDeps:
    def test_no_deps(self, project_dir, backlog_file):
        cmd_add(project_dir, backlog_file, ["F-0200"])
        assert cmd_check_deps(backlog_file, "F-0200") == 0

    def test_unmet_deps(self, project_dir, backlog_file, capsys):
        cmd_add(project_dir, backlog_file, ["F-0200"])
        cmd_add(project_dir, backlog_file, ["F-0201", "--dep", "F-0200"])
        capsys.readouterr()
        result = cmd_check_deps(backlog_file, "F-0201")
        assert result == 2
        assert "UNMET: F-0200" in capsys.readouterr().out

    def test_not_in_backlog(self, backlog_file):
        assert cmd_check_deps(backlog_file, "F-9999") == 0


# ---------------------------------------------------------------------------
# cmd_check_staleness
# ---------------------------------------------------------------------------

class TestCmdCheckStaleness:
    def test_empty_backlog(self, backlog_file):
        assert cmd_check_staleness(backlog_file) == 1

    def test_fresh_item(self, project_dir, backlog_file):
        cmd_add(project_dir, backlog_file, ["F-0200", "-p", "0"])
        assert cmd_check_staleness(backlog_file) == 1  # 1 = fresh (not stale)

    def test_stale_item(self, project_dir, backlog_file, capsys):
        cmd_add(project_dir, backlog_file, ["F-0200", "-p", "0"])
        items = _load(backlog_file)
        items[0]["became_current_at"] = "2026-01-01T00:00:00Z"
        _save(backlog_file, items)
        capsys.readouterr()
        result = cmd_check_staleness(backlog_file)
        assert result == 0  # 0 = stale
        assert "WARNING" in capsys.readouterr().out


# ---------------------------------------------------------------------------
# JSON output commands
# ---------------------------------------------------------------------------

class TestJsonCommands:
    def test_json_current_empty(self, backlog_file):
        assert cmd_json_current(backlog_file) == 1

    def test_json_current(self, project_dir, backlog_file, capsys):
        cmd_add(project_dir, backlog_file, ["F-0200", "--desc", "Phase 1", "-p", "0"])
        capsys.readouterr()
        result = cmd_json_current(backlog_file)
        assert result == 0
        data = json.loads(capsys.readouterr().out)
        assert data["id"] == "F-0200"

    def test_json_all(self, project_dir, backlog_file, capsys):
        cmd_add(project_dir, backlog_file, ["F-0200"])
        cmd_add(project_dir, backlog_file, ["--task", "Research"])
        capsys.readouterr()
        result = cmd_json_all(backlog_file)
        assert result == 0
        data = json.loads(capsys.readouterr().out)
        assert len(data) == 2
