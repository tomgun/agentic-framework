#!/usr/bin/env python3
"""
tests/test_gate_messages.py — R-012 acceptance tests.

Validates the central block-reason catalog (`.agentic/lib/hooks/messages.py`)
and its integration with the two Tier 0 gate modules:

  AC1: every BlockReason has 1–3 next-step commands
  AC2: each canonical reason has both a verbose_detail and a plan_ref
  AC3: by_code() round-trips for every catalog entry
  AC4: format_block() emits compact form by default; expanded with verbose=True
  AC5: precommit_gate.GateResult.from_reason() round-trips title + ac + steps
  AC6: prepush_gate.GateResult.from_reason() round-trips the same
  AC7: catalog covers every gate failure path that constructs a failed GateResult

Designed to run under pytest if available, but the bottom block also runs
as a plain script so the suite works in environments without pytest
installed (this container's case).
"""

from __future__ import annotations

import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
LIB_DIR = REPO_ROOT / ".agentic" / "lib"
HOOKS_DIR = LIB_DIR / "hooks"

# Make `messages`, `precommit_gate`, `prepush_gate` importable.
for path in (LIB_DIR, HOOKS_DIR):
    p = str(path)
    if p not in sys.path:
        sys.path.insert(0, p)

import messages  # type: ignore  # noqa: E402


# ---------------------------------------------------------------------------
# AC1: every reason has 1–3 next-step commands
# ---------------------------------------------------------------------------

def test_every_reason_has_one_to_three_next_steps():
    failures = []
    for reason in messages.ALL_REASONS:
        n = len(reason.next_steps)
        if not 1 <= n <= 3:
            failures.append(f"{reason.code}: has {n} next_steps (expected 1-3)")
    assert not failures, "next_steps count violated:\n  " + "\n  ".join(failures)


def test_dataclass_invariant_rejects_zero_or_four_next_steps():
    """The BlockReason.__post_init__ guard fires before tests run, but
    confirm the invariant via a constructed offender."""
    import pytest as _pytest  # type: ignore

    with _pytest.raises(AssertionError):
        messages.BlockReason(
            code="bad",
            ac="AC9",
            title="x",
            next_steps=(),  # 0 — invalid
        )
    with _pytest.raises(AssertionError):
        messages.BlockReason(
            code="bad",
            ac="AC9",
            title="x",
            next_steps=("a", "b", "c", "d"),  # 4 — invalid
        )


# ---------------------------------------------------------------------------
# AC2: every reason has verbose_detail + plan_ref
# ---------------------------------------------------------------------------

def test_every_reason_has_verbose_detail_and_plan_ref():
    missing_detail = [r.code for r in messages.ALL_REASONS if not r.verbose_detail.strip()]
    missing_plan = [r.code for r in messages.ALL_REASONS if not r.plan_ref.strip()]
    assert not missing_detail, f"missing verbose_detail: {missing_detail}"
    assert not missing_plan, f"missing plan_ref: {missing_plan}"


# ---------------------------------------------------------------------------
# AC3: by_code() round-trip
# ---------------------------------------------------------------------------

def test_by_code_roundtrip():
    for reason in messages.ALL_REASONS:
        assert messages.by_code(reason.code) is reason


def test_by_code_unknown_raises():
    try:
        messages.by_code("definitely_not_a_real_code")
    except KeyError:
        return
    raise AssertionError("by_code() should raise KeyError on unknown code")


# ---------------------------------------------------------------------------
# AC4: format_block compact vs verbose
# ---------------------------------------------------------------------------

def test_format_block_compact_excludes_verbose_extras():
    lines = list(messages.format_block(messages.TESTS_FAILING))
    text = "\n".join(lines)
    # Compact form contains the title + steps but not the verbose_detail body.
    assert "tests failing" in text
    assert "ag commit --skip-gate" in text
    # The verbose-only "Plan ref:" prefix must not leak.
    assert "Plan ref:" not in text


