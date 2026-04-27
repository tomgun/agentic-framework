#!/usr/bin/env python3
"""
tests/test_integrity.py — R-004 acceptance tests.

Validates `.agentic/lib/integrity.py`:

  AC1: compute_baseline() picks up every kind of target (full file, glob,
       partial-JSON subfield) when present, and silently skips absent ones.
  AC2: hash output is deterministic across runs (no timestamps, no order
       dependence).
  AC3: partial-JSON hashing is canonical — adding whitespace or
       reordering unrelated keys doesn't change the hash, but mutating the
       baselined subfield does.
  AC4: save_baseline → load_baseline round-trips.
  AC5: verify_all() reports `modified`, `missing_in_tree`,
       `missing_in_baseline` correctly.
  AC6: verify_all() honors `INTEGRITY_SKIP=1` only when `CI=true`; locally
       the skip is recorded but ignored.
  AC7: first-run state (no baseline file) does NOT produce mismatches —
       returns `baseline_present=False`.
  AC8: catalog has an INTEGRITY_TAMPERED block reason wired up.

Designed to run under pytest if available; the bottom block also runs as
a plain script so the suite works without pytest installed (this
container's case).
"""

from __future__ import annotations

import json
import os
import sys
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
LIB_DIR = REPO_ROOT / ".agentic" / "lib"
HOOKS_DIR = LIB_DIR / "hooks"

for path in (LIB_DIR, HOOKS_DIR):
    p = str(path)
    if p not in sys.path:
        sys.path.insert(0, p)

import integrity  # type: ignore  # noqa: E402
import messages   # type: ignore  # noqa: E402


# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------


def _make_fixture(*, with_settings_json=False, with_agent_md=False) -> Path:
    """Create a temp directory mimicking the layout integrity.py expects.
    The caller is responsible for cleaning up (returns the path)."""
    root = Path(tempfile.mkdtemp(prefix="r004-test-"))

    # .git/hooks shims
    (root / ".git" / "hooks").mkdir(parents=True)
    (root / ".git" / "hooks" / "pre-commit").write_text("#!/bin/bash\necho pre-commit\n")
    (root / ".git" / "hooks" / "pre-push").write_text("#!/bin/bash\necho pre-push\n")

    # framework hooks
    (root / ".agentic" / "lib" / "hooks").mkdir(parents=True)
    (root / ".agentic" / "lib" / "hooks" / "precommit_gate.py").write_text("# stub\n")
    (root / ".agentic" / "lib" / "hooks" / "prepush_gate.py").write_text("# stub\n")
    (root / ".agentic" / "lib" / "hooks" / "messages.py").write_text("# stub\n")
    (root / ".agentic" / "lib" / "integrity.py").write_text("# stub\n")

    # .claude/hooks.json
    (root / ".claude").mkdir(parents=True)
    (root / ".claude" / "hooks.json").write_text(json.dumps({
        "hooks": {"PreToolUse": []}
    }, indent=2))

    if with_settings_json:
        (root / ".claude" / "settings.json").write_text(json.dumps({
            "theme": "dark",
            "model": "claude-sonnet-4-6",
            "hooks": {
                "Stop": [{"matcher": ".*", "hooks": []}],
            },
        }, indent=2))

    if with_agent_md:
        (root / ".claude" / "agents").mkdir(parents=True)
        (root / ".claude" / "agents" / "critic.md").write_text("# critic agent\n")

    return root


def _cleanup(root: Path) -> None:
    import shutil
    if root.exists() and str(root).startswith("/tmp/r004-test-"):
        shutil.rmtree(root)


# ---------------------------------------------------------------------------
# AC1 + AC4: enumerate, save, reload
# ---------------------------------------------------------------------------


def test_compute_baseline_enumerates_all_target_kinds():
    root = _make_fixture(with_settings_json=True, with_agent_md=True)
    try:
        baseline = integrity.compute_baseline(root)
        # Full-file paths
        assert ".git/hooks/pre-commit" in baseline
        assert ".git/hooks/pre-push" in baseline
        assert ".agentic/lib/hooks/precommit_gate.py" in baseline
        assert ".agentic/lib/hooks/prepush_gate.py" in baseline
        assert ".agentic/lib/hooks/messages.py" in baseline
        assert ".agentic/lib/integrity.py" in baseline
        assert ".claude/hooks.json" in baseline
        # Glob expansion
        assert ".claude/agents/critic.md" in baseline
        # Partial JSON
        assert ".claude/settings.json[hooks]" in baseline
    finally:
        _cleanup(root)


def test_compute_baseline_skips_absent_targets():
    root = _make_fixture(with_settings_json=False, with_agent_md=False)
    try:
        baseline = integrity.compute_baseline(root)
        # Settings.json absent → no entry, no error
        assert ".claude/settings.json[hooks]" not in baseline
        # No agents → no glob matches
        assert not any(p.startswith(".claude/agents/") for p in baseline)
    finally:
        _cleanup(root)


