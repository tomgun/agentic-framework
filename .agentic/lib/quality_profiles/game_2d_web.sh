#!/usr/bin/env bash
# Game 2D Web Quality Profile (Phaser 3, PixiJS, etc.)
# Purpose: Validate 2D web game quality before commits
set -euo pipefail

echo "=== 2D Web Game Quality Checks ==="

ERRORS=0

# 1. TypeScript/JavaScript Linting
if [[ -f "package.json" ]]; then
  echo "📋 Running ESLint..."
  if npm run lint --if-present 2>/dev/null; then
    echo "  ✅ ESLint passed"
  else
    echo "  ❌ ESLint failed"
    ((ERRORS++))
  fi
fi

# 2. Unit Tests
echo "🧪 Running unit tests..."
if npm test 2>/dev/null; then
  echo "  ✅ Unit tests passed"
else
  echo "  ❌ Unit tests failed"
  ((ERRORS++))
fi

# 3. Build Check
echo "🔨 Checking build..."
if npm run build --if-present 2>/dev/null; then
  echo "  ✅ Build successful"
else
  echo "  ❌ Build failed"
  ((ERRORS++))
fi

# 4. Game-Specific Checks

# Frame Rate Independence Check (grep for common anti-patterns)
echo "🎮 Checking for frame rate independence..."
if grep -r "setInterval\|setTimeout" src/ 2>/dev/null | grep -v "node_modules" | grep -v ".test." > /dev/null; then
  echo "  ⚠️  WARNING: Found setInterval/setTimeout in game code"
  echo "     Use delta time or requestAnimationFrame for frame-independent logic"
  echo "     See: .agentic/lib/quality_knowledge/game_2d_web.knowledge.md"
else
  echo "  ✅ No obvious frame rate dependencies"
fi

# Physics Stability Check (look for direct position manipulation in game loop)
echo "🔬 Checking physics usage..."
if [[ -d "src/" ]]; then
  DIRECT_POSITION_CHANGES=$(grep -r "\.x\s*=\|\.y\s*=\|\.position\s*=" src/ 2>/dev/null | grep -v "node_modules" | grep -v ".test." | wc -l || echo "0")
  if [[ "$DIRECT_POSITION_CHANGES" -gt 50 ]]; then
    echo "  ⚠️  WARNING: Many direct position changes ($DIRECT_POSITION_CHANGES found)"
    echo "     Consider using physics engine (Matter.js) for smoother, more stable movement"
  else
    echo "  ✅ Reasonable physics usage"
  fi
fi

# Asset Loading Check (ensure assets are preloaded)
echo "🖼️  Checking asset loading..."
if grep -r "new Image()\|createElement('img')" src/ 2>/dev/null | grep -v "node_modules" | grep -v ".test." > /dev/null; then
  echo "  ⚠️  WARNING: Direct image loading detected"
  echo "     Use Phaser's preload system to avoid runtime loading delays"
else
  echo "  ✅ No direct image loading found"
fi

# Performance Budget Check (bundle size)
echo "📦 Checking bundle size..."
if [[ -d "dist/" ]] || [[ -d "build/" ]]; then
  BUILD_DIR="dist"
  [[ -d "build/" ]] && BUILD_DIR="build"
  
  BUNDLE_SIZE=$(du -sh "$BUILD_DIR" 2>/dev/null | awk '{print $1}' || echo "unknown")
  echo "  Bundle size: $BUNDLE_SIZE"
  
  # Check if any single JS file is too large (>2MB is concerning for web games)
  LARGE_FILES=$(find "$BUILD_DIR" -name "*.js" -size +2M 2>/dev/null || true)
  if [[ -n "$LARGE_FILES" ]]; then
    echo "  ⚠️  WARNING: Large JavaScript files detected (>2MB)"
    echo "$LARGE_FILES"
    echo "     Consider code splitting or lazy loading"
  else
    echo "  ✅ Bundle size reasonable"
  fi
fi

# Game Feel Check (look for juice patterns)
echo "✨ Checking for 'game feel' patterns..."
JUICE_PATTERNS=0
[[ -n $(grep -r "tween\|ease\|lerp\|shake" src/ 2>/dev/null | grep -v "node_modules" | grep -v ".test.") ]] && ((JUICE_PATTERNS++))
[[ -n $(grep -r "particle\|emitter" src/ 2>/dev/null | grep -v "node_modules" | grep -v ".test.") ]] && ((JUICE_PATTERNS++))
[[ -n $(grep -r "sound\|audio\|sfx" src/ 2>/dev/null | grep -v "node_modules" | grep -v ".test.") ]] && ((JUICE_PATTERNS++))

if [[ "$JUICE_PATTERNS" -ge 2 ]]; then
  echo "  ✅ Good 'game feel' patterns found (tweens, particles, sounds)"
else
  echo "  ℹ️  Consider adding more 'juice' for better game feel"
  echo "     See: .agentic/lib/quality_knowledge/game_2d_web.knowledge.md"
fi

echo ""
echo "==================================="
if [[ $ERRORS -eq 0 ]]; then
  echo "✅ All critical checks passed!"
  exit 0
else
  echo "❌ $ERRORS critical check(s) failed"
  exit 1
fi

