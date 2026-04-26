"""
messages.py — Centralized catalog of Tier 0 gate block reasons (R-012).

Every pre-commit (R-001) and pre-push (R-002) gate failure surfaces through a
`BlockReason` constant defined here. Each entry pairs the compact failure
view (title + 1–3 next-step commands) with optional verbose extras
(`verbose_detail`, `plan_ref`) that `--verbose` callers can render.

Why centralize
--------------
- Hard guarantee that *every* block has 1–3 next steps (validated by
  `BlockReason.__post_init__` and `tests/test_gate_messages.py`).
- Single place to refine wording when UX feedback comes in — the gates stay
  thin and the catalog stays grep-able.
- `precommit_gate.py` and `prepush_gate.py` share strings instead of
  drifting; cross-references (e.g., R-005's chmod cycle) stay accurate.

Usage from a gate
-----------------
    from messages import TESTS_FAILING, GateResult  # gate keeps its own GateResult
    return GateResult.from_reason(TESTS_FAILING, detail=output_tail)

The `verbose_detail` and `plan_ref` fields are surfaced only when the gate
is invoked with `--verbose`. The default output stays compact.

This module has no runtime dependencies and is safe to import from any
hook (it is loaded before ag.sh sources the rest of the framework).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable


@dataclass(frozen=True)
class BlockReason:
    """A canonical Tier 0 gate-block reason. All fields are static text;
    runtime-specific data (test output tail, offending file list, etc.)
    flows through `GateResult.detail` instead.

    Invariant: `next_steps` has 1–3 entries. R-012 AC1 requires every block
    to surface concrete next-step commands.
    """

    code: str
    """Short stable identifier (e.g., `"tests_failing"`). Used in tests and
    by external tooling that wants to react to specific reasons without
    parsing the title string."""

    ac: str
    """Gate AC label (e.g., `"AC1"`). Mirrors the `ac` field on
    `GateResult` so the printed output groups consistently."""

    title: str
    """One-line failure headline shown at the top of the block entry."""

    next_steps: tuple[str, ...]
    """1–3 actionable commands the agent can run to resolve the block.
    Prefer concrete `ag` invocations over prose."""

    verbose_detail: str = ""
    """Multi-line expanded explanation shown only when `--verbose` is
    passed. Should explain the *why* behind the check, not duplicate the
    next_steps list."""

    plan_ref: str = ""
    """Anchor into the v5 redesign plan
    (`.agentic/journal/plans/2026-04-26-framework-ground-up-redesign-plan.md`).
    Shown only when `--verbose` is passed; lets reviewers locate the
    rationale for the check."""

    def __post_init__(self) -> None:
        n = len(self.next_steps)
        if not 1 <= n <= 3:
            raise AssertionError(
                f"BlockReason {self.code!r} must have 1–3 next_steps; got {n}"
            )
        if not self.code or not self.ac or not self.title:
            raise AssertionError(
                f"BlockReason {self.code!r}: code, ac, and title are required"
            )


# ---------------------------------------------------------------------------
# precommit_gate (R-001) reasons — checked at `git commit`
# ---------------------------------------------------------------------------


TESTS_FAILING = BlockReason(
    code="tests_failing",
    ac="AC1",
    title="tests failing",
    next_steps=(
        "Run the test command above directly to reproduce.",
        "Fix the failing tests, then re-stage and commit.",
        'If you must commit through the failure: ag commit --skip-gate "<reason>"',
    ),
    verbose_detail=(
        "Tier 0 runs the project test command (configured in STACK.md) before\n"
        "every commit. The agent does not run tests itself; the harness does,\n"
        "so the agent cannot claim 'tests pass' without running them.\n\n"
        "Common failure modes:\n"
        "  * Genuine regression — fix the code or update the test.\n"
        "  * Flaky test — rerun once; if persistent, mark skipped or fix the flake.\n"
        "  * Test command misconfigured — update STACK.md and rerun.\n\n"
        "Bypass is audited: events.jsonl records the --skip-gate reason."
    ),
    plan_ref='plan §"Tier 0 — Always-on external enforcement" §7',
)

CONTRACT_CHECK_FAILED = BlockReason(
    code="contract_check_failed",
    ac="AC2",
    title="contract check failed",
    next_steps=(
        "Run: ag contract check                  (verify all assertions)",
        "Run: ag contract check F-XXX            (focus a single feature)",
        'Fix or migrate via: ag contract migrate F-XXX --reason "<text>"',
    ),
    verbose_detail=(
        "Structural assertions in spec/contracts/*.yaml verify shipped behavior.\n"
        "When an assertion fails:\n"
        "  * Implementation drifted — fix the code to match the contract.\n"
        "  * Contract is stale — record a migration entry and update via\n"
        '    `ag contract migrate F-XXX --reason "<why>"`. Shipped contracts\n'
        "    are chmod 444 (R-005); migrate handles the chmod cycle.\n\n"
        "Pre-push (R-002) re-runs coverage on the full pushed range."
    ),
    plan_ref='plan §"Quality + verification capabilities" §7',
)

PLAN_NOT_APPROVED = BlockReason(
    code="plan_not_approved",
    ac="AC3",
    title="no approved plan for this work",
    next_steps=(
        "Run: ag plan F-XXXX                     (drafts a plan in journal/plans/)",
        "Run: ag plan review F-XXXX              (Critic + Advocate review)",
        "After approval the framework writes .agentic/session/.plan-approved.",
    ),
    verbose_detail=(
        "STACK.md has plan_review_enabled: yes. Code commits in this profile\n"
        "require a reviewed and approved plan to prevent jumping straight to\n"
        "implementation without scoping the work.\n\n"
        "ExitPlanMode creates a DRAFT — review is structural, not discretionary.\n"
        "The .plan-approved sentinel is written only after convergence\n"
        "(auto mode) or explicit user approval (manual mode)."
    ),
    plan_ref='plan §"Plan review (dialectical)"',
)

JOURNAL_STALE = BlockReason(
    code="journal_stale",
    ac="AC4",
    title="JOURNAL.md stale (no entry since last commit)",
    next_steps=(
        'Run: bash .agentic/lib/tools/journal.sh "Topic" "Outcomes" "Next" "Blockers" --why "Reason"',
        "Re-stage JOURNAL.md and commit.",
    ),
    verbose_detail=(
        "Formal+ profiles require a journal entry capturing WHY each commit\n"
        "happened. JOURNAL.md mtime is older than HEAD's commit time — meaning\n"
        "no entry has been recorded since the last commit landed.\n\n"
        "Use --why for motivation, --decision for explicit choices.\n"
        "Journal entries are the project's memory; they should let a future\n"
        "reader reconstruct context — what was tried, what was ruled out, why."
    ),
    plan_ref='plan §"Durable history"',
)

SHIPPED_CONTRACT_NO_MIGRATION = BlockReason(
    code="shipped_contract_no_migration",
    ac="AC5",
    title="shipped contract changed without migration entry",
    next_steps=(
        'Run: ag contract migrate F-XXX --reason "<why>"   (sanctioned mutation path)',
        "Or: revert the contract changes if they were unintentional.",
    ),
    verbose_detail=(
        "Contracts with lifecycle: shipped + protection: contract are the\n"
        "framework's contract-with-itself. Any change to assertions, lifecycle,\n"
        "or migrations must record a new entry in the contract's `migrations:`\n"
        "list (with trigger + reason).\n\n"
        "Two-wall design (R-005 + R-001):\n"
        "  * Filesystem: shipped contracts are chmod 444 (R-005). Direct edits\n"
        "    return EACCES. `ag contract migrate` handles the chmod cycle.\n"
        "  * Pre-commit (this gate): catches the case where the file was made\n"
        "    writable manually — the only deliberate bypass."
    ),
    plan_ref='plan §"Tier 0 — Always-on external enforcement"',
)


# ---------------------------------------------------------------------------
# prepush_gate (R-002) reasons — checked at `git push`
# ---------------------------------------------------------------------------


INTEGRATION_TESTS_FAILING = BlockReason(
    code="integration_tests_failing",
    ac="AC2",
    title="full test suite failing",
    next_steps=(
        "Run the test command above to reproduce locally.",
        "Fix or revert the failing changes; re-push.",
        'If you must push through: ag push --skip-gate "<reason>"',
    ),
    verbose_detail=(
        "Pre-push runs the full integration suite (not just per-commit unit\n"
        "tests). This is the second wall after pre-commit (R-001) — even if\n"
        "individual commits passed, the merged range may not.\n\n"
        "Bypass is audited via events.jsonl `push_attempt` entries."
    ),
    plan_ref='plan §"Tier 0 — Always-on external enforcement"',
)

COVERAGE_BELOW_THRESHOLD = BlockReason(
    code="coverage_below_threshold",
    ac="AC3",
    title="contract coverage below threshold",
    next_steps=(
        "Run: ag contract coverage               (per-feature breakdown)",
        "Add assertion-level tests for the under-covered features.",
        "Or adjust the threshold in STACK.md if the requirement has changed.",
    ),
    verbose_detail=(
        "Contract coverage = fraction of structural assertions with linked\n"
        "tests in spec/contracts/F-XXX.yaml. Default threshold: 80%.\n"
        "Pre-push enforces this on the full range; pre-commit only checks\n"
        "assertion validity, not coverage."
    ),
    plan_ref='plan §"Quality + verification capabilities" §7.b',
)

DOC_DRIFT = BlockReason(
    code="doc_drift",
    ac="AC4",
    title="doc drift detected",
    next_steps=(
        "Run: bash .agentic/lib/tools/drift.sh --docs",
        "Update each stale doc, re-stage, and re-push.",
        'Or skip with audit: ag push --skip-gate "<reason>"',
    ),
    verbose_detail=(
        "Formal+ profiles treat documentation as part of the deliverable.\n"
        "drift.sh detects docs that reference shipped features but haven't\n"
        "been updated since the last feature_done event.\n\n"
        "If a doc is genuinely no longer relevant, remove it from the\n"
        "STACK.md `## Docs` registry — that's the source of truth."
    ),
    plan_ref='plan §"Quality + verification capabilities" §7.c',
)

RANGE_MIGRATIONS_MISSING = BlockReason(
    code="range_migrations_missing",
    ac="AC5",
    title="shipped contract changed in pushed range without migration entry",
    next_steps=(
        "Identify the offending commit: git log --oneline <range> -- spec/contracts/",
        'Add the migration entry: ag contract migrate F-XXX --reason "<why>"',
        "Or revert the contract change if unintentional.",
    ),
    verbose_detail=(
        "Pre-push re-runs the shipped-contract-migration check on the full\n"
        "pushed range, not just the most recent commit. This catches the\n"
        "case where a per-commit `--skip-gate` masked the change locally.\n\n"
        "Bypass is audited."
    ),
    plan_ref='plan §"Tier 0 — Always-on external enforcement"',
)


# ---------------------------------------------------------------------------
# Catalog + helpers
# ---------------------------------------------------------------------------


ALL_REASONS: tuple[BlockReason, ...] = (
    TESTS_FAILING,
    CONTRACT_CHECK_FAILED,
    PLAN_NOT_APPROVED,
    JOURNAL_STALE,
    SHIPPED_CONTRACT_NO_MIGRATION,
    INTEGRATION_TESTS_FAILING,
    COVERAGE_BELOW_THRESHOLD,
    DOC_DRIFT,
    RANGE_MIGRATIONS_MISSING,
)


def by_code(code: str) -> BlockReason:
    """Look up a reason by stable code. Raises KeyError if unknown — the
    caller has a typo or is referencing a reason that has been removed."""
    for reason in ALL_REASONS:
        if reason.code == code:
            return reason
    raise KeyError(f"Unknown BlockReason code: {code!r}")


def format_block(
    reason: BlockReason,
    *,
    detail: str = "",
    verbose: bool = False,
    indent: str = "    ",
) -> Iterable[str]:
    """Yield formatted lines for a single block entry. Compact form by
    default; expanded when `verbose=True` (adds `verbose_detail` + `plan_ref`).

    The gate's `print_blocked` function calls this once per failure and
    writes the resulting lines to stderr.
    """
    yield f"[{reason.ac}] {reason.title}"
    if detail:
        for line in detail.splitlines():
            yield f"{indent}{line}"
    yield f"{indent}suggested next steps:"
    for step in reason.next_steps:
        yield f"{indent}  • {step}"
    if verbose:
        if reason.verbose_detail:
            yield ""
            for line in reason.verbose_detail.splitlines():
                yield f"{indent}{line}"
        if reason.plan_ref:
            yield ""
            yield f"{indent}Plan ref: {reason.plan_ref}"