def test_save_load_baseline_roundtrip():
    root = _make_fixture()
    try:
        path, baseline = integrity.update_baseline(root)
        assert path == integrity.baseline_path(root)
        assert path.is_file()
        loaded = integrity.load_baseline(root)
        assert loaded == baseline
        # Schema sanity
        data = json.loads(path.read_text())
        assert data["version"] == 1
        assert data["algorithm"] == "sha256"
        assert isinstance(data["files"], dict)
    finally:
        _cleanup(root)


# ---------------------------------------------------------------------------
# AC2: deterministic hashing
# ---------------------------------------------------------------------------


def test_compute_baseline_is_deterministic():
    root = _make_fixture(with_settings_json=True)
    try:
        a = integrity.compute_baseline(root)
        b = integrity.compute_baseline(root)
        assert a == b
        # Order is sorted, so equality of dicts also implies stable iteration.
        assert list(a.keys()) == list(b.keys())
    finally:
        _cleanup(root)


# ---------------------------------------------------------------------------
# AC3: partial JSON hashing is canonical
# ---------------------------------------------------------------------------


def test_partial_json_ignores_unrelated_keys_and_whitespace():
    root_a = _make_fixture(with_settings_json=True)
    try:
        h_a = integrity.compute_baseline(root_a)[".claude/settings.json[hooks]"]

        # Same `hooks` content, different unrelated keys + whitespace.
        (root_a / ".claude" / "settings.json").write_text(json.dumps({
            "theme": "light",            # changed
            "model": "claude-haiku-4-5", # changed
            "newField": [1, 2, 3],        # added
            "hooks": {
                "Stop": [{"matcher": ".*", "hooks": []}],  # unchanged
            },
        }, indent=4))  # different whitespace
        h_b = integrity.compute_baseline(root_a)[".claude/settings.json[hooks]"]
        assert h_a == h_b, "non-hooks edits must not change the hash"

        # Mutate the hooks subfield → hash MUST change.
        (root_a / ".claude" / "settings.json").write_text(json.dumps({
            "hooks": {
                "Stop": [{"matcher": ".*", "hooks": [{"type": "command", "command": "evil"}]}],
            },
        }))
        h_c = integrity.compute_baseline(root_a)[".claude/settings.json[hooks]"]
        assert h_c != h_a, "mutating hooks subfield MUST change the hash"
    finally:
        _cleanup(root_a)


# ---------------------------------------------------------------------------
# AC5: verify_all reports the right mismatch kinds
# ---------------------------------------------------------------------------


def test_verify_all_detects_modified_file():
    root = _make_fixture()
    try:
        integrity.update_baseline(root)
        # Tamper.
        (root / ".agentic" / "lib" / "hooks" / "precommit_gate.py").write_text("# tampered\n")
        result = integrity.verify_all(root)
        assert result.baseline_present
        modified = [m for m in result.mismatches if m.kind == "modified"]
        assert len(modified) == 1
        assert modified[0].path == ".agentic/lib/hooks/precommit_gate.py"
    finally:
        _cleanup(root)


def test_verify_all_detects_missing_in_tree():
    root = _make_fixture()
    try:
        integrity.update_baseline(root)
        (root / ".agentic" / "lib" / "hooks" / "precommit_gate.py").unlink()
        result = integrity.verify_all(root)
        missing = [m for m in result.mismatches if m.kind == "missing_in_tree"]
        assert any(m.path == ".agentic/lib/hooks/precommit_gate.py" for m in missing)
    finally:
        _cleanup(root)


def test_verify_all_detects_missing_in_baseline():
    """A new agent file the baseline doesn't know about."""
    root = _make_fixture()
    try:
        integrity.update_baseline(root)
        (root / ".claude" / "agents").mkdir(parents=True, exist_ok=True)
        (root / ".claude" / "agents" / "newcomer.md").write_text("# new agent\n")
        result = integrity.verify_all(root)
        new = [m for m in result.mismatches if m.kind == "missing_in_baseline"]
        assert any(m.path == ".claude/agents/newcomer.md" for m in new)
    finally:
        _cleanup(root)


def test_verify_all_clean_when_unchanged():
    root = _make_fixture()
    try:
        integrity.update_baseline(root)
        result = integrity.verify_all(root)
        assert result.baseline_present
        assert result.mismatches == []
    finally:
        _cleanup(root)


# ---------------------------------------------------------------------------
# AC6: INTEGRITY_SKIP only honored under CI
# ---------------------------------------------------------------------------


def test_skip_envvar_honored_under_ci():
    root = _make_fixture()
    try:
        integrity.update_baseline(root)
        # Tamper, but request skip under CI.
        (root / ".agentic" / "lib" / "hooks" / "precommit_gate.py").write_text("# tampered\n")
        old_env = dict(os.environ)
        os.environ["INTEGRITY_SKIP"] = "1"
        os.environ["CI"] = "true"
        try:
            result = integrity.verify_all(root)
        finally:
            os.environ.clear(); os.environ.update(old_env)
        assert result.skipped
        assert result.mismatches == []
    finally:
        _cleanup(root)


