#!/usr/bin/env python3
"""
Interactive LLM Test Runner

Enables running LLM behavioral tests from within IDE-based agents (Cursor, Copilot).
Instead of calling a CLI, the agent reads test definitions and executes them interactively.

Usage:
    python tests/llm/interactive_runner.py --list              # List available tests
    python tests/llm/interactive_runner.py --critical          # Show critical tests
    python tests/llm/interactive_runner.py --setup 001         # Setup test project for test 001
    python tests/llm/interactive_runner.py --verify 001        # Verify test 001 outcomes
    python tests/llm/interactive_runner.py --interactive       # Full interactive mode
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any

# Colors for terminal output
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    BOLD = '\033[1m'
    NC = '\033[0m'  # No Color

    @classmethod
    def disable(cls):
        cls.RED = cls.GREEN = cls.YELLOW = cls.BLUE = cls.BOLD = cls.NC = ''


# Disable colors if not a TTY
if not sys.stdout.isatty():
    Colors.disable()


def get_framework_root() -> Path:
    """Get the framework root directory."""
    script_path = Path(__file__).resolve()
    return script_path.parent.parent.parent


def load_test_definitions() -> dict:
    """Load test definitions from JSON file."""
    defs_path = get_framework_root() / "tests" / "llm" / "test_definitions.json"
    if not defs_path.exists():
        print(f"{Colors.RED}Error: Test definitions not found at {defs_path}{Colors.NC}")
        sys.exit(1)
    
    with open(defs_path) as f:
        return json.load(f)


def list_tests(category: str = None) -> None:
    """List available tests, optionally filtered by category."""
    defs = load_test_definitions()
    
    print(f"\n{Colors.BOLD}Available LLM Behavioral Tests{Colors.NC}")
    print("=" * 60)
    
    for test in defs["tests"]:
        if category and test["category"].lower() != category.lower():
            continue
        
        cat_color = {
            "Critical": Colors.RED,
            "Important": Colors.YELLOW,
            "Normal": Colors.BLUE
        }.get(test["category"], Colors.NC)
        
        print(f"\n{Colors.BOLD}{test['id']}{Colors.NC} [{cat_color}{test['category']}{Colors.NC}]")
        print(f"  {test['description']}")
        print(f"  Profile: {test['profile']} | Section: {test['section']}")
        print(f"  Prompt: \"{test['prompt'][:50]}{'...' if len(test['prompt']) > 50 else ''}\"")
    
    print()


def setup_test_project(test_id: str) -> Path:
    """Create a fresh test project for the given test."""
    defs = load_test_definitions()
    
    # Find the test
    test = None
    for t in defs["tests"]:
        if t["id"] == test_id or t["id"].startswith(test_id):
            test = t
            break
    
    if not test:
        print(f"{Colors.RED}Error: Test '{test_id}' not found{Colors.NC}")
        sys.exit(1)
    
    # Create temp directory
    test_dir = Path(tempfile.mkdtemp(prefix=f"llm-test-{test_id}-"))
    
    print(f"\n{Colors.BLUE}Setting up test project for: {test['id']}{Colors.NC}")
    print(f"Directory: {test_dir}")
    
    # Initialize git
    subprocess.run(["git", "init", "--quiet"], cwd=test_dir, check=True)
    subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=test_dir, check=True)
    subprocess.run(["git", "config", "user.name", "Test User"], cwd=test_dir, check=True)
    
    # Install framework
    framework_root = get_framework_root()
    install_script = framework_root / "install.sh"
    
    # Run install with 'n' for agent suggestions prompt
    result = subprocess.run(
        ["bash", str(install_script), "."],
        cwd=test_dir,
        input=b"n\n",
        capture_output=True
    )
    
    if result.returncode != 0:
        print(f"{Colors.YELLOW}Warning: Install script returned non-zero{Colors.NC}")
    
    # Set up profile-specific structure
    if test["profile"] == "formal":
        (test_dir / "spec" / "acceptance").mkdir(parents=True, exist_ok=True)
        (test_dir / "spec" / "FEATURES.md").write_text("# Features\n")
        (test_dir / "STATUS.md").write_text("# Status\n")
    
    # Create setup files from test definition
    setup_files = test.get("setup", {}).get("files", {})
    for file_path, content in setup_files.items():
        full_path = test_dir / file_path
        full_path.parent.mkdir(parents=True, exist_ok=True)
        full_path.write_text(content)
    
    # Initial commit
    subprocess.run(["git", "add", "-A"], cwd=test_dir, check=True)
    subprocess.run(["git", "commit", "-m", "Initial setup", "--quiet"], cwd=test_dir, check=True)
    
    print(f"{Colors.GREEN}✓ Test project ready{Colors.NC}")
    
    # Print instructions for the agent
    print(f"\n{Colors.BOLD}{'=' * 60}{Colors.NC}")
    print(f"{Colors.BOLD}TEST: {test['id']}{Colors.NC}")
    print(f"{Colors.BOLD}{'=' * 60}{Colors.NC}")
    print(f"\n{Colors.YELLOW}Description:{Colors.NC} {test['description']}")
    print(f"\n{Colors.YELLOW}Category:{Colors.NC} {test['category']}")
    print(f"\n{Colors.YELLOW}Test Project:{Colors.NC} {test_dir}")
    print(f"\n{Colors.YELLOW}PROMPT TO SEND:{Colors.NC}")
    print(f"\n  {Colors.GREEN}\"{test['prompt']}\"{Colors.NC}")
    print(f"\n{Colors.YELLOW}Expected Behavior:{Colors.NC}")
    
    expected = test["expected"]
    if expected.get("output_contains"):
        print(f"  - Output should contain: {expected['output_contains']}")
    if expected.get("output_contains_any"):
        print(f"  - Output should contain any of: {expected['output_contains_any']}")
    if expected.get("output_not_contains"):
        print(f"  - Output should NOT contain: {expected['output_not_contains']}")
    if expected.get("file_exists"):
        print(f"  - Files should exist: {expected['file_exists']}")
    if expected.get("file_not_exists"):
        print(f"  - Files should NOT exist: {expected['file_not_exists']}")
    if expected.get("max_commits"):
        print(f"  - Max commits allowed: {expected['max_commits']}")
    
    print(f"\n{Colors.BOLD}{'=' * 60}{Colors.NC}")
    print(f"\nAfter responding to the prompt, run:")
    print(f"  python tests/llm/interactive_runner.py --verify {test['id']} --project {test_dir}")
    print()
    
    # Save test info for verification
    test_info_path = test_dir / ".test_info.json"
    with open(test_info_path, "w") as f:
        json.dump({"test": test, "created": datetime.now().isoformat()}, f, indent=2)
    
    return test_dir


def verify_test(test_id: str, project_dir: Path = None, agent_output: str = None) -> bool:
    """Verify that a test passed based on outcomes."""
    defs = load_test_definitions()
    
    # Find the test
    test = None
    for t in defs["tests"]:
        if t["id"] == test_id or t["id"].startswith(test_id):
            test = t
            break
    
    if not test:
        print(f"{Colors.RED}Error: Test '{test_id}' not found{Colors.NC}")
        return False
    
    # If no project dir specified, try to find it from test info
    if project_dir is None:
        # Look for most recent test project
        tmp_dir = Path(tempfile.gettempdir())
        candidates = sorted(tmp_dir.glob(f"llm-test-{test_id}*"), key=lambda p: p.stat().st_mtime, reverse=True)
        if candidates:
            project_dir = candidates[0]
        else:
            print(f"{Colors.RED}Error: No test project found. Run --setup first.{Colors.NC}")
            return False
    
    print(f"\n{Colors.BLUE}Verifying test: {test['id']}{Colors.NC}")
    print(f"Project: {project_dir}")
    
    failures = 0
    expected = test["expected"]
    
    # Verify file existence
    for file_path in expected.get("file_exists", []):
        full_path = project_dir / file_path
        if full_path.exists():
            print(f"{Colors.GREEN}✓ File exists: {file_path}{Colors.NC}")
        else:
            print(f"{Colors.RED}✗ File missing: {file_path}{Colors.NC}")
            failures += 1
    
    # Verify file non-existence
    for file_path in expected.get("file_not_exists", []):
        full_path = project_dir / file_path
        if not full_path.exists():
            print(f"{Colors.GREEN}✓ File correctly absent: {file_path}{Colors.NC}")
        else:
            print(f"{Colors.RED}✗ File should not exist: {file_path}{Colors.NC}")
            failures += 1
    
    # Verify commit count
    max_commits = expected.get("max_commits")
    if max_commits is not None:
        result = subprocess.run(
            ["git", "rev-list", "--count", "HEAD"],
            cwd=project_dir,
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            commit_count = int(result.stdout.strip())
            if commit_count <= max_commits:
                print(f"{Colors.GREEN}✓ Commit count OK: {commit_count} <= {max_commits}{Colors.NC}")
            else:
                print(f"{Colors.RED}✗ Too many commits: {commit_count} > {max_commits}{Colors.NC}")
                failures += 1
    
    # Verify output patterns (if agent output provided)
    if agent_output:
        for pattern in expected.get("output_contains", []):
            if re.search(pattern, agent_output, re.IGNORECASE):
                print(f"{Colors.GREEN}✓ Output contains: {pattern}{Colors.NC}")
            else:
                print(f"{Colors.RED}✗ Output missing pattern: {pattern}{Colors.NC}")
                failures += 1
        
        # Check "any" patterns
        any_patterns = expected.get("output_contains_any", [])
        if any_patterns:
            found_any = False
            for pattern in any_patterns:
                if re.search(pattern, agent_output, re.IGNORECASE):
                    found_any = True
                    print(f"{Colors.GREEN}✓ Output contains one of: {pattern}{Colors.NC}")
                    break
            if not found_any:
                print(f"{Colors.RED}✗ Output missing all patterns: {any_patterns}{Colors.NC}")
                failures += 1
        
        for pattern in expected.get("output_not_contains", []):
            if not re.search(pattern, agent_output, re.IGNORECASE):
                print(f"{Colors.GREEN}✓ Output correctly lacks: {pattern}{Colors.NC}")
            else:
                print(f"{Colors.RED}✗ Output should not contain: {pattern}{Colors.NC}")
                failures += 1
    else:
        # Check if there are output patterns we can't verify
        if expected.get("output_contains") or expected.get("output_contains_any") or expected.get("output_not_contains"):
            print(f"{Colors.YELLOW}⚠ Cannot verify output patterns (no agent output provided){Colors.NC}")
            print(f"  To verify output, run with: --output \"<paste agent response>\"")
    
    # Summary
    print()
    if failures == 0:
        print(f"{Colors.GREEN}{'=' * 40}{Colors.NC}")
        print(f"{Colors.GREEN}✅ TEST PASSED: {test['id']}{Colors.NC}")
        print(f"{Colors.GREEN}{'=' * 40}{Colors.NC}")
        return True
    else:
        print(f"{Colors.RED}{'=' * 40}{Colors.NC}")
        print(f"{Colors.RED}❌ TEST FAILED: {test['id']} ({failures} failures){Colors.NC}")
        print(f"{Colors.RED}{'=' * 40}{Colors.NC}")
        return False


def run_interactive_mode(category: str = None) -> None:
    """Run tests interactively, one at a time."""
    defs = load_test_definitions()
    
    tests_to_run = [t for t in defs["tests"] if not category or t["category"].lower() == category.lower()]
    
    if not tests_to_run:
        print(f"{Colors.RED}No tests found for category: {category}{Colors.NC}")
        return
    
    print(f"\n{Colors.BOLD}{'=' * 60}{Colors.NC}")
    print(f"{Colors.BOLD}Interactive LLM Test Mode{Colors.NC}")
    print(f"{Colors.BOLD}{'=' * 60}{Colors.NC}")
    print(f"\nTests to run: {len(tests_to_run)}")
    print("\nThis mode will guide you through each test:")
    print("1. Set up a test project")
    print("2. Show you the prompt to send")
    print("3. You execute the prompt (the agent responds)")
    print("4. Verify the outcomes")
    print()
    
    results = []
    
    for i, test in enumerate(tests_to_run, 1):
        print(f"\n{Colors.BOLD}[{i}/{len(tests_to_run)}] {test['id']}{Colors.NC}")
        print(f"Category: {test['category']} | {test['description']}")
        print()
        
        # Set up the project
        project_dir = setup_test_project(test["id"])
        
        # Wait for user to execute
        print(f"\n{Colors.YELLOW}After executing the prompt above, enter the agent's response{Colors.NC}")
        print(f"{Colors.YELLOW}(paste multi-line response, then press Ctrl+D or type 'DONE' on a new line):{Colors.NC}")
        print()
        
        # Read agent output
        lines = []
        try:
            while True:
                line = input()
                if line.strip() == "DONE":
                    break
                lines.append(line)
        except EOFError:
            pass
        
        agent_output = "\n".join(lines)
        
        # Verify
        passed = verify_test(test["id"], project_dir, agent_output)
        results.append({"test": test["id"], "passed": passed})
        
        # Cleanup
        if passed:
            shutil.rmtree(project_dir, ignore_errors=True)
        else:
            print(f"{Colors.YELLOW}Keeping project for debugging: {project_dir}{Colors.NC}")
    
    # Summary
    print(f"\n{Colors.BOLD}{'=' * 60}{Colors.NC}")
    print(f"{Colors.BOLD}TEST SUMMARY{Colors.NC}")
    print(f"{Colors.BOLD}{'=' * 60}{Colors.NC}")
    
    passed = sum(1 for r in results if r["passed"])
    failed = len(results) - passed
    
    for r in results:
        status = f"{Colors.GREEN}PASS{Colors.NC}" if r["passed"] else f"{Colors.RED}FAIL{Colors.NC}"
        print(f"  {r['test']}: {status}")
    
    print()
    print(f"Passed: {Colors.GREEN}{passed}{Colors.NC}")
    print(f"Failed: {Colors.RED}{failed}{Colors.NC}")
    print()


def detect_environment() -> str:
    """Detect which AI tool environment we're in."""
    # Check for CLI tools
    if shutil.which("claude"):
        return "claude"
    if shutil.which("codex"):
        return "codex"
    if shutil.which("cursor-agent") or shutil.which("cursor"):
        return "cursor-cli"
    
    # Check for IDE indicators
    if os.environ.get("CURSOR_SESSION"):
        return "cursor-ide"
    if os.environ.get("VSCODE_PID"):
        return "copilot-ide"
    
    # Check for process hints
    try:
        result = subprocess.run(["pgrep", "-f", "Cursor"], capture_output=True)
        if result.returncode == 0:
            return "cursor-ide"
    except:
        pass
    
    return "unknown"


