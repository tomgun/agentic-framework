#!/usr/bin/env bash
# Game 2D Mobile Quality Profile (React Native + Expo game, SpriteKit, libGDX)
# Purpose: Validate 2D mobile game quality before commits
set -euo pipefail

echo "=== 2D Mobile Game Quality Checks ==="

ERRORS=0

# Detect platform
IS_EXPO=false
IS_SPRITEKIT=false
IS_LIBGDX=false

[[ -f "app.json" ]] && IS_EXPO=true
[[ -f "*.xcodeproj" ]] || [[ -f "*.xcworkspace" ]] && IS_SPRITEKIT=true
[[ -f "build.gradle" ]] && IS_LIBGDX=true

# 1. Linting
if [[ "$IS_EXPO" == true ]]; then
  echo "📋 Running ESLint (Expo/React Native)..."
  if npm run lint --if-present 2>/dev/null; then
    echo "  ✅ ESLint passed"
  else
    echo "  ❌ ESLint failed"
    ((ERRORS++))
  fi
elif [[ "$IS_SPRITEKIT" == true ]]; then
  echo "📋 Running SwiftLint..."
  if command -v swiftlint >/dev/null 2>&1; then
    if swiftlint 2>/dev/null; then
      echo "  ✅ SwiftLint passed"
    else
      echo "  ❌ SwiftLint failed"
      ((ERRORS++))
    fi
  else
    echo "  ⚠️  SwiftLint not installed (optional)"
  fi
elif [[ "$IS_LIBGDX" == true ]]; then
  echo "📋 Running Gradle checks..."
  if ./gradlew check 2>/dev/null; then
    echo "  ✅ Gradle checks passed"
  else
    echo "  ❌ Gradle checks failed"
    ((ERRORS++))
  fi
fi

# 2. Unit Tests
echo "🧪 Running unit tests..."
if [[ "$IS_EXPO" == true ]]; then
  if npm test 2>/dev/null; then
    echo "  ✅ Unit tests passed"
  else
    echo "  ❌ Unit tests failed"
    ((ERRORS++))
  fi
elif [[ "$IS_LIBGDX" == true ]]; then
  if ./gradlew test 2>/dev/null; then
    echo "  ✅ Unit tests passed"
  else
    echo "  ❌ Unit tests failed"
    ((ERRORS++))
  fi
fi

# 3. Game-Specific Checks

# Frame Rate Independence
echo "🎮 Checking for frame rate independence..."
if [[ "$IS_EXPO" == true ]]; then
  # Check for Animated.timing without proper delta time handling
  if grep -r "Animated\.timing\|setInterval\|setTimeout" src/ 2>/dev/null | grep -v "node_modules" | grep -v ".test." > /dev/null; then
    echo "  ⚠️  WARNING: Check that animations use delta time or are frame-independent"
  else
    echo "  ✅ No obvious frame rate dependencies"
  fi
fi

# Touch Input Responsiveness
echo "👆 Checking touch input handling..."
if [[ "$IS_EXPO" == true ]]; then
  if grep -r "onPress\|onTouchStart\|Gesture" src/ 2>/dev/null | grep -v "node_modules" > /dev/null; then
    echo "  ✅ Touch input handlers found"
  else
    echo "  ⚠️  WARNING: No touch input handlers found for a game?"
  fi
fi

# Performance: 60 FPS Target
echo "📊 Checking for performance considerations..."
if [[ "$IS_EXPO" == true ]]; then
  # Check for heavy operations in render
  if grep -r "\.map(\|\.filter(\|\.sort(" src/ 2>/dev/null | grep -v "node_modules" | grep -v "useMemo\|useCallback" | wc -l | grep -v "^0$" > /dev/null; then
    echo "  ⚠️  WARNING: Found array operations that might need memoization"
    echo "     Use useMemo/useCallback for operations in game loop"
  else
    echo "  ✅ No obvious performance issues"
  fi
fi

# Asset Size Check (mobile games should be lean)
echo "📦 Checking asset sizes..."
if [[ -d "assets/" ]]; then
  LARGE_ASSETS=$(find assets/ -size +1M 2>/dev/null || true)
  if [[ -n "$LARGE_ASSETS" ]]; then
    echo "  ⚠️  WARNING: Large assets detected (>1MB)"
    echo "$LARGE_ASSETS"
    echo "     Consider compression or downscaling for mobile"
  else
    echo "  ✅ Asset sizes reasonable"
  fi
fi

# Sound Effects Check
echo "🔊 Checking for audio feedback..."
if [[ -d "assets/" ]] && find assets/ -name "*.mp3" -o -name "*.wav" -o -name "*.m4a" 2>/dev/null | head -1 > /dev/null; then
  echo "  ✅ Audio files found (good for game feel)"
else
  echo "  ℹ️  No audio files found - consider adding sound effects"
  echo "     See: .agentic/lib/quality_knowledge/game_2d_web.knowledge.md"
fi

# Battery Usage Warning
echo "🔋 Checking for battery-intensive patterns..."
if grep -r "setInterval.*10\|setInterval.*16\|setInterval.*33" src/ 2>/dev/null | grep -v "node_modules" > /dev/null; then
  echo "  ⚠️  WARNING: High-frequency intervals detected"
  echo "     Consider using requestAnimationFrame or reducing update frequency"
else
  echo "  ✅ No obvious battery drains"
fi

echo ""
echo "==================================="
if [[ $ERRORS -eq 0 ]]; then
  echo "✅ All critical checks passed!"
  echo ""
  echo "Before release, test on physical devices:"
  echo "  - Test on low-end device (older iPhone/Android)"
  echo "  - Check battery usage (30min+ gameplay)"
  echo "  - Verify touch responsiveness"
  echo "  - Test interruptions (calls, notifications)"
  exit 0
else
  echo "❌ $ERRORS critical check(s) failed"
  exit 1
fi