def test_skip_envvar_ignored_locally():
    root = _make_fixture()
    try:
        integrity.update_baseline(root)
        (root / ".agentic" / "lib" / "hooks" / "precommit_gate.py").write_text("# tampered\n")
        old_env = dict(os.environ)
        os.environ["INTEGRITY_SKIP"] = "1"
        os.environ.pop("CI", None)
        try:
            result = integrity.verify_all(root)
        finally:
            os.environ.clear(); os.environ.update(old_env)
        assert not result.skipped
        assert result.mismatches  # the tamper still gets reported
        assert "ignored" in result.skip_reason
    finally:
        _cleanup(root)


# ---------------------------------------------------------------------------
# AC7: first-run state
# ---------------------------------------------------------------------------


def test_malformed_partial_json_after_baseline_is_flagged_as_malformed():
    """A baselined `.claude/settings.json` that gets corrupted to invalid
    JSON must surface as kind='malformed', not silently drop. Closes the
    review issue #3 hole."""
    root = _make_fixture(with_settings_json=True)
    try:
        integrity.update_baseline(root)
        # Corrupt the file to invalid JSON.
        (root / ".claude" / "settings.json").write_text("{not valid json")
        result = integrity.verify_all(root)
        malformed = [m for m in result.mismatches if m.kind == "malformed"]
        assert any(m.path == ".claude/settings.json[hooks]" for m in malformed), \
            f"expected malformed mismatch; got {[(m.path, m.kind) for m in result.mismatches]}"
    finally:
        _cleanup(root)


def test_compute_baseline_does_not_persist_malformed_entries():
    """If the file is already malformed at baseline-time, the persisted
    baseline must not contain it (otherwise re-running verify would say
    'fine' on a corrupted file). Caller should fix the JSON before
    `ag integrity update`."""
    root = _make_fixture(with_settings_json=True)
    try:
        # Corrupt the file BEFORE baselining.
        (root / ".claude" / "settings.json").write_text("{garbage}")
        baseline = integrity.compute_baseline(root)
        assert ".claude/settings.json[hooks]" not in baseline, \
            f"malformed entry leaked into baseline: {list(baseline)}"
    finally:
        _cleanup(root)


def test_baseline_covers_audit_and_loader_modules():
    """Review issue #2: events.py + contracts.py + settings.sh must be
    baselined — tampering with them defeats enforcement without tripping
    integrity. We verify against the live framework lib, not a fixture."""
    project_root = REPO_ROOT
    baseline = integrity.compute_baseline(project_root)
    for must_have in (
        ".agentic/lib/events.py",
        ".agentic/lib/contracts.py",
        ".agentic/lib/settings.sh",
    ):
        assert must_have in baseline, f"baseline missing required path: {must_have}"


def test_first_run_no_baseline_returns_baseline_present_false():
    root = _make_fixture()
    try:
        # No update_baseline call — pristine fixture.
        result = integrity.verify_all(root)
        assert not result.baseline_present
        assert result.mismatches == []
    finally:
        _cleanup(root)


# ---------------------------------------------------------------------------
# AC8: catalog wires up INTEGRITY_TAMPERED
# ---------------------------------------------------------------------------


def test_catalog_has_integrity_tampered():
    assert hasattr(messages, "INTEGRITY_TAMPERED")
    r = messages.INTEGRITY_TAMPERED
    assert r.code == "integrity_tampered"
    assert 1 <= len(r.next_steps) <= 3
    assert r.verbose_detail
    assert r.plan_ref


# ---------------------------------------------------------------------------
# Plain-script runner — works without pytest installed
# ---------------------------------------------------------------------------


if __name__ == "__main__":
    tests = [
        test_compute_baseline_enumerates_all_target_kinds,
        test_compute_baseline_skips_absent_targets,
        test_save_load_baseline_roundtrip,
        test_compute_baseline_is_deterministic,
        test_partial_json_ignores_unrelated_keys_and_whitespace,
        test_verify_all_detects_modified_file,
        test_verify_all_detects_missing_in_tree,
        test_verify_all_detects_missing_in_baseline,
        test_verify_all_clean_when_unchanged,
        test_skip_envvar_honored_under_ci,
        test_skip_envvar_ignored_locally,
        test_malformed_partial_json_after_baseline_is_flagged_as_malformed,
        test_compute_baseline_does_not_persist_malformed_entries,
        test_baseline_covers_audit_and_loader_modules,
        test_first_run_no_baseline_returns_baseline_present_false,
        test_catalog_has_integrity_tampered,
    ]
    passed = failed = 0
    for fn in tests:
        try:
            fn()
            print(f"PASS  {fn.__name__}")
            passed += 1
        except Exception as e:
            print(f"FAIL  {fn.__name__}: {e}")
            failed += 1
    print(f"\n{passed}/{passed+failed} passed")
    sys.exit(1 if failed else 0)
