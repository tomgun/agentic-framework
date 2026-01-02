#!/usr/bin/env python3
import re
from pathlib import Path


FEATURE_HEADER_RE = re.compile(r"^##\s+(F-\d{4}):\s*(.+?)\s*$")


def ensure_file(path: Path, content: str) -> None:
    if path.exists():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def load_template(rel_path: str) -> str:
    repo_root = Path.cwd()
    tpl = repo_root / "agentic" / "support" / "docs_templates" / rel_path
    if tpl.exists():
        return tpl.read_text(encoding="utf-8")
    return "# TODO\n"


def parse_features(features_md: str):
    feats = []
    current = None
    for line in features_md.splitlines():
        m = FEATURE_HEADER_RE.match(line)
        if m:
            current = (m.group(1), m.group(2))
            feats.append(current)
    return feats


def main() -> int:
    repo_root = Path.cwd()
    features_path = repo_root / "spec" / "FEATURES.md"
    if not features_path.exists():
        print("Missing spec/FEATURES.md (run: bash .agentic/init/scaffold.sh)")
        return 1

    # docs skeleton
    ensure_file(repo_root / "docs" / "README.md", load_template("docs_README.md"))
    ensure_file(repo_root / "docs" / "architecture" / "ARCHITECTURE.md", load_template("architecture_ARCHITECTURE.md"))
    ensure_file(repo_root / "docs" / "operations" / "RUNBOOK.md", load_template("operations_RUNBOOK.md"))
    ensure_file(repo_root / "docs" / "debugging" / "TROUBLESHOOTING.md", load_template("debugging_TROUBLESHOOTING.md"))

    # per-feature doc stubs (optional but useful)
    features_md = features_path.read_text(encoding="utf-8")
    feats = parse_features(features_md)
    for fid, name in feats:
        ensure_file(
            repo_root / "docs" / "features" / f"{fid}.md",
            f"# {fid}: {name}\n\n"
            f"- Acceptance: spec/acceptance/{fid}.md\n"
            f"- Status: see spec/FEATURES.md\n\n"
            f"## Notes\n- \n",
        )

    print("OK: docs scaffolded/verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


