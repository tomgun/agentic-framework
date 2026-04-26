"""
state.py — Aggregated mission-control state (R-008).

Pure-Python projector. Consumes parsed JSONL records (events, delegation,
token-ledger), maintains per-panel projections:

  * **Header**   — top-level run summary (feature, profile, tokens, ETA hints).
  * **Workers**  — per-active-actor live status (current step, time on task).
  * **Events**   — bounded ring of recent events for the live stream panel.
  * **Health**   — green/yellow/red signal + escalation count + quota warning.
  * **Drilldown** — last selected item details (diff, test output, verdict).

The aggregator is thread-safe (a re-entrant lock around every mutation):
the tailer thread feeds records via `apply_record`; the UI thread reads
projections via `snapshot()`. Each public method returns or accepts only
plain data — Textual is not imported here.

Design notes:

  * **Health rules** are intentionally simple — a single `gate_blocked` event
    flips to YELLOW; an unresolved `human_needed` flips to RED. A successful
    test_run / commit / critic approval can de-escalate back to GREEN if no
    other signal is active.

  * **Worker state** is keyed by `actor` field. We track first/last seen and
    "current step" (the most recent tool_call / task_dispatch payload's
    `step` or `target` field, whichever is present). Idle workers eventually
    age out (default 5 min) so the panel doesn't accumulate ghosts.

  * **Event ring** is bounded to `event_ring_size` (default 200). Older
    events are kept on disk in events.jsonl; the panel only renders recent.

  * **Token totals** are summed across token-ledger entries. Quota %
    requires a `quota_window_tokens` set externally (R-013 / R-101 will set
    it from STACK.md `quota_pro_max_window_tokens`); without it, header
    shows raw token counts.
"""
from __future__ import annotations

import threading
import time
from dataclasses import dataclass, field
from typing import Any, Mapping, Optional


# ---------------------------------------------------------------------------
# Snapshot data classes — consumed by panels
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class HeaderSnapshot:
    feature: str
    profile: str
    mode: str
    tokens_total: int
    quota_window_tokens: Optional[int]
    quota_pct: Optional[float]
    started_at: Optional[str]
    elapsed_seconds: int
    eta_seconds: Optional[int]


@dataclass(frozen=True)
class WorkerSnapshot:
    actor: str
    last_seen: float
    current_step: str
    busy_seconds: int
    feature: str


@dataclass(frozen=True)
class EventSnapshot:
    ts: str
    type: str
    actor: str
    feature: str
    summary: str
    cost_tokens: Optional[int]
    color_hint: str  # 'green'|'yellow'|'red'|'blue'|'dim'


@dataclass(frozen=True)
class HealthSnapshot:
    status: str  # 'green'|'yellow'|'red'
    escalations: int
    last_blocked_reason: Optional[str]
    quota_alert: Optional[str]   # '70%'|'85%'|'95%'|None


@dataclass(frozen=True)
class DashboardSnapshot:
    header: HeaderSnapshot
    workers: list[WorkerSnapshot]
    events: list[EventSnapshot]
    health: HealthSnapshot
    selected_event: Optional[EventSnapshot]


# ---------------------------------------------------------------------------
# Color hints — keep all classification in one table so panels stay dumb
# ---------------------------------------------------------------------------


_COLOR_BY_TYPE: Mapping[str, str] = {
    "session_start": "blue",
    "session_end": "dim",
    "task_dispatch": "blue",
    "task_complete": "green",
    "tool_call": "dim",
    "commit": "green",
    "test_run": "green",
    "critic_verdict": "blue",
    "contract_check": "blue",
    "human_needed": "red",
    "gate_blocked": "yellow",
    "gate_skipped": "yellow",
    "push_attempt": "blue",
    "merge_attempt": "blue",
    "hotfix_commit": "yellow",
    "integrity_baseline_updated": "blue",
    "intel_invoked": "dim",
    "quota_degraded": "yellow",
}


