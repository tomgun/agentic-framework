#!/usr/bin/env python3
"""
Acceptance test runner - runs tests specific to a feature.
Parses FEATURES.md to find test files and runs them.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


FEATURE_HEADER_RE = re.compile(r"^##\s+(F-\d{4}):", re.MULTILINE)


def parse_feature_tests(features_md: str, feature_id: str) -> dict:
    """Extract test information for a specific feature."""
    # Find the feature section
    pattern = rf"^## {feature_id}:.*?(?=^## F-\d{{4}}:|$)"
    match = re.search(pattern, features_md, re.MULTILINE | re.DOTALL)
    
    if not match:
        return {}
    
    section = match.group(0)
    
    # Extract test paths from "Code:" field
    code_paths = []
    code_match = re.search(r"- Code:\s*(.+)", section)
    if code_match:
        code_paths = [p.strip() for p in code_match.group(1).split(",")]
    
    # Extract acceptance file
    acc_match = re.search(r"- Acceptance:\s*(.+)", section)
    acceptance_file = acc_match.group(1).strip() if acc_match else None
    
    return {
        "code_paths": code_paths,
        "acceptance_file": acceptance_file,
    }


def find_test_files(code_paths: list[str]) -> list[str]:
    """Find test files based on code paths."""
    test_files = []
    
    for code_path in code_paths:
        if not code_path or code_path in {"<!-- paths/modules -->", "(to be filled)"}:
            continue
        
        path = Path(code_path)
        
        # Try common test file patterns
        patterns = [
            path.with_suffix(".test" + path.suffix),  # file.test.ts
            path.with_name(path.stem + ".test" + path.suffix),  # file.test.ts
            path.parent / "tests" / path.name,  # tests/file.ts
            Path("tests") / path,  # tests/original/path
        ]
        
        for test_path in patterns:
            if test_path.exists():
                test_files.append(str(test_path))
                break
    
    return test_files


def get_test_command(stack_md_path: Path) -> str | None:
    """Extract test command from STACK.md."""
    if not stack_md_path.exists():
        return None
    
    try:
        content = stack_md_path.read_text(encoding="utf-8")
        patterns = [
            r"(?:^|\n)[\s-]*[Tt]est[:\s]+[`\"]?([^\n`\"]+)[`\"]?",
            r"(?:^|\n)[\s-]*[Tt]est command[:\s]+[`\"]?([^\n`\"]+)[`\"]?",
        ]
        
        for pattern in patterns:
            match = re.search(pattern, content)
            if match:
                return match.group(1).strip()
    except Exception:
        pass
    
    return None


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: bash .agentic/tools/accept.sh F-####")
        print("")
        print("Runs acceptance tests for a specific feature.")
        print("Looks for test files based on code paths in FEATURES.md.")
        return 1
    
    feature_id = sys.argv[1].upper()
    if not feature_id.startswith("F-"):
        feature_id = f"F-{feature_id}"
    
    repo_root = Path.cwd()
    features_path = repo_root / "spec" / "FEATURES.md"
    stack_path = repo_root / "STACK.md"
    
    if not features_path.exists():
        print("Product Management not enabled (spec/FEATURES.md missing).")
        print("Enable it with: bash .agentic/tools/enable-product-management.sh")
        return 0
    
    features_md = features_path.read_text(encoding="utf-8")
    
    if feature_id not in features_md:
        print(f"Error: {feature_id} not found in spec/FEATURES.md")
        return 1
    
    print(f"=== Running acceptance tests for {feature_id} ===\n")
    
    # Parse feature info
    feature_info = parse_feature_tests(features_md, feature_id)
    
    # Find test files
    test_files = find_test_files(feature_info.get("code_paths", []))
    
    if not test_files:
        print(f"No test files found for {feature_id}")
        print(f"Code paths: {feature_info.get('code_paths', [])}")
        print("\nTry running the full test suite with the command from STACK.md")
        return 1
    
    print(f"Found test files:")
    for tf in test_files:
        print(f"  - {tf}")
    print()
    
    # Get test command
    test_cmd = get_test_command(stack_path)
    
    if not test_cmd:
        print("No test command found in STACK.md")
        print("Please run tests manually with your test framework")
        return 1
    
    # Run tests
    print(f"Running: {test_cmd} {' '.join(test_files)}\n")
    
    try:
        result = subprocess.run(
            f"{test_cmd} {' '.join(test_files)}",
            shell=True,
            check=False
        )
        return result.returncode
    except Exception as e:
        print(f"Error running tests: {e}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

