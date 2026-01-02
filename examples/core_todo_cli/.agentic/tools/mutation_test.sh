#!/usr/bin/env bash
# mutation_test.sh: Run mutation testing on specified files/directories
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TARGET_PATH="${1:-.}"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              MUTATION TESTING                                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${BLUE}Target: ${TARGET_PATH}${NC}"
echo ""

# Detect language/framework and run appropriate mutation tool
detect_and_run() {
  # JavaScript/TypeScript (Stryker)
  if [[ -f "package.json" ]]; then
    if grep -q "@stryker-mutator/core" package.json 2>/dev/null; then
      echo -e "${GREEN}✓ Detected Stryker (JavaScript/TypeScript)${NC}"
      echo ""
      if [[ "$TARGET_PATH" != "." ]]; then
        echo "Running: npx stryker run --mutate \"${TARGET_PATH}/**/*.[jt]s\""
        npx stryker run --mutate "${TARGET_PATH}/**/*.[jt]s"
      else
        echo "Running: npx stryker run"
        npx stryker run
      fi
      return 0
    else
      echo -e "${YELLOW}⚠ Stryker not installed.${NC}"
      echo "Install: npm install --save-dev @stryker-mutator/core @stryker-mutator/jest-runner"
      echo "Setup:   npx stryker init"
      return 1
    fi
  fi

  # Python (mutmut)
  if [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]]; then
    if command -v mutmut >/dev/null 2>&1; then
      echo -e "${GREEN}✓ Detected mutmut (Python)${NC}"
      echo ""
      if [[ "$TARGET_PATH" != "." ]]; then
        echo "Running: mutmut run --paths-to-mutate=${TARGET_PATH}"
        mutmut run --paths-to-mutate="${TARGET_PATH}"
      else
        echo "Running: mutmut run"
        mutmut run
      fi
      echo ""
      echo "View results: mutmut results"
      echo "Show details: mutmut show <id>"
      return 0
    else
      echo -e "${YELLOW}⚠ mutmut not installed.${NC}"
      echo "Install: pip install mutmut"
      return 1
    fi
  fi

  # Go
  if [[ -f "go.mod" ]]; then
    if command -v go-mutesting >/dev/null 2>&1; then
      echo -e "${GREEN}✓ Detected go-mutesting (Go)${NC}"
      echo ""
      echo "Running: go-mutesting ${TARGET_PATH}/..."
      go-mutesting "${TARGET_PATH}/..."
      return 0
    else
      echo -e "${YELLOW}⚠ go-mutesting not installed.${NC}"
      echo "Install: go install github.com/zimmski/go-mutesting/cmd/go-mutesting@latest"
      return 1
    fi
  fi

  # Rust
  if [[ -f "Cargo.toml" ]]; then
    if command -v cargo-mutants >/dev/null 2>&1; then
      echo -e "${GREEN}✓ Detected cargo-mutants (Rust)${NC}"
      echo ""
      if [[ "$TARGET_PATH" != "." ]]; then
        echo "Running: cargo mutants --file ${TARGET_PATH}"
        cargo mutants --file "${TARGET_PATH}"
      else
        echo "Running: cargo mutants"
        cargo mutants
      fi
      return 0
    else
      echo -e "${YELLOW}⚠ cargo-mutants not installed.${NC}"
      echo "Install: cargo install cargo-mutants"
      return 1
    fi
  fi

  # Java (PIT)
  if [[ -f "pom.xml" ]] || [[ -f "build.gradle" ]]; then
    if grep -q "pitest" pom.xml 2>/dev/null || grep -q "pitest" build.gradle 2>/dev/null; then
      echo -e "${GREEN}✓ Detected PIT (Java)${NC}"
      echo ""
      if [[ -f "pom.xml" ]]; then
        echo "Running: mvn test org.pitest:pitest-maven:mutationCoverage"
        mvn test org.pitest:pitest-maven:mutationCoverage
      else
        echo "Running: gradle pitest"
        gradle pitest
      fi
      return 0
    else
      echo -e "${YELLOW}⚠ PIT not configured.${NC}"
      echo "See: https://pitest.org/quickstart/"
      return 1
    fi
  fi

  # No mutation tool found
  echo -e "${RED}✗ No mutation testing tool detected for this project.${NC}"
  echo ""
  echo "Supported tools:"
  echo "  - JavaScript/TypeScript: Stryker (npm install --save-dev @stryker-mutator/core)"
  echo "  - Python: mutmut (pip install mutmut)"
  echo "  - Go: go-mutesting (go install github.com/zimmski/go-mutesting/cmd/go-mutesting@latest)"
  echo "  - Rust: cargo-mutants (cargo install cargo-mutants)"
  echo "  - Java: PIT (https://pitest.org/quickstart/)"
  echo ""
  echo "See .agentic/quality/test_strategy.md for setup instructions."
  return 1
}

detect_and_run

EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
  echo ""
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║              MUTATION TESTING COMPLETE                         ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
  echo "Next steps:"
  echo "  1. Review surviving mutants (mutations that didn't cause test failures)"
  echo "  2. Add/strengthen tests for high-value survivors"
  echo "  3. Mark equivalent mutants (semantically identical to original)"
  echo ""
  echo "See .agentic/quality/test_strategy.md for interpretation guidance."
fi

exit $EXIT_CODE