def main():
    parser = argparse.ArgumentParser(
        description="Interactive LLM Test Runner for IDE-based agents",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --list                     List all tests
  %(prog)s --list --critical          List critical tests only
  %(prog)s --setup 001                Set up project for test 001
  %(prog)s --verify 001               Verify test 001 outcomes
  %(prog)s --interactive              Run all tests interactively
  %(prog)s --interactive --critical   Run critical tests interactively
  %(prog)s --detect                   Detect current environment
"""
    )
    
    parser.add_argument("--list", action="store_true", help="List available tests")
    parser.add_argument("--critical", action="store_true", help="Filter to critical tests only")
    parser.add_argument("--important", action="store_true", help="Filter to important tests")
    parser.add_argument("--setup", metavar="TEST_ID", help="Set up a test project")
    parser.add_argument("--verify", metavar="TEST_ID", help="Verify test outcomes")
    parser.add_argument("--project", type=Path, help="Test project directory (for --verify)")
    parser.add_argument("--output", help="Agent output to verify (for --verify)")
    parser.add_argument("--interactive", action="store_true", help="Run tests interactively")
    parser.add_argument("--detect", action="store_true", help="Detect current environment")
    
    args = parser.parse_args()
    
    # Determine category filter
    category = None
    if args.critical:
        category = "critical"
    elif args.important:
        category = "important"
    
    if args.detect:
        env = detect_environment()
        print(f"Detected environment: {env}")
        return
    
    if args.list:
        list_tests(category)
        return
    
    if args.setup:
        setup_test_project(args.setup)
        return
    
    if args.verify:
        success = verify_test(args.verify, args.project, args.output)
        sys.exit(0 if success else 1)
    
    if args.interactive:
        run_interactive_mode(category)
        return
    
    # Default: show help
    parser.print_help()


if __name__ == "__main__":
    main()

