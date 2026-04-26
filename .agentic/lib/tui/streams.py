"""
streams.py — Live-tail the canonical JSONL streams (R-007 spine).

Pure stdlib. No Textual / Rich dependency. The TUI app spawns a `StreamTail`
on a worker thread; the thread reads new JSONL lines as they're appended,
parses each, and dispatches via callback or queue.

Design constraints:

  * **Append-only**: streams are produced by `events.append_event` and friends
    (R-007) which only ever append + fsync. We mirror that: open in 'rb',
    seek to current EOF (or start, configurable), poll for growth.
  * **Multiple streams**: events.jsonl, delegation.jsonl, token-ledger.jsonl
    are tailed in parallel. Each line keeps its origin so the consumer knows
    which schema applies.
  * **Survives rotation**: if a file is replaced (inode changes) we reopen
    from the beginning of the new file. v0.7x writers never rotate but R-209
    might; cheap to support now.
  * **Bounded memory**: lines >LINE_BYTE_CAP are still parsed; events.py
    enforces the cap on the writer side — we trust it.
  * **Stoppable**: `tail.stop()` from another thread; the worker drains its
    open files and exits cleanly within `poll_interval`.

Not provided:

  * Backpressure: callers are expected to be fast (UI updates are cheap) or
    to drop records they can't keep up with.
  * Schema validation: we trust the writer (events.py validates before
    write). Bad lines are dropped with an `on_error` callback if supplied.
"""
from __future__ import annotations

import json
import os
import threading
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable, Iterator, Mapping, Optional


@dataclass
class StreamRecord:
    """One parsed JSONL line with its provenance.

    `stream` is the basename of the source file ('events', 'delegation',
    'token-ledger') so a single consumer can dispatch on origin.
    """
    stream: str
    line_no: int
    record: dict

    @property
    def type(self) -> str:
        """Convenience: the `type` field of events.jsonl records.
        For other streams, returns ''."""
        v = self.record.get("type")
        return v if isinstance(v, str) else ""


# Public default mapping: stream name -> path under .agentic/journal/
DEFAULT_STREAMS: Mapping[str, str] = {
    "events": "events.jsonl",
    "delegation": "delegation.jsonl",
    "token-ledger": "token-ledger.jsonl",
}


# ---------------------------------------------------------------------------
# Single-file iterator (lower-level building block)
# ---------------------------------------------------------------------------


def _iter_new_lines(path: Path, *, from_start: bool, poll_interval: float,
                    stop_event: threading.Event) -> Iterator[str]:
    """Yield UTF-8 lines as they appear at `path`. Survives file replacement.

    Internals:
      * Open in 'rb' to keep tell/seek byte-precise.
      * On open: seek to end if not from_start, else stay at 0.
      * Buffer partial lines across reads (writer fsyncs after each line, but
        we still tolerate a partial line at the read boundary).
      * Detect rotation by comparing st_ino+st_dev across polls; if changed,
        reopen from start.
      * Stop yielding when stop_event is set; finish the current partial line
        first (best-effort).
    """
    line_no = 0
    buffer = b""

    fh = None
    inode_key: Optional[tuple[int, int]] = None
    try:
        while not stop_event.is_set():
            if fh is None:
                if not path.exists():
                    if stop_event.wait(poll_interval):
                        return
                    continue
                fh = open(path, "rb")
                if not from_start:
                    fh.seek(0, os.SEEK_END)
                    from_start = True  # subsequent reopens start fresh
                try:
                    st = os.fstat(fh.fileno())
                    inode_key = (st.st_ino, st.st_dev)
                except OSError:
                    inode_key = None

            chunk = fh.read(65536)
            if chunk:
                buffer += chunk
                while b"\n" in buffer:
                    raw, buffer = buffer.split(b"\n", 1)
                    line_no += 1
                    try:
                        yield raw.decode("utf-8")
                    except UnicodeDecodeError:
                        # Drop pathological line; writer is supposed to be utf-8 only.
                        continue
                continue  # may have more buffered

            # No data this tick — check for rotation, then sleep.
            try:
                disk_st = os.stat(path)
                disk_key = (disk_st.st_ino, disk_st.st_dev)
            except OSError:
                disk_key = None
            if inode_key is not None and disk_key is not None and disk_key != inode_key:
                # Rotated. Drop buffer; reopen from start next iteration.
                fh.close()
                fh = None
                buffer = b""
                inode_key = None
                continue

            if stop_event.wait(poll_interval):
                return
    finally:
        if fh is not None:
            fh.close()


# ---------------------------------------------------------------------------
# Multi-stream tailer
# ---------------------------------------------------------------------------