def test_format_block_verbose_includes_extras():
    lines = list(messages.format_block(messages.TESTS_FAILING, verbose=True))
    text = "\n".join(lines)
    assert "Plan ref:" in text
    # First sentence of the verbose_detail body should appear.
    assert "Tier 0 runs the project test command" in text


def test_format_block_includes_runtime_detail():
    lines = list(messages.format_block(
        messages.TESTS_FAILING,
        detail="command: pytest\nreturn code: 1",
    ))
    text = "\n".join(lines)
    assert "command: pytest" in text
    assert "return code: 1" in text


# ---------------------------------------------------------------------------
# AC5: precommit_gate.GateResult.from_reason
# ---------------------------------------------------------------------------

def test_precommit_gate_result_from_reason():
    import precommit_gate  # type: ignore

    result = precommit_gate.GateResult.from_reason(
        messages.TESTS_FAILING, detail="X"
    )
    assert result.failed is True
    assert result.ac == messages.TESTS_FAILING.ac
    assert result.title == messages.TESTS_FAILING.title
    assert result.next_steps == list(messages.TESTS_FAILING.next_steps)
    assert result.detail == "X"
    assert result.reason is messages.TESTS_FAILING


# ---------------------------------------------------------------------------
# AC6: prepush_gate.GateResult.from_reason
# ---------------------------------------------------------------------------

def test_prepush_gate_result_from_reason():
    import prepush_gate  # type: ignore

    result = prepush_gate.GateResult.from_reason(
        messages.INTEGRATION_TESTS_FAILING, detail="Y"
    )
    assert result.failed is True
    assert result.ac == messages.INTEGRATION_TESTS_FAILING.ac
    assert result.title == messages.INTEGRATION_TESTS_FAILING.title
    assert result.reason is messages.INTEGRATION_TESTS_FAILING


# ---------------------------------------------------------------------------
# AC7: catalog coverage
# ---------------------------------------------------------------------------

def test_precommit_gate_uses_catalog_for_every_failed_path():
    """Every `from_reason(...)` call in precommit_gate.py must reference a
    catalog constant that exists. This guards against typos and accidental
    reintroduction of inline next_steps lists."""
    src = (HOOKS_DIR / "precommit_gate.py").read_text()
    # Heuristic: each `from_reason(messages.X` mention must resolve.
    import re
    refs = set(re.findall(r"from_reason\(messages\.([A-Z_]+)", src))
    assert refs, "precommit_gate.py has no from_reason(messages.X) references — wiring missing"
    catalog_codes = {r.code.upper() for r in messages.ALL_REASONS}
    for ref in refs:
        # Each ref maps to the lowercase `code` attr; messages.<NAME> is a
        # module-level binding pointing at a BlockReason.
        assert hasattr(messages, ref), f"precommit_gate references messages.{ref} which does not exist"


def test_prepush_gate_uses_catalog_for_every_failed_path():
    src = (HOOKS_DIR / "prepush_gate.py").read_text()
    import re
    refs = set(re.findall(r"from_reason\(messages\.([A-Z_]+)", src))
    assert refs, "prepush_gate.py has no from_reason(messages.X) references — wiring missing"
    for ref in refs:
        assert hasattr(messages, ref), f"prepush_gate references messages.{ref} which does not exist"


# ---------------------------------------------------------------------------
# Plain-script runner — works without pytest installed
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    tests = [
        test_every_reason_has_one_to_three_next_steps,
        # The pytest-only one is skipped when run as a script:
        # test_dataclass_invariant_rejects_zero_or_four_next_steps,
        test_every_reason_has_verbose_detail_and_plan_ref,
        test_by_code_roundtrip,
        test_by_code_unknown_raises,
        test_format_block_compact_excludes_verbose_extras,
        test_format_block_verbose_includes_extras,
        test_format_block_includes_runtime_detail,
        test_precommit_gate_result_from_reason,
        test_prepush_gate_result_from_reason,
        test_precommit_gate_uses_catalog_for_every_failed_path,
        test_prepush_gate_uses_catalog_for_every_failed_path,
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
