#!/usr/bin/env bash
set -euo pipefail

# Quality Checks for Next.js Task App
# See: .agentic/workflows/continuous_quality_validation.md

echo "=== Next.js Task App Quality Validation ==="
echo

MODE="${1:---pre-commit}"

# --- Pre-commit checks (fast, < 30 seconds) ---
if [[ "$MODE" == "--pre-commit" ]]; then
  echo "Running pre-commit checks..."
  echo

  # 1. TypeScript compilation
  echo "1/5 TypeScript compilation..."
  npm run type-check || { echo "❌ Type errors found"; exit 1; }
  echo "✅ TypeScript OK"
  echo

  # 2. ESLint
  echo "2/5 Linting (ESLint + a11y)..."
  npm run lint || { echo "❌ Lint errors found"; exit 1; }
  echo "✅ Lint OK"
  echo

  # 3. Unit tests
  echo "3/5 Unit tests (Vitest)..."
  npm test || { echo "❌ Tests failed"; exit 1; }
  echo "✅ Tests OK"
  echo

  # 4. Bundle size check
  echo "4/5 Bundle size check..."
  npm run build >/dev/null 2>&1 || { echo "❌ Build failed"; exit 1; }
  
  # Check .next/static/chunks for largest bundle
  BUNDLE_SIZE=$(du -sk .next | cut -f1)
  MAX_SIZE=512  # 500kb threshold + buffer
  
  if [[ $BUNDLE_SIZE -gt $MAX_SIZE ]]; then
    echo "❌ Bundle size ${BUNDLE_SIZE}kb exceeds ${MAX_SIZE}kb"
    echo "Run: npm run analyze to see breakdown"
    exit 1
  fi
  echo "✅ Bundle size OK (${BUNDLE_SIZE}kb < ${MAX_SIZE}kb)"
  echo

  # 5. Accessibility linting (fast check)
  echo "5/5 Accessibility linting..."
  # Already covered by ESLint with eslint-plugin-jsx-a11y
  echo "✅ Accessibility OK"
  echo

  echo "=== ✅ Pre-commit checks passed ==="
  exit 0
fi

# --- Full suite checks (comprehensive, ~2-3 minutes) ---
if [[ "$MODE" == "--full" ]]; then
  echo "Running full quality suite..."
  echo

  # Run pre-commit checks first
  bash "$0" --pre-commit || exit 1
  echo

  # 6. E2E tests (Playwright)
  echo "6/8 E2E tests (Playwright)..."
  npm run test:e2e || { echo "❌ E2E tests failed"; exit 1; }
  echo "✅ E2E tests OK"
  echo

  # 7. Bundle analysis (detailed)
  echo "7/8 Bundle analysis..."
  npm run analyze
  echo "✅ Bundle analysis complete (check report)"
  echo

  # 8. Lighthouse CI (performance, accessibility, SEO)
  echo "8/8 Lighthouse CI..."
  
  # Start dev server in background
  npm run dev >/dev/null 2>&1 &
  DEV_PID=$!
  sleep 5  # Wait for server to start
  
  # Run Lighthouse
  npx lighthouse http://localhost:3000 \
    --only-categories=performance,accessibility,seo \
    --chrome-flags="--headless" \
    --output=json \
    --output-path=./lighthouse-report.json \
    --quiet
  
  # Kill dev server
  kill $DEV_PID || true
  
  # Check thresholds
  PERF=$(jq '.categories.performance.score * 100' lighthouse-report.json | cut -d. -f1)
  A11Y=$(jq '.categories.accessibility.score * 100' lighthouse-report.json | cut -d. -f1)
  SEO=$(jq '.categories.seo.score * 100' lighthouse-report.json | cut -d. -f1)
  
  echo "Lighthouse scores:"
  echo "  Performance: ${PERF}/100 (threshold: 90)"
  echo "  Accessibility: ${A11Y}/100 (threshold: 95)"
  echo "  SEO: ${SEO}/100 (threshold: 85)"
  
  FAILED=0
  [[ $PERF -lt 90 ]] && { echo "❌ Performance below threshold"; FAILED=1; }
  [[ $A11Y -lt 95 ]] && { echo "❌ Accessibility below threshold"; FAILED=1; }
  [[ $SEO -lt 85 ]] && { echo "❌ SEO below threshold"; FAILED=1; }
  
  if [[ $FAILED -eq 1 ]]; then
    echo "See lighthouse-report.json for details"
    exit 1
  fi
  
  echo "✅ Lighthouse OK"
  echo

  echo "=== ✅ Full quality suite passed ==="
  exit 0
fi

echo "Usage: $0 [--pre-commit | --full]"
echo "  --pre-commit: Fast checks for pre-commit hook (<30s)"
echo "  --full: Comprehensive checks including Lighthouse (~2-3min)"
exit 1

