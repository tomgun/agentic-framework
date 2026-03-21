"""Tests for session-analyze.py — JSONL parsing and violation detection."""

import json
import os
import sys
import tempfile

import pytest

# Add tools directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".agentic", "lib", "tools"))
import importlib.util

SCRIPT_PATH = os.path.join(
    os.path.dirname(__file__), "..", ".agentic", "lib", "tools", "session-analyze.py"
)
spec = importlib.util.spec_from_file_location("session_analyze", SCRIPT_PATH)
sa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sa)


def _make_jsonl(messages: list[dict]) -> str:
    """Write messages to a temp JSONL file, return path."""
    fd, path = tempfile.mkstemp(suffix=".jsonl")
    with os.fdopen(fd, "w") as f:
        for msg in messages:
            f.write(json.dumps(msg) + "\n")
    return path


def _ts(minute: int) -> str:
    return f"2026-03-20T10:{minute:02d}:00Z"


# --- parse_jsonl ---


def test_parse_jsonl_valid():
    path = _make_jsonl([{"type": "user", "timestamp": _ts(0)}])
    try:
        msgs = sa.parse_jsonl(path)
        assert len(msgs) == 1
        assert msgs[0]["type"] == "user"
    finally:
        os.unlink(path)


def test_parse_jsonl_skips_malformed():
    fd, path = tempfile.mkstemp(suffix=".jsonl")
    with os.fdopen(fd, "w") as f:
        f.write('{"valid": true}\n')
        f.write("not json\n")
        f.write('{"also": "valid"}\n')
    try:
        msgs = sa.parse_jsonl(path)
        assert len(msgs) == 2
    finally:
        os.unlink(path)


# --- extract_events ---


def test_extract_user_prompt():
    messages = [
        {"type": "user", "timestamp": _ts(0), "message": {"content": "implement F-0100"}}
    ]
    events = sa.extract_events(messages)
    assert len(events) == 1
    assert events[0]["type"] == "user_prompt"
    assert "implement" in events[0]["text"]


def test_extract_tool_use():
    messages = [
        {
            "type": "assistant",
            "timestamp": _ts(1),
            "message": {
                "content": [
                    {"type": "tool_use", "name": "ExitPlanMode", "input": {}}
                ]
            },
        }
    ]
    events = sa.extract_events(messages)
    assert len(events) == 1
    assert events[0]["type"] == "tool_use"
    assert events[0]["tool_name"] == "ExitPlanMode"


def test_extract_skips_local_commands():
    messages = [
        {"type": "user", "timestamp": _ts(0), "message": {"content": "<local-command>foo</local-command>"}}
    ]
    events = sa.extract_events(messages)
    assert len(events) == 0


# --- detect_violations ---


def _tool(name: str, ts_min: int, tool_input: dict | None = None) -> dict:
    return {
        "type": "assistant",
        "timestamp": _ts(ts_min),
        "message": {
            "content": [{"type": "tool_use", "name": name, "input": tool_input or {}}]
        },
    }


def _user(text: str, ts_min: int) -> dict:
    return {"type": "user", "timestamp": _ts(ts_min), "message": {"content": text}}


def _text(text: str, ts_min: int) -> dict:
    return {
        "type": "assistant",
        "timestamp": _ts(ts_min),
        "message": {"content": [{"type": "text", "text": text}]},
    }


def test_stopped_after_plan_exit():
    """ExitPlanMode followed by user prompt (no Agent spawn) = violation."""
    messages = [
        _tool("ExitPlanMode", 0),
        _tool("Write", 1, {"file_path": "journal/plan.md"}),  # allowlisted
        _user("continue please", 5),
    ]
    events = sa.extract_events(messages)
    violations = sa.detect_violations(events)
    assert len(violations) == 1
    assert violations[0]["type"] == "stopped_after_plan_exit"


def test_no_violation_when_agent_spawned():
    """ExitPlanMode followed by Agent spawn = no violation."""
    messages = [
        _tool("ExitPlanMode", 0),
        _tool("Agent", 1, {"description": "spawn critic"}),
        _user("looks good", 5),
    ]
    events = sa.extract_events(messages)
    violations = sa.detect_violations(events)
    assert len(violations) == 0


def test_code_before_review_grouped():
    """Multiple file edits before APPROVED = one grouped violation."""
    messages = [
        _tool("EnterPlanMode", 0),
        _tool("ExitPlanMode", 1),
        _tool("Edit", 2, {"file_path": "src/main.py"}),
        _tool("Write", 3, {"file_path": "src/utils.py"}),
        _tool("Edit", 4, {"file_path": "src/config.py"}),
        _text("**Status**: APPROVED", 5),
    ]
    events = sa.extract_events(messages)
    violations = sa.detect_violations(events)
    code_violations = [v for v in violations if v["type"] == "code_before_review"]
    assert len(code_violations) == 1
    assert len(code_violations[0]["files"]) == 3