def color_hint_for(rec_type: str, payload: Mapping[str, Any]) -> str:
    """Public helper used by panels and tested directly."""
    base = _COLOR_BY_TYPE.get(rec_type, "dim")
    # Special cases — failure semantics inside payload override the default.
    if rec_type == "test_run":
        rc = payload.get("returncode")
        if isinstance(rc, int) and rc != 0 and not payload.get("skipped"):
            return "red"
    elif rec_type == "critic_verdict":
        verdict = payload.get("verdict")
        if verdict == "request_changes":
            return "yellow"
        if verdict == "escalate":
            return "red"
    elif rec_type == "contract_check":
        rc = payload.get("returncode")
        if isinstance(rc, int) and rc != 0:
            return "yellow"
    elif rec_type == "push_attempt":
        if payload.get("blocked"):
            return "red"
    return base


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _short_summary(rec_type: str, payload: Mapping[str, Any], feature: str) -> str:
    """Compress a record into a single short line for the events stream."""
    if rec_type == "commit":
        return f"commit {payload.get('hash', '?')} {payload.get('subject', '')}".strip()
    if rec_type == "test_run":
        rc = payload.get("returncode")
        dur = payload.get("duration_ms", 0)
        if payload.get("skipped"):
            return f"tests skipped: {payload.get('reason', '')}"
        return f"tests rc={rc} ({dur}ms)"
    if rec_type == "gate_blocked":
        gate = payload.get("gate", "?")
        fails = payload.get("failures") or []
        return f"{gate} BLOCKED · " + ", ".join(f.get("ac", "") for f in fails)
    if rec_type == "gate_skipped":
        return f"{payload.get('gate', '?')} skipped: {payload.get('reason', 'unspecified')}"
    if rec_type == "critic_verdict":
        return f"critic: {payload.get('verdict', '?')} on {payload.get('target', '?')}"
    if rec_type == "contract_check":
        rc = payload.get("returncode")
        return f"contracts rc={rc}"
    if rec_type == "human_needed":
        return f"HUMAN_NEEDED: {payload.get('title', '?')}"
    if rec_type == "task_dispatch":
        return f"dispatch → {payload.get('target', '?')}"
    if rec_type == "task_complete":
        return f"task complete: {payload.get('summary', '?')}"
    if rec_type == "push_attempt":
        if payload.get("blocked"):
            return "push BLOCKED"
        if payload.get("skipped"):
            return f"push skipped: {payload.get('reason', '?')}"
        return "push ok"
    if rec_type == "tool_call":
        return f"tool: {payload.get('tool', '?')}"
    if rec_type == "intel_invoked":
        return f"intel: {payload.get('subcommand', '?')}"
    return rec_type


# ---------------------------------------------------------------------------
# Aggregator
# ---------------------------------------------------------------------------


@dataclass
class _WorkerState:
    actor: str
    first_seen: float
    last_seen: float
    current_step: str
    feature: str