class StreamTail:
    """Tail one or more JSONL streams concurrently and dispatch records.

    Usage::

        tail = StreamTail(journal_dir=Path(".agentic/journal"))
        tail.start(on_record=lambda rec: print(rec))
        ...
        tail.stop()

    Or as an iterator (single-threaded; stop with `tail.stop()` from a
    sigterm handler / Textual binding)::

        for rec in tail.iter(timeout=None):
            ...
    """

    def __init__(self, *, journal_dir: Path,
                 streams: Mapping[str, str] = DEFAULT_STREAMS,
                 poll_interval: float = 0.25,
                 from_start: bool = False) -> None:
        self.journal_dir = Path(journal_dir)
        self.streams = dict(streams)
        self.poll_interval = poll_interval
        self.from_start = from_start
        self._stop_event = threading.Event()
        self._threads: list[threading.Thread] = []
        self._on_record: Optional[Callable[[StreamRecord], None]] = None
        self._on_error: Optional[Callable[[str, str, BaseException], None]] = None
        # Single buffer for iter() consumers
        self._queue: list[StreamRecord] = []
        self._queue_lock = threading.Lock()
        self._queue_event = threading.Event()

    # -- callback API ----------------------------------------------------

    def start(self, *,
              on_record: Optional[Callable[[StreamRecord], None]] = None,
              on_error: Optional[Callable[[str, str, BaseException], None]] = None) -> None:
        """Start one daemon thread per configured stream. Returns immediately.

        on_record  — called for every parsed JSONL line, in worker thread.
        on_error   — called for parse failures: (stream_name, raw_line, exc).
        """
        if self._threads:
            raise RuntimeError("StreamTail already started")
        self._on_record = on_record
        self._on_error = on_error
        for name, rel in self.streams.items():
            path = self.journal_dir / rel
            t = threading.Thread(
                target=self._tail_one, args=(name, path),
                daemon=True, name=f"StreamTail-{name}",
            )
            self._threads.append(t)
            t.start()

    def stop(self, *, timeout: float = 2.0) -> None:
        self._stop_event.set()
        self._queue_event.set()
        for t in list(self._threads):
            t.join(timeout=timeout)
        self._threads.clear()

    @property
    def running(self) -> bool:
        return any(t.is_alive() for t in self._threads)

    # -- iterator API ----------------------------------------------------

    def iter(self, *, timeout: Optional[float] = None) -> Iterator[StreamRecord]:
        """Yield parsed records as they arrive. Uses an internal queue
        populated by the worker threads. Blocks up to `timeout` per record;
        timeout=None blocks forever (until stop()).

        The iterator path co-exists with start(on_record=...) — both fire
        for every record (the on_record callback runs first).
        """
        if not self._threads:
            self.start(on_record=self._enqueue,
                       on_error=self._on_error)
        else:
            # Already started by the caller; chain enqueue without breaking
            # any existing on_record callback.
            existing = self._on_record
            if existing is self._enqueue:
                pass  # already wired
            elif existing is None:
                self._on_record = self._enqueue
            else:
                def both(rec: StreamRecord) -> None:
                    existing(rec)
                    self._enqueue(rec)
                self._on_record = both
        while not self._stop_event.is_set():
            with self._queue_lock:
                if self._queue:
                    yield self._queue.pop(0)
                    continue
                self._queue_event.clear()
            if not self._queue_event.wait(timeout=timeout):
                if timeout is not None:
                    return

    def _enqueue(self, rec: StreamRecord) -> None:
        with self._queue_lock:
            self._queue.append(rec)
        self._queue_event.set()

    # -- worker --------------------------------------------------------

    def _tail_one(self, name: str, path: Path) -> None:
        for raw in _iter_new_lines(
            path,
            from_start=self.from_start,
            poll_interval=self.poll_interval,
            stop_event=self._stop_event,
        ):
            if not raw.strip():
                continue
            try:
                rec_dict = json.loads(raw)
                if not isinstance(rec_dict, dict):
                    raise ValueError("not a JSON object")
            except Exception as exc:  # noqa: BLE001
                if self._on_error is not None:
                    try:
                        self._on_error(name, raw, exc)
                    except Exception:
                        pass
                continue
            rec = StreamRecord(stream=name, line_no=0, record=rec_dict)
            if self._on_record is not None:
                try:
                    self._on_record(rec)
                except Exception:
                    # User callback should never crash the tailer.
                    pass


# ---------------------------------------------------------------------------
# Convenience: read existing content as a list (no tailing)
# ---------------------------------------------------------------------------


def read_jsonl(path: Path) -> list[dict]:
    """Read the entire JSONL file as a list of records. Skips bad lines
    silently (writer is trusted; a corrupt line is unusual)."""
    out: list[dict] = []
    if not Path(path).exists():
        return out
    for line in Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(obj, dict):
            out.append(obj)
    return out


__all__ = [
    "DEFAULT_STREAMS",
    "StreamRecord",
    "StreamTail",
    "read_jsonl",
]