def test_code_before_review_allowlist():
    """Edits to spec/test/journal files are not flagged."""
    messages = [
        _tool("EnterPlanMode", 0),
        _tool("ExitPlanMode", 1),
        _tool("Edit", 2, {"file_path": "spec/acceptance/F-0100.md"}),
        _tool("Write", 3, {"file_path": "tests/test_foo.py"}),
        _tool("Edit", 4, {"file_path": ".agentic/journal/plans/plan.md"}),
        _tool("Edit", 5, {"file_path": ".agentic/session/AGENTS.json"}),
    ]
    events = sa.extract_events(messages)
    violations = sa.detect_violations(events)
    code_violations = [v for v in violations if v["type"] == "code_before_review"]
    assert len(code_violations) == 0


def test_skipped_planning():
    """ag implement without prior EnterPlanMode = violation."""
    messages = [
        _tool("Bash", 0, {"command": "bash .agentic/lib/tools/ag.sh implement F-0100"}),
    ]
    events = sa.extract_events(messages)
    violations = sa.detect_violations(events)
    assert len(violations) == 1
    assert violations[0]["type"] == "skipped_planning"


def test_no_skipped_planning_when_plan_entered():
    """ag implement after EnterPlanMode = no violation."""
    messages = [
        _tool("EnterPlanMode", 0),
        _tool("ExitPlanMode", 1),
        _tool("Bash", 2, {"command": "ag implement F-0100"}),
    ]
    events = sa.extract_events(messages)
    violations = sa.detect_violations(events)
    skipped = [v for v in violations if v["type"] == "skipped_planning"]
    assert len(skipped) == 0


def test_framework_state_files_allowlisted():
    """Framework state files (BACKLOG.json, FEATURES.md) should not trigger code_before_review."""
    messages = [
        _tool("EnterPlanMode", 0),
        _tool("ExitPlanMode", 1),
        _tool("Edit", 2, {"file_path": ".agentic/BACKLOG.json"}),
        _tool("Edit", 3, {"file_path": ".agentic/spec/FEATURES.md"}),
        _tool("Edit", 4, {"file_path": "STACK.md"}),
        _tool("Edit", 5, {"file_path": ".agentic/OVERVIEW.md"}),
    ]
    events = sa.extract_events(messages)
    violations = sa.detect_violations(events)
    code_violations = [v for v in violations if v["type"] == "code_before_review"]
    assert len(code_violations) == 0


# --- F-0242: YAML-driven violation detection ---


def test_load_violations_yaml():
    """violations.yaml loads and has expected structure."""
    patterns = sa.load_violations_yaml()
    assert len(patterns) == 3
    names = {p["name"] for p in patterns}
    assert names == {"stopped_after_plan_exit", "code_before_review", "skipped_planning"}
    for p in patterns:
        assert "handler" in p
        assert "config" in p


def test_yaml_violations_match_hardcoded():
    """YAML-driven detect_violations produces identical output to defaults.

    Tests the stopped_after_plan_exit case with both YAML patterns and
    fallback (no YAML), ensuring they produce the same violation types.
    """
    messages = [
        _tool("ExitPlanMode", 0),
        _tool("Write", 1, {"file_path": "journal/plan.md"}),
        _user("continue please", 5),
    ]
    events = sa.extract_events(messages)

    # With YAML patterns (default)
    v_yaml = sa.detect_violations(events)
    # With explicit empty patterns (triggers fallback)
    v_fallback = sa.detect_violations(events, patterns=[])

    # Both should detect the same violation types
    assert len(v_yaml) == len(v_fallback)
    assert v_yaml[0]["type"] == v_fallback[0]["type"] == "stopped_after_plan_exit"


def test_allowlist_from_yaml_config():
    """Allowlist reads from YAML config, not just hard-coded defaults."""
    patterns = sa.load_violations_yaml()
    cbr_pattern = next(p for p in patterns if p["name"] == "code_before_review")
    config = cbr_pattern["config"]

    # Verify YAML allowlist contains expected entries
    assert "spec/" in config["allowlist_prefixes"]
    assert "tests/" in config["allowlist_prefixes"]
    assert ".claude/plans/" in config["allowlist_substrings"]
    assert "-plan.md" in config["allowlist_suffixes"]

    # Verify the allowlist checker works with YAML config
    assert sa._is_allowlisted("spec/acceptance/F-0100.md", config)
    assert sa._is_allowlisted("tests/test_foo.py", config)
    assert not sa._is_allowlisted("src/main.py", config)
