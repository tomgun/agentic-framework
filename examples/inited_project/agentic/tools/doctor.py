#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass
class Check:
    path: str
    kind: str  # "file" | "dir"
    purpose: str


CHECKS: list[Check] = [
    Check("AGENTS.md", "file", "agent entrypoint (rules + read-first)"),
    Check("CONTEXT_PACK.md", "file", "durable starting context"),
    Check("STATUS.md", "file", "current focus + next steps"),
    Check("STACK.md", "file", "how to run/test + constraints"),
    Check("spec", "dir", "project truth folder"),
    Check("spec/OVERVIEW.md", "file", "vision + current state + pointers"),
    Check("spec/FEATURES.md", "file", "feature registry + acceptance + tests"),
    Check("spec/NFR.md", "file", "non-functional constraints"),
    Check("spec/acceptance", "dir", "per-feature acceptance criteria"),
    Check("spec/LESSONS.md", "file", "lessons/caveats"),
    Check("spec/adr", "dir", "architecture decisions"),
    Check("docs", "dir", "system docs (long-lived)"),
]


def looks_like_template(text: str) -> bool:
    first_lines = "\n".join(text.splitlines()[:3]).lower()
    return "(template)" in first_lines or first_lines.strip().endswith("template")


def main() -> int:
    root = Path.cwd()
    missing: list[Check] = []
    empty_files: list[Check] = []
    template_like: list[Check] = []

    for c in CHECKS:
        p = root / c.path
        if c.kind == "dir":
            if not p.is_dir():
                missing.append(c)
            continue

        # file
        if not p.is_file():
            missing.append(c)
            continue

        try:
            data = p.read_text(encoding="utf-8")
        except Exception:
            data = ""

        if len(data.strip()) == 0:
            empty_files.append(c)
        elif looks_like_template(data) and p.name not in {"FEATURES.md"}:
            template_like.append(c)

    print("=== agentic doctor ===")

    if missing:
        print("\nMissing (run scaffold):")
        for c in missing:
            print(f"- {c.path} ({c.purpose})")

    if empty_files:
        print("\nEmpty (fill in):")
        for c in empty_files:
            print(f"- {c.path} ({c.purpose})")

    if template_like:
        print("\nLooks like template content (consider filling/renaming):")
        for c in template_like:
            print(f"- {c.path} ({c.purpose})")

    if not (missing or empty_files or template_like):
        print("\nOK: baseline project artifacts present")

    print("\nNext commands:")
    print("- bash agentic/tools/brief.sh")
    print("- bash agentic/tools/report.sh")
    print("- bash agentic/tools/sync_docs.sh")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