class DashboardState:
    """Thread-safe aggregator for mission-control panels.

    Lifecycle:
        ds = DashboardState(feature="F-008", profile="autonomous_formal")
        ds.set_quota_window(1_500_000)              # optional
        # tailer thread:
        for rec in tail.iter(): ds.apply_record(rec)
        # UI thread:
        snap = ds.snapshot()
    """

    def __init__(self, *, feature: str = "—", profile: str = "—",
                 mode: str = "—", event_ring_size: int = 200,
                 worker_idle_seconds: float = 300.0,
                 clock=time.time) -> None:
        self.feature = feature
        self.profile = profile
        self.mode = mode
        self._event_ring_size = event_ring_size
        self._worker_idle_seconds = worker_idle_seconds
        self._clock = clock

        self._lock = threading.RLock()
        self._workers: dict[str, _WorkerState] = {}
        self._events: list[EventSnapshot] = []
        self._tokens_total = 0
        self._quota_window_tokens: Optional[int] = None
        self._escalations = 0
        self._last_blocked_reason: Optional[str] = None
        self._has_unresolved_human_needed = False
        self._started_at: Optional[str] = None
        self._started_mono: Optional[float] = None
        self._selected_event: Optional[EventSnapshot] = None

    # -- configuration ---------------------------------------------------

    def set_quota_window(self, tokens: Optional[int]) -> None:
        with self._lock:
            self._quota_window_tokens = tokens

    def set_feature(self, feature: str) -> None:
        with self._lock:
            self.feature = feature

    # -- record ingestion ------------------------------------------------

    def apply_record(self, rec) -> None:
        """`rec` is a `StreamRecord` from streams.py — but we accept any
        object exposing `.stream` and `.record` to keep this module
        importable in tests without depending on streams.StreamRecord."""
        with self._lock:
            if rec.stream == "events":
                self._apply_event(rec.record)
            elif rec.stream == "delegation":
                self._apply_delegation(rec.record)
            elif rec.stream == "token-ledger":
                self._apply_token_ledger(rec.record)

    # -- event handlers --------------------------------------------------

    def _apply_event(self, r: dict) -> None:
        rec_type = r.get("type", "")
        actor = r.get("actor", "harness")
        feature = r.get("feature") or self.feature
        ts = r.get("ts", "")
        payload = r.get("payload") or {}

        # Worker state
        if rec_type in ("session_start", "task_dispatch", "tool_call"):
            self._touch_worker(actor, feature, _short_summary(rec_type, payload, feature))
        elif rec_type in ("session_end", "task_complete"):
            self._workers.pop(actor, None)

        # Health signals
        if rec_type == "gate_blocked":
            self._escalations += 1
            failures = payload.get("failures") or []
            if failures:
                self._last_blocked_reason = (
                    failures[0].get("ac", "?") + ": " + failures[0].get("title", "")
                )
        if rec_type == "human_needed":
            self._has_unresolved_human_needed = True
        if rec_type == "session_start" and self._started_at is None:
            self._started_at = ts
            self._started_mono = self._clock()

        # Event ring
        ev = EventSnapshot(
            ts=ts, type=rec_type, actor=actor, feature=feature,
            summary=_short_summary(rec_type, payload, feature),
            cost_tokens=self._extract_cost(rec_type, payload),
            color_hint=color_hint_for(rec_type, payload),
        )
        self._push_event(ev)

    def _apply_delegation(self, r: dict) -> None:
        ts = r.get("ts", "")
        actor = r.get("actor", "harness")
        feature = r.get("feature") or self.feature
        verdict = r.get("verdict", "in_progress")
        target = r.get("target", "?")
        tokens_in = r.get("tokens_in") or 0
        tokens_out = r.get("tokens_out") or 0
        cost = (tokens_in if isinstance(tokens_in, int) else 0) + (
            tokens_out if isinstance(tokens_out, int) else 0
        )
        ev = EventSnapshot(
            ts=ts, type="delegation", actor=actor, feature=feature,
            summary=f"delegate→{actor} on {target}: {verdict}",
            cost_tokens=cost or None,
            color_hint=("green" if verdict == "approve"
                        else "yellow" if verdict == "request_changes"
                        else "red" if verdict in ("escalate", "error")
                        else "blue"),
        )
        self._push_event(ev)

    def _apply_token_ledger(self, r: dict) -> None:
        for f in ("tokens_in", "tokens_out"):
            v = r.get(f)
            if isinstance(v, int) and v > 0:
                self._tokens_total += v

    # -- helpers ---------------------------------------------------------

    @staticmethod
    def _extract_cost(rec_type: str, payload: Mapping[str, Any]) -> Optional[int]:
        if rec_type in ("commit", "merge_attempt", "push_attempt"):
            return None
        for k in ("tokens_in", "tokens_out", "cost_tokens"):
            v = payload.get(k)
            if isinstance(v, int) and v > 0:
                return v
        return None

    def _touch_worker(self, actor: str, feature: str, step: str) -> None:
        now = self._clock()
        existing = self._workers.get(actor)
        if existing is None:
            self._workers[actor] = _WorkerState(
                actor=actor, first_seen=now, last_seen=now,
                current_step=step, feature=feature,
            )
        else:
            existing.last_seen = now
            existing.current_step = step
            existing.feature = feature

    def _push_event(self, ev: EventSnapshot) -> None:
        self._events.append(ev)
        if len(self._events) > self._event_ring_size:
            # Trim oldest. Pop in batches (10%) to amortize cost on overflow.
            drop = max(1, self._event_ring_size // 10)
            del self._events[:drop]

    # -- queries ---------------------------------------------------------

    def select_event(self, index: Optional[int]) -> Optional[EventSnapshot]:
        with self._lock:
            if index is None:
                self._selected_event = None
            elif 0 <= index < len(self._events):
                self._selected_event = self._events[index]
            return self._selected_event

    def resolve_human_needed(self) -> None:
        with self._lock:
            self._has_unresolved_human_needed = False

    def snapshot(self) -> DashboardSnapshot:
        with self._lock:
            now = self._clock()
            # Prune idle workers
            stale = [k for k, w in self._workers.items()
                     if now - w.last_seen > self._worker_idle_seconds]
            for k in stale:
                self._workers.pop(k, None)

            workers = sorted(
                (
                    WorkerSnapshot(
                        actor=w.actor, last_seen=w.last_seen,
                        current_step=w.current_step,
                        busy_seconds=int(now - w.first_seen),
                        feature=w.feature,
                    )
                    for w in self._workers.values()
                ),
                key=lambda x: x.actor,
            )

            quota_pct: Optional[float] = None
            quota_alert: Optional[str] = None
            if self._quota_window_tokens and self._quota_window_tokens > 0:
                quota_pct = (self._tokens_total / self._quota_window_tokens) * 100.0
                if quota_pct >= 95.0:
                    quota_alert = "95%"
                elif quota_pct >= 85.0:
                    quota_alert = "85%"
                elif quota_pct >= 70.0:
                    quota_alert = "70%"

            elapsed = int(now - self._started_mono) if self._started_mono else 0

            health_status = "green"
            if self._has_unresolved_human_needed:
                health_status = "red"
            elif self._escalations > 0 or quota_alert == "95%":
                health_status = "yellow"
            if quota_alert == "95%":
                health_status = "red"

            return DashboardSnapshot(
                header=HeaderSnapshot(
                    feature=self.feature, profile=self.profile, mode=self.mode,
                    tokens_total=self._tokens_total,
                    quota_window_tokens=self._quota_window_tokens,
                    quota_pct=quota_pct,
                    started_at=self._started_at,
                    elapsed_seconds=elapsed,
                    eta_seconds=None,
                ),
                workers=workers,
                events=list(self._events),
                health=HealthSnapshot(
                    status=health_status,
                    escalations=self._escalations,
                    last_blocked_reason=self._last_blocked_reason,
                    quota_alert=quota_alert,
                ),
                selected_event=self._selected_event,
            )


__all__ = [
    "DashboardSnapshot",
    "DashboardState",
    "EventSnapshot",
    "HeaderSnapshot",
    "HealthSnapshot",
    "WorkerSnapshot",
    "color_hint_for",
]
