#!/usr/bin/env bash
# Web App with E2E Quality Profile (Playwright / Cypress)
# Purpose: Validate web application quality including E2E tests
set -euo pipefail

echo "=== Web App + E2E Quality Checks ==="

ERRORS=0

# 1. Linting
if [[ -f "package.json" ]]; then
  echo "Running linter..."
  if npm run lint --if-present 2>/dev/null; then
    echo "  Lint passed"
  else
    echo "  Lint failed"
    ((ERRORS++))
  fi
elif [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]]; then
  if command -v ruff &>/dev/null; then
    if ruff check . 2>/dev/null; then
      echo "  Lint passed (ruff)"
    else
      echo "  Lint failed (ruff)"
      ((ERRORS++))
    fi
  fi
fi

# 2. Unit tests
echo "Running unit tests..."
if [[ -f "package.json" ]]; then
  if npm test 2>/dev/null; then
    echo "  Unit tests passed"
  else
    echo "  Unit tests failed"
    ((ERRORS++))
  fi
elif [[ -f "pyproject.toml" ]] || [[ -f "pytest.ini" ]]; then
  if python -m pytest tests/unit/ 2>/dev/null || python -m pytest 2>/dev/null; then
    echo "  Unit tests passed"
  else
    echo "  Unit tests failed"
    ((ERRORS++))
  fi
fi

# 3. Build check
if [[ -f "package.json" ]]; then
  echo "Checking build..."
  if npm run build --if-present 2>/dev/null; then
    echo "  Build successful"
  else
    echo "  Build failed"
    ((ERRORS++))
  fi
fi

# 4. E2E tests
echo "Running E2E tests..."
if [[ -f "playwright.config.ts" ]] || [[ -f "playwright.config.js" ]]; then
  if npx playwright test 2>/dev/null; then
    echo "  E2E tests passed (Playwright)"
  else
    echo "  E2E tests failed (Playwright)"
    ((ERRORS++))
  fi
elif [[ -f "cypress.config.ts" ]] || [[ -f "cypress.config.js" ]]; then
  if npx cypress run 2>/dev/null; then
    echo "  E2E tests passed (Cypress)"
  else
    echo "  E2E tests failed (Cypress)"
    ((ERRORS++))
  fi
elif [[ -f "conftest.py" ]] && [[ -d "tests/e2e" ]]; then
  if python -m pytest tests/e2e/ 2>/dev/null; then
    echo "  E2E tests passed (pytest)"
  else
    echo "  E2E tests failed (pytest)"
    ((ERRORS++))
  fi
else
  echo "  No E2E framework detected, skipping"
fi

# 5. Screenshot collection summary
SCREENSHOT_DIRS=("test-results" "cypress/screenshots" "artifacts")
TOTAL_SCREENSHOTS=0
for dir in "${SCREENSHOT_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    count=$(find "$dir" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.webp" \) 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$count" -gt 0 ]]; then
      echo "  Found $count screenshot(s) in $dir/"
      TOTAL_SCREENSHOTS=$((TOTAL_SCREENSHOTS + count))
    fi
  fi
done
if [[ "$TOTAL_SCREENSHOTS" -gt 0 ]]; then
  echo "  Total screenshots: $TOTAL_SCREENSHOTS (use --visual for AI review)"
fi

echo ""
echo "=== Quality Check Complete ==="
if [[ $ERRORS -gt 0 ]]; then
  echo "FAILED: $ERRORS check(s) failed"
  exit 1
else
  echo "PASSED: All checks passed"
  exit 0
fi
