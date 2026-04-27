#!/usr/bin/env bash
# commands/watch.sh — `ag watch` lightweight events.jsonl tail (R-009).
# Sourced by ag.sh. Depends on: ROOT_DIR.

cmd_watch() {
    local journal_dir="$ROOT_DIR/.agentic/journal"
    PYTHONPATH="$ROOT_DIR/.agentic/lib${PYTHONPATH:+:$PYTHONPATH}" \
        python3 -m watch \
        --journal-dir "$journal_dir" \
        "$@"
}
